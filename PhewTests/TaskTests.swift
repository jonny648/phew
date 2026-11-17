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

    private let report = "# Made-up topic\n\nA short made-up answer.\n\n## Not checked\n\nNothing."

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
        XCTAssertTrue(request.schema?.contains(#""act","task","unclear","watch"]"#) == true)
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

    func testThreeRunTogetherAndStopEndsOne() async throws {
        let provider = Hanging()
        let list = list(provider)
        for n in 1...3 { XCTAssertEqual(list.start("Research made-up topic \(n)", packet: nil), TaskList.started) }
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

    /// Every request waits until `finishOldest` answers it with a report. Keeps the requests made.
    final class Held: ModelProvider, @unchecked Sendable {
        private let lock = NSLock()
        private var made: [ModelRequest] = []
        private var open: [AsyncThrowingStream<ModelEvent, Error>.Continuation] = []
        var requests: [ModelRequest] { lock.withLock { made } }

        func stream(_ request: ModelRequest) -> AsyncThrowingStream<ModelEvent, Error> {
            AsyncThrowingStream { continuation in
                self.lock.withLock { made.append(request); open.append(continuation) }
            }
        }

        func finishOldest(_ text: String) {
            guard let next = lock.withLock({ open.isEmpty ? nil : open.removeFirst() }) else { return }
            next.yield(.text(text))
            next.yield(.content(Data("[]".utf8)))
            next.yield(.stop("end_turn"))
            next.finish()
        }
    }

    /// R8: a fourth task waits for a free place with its one screen read held, and starts by itself when one ends;
    /// at most five wait, the sixth is refused; Stop removes a waiting one and drops its screen read.
    func testAFourthWaitsAndStartsWhenOneEnds() async throws {
        let provider = Held()
        let list = list(provider)
        for n in 1...3 { XCTAssertEqual(list.start("Research made-up topic \(n)", packet: nil), TaskList.started) }
        try await waitUntil { provider.requests.count == 3 }
        let screen = ContextPacket(appName: "TextEdit", bundleID: "com.apple.TextEdit", windowTitle: "Made-up notes",
                                   visibleText: "Quillmarrow made-up line", cursor: nil, documentPath: nil)
        XCTAssertEqual(list.start("A fourth made-up task", packet: screen), TaskList.queued)
        let fourth = try XCTUnwrap(list.items.last)
        XCTAssertEqual(fourth.state, .queued)
        XCTAssertEqual(fourth.line, TaskList.queuedProgress)
        XCTAssertNotNil(list.held[fourth.id], "the screen read waits with it, in memory")
        for n in 5...8 { XCTAssertEqual(list.start("Made-up task \(n)", packet: screen), TaskList.queued) }
        XCTAssertEqual(list.start("A ninth made-up task", packet: nil), TaskList.full, "at most five wait")
        XCTAssertEqual(list.queue.count, 5)
        XCTAssertTrue(list.waiting.isEmpty, "a waiting task is not a result")
        // Stop removes a waiting one before it starts: its screen read is dropped and nothing is sent for it.
        let eighth = list.queue[4].id
        list.stop(eighth)
        XCTAssertNil(list.held[eighth])
        XCTAssertEqual(list.queue.count, 4)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(provider.requests.count, 3, "nothing starts while three run")
        // One of the three ends: the oldest waiting one starts by itself, with the screen read it was given.
        provider.finishOldest(report)
        try await waitUntil { provider.requests.count == 4 }
        // Which of the three ended is the provider's oldest request, not always the first task: they start together.
        XCTAssertEqual(list.items.filter { $0.state == .ready }.count, 1)
        XCTAssertEqual(list.items.first { $0.id == fourth.id }?.state, .running)
        XCTAssertNil(list.held[fourth.id], "the task holds it now, and drops it when it ends")
        XCTAssertTrue(try XCTUnwrap(provider.requests.last).text.contains("Quillmarrow made-up line"))
        XCTAssertEqual(list.running.count, 3)
        XCTAssertEqual(list.queue.count, 3)
        // Stop all: the waiting ones go first, so none starts; nothing more is sent.
        list.stopAll()
        XCTAssertTrue(list.held.isEmpty)
        XCTAssertTrue(list.running.isEmpty && list.queue.isEmpty)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(provider.requests.count, 4)
    }

    /// N2.11: a finished task proposes nothing by itself; the one small-model call comes when the user opens its list.
    func testAReportsFactsAreSortedOnlyWhenTheUserOpensTheList() async throws {
        let facts = #"{"facts":[{"sentence":"Made-up fact.","kind":"reference","about_me":false,"things":[{"class":"Topic","kind":"","name":"Made-up topic"}],"date":"","instruction":false,"sensitive":false}]}"#
        let fake = BrainAgentsTests.FakeProvider(rounds: ["runner": [.init(pieces: [report])], "librarian": [.init(pieces: [facts])]])
        let brain = ClaudeBrain(provider: fake, tools: RunnerTests.FakeMap(out: ""))
        let folder = folder!
        let list = TaskList(brain: brain, hand: hand, folder: { folder })
        _ = list.start("Research a made-up topic", packet: nil)
        let item = try await finished(list)
        _ = list.open(item.id)
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(fake.requests.map(\.agent), ["runner"], "no proposal before the list is opened")
        let model = ImportModel(brain: brain)
        model.sort(report: try XCTUnwrap(item.report?.markdown))
        try await waitUntil { model.stage == .ticks }
        XCTAssertEqual(fake.requests.map(\.agent), ["runner", "librarian"])
        XCTAssertEqual(fake.requests.last?.tier, .small)
        XCTAssertEqual(model.candidates.map(\.ticked), [false])
        XCTAssertEqual(model.note, Importer.reportLine)
    }

    func testAFinishedTaskWaitsUntilOpened() async throws {
        let list = list(Script([.init(text: report)]))
        _ = list.start("Research a made-up topic", packet: nil)
        let item = try await finished(list)
        XCTAssertEqual(item.state, .ready)
        XCTAssertFalse(item.opened)
        XCTAssertEqual(list.waiting.map(\.id), [item.id])
        // "Nothing appears" holds by construction: the list has no link to the card. A count of the test host's own
        // windows was tried here and failed now and then, for windows that are not the task's.
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

    // MARK: Skills (NC)

    /// A task writes a skill, runs it, and the report names it. The real helper in the real box; made-up numbers.
    func testATaskWritesASkillRunsItAndTheReportNamesIt() async throws {
        let code = "function run(input) { return input.split(',').map(Number).reduce((a, b) => a + b, 0).toString(); }"
        let write = try String(data: JSONSerialization.data(withJSONObject: [
            "name": "sum-list", "about": "Adds numbers separated by commas", "code": code, "test_input": "1,2", "expected": "3"]), encoding: .utf8)!
        let script = Script([
            call(write, name: "write_skill"),
            call(#"{"name":"sum-list","input":"20,22"}"#, name: "run_skill"),
            call(#"{"name":"no-such-skill","input":"1"}"#, name: "run_skill"),
            .init(text: report),
        ])
        let store = SkillStore(folder: root.appending(path: "skills"))
        let folder = folder!
        let brain = ClaudeBrain(provider: script, tools: RunnerTests.FakeMap(out: ""), skills: SkillTools(store: store))
        let list = TaskList(brain: brain, hand: hand, folder: { folder })
        _ = list.start("Add up a made-up list", packet: nil)
        let item = try await finished(list)
        XCTAssertEqual(script.requests.first?.tools.map(\.name), ["search_map", "add_item", "write_skill", "run_skill"])
        XCTAssertEqual(try result(script, 1), "Kept as sum-list.")
        XCTAssertEqual(try result(script, 2), "<skill>\n42\n</skill>")
        XCTAssertEqual(try result(script, 3), "The skill failed: There is no skill named \"no-such-skill\".")
        XCTAssertEqual(store.all().map(\.name), ["sum-list"])
        XCTAssertEqual(item.report?.markdown, report + "\n\n## Skills he used\n\n- sum-list", "a skill that does not exist is not listed")
        XCTAssertEqual(fake.scripts, [], "a skill never reaches the Hand")
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

    // MARK: N2.4: what cannot be undone waits for one confirm

    func testAddItemAsksForChangesAndDeletesByTitle() throws {
        func item(_ json: String) -> HandScript? { AddItemTool.item(Data(json.utf8))?.2 }
        XCTAssertEqual(item(#"{"kind":"note","title":"Made-up plan","action":"rename","new_title":"Made-up plan two"}"#),
                       .rename(.note, title: "Made-up plan", to: "Made-up plan two"))
        XCTAssertEqual(item(#"{"kind":"note","title":"Made-up plan","action":"edit","body":"A made-up line"}"#),
                       .noteBody(title: "Made-up plan", body: "A made-up line"))
        XCTAssertEqual(item(#"{"kind":"reminder","title":"Made-up call","action":"complete"}"#), .complete(title: "Made-up call"))
        XCTAssertEqual(item(#"{"kind":"event","title":"Made-up review","action":"delete"}"#), .delete(.event, title: "Made-up review"))
        let start = try XCTUnwrap(DateComponents(calendar: .current, year: 2030, month: 1, day: 3, hour: 10, minute: 0).date)
        XCTAssertEqual(item(#"{"kind":"event","title":"Made-up review","action":"move","start":"2030-01-03T10:00"}"#),
                       .move(title: "Made-up review", start: start, end: nil))
        XCTAssertEqual(AddItemTool.item(Data(#"{"kind":"reminder","title":"Made-up call","action":"delete"}"#.utf8))?.0, "Deleted reminder")
        // Refused: a sheet changed, a rename with no new name, a verb on the wrong kind, a move with no time.
        for bad in [#"{"kind":"sheet","title":"Made-up","action":"delete"}"#, #"{"kind":"note","title":"Made-up","action":"rename"}"#,
                    #"{"kind":"note","title":"Made-up","action":"complete"}"#, #"{"kind":"event","title":"Made-up","action":"move","start":"2030-01-03"}"#,
                    #"{"kind":"note","title":"Made-up","action":"burn"}"#] {
            XCTAssertNil(item(bad), bad)
        }
        XCTAssertTrue(ToolSpec.addItem.schema.contains(#""enum":["add","rename","edit","complete","move","delete"]"#))
    }

    /// R7: three changes wait, each in its own row, none done before the confirm; Confirm all runs the three through
    /// the Hand, one after another.
    func testThreeWaitingChangesAreConfirmedAtOnceAndNoneBefore() async throws {
        fake.apps.add("Made-up plan", ["A made-up line"])
        fake.items.entries[.reminder] = [HandEntry(id: "r1", title: "Made-up call"), HandEntry(id: "r2", title: "Made-up review")]
        let script = Script([
            call(#"{"kind":"note","title":"Made-up plan","action":"delete"}"#),
            call(#"{"kind":"reminder","title":"Made-up call","action":"delete"}"#, id: "toolu_2"),
            call(#"{"kind":"reminder","title":"Made-up review","action":"rename","new_title":"Made-up review later"}"#, id: "toolu_3"),
            .init(text: report),
        ])
        let list = list(script)
        _ = list.start("Research a made-up topic and tidy my notes", packet: nil)
        let item = try await finished(list)
        for n in 1...3 { XCTAssertEqual(try result(script, n), HandEnd.needsConfirm.rawValue, "an agent's change waits: it has no Undo") }
        XCTAssertEqual(fake.apps.notes.count, 1, "not deleted")
        XCTAssertEqual(fake.changed, [], "nothing changed before the confirm")
        XCTAssertEqual(list.confirms.map(\.id), [item.id])
        XCTAssertEqual(item.waits.map(\.script), [.delete(.note, title: "Made-up plan"), .delete(.reminder, title: "Made-up call"),
                                                  .rename(.reminder, title: "Made-up review", to: "Made-up review later")])
        XCTAssertEqual(Set(item.waits.map(\.id)).count, 3, "a row each")
        XCTAssertEqual(TaskList.asks(try XCTUnwrap(item.waits[0].script)), "Waiting for you: Delete the note “Made-up plan”?")
        let markdown = try XCTUnwrap(item.report?.markdown)
        XCTAssertTrue(markdown.contains("## Waiting for your confirm in Phew's menu\n\n- Deleted note “Made-up plan”\n- Deleted reminder “Made-up call”\n- Renamed reminder “Made-up review”"), markdown)
        // Confirm all runs exactly those actions, in order, through the Hand, as the user's own.
        let confirmed = await list.confirm(item.id)
        XCTAssertEqual(confirmed, .done)
        XCTAssertTrue(fake.apps.notes.isEmpty)
        XCTAssertEqual(fake.changed, [.delete(.note, title: "Made-up plan"), .delete(.reminder, title: "Made-up call"),
                                      .rename(.reminder, title: "Made-up review", to: "Made-up review later")], "the three, in order")
        XCTAssertTrue(list.confirms.isEmpty)
        let again = await list.confirm(item.id)
        XCTAssertEqual(again, .stopped, "once")
    }

    /// R7: one row confirmed alone leaves the others waiting; the first that fails ends the run, is dropped, and the
    /// ones after it stay waiting; at most 20 wait, the next is refused.
    func testOneRowAloneAFailureAndTheCeiling() async throws {
        for n in 1...21 { fake.apps.add("Made-up note \(n)") }
        let deletes = (1...21).map { #"{"type":"tool_use","id":"toolu_\#($0)","name":"add_item","input":{"kind":"note","title":"Made-up note \#($0)","action":"delete"}}"# }
        let script = Script([.init(blocks: "[" + deletes.joined(separator: ",") + "]", stop: "tool_use"), .init(text: report)])
        let list = list(script)
        _ = list.start("Research a made-up topic and tidy my notes", packet: nil)
        var item = try await finished(list)
        let results = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(script.requests[1].after.last).content) as? [[String: Any]])
        XCTAssertEqual(results.compactMap { $0["content"] as? String },
                       Array(repeating: HandEnd.needsConfirm.rawValue, count: TaskList.mostWaits) + [AddItemTool.refused])
        XCTAssertEqual(item.waits.count, 20)
        XCTAssertEqual(fake.apps.notes.count, 21, "nothing deleted before a confirm")
        // The second row alone.
        let second = await list.confirm(item.id, only: item.waits[1].id)
        XCTAssertEqual(second, .done)
        XCTAssertEqual(fake.apps.notes.map(\.name).contains("Made-up note 2"), false)
        XCTAssertEqual(fake.apps.notes.count, 20)
        item = try XCTUnwrap(list.items.first)
        XCTAssertEqual(item.waits.count, 19)
        // Note 3 is gone before Confirm all: it fails, is dropped, and the 17 after it still wait. Notes 1 went.
        fake.apps.notes.removeAll { $0.name == "Made-up note 3" }
        let all = await list.confirm(item.id)
        XCTAssertNotEqual(all, .done)
        item = try XCTUnwrap(list.items.first)
        XCTAssertEqual(item.waits.map(\.script), (4...20).map { .delete(.note, title: "Made-up note \($0)") })
        XCTAssertFalse(fake.apps.notes.map(\.name).contains("Made-up note 1"))
        list.dismiss(item.id, only: item.waits[0].id)
        XCTAssertEqual(list.items.first?.waits.count, 16)
    }

    /// NR.60: in the PDF a link's address follows its words only for a web address, as on the card.
    func testThePDFShowsOnlyWebAddressesAfterLinks() {
        let text = Report.styled("[Made-up source](https://example.com/page) and [open me](file:///etc/made-up) and [run](javascript:alert(1))").string
        XCTAssertTrue(text.contains("Made-up source (https://example.com/page)"), text)
        XCTAssertTrue(text.contains("open me and run"), text)
        XCTAssertFalse(text.contains("file:"), text)
        XCTAssertFalse(text.contains("javascript:"), text)
    }

    /// R29: a change the user confirmed for an agent can be put back from the menu, until the task's result is opened.
    func testAConfirmedChangeCanBeUndoneUntilTheResultIsOpened() async throws {
        fake.apps.add("Made-up plan", ["A made-up line"])
        let script = Script([call(#"{"kind":"note","title":"Made-up plan","action":"delete"}"#), .init(text: report)])
        let list = list(script)
        _ = list.start("Research a made-up topic and tidy my notes", packet: nil)
        let item = try await finished(list)
        XCTAssertTrue(list.undos.isEmpty, "nothing to put back before the confirm")
        await list.confirm(item.id)
        XCTAssertTrue(fake.apps.notes.isEmpty)
        XCTAssertEqual(list.undos.map(\.id), [item.id], "one Undo row")
        let undo = await list.undo(item.id)
        XCTAssertEqual(undo?.end, .done)
        XCTAssertEqual(fake.apps.notes.count, 1, "put back through the Hand")
        XCTAssertTrue(list.undos.isEmpty, "once")

        // Opened: the Undo row goes with it.
        let second = Script([call(#"{"kind":"note","title":"Made-up plan","action":"delete"}"#), .init(text: report)])
        let other = self.list(second)
        _ = other.start("Research a made-up topic and tidy my notes again", packet: nil)
        let next = try await finished(other)
        await other.confirm(next.id)
        XCTAssertEqual(other.undos.map(\.id), [next.id])
        _ = other.open(next.id)
        XCTAssertTrue(other.undos.isEmpty)
    }

    /// R7 with R29: two rows confirmed one at a time can each be put back, the newest first.
    func testEachConfirmedRowCanBeUndone() async throws {
        fake.apps.add("Made-up plan", ["A made-up line"])
        fake.apps.add("Made-up list", ["Another made-up line"])
        let script = Script([call(#"{"kind":"note","title":"Made-up plan","action":"delete"}"#),
                             call(#"{"kind":"note","title":"Made-up list","action":"delete"}"#, id: "toolu_2"), .init(text: report)])
        let list = list(script)
        _ = list.start("Research a made-up topic and tidy my notes", packet: nil)
        let item = try await finished(list)
        for wait in item.waits { await list.confirm(item.id, only: wait.id) }
        XCTAssertTrue(fake.apps.notes.isEmpty)
        XCTAssertEqual(list.undos.map(\.id), [item.id], "one Undo row for the task")
        XCTAssertEqual(list.items.first?.undo.count, 2)
        _ = await list.undo(item.id)
        XCTAssertEqual(fake.apps.notes.map(\.name), ["Made-up list"], "the newest first")
        _ = await list.undo(item.id)
        XCTAssertEqual(Set(fake.apps.notes.map(\.name)), ["Made-up plan", "Made-up list"])
        XCTAssertTrue(list.undos.isEmpty)
    }

    /// R8: a task asking for depth runs at the deep size (no ceiling here), and the menu's line says so.
    func testADeepTaskShowsItsSizeInTheMenu() async throws {
        let script = Script([.init(text: report)])
        let list = list(script)
        _ = list.start("Do a deep research on a made-up topic", packet: nil)
        let item = try await finished(list)
        XCTAssertTrue(item.deep)
        XCTAssertTrue(item.line.hasPrefix("Deep task."), item.line)
        XCTAssertTrue(try XCTUnwrap(script.requests.first).serverTools.first?.contains(#""max_uses":15"#) == true)
        _ = list.start("Research a made-up topic", packet: nil)
        try await waitUntil { list.items.last?.state != .running }
        XCTAssertEqual(list.items.last?.deep, false)
        XCTAssertFalse(try XCTUnwrap(list.items.last).line.contains("Deep"))
    }

    /// R29: the confirm row says what the change writes, not only which item it touches.
    func testTheConfirmRowShowsWhatTheChangeWrites() {
        XCTAssertEqual(TaskList.asks(.noteBody(title: "Made-up ideas", body: "\n  Made-up first line  \nA second line")),
                       "Waiting for you: Rewrite the note “Made-up ideas” with “Made-up first line …”?")
        XCTAssertEqual(TaskList.asks(.noteBody(title: "Made-up ideas", body: "Made-up only line")),
                       "Waiting for you: Rewrite the note “Made-up ideas” with “Made-up only line”?")
        let long = String(repeating: "made-up ", count: 20)
        XCTAssertEqual(TaskList.asks(.noteBody(title: "Made-up ideas", body: long)),
                       "Waiting for you: Rewrite the note “Made-up ideas” with “\(long.prefix(60))…”?")
        XCTAssertEqual(TaskList.asks(.noteBody(title: "Made-up ideas", body: " \n ")), "Waiting for you: Empty the note “Made-up ideas”?")
        let start = Date(timeIntervalSince1970: 1_800_000_000), end = start + 3600
        let when = start.formatted(date: .abbreviated, time: .shortened)
        XCTAssertEqual(TaskList.asks(.move(title: "Made-up call", start: start, end: nil)),
                       "Waiting for you: Move the event “Made-up call” to \(when)?")
        XCTAssertEqual(TaskList.asks(.move(title: "Made-up call", start: start, end: end)),
                       "Waiting for you: Move the event “Made-up call” to \(when) until \(end.formatted(date: .abbreviated, time: .shortened))?")
    }

    func testDismissDropsTheWaitingAction() async throws {
        fake.apps.add("Made-up plan")
        let script = Script([call(#"{"kind":"note","title":"Made-up plan","action":"delete"}"#), .init(text: report)])
        let list = list(script)
        _ = list.start("Research a made-up topic", packet: nil)
        let item = try await finished(list)
        XCTAssertEqual(list.confirms.count, 1)
        list.dismiss(item.id, only: item.waits[0].id)
        XCTAssertTrue(list.confirms.isEmpty)
        XCTAssertEqual(fake.changed, [])
        XCTAssertEqual(fake.apps.notes.count, 1)
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
