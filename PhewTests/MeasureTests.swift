import XCTest

/// N4.0: `Tools/measure-calls.sh` on a made-up calls.log. Numbers only come out; no model, no network.
final class MeasureTests: XCTestCase {
    func testTheMeasurePrintsGapsJobsLooksAndCostFromAMadeUpLog() throws {
        let lines = [
            #"{"agent":"conductor","tier":"small","ts":"2026-11-16T08:00:00Z","usd":0.0002,"input_tokens":1}"#,
            #"{"agent":"guide","tier":"main","ts":"2026-11-16T08:00:02Z","usd":0.013}"#,
            #"{"agent":"follower","tier":"main","ts":"2026-11-16T08:00:10Z","usd":0.0025}"#,
            #"{"agent":"follower","tier":"main","ts":"2026-11-16T08:00:20Z","usd":0.0025}"#,
            #"{"agent":"conductor","tier":"small","ts":"2026-11-16T08:20:00Z","usd":0.0002}"#,
            #"{"agent":"doer","tier":"main","ts":"2026-11-16T08:20:02Z","usd":0.003}"#,
            #"{"agent":"doer","tier":"main","ts":"2026-11-16T08:20:05Z","usd":0.003}"#,
            #"{"agent":"doer","tier":"main","ts":"2026-11-16T08:20:08Z","usd":0.003}"#,
            "not a line of the log",
            #"{"agent":"conductor","tier":"small","ts":"2026-11-16T10:00:00Z","usd":0.0002}"#,
            #"{"agent":"guide","tier":"main","ts":"2026-11-16T10:00:02Z","usd":0.013}"#,
        ]
        let log = FileManager.default.temporaryDirectory.appending(path: "phew-measure-\(UUID().uuidString).log")
        try lines.joined(separator: "\n").write(to: log, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: log) }
        let script = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Tools/measure-calls.sh")
        let process = Process(), out = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [script.path, log.path]
        process.standardOutput = out
        try process.run()
        let text = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertTrue(text.contains("calls: 10"), text)
        // Requests at 8:00, 8:20 and 10:00: pauses of 20 and 100 minutes.
        XCTAssertTrue(text.contains("between requests (conductor calls): 2 gaps, median 60.00 min, middle half 40.00 to 80.00 min, over 5 min 100.0%, over 60 min 50.0%"), text)
        XCTAssertTrue(text.contains("jobs: 1, calls per job median 3.0, mean 3.00, most 3"), text)
        XCTAssertTrue(text.contains("guides with looks: 1, looks per guide median 2.0, mean 2.00, most 2"), text)
        XCTAssertTrue(text.contains("doer: 3 calls, $0.0090 in all, $0.00300 a call"), text)
        XCTAssertTrue(text.contains("cost: total $0.0406"), text)
    }
}
