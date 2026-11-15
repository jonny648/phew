import Foundation

/// One JSON line per model call in ~/Library/Application Support/Phew/calls.log: what it cost and how long it
/// took. Never the question, the screen, the answer or the key.
enum CallLog {
    /// A var only so unit tests can write elsewhere.
    nonisolated(unsafe) static var url = URL.applicationSupportDirectory.appending(path: "Phew/calls.log")
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
    }

    static func line(_ request: ModelRequest, usage: Usage, msFirst: Int?, msTotal: Int, stop: String?, error: String?,
                     at date: Date = Date()) -> Line {
        let model = request.tier.model
        return Line(ts: date.ISO8601Format(), agent: request.agent, tier: request.tier.rawValue, model: model.id,
                    inputTokens: usage.input, outputTokens: usage.output, cacheWriteTokens: usage.cacheWrite,
                    cacheReadTokens: usage.cacheRead, usd: (model.cost(usage) * 1_000_000).rounded() / 1_000_000,
                    msFirstToken: msFirst, msTotal: msTotal, stop: stop, error: error, task: request.task)
    }

    static func encode(_ line: Line) -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = .sortedKeys
        return ((try? encoder.encode(line)) ?? Data()) + Data("\n".utf8)
    }

    static func record(_ request: ModelRequest, usage: Usage, msFirst: Int?, msTotal: Int, stop: String?, error: String?) {
        let line = line(request, usage: usage, msFirst: msFirst, msTotal: msTotal, stop: stop, error: error)
        shellLog("call \(line.agent) \(line.model): in \(line.inputTokens) out \(line.outputTokens) tokens, $\(line.usd), first token \(line.msFirstToken.map { "\($0) ms" } ?? "none"), total \(line.msTotal) ms, \(line.stop ?? line.error ?? "")")
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

    /// What one task cost so far, in USD, summed from its lines in calls.log (PA.5). Waits for writes still queued.
    static func cost(ofTask task: Int) -> Double {
        let url = url
        return queue.sync {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            return text.split(separator: "\n").compactMap { try? decoder.decode(Line.self, from: Data($0.utf8)) }
                .filter { $0.task == task }.reduce(0) { $0 + $1.usd }
        }
    }

    #if DEBUG
    nonisolated(unsafe) private static var spent = 0.0
    /// USD of every call recorded so far in this run, for the self-check.
    static var spentUSD: Double { queue.sync { spent } }
    #endif
}
