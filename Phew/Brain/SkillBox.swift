import Foundation

/// How one run of a skill ended.
enum SkillEnd: Equatable, Sendable {
    /// What the skill returned, cut at `SkillBox.outputLimit`.
    case done(String)
    /// The skill's own error, or the helper's: short, for the model and the card.
    case failed(String)
    case timeout
    case stopped
    /// The box could not be made (no helper, no Node, no sandbox tool): nothing ran.
    case noBox
}

/// The closed box a self-made skill runs in (decision 44, 16 November 2026): Phew's TypeScript helper (`Engine/`,
/// built to `engine.js`) on the Node program shipped inside the app, started under a macOS sandbox profile.
/// The profile is the lock: no network, no file writes, no child programs, no reading of your folders. The skill gets
/// text and gives text back. Every limit here is kept by this code, never by the helper or the skill.
/// One process per run: nothing is left between two skills, and killing it is Stop.
struct SkillBox: Sendable {
    static let seconds: TimeInterval = 5
    /// Node's own heap limit, and the ceiling on the process's real memory, which Swift watches: Node's limit does
    /// not count memory outside the JavaScript heap.
    static let megabytes = 128
    static let realMegabytes = 384
    /// The most the helper may write back before it is ended: far over any honest answer.
    static let rawOutputLimit = 1_000_000
    static let outputLimit = 20_000
    static let inputLimit = 100_000

    /// The Node program, and the helper's code as text (handed over with `-e`, so Node reads no file).
    var node: URL?
    var engine: String?
    var sandbox = URL(filePath: "/usr/bin/sandbox-exec")
    var seconds = SkillBox.seconds

    static let shared = SkillBox(node: bundledNode, engine: bundledEngine)

    static var bundledEngine: String? {
        Bundle.main.url(forResource: "engine", withExtension: "js").flatMap { try? String(contentsOf: $0, encoding: .utf8) }
    }

    static var bundledNode: URL? {
        var places = [Bundle.main.bundleURL.appending(path: "Contents/Helpers/node")]
        #if DEBUG
        // A build from Xcode or the tests: the copy Tools/fetch-node.sh put in the project folder. Never in a release.
        places.append(URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Vendor/node/node"))
        #endif
        return places.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    /// The sandbox profile. Later rules win. Everything is refused first: the network, writing, starting or signalling
    /// another program, and reading any file. Then only what Node needs to start is opened: itself, the system's own
    /// libraries, and the names of the folders on the way to itself. Nothing of yours, no temporary folder, no log.
    /// One thing it cannot hide: asking about a path under a closed folder answers "refused" when the path exists and
    /// "not there" when it does not. Nothing can be read either way.
    static func profile(node: String) -> String {
        func quoted(_ path: String) -> String {
            "\"" + path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
        }
        var parents: [String] = [], path = (node as NSString).deletingLastPathComponent
        while path != "/", !path.isEmpty {
            parents.append("(literal \(quoted(path)))")
            path = (path as NSString).deletingLastPathComponent
        }
        return """
        (version 1)(allow default)
        (deny network*)
        (deny file-write*)(allow file-write* (literal "/dev/null"))
        (deny process-fork)(deny process-exec)(allow process-exec (literal \(quoted(node))))
        (deny signal)(allow signal (target self))
        (deny file-read*)(deny file-read-metadata)
        (allow file-read* (literal \(quoted(node))) (subpath "/System") (subpath "/usr/lib") (subpath "/usr/share") (subpath "/private/var/db/dyld") (literal "/dev/null") (literal "/dev/urandom") (literal "/dev/random") (literal "/"))
        (allow file-read-metadata \(parents.joined(separator: " ")) (literal "/private") (literal "/var") (literal "/tmp") (literal "/etc") (literal "/dev"))
        """
    }

    /// The real memory of a process, in megabytes: what the system charges it, heap or not.
    static func megabytes(of pid: pid_t) -> Int {
        var info = rusage_info_current()
        let ok = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, $0) }
        }
        return ok == 0 ? Int(info.ri_phys_footprint / 1_048_576) : 0
    }

    /// Runs `code` (JavaScript that defines `run(input)`) on `input`. `stop` is asked ten times a second.
    func run(code: String, input: String, stop: @escaping @Sendable () -> Bool = { false }) async -> SkillEnd {
        guard let link = node, let engine, FileManager.default.isExecutableFile(atPath: sandbox.path) else { return .noBox }
        // The sandbox compares real paths: a link on the way to the app (as /var is on a Mac) would refuse Node itself.
        guard let real = realpath(link.path, nil) else { return .noBox }
        let node = URL(filePath: String(cString: real))
        free(real)
        guard input.count <= Self.inputLimit else { return .failed("The input is longer than \(Self.inputLimit) characters.") }
        let request: [String: Any] = ["code": code, "input": input, "ms": Int(seconds * 1000) - 500]
        guard let body = try? JSONSerialization.data(withJSONObject: request) else { return .failed("The request could not be written.") }
        let sandbox = sandbox, seconds = seconds
        // Cancelling the task that asked (Stop) ends the run like `stop` does.
        let cancelled = Flag()
        return await withTaskCancellationHandler(operation: { await withCheckedContinuation { done in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process(), stdin = Pipe(), stdout = Pipe()
                process.executableURL = sandbox
                process.arguments = ["-p", Self.profile(node: node.path), node.path, "--max-old-space-size=\(Self.megabytes)", "-e", engine]
                process.environment = [:]  // no key, no path, nothing of yours
                process.currentDirectoryURL = URL(filePath: "/")
                process.standardInput = stdin
                process.standardOutput = stdout
                process.standardError = FileHandle.nullDevice
                do { try process.run() } catch { return done.resume(returning: .noBox) }
                // If the child is already gone, a write must fail quietly, not end Phew with a broken-pipe signal.
                _ = fcntl(stdin.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1)
                try? stdin.fileHandleForWriting.write(contentsOf: body)
                try? stdin.fileHandleForWriting.close()
                let out = OutputBox()
                let reader = DispatchQueue(label: "phew.skillbox.read")
                // Read in pieces and stop at the limit: a flood must never fill Phew's own memory.
                reader.async {
                    let handle = stdout.fileHandleForReading
                    while let piece = try? handle.read(upToCount: 65_536), !piece.isEmpty {
                        out.data.append(piece)
                        if out.data.count > Self.rawOutputLimit {
                            out.flooded = true
                            kill(process.processIdentifier, SIGKILL)
                            break
                        }
                    }
                }
                let started = Date()
                var end: SkillEnd?
                while process.isRunning {
                    if stop() || cancelled.on {
                        end = .stopped
                    } else if Date().timeIntervalSince(started) > seconds {
                        end = .timeout
                    } else if Self.megabytes(of: process.processIdentifier) > Self.realMegabytes {
                        end = .failed("The skill used more than \(Self.realMegabytes) MB of memory and was ended.")
                    }
                    if end != nil { kill(process.processIdentifier, SIGKILL); break }
                    Thread.sleep(forTimeInterval: 0.01)
                }
                process.waitUntilExit()
                reader.sync {}
                if out.flooded { end = .failed("The skill wrote far too much and was ended.") }
                done.resume(returning: end ?? Self.answer(out.data, status: process.terminationStatus))
            }
        } }, onCancel: { cancelled.on = true })
    }

    private final class Flag: @unchecked Sendable { var on = false }

    private final class OutputBox: @unchecked Sendable { var data = Data(); var flooded = false }

    /// The helper's one line. Anything else (the sandbox tool refused the profile, Node died, memory ran out) is a failure.
    static func answer(_ data: Data, status: Int32) -> SkillEnd {
        guard status == 0, let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let ok = object["ok"] as? Bool else {
            return .failed("The skill did not finish.")
        }
        if ok, let output = object["output"] as? String { return .done(String(output.prefix(outputLimit))) }
        return .failed(String((object["error"] as? String ?? "The skill failed.").prefix(300)))
    }
}
