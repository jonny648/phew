import XCTest
@testable import Phew

/// The real URLSession path of `ClaudeProvider`, answered by a local stub instead of the network: streaming over
/// `bytes.lines`, HTTP errors, cancellation reaching the request, and one cost-log line per call.
final class ClaudeProviderHTTPTests: XCTestCase {
    final class Stub: URLProtocol {
        nonisolated(unsafe) static var status = 200
        nonisolated(unsafe) static var body = ""
        nonisolated(unsafe) static var hang = false
        nonisolated(unsafe) static var stopped: XCTestExpectation?

        override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "api.anthropic.com" }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: "HTTP/1.1",
                                           headerFields: ["content-type": "text/event-stream"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(Self.body.utf8))
            if !Self.hang { client?.urlProtocolDidFinishLoading(self) }
        }
        override func stopLoading() { Self.stopped?.fulfill() }
    }

    private let log = FileManager.default.temporaryDirectory.appending(path: "phew-calls-\(UUID().uuidString).log")
    private var savedLog: URL!
    private let request = ModelRequest(agent: "unit-test", tier: .small, system: "s", text: "t", maxTokens: 64)
    private let provider = ClaudeProvider(key: { "test-key-not-real" })

    override func setUp() {
        URLProtocol.registerClass(Stub.self)
        (Stub.status, Stub.hang, Stub.stopped) = (200, false, nil)
        savedLog = CallLog.url
        CallLog.url = log
    }

    override func tearDown() {
        URLProtocol.unregisterClass(Stub.self)
        CallLog.url = savedLog
        try? FileManager.default.removeItem(at: log)
    }

    private func logLines() throws -> [CallLog.Line] {
        _ = CallLog.spentUSD  // runs on the log's queue, so earlier writes are done
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try String(decoding: Data(contentsOf: log), as: UTF8.self).split(separator: "\n")
            .map { try decoder.decode(CallLog.Line.self, from: Data($0.utf8)) }
    }

    func testStreamsEventsAndLogsTheCall() async throws {
        Stub.body = """
            event: message_start
            data: {"type":"message_start","message":{"usage":{"input_tokens":12,"output_tokens":1}}}

            event: content_block_delta
            data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hel"}}

            event: content_block_delta
            data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"lo"}}

            event: message_delta
            data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":5}}

            event: message_stop
            data: {"type":"message_stop"}

            """
        var events: [ModelEvent] = []
        for try await event in provider.stream(request) { events.append(event) }
        // No content_block_start in this stream, so the blocks are empty; the text still streams.
        XCTAssertEqual(events, [.text("Hel"), .text("lo"), .content(Data("[]".utf8)), .usage(Usage(input: 12, output: 5)), .stop("end_turn")])
        let lines = try logLines()
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines.first?.agent, "unit-test")
        XCTAssertEqual(lines.first?.stop, "end_turn")
        XCTAssertEqual(lines.first?.inputTokens, 12)
    }

    // MARK: Tool rounds and earlier turns

    private func body(_ request: ModelRequest) throws -> [String: Any] {
        let http = try ClaudeProvider.urlRequest(request, key: "test-key-not-real")
        return try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(http.httpBody)) as? [String: Any])
    }

    private let thinking = #"{"type":"thinking","thinking":"","signature":"EqQBCgIYAhIM1gbcDa9GJwZA2b+/=="}"#
    private let call = #"{"type":"tool_use","id":"toolu_01","name":"search_map","input":{"query":"made-up pricing words"}}"#

    func testMessagesGoInOrderEarlierThenCurrentThenToolRounds() throws {
        var request = ModelRequest(agent: "guide", tier: .main, system: "s", text: "screen and question",
                                   image: TestPNG.make(width: 40, height: 30), schema: #"{"type":"object","properties":{},"additionalProperties":false}"#,
                                   maxTokens: 64)
        request.earlier = [Turn(question: "Question: q1", answer: "a1"), Turn(question: "Question: q2", answer: "a2")]
        request.after = [ModelMessage(role: "assistant", content: Data("[\(thinking),\(call)]".utf8)),
                         ModelMessage(role: "user", content: Data(#"[{"type":"tool_result","tool_use_id":"toolu_01","content":"r"}]"#.utf8))]
        request.tools = [.searchMap]
        request.toolChoice = .none
        let sent = try body(request)
        let messages = try XCTUnwrap(sent["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.map { $0["role"] as? String }, ["user", "assistant", "user", "assistant", "user", "assistant", "user"])
        // Earlier turns: plain text, no picture.
        XCTAssertEqual(messages[0]["content"] as? String, "Question: q1")
        XCTAssertEqual(messages[1]["content"] as? String, "a1")
        XCTAssertEqual(messages[3]["content"] as? String, "a2")
        // The current turn: picture, then text.
        let current = try XCTUnwrap(messages[4]["content"] as? [[String: Any]])
        XCTAssertEqual(current.map { $0["type"] as? String }, ["image", "text"])
        XCTAssertEqual(current[1]["text"] as? String, "screen and question")
        // The tool round: the model's blocks unchanged, thinking and signature included.
        let echoed = try JSONSerialization.data(withJSONObject: try XCTUnwrap(messages[5]["content"]), options: .sortedKeys)
        let original = try JSONSerialization.data(withJSONObject: JSONSerialization.jsonObject(with: Data("[\(thinking),\(call)]".utf8)), options: .sortedKeys)
        XCTAssertEqual(echoed, original)
        XCTAssertEqual((messages[6]["content"] as? [[String: Any]])?.first?["type"] as? String, "tool_result")
        // Tools: strict, the schema as an object; at most one call; `none` forces the answer.
        let tools = try XCTUnwrap(sent["tools"] as? [[String: Any]])
        XCTAssertEqual(tools.count, 1)
        XCTAssertEqual(tools[0]["name"] as? String, "search_map")
        XCTAssertEqual(tools[0]["strict"] as? Bool, true)
        XCTAssertNotNil(tools[0]["input_schema"] as? [String: Any])
        let choice = try XCTUnwrap(sent["tool_choice"] as? [String: Any])
        XCTAssertEqual(choice as NSDictionary, ["type": "none"], "none takes no other field, or the API answers 400")
        request.toolChoice = .auto
        let auto = try XCTUnwrap(try body(request)["tool_choice"] as? [String: Any])
        XCTAssertEqual(auto as NSDictionary, ["type": "auto", "disable_parallel_tool_use": true])
        XCTAssertNotNil((sent["output_config"] as? [String: Any])?["format"])  // structured output with tools (docs)
        XCTAssertEqual(sent["fallbacks"] as? String, "default")
    }

    func testNoToolsMeansNoToolFieldsAndOneUserMessage() throws {
        let sent = try body(request)
        XCTAssertNil(sent["tools"])
        XCTAssertNil(sent["tool_choice"])
        XCTAssertEqual((sent["messages"] as? [[String: Any]])?.count, 1)
    }

    func testToolRoundStreamsItsBlocksAndLogsNoSearchWords() async throws {
        Stub.body = """
            data: {"type":"message_start","message":{"usage":{"input_tokens":900,"output_tokens":1}}}
            data: {"type":"content_block_start","index":0,"content_block":{"type":"thinking","thinking":"","signature":""}}
            data: {"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":""}}
            data: {"type":"content_block_delta","index":0,"delta":{"type":"signature_delta","signature":"EqQBCgIYAhIM1gbcDa9GJwZA2b+/=="}}
            data: {"type":"content_block_stop","index":0}
            data: {"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"toolu_01","name":"search_map","input":{}}}
            data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"{\\"query\\": \\"made-up pri"}}
            data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"cing words\\"}"}}
            data: {"type":"content_block_stop","index":1}
            data: {"type":"message_delta","delta":{"stop_reason":"tool_use"},"usage":{"output_tokens":40}}
            data: {"type":"message_stop"}

            """
        var events: [ModelEvent] = []
        for try await event in provider.stream(request) { events.append(event) }
        XCTAssertEqual(events.count, 3)
        guard case .content(let content) = events[0] else { return XCTFail("expected the reply's blocks first") }
        XCTAssertEqual(events[1...], [.usage(Usage(input: 900, output: 40)), .stop("tool_use")])
        let sorted = try JSONSerialization.data(withJSONObject: JSONSerialization.jsonObject(with: content), options: .sortedKeys)
        let expected = try JSONSerialization.data(withJSONObject: JSONSerialization.jsonObject(with: Data("[\(thinking),\(call)]".utf8)), options: .sortedKeys)
        XCTAssertEqual(sorted, expected)
        // One cost-log line for the round, with stop tool_use, and not one search word.
        XCTAssertEqual(try logLines().map(\.stop), ["tool_use"])
        XCTAssertFalse(String(decoding: try Data(contentsOf: log), as: UTF8.self).contains("made-up"))
    }

    func testAfterAFallbackOnlyTheServingModelsBlocksGoBack() throws {
        var parser = SSEParser()
        for line in [
            #"data: {"type":"content_block_start","index":0,"content_block":{"type":"thinking","thinking":"","signature":""}}"#,
            #"data: {"type":"content_block_delta","index":0,"delta":{"type":"signature_delta","signature":"declined"}}"#,
            #"data: {"type":"content_block_start","index":1,"content_block":{"type":"text","text":""}}"#,
            #"data: {"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":"Part"}}"#,
            #"data: {"type":"content_block_start","index":2,"content_block":{"type":"fallback","from":{"model":"a"},"to":{"model":"b"},"trigger":{"type":"refusal","category":"cyber"}}}"#,
            #"data: {"type":"content_block_start","index":3,"content_block":{"type":"thinking","thinking":"","signature":""}}"#,
            #"data: {"type":"content_block_delta","index":3,"delta":{"type":"signature_delta","signature":"served"}}"#,
        ] { _ = try parser.consume(line) }
        let kept = try XCTUnwrap(JSONSerialization.jsonObject(with: parser.content) as? [[String: Any]])
        XCTAssertEqual(kept.map { $0["type"] as? String }, ["text", "fallback", "thinking"])
        XCTAssertEqual(kept[0]["text"] as? String, "Part")
        XCTAssertEqual(kept[2]["signature"] as? String, "served")
    }

    func testHTTPErrorIsMappedAndLogged() async throws {
        (Stub.status, Stub.body) = (401, #"{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}"#)
        do {
            for try await _ in provider.stream(request) {}
            XCTFail("expected badKey")
        } catch {
            XCTAssertEqual(error as? BrainError, .badKey)
        }
        XCTAssertEqual(try logLines().map(\.error), ["badKey"])
    }

    func testCancellingTheConsumerCancelsTheRequest() async throws {
        Stub.hang = true
        Stub.body = #"data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hel"}}"# + "\n"
        let stopped = expectation(description: "request stopped")
        Stub.stopped = stopped
        let gotText = expectation(description: "first text")
        let consumer = Task {
            for try await event in provider.stream(request) where event == .text("Hel") { gotText.fulfill() }
        }
        await fulfillment(of: [gotText], timeout: 5)
        consumer.cancel()  // the card closed
        await fulfillment(of: [stopped], timeout: 5)
        // The cancelled call is still logged, once.
        for _ in 0..<50 where (try? logLines().count) != 1 { try await Task.sleep(for: .milliseconds(100)) }
        XCTAssertEqual(try logLines().map(\.error), ["cancelled"])
    }
}
