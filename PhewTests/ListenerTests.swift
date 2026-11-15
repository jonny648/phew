import AVFoundation
import XCTest
@testable import Phew

/// The listener behind its seam (P6). Fake recognisers and made-up sound only: no microphone, no model.
final class ListenerTests: XCTestCase {
    /// A recogniser that reads the sound as the real one does (as it comes, keeping nothing) and says what it is told.
    final class FakeEngine: Transcribing, @unchecked Sendable {
        let language: String
        var final: Hearing
        var partials: [Hearing] = []
        var problem: ListenProblem?
        private let lock = NSLock()
        private var reader: Task<Void, Never>?
        private var seen: [Weak] = []
        private(set) var read = 0, cancels = 0
        private(set) var context: [String] = []
        /// The first sample of each piece read, in order: the tests number their pieces there.
        private(set) var firsts: [Int16] = []
        struct Weak { weak var buffer: AVAudioPCMBuffer? }
        static let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!

        init(_ language: String, _ text: String, confidence: Double = 0) {
            self.language = language
            final = Hearing(language: language, text: text, confidence: confidence)
        }

        /// Pieces of sound still alive anywhere.
        var alive: Int { lock.withLock { seen.filter { $0.buffer != nil }.count } }

        func prepare(context: [String]) async throws -> AVAudioFormat {
            if let problem { throw problem }
            self.context = context
            return Self.format
        }

        func start(sound: AsyncStream<AVAudioPCMBuffer>, partial: @escaping @Sendable (Hearing) -> Void) async throws {
            let reader = Task {
                for await buffer in sound {
                    self.lock.withLock {
                        self.seen.append(Weak(buffer: buffer))
                        self.read += 1
                        self.firsts.append(buffer.int16ChannelData?[0][0] ?? -1)
                    }
                }
            }
            lock.withLock { self.reader = reader }
            partials.forEach(partial)
        }

        func finish() async -> Hearing {
            await lock.withLock { reader }?.value
            return final
        }

        func cancel() async {
            lock.withLock { cancels += 1 }
            await lock.withLock { reader }?.value
        }
    }

    final class Lines: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [String] = []
        var all: [String] { lock.withLock { items } }
        func add(_ line: String) { lock.withLock { items.append(line) } }
    }

    /// A tenth of a second of made-up sound at the microphone's usual 48 kHz, in float, so it is converted.
    private func tone() -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4800)!
        buffer.frameLength = 4800
        for i in 0..<4800 { buffer.floatChannelData![0][i] = Float(sin(Double(i) * 0.05) * 0.2) }
        return buffer
    }

    private func listener(_ engines: [FakeEngine]) -> AppleListener { AppleListener(engines: engines, microphone: false) }

    // MARK: Ordering

    func testHearingsBestFirstByTheEnginesConfidence() async throws {
        let it = FakeEngine("it", "apri il menu formato", confidence: 0.41), en = FakeEngine("en", "open the format menu", confidence: 0.92)
        let ear = listener([it, en])
        try await ear.start(context: [], partial: { _ in })
        let heard = await ear.stop()
        XCTAssertEqual(heard.hearings.map(\.language), ["en", "it"])
        XCTAssertEqual(heard.hearings.first?.text, "open the format menu")
    }

    func testWithoutConfidenceTheLanguageGuessOrders() {
        // The English recogniser heard Italian words: its text does not read as English, so Italian comes first.
        let ranked = AppleListener.rank([Hearing(language: "en", text: "apri il menu formato e scegli grassetto", confidence: 0),
                                         Hearing(language: "it", text: "apri il menu formato e scegli grassetto", confidence: 0)])
        XCTAssertEqual(ranked.map(\.language), ["it", "en"])
        let english = AppleListener.rank([Hearing(language: "it", text: "open the format menu and choose bold", confidence: 0),
                                          Hearing(language: "en", text: "open the format menu and choose bold", confidence: 0)])
        XCTAssertEqual(english.map(\.language), ["en", "it"])
    }

    func testOneConfidenceMissingFallsBackToTheGuess() {
        let ranked = AppleListener.rank([Hearing(language: "en", text: "apri il menu formato e scegli grassetto", confidence: 0.9),
                                         Hearing(language: "it", text: "apri il menu formato e scegli grassetto", confidence: 0)])
        XCTAssertEqual(ranked.first?.language, "it")
    }

    func testEmptyWhenNothingWasSaid() async throws {
        let ear = listener([FakeEngine("it", ""), FakeEngine("en", "  ")])
        try await ear.start(context: [], partial: { _ in })
        ear.hear(tone())
        let heard = await ear.stop()
        XCTAssertEqual(heard, Heard(hearings: []))
    }

    func testStopWithoutStartIsEmpty() async {
        let heard = await listener([FakeEngine("it", "ciao")]).stop()
        XCTAssertEqual(heard.hearings, [])
    }

    func testPartialGetsTheBestHearingOnly() async throws {
        let it = FakeEngine("it", ""), en = FakeEngine("en", "")
        it.partials = [Hearing(language: "it", text: "apri il", confidence: 0.3)]
        en.partials = [Hearing(language: "en", text: "open the", confidence: 0.8)]
        let got = expectation(description: "partials")
        got.expectedFulfillmentCount = 2
        let lines = Lines()
        let ear = listener([it, en])
        try await ear.start(context: [], partial: { lines.add($0); got.fulfill() })
        await fulfillment(of: [got], timeout: 2)
        XCTAssertEqual(lines.all.last, "open the")
        await ear.cancel()
    }

    // MARK: Sound

    func testSoundDroppedAtStop() async throws {
        let it = FakeEngine("it", "uno"), en = FakeEngine("en", "one")
        let ear = listener([it, en])
        try await ear.start(context: [], partial: { _ in })
        for _ in 0..<5 { ear.hear(tone()) }
        _ = await ear.stop()
        XCTAssertGreaterThan(it.read, 0)
        XCTAssertGreaterThan(en.read, 0)
        XCTAssertEqual(it.alive + en.alive, 0, "no piece of sound is kept after stop")
        ear.hear(tone())
        XCTAssertEqual(it.alive + en.alive, 0, "sound after stop is not taken")
    }

    func testSoundDroppedAtCancel() async throws {
        let it = FakeEngine("it", "uno"), en = FakeEngine("en", "one")
        let ear = listener([it, en])
        try await ear.start(context: [], partial: { _ in })
        for _ in 0..<5 { ear.hear(tone()) }
        await ear.cancel()
        XCTAssertEqual(it.cancels, 2, "once before starting, once now")
        XCTAssertEqual(it.alive + en.alive, 0, "no piece of sound is kept after cancel")
        let heard = await ear.stop()
        XCTAssertEqual(heard.hearings, [], "nothing to return after cancel")
    }

    func testAMissingModelStopsEverything() async {
        let it = FakeEngine("it", "uno"), en = FakeEngine("en", "one")
        en.problem = .modelMissing("en")
        let ear = listener([it, en])
        do {
            try await ear.start(context: [], partial: { _ in })
            XCTFail("started without the English model")
        } catch {
            XCTAssertEqual(error as? ListenProblem, .modelMissing("en"))
        }
        XCTAssertEqual(it.cancels, 2, "the Italian recogniser is let go too")
        ear.hear(tone())
        XCTAssertEqual(it.read, 0)
    }

    // MARK: First words: the sound kept while the recognisers prepare

    /// A tenth of a second in the recognisers' own format, its first sample set to `n`, so its order can be read back.
    private func piece(_ n: Int) -> AVAudioPCMBuffer {
        let buffer = AVAudioPCMBuffer(pcmFormat: FakeEngine.format, frameCapacity: 1600)!
        buffer.frameLength = 1600
        for i in 0..<1600 { buffer.int16ChannelData![0][i] = i == 0 ? Int16(n) : Int16(i % 50) }
        return buffer
    }

    /// Starts `ear` with a context that waits for `gate`; returns once the context is asked, so sound is being kept.
    private func startWaiting(_ ear: AppleListener, words: [String] = ["Formato"]) async -> (Task<Void, Error>, AsyncStream<Void>.Continuation) {
        let (gate, open) = AsyncStream<Void>.makeStream()
        let asked = expectation(description: "context asked")
        let started = Task {
            try await ear.start(context: {
                asked.fulfill()
                for await _ in gate { break }
                return words
            }, partial: { _ in })
        }
        await fulfillment(of: [asked], timeout: 2)
        return (started, open)
    }

    func testSoundBeforeTheRecognisersAreReadyIsDeliveredInOrderNoneLost() async throws {
        let it = FakeEngine("it", "uno"), en = FakeEngine("en", "one")
        let ear = listener([it, en])
        let (started, open) = await startWaiting(ear)
        for n in 0..<5 { ear.hear(piece(n)) }
        XCTAssertEqual(ear.keptNow, 0.5, accuracy: 0.001)
        XCTAssertEqual(it.read + en.read, 0, "nothing reaches a recogniser before it is ready")
        open.yield(())
        try await started.value
        XCTAssertEqual(ear.keptNow, 0, "handed on and let go")
        for n in 5..<8 { ear.hear(piece(n)) }
        _ = await ear.stop()
        XCTAssertEqual(it.firsts, (0..<8).map(Int16.init), "kept sound first, in order, then the live sound")
        XCTAssertEqual(en.firsts, (0..<8).map(Int16.init))
        XCTAssertEqual(it.context, ["Formato"], "prepared with the context given late")
        XCTAssertEqual(it.alive + en.alive, 0)
    }

    func testKeptSoundIsCappedAtTenSeconds() async throws {
        let it = FakeEngine("it", "uno")
        let ear = listener([it])
        let (started, open) = await startWaiting(ear)
        for n in 0..<120 { ear.hear(piece(n)) }
        XCTAssertEqual(ear.keptNow, AppleListener.keptCap, accuracy: 0.001)
        open.yield(())
        try await started.value
        _ = await ear.stop()
        XCTAssertEqual(it.firsts, (0..<100).map(Int16.init), "the first 10 s, the rest dropped")
    }

    func testKeptSoundDroppedAtCancelAndStopWhilePreparing() async throws {
        for ends in ["cancel", "stop"] {
            let it = FakeEngine("it", "uno"), en = FakeEngine("en", "one")
            let ear = listener([it, en])
            let (started, open) = await startWaiting(ear)
            for n in 0..<5 { ear.hear(piece(n)) }
            if ends == "cancel" {
                await ear.cancel()
            } else {
                let heard = await ear.stop()
                XCTAssertEqual(heard.hearings, [], ends)
            }
            XCTAssertEqual(ear.keptNow, 0, "\(ends): the kept sound is dropped at once")
            open.yield(())
            do {
                try await started.value
                XCTFail("\(ends): started after the hold ended")
            } catch {
                XCTAssertEqual(error as? ListenProblem, .failed, ends)
            }
            ear.hear(piece(9))
            XCTAssertEqual(it.read + en.read, 0, "\(ends): no piece reached a recogniser")
            XCTAssertEqual(ear.keptNow, 0)
        }
    }

    // MARK: Context

    func testContextCappedAndFiltered() {
        let many = (0..<150).map { "Word\($0)" }
        let words = ContextPacket.spokenWords(["Bold", "bold", "sk-ant-api03-abcdefghijklmnopqrstuvwxyz",
                                               String(repeating: "x", count: 41), "Two\nlines", "  "] + many)
        XCTAssertEqual(words.count, 100)
        XCTAssertEqual(Array(words.prefix(3)), ["Bold", "Two lines", "Word0"])
        XCTAssertTrue(words.allSatisfy { $0.count <= 40 })
        XCTAssertFalse(words.contains { $0.contains("sk-") || $0.contains("removed") })
    }

    func testSpokenContextFromAPacket() {
        var packet = ContextPacket(appName: "Quillfen", bundleID: "com.example.quillfen",
                                   windowTitle: "Brightmoss plan 2026 — Edited", visibleText: "", cursor: nil)
        packet.pointables = [Pointable(role: "AXButton", label: "Bold", frame: .zero),
                             Pointable(role: "AXButton", label: "bold", frame: .zero),
                             Pointable(role: "AXTextField", label: "token ghp_abcdefghijklmnopqrstuvwxyz0123", frame: .zero)]
        XCTAssertEqual(packet.spokenContext(extra: ["Odalys Venn"]), ["Quillfen", "Odalys Venn", "Brightmoss", "plan", "Bold"])
    }

    func testTheListenerGivesTheCleanedContextToBothLanguages() async throws {
        let it = FakeEngine("it", ""), en = FakeEngine("en", "")
        let ear = listener([it, en])
        try await ear.start(context: ["Formato", "Formato", "pin 4421"], partial: { _ in })
        await ear.cancel()
        XCTAssertEqual(it.context, ["Formato"])
        XCTAssertEqual(en.context, ["Formato"])
    }

    // MARK: Logs

    func testNoHeardWordAndNoContextWordInAnyLogLine() async throws {
        let lines = Lines()
        shellLogTap = { lines.add($0) }
        defer { shellLogTap = nil }
        let it = FakeEngine("it", "Vexillo frambine", confidence: 0.7), en = FakeEngine("en", "Vexill of rambine", confidence: 0.4)
        it.partials = [Hearing(language: "it", text: "Vexillo", confidence: 0.5)]
        let ear = listener([it, en])
        try await ear.start(context: ["Zorblat", "Quenmoor"], partial: { _ in })
        ear.hear(tone())
        _ = await ear.stop()
        try await ear.start(context: ["Zorblat"], partial: { _ in })
        await ear.cancel()
        XCTAssertFalse(lines.all.isEmpty)
        for line in lines.all {
            for word in ["Vexill", "frambine", "rambine", "Zorblat", "Quenmoor"] {
                XCTAssertFalse(line.contains(word), "\(word) in a log line")
            }
        }
    }
}
