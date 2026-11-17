import XCTest
@testable import Phew

/// Phase N4, cost down: what code now decides without a model call, and the switches. Made-up packets and a scripted
/// provider; no network.
final class CostDownTests: XCTestCase {
    typealias FakeProvider = BrainAgentsTests.FakeProvider

    // MARK: N4.4: a click step checked by code

    private let steps = [GuideStep(instruction: "Click Format", target: .element("e1"), click: true),
                         GuideStep(instruction: "Click Bold in the menu", target: nil, click: true),
                         GuideStep(instruction: "Type the made-up title", target: nil)]

    private func screen(_ labels: [String]) -> ContextPacket {
        ContextPacket(appName: "Practice", bundleID: "com.example.practice", windowTitle: "Made-up page", visibleText: "Made-up words",
                      cursor: nil, windowFrame: CGRect(x: 0, y: 0, width: 800, height: 600),
                      pointables: labels.enumerated().map { Pointable(id: "e\($0.offset + 1)", role: "AXButton", label: $0.element,
                                                                    frame: CGRect(x: 10 + $0.offset * 70, y: 10, width: 60, height: 20)) })
    }

    private let follower = #"{"step":2,"element":null,"point":null}"#

    /// The menu item the next step names has appeared since the hit: confirmed by code, pointed at, no call.
    func testAClickStepIsConfirmedByCodeWhenTheNextControlAppears() async throws {
        let fake = FakeProvider(["follower": [follower]])
        let before = try XCTUnwrap(screen(["Format", "Insert"]).controlLabels)
        let result = try await ClaudeBrain(provider: fake).progress(steps: steps, current: 0, packet: screen(["Format", "Insert", "Italic", "Bold"]),
                                                                    before: before)
        XCTAssertEqual(result, GuideProgress(current: 1, target: .element("e4")))
        XCTAssertTrue(fake.requests.isEmpty, "no model call")
    }

    /// Anything unclear goes to the model as before.
    func testAnythingUnclearStillGoesToTheModel() async throws {
        let brain = { (fake: FakeProvider) in ClaudeBrain(provider: fake) }
        func calls(_ steps: [GuideStep], current: Int = 0, before: [String]?, now: [String], neverRead: Bool = false) async throws -> Int {
            let fake = FakeProvider(["follower": [follower]])
            var packet = screen(now)
            packet.neverRead = neverRead
            _ = try await brain(fake).progress(steps: steps, current: current, packet: packet, before: before.flatMap { screen($0).controlLabels })
            return fake.requests.count
        }
        var typing = steps
        typing[0].click = false
        let cases: [(steps: [GuideStep], current: Int, before: [String]?, now: [String], neverRead: Bool, why: String)] = [
            (steps, 0, ["Format", "Bold"], ["Format", "Bold"], false, "the control was there before the hit"),
            (steps, 0, ["Format"], ["Format", "Bold", "Bold"], false, "two controls of that name"),
            (steps, 0, ["Format"], ["Format", "Bold", "Menu"], false, "the next step names two new controls"),
            (steps, 0, ["Format"], ["Format"], false, "nothing has appeared"),
            (steps, 0, ["Format"], ["Format", "Bolder"], false, "a label only part of a word"),
            (steps, 0, nil, ["Format", "Bold"], false, "no direct hit"),
            (steps, 0, ["Format"], ["Format", "Bold"], true, "an app never read"),
            (typing, 0, ["Format"], ["Format", "Bold"], false, "a step that is not click-only"),
            (Array(steps.prefix(2)), 1, ["Format"], ["Format", "Done"], false, "the last step"),
        ]
        for c in cases {
            let n = try await calls(c.steps, current: c.current, before: c.before, now: c.now, neverRead: c.neverRead)
            XCTAssertEqual(n, 1, c.why)
        }
        // A list cut at the cap cannot say a control was absent.
        XCTAssertNil(screen(Array(repeating: "Made-up", count: ContextPacket.pointableCap)).controlLabels)
        // The same check with the control new and alone: no call.
        let alone = try await calls(steps, before: ["Format"], now: ["Format", "BOLD "])
        XCTAssertEqual(alone, 0)
    }
}
