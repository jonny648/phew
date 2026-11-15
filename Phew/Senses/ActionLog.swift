import Foundation

/// One JSON line per action in ~/Library/Application Support/Phew/actions.log, beside calls.log (docs/13-hand.md
/// 13.6, guard 11). Numbers and fixed words only: never a typed text, an element's name, a window title or an app.
enum ActionLog {
    /// A var only so unit tests can write elsewhere.
    nonisolated(unsafe) static var url = URL.applicationSupportDirectory.appending(path: "Phew/actions.log")
    private static let queue = DispatchQueue(label: "Phew.ActionLog")

    struct Line: Codable, Equatable {
        var ts: String
        var job: Int
        var step: Int
        var kind: String
        /// macOS's own role word, or "other" when an app gives anything else.
        var role: String
        var ended: String
        var marked: Bool
        var ms: Int
        var chars: Int
    }

    static func line(job: Int, step: Int, kind: HandStep.Kind, role: String, ended: HandEnd, marked: Bool, ms: Int,
                     chars: Int, at date: Date = Date()) -> Line {
        // An app names its own roles: keep only the plain AX word, so no text can ride in on it.
        let fixedRole = role.range(of: #"^AX[A-Za-z]{1,40}$"#, options: .regularExpression) != nil ? role : "other"
        return Line(ts: date.ISO8601Format(), job: job, step: step, kind: kind.rawValue, role: fixedRole,
                    ended: ended.rawValue, marked: marked, ms: ms, chars: chars)
    }

    static func record(_ line: Line) {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = .sortedKeys
        let data = ((try? encoder.encode(line)) ?? Data()) + Data("\n".utf8)
        let url = url
        queue.async {
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

    /// Waits for lines still being written (tests).
    static func flush() { queue.sync {} }
}
