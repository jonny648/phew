import Foundation

/// An answer or a report as the card draws it (PA.6): bold, italic, code and links drawn; a heading in bold without
/// its # marks; a list line with a bullet. Line breaks are kept. Text that is not Markdown comes out unchanged.
enum CardMarkdown {
    static func attributed(_ text: String) -> AttributedString {
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
        return (try? AttributedString(markdown: lines, options: inline)) ?? AttributedString(text)
    }
}
