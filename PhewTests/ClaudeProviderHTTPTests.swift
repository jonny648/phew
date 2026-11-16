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
        /// Statuses for the first requests, one each, before `status`; and the `retry-after` header they carry.
        nonisolated(unsafe) static var statuses: [Int] = []
        nonisolated(unsafe) static var retryAfter: String?
        nonisolated(unsafe) static var count = 0

        override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "api.anthropic.com" }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            Self.count += 1
            let status = Self.statuses.isEmpty ? Self.status : Self.statuses.removeFirst()
            var headers = ["content-type": "text/event-stream"]
            if status != 200, let wait = Self.retryAfter { headers["retry-after"] = wait }
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1",
                                           headerFields: headers)!
            if status != 200 {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: Data(#"{"type":"error","error":{"type":"made_up","message":"made up"}}"#.utf8))
                return client?.urlProtocolDidFinishLoading(self) ?? ()
            }
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
        (Stub.statuses, Stub.retryAfter, Stub.count) = ([], nil, 0)
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
        // The last earlier answer ends the cached part (PS.13): the same text, in a block with its cache marker.
        let last = try XCTUnwrap(messages[3]["content"] as? [[String: Any]])
        XCTAssertEqual(last.count, 1)
        XCTAssertEqual(last[0]["text"] as? String, "a2")
        XCTAssertEqual(last[0]["cache_control"] as? [String: String], ["type": "ephemeral"])
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

    // MARK: Prompt caching (PS.13)

    func testCacheMarkersEndTheFixedPartAndTheEarlierTurnsOnly() throws {
        let secret = "sk-" + "ant-api03-" + String(repeating: "Zq7w", count: 10)  // made up, built from pieces
        var request = Guide.request("Question two", packet: nil, route: .explain, shot: nil,
                                    earlier: [Turn(question: "Question: one", answer: "Answer one with \(secret)")])
        request.tools = [.searchMap]
        let sent = try body(request)
        // The system prompt: one block, the fixed text unchanged, with the marker. Tools come before it, so it ends both.
        let system = try XCTUnwrap(sent["system"] as? [[String: Any]])
        XCTAssertEqual(system.count, 1)
        XCTAssertEqual(system[0]["text"] as? String, Guide.system)
        XCTAssertEqual(system[0]["cache_control"] as? [String: String], ["type": "ephemeral"])
        XCTAssertNil((sent["tools"] as? [[String: Any]])?.first?["cache_control"])
        let messages = try XCTUnwrap(sent["messages"] as? [[String: Any]])
        XCTAssertEqual(messages[0]["content"] as? String, "Question: one")
        // The earlier answer, filtered as before the marker: the marker moves no text past the filter.
        let answer = try XCTUnwrap((messages[1]["content"] as? [[String: Any]])?.first)
        XCTAssertEqual(answer["text"] as? String, "Answer one with \(SecretsFilter.keyMarker)")
        XCTAssertEqual(answer["cache_control"] as? [String: String], ["type": "ephemeral"])
        // The current turn changes every time: no marker on it. Two markers in all, of the 4 allowed.
        let current = try XCTUnwrap(messages[2]["content"] as? [[String: Any]])
        XCTAssertTrue(current.allSatisfy { $0["cache_control"] == nil })
        let all = String(decoding: try XCTUnwrap(ClaudeProvider.urlRequest(request, key: "k").httpBody), as: UTF8.self)
        XCTAssertEqual(all.components(separatedBy: "cache_control").count - 1, 2)
        XCTAssertFalse(all.contains(secret))
    }

    /// R56: the Doer's menus, the same on every call of a job, go first in the turn with their own mark; the picture
    /// and the changing text come after it, unmarked.
    func testTheRepeatedPartOfATurnGoesFirstAndCached() throws {
        var packet = ContextPacket(appName: "Practice", bundleID: "com.example.practice", windowTitle: "Made up", visibleText: "Made up", cursor: nil)
        packet.screenshot = TestPNG.make(width: 40, height: 30)
        packet.menus = "Format: Font > [Bold | Italic]"
        let request = Doer.request("Make it bold", packet: packet, shot: ScreenshotSize(width: 40, height: 30), done: [])
        let messages = try XCTUnwrap(try body(request)["messages"] as? [[String: Any]])
        let current = try XCTUnwrap(messages.last?["content"] as? [[String: Any]])
        XCTAssertEqual(current.map { $0["type"] as? String }, ["text", "image", "text"])
        XCTAssertEqual(current[0]["text"] as? String, "<menus>\nFormat: Font > [Bold | Italic]\n</menus>")
        XCTAssertEqual(current[0]["cache_control"] as? [String: String], ["type": "ephemeral"])
        XCTAssertNil(current[1]["cache_control"])
        XCTAssertNil(current[2]["cache_control"])
        XCTAssertFalse((current[2]["text"] as? String ?? "").contains("<menus>"))
        // No menus: nothing extra, no mark.
        packet.menus = ""
        let plain = Doer.request("Make it bold", packet: packet, shot: ScreenshotSize(width: 40, height: 30), done: [])
        let turn = try XCTUnwrap((try body(plain)["messages"] as? [[String: Any]])?.last?["content"] as? [[String: Any]])
        XCTAssertEqual(turn.map { $0["type"] as? String }, ["image", "text"])
    }

    func testAFirstQuestionMarksOnlyTheSystemPrompt() throws {
        let sent = try body(request)
        XCTAssertEqual((sent["system"] as? [[String: Any]])?.first?["cache_control"] as? [String: String], ["type": "ephemeral"])
        let messages = try XCTUnwrap(sent["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 1)
        XCTAssertTrue((messages[0]["content"] as? [[String: Any]] ?? []).allSatisfy { $0["cache_control"] == nil })
    }

    func testCachedTokensReachCallsLogAsNumbers() async throws {
        Stub.body = """
            data: {"type":"message_start","message":{"usage":{"input_tokens":400,"cache_creation_input_tokens":0,"cache_read_input_tokens":3226,"output_tokens":1}}}

            data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":7}}

            data: {"type":"message_stop"}

            """
        for try await _ in provider.stream(request) {}
        let line = try XCTUnwrap(try logLines().first)
        XCTAssertEqual(line.cacheReadTokens, 3226)
        XCTAssertEqual(line.cacheWriteTokens, 0)
        XCTAssertEqual(line.inputTokens, 400)
        // Haiku: 400 × $0.10 + 3,226 × $0.01 + 7 × $0.50, per million.
        XCTAssertEqual(line.usd, (400 * 0.10 + 3226 * 0.01 + 7 * 0.50) / 1_000_000, accuracy: 1e-6)
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

    func testACallOverItsTimeCapIsCancelledAndLoggedAsRunaway() async throws {
        Stub.hang = true  // the answer never ends, as a look that keeps thinking
        Stub.body = #"data: {"type":"message_start","message":{"usage":{"input_tokens":7,"output_tokens":1}}}"# + "\n"
        let stopped = expectation(description: "request stopped")
        Stub.stopped = stopped
        var capped = request
        capped.timeLimit = 0.3
        let t0 = Date()
        do {
            for try await _ in provider.stream(capped) {}
            XCTFail("expected runaway")
        } catch {
            XCTAssertEqual(error as? BrainError, .runaway)
        }
        XCTAssertLessThan(Date().timeIntervalSince(t0), 3)
        await fulfillment(of: [stopped], timeout: 5)  // the HTTP request itself was cancelled
        // One line, "runaway" in how the call ended: numbers and fixed words only.
        let lines = try logLines()
        XCTAssertEqual(lines.map(\.error), ["runaway"])
        XCTAssertGreaterThanOrEqual(lines[0].msTotal, 300)
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

    // MARK: R8 What a cut call really used

    /// Stop during a long answer: the API's last numbers never come, so the line holds an estimate of what was
    /// generated and asked for, marked as one, and the day's total and the task cost read the same dollars.
    func testACancelledCallIsLoggedWithWhatItUsedNotItsFirstNumbers() async throws {
        Stub.hang = true
        let words = String(repeating: "made up words ", count: 30)  // 420 characters
        Stub.body = [#"data: {"type":"message_start","message":{"usage":{"input_tokens":7,"output_tokens":1}}}"#,
                     #"data: {"type":"content_block_start","index":0,"content_block":{"type":"server_tool_use","id":"srvtoolu_1","name":"web_search","input":{}}}"#,
                     #"data: {"type":"content_block_start","index":1,"content_block":{"type":"web_search_tool_result","tool_use_id":"srvtoolu_1","content":[]}}"#,
                     #"data: {"type":"content_block_start","index":2,"content_block":{"type":"text","text":""}}"#,
                     #"data: {"type":"content_block_delta","index":2,"delta":{"type":"text_delta","text":"\#(words)"}}"#].joined(separator: "\n") + "\n"
        let stopped = expectation(description: "request stopped")
        Stub.stopped = stopped
        let gotText = expectation(description: "text")
        var task = request
        task.task = 41
        let consumer = Task {
            for try await event in provider.stream(task) { if case .text = event { gotText.fulfill() } }
        }
        await fulfillment(of: [gotText], timeout: 5)
        consumer.cancel()
        await fulfillment(of: [stopped], timeout: 5)
        for _ in 0..<50 where (try? logLines().count) != 1 { try await Task.sleep(for: .milliseconds(100)) }
        let line = try XCTUnwrap(try logLines().first)
        XCTAssertEqual(line.error, "cancelled")
        XCTAssertEqual(line.estimated, true)
        XCTAssertGreaterThanOrEqual(line.outputTokens, 140, "every generated character counts, at 3 a token")
        XCTAssertGreaterThan(line.inputTokens, 7, "the step after the search result reads the context again")
        // One search asked for: its cent is in the line, so in the day's total and the task's cost.
        XCTAssertGreaterThan(line.usd, Model.perSearch)
        XCTAssertEqual(CallLog.cost(ofTask: 41), line.usd, accuracy: 1e-9)
        XCTAssertFalse(String(decoding: CallLog.encode(line), as: UTF8.self).contains("made up"), "numbers only")
    }

    /// No numbers at all before the cut: the request's own size stands in for its input.
    func testACutBeforeTheFirstNumbersCountsTheRequestItself() {
        var parser = SSEParser()
        XCTAssertEqual(parser.cut(prompt: 1234)?.input, 1234)
        _ = try? parser.consume(#"data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":5}}"#)
        XCTAssertNil(parser.cut(prompt: 1234), "the API's last numbers arrived: nothing to estimate")
        let picture = ModelRequest(agent: "unit-test", tier: .main, system: String(repeating: "s", count: 300), text: "t", maxTokens: 1)
        XCTAssertEqual(ClaudeProvider.promptTokens(picture), 101)
    }

    // MARK: Retries before any output

    private var quick: ClaudeProvider {
        var provider = provider
        provider.retryDelays = [0.01, 0.01]
        return provider
    }

    private let answer = """
        data: {"type":"message_start","message":{"usage":{"input_tokens":3,"output_tokens":1}}}
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hi"}}
        data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":2}}
        data: {"type":"message_stop"}

        """

    func testABusyOrRateLimitedRequestIsTriedAgainBeforeAnyOutput() async throws {
        (Stub.statuses, Stub.body) = ([529, 429], answer)
        var events: [ModelEvent] = []
        for try await event in quick.stream(request) { events.append(event) }
        XCTAssertEqual(events.first, .text("Hi"))
        XCTAssertEqual(Stub.count, 3)
        XCTAssertEqual(try logLines().map(\.stop), ["end_turn"], "one line for the call")
    }

    func testRetriesAreBoundedAndNeverPastTheAPIsOwnWait() async throws {
        (Stub.statuses, Stub.body) = ([529, 529, 529, 529], answer)
        await XCTAssertThrowsBrainError(.overloaded) { for try await _ in self.quick.stream(self.request) {} }
        XCTAssertEqual(Stub.count, 3, "two retries, then the error")
        (Stub.statuses, Stub.retryAfter, Stub.count) = ([429], "30", 0)
        await XCTAssertThrowsBrainError(.rateLimited) { for try await _ in self.quick.stream(self.request) {} }
        XCTAssertEqual(Stub.count, 1, "the API asks for longer than Phew waits")
        XCTAssertEqual(ClaudeProvider.wait(1, retryAfter: "2"), 2)
        XCTAssertNil(ClaudeProvider.wait(1, retryAfter: "11"))
        // Other errors are not tried again.
        (Stub.statuses, Stub.retryAfter, Stub.count) = ([400], nil, 0)
        await XCTAssertThrowsBrainError(.failed(status: 400)) { for try await _ in self.quick.stream(self.request) {} }
        XCTAssertEqual(Stub.count, 1)
    }

    /// An error after the answer started is never sent again: the words already shown would come twice.
    func testAnErrorAfterTheAnswerStartedIsNotRetried() async throws {
        Stub.body = """
            data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hel"}}
            data: {"type":"error","error":{"type":"overloaded_error","message":"made up"}}

            """
        await XCTAssertThrowsBrainError(.overloaded) { for try await _ in self.quick.stream(self.request) {} }
        XCTAssertEqual(Stub.count, 1)
    }

    private func XCTAssertThrowsBrainError(_ expected: BrainError, _ body: () async throws -> Void,
                                           file: StaticString = #filePath, line: UInt = #line) async {
        do {
            try await body()
            XCTFail("expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? BrainError, expected, file: file, line: line)
        }
    }
}
