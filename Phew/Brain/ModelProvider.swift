import Foundation

/// Agents ask for a tier, never for a model by name.
enum Tier: String, Sendable {
    /// Conductor, Observer, Librarian.
    case small
    /// Guide.
    case main

    /// The one table of model ids and prices, read from the Claude API docs (models overview, pricing), Nov 2026.
    var model: Model {
        switch self {
        // shortcut: Haiku 5.5's price for prompts up to 100K tokens (5x above that); Phew's prompts stay far below.
        case .small: Model(id: "claude-haiku-5-5", input: 0.10, output: 0.50, cacheWrite: 0.125, cacheRead: 0.01)
        case .main: Model(id: "claude-sonnet-5-5", input: 2, output: 10, cacheWrite: 2.50, cacheRead: 0.10)
        }
    }
}

struct Model: Sendable {
    let id: String
    /// USD per million tokens. `cacheWrite` is the 5-minute write.
    let input, output, cacheWrite, cacheRead: Double

    func cost(_ usage: Usage) -> Double {
        (Double(usage.input) * input + Double(usage.output) * output
            + Double(usage.cacheWrite) * cacheWrite + Double(usage.cacheRead) * cacheRead) / 1_000_000
    }
}

struct Usage: Sendable, Equatable {
    var input = 0, output = 0, cacheWrite = 0, cacheRead = 0

    static func + (a: Usage, b: Usage) -> Usage {
        Usage(input: a.input + b.input, output: a.output + b.output,
              cacheWrite: a.cacheWrite + b.cacheWrite, cacheRead: a.cacheRead + b.cacheRead)
    }
}

/// One call: a system prompt and one user turn, with an optional PNG and an optional schema for the answer.
struct ModelRequest: Sendable {
    /// conductor, observer, guide: names the call in the cost log.
    var agent: String
    var tier: Tier
    var system: String
    var text: String
    var image: Data? = nil
    /// JSON schema the answer must follow (structured output). The answer then streams as JSON text.
    var schema: String? = nil
    /// Interactive overlay: time to the first word matters more than depth.
    var effort = "low"
    var maxTokens: Int
}

enum ModelEvent: Sendable, Equatable {
    case text(String)
    case usage(Usage)
    /// end_turn, max_tokens… A refusal is thrown as `BrainError.refused` instead.
    case stop(String)
}

/// The one provider interface. Every model call goes through it.
protocol ModelProvider: Sendable {
    func stream(_ request: ModelRequest) -> AsyncThrowingStream<ModelEvent, Error>
}

extension ModelProvider {
    /// The whole answer at once, for agents whose output nobody watches arrive. A cut answer is an error.
    func complete(_ request: ModelRequest) async throws -> String {
        var text = ""
        for try await event in stream(request) {
            switch event {
            case .text(let piece): text += piece
            case .stop("max_tokens"): throw BrainError.badOutput
            default: break
            }
        }
        return text
    }
}
