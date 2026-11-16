import Foundation

/// Agents ask for a tier, never for a model by name.
enum Tier: String, Sendable {
    /// Conductor, Librarian.
    case small
    /// Guide, Follower, Runner.
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
    /// The one-hour write: 2x the input price (docs: prompt caching, pricing).
    var cacheWriteHour: Double { input * 2 }
    /// USD per web search: $10 per 1,000 (docs: web search tool, usage and pricing). A page read costs tokens only.
    static let perSearch = 0.01

    func cost(_ usage: Usage) -> Double {
        (Double(usage.input) * input + Double(usage.output) * output
            + Double(usage.cacheWrite - usage.cacheWriteHour) * cacheWrite + Double(usage.cacheWriteHour) * cacheWriteHour
            + Double(usage.cacheRead) * cacheRead) / 1_000_000
            + Double(usage.searches) * Self.perSearch
    }
}

struct Usage: Sendable, Equatable {
    /// `cacheWrite` is every token written to the cache; `cacheWriteHour` the part of it written for one hour
    /// (`usage.cache_creation.ephemeral_1h_input_tokens`), priced apart.
    var input = 0, output = 0, cacheWrite = 0, cacheRead = 0, cacheWriteHour = 0
    /// Web searches and page reads Anthropic ran in this reply (`usage.server_tool_use`): the Runner's only.
    var searches = 0, fetches = 0

    static func + (a: Usage, b: Usage) -> Usage {
        Usage(input: a.input + b.input, output: a.output + b.output,
              cacheWrite: a.cacheWrite + b.cacheWrite, cacheRead: a.cacheRead + b.cacheRead,
              cacheWriteHour: a.cacheWriteHour + b.cacheWriteHour, searches: a.searches + b.searches, fetches: a.fetches + b.fetches)
    }
}

/// One call: a system prompt and the current user turn (text, optional PNG), after the earlier turns as text,
/// followed by the tool rounds so far. Optional schema for the answer, optional tools.
/// Messages go out in this order: `earlier`, the current turn, `after`.
struct ModelRequest: Sendable {
    /// conductor, guide, runner: names the call in the cost log.
    var agent: String
    var tier: Tier
    var system: String
    var text: String
    /// Text that is the same on every call of a job (the Doer's menus, R56): sent first in the current turn, before
    /// the picture, with its own cache mark. Already filtered, like `text`.
    var cached: String? = nil
    var image: Data? = nil
    /// JSON schema the answer must follow (structured output). The answer then streams as JSON text.
    var schema: String? = nil
    /// Interactive overlay: time to the first word matters more than depth.
    var effort = "low"
    var maxTokens: Int
    /// Hard cap on the whole call, from sending to the last word. Over it the call is cancelled and fails with
    /// `BrainError.runaway`. Nil: no cap.
    var timeLimit: TimeInterval? = nil
    /// Earlier questions and answers of this conversation, text only: never an earlier screen text or picture.
    var earlier: [Turn] = []
    /// Tool rounds, append-only: the model's reply exactly as received, then the user turn with the tool results.
    var after: [ModelMessage] = []
    var tools: [ToolSpec] = []
    /// Anthropic's own tools (web search, web fetch), each one JSON object sent as it is after `tools`. The Runner's only.
    var serverTools: [String] = []
    /// Sent only with tools. Always at most one call per reply.
    var toolChoice = ToolChoice.auto
    /// A cache mark on the last tool results, so each round reads the rounds before it from the cache (the Runner's
    /// rounds carry whole web pages). Off for the Guide, whose two rounds at most were measured without it.
    var cacheRounds = false
    /// The task this call works for, for calls.log only (PA.5). Nil outside a task.
    var task: Int? = nil
}

/// One earlier question and its answer, as text.
struct Turn: Sendable, Equatable {
    var question: String
    var answer: String
}

/// A message in a tool round. `content` is the JSON array of its content blocks, kept as bytes so the model's
/// blocks (thinking with its signature, tool_use with its input) go back unchanged.
struct ModelMessage: Sendable, Equatable {
    var role: String
    var content: Data
}

/// A client tool. Sent with `strict: true`, so its input always matches `schema`.
struct ToolSpec: Sendable, Equatable {
    var name: String
    var description: String
    /// JSON schema of the input.
    var schema: String
}

enum ToolChoice: String, Sendable {
    /// The model may call a tool or answer.
    case auto
    /// The model must answer: no more tool calls.
    case none
}

enum ModelEvent: Sendable, Equatable {
    case text(String)
    /// The reply's content blocks as received (JSON array), for sending back in a tool round. Never logged.
    case content(Data)
    case usage(Usage)
    /// end_turn, tool_use, max_tokens… A refusal is thrown as `BrainError.refused` instead.
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
