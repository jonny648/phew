import AVFoundation
import NaturalLanguage
import Speech

// P6: hold a key, speak, release. Speech to text on the device only. The sound lives in memory while the key is held
// and is dropped at stop or cancel; it is never written to disk and never sent. No log line holds a heard word or a
// context word: counts, languages, confidences and fixed words only.

/// What one language's recogniser heard.
struct Hearing: Sendable, Equatable {
    var language: String   // "it" or "en"
    var text: String
    var confidence: Double  // 0...1, 0 when the engine gives none
}

/// Both languages' hearings, best first; empty when nothing was said.
struct Heard: Sendable, Equatable { var hearings: [Hearing] }

/// The door the Shell listens through, so a later engine swap changes nothing there.
protocol Listening: AnyObject, Sendable {
    /// Starts listening now. `context`: words that matter now (control names, app name, names from memory). `partial` is called on the main actor with what is heard so far, best hearing only.
    func start(context: [String], partial: @escaping @MainActor (String) -> Void) async throws
    /// Stops, returns the final hearings, drops the sound.
    func stop() async -> Heard
    /// Stops and returns nothing; drops the sound.
    func cancel() async
}

enum ListenProblem: Error, Equatable { case noMicrophone, noSpeechPermission, modelMissing(String) /* language */, failed }

/// One recogniser for one language. The seam the unit tests fake; Apple's types stay behind it.
protocol Transcribing: AnyObject, Sendable {
    var language: String { get }
    /// Loads the on-device model with the context words. Returns the audio format it reads. Throws `ListenProblem`.
    func prepare(context: [String]) async throws -> AVAudioFormat
    /// Starts reading `sound` (already in the prepared format). `partial` gets what is heard so far.
    func start(sound: AsyncStream<AVAudioPCMBuffer>, partial: @escaping @Sendable (Hearing) -> Void) async throws
    /// After `sound` has ended: the final hearing. Drops everything it held.
    func finish() async -> Hearing
    /// Stops at once and drops everything it held. Safe to call when not started.
    func cancel() async
}

/// Microphone through AVAudioEngine into one on-device recogniser per language (Italian and English) at once.
/// The sound passes through in memory: each piece is converted, handed on and not kept; the streams are closed and
/// dropped at stop and cancel.
final class AppleListener: Listening, @unchecked Sendable {
    private let engines: [any Transcribing]
    private let microphone: Bool
    private let lock = NSLock()
    private var feeds: [Feed] = []
    private var audio: AVAudioEngine?
    private var latest: [String: Hearing] = [:]
    private var seconds = 0.0

    /// One open stream into one recogniser, with its converter from the microphone's format.
    private struct Feed {
        let format: AVAudioFormat
        let continuation: AsyncStream<AVAudioPCMBuffer>.Continuation
        var converter: AVAudioConverter?
    }

    /// The product listener: the microphone, Italian and English.
    convenience init() {
        if #available(macOS 26, *) {
            self.init(engines: [AppleTranscriber(language: "it", locale: "it-IT"), AppleTranscriber(language: "en", locale: "en-US")])
        } else {
            // shortcut: no voice before macOS 26 (no SpeechAnalyzer); an SFSpeechRecognizer engine behind `Transcribing` if needed.
            self.init(engines: [])
        }
    }

    /// `microphone: false` is for the hear check and the tests: sound comes only through `hear(_:)`.
    init(engines: [any Transcribing], microphone: Bool = true) {
        self.engines = engines
        self.microphone = microphone
    }

    func start(context: [String], partial: @escaping @MainActor (String) -> Void) async throws {
        await cancel()
        guard !engines.isEmpty else { throw ListenProblem.failed }
        let words = ContextPacket.spokenWords(context)
        do {
            var opened: [Feed] = []
            var streams: [AsyncStream<AVAudioPCMBuffer>] = []
            for engine in engines {
                let format = try await engine.prepare(context: words)
                let (stream, continuation) = AsyncStream<AVAudioPCMBuffer>.makeStream()
                opened.append(Feed(format: format, continuation: continuation))
                streams.append(stream)
            }
            lock.withLock { feeds = opened; latest = [:]; seconds = 0 }
            for (engine, stream) in zip(engines, streams) {
                try await engine.start(sound: stream) { [weak self] hearing in self?.heardSoFar(hearing, partial) }
            }
            if microphone { try startMicrophone() }
        } catch {
            await cancel()
            let problem = error as? ListenProblem ?? .failed
            shellLog("listen: not started, \(problem)")
            throw problem
        }
        shellLog("listen: started, \(engines.count) languages, \(words.count) context words")
    }

    func stop() async -> Heard {
        let (opened, heardSeconds) = close()
        guard !opened.isEmpty else { return Heard(hearings: []) }
        let hearings = await withTaskGroup(of: Hearing.self) { group in
            for engine in engines { group.addTask { await engine.finish() } }
            return await group.reduce(into: [Hearing]()) { $0.append($1) }
        }
        let heard = Heard(hearings: Self.rank(hearings))
        let confidences = heard.hearings.map { "\($0.language) \(String(format: "%.2f", $0.confidence))" }.joined(separator: ", ")
        shellLog("listen: stopped, \(String(format: "%.1f", heardSeconds)) s of sound, \(heard.hearings.count) hearings, first \(heard.hearings.first?.language ?? "none"), confidences [\(confidences)]")
        return heard
    }

    func cancel() async {
        let (opened, _) = close()
        for engine in engines { await engine.cancel() }
        if !opened.isEmpty { shellLog("listen: cancelled") }
    }

    /// Where the sound comes in: the microphone's tap, or a file in the hear check. Any thread. Each piece is
    /// converted into a new buffer (the tap may reuse its own) and handed to every recogniser; none is kept here.
    func hear(_ buffer: AVAudioPCMBuffer) {
        lock.withLock {
            guard !feeds.isEmpty, buffer.format.sampleRate > 0 else { return }
            seconds += Double(buffer.frameLength) / buffer.format.sampleRate
            for i in feeds.indices {
                if feeds[i].converter?.inputFormat != buffer.format {
                    feeds[i].converter = AVAudioConverter(from: buffer.format, to: feeds[i].format)
                }
                if let converter = feeds[i].converter, let out = Self.convert(buffer, with: converter) {
                    feeds[i].continuation.yield(out)
                }
            }
        }
    }

    /// Stops the microphone and ends every stream; the streams and their sound are dropped with them.
    private func close() -> ([Feed], Double) {
        let engine = lock.withLock { () -> AVAudioEngine? in defer { audio = nil }; return audio }
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        return lock.withLock {
            let opened = feeds
            feeds = []
            latest = [:]
            opened.forEach { $0.continuation.finish() }
            return (opened, seconds)
        }
    }

    private func heardSoFar(_ hearing: Hearing, _ partial: @escaping @MainActor (String) -> Void) {
        let best: String? = lock.withLock {
            guard !feeds.isEmpty else { return nil }  // a late partial after stop or cancel
            latest[hearing.language] = hearing
            return Self.rank(Array(latest.values)).first?.text ?? ""
        }
        if let best { Task { @MainActor in partial(best) } }
    }

    private func startMicrophone() throws {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else { throw ListenProblem.noMicrophone }
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else { throw ListenProblem.noMicrophone }
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in self?.hear(buffer) }
        engine.prepare()
        do { try engine.start() } catch {
            input.removeTap(onBus: 0)
            throw ListenProblem.noMicrophone
        }
        lock.withLock { audio = engine }
    }

    /// Best first. Empty hearings are dropped. When every hearing has the engine's own confidence, the higher
    /// confidence wins. Otherwise a cheap guess: the system's on-device language recogniser (NaturalLanguage) scores
    /// how much each text reads like the language its recogniser listened for; the higher score wins. Ties keep the
    /// engines' order (Italian first).
    static func rank(_ hearings: [Hearing]) -> [Hearing] {
        let said = hearings.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let byConfidence = said.allSatisfy { $0.confidence > 0 }
        let order = ["it", "en"]
        func score(_ h: Hearing) -> Double { byConfidence ? h.confidence : languageScore(h) }
        func place(_ h: Hearing) -> Int { order.firstIndex(of: h.language) ?? order.count }
        return said.sorted { (score($0), -place($0)) > (score($1), -place($1)) }
    }

    /// 0...1: how much `hearing.text` reads like its own language, by the on-device language recogniser.
    static func languageScore(_ hearing: Hearing) -> Double {
        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = [.italian, .english]
        recognizer.processString(hearing.text)
        let hypotheses = recognizer.languageHypotheses(withMaximum: 2)
        return hypotheses[hearing.language == "it" ? .italian : .english] ?? 0
    }

    /// One buffer into the recogniser's format, as a new buffer. Nil when nothing came out.
    static func convert(_ buffer: AVAudioPCMBuffer, with converter: AVAudioConverter) -> AVAudioPCMBuffer? {
        let ratio = converter.outputFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 16
        guard let out = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: capacity) else { return nil }
        var given = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if given { status.pointee = .noDataNow; return nil }
            given = true
            status.pointee = .haveData
            return buffer
        }
        return error == nil && out.frameLength > 0 ? out : nil
    }
}

/// One language through Apple's on-device `DictationTranscriber` (Speech framework, macOS 26). Chosen over
/// `SpeechTranscriber` because Apple documents contextual strings (`AnalysisContext.contextualStrings`) for this
/// module only. On-device by construction: the module "does not support languages or locales that SFSpeechRecognizer
/// only supports via network access". When the model is not installed, Apple's own download is started and
/// `modelMissing` is thrown until it is there.
@available(macOS 26, *)
final class AppleTranscriber: Transcribing, @unchecked Sendable {
    let language: String
    private let localeID: String
    private let lock = NSLock()
    private var module: DictationTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var reader: Task<Hearing, Never>?
    private static let downloading = NSLock()
    nonisolated(unsafe) private static var started: Set<String> = []

    init(language: String, locale: String) {
        self.language = language
        self.localeID = locale
    }

    func prepare(context: [String]) async throws -> AVAudioFormat {
        guard let locale = await DictationTranscriber.supportedLocale(equivalentTo: Locale(identifier: localeID)) else {
            throw ListenProblem.modelMissing(language)
        }
        let module = DictationTranscriber(locale: locale, contentHints: [.shortForm], transcriptionOptions: [.punctuation],
                                          reportingOptions: [.volatileResults], attributeOptions: [.transcriptionConfidence])
        guard try await Self.modelReady(module, language: language, wait: false) else { throw ListenProblem.modelMissing(language) }
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module]) else {
            throw ListenProblem.modelMissing(language)
        }
        let analysis = AnalysisContext()
        analysis.contextualStrings = [.general: context]
        let analyzer = SpeechAnalyzer(modules: [module], options: .init(priority: .userInitiated, modelRetention: .lingering))
        do {
            try await analyzer.setContext(analysis)
            try await analyzer.prepareToAnalyze(in: format)
        } catch {
            await analyzer.cancelAndFinishNow()
            throw Self.problem(error, language)
        }
        lock.withLock { self.module = module; self.analyzer = analyzer }
        return format
    }

    func start(sound: AsyncStream<AVAudioPCMBuffer>, partial: @escaping @Sendable (Hearing) -> Void) async throws {
        guard let (module, analyzer) = lock.withLock({ self.module.flatMap { m in self.analyzer.map { (m, $0) } } }) else {
            throw ListenProblem.failed
        }
        let language = language
        let reader = Task {
            // Each result replaces what was heard from its start on. On macOS 27.2 this transcriber never marks a
            // result final (`isFinal` stays false, `resultsFinalizationTime` 0), so the latest result counts; the
            // last one, after the end of the sound, carries the confidences.
            var segments: [(start: Double, text: AttributedString)] = []
            var now: AttributedString { segments.reduce(into: AttributedString()) { $0 += $1.text } }
            do {
                for try await result in module.results {
                    let start = result.range.start.isNumeric ? result.range.start.seconds : 0
                    segments.removeAll { $0.start >= start }
                    segments.append((start, result.text))
                    let text = now
                    partial(Hearing(language: language, text: Self.plain(text), confidence: Self.confidence(text)))
                }
            } catch is CancellationError {
            } catch {
                shellLog("listen: \(language) results ended with an error, \(type(of: error))")
            }
            let text = now
            return Hearing(language: language, text: Self.plain(text), confidence: Self.confidence(text))
        }
        lock.withLock { self.reader = reader }
        do {
            try await analyzer.start(inputSequence: sound.map { AnalyzerInput(buffer: $0) })
        } catch {
            await cancel()
            throw Self.problem(error, language)
        }
    }

    func finish() async -> Hearing {
        let (analyzer, reader) = lock.withLock { (self.analyzer, self.reader) }
        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        let hearing = await reader?.value ?? Hearing(language: language, text: "", confidence: 0)
        lock.withLock { self.analyzer = nil; self.reader = nil; self.module = nil }
        return hearing
    }

    func cancel() async {
        let (analyzer, reader) = lock.withLock { () -> (SpeechAnalyzer?, Task<Hearing, Never>?) in
            defer { self.analyzer = nil; self.reader = nil; self.module = nil }
            return (self.analyzer, self.reader)
        }
        await analyzer?.cancelAndFinishNow()
        reader?.cancel()
    }

    /// True when the model is installed. Otherwise starts Apple's download once per language and, with `wait`,
    /// waits for it (the hear check); without, returns false at once (the product reports `modelMissing`).
    static func modelReady(_ module: DictationTranscriber, language: String, wait: Bool) async throws -> Bool {
        switch await AssetInventory.status(forModules: [module]) {
        case .installed: return true
        case .unsupported: return false
        case .supported, .downloading: break
        @unknown default: return false
        }
        let first = downloading.withLock { started.insert(language).inserted }
        guard first || wait else { return false }
        shellLog("listen: model for \(language) not installed, asking the system to download it")
        let download = Task {
            defer { _ = downloading.withLock { started.remove(language) } }
            do {
                try await AssetInventory.assetInstallationRequest(supporting: [module])?.downloadAndInstall()
                shellLog("listen: model for \(language) installed")
            } catch {
                shellLog("listen: model download for \(language) failed, \(type(of: error))")
            }
        }
        if !wait {
            // Seen on macOS 27.2: status says "supported" at each launch even with the model on the Mac, and the
            // "download" then ends in under 0.1 s. A short wait spares the user a first "model missing".
            let quick = await withTaskGroup(of: Bool.self) { group in
                group.addTask { await download.value; return true }
                group.addTask { try? await Task.sleep(for: .seconds(2)); return false }
                let first = await group.next() ?? false
                group.cancelAll()
                return first
            }
            return quick ? await AssetInventory.status(forModules: [module]) == .installed : false
        }
        await download.value
        return await AssetInventory.status(forModules: [module]) == .installed
    }

    /// Wait-for-download variant for the hear check.
    func installModel() async -> Bool {
        guard let locale = await DictationTranscriber.supportedLocale(equivalentTo: Locale(identifier: localeID)) else { return false }
        let module = DictationTranscriber(locale: locale, preset: .shortDictation)
        return (try? await Self.modelReady(module, language: language, wait: true)) ?? false
    }

    private static func problem(_ error: Error, _ language: String) -> ListenProblem {
        if let problem = error as? ListenProblem { return problem }
        let code = (error as NSError).code
        if (error as NSError).domain == SFSpeechError.errorDomain,
           [SFSpeechError.Code.noModel, .assetLocaleNotAllocated, .cannotAllocateUnsupportedLocale].map(\.rawValue).contains(code) {
            return .modelMissing(language)
        }
        shellLog("listen: \(language) recogniser error, domain \((error as NSError).domain) code \(code)")
        return .failed
    }

    private static func plain(_ text: AttributedString) -> String {
        String(text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The engine's confidence, averaged over the text weighted by length; 0 when it gave none.
    private static func confidence(_ text: AttributedString) -> Double {
        var sum = 0.0, count = 0
        for run in text.runs {
            guard let value = run.transcriptionConfidence else { continue }
            let length = text[run.range].characters.count
            sum += value * Double(length)
            count += length
        }
        return count > 0 ? sum / Double(count) : 0
    }
}

/// Microphone and Speech Recognition permissions, for the first-run panel. Asking shows the system's own prompt.
enum ListenPermissions {
    enum State: Sendable, Equatable { case allowed, denied, notAsked }

    static var microphone: State {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: .allowed
        case .notDetermined: .notAsked
        default: .denied
        }
    }

    static var speech: State {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: .allowed
        case .notDetermined: .notAsked
        default: .denied
        }
    }

    static func askMicrophone() async -> Bool { await AVCaptureDevice.requestAccess(for: .audio) }

    static func askSpeech() async -> Bool {
        await withCheckedContinuation { done in
            SFSpeechRecognizer.requestAuthorization { done.resume(returning: $0 == .authorized) }
        }
    }
}

extension ContextPacket {
    /// Words the recogniser should expect now: the app's name, `extra` (names from the Map, given by the Brain), the
    /// distinctive words of the window title and the window's control names. Secrets-filtered, deduped, each at most
    /// 40 characters, at most 100 (Apple's limit for contextual strings). Empty for an app on the never-read list
    /// beyond its name.
    func spokenContext(extra: [String] = []) -> [String] {
        let titleWords = windowTitle.split { !$0.isLetter && !$0.isNumber && $0 != "'" && $0 != "’" }
            .map(String.init)
            .filter { $0.count >= 3 && !$0.allSatisfy(\.isNumber) && !Self.plainTitleWords.contains($0.lowercased()) }
        return Self.spokenWords([appName] + extra + titleWords + pointables.map(\.label))
    }

    /// Cleans a list of context words: secrets filtered (a word that held one is dropped), one line, trimmed,
    /// at most 40 characters (longer ones are dropped: Apple says long phrases are rarely recognised), deduped
    /// ignoring case, the first 100 kept.
    static func spokenWords(_ words: [String]) -> [String] {
        var seen: Set<String> = []
        var kept: [String] = []
        for word in words where kept.count < spokenCap {
            let cleaned = SecretsFilter.clean(word)
            guard cleaned == word else { continue }
            let line = word.split(whereSeparator: \.isNewline).joined(separator: " ").trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, line.count <= spokenLength, seen.insert(line.lowercased()).inserted else { continue }
            kept.append(line)
        }
        return kept
    }

    static let spokenCap = 100
    static let spokenLength = 40
    private static let plainTitleWords: Set<String> = [
        "the", "and", "for", "with", "from", "untitled", "edited", "copy", "document", "window",
        "con", "per", "una", "uno", "della", "delle", "dello", "degli", "senza", "titolo", "modificato", "copia",
    ]
}
