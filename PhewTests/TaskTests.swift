import AppKit
import XCTest
@testable import Phew

/// PA.2 and PA.4 offline: the task route, three tasks at once, Stop, the result waiting in the menu, and `add_item`
/// through a fake Hand surface. Scripted providers, made-up words, temporary folders. No network, nothing on screen,
/// nothing scripted for real.
@MainActor
final class TaskTests: XCTestCase {
    typealias Script = RunnerTests.Script

    /// Every request hangs until it is cancelled. Counts the requests made and the ones cancelled.
    final class Hanging: ModelProvider, @unchecked Sendable {
        private let lock = NSLock()
        private var made = 0, cut = 0
        var started: Int { lock.withLock { made } }
        var ended: Int { lock.withLock { cut } }

        func stream(_ request: ModelRequest) -> AsyncThrowingStream<ModelEvent, Error> {
            lock.withLock { made += 1 }
            return AsyncThrowingStream { continuation in
                continuation.onTermination = { _ in self.lock.withLock { self.cut += 1 } }
            }
        }
    }

    /// Writes a calls.log line for every request, as the real provider does.
    struct Logging: ModelProvider {
        let base: any ModelProvider
        func stream(_ request: ModelRequest) -> AsyncThrowingStream<ModelEvent, Error> {
            CallLog.record(request, usage: Usage(input: 1000, output: 100), msFirst: 5, msTotal: 10, stop: "end_turn", error: nil)
            return base.stream(request)
        }
    }

    final class Lines: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [String] = []
        func add(_ line: String) { lock.withLock { items.append(line) } }
        var all: [String] { lock.withLock { items } }
    }

    private var root: URL!
    private var folder: URL!
    private var suite = ""
    private var defaults: UserDefaults!
    private var fake: FakeSurface!
    private var saved: (copies: URL, calls: URL, actions: URL)!
    private let logged = Lines()

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appending(path: "TaskTests-\(UUID().uuidString)")
        folder = root.appending(path: "chosen")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        saved = (Report.copies, CallLog.url, ActionLog.url)
        Report.copies = root.appending(path: "reports")
        CallLog.url = root.appending(path: "calls.log")  // never the user's real logs
        ActionLog.url = root.appending(path: "actions.log")
        suite = "PhewTests.tasks.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.set(true, forKey: Hand.allowedKey)
        fake = FakeSurface()
        let logged = logged
        shellLogTap = { logged.add($0) }
    }

    override func tearDown() async throws {
        shellLogTap = nil
        ActionLog.flush()
        Report.copies = saved.copies
        CallLog.url = saved.calls
        ActionLog.url = saved.actions
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: root)
    }

    private var hand: Hand { Hand(defaults: defaults, surface: fake, list: NeverReadList(defaults: defaults)) }

    private func list(_ provider: any ModelProvider) -> TaskList {
        let folder = folder!
        return TaskList(brain: ClaudeBrain(provider: provider, tools: RunnerTests.FakeMap(out: "")), hand: hand, folder: { folder })
    }

    private func waitUntil(_ seconds: TimeInterval = 5, _ condition: () -> Bool) async throws {
        let end = Date() + seconds
        while !condition() {
            guard Date() < end else { return XCTFail("timed out") }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    private func finished(_ list: TaskList) async throws -> TaskList.Item {
        try await waitUntil { list.items.first?.state != .running }
        return try XCTUnwrap(list.items.first)
    }

    private let report = "# Made-up topic\n\nA short made-up answer."

    private func call(_ input: String, id: String = "toolu_1", name: String = "add_item") -> Script.Reply {
        .init(blocks: #"[{"type":"tool_use","id":"\#(id)","name":"\#(name)","input":\#(input)}]"#, stop: "tool_use")
    }

    /// The tool result the Runner sent back in request `n` (0-based), as text.
    private func result(_ script: Script, _ n: Int) throws -> String {
        let after = try XCTUnwrap(script.requests[n].after.last)
        let blocks = try XCTUnwrap(JSONSerialization.jsonObject(with: after.content) as? [[String: Any]])
        return try XCTUnwrap(blocks.first?["content"] as? String)
    }

    // MARK: The route

    func testTheTaskRouteInTheConductorRequest() {
        let request = Conductor.request("Research kerning tools and write me a report", packet: nil)
        XCTAssertTrue(request.schema?.contains(#""act","task"]"#) == true)
        XCTAssertTrue(request.system.contains("task: they hand Phew work"))
        XCTAssertTrue(request.system.contains("unsure between task and explain, choose explain"))
        XCTAssertEqual(Conductor.decode(#"{"route":"Task"}"#), .task)
        XCTAssertEqual(Set(BrainSpeedCheck.taskCases.map(\.1)), [.task, .explain, .guide, .act])
    }

    func testTheTaskRouteEndsTheAnswerAfterTheRoute() async throws {
        let provider = BrainAgentsTests.FakeProvider(["conductor": [#"{"route":"task"}"#]])
        var events: [BrainEvent] = []
        for try await event in ClaudeBrain(provider: provider).answer("Find out which made-up fonts are free", packet: nil) {
            events.append(event)
        }
        XCTAssertEqual(events, [.route(.task), .done])
        XCTAssertFalse(provider.requests.contains { $0.agent == "guide" }, "the Guide does not answer a task")
    }

    // MARK: Three at once, Stop

    func testThreeRunTogetherAFourthIsRefusedAndStopEndsOne() async throws {
        let provider = Hanging()
        let list = list(provider)
        for n in 1...3 { XCTAssertEqual(list.start("Research made-up topic \(n)", packet: nil), TaskList.started) }
        XCTAssertEqual(list.start("A fourth made-up task", packet: nil), TaskList.full)
        XCTAssertEqual(list.running.count, 3)
        XCTAssertEqual(Set(list.items.map(\.id)).count, 3, "each task has its own number")
        try await waitUntil { provider.started == 3 }
        let first = list.items[0].id
        let stopped = Date()
        list.stop(first)
        try await waitUntil(2) { provider.ended == 1 }
        XCTAssertLessThan(Date().timeIntervalSince(stopped), 2)
        XCTAssertEqual(list.items[0].state, .stopped)
        XCTAssertEqual(list.running.map(\.id), list.items.dropFirst().map(\.id), "the others go on")
        XCTAssertTrue(list.waiting.isEmpty, "a stopped task reports nothing")
        XCTAssertEqual(list.start("Another made-up task", packet: nil), TaskList.started, "a place is free again")
        try await waitUntil { provider.started == 4 }
        list.stopAll()
        try await waitUntil(2) { provider.ended == 4 }
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), [], "nothing saved after Stop")
    }

    func testAFinishedTaskWaitsUntilOpened() async throws {
        let visible = NSApp.windows.filter(\.isVisible).count
        let list = list(Script([.init(text: report)]))
        _ = list.start("Research a made-up topic", packet: nil)
        let item = try await finished(list)
        XCTAssertEqual(item.state, .ready)
        XCTAssertFalse(item.opened)
        XCTAssertEqual(list.waiting.map(\.id), [item.id])
        XCTAssertEqual(NSApp.windows.filter(\.isVisible).count, visible, "nothing appears when a task ends")
        XCTAssertNotNil(item.report?.saved, "the report is saved at once")
        let opened = try XCTUnwrap(list.open(item.id))
        XCTAssertEqual(opened.report?.markdown, report)
        XCTAssertTrue(list.waiting.isEmpty)
    }

    // MARK: add_item (PA.4)

    func testAddItemGoesThroughTheHandAndReturnsTheFixedWord() async throws {
        let script = Script([
            call(#"{"kind":"note","title":"Made-up note","body":"A made-up line"}"#),
            call(#"{"kind":"reminder","title":"Made-up reminder","due":"2030-01-02T09:30"}"#),
            call(#"{"kind":"event","title":"Made-up event","start":"2030-01-03T10:00","end":"2030-01-03T11:00"}"#),
            call(#"{"kind":"sheet","title":"Made-up sheet","top_left":"b2","rows":[["Name","Count"],["Kerning","3"]]}"#),
            .init(text: report),
        ])
        let list = list(script)
        _ = list.start("Research a made-up topic and add a note", packet: nil)
        let item = try await finished(list)
        XCTAssertEqual(script.requests.first?.tools.map(\.name), ["search_map", "add_item"])
        for n in 1...4 { XCTAssertEqual(try result(script, n), "done") }
        XCTAssertEqual(fake.scripts.count, 5)
        XCTAssertEqual(fake.scripts.first, .note(title: "Made-up note", body: "A made-up line"))
        guard case .reminder(_, let due) = fake.scripts[1] else { return XCTFail("a reminder") }
        XCTAssertEqual([due?.year, due?.month, due?.day, due?.hour, due?.minute], [2030, 1, 2, 9, 30])
        XCTAssertEqual(Array(fake.scripts.suffix(2)), [.workbook, .cells(top: "B2", rows: [["Name", "Count"], ["Kerning", "3"]])])
        let markdown = try XCTUnwrap(item.report?.markdown)
        XCTAssertTrue(markdown.hasPrefix(report))
        XCTAssertTrue(markdown.hasSuffix("## Added on your Mac\n\n- Note “Made-up note”\n- Reminder “Made-up reminder”\n- Event “Made-up event”\n- Sheet “Made-up sheet”"))
    }

    func testANonScriptActionIsRefused() async throws {
        let script = Script([
            call(#"{"kind":"click","title":"Bold"}"#),
            call(#"{"x":1}"#, name: "click"),
            call(#"{"kind":"event","title":"Made-up event","start":"2030-01-03T10:00","end":"2030-01-03T09:00"}"#),
            .init(text: report),
        ])
        let list = list(script)
        _ = list.start("Research a made-up topic", packet: nil)
        let item = try await finished(list)
        for n in 1...3 { XCTAssertEqual(try result(script, n), AddItemTool.refused) }
        XCTAssertEqual(fake.scripts, [], "nothing reached the Hand")
        XCTAssertEqual(item.report?.markdown, report, "nothing added, nothing listed")
        // Only whole new items, even from the Shell's own door.
        let append = await list.add(.append(text: "x"), task: item.id), workbook = await list.add(.workbook, task: item.id)
        XCTAssertEqual([append, workbook], [AddItemTool.refused, AddItemTool.refused])
    }

    func testActingOffAnswersOff() async throws {
        defaults.set(false, forKey: Hand.allowedKey)  // the menu's "Let Phew act", off
        let script = Script([call(#"{"kind":"note","title":"Made-up note"}"#), .init(text: report)])
        let list = list(script)
        _ = list.start("Research a made-up topic and add a note", packet: nil)
        let item = try await finished(list)
        XCTAssertEqual(try result(script, 1), HandEnd.off.rawValue)
        XCTAssertEqual(fake.scripts, [])
        XCTAssertTrue(try XCTUnwrap(item.report?.markdown).hasSuffix("\n\n" + AddedItems.off))
    }

    // MARK: Logs

    func testTheTasksWordsAreNeverLogged() async throws {
        let planted = "Zanzibarquill"
        let script = Script([call(#"{"kind":"note","title":"\#(planted) note","body":"\#(planted)"}"#), .init(text: "# \(planted)\n\nMade up.")])
        let list = list(Logging(base: script))
        _ = list.start("Research \(planted) and write me a report", packet: nil)
        let item = try await finished(list)
        XCTAssertEqual(item.state, .ready)
        XCTAssertEqual(item.cost ?? 0, 2 * Tier.main.model.cost(Usage(input: 1000, output: 100)), accuracy: 1e-6, "the cost from calls.log")
        ActionLog.flush()
        let calls = try String(contentsOf: CallLog.url, encoding: .utf8)
        XCTAssertTrue(calls.contains(#""task":\#(item.id)"#))
        let actions = (try? String(contentsOf: ActionLog.url, encoding: .utf8)) ?? ""
        XCTAssertFalse(logged.all.isEmpty, "the tap saw the log lines")
        for text in logged.all + [calls, actions] { XCTAssertFalse(text.contains(planted), text) }
    }
}
