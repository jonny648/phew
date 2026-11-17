import XCTest
@testable import Phew

/// N4.5: several actions planned in one call, each carried out through the real Hand on a fake surface and checked by
/// the guards that exist. A scripted provider and made-up controls; no network, no real app.
@MainActor
final class PlanTests: XCTestCase {
    typealias FakeProvider = BrainAgentsTests.FakeProvider
    private var suite = ""
    private var defaults: UserDefaults!
    private var fake: FakeSurface!
    private var savedLog: URL!
    private var log: URL!
    private let names = ["One", "Two", "Three", "Four", "Five"]

    override func setUp() {
        suite = "PhewTests.plan.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.set(true, forKey: Hand.allowedKey)
        fake = FakeSurface()
        for (i, name) in names.enumerated() { _ = fake.add(name, frame: frame(i)) }
        _ = fake.add("Delete", frame: frame(5))
        savedLog = ActionLog.url
        log = FileManager.default.temporaryDirectory.appending(path: "phew-actions-\(UUID().uuidString).log")
        ActionLog.url = log  // never the user's real actions.log
    }

    override func tearDown() {
        ActionLog.flush()
        try? FileManager.default.removeItem(at: log)
        ActionLog.url = savedLog
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }

    private func frame(_ i: Int) -> CGRect { CGRect(x: 20 + i * 110, y: 20, width: 100, height: 30) }

    /// The window after `k` actions: the same controls, and a made-up line saying how far it got.
    private func look(_ k: Int) -> ContextPacket {
        ContextPacket(appName: "Practice", bundleID: "com.example.practice", windowTitle: "Practice",
                      visibleText: k == 0 ? "Made up" : "Made up after \(k)", cursor: nil,
                      pointables: (names + ["Delete"]).enumerated().map { Pointable(id: "e\($0.offset + 1)", role: "AXButton", label: $0.element, frame: frame($0.offset)) })
    }

    private func item(_ action: String, element: String? = nil, keys: String? = nil, title: String? = nil, expect: String?) -> String {
        func q(_ s: String?) -> String { s.map { "\"\($0)\"" } ?? "null" }
        return #"{"action":"\#(action)","element":\#(q(element)),"point":null,"menu":[],"text":"","title":\#(q(title)),"keys":\#(q(keys)),"expect":\#(q(expect))}"#
    }

    private func plan(_ items: [String]) -> String { #"{"actions":[\#(items.joined(separator: ","))]}"# }

    private func hand() -> Hand { Hand(defaults: defaults, surface: fake, list: NeverReadList(defaults: defaults)) }

    /// A job on a ClaudeBrain with its own switches; `looks` are the captures in order, the last one repeating.
    private func run(_ replies: [String], looks: [ContextPacket], batch: Bool? = nil) async -> (ActJob.Outcome, FakeProvider) {
        let provider = FakeProvider(rounds: ["doer": replies.map { FakeProvider.Reply(pieces: [$0]) }])
        if let batch { defaults.set(batch, forKey: CostSwitches.batchKey) }
        var brain = ClaudeBrain(provider: provider)
        brain.switches = CostSwitches(defaults: defaults)
        let hand = hand()
        var taken = 0
        let job = ActJob(brain: brain, hand: hand, capture: { _ in
            defer { taken += 1 }
            return looks[min(taken, looks.count - 1)]
        })
        let made = hand.begin(watchUser: false, in: FakeSurface.pid)
        let outcome = await job.run("Press the five made-up buttons", job: made) { _ in }
        hand.close(made)
        return (outcome, provider)
    }

    private let done = #"{"actions":[{"action":"done","element":null,"point":null,"menu":[],"text":"Done.","expect":null}]}"#

    func testFiveActionsFromOneCall() async {
        let five = plan((1...5).map { item("press", element: "e\($0)", expect: "after \($0)") })
        let (outcome, provider) = await run([five, done], looks: (0...5).map(look))
        XCTAssertEqual(outcome, .done("Done."))
        XCTAssertEqual(fake.sent.map(\.name), names, "five actions, in order")
        XCTAssertEqual(provider.requests.count, 2, "one call for five actions, one to see it done")
        XCTAssertEqual(provider.requests[0].system, Doer.batchSystem)
        XCTAssertEqual(provider.requests[0].schema, Doer.batchSchema)
        XCTAssertTrue(provider.requests[1].text.contains("5. Pressed Five: done"))
    }

    /// What the first action should show is not there, or was there already: the second step is never carried out,
    /// and the model is asked again on the fresh look.
    func testAStalePlanAsksAgainAndNeverActsTheStaleStep() async {
        let two = plan([item("press", element: "e1", expect: "after 1"), item("press", element: "e2", expect: "after 2")])
        for looks in [[look(0), look(0)], [look(1), look(1)]] {
            fake = FakeSurface()
            for (i, name) in names.enumerated() { _ = fake.add(name, frame: frame(i)) }
            let (outcome, provider) = await run([two, done], looks: looks)
            XCTAssertEqual(outcome, .done("Done."))
            XCTAssertEqual(fake.sent.map(\.name), ["One"], "the stale step is never sent")
            XCTAssertEqual(provider.requests.count, 2, "asked again")
            XCTAssertTrue(provider.requests[1].text.contains("<actions>\n1. Pressed One: done\n</actions>"))
        }
    }

    /// Nothing goes past an action that cannot be undone, even when its expectation is met.
    func testThePlanEndsAtAnIrreversibleAction() async {
        let two = plan([item("press", element: "e6", expect: "after 1"), item("press", element: "e1", expect: "after 2")])
        let (outcome, provider) = await run([two, done], looks: [look(0), look(1), look(2)])
        XCTAssertEqual(outcome, .done("Done."))
        XCTAssertEqual(fake.sent.map(\.name), ["Delete"])
        XCTAssertEqual(provider.requests.count, 2)
    }

    /// Keys and a switch of app end the plan in code; so does an action with nothing to check.
    func testThePlanEndsAtKeysAtASwitchOfAppAndWithNothingToCheck() throws {
        let saved = Doer.installed
        defer { Doer.installed = saved }
        Doer.installed = { $0 == "Mail" ? [(name: "Mail", bundleID: "com.apple.mail")] : [] }
        func planned(_ items: [String]) throws -> [PlannedAction] {
            let outputs = try JSONDecoder().decode(Doer.Batch.self, from: Data(plan(items).utf8)).actions
            return Doer.planned(outputs, packet: look(0), shot: nil)
        }
        let press = item("press", element: "e2", expect: "after 2")
        XCTAssertEqual(try planned([item("keys", keys: "cmd+b", expect: "after 1"), press]).map(\.action),
                       [.input(.keys, keys: HandChord.parse("cmd+b"))])
        XCTAssertEqual(try planned([item("open_app", title: "Mail", expect: "after 1"), press]).map(\.action),
                       [.front(bundleID: "com.apple.mail", name: "Mail")])
        XCTAssertEqual(try planned([item("press", element: "e1", expect: nil), press]).count, 1)
        // Done or stuck only first; a target code drops ends the plan before it; never more than five.
        XCTAssertEqual(try planned([item("press", element: "e1", expect: "after 1"), item("done", expect: nil)]).count, 1)
        XCTAssertEqual(try planned([item("press", element: "e1", expect: "after 1"), item("press", element: "e99", expect: "x")]).count, 1)
        XCTAssertEqual(try planned((1...7).map { _ in item("press", element: "e1", expect: "after") }).count, Doer.mostPlanned)
    }

    /// The hidden switch off: today's request, one action a call.
    func testTheSwitchOffGivesTodaysRequest() async {
        let one = item("press", element: "e1", expect: nil)
        let (outcome, provider) = await run([one, #"{"action":"done","element":null,"point":null,"menu":[],"text":"Done."}"#],
                                            looks: [look(0), look(1)], batch: false)
        XCTAssertEqual(outcome, .done("Done."))
        XCTAssertEqual(fake.sent.map(\.name), ["One"])
        let first = provider.requests[0]
        XCTAssertEqual(first.system, Doer.system)
        XCTAssertEqual(first.schema, Doer.schema)
        XCTAssertEqual(first.maxTokens, 2048)
        XCTAssertTrue(Doer.system.contains(Doer.singleLine) && !Doer.batchSystem.contains(Doer.singleLine))
        XCTAssertTrue(Doer.batchSystem.contains("Reply in actions with the next actions"))
        XCTAssertTrue(CostSwitches(defaults: UserDefaults(suiteName: "PhewTests.plan.none.\(UUID().uuidString)")!).batch, "on by default")
    }
}
