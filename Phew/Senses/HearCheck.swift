#if DEBUG
import AVFoundation
import Foundation

/// One made-up spoken sentence with its made-up screen, for the hear check (P6.1, P6.3) and later Brain checks.
struct SpokenSample: Sendable {
    enum Kind: String, Sendable { case plain, interface, names }
    let language: String  // "it" or "en"
    let kind: Kind
    let text: String
    /// Control names of a made-up window in front when the sentence is said.
    let screen: [String]
    /// What the Brain should make of it (P6.3's third number): the Conductor's route, and for act what the Doer's
    /// first action is on: a control's label (a press, or a menu path starting there) or a script kind ("reminder").
    /// Nil: the first action is not scored (the sentence names an app or a list that is not on the made-up screen).
    var route = ""
    var first: String? = nil

    /// The made-up names the sentence is about, spelled right: the understood request must hold each.
    var names: [String] { SpokenSamples.names.filter { text.contains($0) } }
}

/// 40 made-up sentences, 20 Italian and 20 English: a third plain requests, a third with interface words, a third
/// with made-up names. Nothing here is anyone's real content.
enum SpokenSamples {
    /// Made-up names, as the Map would give them.
    static let names = ["Brightmoss", "Odalys Venn", "Quillfen", "Tarrow Lane", "Mirelle Okafor"]

    static let screenEN = ["TextEdit", "Format", "Bold", "Italic", "Underline", "Font Size", "Insert Table", "Done",
                           "Title", "Bullet List", "Share", "Export", "Track Changes", "Sidebar", "Text Color", "Align Center"]
    static let screenIT = ["TextEdit", "Formato", "Grassetto", "Corsivo", "Sottolineato", "Dimensione carattere",
                           "Inserisci tabella", "Fatto", "Titolo", "Elenco puntato", "Condividi", "Esporta", "Revisioni",
                           "Barra laterale", "Colore testo", "Allinea al centro"]

    static let all: [SpokenSample] = english + italian

    // kind, sentence, expected route, expected first action of an act (nil: not scored).
    typealias Row = (kind: String, text: String, route: String, first: String?)

    static let english: [SpokenSample] = ([
        ("plain", "what is this window for", "explain", nil),
        ("plain", "explain what this button does", "explain", nil),
        ("plain", "how do I save this file as a PDF", "guide", nil),
        ("plain", "why is this cell showing an error", "explain", nil),
        ("plain", "summarize the page I am reading", "explain", nil),
        ("plain", "what does this setting change", "explain", nil),
        ("plain", "show me how to share this document", "guide", nil),
        ("interface", "make the title bold and tick done", "act", "Bold"),
        ("interface", "open the format menu and choose italic", "act", "Format"),
        ("interface", "turn on track changes in the sidebar", "act", "Track Changes"),
        ("interface", "insert a table under the title", "act", "Insert Table"),
        ("interface", "change the text color to blue", "act", "Text Color"),
        ("interface", "underline the bullet list", "act", "Underline"),
        ("interface", "export the file and click share", "act", "Export"),
        ("names", "add a note to the Brightmoss project", "remember", nil),
        ("names", "send the draft to Odalys Venn", "act", "Share"),
        ("names", "open Quillfen and start a new sketch", "act", nil),
        ("names", "what did Odalys Venn say about Brightmoss", "explain", nil),
        ("names", "move the Quillfen task to Friday", "act", nil),
        ("names", "remind me to call Odalys Venn about the Brightmoss budget", "act", "reminder"),
    ] as [Row]).map { SpokenSample(language: "en", kind: .init(rawValue: $0.kind)!, text: $0.text, screen: screenEN, route: $0.route, first: $0.first) }

    static let italian: [SpokenSample] = ([
        ("plain", "a cosa serve questa finestra", "explain", nil),
        ("plain", "spiegami cosa fa questo pulsante", "explain", nil),
        ("plain", "come salvo questo file in PDF", "guide", nil),
        ("plain", "perché questa cella mostra un errore", "explain", nil),
        ("plain", "riassumi la pagina che sto leggendo", "explain", nil),
        ("plain", "cosa cambia questa impostazione", "explain", nil),
        ("plain", "mostrami come condividere questo documento", "guide", nil),
        ("interface", "apri il menu formato e scegli grassetto", "act", "Formato"),
        ("interface", "metti il titolo in corsivo e spunta fatto", "act", "Corsivo"),
        ("interface", "attiva le revisioni nella barra laterale", "act", "Revisioni"),
        ("interface", "inserisci una tabella sotto il titolo", "act", "Inserisci tabella"),
        ("interface", "cambia il colore del testo in blu", "act", "Colore testo"),
        ("interface", "sottolinea l'elenco puntato", "act", "Sottolineato"),
        ("interface", "esporta il file e premi condividi", "act", "Esporta"),
        ("names", "aggiungi una nota al progetto Brightmoss", "remember", nil),
        ("names", "manda la bozza a Odalys Venn", "act", "Condividi"),
        ("names", "apri Quillfen e inizia un nuovo schizzo", "act", nil),
        ("names", "cosa ha detto Odalys Venn su Brightmoss", "explain", nil),
        ("names", "sposta l'attività di Quillfen a venerdì", "act", nil),
        ("names", "ricordami di chiamare Odalys Venn per il budget di Brightmoss", "act", "reminder"),
    ] as [Row]).map { SpokenSample(language: "it", kind: .init(rawValue: $0.kind)!, text: $0.text, screen: screenIT, route: $0.route, first: $0.first) }

    /// The context words for a sample: its screen's control names and the made-up names.
    static func context(for sample: SpokenSample) -> [String] { sample.screen + names }

    /// Lower case, punctuation and apostrophes to spaces, one space between words. Accents are kept.
    static func words(_ text: String) -> [String] {
        text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }

    /// Word-level edit distance: substitutions, insertions and deletions.
    static func wordErrors(_ expected: [String], _ heard: [String]) -> Int {
        var row = Array(0...heard.count)
        for (i, e) in expected.enumerated() {
            var next = [i + 1]
            for (j, h) in heard.enumerated() {
                next.append(min(row[j] + (e == h ? 0 : 1), row[j + 1] + 1, next[j] + 1))
            }
            row = next
        }
        return row[heard.count]
    }
}

/// `--debug-brain-check hear`: the 40 made-up sentences spoken by the Mac's own voices into files (`say`, the Mac
/// speaking into a file, not Phew speaking), fed through `AppleListener.hear` (the microphone's path) to both
/// recognisers, without and with context words, and with context words after the sound match (N3.5). Logs numbers
/// only, then deletes the files. No microphone, no window, no model call.
enum HearCheck {
    struct Score {
        var count = 0, rightLanguage = 0, exactOwn = 0, exactTop = 0, wordErrors = 0
        var rightByConfidence = 0, rightByGuess = 0
        /// N3.5, with context only: after the sound match (N3.1), its own language exact; names right of the
        /// sentences with names; shown first (N3.3); sent at once though the best hearing was not exact.
        var exactMatched = 0, named = 0, namesRight = 0, shownFirst = 0, wrongSent = 0
        var seconds: [Double] = []
        var kinds: [String: Int] = [:]
    }

    /// Both recognisers with their models installed (waiting up to 5 minutes each), after the product's own first
    /// start. Nil when a model is missing; the reason is logged.
    @available(macOS 26, *)
    static func engines() async -> [AppleTranscriber]? {
        let it = AppleTranscriber(language: "it", locale: "it-IT"), en = AppleTranscriber(language: "en", locale: "en-US")
        // The product's own first start at launch, before anything else touched the models.
        let first = AppleListener(engines: [it, en], microphone: false)
        do {
            try await first.start(context: [], partial: { _ in })
            await first.cancel()
            shellLog("hear check: first start after launch: started")
        } catch { shellLog("hear check: first start after launch: \(error)") }
        for engine in [it, en] {
            let t0 = Date()
            let ready = await withTaskGroup(of: Bool?.self) { group in
                group.addTask { await engine.installModel() }
                group.addTask { try? await Task.sleep(for: .seconds(300)); return nil }
                let first = await group.next() ?? nil
                group.cancelAll()
                return first
            }
            shellLog("hear check: model \(engine.language) \(ready == true ? "ready" : ready == nil ? "still downloading after 5 min" : "missing") in \(Int(Date().timeIntervalSince(t0))) s")
            guard ready == true else { return nil }
        }
        return [it, en]
    }

    /// The 40 sentences spoken by the Mac's voices into a new temporary folder, one file each in `SpokenSamples.all`'s
    /// order, given to `body`; the folder is deleted after, whatever happens. Nil when a file could not be made.
    static func withSoundFiles<T>(_ body: ([URL]) async -> T) async -> T? {
        let folder = FileManager.default.temporaryDirectory.appending(path: "PhewHearCheck-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: folder)
            shellLog("hear check: sound folder deleted \(!FileManager.default.fileExists(atPath: folder.path))")
        }
        do { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) } catch {
            shellLog("hear check: no temporary folder")
            return nil
        }
        let voices = ["it": "Alice", "en": "Samantha"]
        var files: [URL] = []
        for (i, sample) in SpokenSamples.all.enumerated() {
            let file = folder.appending(path: "\(i).wav")
            let say = Process()
            say.executableURL = URL(fileURLWithPath: "/usr/bin/say")
            say.arguments = ["-v", voices[sample.language]!, "-o", file.path, "--data-format=LEI16@16000", sample.text]
            do { try say.run(); say.waitUntilExit() } catch {}
            guard say.terminationStatus == 0 else {
                shellLog("hear check: say failed for sample \(i)")
                return nil
            }
            files.append(file)
        }
        shellLog("hear check: \(files.count) sound files written, voices it Alice, en Samantha")
        return await body(files)
    }

    /// One sound file through `listener` (the microphone's path, no microphone), as fast as a voice. Nil when the
    /// listener did not start; the reason is logged as a fixed word.
    static func hear(_ file: URL, context: [String], with listener: AppleListener) async -> (heard: Heard, startMS: Int, finalSeconds: Double)? {
        let t0 = Date()
        do {
            try await listener.start(context: context, partial: { _ in })
        } catch {
            shellLog("hear check: not started, \(error)")
            return nil
        }
        let startMS = Int(Date().timeIntervalSince(t0) * 1000)
        guard let audio = try? AVAudioFile(forReading: file) else {
            await listener.cancel()
            return nil
        }
        let chunk = AVAudioFrameCount(audio.processingFormat.sampleRate / 10)
        while let buffer = AVAudioPCMBuffer(pcmFormat: audio.processingFormat, frameCapacity: chunk),
              (try? audio.read(into: buffer, frameCount: chunk)) != nil, buffer.frameLength > 0 {
            listener.hear(buffer)
            try? await Task.sleep(for: .milliseconds(100))  // as fast as a voice: one tenth of a second per tenth
        }
        let end = Date()
        let heard = await listener.stop()
        return (heard, startMS, Date().timeIntervalSince(end))
    }

    static func run() async {
        guard #available(macOS 26, *) else { return shellLog("hear check: needs macOS 26") }
        shellLog("hear check: speech permission \(ListenPermissions.speech), microphone not used")
        guard let engines = await engines() else { return }
        await withSoundFiles { files in await score(files, engines: engines) }
    }

    @available(macOS 26, *)
    static func score(_ files: [URL], engines: [AppleTranscriber]) async {
        for withContext in [false, true] {
            let pass = withContext ? "with" : "without"
            let listener = AppleListener(engines: engines, microphone: false)
            var scores: [String: Score] = [:]  // "it plain", "en names"…, "it all", "en all", and "all"
            for (i, sample) in SpokenSamples.all.enumerated() {
                guard let (heard, startMS, finalSeconds) = await hear(files[i], context: withContext ? SpokenSamples.context(for: sample) : [],
                                                                    with: listener) else {
                    shellLog("hear check: \(pass) sample \(i) not heard")
                    continue
                }

                let expected = SpokenSamples.words(sample.text)
                let own = SpokenSamples.words(heard.hearings.first { $0.language == sample.language }?.text ?? "")
                let top = SpokenSamples.words(heard.hearings.first?.text ?? "")
                let errors = SpokenSamples.wordErrors(expected, own)
                // N3.5: the sound match with the same words the recogniser had, and what N3.3 would do.
                let matched = NameMatch.apply(heard, names: SpokenSamples.context(for: sample)).hearings
                let ownMatched = SpokenSamples.words(matched.first { $0.language == sample.language }?.text ?? "")
                let shown = SendOrShow.decide(matched.first) != .send
                let namesRight = sample.names.allSatisfy { BrainVoiceCheck.holds(ownMatched, $0) }
                let byConfidence = heard.hearings.max { $0.confidence < $1.confidence }?.language
                let byGuess = heard.hearings.max { AppleListener.languageScore($0) < AppleListener.languageScore($1) }?.language
                var kinds: [String: Int] = [:]
                if heard.hearings.first?.language != sample.language { kinds["language", default: 0] += 1 }
                let nameWords = Set(SpokenSamples.names.flatMap(SpokenSamples.words))
                let screenWords = Set(sample.screen.flatMap(SpokenSamples.words))
                for word in expected where !own.contains(word) {
                    let kind = nameWords.contains(word) ? "names"
                        : screenWords.contains(word) ? "interface"
                        : own.contains { $0 != word && $0.prefix(4) == word.prefix(4) && word.count >= 4 } ? "endings" : "other"
                    kinds[kind, default: 0] += 1
                }
                for key in ["\(sample.language) \(sample.kind.rawValue)", "\(sample.language) all", "all"] {
                    var s = scores[key, default: Score()]
                    s.count += 1
                    s.rightLanguage += heard.hearings.first?.language == sample.language ? 1 : 0
                    s.rightByConfidence += byConfidence == sample.language ? 1 : 0
                    s.rightByGuess += byGuess == sample.language ? 1 : 0
                    s.exactOwn += own == expected ? 1 : 0
                    s.exactTop += top == expected ? 1 : 0
                    if withContext {
                        s.exactMatched += ownMatched == expected ? 1 : 0
                        s.named += sample.kind == .names ? 1 : 0
                        s.namesRight += sample.kind == .names && namesRight ? 1 : 0
                        s.shownFirst += shown ? 1 : 0
                        s.wrongSent += !shown && SpokenSamples.words(matched.first?.text ?? "") != expected ? 1 : 0
                    }
                    s.wordErrors += errors
                    s.seconds.append(finalSeconds)
                    s.kinds.merge(kinds, uniquingKeysWith: +)
                    scores[key] = s
                }
                let confidences = heard.hearings.map { "\($0.language) \(String(format: "%.2f", $0.confidence))" }.joined(separator: " ")
                shellLog("hear check: \(pass) #\(i) \(sample.language) \(sample.kind.rawValue): first right \(heard.hearings.first?.language == sample.language), exact \(own == expected)\(withContext ? ", after sound match exact \(ownMatched == expected), shown first \(shown)" : ""), word errors \(errors), kinds \(kinds.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: " ")), confidences [\(confidences)], start \(startMS) ms, final \(Int(finalSeconds * 1000)) ms")
            }
            for key in scores.keys.sorted() {
                let s = scores[key]!
                let median = s.seconds.sorted()[s.seconds.count / 2]
                shellLog("hear check summary \(pass) context, \(key): right language \(s.rightLanguage)/\(s.count) (by confidence alone \(s.rightByConfidence), by language guess alone \(s.rightByGuess)), exact own language \(s.exactOwn)/\(s.count), exact first hearing \(s.exactTop)/\(s.count), word errors \(s.wordErrors), median final \(String(format: "%.2f", median)) s, missed words by kind \(s.kinds.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: " "))\(withContext ? ", after sound match exact \(s.exactMatched)/\(s.count), names right \(s.namesRight)/\(s.named), shown first \(s.shownFirst), wrong sent at once \(s.wrongSent)" : "")")
            }
        }
    }
}
#endif
