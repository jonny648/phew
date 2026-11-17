import Foundation

/// The caps of saved conversations (docs/05-map.md 5.8.1, decision D3), kept by code.
enum MapThreads {
    static let maxTurns = 40
    static let maxCharacters = 60_000
    static let maxThreads = 200
}

/// A saved conversation, for the menu's Conversations panel and for Open. `turns` is empty in the list.
struct SavedThread: Sendable, Identifiable, Equatable {
    let id: Int64
    /// When its last turn ended, ISO 8601.
    let time: String
    /// The name of its Project, empty when it has none.
    let project: String
    let projectID: Int64?
    /// The first question as shown, on one line.
    let first: String
    var turns: [Turn] = []
    let sensitive: Bool

    /// A kept question as the user sees it: without the "Question: " the working memory adds for the model.
    static func shown(_ question: String) -> String {
        if question.hasPrefix("Question: none.") { return "(what was on screen)" }
        let words = question.hasPrefix("Question: ") ? String(question.dropFirst("Question: ".count)) : question
        return words
    }
}

/// D3: conversations kept as text in the Map, one row per conversation in `threads` (5.8.1). Code writes them, no
/// model. Not in recall, not in `search_map`: the table has no text index.
extension MapStore {
    private struct Stored: Codable { var q: String; var a: String }

    /// Writes the conversation's turns, filtered again and capped, as thread `id` or as a new one. The file is the one
    /// its Project's sensitive mark names. Nil, writing nothing, when there is no turn, or when thread `id` was forgotten
    /// or wiped meanwhile (a forgotten thread is never written again). Then only the newest 200 threads stay.
    @discardableResult
    func saveThread(id: Int64?, turns: [Turn], project: Int64?, now: Date = .now) throws -> Int64? {
        let turns = Self.capped(turns.map { Turn(question: SecretsFilter.clean($0.question), answer: SecretsFilter.clean($0.answer)) })
        guard !turns.isEmpty else { return nil }
        return try db.transaction {
            if let id, try db.scalar("SELECT count(*) FROM all_threads WHERE id = ? AND deleted = ''", [.int(id)]) == .int(0) {
                return nil
            }
            let row = try project.flatMap {
                try db.query("SELECT sensitive FROM all_nodes WHERE id = ? AND deleted = '' AND valid_to IS NULL", [.int($0)]).first
            }
            let sensitive = row?.int("sensitive") == 1
            let thread = try id ?? db.nextID()
            for file in ["main", "s"] { try db.query("DELETE FROM \(file).threads WHERE id = ?", [.int(thread)]) }
            try db.query("INSERT INTO \(sensitive ? "s" : "main").threads (id, time, project, turns, sensitive) VALUES (?, ?, ?, ?, ?)",
                         [.int(thread), .text(Self.iso(now)), row == nil ? .null : SQLValue(project),
                          .text(Self.json(turns.map { Stored(q: $0.question, a: $0.answer) })), .int(sensitive ? 1 : 0)])
            for file in ["main", "s"] {
                try db.query("""
                    DELETE FROM \(file).threads WHERE deleted = '' AND id NOT IN
                      (SELECT id FROM all_threads WHERE deleted = '' ORDER BY time DESC, id DESC LIMIT ?)
                    """, [.int(Int64(MapThreads.maxThreads))])
            }
            return thread
        }
    }

    /// The saved threads, newest first, without their turns. Nothing in Recently deleted.
    func threads() -> [SavedThread] {
        let rows = (try? db.query("""
            SELECT t.id, t.time, t.project, t.sensitive, json_extract(t.turns, '$[0].q') AS first,
              (SELECT n.name FROM all_nodes n WHERE n.id = t.project AND n.deleted = '') AS name
            FROM all_threads t WHERE t.deleted = '' ORDER BY t.time DESC, t.id DESC
            """)) ?? []
        return rows.compactMap(Self.thread)
    }

    /// One saved thread with its turns, oldest first. Nil when it is not there or in Recently deleted.
    func thread(_ id: Int64) -> SavedThread? {
        guard let row = try? db.query("""
            SELECT t.*, json_extract(t.turns, '$[0].q') AS first,
              (SELECT n.name FROM all_nodes n WHERE n.id = t.project AND n.deleted = '') AS name
            FROM all_threads t WHERE t.id = ? AND t.deleted = ''
            """, [.int(id)]).first, var thread = Self.thread(row) else { return nil }
        let stored: [Stored] = Self.list(row.text("turns"))
        thread.turns = stored.map { Turn(question: $0.q, answer: $0.a) }
        return thread
    }

    /// Forgets one thread: hidden at once, in Recently deleted for 30 days like any forget, in the sensitive file's
    /// `forgets` when the thread is sensitive. Writes no past question. Nil when it is not there.
    @discardableResult
    func forgetThread(_ id: Int64, now: Date = .now) throws -> Forgotten? {
        try db.transaction {
            guard let row = try db.query("SELECT sensitive, json_extract(turns, '$[0].q') AS first FROM all_threads WHERE id = ? AND deleted = ''",
                                         [.int(id)]).first else { return nil }
            let first = SavedThread.shown(row.text("first") ?? "").split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
            let label = SecretsFilter.clean("Forgot the conversation \"\(first.prefix(60))\". In Recently deleted for \(Self.daysInRecentlyDeleted) days.")
            let forget = try db.nextID()
            try db.query("INSERT INTO \(row.int("sensitive") == 1 ? "s" : "main").forgets (id, time, label) VALUES (?, ?, ?)",
                         [.int(forget), .text(Self.iso(now)), .text(label)])
            for file in ["main", "s"] {
                try db.query("""
                    UPDATE \(file).threads SET deleted = CASE WHEN deleted = '' THEN json_array(?2) ELSE json_insert(deleted, '$[#]', ?2) END
                    WHERE id = ?1
                    """, [.int(id), .int(forget)])
            }
            return Forgotten(id: forget, label: label, othersWithName: 0)
        }
    }

    /// The caps of 5.8.1: the last 40 turns, then the oldest turns go until 60,000 characters are left; one turn alone
    /// over that is cut.
    static func capped(_ turns: [Turn]) -> [Turn] {
        var out = Array(turns.suffix(MapThreads.maxTurns))
        func size(_ turns: [Turn]) -> Int { turns.reduce(0) { $0 + $1.question.count + $1.answer.count } }
        while out.count > 1, size(out) > MapThreads.maxCharacters { out.removeFirst() }
        if let only = out.first, size(out) > MapThreads.maxCharacters {
            let question = String(only.question.prefix(MapThreads.maxCharacters))
            out = [Turn(question: question, answer: String(only.answer.prefix(MapThreads.maxCharacters - question.count)))]
        }
        return out
    }

    private static func thread(_ row: SQLRow) -> SavedThread? {
        guard let id = row.int("id") else { return nil }
        let line = SavedThread.shown(row.text("first") ?? "").split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let first = line.count > 80 ? String(line.prefix(79)) + "…" : line  // cut to one line for the panel
        return SavedThread(id: id, time: row.text("time") ?? "", project: row.text("name") ?? "", projectID: row.int("project"),
                           first: first, sensitive: row.int("sensitive") == 1)
    }
}
