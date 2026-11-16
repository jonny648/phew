import Foundation
import os

/// The Claude implementation of `ModelProvider`: raw HTTPS to the Messages API (no official Swift SDK), streamed.
/// Request and event shapes from the Claude API docs, Nov 2026: Messages, streaming, vision, structured outputs,
/// tool use (structured outputs and strict tools in one request; thinking blocks sent back unchanged).
struct ClaudeProvider: ModelProvider {
    var key: @Sendable () -> String? = { KeyStore().read() }

    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    static let apiVersion = "2026-10-21"
    /// Server-side refusal fallback (beta) on the main model: a request its classifier declines (say, a security
    /// lecture flagged as cyber) is answered by the model Anthropic recommends, on the same stream.
    /// Haiku 5.5 has no server-side fallback: there a list is a 400 and "default" does nothing.
    static let fallbackBeta = "server-side-fallback-2026-07-01"

    /// Waits before each retry of a request the API turned away with 429 or 5xx before any of the answer came. A
    /// `retry-after` header wins, up to `maxWait`. A var only so unit tests can wait less.
    var retryDelays: [TimeInterval] = [1, 3]
    /// Longer than this, the API's own wait is not worth it: the error goes to the card.
    static let maxWait: TimeInterval = 10

    func stream(_ request: ModelRequest) -> AsyncThrowingStream<ModelEvent, Error> {
        AsyncThrowingStream { continuation in
            guard let key = key(), !key.isEmpty else { return continuation.finish(throwing: BrainError.noKey) }
            let capped = OSAllocatedUnfairLock(initialState: false)
            let delays = retryDelays
            let task = Task {
                let start = Date()
                var parser = SSEParser()
                var first: Int?
                // The API took the request (200), or it is on its way: from then on a cut may still be billed.
                var accepted = false, sending = false
                do {
                    var retries = delays[...]
                    var bytes: URLSession.AsyncBytes
                    while true {
                        sending = true
                        let (body, response) = try await URLSession.shared.bytes(for: Self.urlRequest(request, key: key, hour: CallLog.hourCache))
                        let http = response as? HTTPURLResponse
                        let status = http?.statusCode ?? 0
                        if status == 200 { bytes = body; break }
                        sending = false  // turned away: not billed
                        // Busy or rate limited before any output: a few bounded tries, never once the answer started.
                        // Stop or the time cap ends the wait like the request.
                        if status == 429 || status >= 500, let delay = retries.popFirst(),
                           let wait = Self.wait(delay, retryAfter: http?.value(forHTTPHeaderField: "retry-after")) {
                            body.task.cancel()
                            shellLog("api error \(status), try again in \(wait) s")
                            try await Task.sleep(for: .seconds(wait))
                            continue
                        }
                        throw await Self.failure(status: status, body: body)
                    }
                    accepted = true
                    for try await line in bytes.lines {
                        guard let text = try parser.consume(line) else { continue }
                        if first == nil { first = Self.ms(since: start) }
                        continuation.yield(.text(text))
                    }
                    try Task.checkCancellation()  // a cancelled read may end the lines without throwing
                    try parser.end()
                    continuation.yield(.content(parser.content))
                    continuation.yield(.usage(parser.usage))
                    continuation.yield(.stop(parser.stopReason ?? ""))
                    CallLog.record(request, usage: parser.usage, msFirst: first, msTotal: Self.ms(since: start),
                                   stop: parser.stopReason, error: nil)
                    continuation.finish()
                } catch {
                    // Over the time cap: "runaway" in calls.log's ending, and the error the caller may retry on.
                    let runaway = capped.withLock { $0 }
                    let failure = runaway ? BrainError.runaway : BrainError(error)
                    // R8: a stream cut once the API took it is billed for what it did: its own numbers, or an estimate.
                    let cut = accepted || sending && (runaway || Task.isCancelled) ? parser.cut(prompt: Self.promptTokens(request)) : nil
                    CallLog.record(request, usage: cut ?? parser.usage, msFirst: first, msTotal: Self.ms(since: start), stop: parser.stopReason,
                                   error: failure != .runaway && Task.isCancelled ? "cancelled" : "\(failure)", estimated: cut != nil)
                    continuation.finish(throwing: failure)
                }
            }
            let cap = request.timeLimit.map { limit in
                Task {
                    try await Task.sleep(for: .seconds(limit))
                    capped.withLock { $0 = true }
                    task.cancel()
                }
            }
            // The consumer stopped listening (card closed): cancelling the task cancels the HTTP request.
            continuation.onTermination = { _ in
                task.cancel()
                cap?.cancel()
            }
        }
    }

    /// The wait before a retry: the API's `retry-after` in seconds when it sends one, else `delay`. Nil when the API
    /// asks for longer than `maxWait`.
    static func wait(_ delay: TimeInterval, retryAfter: String?) -> TimeInterval? {
        let wait = retryAfter.flatMap { TimeInterval($0.trimmingCharacters(in: .whitespaces)) } ?? delay
        return wait <= maxWait ? max(wait, 0) : nil
    }

    /// R8: the request's input tokens, from its size, for a cut that came before the API's first numbers. On the safe
    /// side: one token per 3 characters, and a picture's 28-by-28-pixel blocks.
    static func promptTokens(_ request: ModelRequest) -> Int {
        let characters = request.system.count + request.text.count + (request.cached?.count ?? 0)
            + request.earlier.reduce(0) { $0 + $1.question.count + $1.answer.count }
            + request.after.reduce(0) { $0 + $1.content.count }
            + request.tools.reduce(0) { $0 + $1.description.count + $1.schema.count }
        let picture = request.image.flatMap { ScreenshotSize(png: $0) }.map { ($0.seenWidth * $0.seenHeight + 783) / 784 } ?? 0
        return SSEParser.tokens(characters) + picture
    }

    /// The 5-minute cache: a conversation's replies come minutes apart at most.
    static let ephemeral = ["type": "ephemeral"]
    /// The one-hour cache (D1, docs: prompt caching; no beta header). Written at 2x the input price, so only on the
    /// fixed part and only when `CacheLife` says this Mac's calls come 5 to 60 minutes apart. A longer mark must come
    /// before shorter ones: the system prompt is before every message, so the 5-minute marks after it stay valid.
    static let hourLong = ["type": "ephemeral", "ttl": "1h"]

    /// `hour`: the system prompt's mark lasts one hour.
    static func urlRequest(_ request: ModelRequest, key: String, hour: Bool = false) throws -> URLRequest {
        var content: [[String: Any]] = []
        // R56: the part of the turn that repeats from call to call, read from the cache after the first call.
        if let cached = request.cached {
            content.append(["type": "text", "text": cached, "cache_control": ephemeral])
        }
        if let image = request.image {
            content.append(["type": "image",
                            "source": ["type": "base64", "media_type": "image/png", "data": image.base64EncodedString()]])
        }
        content.append(["type": "text", "text": request.text])
        // No `thinking` field: adaptive on both models; `effort` sets the depth. No sampling parameters (400s).
        var output: [String: Any] = ["effort": request.effort]
        if let schema = request.schema {
            output["format"] = ["type": "json_schema", "schema": try JSONSerialization.jsonObject(with: Data(schema.utf8))]
        }
        // Earlier turns as text only, then the current turn with the fresh look, then the tool rounds unchanged.
        var messages: [[String: Any]] = request.earlier.flatMap { turn in
            [["role": "user", "content": turn.question], ["role": "assistant", "content": turn.answer]]
        }
        // Prompt caching (PS.13, docs: prompt caching): two of the 4 breakpoints. One ends the fixed part (tools, then
        // the system prompt); one ends the earlier turns, so the next reply reads them from the cache and pays about
        // a twentieth for them. A prefix under the model's minimum (512 tokens on both models) is simply not cached.
        // The markers only wrap text already filtered: nothing is added, moved or left out.
        if let last = messages.indices.last, let answer = messages[last]["content"] as? String, !answer.isEmpty {
            messages[last]["content"] = [["type": "text", "text": answer, "cache_control": ephemeral]]
        }
        messages.append(["role": "user", "content": content])
        for message in request.after {
            messages.append(["role": message.role, "content": try JSONSerialization.jsonObject(with: message.content)])
        }
        // The third breakpoint: the last tool results, when they end the request. Only a user turn: the model's own
        // blocks (thinking among them) go back exactly as they came.
        if request.cacheRounds, let last = messages.indices.last, messages[last]["role"] as? String == "user",
           var blocks = messages[last]["content"] as? [[String: Any]], !blocks.isEmpty {
            blocks[blocks.count - 1]["cache_control"] = ephemeral
            messages[last]["content"] = blocks
        }
        var body: [String: Any] = [
            "model": request.tier.model.id,
            "max_tokens": request.maxTokens,
            "stream": true,
            "system": [["type": "text", "text": request.system, "cache_control": hour ? hourLong : ephemeral]],
            "messages": messages,
            "output_config": output,
        ]
        if !request.tools.isEmpty || !request.serverTools.isEmpty {
            // The same tools on every round, so the thinking blocks sent back stay valid; `none` forces the answer.
            body["tools"] = try request.tools.map { tool in
                ["name": tool.name, "description": tool.description, "strict": true,
                 "input_schema": try JSONSerialization.jsonObject(with: Data(tool.schema.utf8))]
            } + request.serverTools.map { try JSONSerialization.jsonObject(with: Data($0.utf8)) }
            // `none` takes no other field: with `disable_parallel_tool_use` the API answers 400 (live, 14 Nov).
            body["tool_choice"] = request.toolChoice == .none ? ["type": "none"]
                : ["type": request.toolChoice.rawValue, "disable_parallel_tool_use": true]
        }
        var http = URLRequest(url: endpoint)
        http.httpMethod = "POST"
        http.setValue(key, forHTTPHeaderField: "x-api-key")
        http.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        http.setValue("application/json", forHTTPHeaderField: "content-type")
        if request.tier == .main {
            http.setValue(fallbackBeta, forHTTPHeaderField: "anthropic-beta")
            body["fallbacks"] = "default"
        }
        http.httpBody = try JSONSerialization.data(withJSONObject: body)
        return http
    }

    #if DEBUG
    /// The API's message for the last HTTP error, kept in memory for the self-check, which sends made-up data only.
    nonisolated(unsafe) static var lastErrorMessage: String?
    #endif

    private static func failure(status: Int, body: URLSession.AsyncBytes) async -> BrainError {
        #if DEBUG
        let text = (try? await body.lines.reduce("", +)) ?? ""
        let error = ((try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any])?["error"] as? [String: Any]
        shellLog("api error \(status) \(error?["type"] as? String ?? "unknown type")")
        lastErrorMessage = error?["message"] as? String
        #endif
        return BrainError(status: status)
    }

    private static func ms(since start: Date) -> Int { Int(Date().timeIntervalSince(start) * 1000) }
}
