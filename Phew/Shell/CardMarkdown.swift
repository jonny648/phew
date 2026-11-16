import Foundation

/// An answer or a report as the card draws it (PA.6): bold, italic, code and links drawn; a heading in bold without
/// its # marks; a list line with a bullet. Line breaks are kept. Text that is not Markdown comes out unchanged.
/// Links (R12): only http and https stay clickable, each followed by its real host in plain ASCII unless the words
/// are that very address; any other link is plain text. What an agent read is data, never a door on the Mac.
enum CardMarkdown {
    /// Parses so far, for the test that a redraw does not parse again (R51).
    nonisolated(unsafe) private(set) static var parses = 0
    /// The last texts parsed: the view body asks again on every streamed piece and typed character (R51).
    nonisolated(unsafe) private static var kept: [String: AttributedString] = [:]
    /// The kept texts, least recently asked first: a streamed answer's passing texts go before the earlier answers,
    /// which every redraw asks for again (R51).
    nonisolated(unsafe) private static var order: [String] = []
    private static let lock = NSLock()
    /// The current answer and the earlier ones of a thread (8 kept turns), with room to spare.
    private static let keptCap = 32

    static func attributed(_ text: String) -> AttributedString {
        let done = lock.withLock { () -> AttributedString? in
            guard let done = kept[text] else { return nil }
            order.removeAll { $0 == text }
            order.append(text)
            return done
        }
        if let done { return done }
        let parsed = parse(text)
        lock.withLock {
            parses += 1
            if kept[text] == nil { order.append(text) }
            kept[text] = parsed
            while order.count > keptCap { kept[order.removeFirst()] = nil }
        }
        return parsed
    }

    private static func parse(_ text: String) -> AttributedString {
        let lines = text.components(separatedBy: "\n").map { line -> String in
            let trimmed = line.drop { $0 == " " }
            let marks = trimmed.prefix { $0 == "#" }.count
            if (1...6).contains(marks), trimmed.dropFirst(marks).first == " " {
                let title = trimmed.dropFirst(marks + 1)
                return title.isEmpty || title.contains("**") ? String(title) : "**\(title)**"
            }
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                return String(repeating: " ", count: line.count - trimmed.count) + "• " + trimmed.dropFirst(2)
            }
            return line
        }.joined(separator: "\n")
        let inline = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        guard var attributed = try? AttributedString(markdown: lines, options: inline) else { return AttributedString(text) }
        // Backwards, so an added host does not move the ranges still to come.
        for (link, range) in attributed.runs[\.link].reversed() {
            guard let link else { continue }
            guard ["http", "https"].contains(link.scheme?.lowercased() ?? ""), let host = link.host(), !host.isEmpty else {
                attributed[range].link = nil
                continue
            }
            // Foundation gives the host in ASCII (look-alike letters as xn--), so it shows where the link really goes.
            let words = String(attributed[range].characters)
            if words == link.absoluteString, link.user == nil { continue }
            var shown = AttributedString(" (\(host.lowercased()))")
            shown.link = nil
            attributed.insert(shown, at: range.upperBound)
        }
        return attributed
    }
}
