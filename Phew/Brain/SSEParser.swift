import Foundation

/// Reads the Messages API stream line by line. Only `data:` lines matter: each carries its event `type`,
/// so `event:` lines and blank lines are skipped (URLSession's `lines` drops the blank ones anyway).
struct SSEParser {
    private(set) var usage = Usage()
    private(set) var stopReason: String?
    private(set) var ended = false
    /// The reply's content blocks by index, built from the stream so they can be sent back unchanged.
    private var blocks: [Int: [String: Any]] = [:]
    private var toolInput: [Int: String] = [:]
    /// R8, for a stream cut before its last usage: whether `message_start` and `message_delta` were read, the
    /// characters the model generated (text, thinking, tool input), the size of each server tool result, in
    /// characters, and the searches and page reads it asked for. Numbers only.
    private var started = false, final = false
    private var generated = 0, results: [Int] = [], asked = (searches: 0, fetches: 0)

    /// One line of the stream. Returns the text it adds, if any. Throws the API's mid-stream error event.
    mutating func consume(_ line: String) throws -> String? {
        guard line.hasPrefix("data:"),
              let event = (try? JSONSerialization.jsonObject(with: Data(line.dropFirst(5).utf8))) as? [String: Any]
        else { return nil }
        let index = event["index"] as? Int ?? 0
        switch event["type"] as? String {
        case "message_start":
            started = true
            merge((event["message"] as? [String: Any])?["usage"])
        case "content_block_start":
            // thinking, redacted_thinking, text, tool_use, fallback… kept as the API sent them.
            let block = event["content_block"] as? [String: Any] ?? [:]
            blocks[index] = block
            let type = block["type"] as? String ?? ""
            if type == "server_tool_use" {
                if block["name"] as? String == "web_search" { asked.searches += 1 } else { asked.fetches += 1 }
            } else if type.hasSuffix("_tool_result") {
                results.append((try? JSONSerialization.data(withJSONObject: block).count) ?? 0)
            }
        case "content_block_delta":
            // Only text is shown. Thinking, its signature and tool input are kept for sending back.
            guard let delta = event["delta"] as? [String: Any] else { break }
            switch delta["type"] as? String {
            case "text_delta":
                let text = delta["text"] as? String ?? ""
                generated += text.count
                append(text, to: "text", at: index)
                return text
            case "thinking_delta":
                let thinking = delta["thinking"] as? String ?? ""
                generated += thinking.count
                append(thinking, to: "thinking", at: index)
            case "signature_delta":
                blocks[index]?["signature"] = delta["signature"]
            case "input_json_delta":
                let json = delta["partial_json"] as? String ?? ""
                generated += json.count
                toolInput[index, default: ""] += json
            case "citations_delta":
                // Web search sources on the report's text: kept, so the block goes back as it came.
                guard let citation = delta["citation"] else { break }
                let cited = blocks[index]?["citations"] as? [Any] ?? []
                blocks[index]?["citations"] = cited + [citation]
            default:
                break
            }
        case "content_block_stop":
            // A server tool's input (the search words, the page address) streams the same way and goes back with it.
            if ["tool_use", "server_tool_use"].contains(blocks[index]?["type"] as? String ?? "") {
                let json = toolInput[index] ?? ""
                // Strict tools: the input matches its schema. Anything unreadable is not run.
                let input: Any? = json.isEmpty ? [String: Any]() : try? JSONSerialization.jsonObject(with: Data(json.utf8))
                guard let input else { throw BrainError.badOutput }
                blocks[index]?["input"] = input
            }
        case "message_delta":
            final = true
            if let reason = (event["delta"] as? [String: Any])?["stop_reason"] as? String { stopReason = reason }
            merge(event["usage"])
        case "message_stop":
            ended = true
        case "error":
            let type = (event["error"] as? [String: Any])?["type"] as? String ?? ""
            throw BrainError(status: Self.status(ofType: type))
        default:
            break  // ping, and event types added later
        }
        return nil
    }

    private mutating func append(_ piece: String, to key: String, at index: Int) {
        guard var block = blocks[index] else { return }
        block[key] = (block[key] as? String ?? "") + piece
        blocks[index] = block
    }

    /// The reply's blocks as a JSON array, ready to send back as the assistant turn of a tool round.
    /// After a server-side fallback, the blocks the declining model wrote before the last `fallback` block are
    /// dropped as the docs say (thinking, redacted thinking, connector text, client tool calls); text is kept.
    var content: Data {
        let all = blocks.keys.sorted().compactMap { blocks[$0] }
        let cut = all.lastIndex { $0["type"] as? String == "fallback" } ?? 0
        let dropped: Set = ["thinking", "redacted_thinking", "connector_text", "tool_use"]
        let kept = all.enumerated().filter { $0.offset >= cut || !dropped.contains($0.element["type"] as? String ?? "") }
        return (try? JSONSerialization.data(withJSONObject: kept.map(\.element))) ?? Data("[]".utf8)
    }

    /// After the last line: a refusal, or a stream cut before `message_stop`, is an error.
    func end() throws {
        if stopReason == "refusal" { throw BrainError.refused }
        guard ended else { throw BrainError.network }
    }

    /// R8: what a stream cut short (Stop, a time cap, a dropped connection) used. The API's own numbers when its last
    /// usage arrived; otherwise an estimate on the safe side: `prompt` (the request's own size) when `message_start`
    /// never came, every generated character as output, every search and page read asked for, and, for each server
    /// tool result, one more sampling step reading the whole context so far, priced as fresh input. Nil: nothing to add.
    func cut(prompt: Int) -> Usage? {
        guard !final else { return nil }
        var usage = usage
        if !started { usage.input = prompt }
        var context = usage.input + usage.cacheRead + usage.cacheWrite, steps = 0
        for result in results {
            context += Self.tokens(result)
            steps += context
        }
        usage.input += steps
        usage.output = max(usage.output, Self.tokens(generated))
        usage.searches = max(usage.searches, asked.searches)
        usage.fetches = max(usage.fetches, asked.fetches)
        return usage
    }

    /// Tokens in `characters`, rounded up: one per 3 characters, more than the usual 3.5, so the estimate stays high.
    static func tokens(_ characters: Int) -> Int { (characters + 2) / 3 }

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
            // Server tools also bring `iterations` (one per sampling step, live 15 Nov), but their searches and page
            // reads are counted only at the top level.
            usage.merge(fields.filter { $0.key == "server_tool_use" })
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
        if let creation = fields["cache_creation"] as? [String: Any] {
            cacheWriteHour = creation["ephemeral_1h_input_tokens"] as? Int ?? cacheWriteHour
        }
        if let server = fields["server_tool_use"] as? [String: Any] {
            searches = server["web_search_requests"] as? Int ?? searches
            fetches = server["web_fetch_requests"] as? Int ?? fetches
        }
    }
}
