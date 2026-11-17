import AppKit
import XCTest
@testable import Phew

/// NA.15 and NA.16 offline: the watcher for one thing on a fake surface, and "Notify me" through a fake poster.
/// Made-up apps and texts; no real app is read, no real notification is posted, no model is called.
@MainActor
final class WatcherTests: XCTestCase {
    /// One made-up control: its text at the start, then whatever `now` holds. Counts its reads.
    final class FakeWatch: WatchSurface {
        var pids = ["com.example.Exporter": pid_t(4242), "com.example.Slides": 4243, "com.1password.1password": 4244]
        var start: WatchTarget? = WatchTarget(text: "Exporting 10%")
        var now: String? = "Exporting 10%"
        var secure = false
        var reads = 0
        func pid(of bundleID: String) -> pid_t? { pids[bundleID] }
        func target(at point: CGPoint, pid: pid_t) -> WatchTarget? { start }
        func read(_ target: WatchTarget) -> String? { reads += 1; return now }
        func secureInput() -> Bool { secure }
    }

    final class FakePoster: NoticePoster {
        var allowed = true
        var asked = 0
        var posted: [String] = []
        func allow() async -> Bool { asked += 1; return allowed }
        func post(title: String, line: String) { posted.append("\(title)|\(line)") }
    }

    private var suite = ""
    private var defaults: UserDefaults!
    private var list: NeverReadList!
    private var fake: FakeWatch!
    private var poster: FakePoster!
    private var notices: Notices!
    private var root: URL!
    private var saved: (copies: URL, calls: URL, actions: URL)!
    private let logged = TaskTests.Lines()

    override func setUp() async throws {
        suite = "PhewTests.watcher.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        list = NeverReadList(defaults: defaults)
        fake = FakeWatch()
        poster = FakePoster()
        root = FileManager.default.temporaryDirectory.appending(path: "WatcherTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        saved = (Report.copies, CallLog.url, ActionLog.url)
        Report.copies = root.appending(path: "reports")
        CallLog.url = root.appending(path: "calls.log")  // never the user's real logs
        ActionLog.url = root.appending(path: "actions.log")
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

    private func make(watch: Bool = true, notify: Bool = true) -> (Watching, Watcher) {
        defaults.set(watch, forKey: Watching.key)
        defaults.set(notify, forKey: Notices.key)
        let watcher = Watcher(surface: fake, list: list, ownPID: getpid(), ticks: false)
        notices = Notices(defaults: defaults, poster: poster)
        return (Watching(watcher: watcher, notices: notices, defaults: defaults), watcher)
    }

    private func packet(_ app: String = "Exporter", _ bundleID: String = "com.example.Exporter") -> ContextPacket {
        ContextPacket(appName: app, bundleID: bundleID, windowTitle: "Made-up export", visibleText: "", cursor: nil,
                      mouse: CGPoint(x: 200, y: 300))
    }

    private let watched = "What you asked me to watch has changed. In Exporter."

    // MARK: Off until switched on

    func testWithTheSwitchesOffNothingIsPostedAndAWatchIsRefusedInOneLine() {
        let (watching, watcher) = make(watch: false, notify: false)
        XCTAssertEqual(watching.start(packet()), Watching.off)
        XCTAssertTrue(Watching.off.contains("Let Phew watch one thing"), "it says where to turn it on")
        XCTAssertNil(watcher.watch)
        XCTAssertEqual(fake.reads, 0)
        notices.task("Research made-up fonts", ended: .ready)
        notices.watcherFired(app: "Exporter")
        XCTAssertEqual(poster.posted, [], "with the switch off nothing is ever posted")
        XCTAssertEqual(poster.asked, 0)
    }

    func testTurningNotificationsOnAsksTheSystemAndARefusalTurnsThemOff() async {
        _ = make(notify: false)
        poster.allowed = false
        await notices.set(true)
        XCTAssertFalse(notices.on, "refused: the switch goes back off")
        XCTAssertTrue(notices.refused)
        poster.allowed = true
        await notices.set(true)
        XCTAssertTrue(notices.on)
        XCTAssertFalse(notices.refused)
        XCTAssertEqual(poster.asked, 2)
        await notices.set(false)
        XCTAssertFalse(notices.on)
        XCTAssertEqual(poster.asked, 2, "turning off asks nothing")
    }

    // MARK: What a task's notification holds

    func testATasksNotificationHoldsOnlyItsTitleAndHowItEnded() {
        XCTAssertEqual(Notices.line(task: "Research made-up fonts", ended: .ready), "Research made-up fonts: done")
        XCTAssertEqual(Notices.line(task: "Research made-up fonts", ended: .failed(.limited(.minute))), "Research made-up fonts: stopped at a limit")
        XCTAssertEqual(Notices.line(task: "Research made-up fonts", ended: .failed(.network)), "Research made-up fonts: failed")
        XCTAssertNil(Notices.line(task: "Research made-up fonts", ended: .stopped), "the user stopped it: nothing")
        let long = String(repeating: "x", count: 120)
        XCTAssertEqual(Notices.line(task: long, ended: .ready), String(repeating: "x", count: 80) + ": done", "cut to 80 characters")
    }

    func testAFinishedTaskPostsItsTitleLineAndAStoppedOneNothing() async throws {
        _ = make()
        let report = "# Made-up topic\n\nA short made-up answer about Quillmarrow."
        let hand = Hand(defaults: defaults, surface: FakeSurface(), list: list)
        let folder = root!
        let tasks = TaskList(brain: ClaudeBrain(provider: RunnerTests.Script([.init(text: report)]), tools: RunnerTests.FakeMap(out: "")),
                             hand: hand, folder: { folder })
        let notices = notices!
        tasks.onEnd = { notices.task($0.title, ended: $0.state) }
        _ = tasks.start("Research a made-up topic about kerning", packet: nil)
        let end = Date() + 5
        while tasks.items.first?.state == .running && Date() < end { try await Task.sleep(for: .milliseconds(20)) }
        let item = try XCTUnwrap(tasks.items.first)
        XCTAssertEqual(item.state, .ready)
        XCTAssertEqual(poster.posted, ["Phew|\(item.title): done"])
        XCTAssertFalse(poster.posted[0].contains("Quillmarrow"), "no report text")

        let hanging = TaskTests.Hanging()
        let stopping = TaskList(brain: ClaudeBrain(provider: hanging, tools: RunnerTests.FakeMap(out: "")), hand: hand, folder: { folder })
        stopping.onEnd = { notices.task($0.title, ended: $0.state) }
        _ = stopping.start("Another made-up task", packet: nil)
        stopping.stop(try XCTUnwrap(stopping.items.first).id)
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(poster.posted.count, 1, "a task the user stopped posts nothing")
    }

    // MARK: The watcher fires once

    func testItFiresOnceOnAChange() {
        let (watching, watcher) = make()
        XCTAssertEqual(watching.start(packet()), Watching.started)
        XCTAssertEqual(watching.app, "Exporter", "the Stop row")
        let t = Date()
        XCTAssertNil(watcher.check(at: t + 5), "unchanged: it goes on")
        XCTAssertNil(watcher.check(at: t + 10))
        fake.now = "Export done"
        XCTAssertEqual(watcher.check(at: t + 15), .changed(before: "Exporting 10%", now: "Export done"))
        XCTAssertNil(watcher.check(at: t + 20), "it stopped: it fires once only")
        XCTAssertNil(watcher.watch)
        XCTAssertNil(watching.app)
        XCTAssertEqual(fake.reads, 3)
        XCTAssertEqual(poster.posted, ["Phew|\(watched)"])
        let result = try? XCTUnwrap(watching.result)
        XCTAssertEqual(result?.row, "What you watched in Exporter changed")
        XCTAssertTrue(result?.text.contains("Exporting 10%") == true && result?.text.contains("Export done") == true, "the card shows both")
        XCTAssertEqual(watching.open(), result)
        XCTAssertNil(watching.result, "opened: it leaves the menu")
    }

    func testItFiresWhenTheControlIsGone() {
        let (watching, watcher) = make()
        _ = watching.start(packet())
        fake.now = nil
        XCTAssertEqual(watcher.check(at: Date() + 5), .gone(before: "Exporting 10%"))
        XCTAssertEqual(watching.result?.row, "What you watched in Exporter changed")
        XCTAssertEqual(poster.posted, ["Phew|\(watched)"])
    }

    /// The watch route ends the Brain's answer after the Conductor; then the watcher waits and fires with no request.
    func testNoModelRequestIsMadeWhileItWaits() async throws {
        let provider = BrainAgentsTests.FakeProvider(["conductor": [#"{"route":"watch","about_phew":false}"#]])
        var events: [BrainEvent] = []
        for try await event in ClaudeBrain(provider: provider).answer("Tell me when this export is done", packet: packet()) {
            events.append(event)
        }
        XCTAssertEqual(events, [.route(.watch), .done])
        XCTAssertEqual(provider.requests.map(\.agent), ["conductor"], "only the route; the Guide does not answer")
        let (watching, watcher) = make()
        XCTAssertEqual(watching.start(packet()), Watching.started)
        let t = Date()
        for n in 1...100 { XCTAssertNil(watcher.check(at: t + Double(n) * Watcher.interval)) }
        fake.now = "Export done"
        XCTAssertNotNil(watcher.check(at: t + 101 * Watcher.interval))
        XCTAssertEqual(provider.requests.count, 1, "no model request while it waits, nor when it fires")
    }

    // MARK: What ends it

    func testStopTheTwoHoursSleepSecureInputAndANeverReadAppEndIt() async throws {
        let (watching, watcher) = make()
        _ = watching.start(packet())
        watching.stop()
        XCTAssertNil(watcher.watch)
        XCTAssertNil(watching.app)
        XCTAssertNil(watching.result, "Stop leaves no row")

        _ = watching.start(packet())
        let t = Date()
        XCTAssertNil(watcher.check(at: t + Watcher.most - 10))
        XCTAssertEqual(watcher.check(at: t + Watcher.most + 1), .timeUp)
        XCTAssertEqual(watching.result?.row, "Stopped watching in Exporter: two hours passed")

        _ = watching.start(packet())
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.willSleepNotification, object: nil)  // this process only
        let end = Date() + 2
        while watcher.watch != nil && Date() < end { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertNil(watcher.watch, "the Mac sleeps: it ends")
        XCTAssertEqual(watching.result?.row, "Stopped watching in Exporter: the Mac slept or locked")

        _ = watching.start(packet())
        fake.secure = true
        XCTAssertEqual(watcher.check(at: Date() + 5), .secureInput)
        fake.secure = false

        _ = watching.start(packet())
        let reads = fake.reads
        list.add(name: "Exporter", bundleID: "com.example.Exporter")  // the user adds it to Never read
        XCTAssertEqual(watcher.check(at: Date() + 5), .neverRead)
        XCTAssertEqual(fake.reads, reads, "a refused app is not read again")
        XCTAssertEqual(watching.result?.row, "Stopped watching in Exporter: it is never read")
        XCTAssertEqual(poster.posted, [], "none of these fired")
    }

    func testItRefusesASecureFieldAPasswordManagerAndItsOwnWindows() {
        let (watching, watcher) = make()
        fake.start = WatchTarget(text: "", secure: true)
        XCTAssertEqual(watching.start(packet()), Watching.secure)
        fake.start = WatchTarget(text: "Exporting 10%")
        XCTAssertEqual(watching.start(packet("1Password", "com.1password.1password")), Watching.neverRead("1Password"))
        var refused = packet("Notes", "com.apple.Notes")
        refused.neverRead = true
        refused.mouse = nil
        XCTAssertEqual(watching.start(refused), Watching.neverRead("Notes"))
        fake.pids["com.example.Exporter"] = getpid()
        XCTAssertEqual(watching.start(packet()), Watching.ownApp)
        fake.pids["com.example.Exporter"] = 4242
        fake.secure = true
        XCTAssertEqual(watching.start(packet()), Watching.secureInput)
        fake.secure = false
        fake.start = nil
        XCTAssertEqual(watching.start(packet()), Watching.nothing)
        XCTAssertEqual(watching.start(nil), Watching.nothing)
        XCTAssertNil(watcher.watch)
        XCTAssertEqual(fake.reads, 0)
    }

    func testASecondWatchReplacesTheFirstAndSaysSo() {
        let (watching, watcher) = make()
        XCTAssertEqual(watching.start(packet()), Watching.started)
        fake.start = WatchTarget(text: "Slide 3 of 9")
        XCTAssertEqual(watching.start(packet("Slides", "com.example.Slides")), Watching.replaced("Exporter"))
        XCTAssertEqual(watcher.watch?.app, "Slides")
        XCTAssertEqual(watcher.watch?.target.text, "Slide 3 of 9")
        XCTAssertEqual(watching.app, "Slides")
        XCTAssertNil(watching.result, "a replaced watch leaves no row")
        XCTAssertEqual(poster.posted, [])
    }

    // MARK: The watched text stays on the Mac

    func testNothingOfTheWatchedTextIsPostedOrLogged() {
        let (watching, watcher) = make()
        fake.start = WatchTarget(text: "Quillmarrow 42%")
        fake.now = "Quillmarrow 42%"
        _ = watching.start(packet())
        _ = watcher.check(at: Date() + 5)
        fake.now = "Quillmarrow done"
        _ = watcher.check(at: Date() + 10)
        XCTAssertEqual(poster.posted, ["Phew|\(watched)"])
        XCTAssertTrue(logged.all.contains("watcher started, a control"))
        XCTAssertTrue(logged.all.contains("watcher ended: changed"))
        XCTAssertFalse(logged.all.contains { $0.contains("Quillmarrow") }, "no words of the user in the log")
        XCTAssertFalse(poster.posted.contains { $0.contains("Quillmarrow") })
        let calls = (try? String(contentsOf: CallLog.url, encoding: .utf8)) ?? ""
        XCTAssertFalse(calls.contains("Quillmarrow"))
        XCTAssertTrue(calls.isEmpty, "no call at all")
    }

    func testTheWatchRouteInTheConductor() {
        let request = Conductor.request("Avvisami quando cambia", packet: nil)
        XCTAssertTrue(request.schema?.contains(#""watch"]"#) == true)
        XCTAssertTrue(request.system.contains("watch: they ask Phew to tell them later"))
        XCTAssertEqual(Conductor.decode(#"{"route":"Watch"}"#), .watch)
    }
}
