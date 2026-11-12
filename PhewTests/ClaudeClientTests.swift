import XCTest
@testable import Phew

/// The Claude client offline: canned SSE lines, request bodies, cost arithmetic, the key store. No network.
final class ClaudeClientTests: XCTestCase {
    private func parse(_ lines: [String]) throws -> (texts: [String], parser: SSEParser) {
        var parser = SSEParser()
        var texts: [String] = []
        for line in lines { if let text = try parser.consume(line) { texts.append(text) } }
        return (texts, parser)
    }

    private let start = #"data: {"type":"message_start","message":{"id":"msg_1","type":"message","role":"assistant","content":[],"model":"claude-sonnet-5-5","usage":{"input_tokens":25,"output_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}"#
    private func text(_ index: Int, _ piece: String) -> String {
        #"data: {"type":"content_block_delta","index":\#(index),"delta":{"type":"text_delta","text":"\#(piece)"}}"#
    }
    private func stop(_ reason: String, output: Int) -> String {
        #"data: {"type":"message_delta","delta":{"stop_reason":"\#(reason)","stop_sequence":null},"usage":{"output_tokens":\#(output)}}"#
    }
    private let end = #"data: {"type":"message_stop"}"#

    func testTextDeltasUsageAndStopReason() throws {
        let (texts, parser) = try parse([
            "event: message_start", start, "",
            #"data: {"type":"content_block_start","index":0,"content_block":{"type":"thinking","thinking":""}}"#,
            #"data: {"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":""}}"#,
            #"data: {"type":"content_block_delta","index":0,"delta":{"type":"signature_delta","signature":"abc"}}"#,
            #"data: {"type": "ping"}"#,
            text(1, "Hel"), text(1, "lo"),
            stop("end_turn", output: 15), end,
        ])
        XCTAssertEqual(texts, ["Hel", "lo"])
        XCTAssertEqual(parser.usage, Usage(input: 25, output: 15))
        XCTAssertEqual(parser.stopReason, "end_turn")
        XCTAssertNoThrow(try parser.end())
    }

    func testStructuredAnswerArrivesInPieces() throws {
        let pieces = [#"{\"explanation\":\"A Fou"#, #"rier series\",\"st"#, #"eps\":[]}"#]
        let (texts, _) = try parse([start] + pieces.map { text(0, $0) } + [stop("end_turn", output: 9), end])
        XCTAssertEqual(texts.joined(), #"{"explanation":"A Fourier series","steps":[]}"#)
    }

    func testErrorEventMidStreamThrows() throws {
        var parser = SSEParser()
        XCTAssertEqual(try parser.consume(text(0, "Hi")), "Hi")
        XCTAssertThrowsError(try parser.consume(#"data: {"type": "error", "error": {"type": "overloaded_error", "message": "Overloaded"}}"#)) {
            XCTAssertEqual($0 as? BrainError, .overloaded)
        }
        XCTAssertThrowsError(try parser.consume(#"data: {"type":"error","error":{"type":"rate_limit_error","message":"slow down"}}"#)) {
            XCTAssertEqual($0 as? BrainError, .rateLimited)
        }
    }

    func testRefusalAndCutStreamAreErrors() throws {
        let (_, refused) = try parse([start, stop("refusal", output: 3), end])
        XCTAssertThrowsError(try refused.end()) { XCTAssertEqual($0 as? BrainError, .refused) }
        let (_, cut) = try parse([start, text(0, "Half an ans")])
        XCTAssertThrowsError(try cut.end()) { XCTAssertEqual($0 as? BrainError, .network) }
    }

    func testFallbackAttemptsAreSummed() throws {
        let final = #"data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"input_tokens":400,"output_tokens":200,"iterations":[{"type":"message","model":"claude-sonnet-5-5","input_tokens":410,"output_tokens":20,"cache_read_input_tokens":0,"cache_creation_input_tokens":0},{"type":"fallback_message","model":"claude-sonnet-5","input_tokens":400,"output_tokens":200,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}]}}"#
        let (_, parser) = try parse([start, final, end])
        XCTAssertEqual(parser.usage, Usage(input: 810, output: 220))
    }

    func testHTTPStatusesMapToTheReadableSet() {
        XCTAssertEqual(BrainError(status: 401), .badKey)
        XCTAssertEqual(BrainError(status: 429), .rateLimited)
        XCTAssertEqual(BrainError(status: 529), .overloaded)
        XCTAssertEqual(BrainError(status: 500), .overloaded)
        XCTAssertEqual(BrainError(status: 400), .failed(status: 400))
        XCTAssertEqual(BrainError(URLError(.notConnectedToInternet)), .network)
    }

    func testCostFromTheTable() {
        XCTAssertEqual(Tier.main.model.cost(Usage(input: 1000, output: 500)), 0.007, accuracy: 1e-12)
        XCTAssertEqual(Tier.small.model.cost(Usage(input: 2000, output: 100)), 0.00025, accuracy: 1e-12)
        XCTAssertEqual(Tier.main.model.cost(Usage(cacheWrite: 1_000_000, cacheRead: 1_000_000)), 2.60, accuracy: 1e-9)
    }

    func testLogLineHoldsCountsOnly() throws {
        let request = ModelRequest(agent: "guide", tier: .main, system: "secret system", text: "the student's screen", maxTokens: 10)
        let line = CallLog.line(request, usage: Usage(input: 1000, output: 500), msFirst: 800, msTotal: 2100, stop: "end_turn",
                                error: nil, at: Date(timeIntervalSince1970: 0))
        let json = String(decoding: CallLog.encode(line), as: UTF8.self)
        XCTAssertEqual(json, #"{"agent":"guide","cache_read_tokens":0,"cache_write_tokens":0,"input_tokens":1000,"model":"claude-sonnet-5-5","ms_first_token":800,"ms_total":2100,"output_tokens":500,"stop":"end_turn","tier":"main","ts":"1970-01-01T00:00:00Z","usd":0.007}"# + "\n")
    }

    private func body(_ request: ModelRequest) throws -> [String: Any] {
        let http = try ClaudeProvider.urlRequest(request, key: "test-key-not-real")
        XCTAssertEqual(http.value(forHTTPHeaderField: "x-api-key"), "test-key-not-real")
        XCTAssertEqual(http.value(forHTTPHeaderField: "anthropic-version"), "2026-10-21")
        return try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(http.httpBody)) as? [String: Any])
    }

    private func content(_ body: [String: Any]) -> [[String: Any]] {
        ((body["messages"] as? [[String: Any]])?.first?["content"] as? [[String: Any]]) ?? []
    }

    func testRequestUsesTheTiersModelAndKeepsTheKeyOutOfTheBody() throws {
        let small = try body(ModelRequest(agent: "conductor", tier: .small, system: "s", text: "t", schema: Conductor.schema, maxTokens: 1024))
        XCTAssertEqual(small["model"] as? String, "claude-haiku-5-5")
        XCTAssertNil(small["fallbacks"])  // Haiku 5.5 has no server-side fallback
        XCTAssertEqual((small["output_config"] as? [String: Any])?["effort"] as? String, "low")
        XCTAssertNotNil(((small["output_config"] as? [String: Any])?["format"] as? [String: Any])?["schema"])
        XCTAssertNil(small["thinking"])
        XCTAssertNil(small["temperature"])
        XCTAssertEqual(small["stream"] as? Bool, true)

        let mainRequest = ModelRequest(agent: "guide", tier: .main, system: "s", text: "t", maxTokens: 8192)
        let main = try body(mainRequest)
        XCTAssertEqual(main["model"] as? String, "claude-sonnet-5-5")
        XCTAssertEqual(main["fallbacks"] as? String, "default")
        XCTAssertEqual(try ClaudeProvider.urlRequest(mainRequest, key: "k").value(forHTTPHeaderField: "anthropic-beta"), "server-side-fallback-2026-07-01")
        XCTAssertFalse(String(decoding: try XCTUnwrap(ClaudeProvider.urlRequest(mainRequest, key: "test-key-not-real").httpBody), as: UTF8.self).contains("test-key-not-real"))
    }

    func testImageBlockOnlyWithAScreenshot() throws {
        let png = TestPNG.make(width: 400, height: 300)
        let packet = ContextPacket(appName: "Sketchpad", bundleID: "x", windowTitle: "w", visibleText: "Layers", cursor: nil, screenshot: png)
        let with = content(try body(Guide.request("Where?", packet: packet, route: .guide, shot: ScreenshotSize(png: png))))
        XCTAssertEqual(with.map { $0["type"] as? String }, ["image", "text"])
        XCTAssertEqual((with[0]["source"] as? [String: Any])?["media_type"] as? String, "image/png")
        XCTAssertEqual((with[0]["source"] as? [String: Any])?["data"] as? String, png.base64EncodedString())

        var plain = packet
        plain.screenshot = nil
        let without = content(try body(Guide.request("Where?", packet: plain, route: .guide, shot: nil)))
        XCTAssertEqual(without.map { $0["type"] as? String }, ["text"])
    }

    func testMissingKeyFailsWithoutACall() async {
        let provider = ClaudeProvider(key: { nil })
        do {
            for try await _ in provider.stream(ModelRequest(agent: "check", tier: .small, system: "", text: "", maxTokens: 1)) {}
            XCTFail("expected noKey")
        } catch {
            XCTAssertEqual(error as? BrainError, .noKey)
        }
    }

    /// Writes, reads and deletes a made-up key under a test-only service, never the app's own item.
    func testKeyStoreRoundTrip() throws {
        let store = KeyStore(service: "com.gianlucatroietto.Phew.tests", account: "unit-test")
        try store.save("  made-up-test-value\n")
        XCTAssertEqual(store.read(), "made-up-test-value")
        try store.save("second-made-up-value")
        XCTAssertEqual(store.read(), "second-made-up-value")
        try store.delete()
        XCTAssertNil(store.read())
        XCTAssertNoThrow(try store.delete())
    }
}

/// A PNG header with the given size: enough for the size reader and the request builder.
enum TestPNG {
    static func make(width: UInt32, height: UInt32) -> Data {
        var data = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13]) + Data("IHDR".utf8)
        for value in [width, height] { withUnsafeBytes(of: value.bigEndian) { data.append(contentsOf: $0) } }
        return data + Data([8, 6, 0, 0, 0])
    }
}
