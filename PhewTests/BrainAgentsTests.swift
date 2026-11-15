import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import Phew

/// Conductor, Observer, Guide and the Brain's flow, with a fake provider and made-up packets. No network.
final class BrainAgentsTests: XCTestCase {
    /// Answers each agent with canned replies and records every request. An agent's n-th call gets its n-th
    /// reply; the last one repeats.
    final class FakeProvider: ModelProvider, @unchecked Sendable {
        struct Reply {
            var pieces: [String] = []
            /// The reply's content blocks, as the provider would hand them back.
            var blocks = "[]"
            var stop = "end_turn"
        }

        private let lock = NSLock()
        private let replies: [String: [Reply]]
        private var made: [ModelRequest] = []
        init(_ replies: [String: [String]]) { self.replies = replies.mapValues { [Reply(pieces: $0)] } }
        init(rounds: [String: [Reply]]) { self.replies = rounds }

        var requests: [ModelRequest] { lock.withLock { made } }

        func stream(_ request: ModelRequest) -> AsyncThrowingStream<ModelEvent, Error> {
            let reply = lock.withLock {
                let calls = made.filter { $0.agent == request.agent }.count
                made.append(request)
                let list = replies[request.agent] ?? [Reply()]
                return list[min(calls, list.count - 1)]
            }
            return AsyncThrowingStream { continuation in
                for piece in reply.pieces { continuation.yield(.text(piece)) }
                continuation.yield(.content(Data(reply.blocks.utf8)))
                continuation.yield(.stop(reply.stop))
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
        XCTAssertFalse(request.text.contains("Mouse pointer:"))
    }

    func testGuideContextUsesScreenshotPixelsWithTheMouse() {
        // The whole display under the mouse, not the window: positions count from the display's corner.
        var p = packet()
        p.screenshotFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        p.mouse = CGPoint(x: 700, y: 420)
        let text = Guide.context(p, shot: ScreenshotSize(width: 1440, height: 900))
        XCTAssertTrue(text.contains("e2 AXButton \"Table\" 190,60 60×28"))
        XCTAssertTrue(text.contains("Mouse pointer: 700,420 in screenshot pixels."))
        XCTAssertTrue(text.contains("in screenshot pixels):"))

        // A display too big for the model: the API shows it 2576×1449, so positions are scaled the same way.
        p.screenshotFrame = CGRect(x: 0, y: 0, width: 3840, height: 2160)
        p.mouse = CGPoint(x: 1920, y: 1000)
        let big = Guide.context(p, shot: ScreenshotSize(width: 3840, height: 2160))
        XCTAssertTrue(big.contains("e2 AXButton \"Table\" 127,40 40×19"))
        XCTAssertTrue(big.contains("Mouse pointer: 1288,671 in screenshot pixels."))

        // Mouse outside the screenshot, or no screenshot: no mouse line.
        p.mouse = CGPoint(x: 4000, y: 10)
        XCTAssertFalse(Guide.context(p, shot: ScreenshotSize(width: 3840, height: 2160)).contains("Mouse pointer:"))
        p.mouse = CGPoint(x: 700, y: 420)
        let none = Guide.context(p, shot: nil)
        XCTAssertFalse(none.contains("Mouse pointer:"))
        XCTAssertTrue(none.contains("e2 AXButton \"Table\" 90,10 60×28"))  // window pixels
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

    /// PS.12: an explanation gets no list of elements; a guide still does.
    func testOnlyAGuideGetsTheElements() {
        var p = packet()
        p.cursor?.id = "e2"
        let explain = Guide.request("What is this?", packet: p, route: .explain, shot: nil).text
        XCTAssertFalse(explain.contains("Elements you can point at"))
        XCTAssertFalse(explain.contains("\"Table\""))
        XCTAssertTrue(explain.contains("Under the mouse pointer: AXTextArea \"Body\"\n"))  // without the id of a list it lacks
        let guide = Guide.request("How do I add a table?", packet: p, route: .guide, shot: nil).text
        XCTAssertTrue(guide.contains("e2 AXButton \"Table\""))
        XCTAssertTrue(guide.contains("Under the mouse pointer: AXTextArea \"Body\" (e2)"))
    }

    func testTheGuideMarksTheStepsThatNeedOnlyAClick() async throws {
        let fake = FakeProvider([
            "conductor": [#"{"route":"guide"}"#],
            "guide": [#"{"explanation":"Two steps.","steps":["#,
                      #"{"instruction":"Click Table","element":"e2","point":null,"click":true},"#,
                      #"{"instruction":"Type the caption","element":"e1","point":null,"click":false},"#,
                      #"{"instruction":"Pick a style","element":null,"point":null}]}"#],  // no flag: waits for the look
        ])
        let all = try await events(ClaudeBrain(provider: fake), "How do I add a table?", packet())
        XCTAssertTrue(all.contains(.steps([GuideStep(instruction: "Click Table", target: .element("e2"), click: true),
                                           GuideStep(instruction: "Type the caption", target: .element("e1"), click: false),
                                           GuideStep(instruction: "Pick a style", target: nil, click: false)])))
        // The fixed schema asks for the flag on every step, under the strict rules.
        let schema = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(Guide.schema.utf8)) as? [String: Any])
        let step = try XCTUnwrap(((schema["properties"] as? [String: Any])?["steps"] as? [String: Any])?["items"] as? [String: Any])
        XCTAssertEqual((step["properties"] as? [String: Any])?["click"] as? NSDictionary, ["type": "boolean"])
        XCTAssertEqual(step["required"] as? [String], ["instruction", "element", "point", "click"])
        XCTAssertEqual(step["additionalProperties"] as? Bool, false)
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
        // Over the observer's threshold, which today's packets never reach (PS.12).
        let long = String(repeating: "Fourier series text. ", count: Observer.minChars / 20 + 1)
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

    // MARK: Follower

    /// Fails every call with `error`.
    struct FailingProvider: ModelProvider {
        let error: Error
        func stream(_ request: ModelRequest) -> AsyncThrowingStream<ModelEvent, Error> {
            AsyncThrowingStream { $0.finish(throwing: error) }
        }
    }

    private let guideSteps = [GuideStep(instruction: "Click Insert", target: .element("e1")),
                              GuideStep(instruction: "Click Table", target: .element("e2")),
                              GuideStep(instruction: "Pick a style", target: nil)]

    private func follow(_ reply: String, current: Int = 0, screenshot: Data? = nil) async throws -> GuideProgress {
        try await ClaudeBrain(provider: FakeProvider(["follower": [reply]]))
            .progress(steps: guideSteps, current: current, packet: packet(screenshot: screenshot))
    }

    func testFollowerRequestSendsStepsScreenAndPicture() throws {
        let png = TestPNG.make(width: 400, height: 300)
        var p = packet(screenshot: png)
        p.screenshotFrame = window
        let request = Follower.request(steps: guideSteps, current: 1, packet: p, shot: ScreenshotSize(png: png))
        XCTAssertEqual(request.agent, "follower")
        XCTAssertEqual(request.tier, .main)
        XCTAssertEqual(request.image, png)
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: Data(try XCTUnwrap(request.schema).utf8)))
        XCTAssertTrue(request.text.contains("e2 AXButton \"Table\" 90,10 60×28"))  // the screen, as the Guide sees it
        XCTAssertTrue(request.text.contains("Screenshot: attached, 400×300 pixels."))
        // The steps are in the fixed part, the same on every look of this guide, so it is cached (PS.4).
        XCTAssertTrue(request.system.hasPrefix(Follower.system))
        XCTAssertTrue(request.system.contains("1. Click Insert\n2. Click Table\n3. Pick a style"))
        XCTAssertTrue(request.system.hasSuffix("a number from 1 to 3, or 4 when every step is done."))
        XCTAssertFalse(request.text.contains("1. Click Insert"))
        XCTAssertTrue(request.text.hasSuffix("The user was on step 2."))
        XCTAssertEqual(Follower.request(steps: guideSteps, current: 0, packet: p, shot: nil).system, request.system)
        // No picture: no image, positions in window pixels.
        XCTAssertNil(Follower.request(steps: guideSteps, current: 0, packet: packet(), shot: nil).image)
    }

    // MARK: Less per look (PS.4)

    /// A real 1600×1000 PNG, white, with a red 20×20 square at 1300,700 (top-left origin).
    private func display() -> Data {
        let context = CGContext(data: nil, width: 1600, height: 1000, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1600, height: 1000))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 1300, y: 1000 - 700 - 20, width: 20, height: 20))
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }

    /// Red, green and blue at x,y of a PNG, top-left origin.
    private func rgb(_ png: Data, _ x: Int, _ y: Int) throws -> [UInt8] {
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(XCTUnwrap(CGImageSourceCreateWithData(png as CFData, nil)), 0, nil))
        let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        // Core Graphics counts y from the bottom: the wanted pixel lands on the 1×1 context's only pixel.
        context.draw(image, in: CGRect(x: -x, y: y - image.height + 1, width: image.width, height: image.height))
        let bytes = context.data!.assumingMemoryBound(to: UInt8.self)
        return [bytes[0], bytes[1], bytes[2]]
    }

    func testTheCutIsCentredOnTheMouseAndKeptInsideThePicture() throws {
        let png = display()
        XCTAssertEqual(Follower.cutRect(png: png, mouse: CGPoint(x: 800, y: 500)), CGRect(x: 400, y: 200, width: 800, height: 600))
        XCTAssertEqual(Follower.cutRect(png: png, mouse: CGPoint(x: 10, y: 10)), CGRect(x: 0, y: 0, width: 800, height: 600))
        XCTAssertEqual(Follower.cutRect(png: png, mouse: CGPoint(x: 1590, y: 990)), CGRect(x: 800, y: 400, width: 800, height: 600))
        XCTAssertNil(Follower.cutRect(png: png, mouse: CGPoint(x: 1700, y: 500)))  // the mouse is off the picture
        XCTAssertNil(Follower.cutRect(png: TestPNG.make(width: 800, height: 600), mouse: CGPoint(x: 400, y: 300)))  // small already
        // Only one side larger: cut on that side only.
        XCTAssertEqual(Follower.cutRect(png: TestPNG.make(width: 1200, height: 500), mouse: CGPoint(x: 600, y: 250)),
                       CGRect(x: 200, y: 0, width: 800, height: 500))
    }

    func testALookSendsTheCutPictureAndPointsBackInTheWholeScreenshot() async throws {
        let png = display()
        let frame = CGRect(x: 100, y: 50, width: 1600, height: 1000)
        var p = packet(screenshot: png)
        p.screenshotFrame = frame
        p.mouse = CGPoint(x: frame.minX + 1310, y: frame.minY + 710)  // on the red square
        let (look, offset) = Follower.less(p, steps: guideSteps, current: 0)
        let cut = try XCTUnwrap(look.screenshot)
        XCTAssertEqual(ScreenshotSize(png: cut).map { [$0.width, $0.height] }, [800, 600])
        XCTAssertEqual(offset.x, 800)
        XCTAssertEqual(offset.y, 400)
        XCTAssertEqual(look.screenshotFrame, CGRect(x: 900, y: 450, width: 800, height: 600))
        // Red within a colour-space conversion; the square spans 1300 to 1320 both ways.
        func red(_ c: [UInt8]) -> Bool { c[0] > 200 && c[1] < 100 && c[2] < 100 }
        func white(_ c: [UInt8]) -> Bool { c.allSatisfy { $0 > 240 } }
        XCTAssertTrue(red(try rgb(png, 1310, 710)))
        XCTAssertTrue(red(try rgb(cut, 1310 - 800, 710 - 400)))  // the square, moved by the cut
        XCTAssertTrue(white(try rgb(cut, 1295 - 800, 710 - 400)))  // just left of it
        XCTAssertTrue(white(try rgb(cut, 1310 - 800, 725 - 400)))  // just below it
        XCTAssertEqual(look.windowFrame, p.windowFrame)

        // The model answers in the cut picture's pixels; the Shell gets whole-screenshot pixels.
        let fake = FakeProvider(["follower": [#"{"step":1,"element":null,"point":{"x":510,"y":310}}"#]])
        let result = try await ClaudeBrain(provider: fake).progress(steps: guideSteps, current: 0, packet: p)
        XCTAssertEqual(result.target, .point(x: 1310, y: 710))
        let sent = try XCTUnwrap(fake.requests.first)
        XCTAssertEqual(sent.image, cut)
        XCTAssertTrue(sent.text.contains("Screenshot: attached, 800×600 pixels."))
    }

    func testALookSendsFewerElementsAndLessText() {
        let mouse = CGPoint(x: 1000, y: 500)
        var p = packet(text: String(repeating: "x", count: 4000))
        p.mouse = mouse
        // 80 elements, one per 20 points to the right of the mouse; the step names "Color", the farthest.
        p.pointables = (1...80).map { n in
            Pointable(id: "e\(n)", role: "AXButton", label: n == 80 ? "Color" : "Item \(n)",
                      frame: CGRect(x: mouse.x + CGFloat(n) * 20, y: mouse.y, width: 10, height: 10))
        }
        let steps = [GuideStep(instruction: "Click the note", target: nil), GuideStep(instruction: "Click Color in the toolbar", target: nil)]
        let (look, _) = Follower.less(p, steps: steps, current: 0)
        XCTAssertEqual(look.pointables.count, Follower.maxElements)
        XCTAssertEqual(look.pointables.map(\.id), (1...29).map { "e\($0)" } + ["e80"])  // nearest, plus the one named; ids kept
        XCTAssertEqual(look.visibleText.count, Follower.maxText)
        // A step already passed no longer keeps its element.
        XCTAssertFalse(Follower.less(p, steps: steps, current: 2).0.pointables.contains { $0.label == "Color" })
        // A short list is sent whole.
        p.pointables = Array(p.pointables.prefix(5))
        XCTAssertEqual(Follower.less(p, steps: steps, current: 0).0.pointables, p.pointables)
    }

    func testFollowerTargetIsValidatedAgainstTheFreshPacket() async throws {
        let png = TestPNG.make(width: 400, height: 300)
        var result = try await follow(#"{"step":2,"element":" E2 ","point":null}"#)
        XCTAssertEqual(result, GuideProgress(current: 1, target: .element("e2")))
        // An invented id falls back to the point, when the point is inside the picture.
        result = try await follow(#"{"step":3,"element":"e99","point":{"x":300,"y":100}}"#, screenshot: png)
        XCTAssertEqual(result, GuideProgress(current: 2, target: .point(x: 300, y: 100)))
        result = try await follow(#"{"step":3,"element":"e99","point":{"x":900,"y":100}}"#, screenshot: png)
        XCTAssertEqual(result, GuideProgress(current: 2, target: nil))
        result = try await follow(#"{"step":3,"element":null,"point":{"x":300,"y":100}}"#)  // no picture
        XCTAssertEqual(result, GuideProgress(current: 2, target: nil))
    }

    func testFollowerClampsTheStepAndDropsTheTargetWhenDone() async throws {
        var result = try await follow(#"{"step":9,"element":"e1","point":null}"#)
        XCTAssertEqual(result, GuideProgress(current: 3, target: nil))
        result = try await follow(#"{"step":4,"element":"e1","point":null}"#, current: 2)
        XCTAssertEqual(result, GuideProgress(current: 3, target: nil))
        result = try await follow(#"{"step":-2,"element":"e1","point":null}"#, current: 1)
        XCTAssertEqual(result, GuideProgress(current: 0, target: .element("e1")))
        // Already done, or nothing to look at: no call at all.
        let fake = FakeProvider([:])
        let done = try await ClaudeBrain(provider: fake).progress(steps: guideSteps, current: 7, packet: packet())
        let blind = try await ClaudeBrain(provider: fake).progress(steps: guideSteps, current: 1, packet: nil)
        XCTAssertEqual(done, GuideProgress(current: 3, target: nil))
        XCTAssertEqual(blind, GuideProgress(current: 1, target: nil))
        XCTAssertTrue(fake.requests.isEmpty)
    }

    func testFollowerStaysOnRefusalOrBadOutputButThrowsTheRest() async throws {
        for reply in [#"{"step":"#, "not json", #"{"element":"e1","point":null}"#] {
            let result = try await follow(reply, current: 1)
            XCTAssertEqual(result, GuideProgress(current: 1, target: nil, checked: false), reply)
        }
        let refused = try await ClaudeBrain(provider: FailingProvider(error: BrainError.refused))
            .progress(steps: guideSteps, current: 1, packet: packet())
        XCTAssertEqual(refused, GuideProgress(current: 1, target: nil, checked: false))
        for (error, expected) in [(BrainError.badKey, BrainError.badKey), (BrainError.noKey, .noKey),
                                  (BrainError.rateLimited, .rateLimited), (URLError(.notConnectedToInternet), .network)] as [(Error, BrainError)] {
            do {
                _ = try await ClaudeBrain(provider: FailingProvider(error: error)).progress(steps: guideSteps, current: 1, packet: packet())
                XCTFail("expected \(expected)")
            } catch {
                XCTAssertEqual(error as? BrainError, expected)
            }
        }
    }

    // MARK: PS.5, runaway looks

    /// Fails the first `runaways` calls as the time cap does, then answers `reply`. Counts the calls.
    final class RunawayProvider: ModelProvider, @unchecked Sendable {
        private let lock = NSLock()
        private var calls = 0
        let runaways: Int
        let reply: String
        init(runaways: Int, reply: String) { (self.runaways, self.reply) = (runaways, reply) }
        var made: Int { lock.withLock { calls } }

        func stream(_ request: ModelRequest) -> AsyncThrowingStream<ModelEvent, Error> {
            let n = lock.withLock { calls += 1; return calls }
            return AsyncThrowingStream { continuation in
                if n <= runaways { return continuation.finish(throwing: BrainError.runaway) }
                continuation.yield(.text(reply))
                continuation.yield(.stop("end_turn"))
                continuation.finish()
            }
        }
    }

    func testTheLookIsCappedInTimeAndOutput() {
        let request = Follower.request(steps: guideSteps, current: 0, packet: packet(), shot: nil)
        XCTAssertEqual(request.timeLimit, Follower.timeLimit)
        XCTAssertEqual(request.maxTokens, Follower.maxTokens)
        XCTAssertLessThan(Follower.timeLimit, 4)  // the done-when: no look above 4 s
        // The Guide's answer has no time cap: it streams to the card.
        XCTAssertNil(Guide.request("q", packet: packet(), route: .guide, shot: nil).timeLimit)
    }

    func testARunawayLookIsRetriedOnce() async throws {
        let once = RunawayProvider(runaways: 1, reply: #"{"step":2,"element":"e2","point":null}"#)
        let result = try await ClaudeBrain(provider: once).progress(steps: guideSteps, current: 0, packet: packet())
        XCTAssertEqual(result, GuideProgress(current: 1, target: .element("e2")))
        XCTAssertEqual(once.made, 2)
        // Two runaways: no third call, and no judgement, so the guide stays where it is.
        let twice = RunawayProvider(runaways: 5, reply: "")
        let stuck = try await ClaudeBrain(provider: twice).progress(steps: guideSteps, current: 1, packet: packet())
        XCTAssertEqual(stuck, GuideProgress(current: 1, target: nil, checked: false))
        XCTAssertEqual(twice.made, 2)
        // An answer cut at the output cap is retried the same way.
        let cut = FakeProvider(rounds: ["follower": [FakeProvider.Reply(pieces: [#"{"step":"#], stop: "max_tokens"),
                                                     FakeProvider.Reply(pieces: [#"{"step":3,"element":null,"point":null}"#])]])
        let later = try await ClaudeBrain(provider: cut).progress(steps: guideSteps, current: 1, packet: packet())
        XCTAssertEqual(later, GuideProgress(current: 2, target: nil))
        XCTAssertEqual(cut.requests.count, 2)
    }
}
