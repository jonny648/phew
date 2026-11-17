import Foundation
import os

/// One JSON line per model call in ~/Library/Application Support/Phew/calls.log: what it cost and how long it
/// took. Never the question, the screen, the answer or the key.
enum CallLog {
    /// A var only so unit tests can write elsewhere.
    nonisolated(unsafe) static var url = URL.applicationSupportDirectory.appending(path: "Phew/calls.log")
    /// The app's running total of today's spend (N2.12), updated by every `record`. A var only so unit tests can
    /// swap it.
    nonisolated(unsafe) static var spend = Spend()
    private static let queue = DispatchQueue(label: "Phew.CallLog")

    struct Line: Codable, Equatable {
        var ts: String
        var agent: String
        var tier: String
        var model: String
        var inputTokens: Int
        var outputTokens: Int
        var cacheWriteTokens: Int
        var cacheReadTokens: Int
        var usd: Double
        /// Nil when no text arrived.
        var msFirstToken: Int?
        var msTotal: Int
        var stop: String?
        var error: String?
        /// The task number for a Runner call (PA.5); absent outside a task.
        var task: Int? = nil
        /// The part of `cacheWriteTokens` written for one hour (D1); absent when none.
        var cacheWriteHourTokens: Int? = nil
        /// R8: true when the stream was cut before the API's last usage numbers, so the tokens are Phew's estimate.
        var estimated: Bool? = nil
        /// NB.9: what a run through Claude Code would have cost, counted, not charged: the user's Claude plan pays, so
        /// `usd` is 0 and the day's money ceiling is untouched. Absent for an API call.
        var planUsd: Double? = nil

        /// `ts` as a date; nil when unreadable.
        var date: Date? { try? Date(ts, strategy: .iso8601) }
    }

    static func line(_ request: ModelRequest, usage: Usage, msFirst: Int?, msTotal: Int, stop: String?, error: String?,
                     estimated: Bool = false, at date: Date = Date()) -> Line {
        let model = request.tier.model
        return Line(ts: date.ISO8601Format(), agent: request.agent, tier: request.tier.rawValue, model: model.id,
                    inputTokens: usage.input, outputTokens: usage.output, cacheWriteTokens: usage.cacheWrite,
                    cacheReadTokens: usage.cacheRead, usd: (model.cost(usage) * 1_000_000).rounded() / 1_000_000,
                    msFirstToken: msFirst, msTotal: msTotal, stop: stop, error: error, task: request.task,
                    cacheWriteHourTokens: usage.cacheWriteHour > 0 ? usage.cacheWriteHour : nil, estimated: estimated ? true : nil)
    }

    static func encode(_ line: Line) -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = .sortedKeys
        return ((try? encoder.encode(line)) ?? Data()) + Data("\n".utf8)
    }

    static func record(_ request: ModelRequest, usage: Usage, msFirst: Int?, msTotal: Int, stop: String?, error: String?,
                       estimated: Bool = false, at date: Date = Date()) {
        record(line(request, usage: usage, msFirst: msFirst, msTotal: msTotal, stop: stop, error: error, estimated: estimated, at: date))
    }

    /// One line as it is: numbers and names only.
    static func record(_ line: Line) {
        shellLog("call \(line.agent) \(line.model): in \(line.inputTokens) out \(line.outputTokens) tokens, $\(line.usd), first token \(line.msFirstToken.map { "\($0) ms" } ?? "none"), total \(line.msTotal) ms, \(line.stop ?? line.error ?? "")")
        // Before the write is queued: a read of the file that `spend` makes meanwhile either finds the line or comes first.
        spend.add(line)
        let url = url
        queue.async {
            #if DEBUG
            spent += line.usd
            #endif
            let data = encode(line)
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let handle = try? FileHandle(forWritingTo: url) {
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
                try? handle.close()
            } else {
                try? data.write(to: url)
            }
        }
    }

    /// Every readable line of calls.log: numbers and names only. Waits for writes still queued.
    // shortcut: reads the whole file each time; the limits read it only at launch and when the day changes (N2.12),
    // a finished task once for its cost. Keep only recent lines if calls.log ever grows past a few MB.
    static func lines() -> [Line] {
        let url = url
        return queue.sync {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            return text.split(separator: "\n").compactMap { try? decoder.decode(Line.self, from: Data($0.utf8)) }
        }
    }

    /// What one task cost so far, in USD, summed from its lines in calls.log (PA.5).
    static func cost(ofTask task: Int) -> Double {
        lines().filter { $0.task == task }.reduce(0) { $0 + $1.usd }
    }

    /// What the calls of `day`'s local day cost, in USD (the daily ceiling, `Limits`).
    static func spent(_ lines: [Line], on day: Date, calendar: Calendar = .current) -> Double {
        lines.filter { $0.date.map { calendar.isDate($0, inSameDayAs: day) } ?? false }.reduce(0) { $0 + $1.usd }
    }

    /// D1: whether the system prompt's cache mark lasts one hour, chosen at each started request from this Mac's own
    /// calls (`CacheLife`). False until then. Read by `ClaudeProvider` for every call.
    static var hourCache: Bool {
        get { hour.withLock { $0 } }
        set { hour.withLock { $0 = newValue } }
    }
    private static let hour = OSAllocatedUnfairLock(initialState: false)

    #if DEBUG
    nonisolated(unsafe) private static var spent = 0.0
    /// USD of every call recorded so far in this run, for the self-check.
    static var spentUSD: Double { queue.sync { spent } }
    #endif
}
