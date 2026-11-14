import XCTest
@testable import Phew

/// The search loop (at most 2 tool calls, then the model must answer) and the working memory for follow-up
/// questions (P5.5). Fake provider, fake tool, made-up content. No network.
final class ToolLoopTests: XCTestCase {
    typealias FakeProvider = BrainAgentsTests.FakeProvider
    typealias Reply = FakeProvider.Reply

    /// Answers every call with `answer` and counts the calls. Never logs or keeps what it was asked.
    final class FakeSearch: ToolRunner, @unchecked Sendable {
        private let lock = NSLock()
        private var made = 0
        let answer: String
        init(answer: String = "Review with Marta (Event, meeting). Starts 20 Nov 15:00.") { self.answer = answer }
        var calls: Int { lock.withLock { made } }
        var tools: [ToolSpec] { [.searchMap] }
        func run(_ name: String, input: Data) async throws -> String {
            lock.withLock { made += 1 }
            return answer
        }
    }

    /// A tool round as the API sends it: an omitted thinking block with its signature, then one search call.
    private func searchRound(_ n: Int) -> Reply {
        Reply(blocks: #"[{"type":"thinking","thinking":"","signature":"sig-\#(n)-EqQBCgIYAh"},{"type":"tool_use","id":"toolu_\#(n)","name":"search_map","input":{"query":"made-up words \#(n)"}}]"#,
              stop: "tool_use")
    }
    private let answer = Reply(pieces: [#"{"explanation":"The review is on 20 Nov.","steps":[]}"#],
                               blocks: #"[{"type":"text","text":"{}"}]"#)

    private func packet(_ text: String, screenshot: Data? = nil) -> ContextPacket {
        ContextPacket(appName: "Calendar", bundleID: "com.apple.iCal", windowTitle: "Week 47", visibleText: text,
                      cursor: nil, windowFrame: CGRect(x: 0, y: 0, width: 800, height: 600), pointables: [], screenshot: screenshot)
    }

    private func events(_ brain: some Brain, _ question: String, _ packet: ContextPacket?) async throws -> [BrainEvent] {
        var all: [BrainEvent] = []
        for try await event in brain.answer(question, packet: packet) { all.append(event) }
        return all
    }

    private func blocks(_ data: Data) throws -> [[String: Any]] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
    }

    // MARK: The loop

    func testSearchesTwiceThenMustAnswerWithBlocksSentBackUnchanged() async throws {
        let fake = FakeProvider(rounds: ["conductor": [Reply(pieces: [#"{"route":"explain"}"#])],
                                         "guide": [searchRound(1), searchRound(2), answer]])
        let search = FakeSearch()
        let all = try await events(ClaudeBrain(provider: fake, tools: search), "When is the review?", packet("Week 47"))
        XCTAssertEqual(all, [.route(.explain), .text("The review is on 20 Nov."), .done])
        XCTAssertEqual(search.calls, 2)

        let guide = fake.requests.filter { $0.agent == "guide" }
        XCTAssertEqual(guide.map(\.toolChoice), [.auto, .auto, .none])  // no third search
        XCTAssertTrue(guide.allSatisfy { $0.tools == [.searchMap] })   // the same tools on every round
        XCTAssertEqual(guide.map(\.after.count), [0, 2, 4])             // append-only
        XCTAssertEqual(guide[2].after.prefix(2), guide[1].after[...])
        XCTAssertTrue(guide.allSatisfy { $0.text == guide[0].text })    // the first message goes again unchanged

        // The model's reply goes back exactly as received, thinking block and signature included.
        XCTAssertEqual(guide[1].after[0], ModelMessage(role: "assistant", content: Data(searchRound(1).blocks.utf8)))
        XCTAssertEqual(guide[2].after[2], ModelMessage(role: "assistant", content: Data(searchRound(2).blocks.utf8)))
        let result = try blocks(guide[1].after[1].content)
        XCTAssertEqual(guide[1].after[1].role, "user")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0]["type"] as? String, "tool_result")
        XCTAssertEqual(result[0]["tool_use_id"] as? String, "toolu_1")
        XCTAssertEqual(result[0]["content"] as? String, search.answer)
    }

    func testAModelThatKeepsSearchingGetsNoThirdSearch() async throws {
        let fake = FakeProvider(rounds: ["guide": [searchRound(1)]])  // asks for a search on every round
        let search = FakeSearch()
        do {
            _ = try await events(ClaudeBrain(provider: fake, tools: search), "", packet("Week 47"))
            XCTFail("expected badOutput: no answer came")
        } catch {
            XCTAssertEqual(error as? BrainError, .badOutput)
        }
        XCTAssertEqual(search.calls, 2)
        XCTAssertEqual(fake.requests.map(\.toolChoice), [.auto, .auto, .none])
    }

    func testNoToolsWithoutARunnerAndNeverForTheFollower() async throws {
        let fake = FakeProvider(rounds: ["guide": [answer], "follower": [Reply(pieces: [#"{"step":1,"element":null,"point":null}"#])]])
        let brain = ClaudeBrain(provider: fake, tools: FakeSearch())
        _ = try await brain.progress(steps: [GuideStep(instruction: "Click Today")], current: 0, packet: packet("Week 47"))
        _ = try await events(ClaudeBrain(provider: fake), "", packet("Week 47"))
        let follower = try XCTUnwrap(fake.requests.first { $0.agent == "follower" })
        XCTAssertTrue(follower.tools.isEmpty)
        XCTAssertTrue(try XCTUnwrap(fake.requests.last { $0.agent == "guide" }).tools.isEmpty)
    }

    func testSecretInAToolResultIsRemovedBeforeItIsSent() async throws {
        let key = "sk-" + "ant-api03-" + String(repeating: "Zq7w", count: 10)  // made up, built from pieces
        let fake = FakeProvider(rounds: ["guide": [searchRound(1), answer]])
        let search = FakeSearch(answer: "Deploy note (Note). The key is \(key). Told on 12 Nov.")
        _ = try await events(ClaudeBrain(provider: fake, tools: search), "", packet("Week 47"))
        let sent = try XCTUnwrap(fake.requests.last).after
        let text = try XCTUnwrap(try blocks(sent[1].content).first?["content"] as? String)
        XCTAssertFalse(text.contains(key))
        XCTAssertTrue(text.contains(SecretsFilter.keyMarker))
        XCTAssertTrue(text.contains("Deploy note"))
    }

    func testAFailedToolSaysOnlyThatItFailed() async {
        struct Broken: ToolRunner {
            struct Failure: Error {}
            var tools: [ToolSpec] { [.searchMap] }
            func run(_ name: String, input: Data) async throws -> String { throw Failure() }
        }
        let use = ToolLoop.Use(id: "toolu_9", name: "search_map", input: Data(#"{"query":"x"}"#.utf8))
        let block = await ToolLoop.result(of: use, runner: Broken(), allowed: true)
        XCTAssertEqual(block["is_error"] as? Bool, true)
        XCTAssertEqual(block["tool_use_id"] as? String, "toolu_9")
    }

    func testSearchMapToolDefinitionIsValidJSON() throws {
        let schema = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(ToolSpec.searchMap.schema.utf8)) as? [String: Any])
        XCTAssertEqual(schema["additionalProperties"] as? Bool, false)
        XCTAssertEqual(Set((schema["properties"] as? [String: Any])?.keys.map { $0 } ?? []), ["query", "class", "since", "list", "past"])
    }

    // MARK: P5.5 follow-up questions

    func testFollowUpCarriesEarlierTurnsAsTextAndOnlyTheFreshLook() async throws {
        let first = TestPNG.make(width: 400, height: 300), second = TestPNG.make(width: 320, height: 200)
        let fake = FakeProvider(rounds: [
            "conductor": [Reply(pieces: [#"{"route":"explain"}"#])],
            "guide": [Reply(pieces: [#"{"explanation":"Two formulas: Euler's and Fourier's.","steps":[]}"#]),
                      Reply(pieces: [#"{"explanation":"Fourier's sums sines.","steps":[]}"#])],
        ])
        let brain = ClaudeBrain(provider: fake)
        _ = try await events(brain, "What are these formulas?", packet("FIRST-SCREEN-TEXT", screenshot: first))
        _ = try await events(brain, "And the second one?", packet("SECOND-SCREEN-TEXT", screenshot: second))

        let followUp = try XCTUnwrap(fake.requests.last { $0.agent == "guide" })
        XCTAssertEqual(followUp.earlier, [Turn(question: "Question: What are these formulas?", answer: "Two formulas: Euler's and Fourier's.")])
        XCTAssertEqual(followUp.image, second)  // the fresh look only
        XCTAssertTrue(followUp.text.contains("SECOND-SCREEN-TEXT"))
        XCTAssertTrue(followUp.text.hasSuffix("Question: And the second one?"))
        // Nothing of the earlier look: no screen text, no picture.
        let earlierText = followUp.earlier.map { $0.question + $0.answer }.joined()
        XCTAssertFalse(earlierText.contains("FIRST-SCREEN-TEXT"))
        XCTAssertFalse(followUp.text.contains("FIRST-SCREEN-TEXT"))
        // On the wire: one picture in the whole request, in the last user message.
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(ClaudeProvider.urlRequest(followUp, key: "k").httpBody)) as? [String: Any])
        let wire = String(decoding: try JSONSerialization.data(withJSONObject: body), as: UTF8.self)
        XCTAssertEqual(wire.components(separatedBy: #""type":"image""#).count - 1, 1)
        XCTAssertFalse(wire.contains("FIRST-SCREEN-TEXT"))
        XCTAssertFalse(wire.contains(first.base64EncodedString()))
    }

    func testGuideTurnKeepsStepWordsButNoTargets() {
        let turn = Guide.turn("", explanation: "Use the toolbar.", steps: [GuideStep(instruction: "Click Table", target: .element("e2")),
                                                                         GuideStep(instruction: "Pick a style", target: .point(x: 3, y: 4))])
        XCTAssertEqual(turn, Turn(question: "Question: none. Explain what is under the mouse pointer.",
                                  answer: "Use the toolbar.\nSteps:\n1. Click Table\n2. Pick a style"))
    }

    func testAtMostThreeTurnsAreKept() {
        let memory = WorkingMemory()
        for n in 1...4 { memory.add(Turn(question: "q\(n)", answer: "a\(n)")) }
        XCTAssertEqual(memory.turns.map(\.question), ["q2", "q3", "q4"])
    }

    func testTurnsAreDroppedFiveMinutesAfterTheLastAnswer() {
        final class Clock: @unchecked Sendable {
            private let lock = NSLock()
            private var value = Date(timeIntervalSince1970: 1_000_000)
            var now: Date { lock.withLock { value } }
            func advance(_ seconds: TimeInterval) { lock.withLock { value += seconds } }
        }
        let clock = Clock()
        let memory = WorkingMemory(now: { clock.now })
        memory.add(Turn(question: "q1", answer: "a1"))
        clock.advance(200)
        memory.add(Turn(question: "q2", answer: "a2"))  // the 5 minutes count from the last answer
        clock.advance(299)
        XCTAssertEqual(memory.turns.count, 2)
        clock.advance(1)
        XCTAssertTrue(memory.turns.isEmpty)
        memory.add(Turn(question: "q3", answer: "a3"))  // a new conversation starts empty
        XCTAssertEqual(memory.turns.map(\.question), ["q3"])
    }

    func testTurnsAreDroppedOnQuit() async throws {
        let fake = FakeProvider(rounds: ["guide": [answer]])
        let brain: any Brain = ClaudeBrain(provider: fake)
        _ = try await events(brain, "", packet("Week 47"))
        XCTAssertEqual((brain as? ClaudeBrain)?.memory.turns.count, 1)
        brain.forgetTurns()  // what the Shell calls on Quit
        XCTAssertEqual((brain as? ClaudeBrain)?.memory.turns.count, 0)
    }

    func testAFailedAnswerIsNotKept() async {
        let brain = ClaudeBrain(provider: FakeProvider(rounds: ["guide": [Reply(pieces: [#"{"explanation":"Half"#])]]))
        _ = try? await events(brain, "", packet("Week 47"))
        XCTAssertTrue(brain.memory.turns.isEmpty)
    }
}
