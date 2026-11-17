import Foundation
import SQLCipher

/// A value read from or bound to SQLite.
enum SQLValue: Equatable, Sendable, ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByNilLiteral {
    case null, int(Int64), real(Double), text(String)
    init(stringLiteral value: String) { self = .text(value) }
    init(integerLiteral value: Int64) { self = .int(value) }
    init(nilLiteral: ()) { self = .null }
    init(_ value: Int64?) { self = value.map { .int($0) } ?? .null }
    init(_ value: String?) { self = value.map { .text($0) } ?? .null }
}

typealias SQLRow = [String: SQLValue]

extension Dictionary where Key == String, Value == SQLValue {
    func int(_ column: String) -> Int64? { if case .int(let v)? = self[column] { return v }; return nil }
    func real(_ column: String) -> Double? {
        switch self[column] {
        case .real(let v)?: return v
        case .int(let v)?: return Double(v)
        default: return nil
        }
    }
    func text(_ column: String) -> String? { if case .text(let v)? = self[column] { return v }; return nil }
}

/// The Map's one SQLite connection, and the only file in Phew that calls `sqlite3_*` (SQLCipher, never the system
/// SQLite). `map.sqlite` is `main` with key 1; `map-sensitive.sqlite` is attached as `s` with key 2 (docs/05-map-storage.md 5.12).
/// Keys never appear in SQL text, logs or errors: they are passed to `sqlite3_key` and bound as an ATTACH parameter.
/// Errors carry a SQLite result code and a fixed step name only, never SQL, a key or any Map words.
final class Database {
    struct Failure: Error, Equatable {
        let code: Int32
        let step: String
    }

    private var handle: OpaquePointer?

    #if DEBUG
    /// Unit tests only: each statement's SQL as it runs, to count reads (R50). Never set by the app.
    var traced: ((String) -> Void)?
    #endif

    /// `folder` nil: both databases in memory with no key (unit tests). Keys nil with a folder: plain files, used only
    /// by the secure-delete test, which must see plain pages. The app always passes both keys (MapStore).
    init(folder: URL?, key: String?, sensitiveKey: String?) throws {
        guard (key == nil) == (sensitiveKey == nil) else { throw Failure(code: SQLITE_MISUSE, step: "keys") }
        let mainPath = folder?.appending(path: "map.sqlite").path ?? ":memory:"
        let sensitivePath = folder?.appending(path: "map-sensitive.sqlite").path ?? ":memory:"
        guard sqlite3_open_v2(mainPath, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK else {
            let code = handle.map { sqlite3_errcode($0) } ?? SQLITE_CANTOPEN
            close()
            throw Failure(code: code, step: "open")
        }
        // Wait up to 2 s for a lock another connection holds, on both files (the attached one shares this connection), instead of failing at once (R28).
        sqlite3_busy_timeout(handle, 2000)
        do {
            if let key {
                // The key goes first on the connection, as the text x'<hex>' with its length, never the raw bytes.
                let raw = try Self.rawKey(key)
                let rc = raw.withCString { sqlite3_key(handle, $0, Int32(strlen($0))) }
                guard rc == SQLITE_OK else { throw Failure(code: rc, step: "key") }
            }
            // A build that links the system SQLite by mistake runs with no encryption and an empty cipher_version.
            guard case .text(let cipher) = try scalar("PRAGMA cipher_version"), cipher.hasPrefix("4.20.0") else {
                throw Failure(code: SQLITE_ERROR, step: "cipher version")
            }
            try check("SELECT count(*) FROM main.sqlite_master", step: "key check")
            // Before the ATTACH, so the sensitive file inherits it.
            try check("PRAGMA secure_delete = ON", step: "settings")
            try check("PRAGMA temp_store = MEMORY", step: "settings")
            try check("PRAGMA main.journal_mode = DELETE", step: "settings")
            if let sensitiveKey {
                try check("ATTACH DATABASE ?1 AS s KEY ?2", [.text(sensitivePath), .text(Self.rawKey(sensitiveKey))], step: "attach")
            } else {
                try check("ATTACH DATABASE ?1 AS s", [.text(sensitivePath)], step: "attach")
            }
            try check("SELECT count(*) FROM s.sqlite_master", step: "sensitive key check")
            try check("PRAGMA s.secure_delete = ON", step: "settings")
            try check("PRAGMA s.journal_mode = DELETE", step: "settings")
            try createSchema()
            // The high-water mark is stored, and raised to the highest id found, so an id is never handed out twice.
            try check("""
                INSERT INTO main.counter (one, last) SELECT 1, coalesce(max(m), 0) FROM (
                  SELECT max(id) m FROM main.nodes UNION ALL SELECT max(id) FROM s.nodes
                  UNION ALL SELECT max(id) FROM main.edges UNION ALL SELECT max(id) FROM s.edges
                  UNION ALL SELECT max(id) FROM main.events UNION ALL SELECT max(id) FROM s.events
                  UNION ALL SELECT max(id) FROM main.forgets UNION ALL SELECT max(id) FROM s.forgets
                  UNION ALL SELECT max(id) FROM main.threads UNION ALL SELECT max(id) FROM s.threads) WHERE true
                ON CONFLICT (one) DO UPDATE SET last = max(last, excluded.last)
                """, step: "counter")
        } catch {
            close()
            throw error
        }
    }

    deinit { close() }

    func close() {
        if let handle { sqlite3_close_v2(handle) }
        handle = nil
    }

    /// One id counter across both files and all tables, so a sensitive row and a normal row never share an id.
    /// Stored in `main.counter`, so an id is never reused, even after the top row is wiped for real.
    func nextID() throws -> Int64 {
        guard let id = try scalar("UPDATE main.counter SET last = last + 1 RETURNING last").intValue else {
            throw Failure(code: SQLITE_ERROR, step: "counter")
        }
        return id
    }

    /// Runs one statement and returns its rows.
    @discardableResult
    func query(_ sql: String, _ params: [SQLValue] = []) throws -> [SQLRow] {
        guard let handle else { throw Failure(code: SQLITE_MISUSE, step: "closed") }
        #if DEBUG
        traced?(sql)
        #endif
        var statement: OpaquePointer?
        var rc = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
        guard rc == SQLITE_OK, let statement else { throw Failure(code: rc, step: "prepare") }
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (index, value) in params.enumerated() {
            let position = Int32(index + 1)
            switch value {
            case .null: rc = sqlite3_bind_null(statement, position)
            case .int(let v): rc = sqlite3_bind_int64(statement, position, v)
            case .real(let v): rc = sqlite3_bind_double(statement, position, v)
            case .text(let v): rc = sqlite3_bind_text(statement, position, v, -1, transient)
            }
            guard rc == SQLITE_OK else { throw Failure(code: rc, step: "bind") }
        }
        var rows: [SQLRow] = []
        while true {
            rc = sqlite3_step(statement)
            if rc == SQLITE_DONE { return rows }
            guard rc == SQLITE_ROW else { throw Failure(code: rc, step: "step") }
            var row: SQLRow = [:]
            for column in 0..<sqlite3_column_count(statement) {
                let name = String(cString: sqlite3_column_name(statement, column))
                switch sqlite3_column_type(statement, column) {
                case SQLITE_INTEGER: row[name] = .int(sqlite3_column_int64(statement, column))
                case SQLITE_FLOAT: row[name] = .real(sqlite3_column_double(statement, column))
                case SQLITE_TEXT: row[name] = .text(String(cString: sqlite3_column_text(statement, column)))
                default: row[name] = .null   // NULL, and the empty embedding blobs
                }
            }
            rows.append(row)
        }
    }

    /// The value of a one-column query's first row, or null.
    func scalar(_ sql: String, _ params: [SQLValue] = []) throws -> SQLValue {
        try query(sql, params).first?.values.first ?? .null
    }

    /// Runs `body` in one transaction across both files: all or nothing (rollback journal, see 5.12).
    func transaction<T>(_ body: () throws -> T) throws -> T {
        try query("BEGIN IMMEDIATE")
        do {
            let result = try body()
            try query("COMMIT")
            return result
        } catch {
            _ = try? query("ROLLBACK")
            throw error
        }
    }

    // MARK: - Private

    private func check(_ sql: String, _ params: [SQLValue] = [], step: String) throws {
        do { try query(sql, params) } catch let failure as Failure { throw Failure(code: failure.code, step: step) }
    }

    /// The text SQLCipher reads as a raw 32-byte key. A malformed value would silently become a passphrase.
    static func rawKey(_ hex: String) throws -> String {
        guard hex.count == 64, hex.allSatisfy({ "0123456789abcdef".contains($0) }) else {
            throw Failure(code: SQLITE_MISUSE, step: "key format")
        }
        return "x'\(hex)'"
    }

    private func createSchema() throws {
        var sql = """
            CREATE TABLE IF NOT EXISTS main.terms (name TEXT PRIMARY KEY, query TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS main.counter (one INTEGER PRIMARY KEY CHECK (one = 1), last INTEGER NOT NULL);
            """
        for schema in ["main", "s"] { sql += Self.tables(in: schema) }
        sql += """
            CREATE TEMP VIEW IF NOT EXISTS all_nodes AS SELECT * FROM main.nodes UNION ALL SELECT * FROM s.nodes;
            CREATE TEMP VIEW IF NOT EXISTS all_edges AS SELECT * FROM main.edges UNION ALL SELECT * FROM s.edges;
            CREATE TEMP VIEW IF NOT EXISTS all_events AS SELECT * FROM main.events UNION ALL SELECT * FROM s.events;
            CREATE TEMP VIEW IF NOT EXISTS all_threads AS SELECT * FROM main.threads UNION ALL SELECT * FROM s.threads;
            """
        let rc = sqlite3_exec(handle, sql, nil, nil, nil)
        guard rc == SQLITE_OK else { throw Failure(code: rc, step: "schema") }
    }

    /// The tables of 5.12 (terms only in main), `threads` (05-map.md 5.8.1, D3: no text index, so never searched), and
    /// the two text indexes of one file. The plain indexes (R49) serve
    /// the reads by link end, Project, replacement and source on every answer; "IF NOT EXISTS" adds them to a
    /// Map made before them the next time it opens, inside its encryption like every other page. A row in Recently deleted
    /// (`deleted` not empty) is kept out of its index by the triggers, so a forget and a restore update the index too.
    private static func tables(in s: String) -> String {
        """
        CREATE TABLE IF NOT EXISTS \(s).nodes (
          id INTEGER PRIMARY KEY, owner INTEGER NOT NULL DEFAULT 1, class TEXT NOT NULL, kind TEXT NOT NULL DEFAULT '',
          name TEXT NOT NULL DEFAULT '', aliases TEXT NOT NULL DEFAULT '[]', text TEXT NOT NULL DEFAULT '',
          properties TEXT NOT NULL DEFAULT '{}', origin TEXT NOT NULL, source_event INTEGER, confidence REAL NOT NULL,
          sensitive INTEGER NOT NULL DEFAULT 0, valid_from TEXT NOT NULL, valid_to TEXT, superseded_by INTEGER,
          deleted TEXT NOT NULL DEFAULT '', embedding BLOB, created TEXT NOT NULL, updated TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS \(s).edges (
          id INTEGER PRIMARY KEY, owner INTEGER NOT NULL DEFAULT 1, from_node INTEGER NOT NULL, to_node INTEGER NOT NULL,
          link TEXT NOT NULL, strength REAL, confidence REAL NOT NULL, origin TEXT NOT NULL, source_event INTEGER,
          valid_from TEXT NOT NULL, valid_to TEXT, superseded_by INTEGER, deleted TEXT NOT NULL DEFAULT '',
          created TEXT NOT NULL, updated TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS \(s).events (
          id INTEGER PRIMARY KEY, owner INTEGER NOT NULL DEFAULT 1, time TEXT NOT NULL, app TEXT NOT NULL DEFAULT '',
          kind TEXT NOT NULL, summary TEXT NOT NULL DEFAULT '', project INTEGER, mentions TEXT NOT NULL DEFAULT '[]',
          sensitive INTEGER NOT NULL DEFAULT 0, deleted TEXT NOT NULL DEFAULT '', embedding BLOB);
        CREATE TABLE IF NOT EXISTS \(s).forgets (id INTEGER PRIMARY KEY, time TEXT NOT NULL, label TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS \(s).threads (
          id INTEGER PRIMARY KEY, owner INTEGER NOT NULL DEFAULT 1, time TEXT NOT NULL, project INTEGER,
          turns TEXT NOT NULL DEFAULT '[]', sensitive INTEGER NOT NULL DEFAULT 0, deleted TEXT NOT NULL DEFAULT '');
        CREATE INDEX IF NOT EXISTS \(s).edges_from ON edges(from_node);
        CREATE INDEX IF NOT EXISTS \(s).edges_to ON edges(to_node);
        CREATE INDEX IF NOT EXISTS \(s).events_project ON events(project);
        CREATE INDEX IF NOT EXISTS \(s).nodes_superseded ON nodes(superseded_by);
        CREATE INDEX IF NOT EXISTS \(s).nodes_source ON nodes(source_event);
        CREATE VIRTUAL TABLE IF NOT EXISTS \(s).nodes_fts USING fts5(name, aliases, kind, text,
          content='nodes', content_rowid='id', tokenize='unicode61 remove_diacritics 2');
        CREATE VIRTUAL TABLE IF NOT EXISTS \(s).events_fts USING fts5(summary,
          content='events', content_rowid='id', tokenize='unicode61 remove_diacritics 2');
        INSERT INTO \(s).nodes_fts(nodes_fts, rank) VALUES ('secure-delete', 1);
        INSERT INTO \(s).events_fts(events_fts, rank) VALUES ('secure-delete', 1);
        CREATE TRIGGER IF NOT EXISTS \(s).nodes_ai AFTER INSERT ON nodes WHEN new.deleted = '' BEGIN
          INSERT INTO nodes_fts(rowid, name, aliases, kind, text) VALUES (new.id, new.name, new.aliases, new.kind, new.text);
        END;
        CREATE TRIGGER IF NOT EXISTS \(s).nodes_ad AFTER DELETE ON nodes WHEN old.deleted = '' BEGIN
          INSERT INTO nodes_fts(nodes_fts, rowid, name, aliases, kind, text)
            VALUES ('delete', old.id, old.name, old.aliases, old.kind, old.text);
        END;
        CREATE TRIGGER IF NOT EXISTS \(s).nodes_au AFTER UPDATE ON nodes BEGIN
          INSERT INTO nodes_fts(nodes_fts, rowid, name, aliases, kind, text)
            SELECT 'delete', old.id, old.name, old.aliases, old.kind, old.text WHERE old.deleted = '';
          INSERT INTO nodes_fts(rowid, name, aliases, kind, text)
            SELECT new.id, new.name, new.aliases, new.kind, new.text WHERE new.deleted = '';
        END;
        CREATE TRIGGER IF NOT EXISTS \(s).events_ai AFTER INSERT ON events WHEN new.deleted = '' BEGIN
          INSERT INTO events_fts(rowid, summary) VALUES (new.id, new.summary);
        END;
        CREATE TRIGGER IF NOT EXISTS \(s).events_ad AFTER DELETE ON events WHEN old.deleted = '' BEGIN
          INSERT INTO events_fts(events_fts, rowid, summary) VALUES ('delete', old.id, old.summary);
        END;
        CREATE TRIGGER IF NOT EXISTS \(s).events_au AFTER UPDATE ON events BEGIN
          INSERT INTO events_fts(events_fts, rowid, summary) SELECT 'delete', old.id, old.summary WHERE old.deleted = '';
          INSERT INTO events_fts(rowid, summary) SELECT new.id, new.summary WHERE new.deleted = '';
        END;
        """
    }
}

extension SQLValue {
    var intValue: Int64? { if case .int(let v) = self { return v }; return nil }
}
