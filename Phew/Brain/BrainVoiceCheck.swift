#if DEBUG
import Foundation

/// `--debug-brain-check voice` (P6.3, the third number): each of the 40 made-up spoken sentences (`SpokenSamples`)
/// is spoken by the Mac's own voice into a temporary file and run through the real listener with the context words
/// (the microphone's path, no microphone), so both hearings are real, then the sound match (N3.1) as in the product. Its made-up window and both hearings then go
/// through the real Conductor, and for an act sample the Doer's first action. The files are deleted at the end.
/// Logs counts, languages, route names and fixed words only: never a hearing, a sentence or an understood line.
///
/// `--debug-brain-check voicetyped`: the Conductor on the 40 sentences typed, with its schema and system text as they
/// are and as they were before `heard`, interleaved, to see what `heard` costs the typed path.
enum BrainVoiceCheck {
    /// A made-up window for a sample: its control names as pointables, a few lines of made-up text.
    static func packet(_ sample: SpokenSample) -> ContextPacket {
        let roles = ["Done": "AXCheckBox", "Fatto": "AXCheckBox", "Track Changes": "AXCheckBox", "Revisioni": "AXCheckBox",
                     "Format": "AXMenuButton", "Formato": "AXMenuButton", "Font Size": "AXPopUpButton",
                     "Dimensione carattere": "AXPopUpButton", "Text Color": "AXColorWell", "Colore testo": "AXColorWell"]
        let controls = sample.screen.dropFirst()  // the first is the app's name
        let italian = sample.language == "it"
        return ContextPacket(
            appName: sample.screen.first ?? "TextEdit", bundleID: "com.apple.TextEdit",
            windowTitle: italian ? "Bozza di prova.rtf" : "Made-up draft.rtf",
            visibleText: italian ? "Piano di primavera\nUna bozza inventata per la prova.\n• primo punto\n• secondo punto"
                                 : "Spring plan\nA made-up draft for the check.\n• first point\n• second point",
            cursor: nil, windowFrame: CGRect(x: 0, y: 0, width: 900, height: 700),
            pointables: controls.enumerated().map { i, label in
                Pointable(id: "e\(i + 1)", role: roles[label] ?? "AXButton", label: label,
                          frame: CGRect(x: 20 + 105 * (i % 8), y: 40 + 40 * (i / 8), width: 95, height: 28))
            })
    }

    /// The first action is on the expected control: a press, set or click on it, a menu path starting there, or for
    /// "reminder" a new reminder.
    static func hits(_ next: NextAction, _ expected: String, in packet: ContextPacket) -> Bool {
        switch next {
        case .act(_, .element(let id)?, let menu, _):
            return packet.pointables.first { $0.id == id }?.label == expected || menu.first == expected
        case .act(.pick, _, let menu, _):
            return menu.first?.caseInsensitiveCompare(expected) == .orderedSame
        case .script(.reminder): return expected == "reminder"
        default: return false
        }
    }

    /// Every word of `name` in `heard`, in a row, after normalising.
    static func holds(_ heard: [String], _ name: String) -> Bool {
        let words = SpokenSamples.words(name)
        guard !words.isEmpty, heard.count >= words.count else { return false }
        return (0...(heard.count - words.count)).contains { Array(heard[$0..<($0 + words.count)]) == words }
    }

    struct Score {
        var count = 0, recogniser = 0, route = 0, acts = 0, hit = 0, named = 0, namesRight = 0, right = 0
        var exact = 0, unclear = 0, garbled = 0, missed = 0, errors = 0

        static func + (a: Score, b: Score) -> Score {
            Score(count: a.count + b.count, recogniser: a.recogniser + b.recogniser, route: a.route + b.route, acts: a.acts + b.acts,
                  hit: a.hit + b.hit, named: a.named + b.named, namesRight: a.namesRight + b.namesRight, right: a.right + b.right,
                  exact: a.exact + b.exact, unclear: a.unclear + b.unclear, garbled: a.garbled + b.garbled, missed: a.missed + b.missed,
                  errors: a.errors + b.errors)
        }

        var line: String {
            "right \(right)/\(count), recogniser with context exact \(recogniser)/\(count), route \(route)/\(count), first action \(hit)/\(acts), names understood \(namesRight)/\(named), understood line exact \(exact)/\(count), unclear \(unclear) (truly garbled \(garbled), should have been understood \(missed)), errors \(errors)"
        }
    }

    /// Stops before this much is spent in one run.
    static let budgetUSD = 0.40

    static func run() async {
        guard #available(macOS 26, *) else { return shellLog("voice check: needs macOS 26") }
        guard let engines = await HearCheck.engines() else { return shellLog("voice check: the speech models are not ready") }
        let provider = BrainSpeedCheck.Clock(ClaudeProvider()), usd0 = CallLog.spentUSD
        let scores: [String: Score]? = await HearCheck.withSoundFiles { files in
            let listener = AppleListener(engines: engines, microphone: false)
            var scores: [String: Score] = [:]
            for (i, sample) in SpokenSamples.all.enumerated() {
                guard CallLog.spentUSD - usd0 < budgetUSD else {
                    shellLog("voice check: stopped at sample \(i), budget reached")
                    break
                }
                var s = Score(count: 1)
                defer { scores["\(sample.language) \(sample.kind.rawValue)", default: Score()] = scores["\(sample.language) \(sample.kind.rawValue)", default: Score()] + s }
                guard let (heard, _, _) = await HearCheck.hear(files[i], context: SpokenSamples.context(for: sample), with: listener) else {
                    s.errors = 1
                    shellLog("voice check #\(i) \(sample.language) \(sample.kind.rawValue): not heard")
                    continue
                }
                let expected = SpokenSamples.words(sample.text)
                let own = SpokenSamples.words(heard.hearings.first { $0.language == sample.language }?.text ?? "")
                // As the product sends them: after the sound match on the same words (N3.1).
                let hearings = NameMatch.apply(heard, names: SpokenSamples.context(for: sample)).hearings
                if own == expected { s.recogniser = 1 }
                let window = packet(sample)
                let best = hearings.first?.text ?? ""
                let want = Route(rawValue: sample.route)

                var route = "none", understood: String?
                do {
                    // The words the recogniser had, as the product gives them (`ClaudeBrain`): the screen's and the memory's.
                    let got = try await Conductor.understand(best, packet: window, spoken: hearings,
                                                             names: window.spokenContext(extra: SpokenSamples.names), provider: provider)
                    route = got.route.rawValue
                    understood = got.heard
                } catch {
                    route = "error \(BrainError(error))"
                    s.errors = 1
                }
                let routeRight = route == want?.rawValue && !hearings.isEmpty
                if routeRight { s.route = 1 }
                if route == Route.unclear.rawValue {
                    s.unclear = 1
                    // Garbled: the recogniser got more than half of the sentence's words wrong in its own language.
                    if SpokenSamples.wordErrors(expected, own) * 2 > expected.count { s.garbled = 1 } else { s.missed = 1 }
                }
                let heardWords = SpokenSamples.words(understood ?? "")
                if heardWords == expected { s.exact = 1 }

                var action = "not scored"
                var actionRight = true
                if let first = sample.first {
                    s.acts = 1
                    do {
                        let next = try await Doer.next(best, packet: window, done: [], spoken: hearings, provider: provider)
                        actionRight = hits(next, first, in: window)
                        action = actionRight ? "hit" : "miss \(Self.kind(next))"
                    } catch {
                        actionRight = false
                        action = "error \(BrainError(error))"
                        s.errors = 1
                    }
                    if actionRight { s.hit = 1 }
                }
                var namesRight = true
                if sample.kind == .names {
                    s.named = 1
                    namesRight = !sample.names.isEmpty && sample.names.allSatisfy { holds(heardWords, $0) }
                    if namesRight { s.namesRight = 1 }
                }
                if routeRight && actionRight && namesRight { s.right = 1 }
                shellLog("voice check #\(i) \(sample.language) \(sample.kind.rawValue): \(hearings.count) hearings, first \(hearings.first.map { Spoken.code($0.language) } ?? "none"), recogniser exact \(own == expected), expected \(sample.route), route \(route), first action \(action), names \(sample.kind == .names ? "\(namesRight)" : "-"), understood line \(understood == nil ? "none" : "\(heardWords.count) words, exact \(heardWords == expected)"), right \(s.right == 1)")
            }
            return scores
        }
        guard let scores else { return shellLog("voice check: no sound files") }
        for key in scores.keys.sorted() { shellLog("voice check summary \(key): \(scores[key]!.line)") }
        for language in ["it", "en"] {
            let all = scores.filter { $0.key.hasPrefix(language) }.values.reduce(Score(), +)
            shellLog("voice check summary \(language) all: \(all.line)")
        }
        for kind in ["plain", "interface", "names"] {
            let all = scores.filter { $0.key.hasSuffix(kind) }.values.reduce(Score(), +)
            shellLog("voice check summary all \(kind): \(all.line)")
        }
        let total = scores.values.reduce(Score(), +)
        let conductor = provider.calls.filter { $0.agent == "conductor" }.map(\.ms).sorted()
        shellLog("voice check summary all: \(total.line); conductor median \(conductor.isEmpty ? -1 : conductor[conductor.count / 2]) ms, \(provider.calls.count) calls, $\(String(format: "%.4f", CallLog.spentUSD - usd0))")
    }

    /// A fixed word for what the Doer did instead.
    static func kind(_ next: NextAction) -> String {
        switch next {
        case .act(let kind, _, _, _): kind.rawValue
        case .script: "script"
        case .front: "open app"
        case .skill: "skill"
        case .done: "done"
        case .stuck: "stuck"
        }
    }

    // MARK: What `heard` costs a typed request

    static func typed() async {
        let provider = BrainSpeedCheck.Clock(ClaudeProvider()), usd0 = CallLog.spentUSD
        let paragraph = Conductor.system.range(of: "heard: only when").map { start in
            Conductor.system[start.lowerBound..<Conductor.system.range(of: "<spoken> block.\n", range: start.upperBound..<Conductor.system.endIndex)!.upperBound]
        }
        guard let paragraph else { return shellLog("voice typed: no heard paragraph") }
        let oldSystem = Conductor.system.replacingOccurrences(of: String(paragraph), with: "")
        let oldSchema = #"{"type":"object","properties":{"route":{"type":"string","enum":["explain","guide","remember","act","task","unclear"]}},"required":["route"],"additionalProperties":false}"#
        var withHeard: [Int] = [], without: [Int] = [], outWith = 0, outWithout = 0, cacheWith = 0, cacheWithout = 0, leaked = 0
        for (i, sample) in SpokenSamples.all.enumerated() {
            for now in (i % 2 == 0 ? [true, false] : [false, true]) {
                var request = Conductor.request(sample.text, packet: packet(sample))
                if !now { request.system = oldSystem; request.schema = oldSchema }
                let before = provider.calls.count
                let json = (try? await provider.complete(request)) ?? ""
                guard let call = provider.calls.dropFirst(before).first else { continue }
                if now {
                    withHeard.append(call.ms); outWith += call.usage.output; cacheWith += call.usage.cacheRead
                    if Conductor.heard(json) != nil { leaked += 1 }
                } else {
                    without.append(call.ms); outWithout += call.usage.output; cacheWithout += call.usage.cacheRead
                }
            }
        }
        func median(_ v: [Int]) -> Int { v.isEmpty ? -1 : v.sorted()[v.count / 2] }
        shellLog("voice typed: with heard median \(median(withHeard)) ms, output \(outWith) tokens, cache read \(cacheWith); before heard median \(median(without)) ms, output \(outWithout) tokens, cache read \(cacheWithout); typed answers that still gave heard \(leaked)/\(withHeard.count); $\(String(format: "%.4f", CallLog.spentUSD - usd0))")
    }
}
#endif
