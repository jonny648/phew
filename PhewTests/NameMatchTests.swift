import Speech
import XCTest
@testable import Phew

/// Phase N3: names matched by sound (N3.1), sure or unsure hearing (N3.3), held after routing only when it would
/// change something (N3.7), "remind me to call" (N3.4), and what
/// he learns from a correction (N3.2). Made-up names and sentences; no microphone, no model, no network, no window.
final class NameMatchTests: XCTestCase {
    private typealias FakeProvider = BrainAgentsTests.FakeProvider

    private func hearing(_ text: String, _ language: String = "en", confidence: Double = 0.95) -> Hearing {
        Hearing(language: language, text: text, confidence: confidence)
    }

    // MARK: N3.1 The recorded mishearings

    /// What the two recognisers heard on this Mac on 16 November 2026 for the 40 made-up sentences of `SpokenSamples`,
    /// said into files by the Mac's own voices (Alice, Samantha; no microphone): without the context words (false) and
    /// with them (true), both hearings best first, with the engine's confidence. Made-up content only.
    static let recorded: [(context: Bool, sample: Int, hearings: [(String, Double, String)])] = [
        (false, 0, [("en", 0.953, "What is this window for?"), ("it", 0.127, "Guarda for")]),
        (false, 1, [("en", 0.962, "Explain what this button does"), ("it", 0.208, "Ex plane the spa jazz")]),
        (false, 2, [("en", 0.938, "How do I save this file as a PDF?"), ("it", 0.270, "How do you I Say the files PDF?")]),
        (false, 3, [("en", 0.845, "Why is this cell showing an error?"), ("it", 0.163, "Wild the show")]),
        (false, 4, [("en", 0.917, "Summarize the page I am reading"), ("it", 0.314, "Sunrise the page and reading")]),
        (false, 5, [("en", 0.961, "What does this setting change?"), ("it", 0.233, "What just in change")]),
        (false, 6, [("en", 0.955, "Show me how to share this document"), ("it", 0.230, "Show the share the Stack menthe")]),
        (false, 7, [("en", 0.809, "Make the title bold and ticked on"), ("it", 0.178, "Make table the Gun")]),
        (false, 8, [("en", 0.780, "Open the format menu and choose metallic"), ("it", 0.225, "Open for menu and talk")]),
        (false, 9, [("en", 0.914, "Turn on track changes in the sidebar"), ("it", 0.161, "Change the side bar")]),
        (false, 10, [("en", 0.881, "Insert a table under the title"), ("it", 0.264, "Penso andare da tavolo")]),
        (false, 11, [("en", 0.888, "Change the text color to blue"), ("it", 0.182, "Change text Blue")]),
        (false, 12, [("en", 0.951, "Underline the bullet list"), ("it", 0.311, "Mangio online, post")]),
        (false, 13, [("en", 0.892, "Export the file and click share"), ("it", 0.181, "Export Fisher")]),
        (false, 14, [("en", 0.783, "Add a note to the bride project"), ("it", 0.207, "Dare to the Bright project")]),
        (false, 15, [("en", 0.550, "Send the draft to Dallas van"), ("it", 0.257, "Senza draft Eleven")]),
        (false, 16, [("en", 0.731, "Open Quil and start a new scratch"), ("it", 0.141, "Ho quel sta new Catch")]),
        (false, 17, [("en", 0.566, "What did Oda Van say about bride?"), ("it", 0.153, "Guarderò dalla Rimes")]),
        (false, 18, [("en", 0.673, "Move the quilt and task to Friday"), ("it", 0.456, "Molto quel fantastico Friday")]),
        (false, 19, [("en", 0.600, "Remind me to call Oda vet about the bright budget"), ("it", 0.206, "Remind me call of the Bright space")]),
        (false, 20, [("it", 0.846, "A cosa serve questa finestra?"), ("en", 0.299, "I caused a Servic with stuffy Astra")]),
        (false, 21, [("it", 0.971, "Spiegami, cosa fa questo pulsante"), ("en", 0.189, "Spiga, cause of fact")]),
        (false, 22, [("it", 0.800, "Come salvo questo file in PDF"), ("en", 0.282, "Filing PDS Request to filing PDS")]),
        (false, 23, [("it", 0.959, "Perché questa cella mostra un errore"), ("en", 0.003, "Trailer")]),
        (false, 24, [("it", 0.974, "Riassumi la pagina che sto leggendo"), ("en", 0.175, "Sumi, La Pana")]),
        (false, 25, [("it", 0.977, "Cosa cambia questa impostazione?"), ("en", 0.094, "Cause I can")]),
        (false, 26, [("it", 0.979, "Mostrami come condividere questo documento"), ("en", 0.508, "Most amigo con de request to document")]),
        (false, 27, [("it", 0.819, "Apri il menu formato e scegli grassetto"), ("en", 0.211, "Menu format Menu format")]),
        (false, 28, [("it", 0.849, "Metti il titolo in corsivo e spunta affatto"), ("en", 0.156, "Meet Punta fat")]),
        (false, 29, [("it", 0.893, "Attiva le revisioni nella barra laterale"), ("en", 0.003, "Revision")]),
        (false, 30, [("it", 0.978, "Inserisci una tabella sotto il titolo"), ("en", 0.103, "He said she not")]),
        (false, 31, [("it", 0.933, "Cambia il colore del testo in blu"), ("en", 0.433, "Gambia to")]),
        (false, 32, [("it", 0.957, "Sottolinea l'elenco puntato"), ("en", 0.169, "Sulin line Kota")]),
        (false, 33, [("it", 0.795, "Esporta i file premi, condividi"), ("en", 0.365, "His birthday finally Precon")]),
        (false, 34, [("it", 0.703, "Aggiungi una nota al progetto Brig"), ("en", 0.361, "Arjun Jana project to breathe with us")]),
        (false, 35, [("it", 0.408, "Manda la bozza della"), ("en", 0.011, "Mandela")]),
        (false, 36, [("it", 0.647, "Apri quel film, inizia un nuovo schizzo"), ("en", 0.014, "I will")]),
        (false, 37, [("it", 0.395, "Cosa ha detto Alice su Brit?"), ("en", 0.154, "Cause")]),
        (false, 38, [("it", 0.651, "Sposta l'attività di cui il Fena venerdì"), ("en", 0.019, "Spell activity")]),
        (false, 39, [("it", 0.503, "Ricordami di chiamare Hollis per il budget di Breathed"), ("en", 0.231, "Record the Marriott budget")]),
        (true, 0, [("en", 0.955, "What is this window for?"), ("it", 0.174, "Guarda for")]),
        (true, 1, [("en", 0.962, "Explain what this button does"), ("it", 0.207, "Ex plane the spa jazz")]),
        (true, 2, [("en", 0.937, "How do I save this file as a PDF?"), ("it", 0.253, "How do you I Say the files PDF?")]),
        (true, 3, [("en", 0.849, "Why is this cell showing an error?"), ("it", 0.134, "Wild the show")]),
        (true, 4, [("en", 0.920, "Summarize the page I am reading"), ("it", 0.311, "Sunrise the page and reading")]),
        (true, 5, [("en", 0.961, "What does this setting change?"), ("it", 0.216, "What just in change")]),
        (true, 6, [("en", 0.955, "Show me how to share this document"), ("it", 0.184, "Xiaomi the share the Stack menthe")]),
        (true, 7, [("en", 0.816, "Make the title bold and ticked on"), ("it", 0.174, "Make table the Gun")]),
        (true, 8, [("en", 0.909, "Open the Format menu and choose Italic"), ("it", 0.254, "Open for menu and talk")]),
        (true, 9, [("en", 0.931, "Turn on Track Changes in the Sidebar"), ("it", 0.265, "Change the Sidebar")]),
        (true, 10, [("en", 0.964, "Insert a table under the title"), ("it", 0.269, "Penso andare da tavolo")]),
        (true, 11, [("en", 0.950, "Change the Text Color to blue"), ("it", 0.181, "Change text Blue")]),
        (true, 12, [("en", 0.909, "Underline the Bullet List"), ("it", 0.307, "Mangio online, post")]),
        (true, 13, [("en", 0.881, "Export the file and click Share"), ("it", 0.176, "Export Fisher")]),
        (true, 14, [("en", 0.783, "Add a note to the bride project"), ("it", 0.206, "Dare to the Bright project")]),
        (true, 15, [("en", 0.451, "Send the draft to Oda van"), ("it", 0.260, "Senza draft Eleven")]),
        (true, 16, [("en", 0.798, "Open Quillfen and start a new scratch"), ("it", 0.207, "Ho quel sta new Catch")]),
        (true, 17, [("en", 0.619, "What did Odalys Venn say about bride?"), ("it", 0.137, "Guarderò dalla Rimes")]),
        (true, 18, [("en", 0.673, "Move the quilt and task to Friday"), ("it", 0.462, "Molto quel fantastico Friday")]),
        (true, 19, [("en", 0.682, "Remind me to call Odalys Venn about the bright budget"), ("it", 0.212, "Remind me call of the Bright space")]),
        (true, 20, [("it", 0.846, "A cosa serve questa finestra?"), ("en", 0.303, "I caused a Servic with stuffy Astra")]),
        (true, 21, [("it", 0.971, "Spiegami, cosa fa questo pulsante"), ("en", 0.291, "Spiga, cause of fact")]),
        (true, 22, [("it", 0.800, "Come salvo questo file in PDF"), ("en", 0.283, "Filing PDS Request to filing PDS")]),
        (true, 23, [("it", 0.961, "Perché questa cella mostra un errore"), ("en", 0.003, "Trailer")]),
        (true, 24, [("it", 0.974, "Riassumi la pagina che sto leggendo"), ("en", 0.219, "Sumi, La Pana")]),
        (true, 25, [("it", 0.981, "Cosa cambia questa impostazione?"), ("en", 0.097, "Cause I can")]),
        (true, 26, [("it", 0.979, "Mostrami come condividere questo documento"), ("en", 0.625, "Most amigo Condividi request to document")]),
        (true, 27, [("it", 0.927, "Apri il menu Formato e scegli Grassetto"), ("en", 0.320, "Apple menu Formato Grassetto")]),
        (true, 28, [("it", 0.849, "Metti il titolo in corsivo e spunta affatto"), ("en", 0.321, "Meet in Corsivo Punta Fatto")]),
        (true, 29, [("it", 0.836, "Attiva le revisioni nella barra laterale"), ("en", 0.201, "Attiva Revisioni")]),
        (true, 30, [("it", 0.975, "Inserisci una tabella sotto il titolo"), ("en", 0.107, "He said she not available")]),
        (true, 31, [("it", 0.930, "Cambia il colore del testo in blu"), ("en", 0.430, "Gambia to")]),
        (true, 32, [("it", 0.961, "Sottolinea l'elenco puntato"), ("en", 0.535, "Sottolineato")]),
        (true, 33, [("it", 0.899, "Esporta i file premi Condividi"), ("en", 0.374, "His birthday finally Precon DVD")]),
        (true, 34, [("it", 0.751, "Aggiungi una nota al progetto Brightmoss"), ("en", 0.339, "Arjun Jana project to breathe with us")]),
        (true, 35, [("it", 0.100, "Manda la bozza"), ("en", 0.024, "Mandela")]),
        (true, 36, [("it", 0.665, "Apri quel fieno, inizia un nuovo schizzo"), ("en", 0.015, "I will")]),
        (true, 37, [("it", 0.415, "Cosa ha detto Alice su Brightmoss?"), ("en", 0.154, "Cause")]),
        (true, 38, [("it", 0.666, "Sposta l'attività di cui il Fena venerdì"), ("en", 0.035, "Post activity")]),
        (true, 39, [("it", 0.658, "Ricordami di chiamare Odalys Venn per il budget di Brightmoss"), ("en", 0.232, "Record the Marriott budget")]),
    ]

    struct Measure: Equatable {
        /// `unsureBeforeRouting`: `SendOrShow.decide` says unsure on the best hearing. Since N3.7 that alone holds nothing:
        /// only those the Conductor then routes to act, remember or a task are shown in the ask panel.
        var exact = 0, exactMatched = 0, named = 0, namesBefore = 0, namesAfter = 0, unsureBeforeRouting = 0, wrongSent = 0
    }

    /// N3.5 offline, on the recorded hearings: the sound match with the words the recogniser had (`SpokenSamples.context`).
    static func measure(context: Bool) -> Measure {
        var m = Measure()
        for (_, i, hearings) in recorded.filter({ $0.context == context }) {
            let sample = SpokenSamples.all[i], expected = SpokenSamples.words(sample.text)
            let heard = Heard(hearings: hearings.map { Hearing(language: $0.0, text: $0.2, confidence: $0.1) })
            let matched = NameMatch.apply(heard, names: SpokenSamples.context(for: sample)).hearings
            let own = { (h: [Hearing]) in SpokenSamples.words(h.first { $0.language == sample.language }?.text ?? "") }
            m.exact += own(heard.hearings) == expected ? 1 : 0
            m.exactMatched += own(matched) == expected ? 1 : 0
            if sample.kind == .names {
                m.named += 1
                m.namesBefore += sample.names.allSatisfy { BrainVoiceCheck.holds(own(heard.hearings), $0) } ? 1 : 0
                m.namesAfter += sample.names.allSatisfy { BrainVoiceCheck.holds(own(matched), $0) } ? 1 : 0
            }
            let unsure = SendOrShow.decide(matched.first) != .send
            m.unsureBeforeRouting += unsure ? 1 : 0
            m.wrongSent += !unsure && SpokenSamples.words(matched.first?.text ?? "") != expected ? 1 : 0
        }
        return m
    }

    /// N3.1 on the 12 sentences with names and N3.5 offline on all 40. With the context words (the product's path):
    /// names right 3 before the sound match, 5 after. Under the roadmap's bar of 10: of the 7 still wrong, a common
    /// word took the name's place in 4 ("bride" twice and "bright" for Brightmoss, "Alice" for Odalys Venn), which
    /// the rule never replaces; one name was not heard at all; "quilt and" (two common words) is 0.71 from Quillfen;
    /// "il Fena" is 0.67 from Quillfen, under the threshold, and is unsure with the words marked.
    /// Pinned to the exact numbers, so a change to the match shows here. The word list is the fixed one of
    /// `CommonWords`, not this Mac's.
    func testTheRecordedHearingsMeasured() {
        XCTAssertEqual(Self.measure(context: true),
                       Measure(exact: 27, exactMatched: 28, named: 12, namesBefore: 3, namesAfter: 5, unsureBeforeRouting: 20, wrongSent: 0))
        XCTAssertEqual(Self.measure(context: false),
                       Measure(exact: 24, exactMatched: 25, named: 12, namesBefore: 0, namesAfter: 2, unsureBeforeRouting: 24, wrongSent: 0))
    }

    func testNoRightSentenceIsMadeWrong() {
        for (context, i, hearings) in Self.recorded {
            let sample = SpokenSamples.all[i], expected = SpokenSamples.words(sample.text)
            for h in hearings where h.0 == sample.language && SpokenSamples.words(h.2) == expected {
                let after = NameMatch.hearing(Hearing(language: h.0, text: h.2, confidence: h.1), names: SpokenSamples.context(for: sample))
                XCTAssertEqual(SpokenSamples.words(after.text), expected, "sample \(i), context \(context)")
            }
        }
    }

    /// N3.5, the automatic measure, live: the 40 sentences said into files by the Mac's own voices (`say` into a
    /// temporary folder, no sound, no microphone), through the real on-device recognisers without and with the context
    /// words, then the sound match. No model call, no network, no window; nothing is downloaded: it runs only when
    /// both speech models are on this Mac already. Off unless `PHEW_HEAR=1` (pass `TEST_RUNNER_PHEW_HEAR=1` to
    /// xcodebuild): about four minutes. The summary lines (numbers only) are the test's activities in the result.
    func testTheFortySentencesSpokenByTheMacsVoices() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["PHEW_HEAR"] == "1", "the spoken measure is off: about four minutes")
        guard #available(macOS 26, *) else { throw XCTSkip("needs macOS 26") }
        let installed = await DictationTranscriber.installedLocales.map { Spoken.code($0.identifier) }
        try XCTSkipUnless(installed.contains("it") && installed.contains("en"), "a speech model is not on this Mac: nothing is downloaded")
        let lines = ListenerTests.Lines()
        shellLogTap = { lines.add($0) }
        defer { shellLogTap = nil }
        let engines = [AppleTranscriber(language: "it", locale: "it-IT"), AppleTranscriber(language: "en", locale: "en-US")]
        let done: Bool? = await HearCheck.withSoundFiles { files in
            await HearCheck.score(files, engines: engines)
            return true
        }
        XCTAssertEqual(done, true)
        let summary = lines.all.filter { $0.hasPrefix("hear check summary") && $0.contains(" all:") }
        for line in summary { XCTContext.runActivity(named: line) { _ in } }
        XCTAssertTrue(summary.contains { $0.hasPrefix("hear check summary with context, all:") && $0.contains("after sound match exact") })
    }

    // MARK: N3.1 The rules

    func testATieBetweenTwoNamesChangesNothing() {
        // "Corin Vale" and "Karin Vale" have the same sound key: equally close to what was heard.
        let out = NameMatch.hearing(hearing("send it to Coreen Vail"), names: ["Corin Vale", "Karin Vale"])
        XCTAssertEqual(out.text, "send it to Coreen Vail")
        XCTAssertTrue(out.swaps.contains { $0.tied && !$0.replaced })
    }

    /// R45: the tests run on a fixed word list, set when the bundle loads, not on this Mac's lists.
    func testTheWordListIsFixedForTests() {
        XCTAssertEqual(NameMatch.fixedCommon, CommonWords.all)
        XCTAssertTrue(NameMatch.common("Window"))
        XCTAssertFalse(NameMatch.common("brightmoss"))
    }

    /// A Mac with no word lists: no word is common, so a name made of plain words is still matched, and nothing crashes.
    func testWithNoWordListNoWordIsCommon() {
        NameMatch.fixedCommon = []
        defer { CommonWords.fix() }
        XCTAssertFalse(NameMatch.common("window"))
        XCTAssertEqual(NameMatch.names(["Track Changes", "Brightmoss"]), ["Track Changes", "Brightmoss"])
    }

    /// The Mac's own lists, when present: five plain words are in them and a made-up name is not.
    func testTheMacsOwnWordLists() throws {
        NameMatch.fixedCommon = nil
        defer { CommonWords.fix() }
        try XCTSkipUnless(NameMatch.common("window") && NameMatch.common("finestra"), "this Mac has no English or Italian word list")
        for word in ["table", "color", "title", "colore", "testo"] { XCTAssertTrue(NameMatch.common(word), word) }
        XCTAssertFalse(NameMatch.common("brightmoss"))
    }

    func testCommonWordsAreLeftAlone() {
        // "brightness" is a common word, close by sound to the made-up "Brightmoss": a single common word never changes.
        let out = NameMatch.hearing(hearing("turn the brightness down"), names: ["Brightmoss", "Odalys Venn", "Quillfen"])
        XCTAssertEqual(out.text, "turn the brightness down")
        XCTAssertTrue(out.swaps.isEmpty)
        // Names that are only common words are not matched at all.
        XCTAssertEqual(NameMatch.names(["Track Changes", "Bold", "Barra laterale", "Brightmoss", "TextEdit"]), ["Brightmoss", "TextEdit"])
        // A sentence with no name in it stays as it was.
        for plain in ["what is this window for", "cambia il colore del testo in blu", "insert a table under the title"] {
            XCTAssertEqual(NameMatch.hearing(hearing(plain), names: SpokenSamples.names).text, plain)
        }
    }

    /// A word that is itself a name in the Map never becomes another way to say a different name.
    func testANameInTheMapIsNeverLearnedAsAnotherName() async throws {
        let store = try MapStore()
        try await store.add(MapNode(mapClass: .person, kind: "made up", name: "Marta Made-up", origin: .told))
        try await store.add(MapNode(mapClass: .person, kind: "made up", name: "Marco Made-up", origin: .told))
        let learned = try await store.addHeardAs("Marta Made-up", name: "Marco Made-up")
        XCTAssertFalse(learned)
        let aliases = try await store.heardAs()
        XCTAssertTrue(aliases.isEmpty)
    }

    func testAWordHeardBeforeIsReplacedExactly() {
        let out = NameMatch.hearing(hearing("call Hollis tomorrow", "it"), names: [], heardAs: ["hollis": "Odalys Venn"])
        XCTAssertEqual(out.text, "call Odalys Venn tomorrow")
        XCTAssertEqual(out.swaps.first?.closeness, 1)
    }

    func testANameAlreadyRightIsKeptAndBothHearingsAreMatched() {
        let heard = Heard(hearings: [hearing("ask Odalys Venn about bright moss", "en"), hearing("ask Odalys venne a bright moss", "it")])
        let out = NameMatch.apply(heard, names: SpokenSamples.names)
        XCTAssertEqual(out.hearings.map(\.text), ["ask Odalys Venn about Brightmoss", "ask Odalys Venn a Brightmoss"])
    }

    func testSoundKeysFitItalianAndEnglishSpellings() {
        XCTAssertEqual(NameMatch.key("Quillfen"), NameMatch.key("Quill fen"))
        XCTAssertEqual(NameMatch.key("Chiara"), NameMatch.key("Kiara"))
        XCTAssertEqual(NameMatch.key("Filippo"), NameMatch.key("Phillippo"))
        XCTAssertEqual(NameMatch.closeness("abcd", "abcd"), 1)
        XCTAssertEqual(NameMatch.closeness("abcd", "abce"), 0.75)
    }

    // MARK: N3.3 Send at once or show first

    func testTheRuleAtEachEdge() {
        let sure = SendOrShow.sure
        XCTAssertEqual(SendOrShow.decide(hearing("tick done", confidence: sure)), .send, "at the line: sent")
        XCTAssertEqual(SendOrShow.decide(hearing("tick done", confidence: sure - 0.001)), .show(doubtful: []), "under it: shown")
        XCTAssertEqual(SendOrShow.decide(hearing("tick done", confidence: 0)), .send, "no confidence given: the names decide")
        XCTAssertEqual(SendOrShow.decide(nil), .send, "nothing said: explain what is under the cursor")

        func swap(_ closeness: Double, replaced: Bool, tied: Bool = false) -> Hearing {
            var h = hearing("call Odalys Venn")
            h.swaps = [NameMatch.Swap(heard: "Dallas van", name: "Odalys Venn", closeness: closeness, replaced: replaced, tied: tied)]
            return h
        }
        let t = NameMatch.threshold, near = NameMatch.near
        XCTAssertEqual(SendOrShow.decide(swap(1, replaced: true)), .send, "exact: sure")
        XCTAssertEqual(SendOrShow.decide(swap(t + near + 0.001, replaced: true)), .send, "clear of the threshold: sent")
        XCTAssertEqual(SendOrShow.decide(swap(t + near - 0.001, replaced: true)), .show(doubtful: ["Odalys Venn"]), "just over: the name is marked")
        XCTAssertEqual(SendOrShow.decide(swap(t, replaced: true)), .show(doubtful: ["Odalys Venn"]))
        XCTAssertEqual(SendOrShow.decide(swap(t - 0.001, replaced: false)), .show(doubtful: ["Dallas van"]), "just under: the heard words are marked")
        XCTAssertEqual(SendOrShow.decide(swap(t - near + 0.001, replaced: false)), .show(doubtful: ["Dallas van"]))
        XCTAssertEqual(SendOrShow.decide(swap(t - near - 0.001, replaced: false)), .send, "far under: no name there")
        XCTAssertEqual(SendOrShow.decide(swap(0.95, replaced: false, tied: true)), .show(doubtful: ["Dallas van"]), "a tie: marked")
    }

    func testTheCheckLineMarksTheDoubtfulWords() {
        XCTAssertEqual(AppDelegate.checkLine(["Odalys Venn"]), "Did I hear “Odalys Venn” right? Fix it and press Return.")
        XCTAssertEqual(AppDelegate.checkLine([]), "Is this what you said? Fix it and press Return.")
    }

    /// N3.7: a doubtful name is no longer shown first: the sentence goes at once with its hearings, which carry the doubt
    /// for the card to hold after routing.
    @MainActor
    func testADoubtfulNameIsSentAtOnce() async {
        let listener = VoiceTests.FakeListener(heard: Heard(hearings: [hearing("send the draft to Oda van", confidence: 0.95)]))
        let talk = Talk()
        var sent: (String, [Hearing])?
        talk.listener = listener
        talk.names = { ["Odalys Venn"] }
        talk.capture = { nil }
        talk.send = { question, spoken, _ in sent = (question, spoken) }
        talk.holdStart()
        try? await Task.sleep(for: .milliseconds(50))
        talk.holdEnd()
        for _ in 0..<400 where sent == nil { try? await Task.sleep(for: .milliseconds(5)) }
        XCTAssertEqual(sent?.0, "send the draft to Odalys Venn", "the name put right, sent at once")
        XCTAssertEqual(SendOrShow.decide(sent?.1.first), .show(doubtful: ["Odalys Venn"]), "the doubt goes along: the match was close to the threshold")
    }

    // MARK: N3.7 Sent at once; held after routing only when it would change something

    /// A doubtful name: "Odalys Venn" put in place of the heard words right at the threshold.
    private func unsure() -> [Hearing] {
        var h = hearing("send the draft to Odalys Venn")
        h.swaps = [NameMatch.Swap(heard: "Oda van", name: "Odalys Venn", closeness: NameMatch.threshold, replaced: true, tied: false)]
        return [h, hearing("sent the raft to other van", "it", confidence: 0.2)]
    }

    /// The card with a Brain that gives one route. It is never put on screen; a job could not act: its app is this
    /// test's own process, which the card never acts in.
    final class RouteBrain: Brain, @unchecked Sendable {
        let route: Route
        private let lock = NSLock()
        private var asked = 0
        var actions: Int { lock.withLock { asked } }
        init(_ route: Route) { self.route = route }
        func answer(_ question: String, packet: ContextPacket?) -> AsyncThrowingStream<BrainEvent, Error> {
            let route = route
            return AsyncThrowingStream {
                $0.yield(.route(route))
                if route == .explain { $0.yield(.text("Made-up answer.")) }
                $0.yield(.done)
                $0.finish()
            }
        }
        func progress(steps: [GuideStep], current: Int, packet: ContextPacket?) async throws -> GuideProgress { GuideProgress(current: current) }
        func nextAction(_ request: String, packet: ContextPacket?, done: [String]) async throws -> NextAction {
            lock.withLock { asked += 1 }
            return .stuck("")
        }
    }

    private struct Played {
        var held: (String, [String])?
        var tasks = 0
        var text = ""
        var visible = false
        var log: [String] = []
    }

    @MainActor
    private func play(_ route: Route, spoken: [Hearing], brain: RouteBrain? = nil) async -> Played {
        let defaults = UserDefaults(suiteName: "phew-n37-test")!
        defaults.removePersistentDomain(forName: "phew-n37-test")  // acting on, as when never set
        TextCard.testWindow = (pid: getpid(), look: { _ in nil })
        let lines = ListenerTests.Lines()
        shellLogTap = { lines.add($0) }
        defer {
            TextCard.testWindow = nil
            shellLogTap = nil
            defaults.removePersistentDomain(forName: "phew-n37-test")
        }
        let card = TextCard()
        var played = Played()
        card.brain = brain ?? RouteBrain(route)
        card.consent = ActConsent(defaults: defaults)
        card.onUnsure = { heard, doubtful, _ in played.held = (heard, doubtful) }
        card.onTask = { _, _, _ in played.tasks += 1; return "" }
        card.onUnclear = { _, _ in XCTFail("not unclear") }
        card.answer(spoken.first?.text ?? "add a made-up note", spoken: spoken, capture: nil)
        for _ in 0..<400 where card.answering { try? await Task.sleep(for: .milliseconds(5)) }
        played.text = card.model.text
        played.visible = card.isVisible
        played.log = lines.all
        return played
    }

    @MainActor
    func testUnsureHearingOnExplainIsAnsweredAsIfSure() async throws {
        let played = await play(.explain, spoken: unsure())
        XCTAssertNil(played.held, "the panel is not shown")
        XCTAssertEqual(played.text, "Made-up answer.")
        // The Brain answers too: the Guide is asked.
        let fake = FakeProvider(rounds: ["conductor": [.init(pieces: [#"{"route":"explain","about_phew":false}"#])],
                                         "guide": [.init(pieces: [#"{"explanation":"Made-up answer.","steps":[]}"#])]])
        var events: [BrainEvent] = []
        for try await event in ClaudeBrain(provider: fake).answer(unsure()[0].text, packet: nil, state: ShellState(acting: true), spoken: unsure()) {
            events.append(event)
        }
        XCTAssertEqual(events.first, .route(.explain))
        XCTAssertTrue(events.contains(.text("Made-up answer.")))
        XCTAssertNil(SendOrShow.held(.guide, acting: true, spoken: unsure()))
        XCTAssertNil(SendOrShow.held(.unclear, acting: true, spoken: unsure()))
    }

    @MainActor
    func testUnsureHearingOnActActsNothingAndShowsTheHeardText() async {
        let brain = RouteBrain(.act)
        let played = await play(.act, spoken: unsure(), brain: brain)
        XCTAssertEqual(played.held?.0, "send the draft to Odalys Venn", "the heard text, the name put right")
        XCTAssertEqual(played.held?.1, ["Odalys Venn"], "the doubtful words, to mark")
        XCTAssertEqual(brain.actions, 0, "nothing acted")
        XCTAssertFalse(played.visible)
        XCTAssertTrue(played.log.contains("card: route act held, the hearing was unsure, 1 doubtful words"))
        for line in played.log { XCTAssertFalse(line.contains("Odalys") || line.contains("draft"), "no heard word in a log line") }
        XCTAssertNil(SendOrShow.held(.act, acting: false, spoken: unsure()), "acting off: a guide, which changes nothing")
    }

    @MainActor
    func testUnsureHearingOnRememberWritesNothing() async throws {
        let played = await play(.remember, spoken: unsure())
        XCTAssertEqual(played.held?.1, ["Odalys Venn"], "the panel is shown")
        // The Brain stops after the route: no Librarian, nothing in the Map.
        let store = try MapStore()
        try await store.add(MapNode(mapClass: .person, kind: "made up", name: "Odalys Venn", origin: .told))
        let before = await store.counts()
        let fake = FakeProvider(["conductor": [#"{"route":"remember","about_phew":false}"#], "observer": ["text"],
                                 "librarian": [#"{"facts":[]}"#]])
        let brain = ClaudeBrain(provider: fake, map: BrainMap(open: { store }, maintenance: false))
        var events: [BrainEvent] = []
        for try await event in brain.answer(unsure()[0].text, packet: nil, state: ShellState(acting: true), spoken: unsure()) {
            events.append(event)
        }
        XCTAssertEqual(events, [.route(.remember), .done], "nothing answered or stored")
        XCTAssertFalse(fake.requests.contains { $0.agent == "librarian" })
        let after = await store.counts()
        XCTAssertEqual(after.facts, before.facts)
        XCTAssertEqual(after.projects, before.projects)
    }

    @MainActor
    func testUnsureHearingOnTaskStartsNoTask() async {
        let played = await play(.task, spoken: unsure())
        XCTAssertEqual(played.tasks, 0, "no task started")
        XCTAssertEqual(played.held?.0, "send the draft to Odalys Venn")
    }

    @MainActor
    func testSureHearingOnActGoesOnAsToday() async throws {
        var sure = unsure()
        sure[0].swaps = []
        let played = await play(.act, spoken: sure)
        XCTAssertNil(played.held, "not held: the card goes on to the job")
        XCTAssertFalse(played.log.contains { $0.contains("held") })
        let fake = FakeProvider(["conductor": [#"{"route":"act","about_phew":false}"#], "observer": ["text"]])
        var events: [BrainEvent] = []
        for try await event in ClaudeBrain(provider: fake).answer(sure[0].text, packet: nil, state: ShellState(acting: true), spoken: sure) {
            events.append(event)
        }
        XCTAssertEqual(events, [.route(.act), .done], "the Shell starts the job, as before")
    }

    /// The panel's Return sends the text as typed (`AppDelegate.showFirst` calls `ask` with no hearings).
    @MainActor
    func testTextSentFromTheShownPanelIsNotHeldAgain() async {
        let played = await play(.task, spoken: [])
        XCTAssertNil(played.held)
        XCTAssertEqual(played.tasks, 1, "the task starts")
        for route in Route.allCases { XCTAssertNil(SendOrShow.held(route, acting: true, spoken: []), "\(route)") }
    }

    // MARK: N3.4 "Remind me to call…" makes a reminder

    func testRemindMeToCallIsRoutedToActInBothLanguages() async throws {
        XCTAssertTrue(Conductor.system.contains("\"remind me to call…\""))
        XCTAssertTrue(Conductor.system.contains("\"ricordami di chiamare…\""))
        for words in ["remind me to call Odalys Venn about the Brightmoss budget", "ricordami di chiamare Odalys Venn per il budget di Brightmoss"] {
            let fake = FakeProvider(["conductor": [#"{"route":"act","about_phew":false}"#], "observer": ["text"]])
            var events: [BrainEvent] = []
            for try await event in ClaudeBrain(provider: fake).answer(words, packet: nil, state: ShellState(acting: true)) { events.append(event) }
            XCTAssertEqual(events, [.route(.act), .done], "the Shell starts an act job; nothing is answered or remembered")
            XCTAssertFalse(fake.requests.contains { $0.agent == "librarian" }, "not stored in Phew's memory")
            let conductor = try XCTUnwrap(fake.requests.first { $0.agent == "conductor" })
            XCTAssertEqual(conductor.system, Conductor.system, "the fixed system text, the same for every request: cache-friendly")
            XCTAssertTrue(conductor.text.hasSuffix("Request: \(words)"))
        }
    }

    // MARK: N3.2 He learns from corrections

    func testACorrectionIsOneWordOrAPair() {
        XCTAssertEqual(NameMatch.correction(heard: "send the draft to Dallas van", meant: "send the draft to Odalys Venn").map { [$0.heard, $0.meant] },
                       ["Dallas van", "Odalys Venn"])
        XCTAssertEqual(NameMatch.correction(heard: "apri Quil e inizia", meant: "apri Quillfen e inizia").map { [$0.heard, $0.meant] }, ["Quil", "Quillfen"])
        XCTAssertNil(NameMatch.correction(heard: "send the draft", meant: "send the draft"), "nothing changed")
        XCTAssertNil(NameMatch.correction(heard: "send the draft to Dallas van", meant: "please open the made-up file in Pages now"),
                     "a rewritten sentence teaches nothing")
    }

    func testACorrectionIsStoredOnceUsedAtTheNextHearingAndGoneAfterForget() async throws {
        let store = try MapStore()
        let id = try await store.add(MapNode(mapClass: .person, kind: "made up", name: "Odalys Venn", origin: .told))
        try await store.add(MapNode(mapClass: .note, kind: "fact", text: "A made-up fact.", origin: .told))
        let brain = ClaudeBrain(provider: FakeProvider([:]), map: BrainMap(open: { store }, maintenance: false))

        let first = await brain.learnHeard("send the draft to Dallas van", meant: "send the draft to Odalys Venn")
        let again = await brain.learnHeard("send the draft to Dallas van", meant: "send the draft to Odalys Venn")
        XCTAssertTrue(first)
        XCTAssertFalse(again, "stored once")
        let kept = try await store.node(id).map { MapStore.heard($0.properties) }
        XCTAssertEqual(kept, ["Dallas van"])
        let rewritten = await brain.learnHeard("send the draft to Dallas van", meant: "open the made-up list in Notes please")
        let noName = await brain.learnHeard("make it blue", meant: "make it red")
        XCTAssertFalse(rewritten || noName, "no name, or a rewritten sentence: nothing kept")

        // The next hearing: a contextual string, and the same words put right exactly.
        let heardAs = await brain.heardAs()
        XCTAssertEqual(heardAs, ["Dallas van": "Odalys Venn"])
        let listener = VoiceTests.FakeListener(heard: Heard(hearings: [hearing("call Dallas van now", confidence: 0.95)]))
        let sent = await hold(listener, heardAs: heardAs)
        XCTAssertTrue(listener.context.contains("Dallas van"), "given to the recogniser")
        XCTAssertEqual(sent, "call Odalys Venn now", "put right, and sent at once: an exact match is sure")

        try await store.forget([id])
        let after = await brain.heardAs()
        XCTAssertEqual(after, [:], "gone with the name after Forget")
        let lost = await brain.learnHeard("send the draft to Dallas van", meant: "send the draft to Odalys Venn")
        XCTAssertFalse(lost, "a forgotten name learns nothing")
    }

    /// One hold through `Talk` with a fake listener; the question, sent at once.
    @MainActor
    private func hold(_ listener: VoiceTests.FakeListener, heardAs: [String: String]) async -> String? {
        let talk = Talk()
        var done = false, question: String?
        talk.listener = listener
        talk.heardAs = { heardAs }
        talk.capture = { nil }
        talk.send = { q, _, _ in question = q; done = true }
        talk.holdStart()
        try? await Task.sleep(for: .milliseconds(50))
        talk.holdEnd()
        for _ in 0..<400 where !done { try? await Task.sleep(for: .milliseconds(5)) }
        return question
    }
}
