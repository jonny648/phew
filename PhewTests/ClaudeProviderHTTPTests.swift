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
        XCTAssertEqual(events, [.text("Hel"), .text("lo"), .usage(Usage(input: 12, output: 5)), .stop("end_turn")])
        let lines = try logLines()
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines.first?.agent, "unit-test")
        XCTAssertEqual(lines.first?.stop, "end_turn")
        XCTAssertEqual(lines.first?.inputTokens, 12)
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
