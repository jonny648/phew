import Foundation
import Security

/// The eleven classes of docs/05-map.md 5.3. Nothing else can be written.
enum MapClass: String, CaseIterable, Sendable {
    case me = "Me", project = "Project", task = "Task", topic = "Topic", document = "Document", person = "Person"
    case organization = "Organization", tool = "Tool", event = "Event", place = "Place", note = "Note"
}

/// The seven links of 5.4, with the ends each one allows.
enum MapLink: String, CaseIterable, Sendable {
    case partOf = "part_of", about, requires, involves, uses, at, understands

    func allows(_ from: MapClass, _ to: MapClass) -> Bool {
        switch self {
        case .partOf:
            return ([.task, .document, .event, .project].contains(from) && to == .project)
                || (from == .document && to == .event) || (from == .person && to == .organization)
        case .about: return from == .note || ([.document, .event].contains(from) && to == .topic)
        case .requires: return (from == .task && [.topic, .document].contains(to)) || (from == .topic && to == .topic)
        case .involves: return [.project, .task, .event].contains(from) && [.person, .organization].contains(to)
        case .uses: return from == .project && to == .tool
        case .at: return [.event, .organization].contains(from) && to == .place
        case .understands: return from == .me && to == .topic
        }
    }
}

/// Where a fact came from (5.5). Its starting confidence is set here, by code, never by a model.
enum Origin: String, Sendable {
    case told, observed, imported
    var startingConfidence: Double {
        switch self {
        case .told: return 0.9
        case .observed: return 0.6
        case .imported: return 0.5
        }
    }
}

enum EventKind: String, Sendable { case ask, guide, tell, correction, task, `import` }

/// A thing or a Note (a row of `nodes`). `confidence`, `created` and `updated` are set by the store.
struct MapNode: Equatable, Sendable {
    var id: Int64 = 0
    var mapClass: MapClass
    var kind = ""
    var name = ""
    var aliases: [String] = []
    var text = ""
    var properties = "{}"
    var origin: Origin
    var sourceEvent: Int64?
    var confidence = 0.0
    var sensitive = false
    var validFrom = ""
    var validTo: String?
    var supersededBy: Int64?
    var created = ""
    var updated = ""
}

/// A link (a row of `edges`). `strength` is kept only for "understands".
struct MapEdge: Equatable, Sendable {
    var id: Int64 = 0
    var from: Int64
    var to: Int64
    var link: MapLink
    var strength: Double?
    var confidence = 0.0
    var origin: Origin
    var sourceEvent: Int64?
    var validFrom = ""
    var validTo: String?
    var supersededBy: Int64?
    var created = ""
    var updated = ""
}

/// A past question (a row of `events`). It is sensitive when marked so or when it mentions a sensitive thing.
struct MapEvent: Equatable, Sendable {
    var id: Int64 = 0
    var time = ""
    var app = ""
    var kind: EventKind
    var summary = ""
    var project: Int64?
    var mentions: [Int64] = []
    var sensitive = false
}

enum MapError: Error, Equatable {
    case underTests, keyMissingForExistingFile, randomFailed, keyNotStored
}

/// The Map: two encrypted SQLite files, one connection (docs/05-map-storage.md 5.12). Writes name their file (`main` or `s`);
/// reads go through the `all_*` views. Nothing opens it at launch: `openOnMac()` is called when it is first needed.
actor MapStore {
    let db: Database

    /// The real Map, in ~/Library/Application Support/Phew/, with its keys from the login Keychain. Refused under tests,
    /// so a test never reads `map-key` or creates a real file or Keychain item.
    static func openOnMac() throws -> MapStore {
        guard NSClassFromString("XCTestCase") == nil else { throw MapError.underTests }
        let folder = URL.applicationSupportDirectory.appending(path: "Phew")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        func key(_ account: String, _ file: String) throws -> String {
            var store = KeyStore()
            store.account = account
            return try provisionKey(fileExists: FileManager.default.fileExists(atPath: folder.appending(path: file).path),
                                    read: store.read, save: store.save)
        }
        let key1 = try key("map-key", "map.sqlite")
        let key2 = try key("map-sensitive-key", "map-sensitive.sqlite")
        return try MapStore(folder: folder, key: key1, sensitiveKey: key2)
    }

    /// The stored key, or on first run a new one: 32 random bytes as 64 hex characters, written to the Keychain and
    /// read back unchanged before any file exists. Never a new key over an existing file.
    static func provisionKey(fileExists: Bool, read: () -> String?, save: (String) throws -> Void) throws -> String {
        if let stored = read() {
            _ = try Database.rawKey(stored)
            return stored
        }
        guard !fileExists else { throw MapError.keyMissingForExistingFile }
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw MapError.randomFailed }
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        try save(hex)
        guard read() == hex else { throw MapError.keyNotStored }
        return hex
    }

    /// Encrypted files in `folder` with the two keys (64 hex characters each).
    init(folder: URL, key: String, sensitiveKey: String) throws {
        try self.init(database: Database(folder: folder, key: key, sensitiveKey: sensitiveKey))
    }

    /// A plain Map in memory, for unit tests.
    init() throws {
        try self.init(database: Database(folder: nil, key: nil, sensitiveKey: nil))
    }

    /// Also used by the real-delete test, on plain files in a temporary folder.
    init(database: Database) throws {
        db = database
        // Me: one row, made when the Map is created (5.3).
        if try db.scalar("SELECT count(*) FROM all_nodes WHERE class = 'Me'") == .int(0) {
            let now = Self.now()
            try db.query("""
                INSERT INTO main.nodes (id, class, origin, confidence, valid_from, created, updated)
                VALUES (?, 'Me', 'told', 1.0, ?, ?, ?)
                """, [.int(db.nextID()), .text(now), .text(now), .text(now)])
        }
        // The defined terms of 5.6, once. A row already there is kept, so a tuned number stays.
        for (name, query) in Self.termQueries {
            try db.query("INSERT OR IGNORE INTO main.terms (name, query) VALUES (?, ?)", [.text(name), .text(query)])
        }
        // R10: past questions written before a Project's own sensitive mark counted for them, still in the normal
        // file, go under the second lock. At every open; a second run finds nothing to move.
        let filed = "project IN (SELECT id FROM s.nodes)"
        if try db.scalar("SELECT count(*) FROM main.events WHERE \(filed)") != .int(0) {
            try database.transaction {
                try database.query("UPDATE main.events SET sensitive = 1 WHERE \(filed)")
                try database.query("INSERT INTO s.events SELECT * FROM main.events WHERE \(filed)")
                try database.query("DELETE FROM main.events WHERE \(filed)")
            }
        }
    }

    func close() { db.close() }

    /// For tests: how many rows of `table` (nodes, edges or events) with this id each file holds.
    func fileCounts(_ table: String, _ id: Int64) throws -> (main: Int64, sensitive: Int64) {
        precondition(["nodes", "edges", "events", "threads"].contains(table))
        let count = { (file: String) in try self.db.scalar("SELECT count(*) FROM \(file).\(table) WHERE id = ?", [.int(id)]).intValue ?? -1 }
        return try (count("main"), count("s"))
    }

    /// How many projects and facts the Map holds now, for Phew's knowledge of himself (PS.14): current things and
    /// Notes in both files, not Me, nothing superseded or in Recently deleted. Numbers only.
    func counts() -> (projects: Int, facts: Int) {
        let row = try? db.query("""
            SELECT coalesce(sum(class = 'Project'), 0) AS projects, count(*) AS facts FROM all_nodes
            WHERE class != 'Me' AND valid_to IS NULL AND deleted = ''
            """).first
        return (Int(row?.int("projects") ?? 0), Int(row?.int("facts") ?? 0))
    }

    // MARK: - Nodes

    /// Writes a thing or a Note to the file its sensitive mark names. Returns the new id.
    @discardableResult
    func add(_ node: MapNode) throws -> Int64 {
        let id = try db.nextID()
        let now = Self.now()
        try db.query("""
            INSERT INTO \(node.sensitive ? "s" : "main").nodes (id, class, kind, name, aliases, text, properties, origin,
              source_event, confidence, sensitive, valid_from, valid_to, superseded_by, created, updated)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, [.int(id), .text(node.mapClass.rawValue), .text(node.kind), .text(node.name), .text(Self.json(node.aliases)),
                  .text(node.text), .text(node.properties), .text(node.origin.rawValue), SQLValue(node.sourceEvent),
                  .real(node.origin.startingConfidence), .int(node.sensitive ? 1 : 0),
                  .text(node.validFrom.isEmpty ? now : node.validFrom), SQLValue(node.validTo), SQLValue(node.supersededBy),
                  .text(node.created.isEmpty ? now : node.created), .text(node.updated.isEmpty ? now : node.updated)])
        return id
    }

    func node(_ id: Int64) throws -> MapNode? {
        try db.query("SELECT * FROM all_nodes WHERE id = ? AND deleted = ''", [.int(id)]).first.flatMap(Self.node)
    }

    /// Marks a thing sensitive or not, and moves it, its history rows, its links and its past questions to the
    /// other file in one transaction. Links and past questions stay sensitive while they touch another sensitive thing.
    func setSensitive(_ id: Int64, _ sensitive: Bool) throws {
        try db.transaction { try moveSensitive(id, sensitive) }
    }

    /// The move of `setSensitive`, inside a transaction the caller holds.
    func moveSensitive(_ id: Int64, _ sensitive: Bool) throws {
        let (from, to) = sensitive ? ("main", "s") : ("s", "main")
        let flag: SQLValue = .int(sensitive ? 1 : 0)
        do {
            let rows = "id = ?1 OR superseded_by = ?1"
            try db.query("INSERT INTO \(to).nodes SELECT * FROM \(from).nodes WHERE \(rows)", [.int(id)])
            try db.query("UPDATE \(to).nodes SET sensitive = ?2 WHERE \(rows)", [.int(id), flag])
            try db.query("DELETE FROM \(from).nodes WHERE \(rows)", [.int(id)])

            // Leaving the sensitive file: only what no longer touches any sensitive thing.
            let staysSensitive = sensitive ? "0" : "EXISTS (SELECT 1 FROM s.nodes n WHERE n.id IN (e.from_node, e.to_node))"
            let edges = "(e.from_node = ?1 OR e.to_node = ?1) AND NOT \(staysSensitive)"
            try db.query("INSERT INTO \(to).edges SELECT * FROM \(from).edges e WHERE \(edges)", [.int(id)])
            try db.query("DELETE FROM \(from).edges WHERE id IN (SELECT id FROM \(to).edges) AND (from_node = ?1 OR to_node = ?1)", [.int(id)])

            // R10: a past question belongs to the thing it mentions and to the Project it was filed under.
            let mentionsOther = sensitive ? "0"
                : "(EXISTS (SELECT 1 FROM json_each(e.mentions) m JOIN s.nodes n ON n.id = m.value) OR e.project IN (SELECT id FROM s.nodes))"
            let touches = "(EXISTS (SELECT 1 FROM json_each(e.mentions) WHERE value = ?1) OR e.project = ?1)"
            let events = "\(touches) AND NOT \(mentionsOther)"
            try db.query("INSERT INTO \(to).events SELECT * FROM \(from).events e WHERE \(events)", [.int(id)])
            try db.query("UPDATE \(to).events SET sensitive = ?2 WHERE id IN (SELECT e.id FROM \(to).events e WHERE \(touches))", [.int(id), flag])
            try db.query("DELETE FROM \(from).events WHERE id IN (SELECT id FROM \(to).events)")

            // D3 (5.8.1): a saved conversation lives in its Project's file.
            try db.query("INSERT INTO \(to).threads SELECT * FROM \(from).threads WHERE project = ?1", [.int(id)])
            try db.query("UPDATE \(to).threads SET sensitive = ?2 WHERE project = ?1", [.int(id), flag])
            try db.query("DELETE FROM \(from).threads WHERE project = ?1", [.int(id)])
        }
    }

    // MARK: - Edges

    /// Writes a link between two current things. Returns nil, writing nothing, when an end is missing or the link
    /// does not allow those two classes (5.4). A link touching a sensitive thing goes to the sensitive file.
    @discardableResult
    func add(_ edge: MapEdge) throws -> Int64? {
        let ends = try db.query("SELECT id, class, sensitive FROM all_nodes WHERE id IN (?, ?) AND valid_to IS NULL AND deleted = ''",
                                [.int(edge.from), .int(edge.to)])
        func end(_ id: Int64) -> SQLRow? { ends.first { $0.int("id") == id } }
        guard let from = end(edge.from), let to = end(edge.to),
              let fromClass = from.text("class").flatMap(MapClass.init), let toClass = to.text("class").flatMap(MapClass.init),
              edge.link.allows(fromClass, toClass) else { return nil }
        let sensitive = from.int("sensitive") == 1 || to.int("sensitive") == 1
        let id = try db.nextID()
        let now = Self.now()
        try db.query("""
            INSERT INTO \(sensitive ? "s" : "main").edges (id, from_node, to_node, link, strength, confidence, origin,
              source_event, valid_from, valid_to, superseded_by, created, updated)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, [.int(id), .int(edge.from), .int(edge.to), .text(edge.link.rawValue),
                  edge.link == .understands ? edge.strength.map { .real($0) } ?? .null : .null,
                  .real(edge.origin.startingConfidence), .text(edge.origin.rawValue), SQLValue(edge.sourceEvent),
                  .text(edge.validFrom.isEmpty ? now : edge.validFrom), SQLValue(edge.validTo), SQLValue(edge.supersededBy),
                  .text(edge.created.isEmpty ? now : edge.created), .text(edge.updated.isEmpty ? now : edge.updated)])
        return id
    }

    func edge(_ id: Int64) throws -> MapEdge? {
        try db.query("SELECT * FROM all_edges WHERE id = ? AND deleted = ''", [.int(id)]).first.flatMap(Self.edge)
    }

    // MARK: - Events

    @discardableResult
    func add(_ event: MapEvent) throws -> Int64 {
        // R10: also when it is filed under a sensitive Project.
        let mentionsSensitive = try db.scalar(
            "SELECT count(*) FROM s.nodes WHERE id IN (SELECT value FROM json_each(?1)) OR id = ?2",
            [.text(Self.json(event.mentions)), SQLValue(event.project)])
        let sensitive = event.sensitive || mentionsSensitive != .int(0)
        let id = try db.nextID()
        try db.query("""
            INSERT INTO \(sensitive ? "s" : "main").events (id, time, app, kind, summary, project, mentions, sensitive)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, [.int(id), .text(event.time.isEmpty ? Self.now() : event.time), .text(event.app), .text(event.kind.rawValue),
                  .text(event.summary), SQLValue(event.project), .text(Self.json(event.mentions)), .int(sensitive ? 1 : 0)])
        return id
    }

    func event(_ id: Int64) throws -> MapEvent? {
        try db.query("SELECT * FROM all_events WHERE id = ? AND deleted = ''", [.int(id)]).first.flatMap(Self.event)
    }

    // MARK: - Search

    /// Current things and Notes matching any word of `parts` (the question, the app name, the window title), best
    /// first, from both files' indexes merged. A match in a name counts more than one in a sentence. Never throws:
    /// a failed search returns nothing and the answer goes on without it (5.12).
    /// `classes` empty means every class. `since`: only facts true from that day (an unreadable date is ignored).
    /// `past`: old versions too. `namesOnly`: match names and aliases only (project detection, 5.11).
    func search(_ parts: [String], classes: [MapClass] = [], since: String? = nil, past: Bool = false,
                namesOnly: Bool = false, limit: Int = 10) -> [MapNode] {
        guard let words = Self.matchQuery(parts) else { return [] }
        let match = namesOnly ? "{name aliases} : (\(words))" : words
        let classList = classes.isEmpty ? "" : "," + classes.map(\.rawValue).joined(separator: ",") + ","
        let rows = (try? ["main", "s"].flatMap { file in
            try db.query("""
                SELECT n.*, bm25(nodes_fts, 10.0, 5.0, 2.0, 1.0) AS score FROM \(file).nodes_fts JOIN \(file).nodes n ON n.id = nodes_fts.rowid
                WHERE nodes_fts MATCH ?1 AND n.deleted = '' AND (?2 OR n.valid_to IS NULL)
                  AND (?3 = '' OR instr(?3, ',' || n.class || ',') > 0)
                  AND (julianday(?4) IS NULL OR julianday(n.valid_from) >= julianday(?4))
                ORDER BY score LIMIT ?5
                """, [.text(match), .int(past ? 1 : 0), .text(classList), SQLValue(since), .int(Int64(limit))])
        }) ?? []
        return Self.merged(rows, limit).compactMap(Self.node)
    }

    /// Past questions whose summary matches, best first, from both files. An emptied summary is never found.
    func searchEvents(_ parts: [String], since: String? = nil, limit: Int = 10) -> [MapEvent] {
        guard let match = Self.matchQuery(parts) else { return [] }
        let rows = (try? ["main", "s"].flatMap { file in
            try db.query("""
                SELECT e.*, bm25(events_fts) AS score FROM \(file).events_fts JOIN \(file).events e ON e.id = events_fts.rowid
                WHERE events_fts MATCH ?1 AND e.deleted = '' AND e.summary != ''
                  AND (julianday(?2) IS NULL OR julianday(e.time) >= julianday(?2))
                ORDER BY score LIMIT ?3
                """, [.text(match), SQLValue(since), .int(Int64(limit))])
        }) ?? []
        return Self.merged(rows, limit).compactMap(Self.event)
    }

    /// The search words of 5.12: split at every character that is not a letter or a digit, single characters dropped,
    /// at most 30, each quoted with a star, joined with OR. Nil when no word is left.
    static func matchQuery(_ parts: [String]) -> String? {
        let words = parts.flatMap { $0.split { !$0.isLetter && !$0.isNumber } }.filter { $0.count > 1 }.prefix(30)
        return words.isEmpty ? nil : words.map { "\"\($0)\"*" }.joined(separator: " OR ")
    }

    // MARK: - Helpers (shared with MapRecall.swift)

    /// The two indexes rank with their own statistics, so the merged order is approximate (5.12). Equal scores: the
    /// more confident first.
    static func merged(_ rows: [SQLRow], _ limit: Int) -> [SQLRow] {
        Array(rows.sorted {
            let a = $0.real("score") ?? 0, b = $1.real("score") ?? 0
            return a != b ? a < b : ($0.real("confidence") ?? 0) > ($1.real("confidence") ?? 0)
        }.prefix(limit))
    }

    static func now() -> String { Date.now.formatted(.iso8601) }

    static func json<T: Encodable>(_ value: T) -> String {
        (try? String(decoding: JSONEncoder().encode(value), as: UTF8.self)) ?? "[]"
    }

    static func list<T: Decodable>(_ text: String?) -> [T] {
        (try? JSONDecoder().decode([T].self, from: Data((text ?? "[]").utf8))) ?? []
    }

    static func node(_ row: SQLRow) -> MapNode? {
        guard let id = row.int("id"), let mapClass = row.text("class").flatMap(MapClass.init),
              let origin = row.text("origin").flatMap(Origin.init) else { return nil }
        return MapNode(id: id, mapClass: mapClass, kind: row.text("kind") ?? "", name: row.text("name") ?? "",
                       aliases: list(row.text("aliases")), text: row.text("text") ?? "", properties: row.text("properties") ?? "{}",
                       origin: origin, sourceEvent: row.int("source_event"), confidence: row.real("confidence") ?? 0,
                       sensitive: row.int("sensitive") == 1, validFrom: row.text("valid_from") ?? "", validTo: row.text("valid_to"),
                       supersededBy: row.int("superseded_by"), created: row.text("created") ?? "", updated: row.text("updated") ?? "")
    }

    static func edge(_ row: SQLRow) -> MapEdge? {
        guard let id = row.int("id"), let from = row.int("from_node"), let to = row.int("to_node"),
              let link = row.text("link").flatMap(MapLink.init), let origin = row.text("origin").flatMap(Origin.init) else { return nil }
        return MapEdge(id: id, from: from, to: to, link: link, strength: row.real("strength"), confidence: row.real("confidence") ?? 0,
                       origin: origin, sourceEvent: row.int("source_event"), validFrom: row.text("valid_from") ?? "",
                       validTo: row.text("valid_to"), supersededBy: row.int("superseded_by"),
                       created: row.text("created") ?? "", updated: row.text("updated") ?? "")
    }

    static func event(_ row: SQLRow) -> MapEvent? {
        guard let id = row.int("id"), let kind = row.text("kind").flatMap(EventKind.init) else { return nil }
        return MapEvent(id: id, time: row.text("time") ?? "", app: row.text("app") ?? "", kind: kind,
                        summary: row.text("summary") ?? "", project: row.int("project"), mentions: list(row.text("mentions")),
                        sensitive: row.int("sensitive") == 1)
    }
}
