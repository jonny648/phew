import XCTest
@testable import Phew

/// PS.11, the conversation card (docs/03-experience.md 3.10): the thread's limits, the secrets filter on the whole
/// history, forgetting on close, and the card's model and placement without a window on screen. Made-up data only.
final class ConversationTests: XCTestCase {
    typealias FakeProvider = BrainAgentsTests.FakeProvider
    typealias Reply = FakeProvider.Reply

    private func packet(_ text: String) -> ContextPacket {
        ContextPacket(appName: "Notes", bundleID: "com.apple.Notes", windowTitle: "Made up", visibleText: text,
                      cursor: nil, windowFrame: CGRect(x: 0, y: 0, width: 800, height: 600), pointables: [])
    }

    // MARK: The secrets filter on the whole history

    func testEveryEarlierTurnIsFilteredAgainBeforeAFollowUp() async throws {
        let key = "sk-" + "ant-api03-" + String(repeating: "Qm4x", count: 10)  // made up, built from pieces
        let fake = FakeProvider(rounds: ["guide": [Reply(pieces: [#"{"explanation":"Fine.","steps":[]}"#])]])
        let brain = ClaudeBrain(provider: fake)
        // Kept turns as if a key had slipped in, in a question and in an answer.
        brain.memory.add(Turn(question: "Question: is \(key) my key?", answer: "It looks like one."))
        brain.memory.add(Turn(question: "Question: and now?", answer: "You pasted \(key) again."))
        for try await _ in brain.answer("What next?", packet: packet("Made-up screen")) {}

        let followUp = try XCTUnwrap(fake.requests.last { $0.agent == "guide" })
        XCTAssertEqual(followUp.earlier.count, 2)
        let history = followUp.earlier.map { $0.question + $0.answer }.joined()
        XCTAssertFalse(history.contains(key))
        XCTAssertEqual(history.components(separatedBy: SecretsFilter.keyMarker).count - 1, 2)
        // On the wire too: nothing of the key leaves the Mac.
        let body = try XCTUnwrap(ClaudeProvider.urlRequest(followUp, key: "k").httpBody)
        XCTAssertFalse(String(decoding: body, as: UTF8.self).contains(key))
    }

    func testAConversationOfNineTurnsSendsOnlyTheLastEight() async throws {
        let answers = (1...9).map { Reply(pieces: [#"{"explanation":"Answer \#($0).","steps":[]}"#]) }
        let fake = FakeProvider(rounds: ["guide": answers])
        let brain = ClaudeBrain(provider: fake)
        for n in 1...9 { for try await _ in brain.answer("Made-up question \(n)?", packet: packet("Screen \(n)")) {} }
        let last = try XCTUnwrap(fake.requests.last { $0.agent == "guide" })
        XCTAssertEqual(last.earlier.map(\.question), (1...8).map { "Question: Made-up question \($0)?" })
        XCTAssertEqual(brain.memory.turns.count, 8)
        XCTAssertEqual(brain.memory.turns.first?.question, "Question: Made-up question 2?")
    }

    // MARK: Closing forgets

    final class ForgetCounter: Brain, @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0
        var forgets: Int { lock.withLock { count } }
        func answer(_ question: String, packet: ContextPacket?) -> AsyncThrowingStream<BrainEvent, Error> {
            AsyncThrowingStream { $0.finish() }
        }
        func progress(steps: [GuideStep], current: Int, packet: ContextPacket?) async throws -> GuideProgress {
            GuideProgress(current: current)
        }
        func forgetTurns() { lock.withLock { count += 1 } }
    }

    @MainActor
    func testClosingTheCardForgetsTheConversation() {
        let card = TextCard()
        let brain = ForgetCounter()
        card.brain = brain
        card.model.begin("Made-up question")
        card.model.draft = "a made-up reply"
        card.dismiss()  // what Escape, the close control, the shortcut and the 10-minute end call
        XCTAssertEqual(brain.forgets, 1)
    }

    func testTheConversationEndsAfterTenMinutes() {
        XCTAssertEqual(TextCard.idleLimit, 10 * 60)
        XCTAssertEqual(WorkingMemory.lifetime, TextCard.idleLimit)  // the card and the Brain end together
        XCTAssertEqual(CardModel.keptTurns, WorkingMemory.maxTurns)
    }

    // MARK: The card's model

    func testAReplyMovesTheTurnUpIntoTheThread() {
        let model = CardModel()
        model.begin("")
        XCTAssertTrue(model.history.isEmpty)  // the first question has nothing before it
        model.apply(.text("Made-up answer."))
        model.apply(.steps([GuideStep(instruction: "Click Made-up", target: nil)]))
        model.begin("And then?")
        XCTAssertEqual(model.history, [CardModel.Exchange(question: "", answer: "Made-up answer.", steps: ["Click Made-up"])])
        XCTAssertEqual(model.question, "And then?")
        XCTAssertTrue(model.thinking)
        XCTAssertTrue(model.text.isEmpty && model.steps.isEmpty && model.problem == nil)
    }

    func testTheThreadShowsAtMostEightTurns() {
        let model = CardModel()
        for n in 1...10 { model.begin("q\(n)"); model.apply(.text("a\(n)")) }
        XCTAssertEqual(model.history.map(\.question), (3...9).map { "q\($0)" })  // 7 earlier + the one on the card
        XCTAssertEqual(model.question, "q10")
    }

    func testResetDropsTheWholeThread() {
        let model = CardModel()
        model.begin("q1"); model.apply(.text("a1")); model.begin("q2")
        model.open = true; model.draft = "made-up draft"; model.queued = true
        model.reset()
        XCTAssertTrue(model.history.isEmpty && model.question.isEmpty && model.draft.isEmpty)
        XCTAssertFalse(model.open || model.queued)
        model.begin("fresh")
        XCTAssertTrue(model.history.isEmpty)  // the next call starts a fresh card
    }

    // MARK: Moving aside from the pointer's spot

    func testTheCardMovesAsideFromTheSpotItCovers() {
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 875)
        let card = CGRect(x: 600, y: 300, width: 400, height: 300)
        // Not covering: stays.
        XCTAssertNil(TextCard.aside(of: card, from: CGRect(x: 100, y: 100, width: 50, height: 20), in: visible))
        // An element under the card: the card goes to its left, at the same height.
        let element = CGRect(x: 700, y: 400, width: 80, height: 24)
        let moved = try? XCTUnwrap(TextCard.aside(of: card, from: element, in: visible))
        XCTAssertEqual(moved, CGPoint(x: 700 - 24 - 400, y: 300))
        // A point ring near the left edge: no room on the left, so to its right.
        let ring = CGRect(x: 120, y: 400, width: 0, height: 0)
        let left = CGRect(x: 20, y: 300, width: 400, height: 300)
        XCTAssertEqual(TextCard.aside(of: left, from: ring, in: visible), CGPoint(x: 144, y: 300))
        // Whatever it picks stays on screen and clear of the spot.
        for target in [element, ring] {
            for start in [card, left] {
                guard let origin = TextCard.aside(of: start, from: target, in: visible) else { continue }
                let placed = CGRect(origin: origin, size: start.size)
                XCTAssertTrue(visible.contains(placed))
                XCTAssertFalse(placed.intersects(target.insetBy(dx: -23, dy: -23)))
            }
        }
    }
}
