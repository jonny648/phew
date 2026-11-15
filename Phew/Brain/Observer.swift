import Foundation

/// Turns a long packet's visible text into a shorter clean one that keeps what matters for the question.
/// Small model. Never fails the request: on any problem the original text goes on to the Guide.
enum Observer {
    /// Up to this many characters the text is short enough for the Guide as it is. It is the packet's own cap, so
    /// today the Observer is skipped on every answer (PS.12): measured on 15 Nov, cleaning 4,000 characters took 2 to
    /// 3 s, all before the Guide could start, and saved the Guide about 700 tokens, 0.14 cents. Was 1,500.
    static let minChars = ContextPacket.textCap + 1

    static let system = """
        You prepare screen text for another assistant, who will answer the user's question about \
        their screen. Rewrite the visible text so it keeps everything that matters for the question: the content \
        itself, headings, terms, names, numbers, formulas, code, and the exact wording of anything the user \
        might ask about. Drop navigation, menus, button labels, ads, cookie notices, footers and repeated lines. \
        Keep the original language and order. Do not answer the question, do not summarize away details, do not \
        add anything. Reply with the cleaned text only.
        """

    static func clean(_ text: String, question: String, provider: any ModelProvider) async -> String {
        guard text.count >= minChars, let cleaned = try? await provider.complete(request(text, question: question)) else { return text }
        return accept(cleaned, original: text)
    }

    static func request(_ text: String, question: String) -> ModelRequest {
        let asked = question.isEmpty ? "(none: the user wants what is under the mouse pointer explained)" : question
        return ModelRequest(agent: "observer", tier: .small, system: system,
                            text: "Question: \(asked)\n\nVisible text:\n\(text)", maxTokens: 4096)
    }

    /// Meaning kept is the prompt's job; shorter and not empty is checked here.
    static func accept(_ cleaned: String, original: String) -> String {
        let cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return !cleaned.isEmpty && cleaned.count < original.count ? cleaned : original
    }
}
