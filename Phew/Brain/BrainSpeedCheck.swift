#if DEBUG
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// `--debug-brain-check <part>`: one part of the live check, for measuring speed and cost (PS.4, PS.12, PS.13).
/// Real API calls, made-up data only, the key from the Keychain. Logs numbers only: timings, token counts, costs,
/// pass or fail. Never a question, an answer or a Map fact.
///
/// Parts: `speed [n]` plain questions with the Map, `search [n]` the "this month" question, `conversation` four
/// replies in one conversation, `looks [n]` Follower looks on a full-size made-up window, `pages [n]` the guide case
/// "native app with pointables" again.
enum BrainSpeedCheck {
    static func run(_ part: String, count: Int?) async {
        switch part {
        case "speed": await speed(count ?? 10)
        case "search": await search(count ?? 3)
        case "conversation": await conversation()
        case "looks": await looks(count ?? 10)
        case "pages": await pages(count ?? 5)
        case "librarian":
            var sensitive = 0
            for n in 0..<(count ?? 3) {
                let result = await LibrarianSelfCheck.run(provider: ClaudeProvider())
                if result.sensitive { sensitive += 1 }
                shellLog("librarian part run \(n + 1): \(result.passed)/\(result.total), sensitive \(result.sensitive)")
            }
            shellLog("librarian part done: sensitive passed \(sensitive)/\(count ?? 3)")
        default: shellLog("brain check: unknown part")
        }
    }

    /// The real provider, timing every call and keeping its usage, in memory. Counts only.
    final class Clock: ModelProvider, @unchecked Sendable {
        struct Call {
            let agent: String
            let tier: Tier
            let start: Date
            var ms = 0
            var usage = Usage()
            var stop = ""
            var usd: Double { tier.model.cost(usage) }
        }
        let base: any ModelProvider
        private let lock = NSLock()
        private var made: [Call] = []
        init(_ base: any ModelProvider) { self.base = base }
        var calls: [Call] { lock.withLock { made } }

        func stream(_ request: ModelRequest) -> AsyncThrowingStream<ModelEvent, Error> {
            let index = lock.withLock {
                made.append(Call(agent: request.agent, tier: request.tier, start: Date()))
                return made.count - 1
            }
            let inner = base.stream(request)
            return AsyncThrowingStream { continuation in
                let task = Task {
                    do {
                        for try await event in inner {
                            lock.withLock {
                                if case .usage(let usage) = event { made[index].usage = usage }
                                if case .stop(let stop) = event { made[index].stop = stop }
                            }
                            continuation.yield(event)
                        }
                        continuation.finish()
                    } catch { continuation.finish(throwing: error) }
                    lock.withLock { made[index].ms = Int(Date().timeIntervalSince(made[index].start) * 1000) }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
    }

    private static func ms(_ since: Date) -> Int { Int(Date().timeIntervalSince(since) * 1000) }
    private static func cents(_ usd: Double) -> String { String(format: "%.3f", usd * 100) }
    private static func average(_ values: [Int]) -> Int { values.isEmpty ? -1 : values.reduce(0, +) / values.count }

    // MARK: PS.12, plain questions with the Map

    static let questions = [
        "What does this formula mean?", "What is the Gibbs phenomenon?", "Why do only odd terms appear in the square wave?",
        "What is a Fourier coefficient?", "What is a0/2 here?", "Where are Fourier series used?", "What does period 2π mean?",
        "How are the coefficients found?", "What does the overshoot near the jumps mean?", "What is harmonic analysis?",
    ]

    /// Questions one after another, as when the user asks again soon after an answer: the card closes in between,
    /// nobody waits for the Librarian. Logs, per question, the wait before the Guide starts, the first word, the
    /// Observer and the cost of that question's calls.
    static func speed(_ count: Int) async {
        let clock = Clock(ClaudeProvider())
        guard let store = try? await BrainSelfCheck.monthOfWork() else { return shellLog("speed check: made-up map failed") }
        let brain = BrainSelfCheck.brain(clock, store)
        var firsts: [Int] = [], readies: [Int] = [], totals: [Int] = [], spent = 0.0
        for n in 0..<count {
            let t0 = Date(), before = clock.calls.count
            var first: Int?
            do {
                for try await event in brain.answer(questions[n % questions.count], packet: fullWindow(), state: BrainSelfCheck.setUp) {
                    if case .text = event { first = first ?? ms(t0) }
                }
            } catch { shellLog("speed check: question \(n + 1) failed, \(error)") }
            let total = ms(t0)
            brain.forgetTurns()
            let mine = clock.calls[before...]
            let guide = mine.first { $0.agent == "guide" }
            let ready = guide.map { Int($0.start.timeIntervalSince(t0) * 1000) } ?? -1
            let observer = mine.first { $0.agent == "observer" }
            let rounds = mine.filter { $0.agent == "guide" }.count
            firsts.append(first ?? -1); readies.append(ready); totals.append(total)
            shellLog("speed check question \(n + 1): guide starts after \(ready) ms, first word \(first ?? -1) ms, answer done \(total) ms, observer \(observer.map { "\($0.ms) ms" } ?? "skipped"), guide rounds \(rounds), guide in \(guide?.usage.input ?? 0) cached \(guide?.usage.cacheRead ?? 0) written \(guide?.usage.cacheWrite ?? 0) tokens")
        }
        _ = await brain.map.ready()  // the last Librarian, so its cost is counted
        spent = clock.calls.reduce(0) { $0 + $1.usd }
        let byAgent = Dictionary(grouping: clock.calls, by: \.agent).map { "\($0.key) \($0.value.count) calls \(cents($0.value.reduce(0) { $0 + $1.usd })) cents" }.sorted()
        shellLog("speed check done: \(count) questions, guide starts after \(average(readies)) ms on average (max \(readies.max() ?? -1)), first word \(average(firsts)) ms on average (max \(firsts.max() ?? -1)), answer done \(average(totals)) ms on average, \(cents(spent / Double(count))) cents a question with its Librarian; \(byAgent.joined(separator: ", "))")
    }

    // MARK: PS.12, the question that needs one Map search

    static func search(_ count: Int) async {
        var ones = 0
        for n in 0..<count {
            let clock = Clock(ClaudeProvider())
            let t0 = Date()
            var first: Int?
            do {
                let brain = BrainSelfCheck.brain(clock, try await BrainSelfCheck.monthOfWork())
                for try await event in brain.answer("What did I do on this project this month?", packet: BrainSelfCheck.bakeryWindow) {
                    if case .text = event { first = first ?? ms(t0) }
                }
                _ = await brain.map.ready()
            } catch { shellLog("search check: run \(n + 1) failed, \(error)") }
            let guide = clock.calls.filter { $0.agent == "guide" }
            let searches = guide.filter { $0.stop == "tool_use" }.count
            if searches == 1 { ones += 1 }
            shellLog("search check run \(n + 1): \(searches) searches, guide rounds \(guide.map(\.ms)) ms, first word \(first ?? -1) ms, guide \(cents(guide.reduce(0) { $0 + $1.usd })) cents, all calls \(cents(clock.calls.reduce(0) { $0 + $1.usd })) cents")
        }
        shellLog("search check done: \(ones)/\(count) runs with exactly one search")
    }

    // MARK: PS.13, one conversation of four replies

    static func conversation() async {
        let clock = Clock(ClaudeProvider())
        guard let store = try? await BrainSelfCheck.monthOfWork() else { return shellLog("conversation check: made-up map failed") }
        let brain = BrainSelfCheck.brain(clock, store)
        let replies = ["What does this formula mean?", "And what are an and bn?", "Why only odd n for the square wave?",
                       "So what is the overshoot called?"]
        var cachedFromSecond = true
        for (n, question) in replies.enumerated() {
            let before = clock.calls.count, t0 = Date()
            var first: Int?
            do {
                for try await event in brain.answer(question, packet: fullWindow(), state: BrainSelfCheck.setUp) {
                    if case .text = event { first = first ?? ms(t0) }
                }
            } catch { shellLog("conversation check: reply \(n + 1) failed, \(error)") }
            let guide = clock.calls[before...].filter { $0.agent == "guide" }
            let read = guide.reduce(0) { $0 + $1.usage.cacheRead }
            if n > 0, read == 0 { cachedFromSecond = false }
            shellLog("conversation check reply \(n + 1): guide in \(guide.reduce(0) { $0 + $1.usage.input }) cached \(read) written \(guide.reduce(0) { $0 + $1.usage.cacheWrite }) out \(guide.reduce(0) { $0 + $1.usage.output }) tokens, guide \(cents(guide.reduce(0) { $0 + $1.usd })) cents, reply with all its calls \(cents(clock.calls[before...].reduce(0) { $0 + $1.usd })) cents, first word \(first ?? -1) ms")
        }
        _ = await brain.map.ready()
        brain.forgetTurns()
        shellLog("conversation check \(cachedFromSecond ? "PASS" : "FAIL"): cached tokens on the Guide from the second reply on \(cachedFromSecond)")
    }

    // MARK: PS.4, Follower looks on a full-size window

    static func looks(_ count: Int) async {
        let clock = Clock(ClaudeProvider())
        var right = 0, times: [Int] = []
        for n in 0..<count {
            let item = bigLooks[n % bigLooks.count]
            let before = clock.calls.count, t0 = Date()
            do {
                let result = try await Follower.progress(steps: BrainSelfCheck.noteSteps, current: item.current, packet: item.packet, provider: clock)
                times.append(ms(t0))
                let ok = result.current == item.expected && item.target(result.target)
                if ok { right += 1 }
                let mine = clock.calls[before...]
                shellLog("looks check \(n + 1) \(item.name): \(ok ? "right" : "wrong"), in \(mine.reduce(0) { $0 + $1.usage.input }) cached \(mine.reduce(0) { $0 + $1.usage.cacheRead }) written \(mine.reduce(0) { $0 + $1.usage.cacheWrite }) out \(mine.reduce(0) { $0 + $1.usage.output }) tokens, \(cents(mine.reduce(0) { $0 + $1.usd })) cents, \(ms(t0)) ms")
            } catch { shellLog("looks check \(n + 1): failed, \(error)") }
        }
        let spent = clock.calls.reduce(0) { $0 + $1.usd }
        shellLog("looks check done: \(right)/\(count) right, \(cents(spent / Double(max(count, 1)))) cents a look on average, slowest \(times.max() ?? -1) ms")
    }

    // MARK: The guide case "native app with pointables", again

    static func pages(_ count: Int) async {
        let provider = ClaudeProvider()
        var right = 0
        for n in 0..<count {
            var text = "", steps: [GuideStep] = []
            do {
                try await Guide.answer("How do I add a table?", packet: BrainSelfCheck.pagesApp, route: .guide, provider: provider) { event in
                    if case .text(let piece) = event { text += piece }
                    if case .steps(let given) = event { steps = given }
                }
            } catch { shellLog("pages check \(n + 1): failed, \(error)") }
            let ok = !text.isEmpty && steps.contains { $0.target == .element("e5") }
            if ok { right += 1 }
            shellLog("pages check \(n + 1): \(ok ? "right" : "wrong"), explanation \(text.count) chars, \(steps.count) steps")
        }
        shellLog("pages check done: \(right)/\(count) right")
    }

    // MARK: Made-up full-size window

    /// The whole display, 1512×982, as on a 14-inch MacBook: where the sticky board of the Follower cases sits.
    static let display = CGRect(x: 0, y: 0, width: 1512, height: 982)
    /// Where the 400×300 board is drawn inside the display.
    static let board = CGPoint(x: 560, y: 320)

    /// A Safari window on the made-up Fourier page, with a full-size picture, the most text and elements a packet holds.
    static func fullWindow() -> ContextPacket {
        var packet = BrainSelfCheck.webPage
        packet.visibleText = String((packet.visibleText + "\n" + filler).prefix(ContextPacket.textCap))
        packet.windowFrame = display
        packet.pointables = fillerElements(count: ContextPacket.pointableCap, avoiding: .null)
        packet.mouse = CGPoint(x: 700, y: 400)
        packet.screenshot = picture(board: nil)
        packet.screenshotFrame = display
        return packet
    }

    struct BigLook {
        let name: String
        let current: Int
        let packet: ContextPacket
        let expected: Int
        let target: (StepTarget?) -> Bool
    }

    /// The four Follower cases of the brain check, on a full display with the most elements and text a packet holds.
    static let bigLooks: [BigLook] = {
        func inside(_ t: StepTarget?, _ x: ClosedRange<Int>, _ y: ClosedRange<Int>) -> Bool {
            let (bx, by) = (Int(board.x), Int(board.y))
            if case let .point(px, py) = t { return x.contains(px - bx) && y.contains(py - by) } else { return false }
        }
        func color(_ packet: ContextPacket) -> (StepTarget?) -> Bool {
            let id = packet.pointables.first { $0.label == "Color" }?.id ?? "none"
            return { $0 == .element(id) }
        }
        let a = bigBoard(selected: false, palette: false, blue: false), b = bigBoard(selected: true, palette: false, blue: false)
        let c = bigBoard(selected: true, palette: true, blue: false), d = bigBoard(selected: true, palette: false, blue: true)
        return [
            BigLook(name: "(a) not done yet", current: 0, packet: a, expected: 0) { inside($0, 50...190, 100...240) },
            BigLook(name: "(b) done, moves on", current: 0, packet: b, expected: 1, target: color(b)),
            BigLook(name: "(c) two at once", current: 0, packet: c, expected: 2) { inside($0, 140...200, 41...91) },
            BigLook(name: "(d) all done", current: 2, packet: d, expected: 3) { $0 == nil },
        ]
    }()

    static func bigBoard(selected: Bool, palette: Bool, blue: Bool) -> ContextPacket {
        let small = BrainSelfCheck.noteBoard(selected: selected, palette: palette, blue: blue)
        let area = CGRect(origin: board, size: CGSize(width: 400, height: 300))
        // The board's own three buttons, moved with it, among elements spread over the rest of the display.
        let own = small.pointables.map { Pointable(role: $0.role, label: $0.label, frame: $0.frame.offsetBy(dx: board.x - 100, dy: board.y - 100)) }
        let all = (fillerElements(count: ContextPacket.pointableCap - own.count, avoiding: area) + own)
            .sorted { ($0.frame.minY, $0.frame.minX) < ($1.frame.minY, $1.frame.minX) }
            .enumerated().map { n, p in Pointable(id: "e\(n + 1)", role: p.role, label: p.label, frame: p.frame) }
        return ContextPacket(
            appName: "Sticky Board", bundleID: "com.example.stickyboard", windowTitle: "Ideas board",
            visibleText: String(("Ideas board\nIdeas\n" + filler).prefix(ContextPacket.textCap)),
            cursor: CursorElement(role: "AXGroup", label: "", value: ""), windowFrame: display, pointables: all,
            mouse: CGPoint(x: board.x + 120, y: board.y + 170),  // on the note
            screenshot: picture(board: small.screenshot), screenshotFrame: display)
    }

    /// Made-up elements in rows over the display, outside `avoiding`.
    static func fillerElements(count: Int, avoiding: CGRect) -> [Pointable] {
        let words = ["Inbox", "Drafts", "Archive", "Projects", "Calendar", "Reminders", "Library", "Gallery", "Settings",
                     "Profile", "Search", "Filter", "Sort", "Export", "Import", "Print", "Help", "Layers", "Assets", "Pages"]
        var found: [Pointable] = []
        var y: CGFloat = 40
        while found.count < count, y < display.height - 30 {
            var x: CGFloat = 20
            while found.count < count, x < display.width - 100 {
                let frame = CGRect(x: x, y: y, width: 90, height: 24)
                if !frame.intersects(avoiding) {
                    found.append(Pointable(id: "e\(found.count + 1)", role: found.count % 3 == 0 ? "AXLink" : "AXButton",
                                           label: "\(words[found.count % words.count]) \(found.count / words.count + 1)", frame: frame))
                }
                x += 150
            }
            y += 90
        }
        return found
    }

    /// Made-up page text: a long list of notes, so the packet holds as much text as a real one.
    static let filler = (1...80).map { "Note \($0): the orchard harvest list, row \($0 * 3), checked on day \($0 % 28 + 1)." }
        .joined(separator: "\n")

    /// The display: grey bars and lines like a busy window, with the board's picture drawn at `board`.
    static func picture(board png: Data?) -> Data {
        let (w, h) = (Int(display.width), Int(display.height))
        let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(gray: 0.97, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: w, height: h))
        context.setFillColor(CGColor(gray: 0.8, alpha: 1))
        for row in stride(from: 40, to: h - 30, by: 90) {
            for col in stride(from: 20, to: w - 100, by: 150) { context.fill(CGRect(x: col, y: h - row - 24, width: 90, height: 24)) }
        }
        if let png, let source = CGImageSourceCreateWithData(png as CFData, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            context.draw(image, in: CGRect(x: board.x, y: CGFloat(h) - board.y - 300, width: 400, height: 300))
        }
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }
}
#endif
