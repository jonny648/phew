import Foundation

/// Turns a long packet's visible text into a shorter clean one that keeps what matters for the question.
/// Small model. Never fails the request: on any problem the original text goes on to the Guide.
enum Observer {
    /// Below this many characters (about 400 tokens) the text is already short: cleaning it would cost a round
    /// trip and save little.
    static let minChars = 1500

    static let system = """
        You prepare screen text for another assistant, who will answer a university student's question about \
        their screen. Rewrite the visible text so it keeps everything that matters for the question: the content \
        itself, headings, terms, names, numbers, formulas, code, and the exact wording of anything the student \
        might ask about. Drop navigation, menus, button labels, ads, cookie notices, footers and repeated lines. \
        Keep the original language and order. Do not answer the question, do not summarize away details, do not \
        add anything. Reply with the cleaned text only.
        """

    static func clean(_ text: String, question: String, provider: any ModelProvider) async -> String {
        guard text.count >= minChars, let cleaned = try? await provider.complete(request(text, question: question)) else { return text }
        return accept(cleaned, original: text)
    }

    static func request(_ text: String, question: String) -> ModelRequest {
        let asked = question.isEmpty ? "(none: the student wants what is under the mouse pointer explained)" : question
        return ModelRequest(agent: "observer", tier: .small, system: system,
                            text: "Question: \(asked)\n\nVisible text:\n\(text)", maxTokens: 4096)
    }

    /// Meaning kept is the prompt's job; shorter and not empty is checked here.
    static func accept(_ cleaned: String, original: String) -> String {
        let cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return !cleaned.isEmpty && cleaned.count < original.count ? cleaned : original
    }
}
