import XCTest
@testable import Phew

/// Conductor, Observer, Guide and the Brain's flow, with a fake provider and made-up packets. No network.
final class BrainAgentsTests: XCTestCase {
    /// Answers each agent with canned text pieces and records every request.
    final class FakeProvider: ModelProvider, @unchecked Sendable {
        private let lock = NSLock()
        private let replies: [String: [String]]
        private var made: [ModelRequest] = []
        init(_ replies: [String: [String]]) { self.replies = replies }

        var requests: [ModelRequest] { lock.withLock { made } }

        func stream(_ request: ModelRequest) -> AsyncThrowingStream<ModelEvent, Error> {
            lock.withLock { made.append(request) }
            let pieces = replies[request.agent] ?? []
            return AsyncThrowingStream { continuation in
                for piece in pieces { continuation.yield(.text(piece)) }
                continuation.yield(.stop("end_turn"))
                continuation.finish()
            }
        }
    }

    private let window = CGRect(x: 100, y: 50, width: 800, height: 600)

    private func packet(text: String = "Lab report\nResults", screenshot: Data? = nil) -> ContextPacket {
        ContextPacket(appName: "Pages", bundleID: "com.apple.iWork.Pages", windowTitle: "Lab report.pages", visibleText: text,
                      cursor: CursorElement(role: "AXTextArea", label: "Body", value: ""), windowFrame: window,
                      pointables: [Pointable(id: "e1", role: "AXButton", label: "Insert", frame: CGRect(x: 120, y: 60, width: 60, height: 28)),
                                   Pointable(id: "e2", role: "AXButton", label: "Table", frame: CGRect(x: 190, y: 60, width: 60, height: 28))],
                      screenshot: screenshot)
    }

    private func events(_ brain: ClaudeBrain, _ question: String, _ packet: ContextPacket?) async throws -> [BrainEvent] {
        var all: [BrainEvent] = []
        for try await event in brain.answer(question, packet: packet) { all.append(event) }
        return all
    }

    // MARK: Conductor

    func testRouteDecoding() {
        XCTAssertEqual(Conductor.decode(#"{"route":"guide"}"#), .guide)
        XCTAssertEqual(Conductor.decode(#"{"route": "Remember"}"#), .remember)  // enum casing is not guaranteed
        XCTAssertNil(Conductor.decode(#"{"route":"dance"}"#))
        XCTAssertNil(Conductor.decode("guide"))
    }

    func testConductorSeesAFewLinesNotThePacket() {
        let request = Conductor.request("How do I add a table?", packet: packet(text: "SECRET-BODY-TEXT"))
        XCTAssertEqual(request.tier, .small)
        XCTAssertTrue(request.text.hasSuffix("Request: How do I add a table?"))
        XCTAssertFalse(request.text.contains("SECRET-BODY-TEXT"))
    }

    // MARK: Observer

    func testObserverKeepsTheOriginalUnlessShorterAndNotEmpty() {
        XCTAssertEqual(Observer.accept("  short  ", original: "a much longer original"), "short")
        XCTAssertEqual(Observer.accept("", original: "original"), "original")
        XCTAssertEqual(Observer.accept("longer than the original", original: "original"), "original")
    }

    func testObserverSkipsShortText() async {
        let fake = FakeProvider(["observer": ["cleaned"]])
        let short = String(repeating: "a", count: Observer.minChars - 1)
        let result = await Observer.clean(short, question: "q", provider: fake)
        XCTAssertEqual(result, short)
        XCTAssertTrue(fake.requests.isEmpty)
    }

    // MARK: Guide

    func testExplanationStreamsAcrossPiecesAndEscapes() {
        var stream = ExplanationStream()
        let pieces = [#"{"expla"#, #"nation" : "Hel"#, #"lo \"wo"#, #"rld\"\n\u00e"#, #"9 \ud83d"#, #"\ude00 done","steps":[{"instruction":"x"}]}"#]
        let out = pieces.map { stream.feed($0) }
        XCTAssertEqual(out.joined(), "Hello \"world\"\né 😀 done")
        XCTAssertEqual(out[0], "")
        XCTAssertEqual(out[2], "lo \"wo")
        XCTAssertTrue(stream.finished)
        XCTAssertEqual(stream.feed("more"), "")
    }

    private func step(_ instruction: String, element: String? = nil, x: Int? = nil, y: Int? = nil) throws -> Guide.Output.Step {
        let point = x.map { #"{"x":\#($0),"y":\#(y ?? 0)}"# } ?? "null"
        let element = element.map { "\"\($0)\"" } ?? "null"
        return try JSONDecoder().decode(Guide.Output.Step.self,
                                        from: Data(#"{"instruction":"\#(instruction)","element":\#(element),"point":\#(point)}"#.utf8))
    }

    func testStepTargetsAreValidatedAgainstThePacket() throws {
        let raw = [try step("Click Insert", element: "e1"),
                   try step("Click the invented button", element: "e99"),
                   try step("Click Table", element: " E2 "),
                   try step("   "),
                   try step("Click the circle", x: 300, y: 100),
                   try step("Click outside", x: 900, y: 100)]
        let shot = ScreenshotSize(width: 400, height: 300)
        XCTAssertEqual(Guide.steps(raw, packet: packet(), shot: shot), [
            GuideStep(instruction: "Click Insert", target: .element("e1")),
            GuideStep(instruction: "Click the invented button", target: nil),  // unknown id: dropped, never invented
            GuideStep(instruction: "Click Table", target: .element("e2")),
            GuideStep(instruction: "Click the circle", target: .point(x: 300, y: 100)),
            GuideStep(instruction: "Click outside", target: nil),
        ])
        // Without a screenshot there is nothing a point could refer to.
        XCTAssertNil(Guide.steps([try step("Click the circle", x: 300, y: 100)], packet: packet(), shot: nil)[0].target)
    }

    func testPointsAreScaledBackWhenTheAPIDownsizes() throws {
        XCTAssertEqual(ScreenshotSize.seen(width: 1920, height: 1080).0, 1920)  // fits the high-resolution tier
        XCTAssertTrue(ScreenshotSize.seen(width: 3840, height: 2160) == (2576, 1449))  // docs table
        XCTAssertTrue(ScreenshotSize.seen(width: 1075, height: 1520, maxEdge: 1568, maxTokens: 1568) == (924, 1307))  // docs A4 example
        let big = ScreenshotSize(width: 3840, height: 2160)
        XCTAssertTrue(big.pixel(x: 1288, y: 724)! == (1920, 1079))
        XCTAssertEqual(ScreenshotSize(png: TestPNG.make(width: 400, height: 300)), ScreenshotSize(width: 400, height: 300))
        XCTAssertNil(ScreenshotSize(png: Data("not a png at all, just text".utf8)))
    }

    func testGuideContextUsesWindowPixelsAndAsksLast() {
        let request = Guide.request("How do I add a table?", packet: packet(), route: .guide, shot: nil)
        XCTAssertEqual(request.tier, .main)
        XCTAssertTrue(request.text.contains("e2 AXButton \"Table\" 90,10 60×28"))
        XCTAssertTrue(request.text.contains("Screenshot: none."))
        XCTAssertTrue(request.text.hasSuffix("Question: How do I add a table?"))
        XCTAssertNil(request.image)
    }

    // MARK: The Brain's flow

    func testGuideRequestStreamsTextThenValidatedSteps() async throws {
        let fake = FakeProvider([
            "conductor": [#"{"route":"#, #""guide"}"#],
            "guide": [#"{"explanation":"Tables live in "#, #"the toolbar.","steps":["#,
                      #"{"instruction":"Click Table","element":"e2","point":null},"#,
                      #"{"instruction":"Pick a style","element":"e7","point":null}]}"#],
        ])
        let all = try await events(ClaudeBrain(provider: fake), "How do I add a table?", packet())
        XCTAssertEqual(all, [.route(.guide), .text("Tables live in "), .text("the toolbar."),
                             .steps([GuideStep(instruction: "Click Table", target: .element("e2")),
                                     GuideStep(instruction: "Pick a style", target: nil)]),
                             .done])
    }

    func testEmptyQuestionExplainsWithoutTheConductor() async throws {
        let fake = FakeProvider(["guide": [#"{"explanation":"This is the body text.","steps":[]}"#]])
        let all = try await events(ClaudeBrain(provider: fake), "  ", packet())
        XCTAssertEqual(all, [.route(.explain), .text("This is the body text."), .done])
        XCTAssertEqual(fake.requests.map(\.agent), ["guide"])
    }

    func testRememberAnswersWithoutTheGuide() async throws {
        let fake = FakeProvider(["conductor": [#"{"route":"remember"}"#]])
        let all = try await events(ClaudeBrain(provider: fake), "Remember the exam is on Friday", packet())
        XCTAssertEqual(all, [.route(.remember), .text(ClaudeBrain.cannotRemember), .done])
        XCTAssertFalse(fake.requests.contains { $0.agent == "guide" })
    }

    func testQuestionPassesTheSecretsFilterBeforeAnyCall() async throws {
        let key = "sk-" + "ant-api03-" + String(repeating: "aB3x", count: 10)  // made up, built from pieces
        let fake = FakeProvider([
            "conductor": [#"{"route":"explain"}"#],
            "observer": ["Fourier series: a sum of sines."],
            "guide": [#"{"explanation":"ok","steps":[]}"#],
        ])
        let long = String(repeating: "Fourier series text. ", count: 100)  // over the observer's threshold
        _ = try await events(ClaudeBrain(provider: fake), "why does \(key) fail?", packet(text: long))
        XCTAssertEqual(Set(fake.requests.map(\.agent)), ["conductor", "observer", "guide"])
        for request in fake.requests {
            XCTAssertFalse(request.text.contains(key), request.agent)
            XCTAssertTrue(request.text.contains(SecretsFilter.keyMarker), request.agent)
        }
        // The Guide got the observer's shorter text, not the long original.
        let guide = try XCTUnwrap(fake.requests.first { $0.agent == "guide" })
        XCTAssertTrue(guide.text.contains("Fourier series: a sum of sines."))
        XCTAssertFalse(guide.text.contains(long))
    }

    func testCutOrMalformedGuideAnswerIsBadOutput() async {
        let fake = FakeProvider(["guide": [#"{"explanation":"Half"#]])
        do {
            _ = try await events(ClaudeBrain(provider: fake), "", packet())
            XCTFail("expected badOutput")
        } catch {
            XCTAssertEqual(error as? BrainError, .badOutput)
        }
    }
}
