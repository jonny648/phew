import Foundation

/// Reads the Messages API stream line by line. Only `data:` lines matter: each carries its event `type`,
/// so `event:` lines and blank lines are skipped (URLSession's `lines` drops the blank ones anyway).
struct SSEParser {
    private(set) var usage = Usage()
    private(set) var stopReason: String?
    private(set) var ended = false

    /// One line of the stream. Returns the text it adds, if any. Throws the API's mid-stream error event.
    mutating func consume(_ line: String) throws -> String? {
        guard line.hasPrefix("data:"),
              let event = (try? JSONSerialization.jsonObject(with: Data(line.dropFirst(5).utf8))) as? [String: Any]
        else { return nil }
        switch event["type"] as? String {
        case "message_start":
            merge((event["message"] as? [String: Any])?["usage"])
        case "content_block_delta":
            // Thinking, signature and tool-input deltas are not shown.
            let delta = event["delta"] as? [String: Any]
            if delta?["type"] as? String == "text_delta" { return delta?["text"] as? String }
        case "message_delta":
            if let reason = (event["delta"] as? [String: Any])?["stop_reason"] as? String { stopReason = reason }
            merge(event["usage"])
        case "message_stop":
            ended = true
        case "error":
            let type = (event["error"] as? [String: Any])?["type"] as? String ?? ""
            throw BrainError(status: Self.status(ofType: type))
        default:
            break  // ping, content_block_start/stop (thinking, fallback), and event types added later
        }
        return nil
    }

    /// After the last line: a refusal, or a stream cut before `message_stop`, is an error.
    func end() throws {
        if stopReason == "refusal" { throw BrainError.refused }
        guard ended else { throw BrainError.network }
    }

    /// Counts are cumulative: the latest value of each field wins. After a server-side fallback the top level
    /// covers only the serving attempt, so the per-attempt `iterations` are summed instead.
    // shortcut: an attempt declined before any output is summed although some categories are not billed; rare.
    private mutating func merge(_ value: Any?) {
        guard let fields = value as? [String: Any] else { return }
        if let attempts = fields["iterations"] as? [[String: Any]], !attempts.isEmpty {
            usage = attempts.reduce(Usage()) { sum, attempt in
                var one = Usage()
                one.merge(attempt)
                return sum + one
            }
        } else {
            usage.merge(fields)
        }
    }

    /// The HTTP status an error event stands for (docs: errors).
    static func status(ofType type: String) -> Int {
        ["invalid_request_error": 400, "authentication_error": 401, "billing_error": 402, "permission_error": 403,
         "not_found_error": 404, "request_too_large": 413, "rate_limit_error": 429, "api_error": 500,
         "overloaded_error": 529][type] ?? 500
    }
}

extension Usage {
    mutating func merge(_ fields: [String: Any]) {
        input = fields["input_tokens"] as? Int ?? input
        output = fields["output_tokens"] as? Int ?? output
        cacheWrite = fields["cache_creation_input_tokens"] as? Int ?? cacheWrite
        cacheRead = fields["cache_read_input_tokens"] as? Int ?? cacheRead
    }
}
