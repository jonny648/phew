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
    static let megabytes = 128
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

    /// The sandbox profile. Later rules win. Reading is closed for your folders and outside disks; the one file under
    /// them the box may read is Node itself (the app may sit in a folder of yours).
    static func profile(node: String) -> String {
        let quoted = "\"" + node.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
        return """
        (version 1)(allow default)
        (deny network*)
        (deny file-write*)(allow file-write* (literal "/dev/null"))
        (deny process-fork)(deny process-exec)(allow process-exec (literal \(quoted)))
        (deny file-read* (subpath "/Users") (subpath "/Volumes"))(allow file-read* (literal \(quoted)))(allow file-read-metadata)
        """
    }

    /// Runs `code` (JavaScript that defines `run(input)`) on `input`. `stop` is asked ten times a second.
    func run(code: String, input: String, stop: @escaping @Sendable () -> Bool = { false }) async -> SkillEnd {
        guard let node, let engine, FileManager.default.isExecutableFile(atPath: sandbox.path) else { return .noBox }
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
                reader.async { out.data = stdout.fileHandleForReading.readDataToEndOfFile() }
                let started = Date()
                var end: SkillEnd?
                while process.isRunning {
                    if stop() || cancelled.on { end = .stopped } else if Date().timeIntervalSince(started) > seconds { end = .timeout }
                    if end != nil { kill(process.processIdentifier, SIGKILL); break }
                    Thread.sleep(forTimeInterval: 0.02)
                }
                process.waitUntilExit()
                reader.sync {}
                done.resume(returning: end ?? Self.answer(out.data, status: process.terminationStatus))
            }
        } }, onCancel: { cancelled.on = true })
    }

    private final class Flag: @unchecked Sendable { var on = false }

    private final class OutputBox: @unchecked Sendable { var data = Data() }

    /// The helper's one line. Anything else (the sandbox tool refused the profile, Node died, memory ran out) is a failure.
    static func answer(_ data: Data, status: Int32) -> SkillEnd {
        guard status == 0, let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let ok = object["ok"] as? Bool else {
            return .failed("The skill did not finish.")
        }
        if ok, let output = object["output"] as? String { return .done(String(output.prefix(outputLimit))) }
        return .failed(String((object["error"] as? String ?? "The skill failed.").prefix(300)))
    }
}
