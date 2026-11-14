#if DEBUG
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// `--debug-brain-check`: the Brain against the real API, with the key from the Keychain and made-up content only.
/// Costs a few cents. Logs pass or fail per item with timings and cost, then one summary line. Counts only:
/// no model text goes to the log.
enum BrainSelfCheck {
    static func run() {
        Task.detached {
            guard KeyStore().read() != nil else { return shellLog("brain check: no API key in the Keychain, stopping") }
            let provider = ClaudeProvider()
            let start = Date()
            var passed = 0, total = 0
            func report(_ name: String, _ ok: Bool, _ detail: String) {
                total += 1
                if ok { passed += 1 }
                shellLog("brain check \(ok ? "PASS" : "FAIL") \(name): \(detail)")
            }
            func failure(_ error: Error) -> String { "error \(error) \(ClaudeProvider.lastErrorMessage ?? "")" }

            // (a) One streamed test prompt per tier.
            for tier in [Tier.small, .main] {
                let t0 = Date(), usd0 = CallLog.spentUSD
                var pieces = 0, chars = 0, first: Int?, stop = ""
                do {
                    let request = ModelRequest(agent: "check", tier: tier, system: "Reply in one short sentence.",
                                               text: "Say hello to someone who works on a Mac.", maxTokens: 1024)
                    for try await event in provider.stream(request) {
                        switch event {
                        case .text(let piece): pieces += 1; chars += piece.count; first = first ?? ms(t0)
                        case .stop(let reason): stop = reason
                        case .usage, .content: break
                        }
                    }
                    report("stream \(tier)", chars > 0 && stop == "end_turn",
                           "\(pieces) text pieces, \(chars) chars, stop \(stop), first token \(first ?? -1) ms, total \(ms(t0)) ms, $\(CallLog.spentUSD - usd0)")
                } catch { report("stream \(tier)", false, failure(error)) }
            }

            // (b) Observer: shorter, and the words that carry the meaning are still there.
            do {
                let t0 = Date(), usd0 = CallLog.spentUSD
                let page = webPage.visibleText
                let cleaned = Observer.accept(try await provider.complete(Observer.request(page, question: "What does this formula mean?")), original: page)
                let kept = ["Fourier", "period", "coefficient"].filter { cleaned.localizedCaseInsensitiveContains($0) }
                report("observer", cleaned.count < page.count && kept.count == 3,
                       "\(page.count) to \(cleaned.count) chars, \(kept.count)/3 key words kept, total \(ms(t0)) ms, $\(CallLog.spentUSD - usd0)")
            } catch { report("observer", false, failure(error)) }

            // (b) The Guide on 6 made-up cases.
            for item in guideCases {
                let t0 = Date(), usd0 = CallLog.spentUSD
                var first: Int?, text = "", steps: [GuideStep]?
                do {
                    try await Guide.answer(item.question, packet: item.packet, route: item.route, provider: provider) { event in
                        switch event {
                        case .text(let piece): first = first ?? ms(t0); text += piece
                        case .steps(let s): steps = s
                        default: break
                        }
                    }
                    let onElements = steps?.filter { if case .element = $0.target { true } else { false } }.count ?? 0
                    let onPoints = steps?.filter { if case .point = $0.target { true } else { false } }.count ?? 0
                    // The explanation stays in memory: only whether it names the expected thing is logged.
                    let named = item.mentions.isEmpty || item.mentions.contains { text.localizedCaseInsensitiveContains($0) }
                    let valid = !text.isEmpty && named && (item.route == .guide) == (steps != nil) && item.check(steps ?? [])
                    report("guide \(item.name)", valid,
                           "explanation \(text.count) chars\(item.mentions.isEmpty ? "" : ", names it \(named)"), \(steps?.count ?? 0) steps (\(onElements) on elements, \(onPoints) on points), first word \(first ?? -1) ms, total \(ms(t0)) ms, $\(CallLog.spentUSD - usd0)")
                } catch { report("guide \(item.name)", false, failure(error)) }
            }

            // (c) The Conductor on 12 requests.
            for (question, expected) in conductorCases {
                let t0 = Date()
                do {
                    let route = try await Conductor.route(question, packet: coursePage, provider: provider)
                    report("conductor \(expected)", route == expected, "got \(route), \(ms(t0)) ms")
                } catch { report("conductor \(expected)", false, failure(error)) }
            }

            // (d) The Follower on 4 drawn screens of a made-up sticky-note board.
            for item in followerCases {
                let t0 = Date(), usd0 = CallLog.spentUSD
                do {
                    let result = try await Follower.progress(steps: noteSteps, current: item.current, packet: item.packet, provider: provider)
                    let kind = switch result.target { case .element: "element"; case .point: "point"; case nil: "none" }
                    let placed = item.target(result.target)
                    report("follower \(item.name)", result.current == item.expected && placed,
                           "step \(item.current + 1) to \(result.current + 1), expected \(item.expected + 1), target \(kind) in place \(placed), total \(ms(t0)) ms, $\(CallLog.spentUSD - usd0)")
                } catch { report("follower \(item.name)", false, failure(error)) }
            }

            shellLog("brain check done: \(passed)/\(total) passed, $\(CallLog.spentUSD) in all, \(ms(start) / 1000) s")
        }
    }

    private static func ms(_ since: Date) -> Int { Int(Date().timeIntervalSince(since) * 1000) }

    // MARK: - Made-up data

    struct GuideCase {
        let name: String
        let question: String
        let route: Route
        let packet: ContextPacket
        /// The explanation must contain one of these words, when any are given.
        var mentions: [String] = []
        let check: ([GuideStep]) -> Bool
    }

    static let guideCases = [
        GuideCase(name: "text-rich web page", question: "What does this formula mean?", route: .explain, packet: webPage) { _ in true },
        GuideCase(name: "native app with pointables", question: "How do I add a table?", route: .guide, packet: pagesApp) { steps in
            steps.contains { $0.target == .element("e5") }
        },
        GuideCase(name: "canvas with screenshot", question: "How do I select the red circle?", route: .guide, packet: canvasApp) { steps in
            // The red circle spans 260...340 by 60...140 in the screenshot; 20 px of slack.
            steps.contains { if case let .point(x, y) = $0.target { (240...360).contains(x) && (40...160).contains(y) } else { false } }
        },
        // The mouse is on the blue square: "this" is read from the picture at the pointer.
        GuideCase(name: "this at the mouse pointer", question: "What is this?", route: .explain, packet: canvasApp,
                  mentions: ["square"]) { _ in true },
        GuideCase(name: "empty question", question: "", route: .explain, packet: wordApp) { _ in true },
        GuideCase(name: "how do I guide request", question: "How do I submit my homework?", route: .guide, packet: coursePage) { steps in
            !steps.isEmpty && steps.contains { if case .element = $0.target { true } else { false } }
        },
    ]

    static let conductorCases: [(String, Route)] = [
        ("What does this error mean?", .explain),
        ("How do I export this as a PDF?", .guide),
        ("Remember that the exam is on Friday", .remember),
        ("I don't get this", .explain),
        ("Where do I change the font size?", .guide),
        ("Save this formula for later", .remember),
        ("Explain this paragraph", .explain),
        ("Come faccio a inserire una tabella?", .guide),
        ("Ricordati questa definizione", .remember),
        ("Why does this graph go down at the end?", .explain),
        ("What do you remember about this project?", .explain),
        ("Forget what I told you about the exam", .remember),
    ]

    private static func pointables(_ labels: [String], role: String = "AXButton", y: CGFloat, in window: CGRect) -> [Pointable] {
        labels.enumerated().map { i, label in
            Pointable(id: "e\(i + 1)", role: role, label: label,
                      frame: CGRect(x: window.minX + 20 + CGFloat(i) * 70, y: window.minY + y, width: 60, height: 28))
        }
    }

    static let webPage = ContextPacket(
        appName: "Safari", bundleID: "com.apple.Safari", windowTitle: "Fourier series - Example Encyclopedia",
        visibleText: """
            Main page  Contents  Current events  Random article  About  Contact  Donate  Log in  Create account
            Search Example Encyclopedia
            Fourier series
            From Example Encyclopedia, the free encyclopedia
            A Fourier series is a way to write a periodic function as a sum of sine and cosine waves. Any reasonably \
            smooth function f(x) with period 2π can be written as f(x) = a0/2 + Σ (an cos(nx) + bn sin(nx)), where \
            the sum runs over n = 1, 2, 3 and so on. The numbers an and bn are the Fourier coefficients. Each \
            coefficient measures how much of the wave with frequency n is present in the function.
            The coefficients are found by integrating over one period: an = (1/π) ∫ f(x) cos(nx) dx and \
            bn = (1/π) ∫ f(x) sin(nx) dx, with both integrals taken from −π to π. The term a0/2 is the average value \
            of the function over one period.
            Example: a square wave that is +1 on half of the period and −1 on the other half has only sine terms, and \
            only odd n appear: f(x) = (4/π) (sin x + sin 3x / 3 + sin 5x / 5 + …). Adding more terms makes the sum \
            closer to the square wave, except near the jumps, where an overshoot of about 9 percent remains. This is \
            called the Gibbs phenomenon.
            Fourier series are used to solve the heat equation, to analyse sound and vibrations, and in signal \
            processing, where a signal is described by the strength of each of its frequencies.
            See also  Fourier transform  Harmonic analysis  Gibbs phenomenon
            References  External links
            This page was last edited on 3 March.  Text is available under a free licence.
            Privacy policy  About Example Encyclopedia  Disclaimers  Contact  Mobile view  Cookie settings
            Main page  Contents  Current events  Random article  About  Contact  Donate
            """,
        cursor: CursorElement(role: "AXStaticText", label: "", value: "f(x) = a0/2 + Σ (an cos(nx) + bn sin(nx))"),
        windowFrame: CGRect(x: 0, y: 25, width: 1440, height: 875))

    static let pagesApp: ContextPacket = {
        let window = CGRect(x: 80, y: 60, width: 1280, height: 800)
        return ContextPacket(
            appName: "Pages", bundleID: "com.apple.iWork.Pages", windowTitle: "Lab report.pages",
            visibleText: "Lab report\nIntroduction\nThe aim of this experiment was to measure the spring constant of two springs.\nMethod\nResults",
            cursor: CursorElement(role: "AXTextArea", label: "Body", value: "Results"),
            windowFrame: window,
            pointables: pointables(["View", "Zoom", "Add Page", "Insert", "Table", "Chart", "Text", "Shape", "Media",
                                    "Comment", "Share", "Format", "Document"], y: 10, in: window))
    }()

    static let canvasApp: ContextPacket = {
        let window = CGRect(x: 100, y: 100, width: 400, height: 300)
        return ContextPacket(
            appName: "Sketchpad", bundleID: "com.example.sketchpad", windowTitle: "Untitled drawing",
            visibleText: "Layers\nCanvas 1", cursor: CursorElement(role: "AXGroup", label: "", value: ""),
            windowFrame: window, pointables: pointables(["Brush", "Eraser"], y: 4, in: window),
            mouse: CGPoint(x: window.minX + 110, y: window.minY + 210),  // on the blue square, away from the circle
            screenshot: canvasPNG(), screenshotFrame: window)
    }()

    static let wordApp: ContextPacket = {
        let window = CGRect(x: 0, y: 25, width: 1440, height: 875)
        var buttons = pointables(["Home", "Insert", "Review", "Track Changes", "Accept", "Reject", "Comments"], y: 40, in: window)
        buttons[3].role = "AXCheckBox"
        return ContextPacket(
            appName: "Microsoft Word", bundleID: "com.microsoft.Word", windowTitle: "Essay draft.docx",
            visibleText: "Essay draft\nThe industrial revolution changed how cities grew.\nReview\nTrack Changes\nAccept\nReject",
            cursor: CursorElement(role: "AXCheckBox", label: "Track Changes", value: "0", frame: buttons[3].frame, id: "e4"),
            windowFrame: window, pointables: buttons)
    }()

    static let coursePage: ContextPacket = {
        let window = CGRect(x: 0, y: 25, width: 1440, height: 875)
        return ContextPacket(
            appName: "Safari", bundleID: "com.apple.Safari", windowTitle: "Calculus II - Course page",
            visibleText: "Calculus II\nAnnouncements\nHomework 4 is due on Friday at 18:00.\nAssignments\nHomework 4: series and convergence\nGrades",
            cursor: CursorElement(role: "AXLink", label: "Assignments", value: ""),
            windowFrame: window,
            pointables: pointables(["Home", "Courses", "Calculus II", "Assignments", "Homework 4", "Add submission",
                                    "Grades", "Log out"], role: "AXLink", y: 120, in: window))
    }()

    struct FollowerCase {
        let name: String
        /// The step the user was on, 0-based.
        let current: Int
        let packet: ContextPacket
        /// The step they should be on now, 0-based; `noteSteps.count` is done.
        let expected: Int
        let target: (StepTarget?) -> Bool
    }

    static let noteSteps = [
        GuideStep(instruction: "Click the yellow note to select it.", target: nil),
        GuideStep(instruction: "Click Color in the toolbar.", target: .element("e2")),
        GuideStep(instruction: "Click the blue swatch.", target: nil),
    ]

    private static func inside(_ target: StepTarget?, x: ClosedRange<Int>, y: ClosedRange<Int>) -> Bool {
        if case let .point(px, py) = target { x.contains(px) && y.contains(py) } else { false }
    }

    static let followerCases = [
        // Nothing selected yet: stays on step 1, pointing at the note (60...180 by 110...230, 10 px of slack).
        FollowerCase(name: "(a) not done yet", current: 0, packet: noteBoard(selected: false, palette: false, blue: false),
                     expected: 0) { inside($0, x: 50...190, y: 100...240) },
        // The note is selected: step 2, the Color button.
        FollowerCase(name: "(b) done, moves on", current: 0, packet: noteBoard(selected: true, palette: false, blue: false),
                     expected: 1) { $0 == .element("e2") },
        // Selected and the palette is open: skips to step 3, the blue swatch (150...190 by 51...81, 10 px of slack).
        FollowerCase(name: "(c) two at once", current: 0, packet: noteBoard(selected: true, palette: true, blue: false),
                     expected: 2) { inside($0, x: 140...200, y: 41...91) },
        // The note is blue: done, nothing to point at.
        FollowerCase(name: "(d) all done", current: 2, packet: noteBoard(selected: true, palette: false, blue: true),
                     expected: 3) { $0 == nil },
    ]

    static func noteBoard(selected: Bool, palette: Bool, blue: Bool) -> ContextPacket {
        let window = CGRect(x: 100, y: 100, width: 400, height: 300)
        return ContextPacket(
            appName: "Sticky Board", bundleID: "com.example.stickyboard", windowTitle: "Ideas board",
            visibleText: "Ideas board\nIdeas", cursor: CursorElement(role: "AXGroup", label: "", value: ""),
            windowFrame: window, pointables: pointables(["Text", "Color", "Delete"], y: 4, in: window),
            mouse: CGPoint(x: window.minX + 120, y: window.minY + 170),  // on the note
            screenshot: notePNG(selected: selected, palette: palette, blue: blue), screenshotFrame: window)
    }

    /// 400×300, top-left origin: a toolbar (Text, Color, Delete at x 20, 90, 160, y 4, 60×28), a note at 60,110
    /// (120×120, yellow or blue), a selection frame with handles around it, and a palette under Color with red,
    /// blue and green swatches (40×30 at x 100, 150, 200, y 51).
    static func notePNG(selected: Bool, palette: Bool, blue: Bool) -> Data {
        let context = CGContext(data: nil, width: 400, height: 300, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        // Core Graphics counts y from the bottom: flip each top-left rect.
        func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x, y: 300 - y - h, width: w, height: h) }
        func fill(_ r: CGRect, _ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) {
            context.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 1))
            context.fill(r)
        }
        func text(_ string: String, _ x: CGFloat, _ baseline: CGFloat) {
            let attributes = [NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, 13, nil)]
            context.textPosition = CGPoint(x: x, y: 300 - baseline)
            CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attributes)), context)
        }
        fill(rect(0, 0, 400, 300), 1, 1, 1)
        fill(rect(0, 0, 400, 36), 0.9, 0.9, 0.9)
        for (i, label) in ["Text", "Color", "Delete"].enumerated() {
            let x = 20 + CGFloat(i) * 70
            context.setStrokeColor(CGColor(gray: 0.6, alpha: 1))
            fill(rect(x, 4, 60, 28), 1, 1, 1)
            context.stroke(rect(x, 4, 60, 28))
            text(label, x + 10, 23)
        }
        if blue { fill(rect(60, 110, 120, 120), 0.3, 0.5, 0.95) } else { fill(rect(60, 110, 120, 120), 1, 0.88, 0.3) }
        text("Ideas", 75, 135)
        if selected {
            context.setStrokeColor(CGColor(red: 0.1, green: 0.3, blue: 0.9, alpha: 1))
            context.setLineWidth(3)
            context.stroke(rect(55, 105, 130, 130))
            for (x, y) in [(51, 101), (177, 101), (51, 227), (177, 227)] { fill(rect(CGFloat(x), CGFloat(y), 12, 12), 0.1, 0.3, 0.9) }
        }
        if palette {
            context.setStrokeColor(CGColor(gray: 0.5, alpha: 1))
            context.setLineWidth(1)
            fill(rect(90, 40, 160, 52), 0.98, 0.98, 0.98)
            context.stroke(rect(90, 40, 160, 52))
            fill(rect(100, 51, 40, 30), 0.9, 0.15, 0.15)
            fill(rect(150, 51, 40, 30), 0.15, 0.35, 0.95)
            fill(rect(200, 51, 40, 30), 0.15, 0.75, 0.3)
        }
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }

    /// 400×300: a blue square at 60,160 (100×100) and a red circle centred at 300,100 (radius 40), top-left origin.
    static func canvasPNG() -> Data {
        let context = CGContext(data: nil, width: 400, height: 300, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
        // Core Graphics counts y from the bottom.
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 60, y: 40, width: 100, height: 100))
        context.setFillColor(CGColor(red: 0.9, green: 0.1, blue: 0.1, alpha: 1))
        context.fillEllipse(in: CGRect(x: 260, y: 160, width: 80, height: 80))
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }
}
#endif
