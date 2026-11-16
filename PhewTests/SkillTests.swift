import XCTest
@testable import Phew

/// Phase NC: self-made skills in the closed box. These run the real helper on the real Node program
/// (`Tools/fetch-node.sh`) under the real sandbox profile. No model, no network. Made-up skills only.
final class SkillTests: XCTestCase {
    private var folder: URL!
    private var store: SkillStore { SkillStore(folder: folder) }

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appending(path: "phew-skills-\(UUID().uuidString)")
        XCTAssertNotNil(SkillBox.bundledNode, "run Tools/fetch-node.sh once: the tests need the Node program")
        XCTAssertNotNil(SkillBox.bundledEngine, "engine.js is in the app: Tools/build-engine.sh makes it")
    }

    override func tearDown() { try? FileManager.default.removeItem(at: folder) }

    private let sum = "function run(input) { return input.split(',').map(Number).reduce((a, b) => a + b, 0).toString(); }"

    // MARK: The box

    func testASkillGetsTextAndGivesTextBack() async {
        let end = await SkillBox.shared.run(code: sum, input: "1,2,39")
        XCTAssertEqual(end, .done("42"))
    }

    /// The lock is the sandbox profile, so it is tested with a stand-in for the helper that tries everything a
    /// program could: the network, writing a file, reading your home folder, starting a program, reading the environment.
    func testTheBoxRefusesNetworkWritesYourFoldersAndPrograms() async throws {
        let probe = """
        const fs = require("fs"), cp = require("child_process"), net = require("net"), os = require("os");
        const out = {};
        const tryIt = (name, f) => { try { f(); out[name] = "open"; } catch (e) { out[name] = "refused"; } };
        tryIt("write", () => fs.writeFileSync(os.tmpdir() + "/phew-box-probe.txt", "made up"));
        tryIt("home", () => fs.readdirSync(os.homedir()));
        tryIt("temporary", () => fs.readdirSync(os.tmpdir()));
        tryIt("applications", () => fs.readdirSync("/Applications"));
        tryIt("log", () => fs.readFileSync("/private/var/log/system.log"));
        tryIt("accounts", () => fs.readFileSync("/etc/passwd"));
        tryIt("signal", () => process.kill(process.ppid, 0));
        tryIt("program", () => cp.execFileSync("/bin/echo", ["made up"]));
        out.environment = Object.keys(process.env).filter(k => !k.startsWith("__CF")).length;
        const answer = () => { process.stdout.write(JSON.stringify({ ok: true, output: JSON.stringify(out) }) + "\\n"); process.exit(0); };
        const socket = net.connect(80, "192.0.2.1");
        socket.on("error", () => { out.network = "refused"; answer(); });
        socket.on("connect", () => { out.network = "open"; answer(); });
        """
        var box = SkillBox.shared
        box.engine = probe
        guard case .done(let text) = await box.run(code: "", input: "") else { return XCTFail("the probe did not answer") }
        let got = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        for door in ["write", "home", "temporary", "applications", "log", "accounts", "signal", "program", "network"] { XCTAssertEqual(got[door] as? String, "refused", door) }
        XCTAssertEqual(got["environment"] as? Int, 0, "nothing of yours is in its environment")
        XCTAssertFalse(FileManager.default.fileExists(atPath: NSTemporaryDirectory() + "phew-box-probe.txt"))
    }

    func testAnEndlessLoopIsEndedAndSoIsOneTheHelperCannotEnd() async {
        var box = SkillBox.shared
        box.seconds = 1
        let started = Date()
        let end = await box.run(code: "function run() { for (;;) {} }", input: "")
        XCTAssertNotEqual(end, .done(""))
        XCTAssertLessThan(Date().timeIntervalSince(started), 3)
        // A helper that never answers: Swift's own clock ends it.
        box.engine = "setInterval(() => {}, 1000);"
        let hung = await box.run(code: "", input: "")
        XCTAssertEqual(hung, .timeout)
    }

    func testStopEndsARunWithinASecond() async {
        var box = SkillBox.shared
        box.engine = "setInterval(() => {}, 1000);"
        let started = Date()
        let end = await box.run(code: "", input: "", stop: { Date().timeIntervalSince(started) > 0.2 })
        XCTAssertEqual(end, .stopped)
        XCTAssertLessThan(Date().timeIntervalSince(started), 1)
    }

    func testCancellingTheTaskEndsTheRun() async {
        var box = SkillBox.shared
        box.engine = "setInterval(() => {}, 1000);"
        let run = Task { [box] in await box.run(code: "", input: "") }
        try? await Task.sleep(for: .milliseconds(200))
        let started = Date()
        run.cancel()
        let end = await run.value
        XCTAssertEqual(end, .stopped)
        XCTAssertLessThan(Date().timeIntervalSince(started), 1)
    }

    /// The app may sit behind a link (as /var is on a Mac): the box still starts, on Node's real path.
    func testNodeBehindALinkStillRuns() async throws {
        let link = FileManager.default.temporaryDirectory.appending(path: "phew-node-link-\(UUID().uuidString)")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: try XCTUnwrap(SkillBox.bundledNode))
        defer { try? FileManager.default.removeItem(at: link) }
        var box = SkillBox.shared
        box.node = link
        let end = await box.run(code: sum, input: "1,2")
        XCTAssertEqual(end, .done("3"))
    }

    /// Memory outside the JavaScript heap, which Node's own limit does not count: Swift's watch ends the process.
    func testMemoryOutsideTheHeapIsEndedBySwift() async {
        var box = SkillBox.shared
        box.engine = "const kept = []; setInterval(() => { kept.push(Buffer.alloc(64 * 1024 * 1024, 1)); }, 5);"
        let end = await box.run(code: "", input: "")
        XCTAssertEqual(end, .failed("The skill used more than \(SkillBox.realMegabytes) MB of memory and was ended."))
    }

    /// A helper that floods its answer pipe is ended at the limit; Phew never holds the flood.
    func testAFloodOfOutputIsEnded() async {
        var box = SkillBox.shared
        box.engine = "const piece = 'x'.repeat(65536); for (;;) { require('fs').writeSync(1, piece); }"
        let started = Date()
        let end = await box.run(code: "", input: "")
        XCTAssertEqual(end, .failed("The skill wrote far too much and was ended."))
        XCTAssertLessThan(Date().timeIntervalSince(started), 3)
    }

    /// The way out of the context the checker found, and typed arrays by name: closed in the helper.
    func testTheWayOutOfTheContextIsClosed() async {
        for way in ["this.constructor.constructor('return process')()", "new Uint8Array(1500000000)"] {
            let end = await SkillBox.shared.run(code: "function run() { return typeof (\(way)); }", input: "")
            if case .done(let text) = end { XCTAssertEqual(text, "undefined", way) }
        }
    }

    /// What is kept is what was tested, whatever line breaks the description holds.
    func testTheKeptCodeIsTheTestedCode() async throws {
        let code = "var run = function (i) { return 'A'; }\nfunction later(i) { return 'B'; }"
        for about in ["x\r", "x\r\ny", "x\u{2028}y", ""] {
            try await store.write(name: "kept-as-tested", about: about, code: code, testInput: "", expected: "A")
            XCTAssertEqual(store.find("kept-as-tested")?.code, code, about.debugDescription)
            let end = await store.run("kept-as-tested", input: "")
            XCTAssertEqual(end, .done("A"))
        }
    }

    func testTooMuchOutputIsCutAndTooMuchInputIsRefused() async {
        let end = await SkillBox.shared.run(code: "function run() { return 'x'.repeat(50000); }", input: "")
        guard case .done(let text) = end else { return XCTFail("\(end)") }
        XCTAssertEqual(text.count, SkillBox.outputLimit)
        let long = await SkillBox.shared.run(code: sum, input: String(repeating: "1", count: SkillBox.inputLimit + 1))
        XCTAssertEqual(long, .failed("The input is longer than \(SkillBox.inputLimit) characters."))
    }

    func testWithNoSandboxToolOrNoNodeNothingRuns() async {
        var box = SkillBox.shared
        box.sandbox = URL(filePath: "/usr/bin/no-such-sandbox-tool")
        let noTool = await box.run(code: sum, input: "1,2")
        XCTAssertEqual(noTool, .noBox)
        box = SkillBox(node: nil, engine: SkillBox.bundledEngine)
        let noNode = await box.run(code: sum, input: "1,2")
        XCTAssertEqual(noNode, .noBox)
    }

    func testAProfileTheSandboxRefusesRunsNothing() {
        // What comes back when the sandbox tool exits without starting Node: a failure, never a result.
        XCTAssertEqual(SkillBox.answer(Data(), status: 65), .failed("The skill did not finish."))
        XCTAssertEqual(SkillBox.answer(Data(#"{"ok":true,"output":"made up"}"#.utf8), status: 1), .failed("The skill did not finish."))
        let profile = SkillBox.profile(node: "/made up/\"app/node")
        XCTAssertTrue(profile.contains(#"(allow process-exec (literal "/made up/\"app/node"))"#))
        XCTAssertTrue(profile.contains(#"(literal "/made up/\"app") (literal "/made up")"#), "the folders on the way, by name only")
        XCTAssertTrue(profile.contains("(deny file-read*)(deny file-read-metadata)") && profile.contains("(deny signal)"))
    }

    // MARK: The store

    func testASkillIsKeptOnlyWhenItsOwnTestPasses() async throws {
        do {
            try await store.write(name: "sum-list", about: "Adds numbers", code: sum, testInput: "1,2", expected: "4")
            XCTFail("kept with a failing test")
        } catch {
            XCTAssertEqual(error as? SkillProblem, .testFailed("it gave \"3\""))
        }
        XCTAssertEqual(store.all(), [])
        try await store.write(name: "sum-list", about: "Adds numbers\nseparated by commas", code: sum, testInput: "1,2", expected: "3")
        let kept = try XCTUnwrap(store.find("sum-list"))
        XCTAssertEqual(kept.about, "Adds numbers separated by commas")
        XCTAssertEqual(kept.code, sum)
        let end = await store.run("sum-list", input: "20,22")
        XCTAssertEqual(end, .done("42"))
    }

    func testADeletedSkillCannotRunAndNamesCannotLeaveTheFolder() async throws {
        try await store.write(name: "sum-list", about: "Adds numbers", code: sum, testInput: "1,2", expected: "3")
        store.delete("sum-list")
        XCTAssertEqual(store.all(), [])
        let end = await store.run("sum-list", input: "1,2")
        XCTAssertEqual(end, .failed("There is no skill named \"sum-list\"."))
        for name in ["../escape", "a/b", "Sum", "ab", "-rf", "name.js", String(repeating: "a", count: 41)] {
            XCTAssertFalse(SkillStore.valid(name), name)
            do {
                try await store.write(name: name, about: "", code: sum, testInput: "1", expected: "1")
                XCTFail(name)
            } catch {
                XCTAssertEqual(error as? SkillProblem, .name)
            }
        }
    }

    /// The menu's list goes through the Brain: it shows what is kept and Delete removes the file.
    @MainActor
    func testTheMenuListsSkillsAndDeletesOne() async throws {
        try await store.write(name: "sum-list", about: "Adds numbers", code: sum, testInput: "1,2", expected: "3")
        let brain = ClaudeBrain(skills: SkillTools(store: store), map: BrainMap(open: { throw MapError.underTests }, maintenance: false))
        let model = SkillsModel(brain: brain)
        await model.refresh()
        XCTAssertEqual(model.skills.map(\.name), ["sum-list"])
        XCTAssertEqual(model.skills.first?.about, "Adds numbers")
        await model.delete("sum-list")
        XCTAssertEqual(model.skills, [])
        XCTAssertEqual(store.all(), [])
        // A Brain with no skill tools (tests, the checks) lists nothing and deletes nothing.
        let none = await ClaudeBrain(map: BrainMap(open: { throw MapError.underTests }, maintenance: false)).skills()
        XCTAssertEqual(none, [])
    }

    func testCodeOverTheLimitIsRefused() async {
        do {
            try await store.write(name: "too-long", about: "", code: sum + String(repeating: " ", count: SkillStore.codeLimit), testInput: "1", expected: "1")
            XCTFail("kept")
        } catch {
            XCTAssertEqual(error as? SkillProblem, .tooLong)
        }
    }
}
