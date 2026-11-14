import Foundation

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

    func stream(_ request: ModelRequest) -> AsyncThrowingStream<ModelEvent, Error> {
        AsyncThrowingStream { continuation in
            guard let key = key(), !key.isEmpty else { return continuation.finish(throwing: BrainError.noKey) }
            let task = Task {
                let start = Date()
                var parser = SSEParser()
                var first: Int?
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: Self.urlRequest(request, key: key))
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    guard status == 200 else { throw await Self.failure(status: status, body: bytes) }
                    for try await line in bytes.lines {
                        guard let text = try parser.consume(line) else { continue }
                        if first == nil { first = Self.ms(since: start) }
                        continuation.yield(.text(text))
                    }
                    try parser.end()
                    continuation.yield(.content(parser.content))
                    continuation.yield(.usage(parser.usage))
                    continuation.yield(.stop(parser.stopReason ?? ""))
                    CallLog.record(request, usage: parser.usage, msFirst: first, msTotal: Self.ms(since: start),
                                   stop: parser.stopReason, error: nil)
                    continuation.finish()
                } catch {
                    let failure = BrainError(error)
                    CallLog.record(request, usage: parser.usage, msFirst: first, msTotal: Self.ms(since: start),
                                   stop: parser.stopReason, error: Task.isCancelled ? "cancelled" : "\(failure)")
                    continuation.finish(throwing: failure)
                }
            }
            // The consumer stopped listening (card closed): cancelling the task cancels the HTTP request.
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static func urlRequest(_ request: ModelRequest, key: String) throws -> URLRequest {
        var content: [[String: Any]] = []
        if let image = request.image {
            content.append(["type": "image",
                            "source": ["type": "base64", "media_type": "image/png", "data": image.base64EncodedString()]])
        }
        content.append(["type": "text", "text": request.text])
        // No `thinking` field: adaptive on both models; `effort` sets the depth. No sampling parameters (400s).
        // No `cache_control`: the only stable prefix, the system prompt, is under the 512-token cache minimum.
        var output: [String: Any] = ["effort": request.effort]
        if let schema = request.schema {
            output["format"] = ["type": "json_schema", "schema": try JSONSerialization.jsonObject(with: Data(schema.utf8))]
        }
        // Earlier turns as text only, then the current turn with the fresh look, then the tool rounds unchanged.
        var messages: [[String: Any]] = request.earlier.flatMap { turn in
            [["role": "user", "content": turn.question], ["role": "assistant", "content": turn.answer]]
        }
        messages.append(["role": "user", "content": content])
        for message in request.after {
            messages.append(["role": message.role, "content": try JSONSerialization.jsonObject(with: message.content)])
        }
        var body: [String: Any] = [
            "model": request.tier.model.id,
            "max_tokens": request.maxTokens,
            "stream": true,
            "system": request.system,
            "messages": messages,
            "output_config": output,
        ]
        if !request.tools.isEmpty {
            // The same tools on every round, so the thinking blocks sent back stay valid; `none` forces the answer.
            body["tools"] = try request.tools.map { tool in
                ["name": tool.name, "description": tool.description, "strict": true,
                 "input_schema": try JSONSerialization.jsonObject(with: Data(tool.schema.utf8))]
            }
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
