import Foundation

/// A question said aloud (P6.3, the owner's choices of 15 November): transcribed on this Mac twice, as Italian and as
/// English, and both hearings go to the model, which reads them against the screen and the memory. The rule sits in
/// each agent's fixed system text, always, so the cached prefix is the same for spoken and typed requests; the
/// hearings travel in the user turn, after the words.
enum Spoken {
    /// The one rule, word for word in the Conductor, the Guide (both variants), the Doer and the Runner.
    static let rule = """
        The user's words may be followed by a <spoken> block: the user said them aloud and this Mac transcribed them \
        twice, once as Italian (it:) and once as English (en:). One hearing is in the wrong language and reads as \
        nonsense: ignore it. A word may be misheard: read the words against the screen and the memory, and when a \
        heard word makes no sense but a similar-sounding control or name is there, take that one. Never invent a \
        request the words do not make.
        """

    /// The hearings in their delimiter, one line each, best first; nil for a typed request. Filtered here, before any
    /// call, and a line cannot close the block early.
    static func block(_ hearings: [Hearing]) -> String? {
        guard !hearings.isEmpty else { return nil }
        let lines = hearings.map { "\(code($0.language)): \(SecretsFilter.clean($0.text))" }.joined(separator: "\n")
        return "<spoken>\n\(lines.replacingOccurrences(of: "</spoken>", with: "</ spoken>", options: .caseInsensitive))\n</spoken>"
    }

    /// "it-IT" or "it_IT" as "it".
    static func code(_ language: String) -> String {
        String(language.prefix { $0 != "-" && $0 != "_" }).lowercased()
    }

    /// The user turn's words with the block after them, when there is one.
    static func after(_ line: String, _ hearings: [Hearing]) -> String {
        block(hearings).map { line + "\n" + $0 } ?? line
    }
}
