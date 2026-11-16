import Foundation
import NaturalLanguage

/// N3.1: names matched by sound, in code, on the device, no model. After the recogniser, each heard word and each
/// pair of neighbouring words is compared with the known names (the context words that look like names: names from
/// the Map, names on screen) by a sound key that fits Italian and English spellings, and an edit distance on the keys.
/// One clear best match replaces the heard words; two names equally close, or a heard word that is itself a common
/// word, change nothing. A word heard before for a name (N3.2, `heardAs`) is replaced exactly.
/// What was matched stays on the hearing (`Hearing.swaps`), in memory only; no log holds a word of it.
enum NameMatch {
    /// One heard word or pair compared with a name. `replaced`: the hearing now holds `name` in its place.
    struct Swap: Sendable, Equatable {
        var heard: String
        var name: String
        /// 0...1: 1 is the same sound key.
        var closeness: Double
        var replaced: Bool
        /// Two names were equally close: nothing replaced.
        var tied = false
    }

    /// The least closeness that replaces.
    static let threshold = 0.75
    /// Two names this close to each other in closeness count as equally close.
    static let tie = 0.05
    /// Sound keys shorter than this are never matched: too many words sound alike.
    static let shortestKey = 4

    /// Both hearings through `hearing(_:names:heardAs:)`.
    static func apply(_ heard: Heard, names: [String], heardAs: [String: String] = [:]) -> Heard {
        let known = self.names(names, heardAs: heardAs)
        return Heard(hearings: heard.hearings.map { hearing($0, known: known, heardAs: heardAs) })
    }

    static func hearing(_ hearing: Hearing, names: [String], heardAs: [String: String] = [:]) -> Hearing {
        self.hearing(hearing, known: self.names(names, heardAs: heardAs), heardAs: heardAs)
    }

    /// The names worth matching: those with at least one word that is not a common word, deduped.
    /// The words heard before (`heardAs`) are not names: they are put right exactly.
    static func names(_ words: [String], heardAs: [String: String] = [:]) -> [String] {
        var seen = Set(heardAs.keys.map(folded))
        return words.filter { name in
            let parts = name.split(whereSeparator: \.isWhitespace)
            return (1...2).contains(parts.count) && parts.contains { !common(String($0)) } && key(name).count >= shortestKey
                && seen.insert(folded(name)).inserted
        }
    }

    private static func hearing(_ hearing: Hearing, known: [String], heardAs: [String: String]) -> Hearing {
        let text = hearing.text
        var words: [Range<String.Index>] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .byWords) { _, range, _, _ in words.append(range) }
        let exactNames = Set(known.map(folded))
        let aliases = Dictionary(heardAs.map { (folded($0.key), $0.value) }, uniquingKeysWith: { a, _ in a })

        // Every single word and pair of neighbours (only white space between them), with its best name.
        struct Found { var range: Range<String.Index>; var first: Int; var last: Int; var swap: Swap; var exact: Bool }
        var found: [Found] = []
        for first in words.indices {
            for last in first...min(first + 1, words.count - 1) {
                if last > first, !text[words[first].upperBound..<words[last].lowerBound].allSatisfy(\.isWhitespace) { continue }
                let range = words[first].lowerBound..<words[last].upperBound
                let heard = String(text[range])
                let fold = folded(heard)
                if let name = aliases[fold], first == last ? !common(heard) : true {
                    found.append(Found(range: range, first: first, last: last, swap: Swap(heard: heard, name: name, closeness: 1, replaced: true), exact: true))
                    continue
                }
                if exactNames.contains(fold) {
                    // Already right: it holds this place.
                    found.append(Found(range: range, first: first, last: last, swap: Swap(heard: heard, name: heard, closeness: 1, replaced: false), exact: true))
                    continue
                }
                // shortcut: a pair of two common words can still match ("bright moss" is how Brightmoss is heard, so it
                // must); a wrong pair match is unsure, so held before it acts, remembers or starts a task (N3.7). Upgrade if real use shows wrong swaps.
                if first == last, common(heard) { continue }
                guard key(heard).count >= shortestKey - 1 else { continue }
                let parts = (first...last).map { String(text[words[$0]]) }
                let ranked = known.map { ($0, closeness(heard: parts, to: $0)) }.sorted { $0.1 > $1.1 }
                guard let best = ranked.first, best.1 >= threshold - near else { continue }
                // A pair whose one word alone sounds as close is that word's match, not the pair's ("the brightness").
                if parts.count > 1, parts.contains(where: { closeness(heard: [$0], to: best.0) >= best.1 }) { continue }
                let tied = ranked.count > 1 && best.1 - ranked[1].1 < tie && folded(ranked[1].0) != folded(best.0)
                found.append(Found(range: range, first: first, last: last,
                                   swap: Swap(heard: heard, name: best.0, closeness: best.1, replaced: best.1 >= threshold && !tied, tied: tied),
                                   exact: false))
            }
        }

        // The closest first, a pair before a single word; a place taken is not matched again.
        var taken = Set<Int>()
        var kept: [Found] = []
        for item in found.sorted(by: { ($0.exact ? 1 : 0, $0.swap.closeness, $0.last - $0.first) > ($1.exact ? 1 : 0, $1.swap.closeness, $1.last - $1.first) }) {
            let places = Set(item.first...item.last)
            guard taken.isDisjoint(with: places) else { continue }
            if item.swap.replaced || item.exact { taken.formUnion(places) }
            if !(item.exact && !item.swap.replaced) { kept.append(item) }
        }
        var out = hearing
        var newText = text
        for item in kept.filter(\.swap.replaced).sorted(by: { $0.range.lowerBound > $1.range.lowerBound }) {
            newText.replaceSubrange(item.range, with: item.swap.name)
        }
        out.text = newText
        out.swaps = kept.sorted { $0.range.lowerBound < $1.range.lowerBound }.map(\.swap)
        return out
    }

    /// Within this of `threshold`, a match may be doubtful (N3.3), replaced or not.
    static let near = 0.1

    /// A doubtful match (N3.3): a name put in at a closeness just over the threshold; or, not put in, two names
    /// equally close over it, or one just under it where the recogniser heard a word that is not a common word (the
    /// mark of a misheard name; common words near a name are only chance).
    static func doubtful(_ swap: Swap) -> Bool {
        if swap.replaced { return swap.closeness < 1 && swap.closeness < threshold + near }
        if swap.tied, swap.closeness >= threshold { return true }
        return swap.closeness >= threshold - near && swap.heard.split(whereSeparator: \.isWhitespace).contains { !common(String($0)) }
    }

    /// N3.2: what the user changed in a heard text shown first, when the change is one word or a pair (the new words
    /// at most three, a name's length). Nil when nothing changed or the sentence was rewritten.
    static func correction(heard: String, meant: String) -> (heard: String, meant: String)? {
        let h = heard.split(whereSeparator: \.isWhitespace).map(String.init), m = meant.split(whereSeparator: \.isWhitespace).map(String.init)
        let same = { (a: String, b: String) in folded(a) == folded(b) }
        var prefix = 0
        while prefix < min(h.count, m.count), same(h[prefix], m[prefix]) { prefix += 1 }
        var suffix = 0
        while suffix < min(h.count, m.count) - prefix, same(h[h.count - 1 - suffix], m[m.count - 1 - suffix]) { suffix += 1 }
        let was = h[prefix..<(h.count - suffix)], now = m[prefix..<(m.count - suffix)]
        guard (1...2).contains(was.count), (1...3).contains(now.count) else { return nil }
        let trim = { (words: ArraySlice<String>) in words.joined(separator: " ").trimmingCharacters(in: .punctuationCharacters) }
        return (trim(was), trim(now))
    }

    // MARK: Sound

    /// A word in the system's on-device word lists of English or Italian (NaturalLanguage's word embeddings, which
    /// hold common words and no proper names).
    static func common(_ word: String) -> Bool {
        let word = word.lowercased()
        if let fixed = fixedCommon { return fixed.contains(word) }
        return lexicons.contains { $0.contains(word) }
    }

    /// Tests set a fixed list here, so they do not depend on the word lists of the Mac they run on (R45).
    nonisolated(unsafe) static var fixedCommon: Set<String>?

    // shortcut: no word lists when the system has none for a language; then no word counts as common for it.
    private static let lexicons: [NLEmbedding] = [NLLanguage.english, .italian].compactMap { NLEmbedding.wordEmbedding(for: $0) }

    /// Lower case, no accents, single spaces.
    static func folded(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .split { !$0.isLetter && !$0.isNumber }.joined(separator: " ")
    }

    /// A compact sound key for Italian and English spellings: letters that sound alike in either language become
    /// one, sounds a recogniser mixes up (voiced and unvoiced, m and n) become one, every vowel becomes "a" (so the
    /// syllables stay), a silent h goes, repeats go.
    static func key(_ text: String) -> String {
        var s = folded(text).replacingOccurrences(of: " ", with: "")
        for (from, to) in [("sch", "sk"), ("ch", "k"), ("ck", "k"), ("ph", "f"), ("gh", "g"), ("gn", "n"), ("qu", "k"),
                           ("wh", "w"), ("th", "t"), ("sh", "s"), ("ce", "se"), ("ci", "si"), ("cy", "sy"), ("x", "ks")] {
            s = s.replacingOccurrences(of: from, with: to)
        }
        var out = ""
        for c in s {
            let sound: Character?
            switch c {
            case "a", "e", "i", "o", "u", "y": sound = "a"
            case "h": sound = nil
            case "b", "p": sound = "p"
            case "d", "t": sound = "t"
            case "c", "g", "j", "k", "q": sound = "k"
            case "f", "v", "w": sound = "f"
            case "s", "z": sound = "s"
            case "m", "n": sound = "n"
            default: sound = c
            }
            if let sound, out.last != sound { out.append(sound) }
        }
        return out
    }

    /// How close heard words sound to a name: the whole keys; for two heard words and a name of two words, also word
    /// by word on average, as a recogniser that cuts one word of a name keeps the other ("Oda van" for "Odalys Venn").
    static func closeness(heard: [String], to name: String) -> Double {
        let whole = closeness(key(heard.joined()), key(name))
        let parts = name.split(whereSeparator: \.isWhitespace).map(String.init)
        guard heard.count == 2, parts.count == 2 else { return whole }
        return max(whole, (closeness(key(heard[0]), key(parts[0])) + closeness(key(heard[1]), key(parts[1]))) / 2)
    }

    /// 1 minus the edit distance over the longer key's length.
    static func closeness(_ a: String, _ b: String) -> Double {
        let a = Array(a), b = Array(b)
        guard !a.isEmpty || !b.isEmpty else { return 1 }
        var row = Array(0...b.count)
        for i in a.indices {
            var next = [i + 1]
            for j in b.indices { next.append(min(row[j] + (a[i] == b[j] ? 0 : 1), row[j + 1] + 1, next[j] + 1)) }
            row = next
        }
        return 1 - Double(row[b.count]) / Double(max(a.count, b.count))
    }
}

/// N3.3, N3.7: is the hearing of a spoken sentence sure? Decided by code, per sentence, from the best hearing: sure
/// when the recogniser is sure and no name was doubtful. A spoken sentence is always sent; an unsure one is held only
/// once the Conductor routed it to something that changes things (`held`).
enum SendOrShow: Equatable {
    case send
    /// `doubtful`: the words to mark, as they stand in the shown text; empty when only the confidence was low.
    case show(doubtful: [String])

    /// The recogniser's confidence below which a hearing is unsure. 0 means the engine gave none: then only
    /// the names decide.
    static let sure = 0.9

    static func decide(_ hearing: Hearing?) -> SendOrShow {
        guard let hearing, !hearing.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .send }
        let doubtful = hearing.swaps.filter(NameMatch.doubtful).map { $0.replaced ? $0.name : $0.heard }
        let unsure = hearing.confidence > 0 && hearing.confidence < sure
        return doubtful.isEmpty && !unsure ? .send : .show(doubtful: doubtful)
    }

    /// N3.7, the one rule after routing: an unsure hearing on a route that changes something (a job while acting is on,
    /// remember, a task) is held: nothing is done and the heard text goes to the ask panel. Returns the words to mark;
    /// nil goes on as if the hearing were sure. A typed question (`spoken` empty) is never held.
    static func held(_ route: Route, acting: Bool, spoken: [Hearing]) -> [String]? {
        guard route == .remember || route == .task || (route == .act && acting),
              case .show(let doubtful) = decide(spoken.first) else { return nil }
        return doubtful
    }
}
