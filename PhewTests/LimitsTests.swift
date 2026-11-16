import XCTest
import ImageIO
import UniformTypeIdentifiers
@testable import Phew

/// The cost cuts of the after-MVP review (A1 is in SelfKnowledgeTests): the one-hour cache (D1), the ceiling on the
/// whole-display picture (A3), and Phew's own limits. Made-up numbers, a private UserDefaults suite, a made-up
/// calls.log in a temporary folder. No network.
final class LimitsTests: XCTestCase {
    typealias FakeProvider = BrainAgentsTests.FakeProvider
    typealias Reply = FakeProvider.Reply

    private var suite = ""
    private var defaults: UserDefaults!
    private let clock = Clock()
    /// Rome: midnight there is not midnight in UTC, where calls.log writes `ts`.
    private var rome: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Rome")!
        return calendar
    }()

    override func setUp() {
        suite = "phew.limits.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        clock.now = date("2026-11-16T10:00:00Z")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        CallLog.hourCache = false
    }

    final class Clock: @unchecked Sendable {
        private let lock = NSLock()
        private var value = Date(timeIntervalSince1970: 0)
        var now: Date {
            get { lock.withLock { value } }
            set { lock.withLock { value = newValue } }
        }
    }

    private func date(_ iso: String) -> Date { try! Date(iso, strategy: .iso8601) }

    private func line(_ iso: String, usd: Double, tier: Tier = .main) -> CallLog.Line {
        CallLog.Line(ts: iso, agent: "guide", tier: tier.rawValue, model: tier.model.id, inputTokens: 1, outputTokens: 1,
                     cacheWriteTokens: 0, cacheReadTokens: 0, usd: usd, msFirstToken: nil, msTotal: 1, stop: nil, error: nil)
    }

    private func limits(_ lines: [CallLog.Line] = []) -> Limits {
        let clock = clock
        return Limits(defaults: defaults, now: { clock.now }, calendar: rome, log: { lines })
    }

    // MARK: Limits

    func testUnderTheCeilingsARequestGoesAndIsCounted() throws {
        let limits = limits([line("2026-11-16T09:00:00Z", usd: 1.20)])
        try limits.start()
        XCTAssertEqual(limits.today(), LimitsToday(spentUSD: 1.20, requests: 1, usdPerDay: 3, requestsPerDay: 400))
    }

    /// 30 questions in one minute go; the 31st is refused and the Brain sends nothing.
    func testThe31stInAMinuteIsRefusedAndNothingIsSent() async throws {
        let fake = FakeProvider(rounds: ["guide": [Reply(pieces: [#"{"explanation":"Made-up answer.","steps":[]}"#])]])
        let brain = ClaudeBrain(provider: fake, map: BrainMap(open: { throw MapError.underTests }, maintenance: false), limits: limits())
        for n in 0..<30 {
            clock.now = date("2026-11-16T10:00:00Z").addingTimeInterval(Double(n))
            for try await _ in brain.answer("", packet: nil) {}
        }
        let sent = fake.requests.count
        XCTAssertEqual(sent, 30)
        clock.now = date("2026-11-16T10:00:45Z")
        do {
            for try await _ in brain.answer("", packet: nil) {}
            XCTFail("the 31st went")
        } catch {
            XCTAssertEqual(error as? BrainError, .limited(.minute))
        }
        XCTAssertEqual(fake.requests.count, sent, "nothing is sent")
        clock.now = date("2026-11-16T10:01:01Z")  // a minute after the first: room again
        for try await _ in brain.answer("", packet: nil) {}
        XCTAssertEqual(fake.requests.count, sent + 1)
    }

    @MainActor
    func testTheDailySpendCeilingRefusesWithTheRightSentence() throws {
        XCTAssertThrowsError(try limits([line("2026-11-16T08:00:00Z", usd: 2.5), line("2026-11-16T09:00:00Z", usd: 0.6)]).start()) {
            XCTAssertEqual($0 as? BrainError, .limited(.dayUSD(3)))
            XCTAssertEqual(TextCard.sentence(for: $0 as! BrainError),
                           "Today's limit is reached ($3.00). It starts again tomorrow. You can change it in the menu: Limits.")
        }
        XCTAssertEqual(TextCard.sentence(for: .limited(.minute)), "That is a lot at once. Try again in a moment.")
        defaults.set(10.0, forKey: Limits.usdKey)
        XCTAssertNoThrow(try limits([line("2026-11-16T08:00:00Z", usd: 3.1)]).start())
        defaults.set(1, forKey: Limits.requestsKey)  // one request went today, just above
        XCTAssertThrowsError(try limits().start()) { XCTAssertEqual($0 as? BrainError, .limited(.dayRequests(1))) }
        XCTAssertEqual(TextCard.sentence(for: .limited(.dayRequests(2))),
                       "Today's limit is reached (2 requests). It starts again tomorrow. You can change it in the menu: Limits.")
    }

    func testZeroMeansNoLimit() throws {
        for key in [Limits.usdKey, Limits.requestsKey, Limits.minuteKey] { defaults.set(0, forKey: key) }
        let limits = limits([line("2026-11-16T08:00:00Z", usd: 500)])
        for _ in 0..<50 { try limits.start() }
        XCTAssertNil(Limits.refusal(starts: Array(repeating: clock.now, count: 1000), spent: 1e6, now: clock.now, calendar: rome,
                                    perMinute: 0, perDay: 0, usdPerDay: 0))
        XCTAssertEqual(limits.dayLeft(), .infinity)
    }

    /// The day is the local day: it rolls over at midnight in Rome, not in UTC.
    func testTheDayRollsOverAtLocalMidnight() throws {
        defaults.set(2, forKey: Limits.requestsKey)
        // 23:58 and 23:59 in Rome are 22:58 and 22:59 UTC; 00:00:30 in Rome is still the 16th in UTC.
        let spent = [line("2026-11-16T22:00:00Z", usd: 3.5)]
        clock.now = date("2026-11-16T22:58:00Z")
        XCTAssertThrowsError(try limits(spent).start()) { XCTAssertEqual($0 as? BrainError, .limited(.dayUSD(3))) }
        let none = limits()
        try none.start()
        clock.now = date("2026-11-16T22:59:00Z")
        try none.start()
        XCTAssertThrowsError(try none.start()) { XCTAssertEqual($0 as? BrainError, .limited(.dayRequests(2))) }
        clock.now = date("2026-11-16T23:00:30Z")
        XCTAssertNoThrow(try limits(spent).start(), "yesterday's dollars and requests no longer count")
        XCTAssertEqual(limits(spent).today().spentUSD, 0)
        XCTAssertEqual(limits(spent).today().requests, 1)
    }

    /// The sum reads `ts` and `usd` only: a line it cannot read is skipped, another day's line does not count.
    func testTheDaySumReadsOnlyNumbersFromCallsLog() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "phew-limits-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let saved = CallLog.url
        CallLog.url = folder.appending(path: "calls.log")
        defer { CallLog.url = saved }
        let text = [CallLog.encode(line("2026-11-16T09:00:00Z", usd: 0.25)), CallLog.encode(line("2026-11-15T09:00:00Z", usd: 9)),
                    Data("not a line at all\n".utf8), CallLog.encode(line("2026-11-16T09:30:00Z", usd: 0.5, tier: .small))]
        try text.reduce(Data(), +).write(to: CallLog.url)
        let lines = CallLog.lines()
        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(CallLog.spent(lines, on: clock.now, calendar: rome), 0.75, accuracy: 1e-9)
        let clock = clock
        XCTAssertEqual(Limits(defaults: defaults, now: { clock.now }, calendar: rome).dayLeft(), 2.25, accuracy: 1e-9)
    }

    /// A task that would pass today's ceiling ends through its cost limit, with its report and today's line.
    func testATaskEndsWithItsReportWhenTheDayCeilingIsPassed() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "phew-limits-task-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        var limits = TaskLimits()
        limits.dayLeft = 0.10
        limits.dayCeiling = 3
        // 45,000 tokens in at $2 a million: 9 cents, past 80% of the 10 left today, so the next round writes.
        let call = #"[{"type":"tool_use","id":"toolu_1","name":"search_map","input":{"query":"kerning"}}]"#
        let fake = FakeProvider(rounds: ["runner": [Reply(blocks: call, stop: "tool_use"), Reply(pieces: ["# Kerning\nThe short answer."])]])
        let costly = Costly(fake, usage: Usage(input: 45_000))
        var report: TaskReport?
        for try await event in Runner.stream("Find sources on kerning", packet: nil, number: 9, folder: folder,
                                             tools: { RunnerTools(base: Silent()) }, provider: costly, limits: limits) {
            if case .done(let done) = event { report = done }
        }
        let done = try XCTUnwrap(report)
        XCTAssertEqual(done.limit, .cost)
        XCTAssertTrue(done.markdown.hasPrefix("# Kerning\nThe short answer."))
        XCTAssertTrue(done.markdown.hasSuffix("Phew stopped here: today's limit of $3.00 was reached."))
        XCTAssertEqual(fake.requests.map(\.toolChoice), [.auto, .none])
    }

    /// No dollars left today: the task is refused before anything is sent.
    func testATaskIsRefusedWhenNothingIsLeftToday() async throws {
        let fake = FakeProvider([:])
        let brain = ClaudeBrain(provider: fake, map: BrainMap(open: { throw MapError.underTests }, maintenance: false),
                                limits: limits([line("2026-11-16T08:00:00Z", usd: 3)]))
        do {
            for try await _ in brain.runTask("Find sources", packet: nil, number: 1, folder: nil, add: nil) {}
            XCTFail("the task ran")
        } catch {
            XCTAssertEqual(error as? BrainError, .limited(.dayUSD(3)))
        }
        XCTAssertTrue(fake.requests.isEmpty)
    }

    // MARK: D1: the one-hour cache

    func testCacheLifeFollowsTheGapsBetweenCalls() {
        let start = date("2026-11-16T08:00:00Z")
        func times(_ gaps: [Double]) -> [Date] { gaps.reduce(into: [start]) { $0.append($0.last!.addingTimeInterval($1 * 60)) } }
        XCTAssertTrue(CacheLife.hour(times(Array(repeating: 15, count: 20))), "every 15 minutes: the hour cache")
        XCTAssertFalse(CacheLife.hour(times(Array(repeating: 2, count: 40))), "every 2 minutes: the 5-minute cache stays warm")
        XCTAssertFalse(CacheLife.hour(times(Array(repeating: 180, count: 10))), "a few times a day: cold either way")
        XCTAssertFalse(CacheLife.hour(times([20] + Array(repeating: 1, count: 30))), "one pause is not enough to go on")
        // Bursts of a guide (seconds apart) between pauses of 20 minutes: the pauses decide.
        XCTAssertTrue(CacheLife.hour(times([0.1, 0.1, 20, 0.1, 0.1, 20, 0.2, 25])))
        // 3 pauses in the window against 5 over an hour: 3 > 3.125 is false.
        XCTAssertFalse(CacheLife.hour(times([20, 20, 20, 90, 90, 90, 90, 90])))
        XCTAssertTrue(CacheLife.hour(times([20, 20, 20, 20, 90, 90, 90, 90, 90])))
        XCTAssertFalse(CacheLife.hour([]))
    }

    func testStartChoosesTheCacheLifeFromMainModelCallsOnly() throws {
        let main = (0..<6).map { line(Date(timeIntervalSince1970: 1_700_000_000 + Double($0) * 900).ISO8601Format(), usd: 0) }
        try limits(main).start()
        XCTAssertTrue(CallLog.hourCache)
        let small = (0..<6).map { line(Date(timeIntervalSince1970: 1_700_000_000 + Double($0) * 900).ISO8601Format(), usd: 0, tier: .small) }
        try limits(small).start()
        XCTAssertFalse(CallLog.hourCache)
    }

    /// The exact shape from the prompt caching docs: `{"type":"ephemeral","ttl":"1h"}`, no beta header; only the
    /// system prompt's mark, which comes before every 5-minute one.
    func testTheHourMarkIsOnTheSystemPromptOnly() throws {
        let request = Guide.request("Question two", packet: nil, route: .explain, shot: nil,
                                    earlier: [Turn(question: "Question: one", answer: "Answer one")])
        let http = try ClaudeProvider.urlRequest(request, key: "test-key-not-real", hour: true)
        let sent = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(http.httpBody)) as? [String: Any])
        let system = try XCTUnwrap(sent["system"] as? [[String: Any]])
        XCTAssertEqual(system[0]["cache_control"] as? [String: String], ["type": "ephemeral", "ttl": "1h"])
        let messages = try XCTUnwrap(sent["messages"] as? [[String: Any]])
        XCTAssertEqual((messages[1]["content"] as? [[String: Any]])?.first?["cache_control"] as? [String: String], ["type": "ephemeral"])
        XCTAssertEqual(http.value(forHTTPHeaderField: "anthropic-beta"), ClaudeProvider.fallbackBeta, "no beta for the hour cache")
        let short = try ClaudeProvider.urlRequest(request, key: "test-key-not-real")
        XCTAssertFalse(String(decoding: try XCTUnwrap(short.httpBody), as: UTF8.self).contains("\"ttl\""))
    }

    /// A one-hour write costs 2x the input price, a five-minute one 1.25x; usage says which is which.
    func testTheHourWriteIsPricedApart() {
        var usage = Usage()
        usage.merge(["input_tokens": 10, "cache_creation_input_tokens": 1200,
                     "cache_creation": ["ephemeral_5m_input_tokens": 200, "ephemeral_1h_input_tokens": 1000]])
        XCTAssertEqual(usage.cacheWrite, 1200)
        XCTAssertEqual(usage.cacheWriteHour, 1000)
        let main = Tier.main.model
        XCTAssertEqual(main.cacheWriteHour, 4)
        let expected: Double = 4520 / 1_000_000  // 10 in at $2, 200 written for 5 minutes at $2.50, 1,000 for an hour at $4
        XCTAssertEqual(main.cost(usage), expected, accuracy: 1e-12)
        XCTAssertEqual(Tier.small.model.cost(Usage(cacheWrite: 1000, cacheWriteHour: 1000)), 1000 * 0.2 / 1_000_000, accuracy: 1e-12)
        let line = CallLog.line(ModelRequest(agent: "guide", tier: .main, system: "", text: "", maxTokens: 1), usage: usage,
                                msFirst: nil, msTotal: 1, stop: nil, error: nil)
        XCTAssertEqual(line.usd, 0.00452, accuracy: 1e-9)
        XCTAssertTrue(String(decoding: CallLog.encode(line), as: UTF8.self).contains(#""cache_write_hour_tokens":1000"#))
    }

    // MARK: A3: the ceiling on the whole-display picture

    func testAWholeDisplayCostsAtMost1950Tokens() {
        func tokens(_ w: Int, _ h: Int) -> Int { ((w + 27) / 28) * ((h + 27) / 28) }
        for (w, h) in [(2560, 1440), (3840, 2160), (1920, 1080), (2560, 1600), (1080, 1920)] {
            let size = ScreenshotSize(width: w, height: h, maxTokens: ScreenshotSize.displayTokens)
            XCTAssertLessThanOrEqual(tokens(size.seenWidth, size.seenHeight), 1950, "\(w)×\(h)")
            XCTAssertGreaterThan(tokens(size.seenWidth, size.seenHeight), 1800, "\(w)×\(h): not smaller than needed")
            XCTAssertEqual(Double(size.seenWidth) / Double(size.seenHeight), Double(w) / Double(h), accuracy: 0.01)
        }
        // A laptop's display fits as it is.
        let laptop = ScreenshotSize(width: 1512, height: 982, maxTokens: ScreenshotSize.displayTokens)
        XCTAssertEqual([laptop.seenWidth, laptop.seenHeight], [1512, 982])
    }

    /// The smaller picture is what goes; a point the model gives on it lands where it was on the screen.
    func testThePictureGoesSmallerAndAPointMapsBack() throws {
        let png = try picture(width: 2560, height: 1440)
        let display = CGRect(x: -2560, y: 0, width: 2560, height: 1440)  // a second display, left of the main one
        var packet = ContextPacket(appName: "Finder", bundleID: "com.apple.finder", windowTitle: "", visibleText: "", cursor: nil,
                                   screenshot: png, screenshotFrame: display)
        packet.wholeDisplay = true
        let (sent, shot) = ScreenshotSize.sent(packet)
        let size = try XCTUnwrap(shot)
        XCTAssertEqual([size.width, size.height], [2560, 1440])
        let small = try XCTUnwrap(ScreenshotSize(png: try XCTUnwrap(sent.screenshot)))
        XCTAssertEqual([small.width, small.height], [size.seenWidth, size.seenHeight])
        XCTAssertEqual([small.seenWidth, small.seenHeight], [small.width, small.height], "the API sends it on as it is")
        XCTAssertEqual(sent.screenshotFrame, display)
        // The model points at the middle of the button at screen point (-1000, 300), as seen in the smaller picture.
        let sx: Double = 1560 * Double(size.seenWidth) / 2560
        let sy: Double = 300 * Double(size.seenHeight) / 1440
        let seen = Guide.Output.Step.Point(x: Int(sx.rounded()), y: Int(sy.rounded()))
        let target = try XCTUnwrap(Guide.target(element: nil, point: seen, packet: sent, shot: shot))
        let rect = try XCTUnwrap(sent.screenRect(for: target))
        XCTAssertEqual(rect.minX, -1000, accuracy: 2)
        XCTAssertEqual(rect.minY, 300, accuracy: 2)
        // A window's picture goes as it was taken.
        packet.wholeDisplay = false
        XCTAssertEqual(ScreenshotSize.sent(packet).0.screenshot, png)
        XCTAssertEqual(ScreenshotSize.sent(packet).1, ScreenshotSize(width: 2560, height: 1440))
    }

    // MARK: Helpers

    private func picture(width: Int, height: Int) throws -> Data {
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height / 2))
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try XCTUnwrap(context.makeImage()), nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }

    /// A provider that bills each reply `usage`.
    struct Costly: ModelProvider {
        let base: any ModelProvider
        let usage: Usage
        init(_ base: any ModelProvider, usage: Usage) { (self.base, self.usage) = (base, usage) }

        func stream(_ request: ModelRequest) -> AsyncThrowingStream<ModelEvent, Error> {
            let inner = base.stream(request), usage = usage
            return AsyncThrowingStream { continuation in
                Task {
                    do {
                        for try await event in inner {
                            if case .stop = event { continuation.yield(.usage(usage)) }
                            continuation.yield(event)
                        }
                        continuation.finish()
                    } catch { continuation.finish(throwing: error) }
                }
            }
        }
    }

    /// A Map search that finds nothing.
    struct Silent: ToolRunner {
        var tools: [ToolSpec] { [.searchMap] }
        func run(_ name: String, input: Data) async throws -> String { "" }
    }
}
