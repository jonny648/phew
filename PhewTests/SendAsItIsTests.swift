import XCTest
@testable import Phew

/// D7 "Send as it is": the user's own words past the secrets filter, for one message, after the user's own press.
/// Made-up keys, a made-up screen, a throwaway Map, a fake provider: no network, no screen read.
final class SendAsItIsTests: XCTestCase {
    typealias FakeProvider = BrainAgentsTests.FakeProvider
    typealias Reply = FakeProvider.Reply

    static let key = "sk-ant-madeUpQuestionKey000000000000000"
    static let screenKey = "sk-ant-madeUpScreenKey1111111111111111"
    static let question = "Why is this test key \(key) rejected?"

    /// As Senses hands it on: filtered.
    private func packet() -> ContextPacket {
        ContextPacket(appName: "Made Up Editor", bundleID: "com.example.madeup-editor", windowTitle: "Untitled",
                      visibleText: "API_KEY=\(Self.screenKey)", cursor: nil).filtered()
    }

    private func fake() -> FakeProvider {
        FakeProvider(rounds: [
            "conductor": [Reply(pieces: [#"{"route":"explain"}"#])],
            "guide": [Reply(pieces: [#"{"explanation":"The key looks cut short.","steps":[]}"#])],
            "librarian": [Reply(pieces: [Made.reply(summary: "Asked why a key was rejected.")])],
        ])
    }

    /// Everything a request carries as text: system, cached part, user turn, earlier turns, tool rounds.
    private func all(_ request: ModelRequest) -> String {
        ([request.system, request.cached ?? "", request.text] + request.earlier.flatMap { [$0.question, $0.answer] }
            + request.after.map { String(decoding: $0.content, as: UTF8.self) }).joined(separator: "\n")
    }

    private func run(_ stream: AsyncThrowingStream<BrainEvent, Error>) async throws {
        for try await _ in stream {}
    }

    func testPressedTheQuestionGoesUnfilteredAndEverythingElseStaysFiltered() async throws {
        let store = try MapStore()
        let fake = fake()
        let brain = ClaudeBrain(provider: fake, map: BrainMap(open: { store }, maintenance: false))
        try await run(brain.answerAsItIs(Self.question, packet: packet(), state: ShellState()))
        _ = await brain.map.ready()  // the Librarian's run has ended

        let guide = try XCTUnwrap(fake.requests.first { $0.agent == "guide" })
        XCTAssertTrue(guide.text.contains("Question: \(Self.question)"), "the user's own words, as typed")
        XCTAssertFalse(all(guide).contains(Self.screenKey), "the screen text still filtered")
        XCTAssertTrue(guide.text.contains(SecretsFilter.keyMarker))
        // Only the Guide: the Conductor, the Librarian (the Map write), the turn kept and calls.log hold none of it.
        for request in fake.requests where request.agent != "guide" {
            XCTAssertFalse(all(request).contains(Self.key), request.agent)
        }
        XCTAssertTrue(fake.requests.contains { $0.agent == "librarian" })
        XCTAssertFalse(brain.memory.turns.contains { $0.question.contains(Self.key) || $0.answer.contains(Self.key) })
        XCTAssertTrue(brain.memory.turns.last?.question.contains(SecretsFilter.keyMarker) == true)
        let map = await brain.exportMap(includeSensitive: true) ?? ""
        XCTAssertFalse(map.contains(Self.key))
        let line = CallLog.line(guide, usage: Usage(input: 10, output: 5), msFirst: 1, msTotal: 2, stop: "end_turn", error: nil)
        XCTAssertFalse(String(decoding: CallLog.encode(line), as: UTF8.self).contains(Self.key))
    }

    func testALaterQuestionIsFilteredAgain() async throws {
        let fake = fake()
        let brain = ClaudeBrain(provider: fake, map: BrainMap(open: { throw MapError.underTests }, maintenance: false))
        try await run(brain.answerAsItIs(Self.question, packet: packet(), state: ShellState()))
        try await run(brain.answer("And now? \(Self.key)", packet: packet(), state: ShellState()))
        let guides = fake.requests.filter { $0.agent == "guide" }
        XCTAssertEqual(guides.count, 2)
        XCTAssertTrue(guides[0].text.contains(Self.key))
        XCTAssertFalse(all(guides[1]).contains(Self.key), "nothing remembered: the next message, and the turn before it, filtered")
    }

    func testAPlainAnswerNeverSendsTheKey() async throws {
        let fake = fake()
        let brain = ClaudeBrain(provider: fake, map: BrainMap(open: { throw MapError.underTests }, maintenance: false))
        try await run(brain.answer(Self.question, packet: packet(), state: ShellState()))
        XCTAssertFalse(fake.requests.contains { all($0).contains(Self.key) })
    }

    // MARK: The card

    /// Records which door each question came through, and answers on `route`.
    final class Recorder: Brain, @unchecked Sendable {
        private let lock = NSLock()
        private var log: [(question: String, asItIs: Bool)] = []
        let route: Route
        init(route: Route = .explain) { self.route = route }
        var asked: [(question: String, asItIs: Bool)] { lock.withLock { log } }
        private func reply(_ question: String, asItIs: Bool) -> AsyncThrowingStream<BrainEvent, Error> {
            lock.withLock { log.append((question, asItIs)) }
            let route = route
            return AsyncThrowingStream { $0.yield(.route(route)); $0.yield(.text("Made-up answer.")); $0.yield(.done); $0.finish() }
        }
        func answer(_ question: String, packet: ContextPacket?) -> AsyncThrowingStream<BrainEvent, Error> { reply(question, asItIs: false) }
        func answerAsItIs(_ question: String, packet: ContextPacket?, state: ShellState) -> AsyncThrowingStream<BrainEvent, Error> {
            reply(question, asItIs: true)
        }
        func progress(steps: [GuideStep], current: Int, packet: ContextPacket?) async throws -> GuideProgress { GuideProgress(current: current) }
    }

    @MainActor
    private func turn(_ card: TextCard, _ question: String) async throws {
        card.answer(question, capture: Task { self.packet() })
        try await finished(card)
    }

    @MainActor
    private func finished(_ card: TextCard) async throws {
        for _ in 0..<200 where card.answering { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(card.answering)
    }

    @MainActor
    func testTheLineShowsOnlyWhenTheFilterChangedTheQuestion() async throws {
        let card = TextCard(), brain = Recorder()
        card.brain = brain
        try await turn(card, "What does this button do?")
        XCTAssertFalse(card.model.leftOut, "nothing removed: no line")
        card.sendAsItIs { Task { nil } }
        XCTAssertEqual(brain.asked.count, 1, "no line, no press")
        try await turn(card, Self.question)
        XCTAssertTrue(card.model.leftOut)
        card.dismiss()
    }

    @MainActor
    func testTheLineIsNotOfferedForAJobATaskOrAMemory() async throws {
        for route in [Route.task, .remember] {
            let card = TextCard()
            card.brain = Recorder(route: route)
            card.onTask = { _, _, _ in "" }
            try await turn(card, Self.question)
            XCTAssertFalse(card.model.leftOut, "\(route)")
            card.dismiss()
        }
    }

    @MainActor
    func testPressingSendsThatQuestionOnceAsItIsAndTheNextIsFilteredAgain() async throws {
        let card = TextCard(), brain = Recorder()
        card.brain = brain
        try await turn(card, Self.question)
        card.sendAsItIs { Task { self.packet() } }
        try await finished(card)
        XCTAssertEqual(brain.asked.map(\.asItIs), [false, true])
        XCTAssertEqual(brain.asked.last?.question, Self.question)
        XCTAssertFalse(card.model.leftOut, "after a send as it is, no second offer")
        card.sendAsItIs { Task { nil } }
        XCTAssertEqual(brain.asked.count, 2)
        try await turn(card, "And this \(Self.key)?")
        XCTAssertEqual(brain.asked.last?.asItIs, false, "a later question goes the filtered way")
        XCTAssertTrue(card.model.leftOut)
        card.model.begin("next")
        XCTAssertFalse(card.model.leftOut, "gone with the turn")
        card.dismiss()
    }
}
