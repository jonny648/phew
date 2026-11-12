/// Pulls the value of the "explanation" key out of the Guide's JSON answer while it streams, so the card can
/// show words before the whole answer has arrived. Structured outputs keep schema order, and "explanation" is
/// the first required property, so its value streams first.
struct ExplanationStream {
    private var scalars: [Unicode.Scalar] = []
    private var position: Int?  // next scalar of the value to read, once its opening quote has arrived
    private(set) var finished = false

    /// Adds a piece of JSON; returns the explanation text it completes, unescaped.
    mutating func feed(_ piece: String) -> String {
        scalars += piece.unicodeScalars
        guard !finished, let start = position ?? valueStart() else { return "" }
        var i = start
        var out = String.UnicodeScalarView()
        while i < scalars.count {
            let c = scalars[i]
            if c == "\"" { finished = true; break }
            if c != "\\" { out.append(c); i += 1; continue }
            guard let (decoded, length) = escape(at: i) else { break }  // still incomplete: wait for the next piece
            out.append(decoded)
            i += length
        }
        position = i
        return String(out)
    }

    /// Index just after the opening quote of the explanation's value, once it has arrived.
    private func valueStart() -> Int? {
        let key = Array("\"explanation\"".unicodeScalars)
        guard scalars.count >= key.count,
              var i = (0...(scalars.count - key.count)).first(where: { scalars[$0..<$0 + key.count].elementsEqual(key) })
        else { return nil }
        i += key.count
        for expected: Unicode.Scalar in [":", "\""] {
            while i < scalars.count, scalars[i].properties.isWhitespace { i += 1 }
            guard i < scalars.count, scalars[i] == expected else { return nil }
            i += 1
        }
        return i
    }

    /// The escape sequence at `i` decoded, and its length; nil while it has not fully arrived.
    private func escape(at i: Int) -> (Unicode.Scalar, Int)? {
        guard i + 1 < scalars.count else { return nil }
        let simple: [Unicode.Scalar: Unicode.Scalar] = ["\"": "\"", "\\": "\\", "/": "/", "b": "\u{8}", "f": "\u{C}",
                                                        "n": "\n", "r": "\r", "t": "\t"]
        if let s = simple[scalars[i + 1]] { return (s, 2) }
        guard scalars[i + 1] == "u" else { return ("\u{FFFD}", 2) }
        guard let high = code(at: i + 2) else { return nil }
        guard (0xD800..<0xDC00).contains(high) else { return (Unicode.Scalar(high) ?? "\u{FFFD}", 6) }
        // A surrogate pair: 😀.
        guard i + 7 < scalars.count else { return nil }
        guard scalars[i + 6] == "\\", scalars[i + 7] == "u" else { return ("\u{FFFD}", 6) }
        guard let low = code(at: i + 8) else { return nil }
        guard (0xDC00..<0xE000).contains(low) else { return ("\u{FFFD}", 6) }
        return (Unicode.Scalar(0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00)) ?? "\u{FFFD}", 12)
    }

    /// Four hex digits at `i`; nil while they have not all arrived. Bad digits read as U+FFFD.
    private func code(at i: Int) -> UInt32? {
        guard i + 4 <= scalars.count else { return nil }
        return UInt32(String(String.UnicodeScalarView(scalars[i..<i + 4])), radix: 16) ?? 0xFFFD
    }
}
