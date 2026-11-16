import XCTest
@testable import Phew

/// P5.1: the tables of docs/05-map-storage.md 5.12 and text search, on a plain Map in memory. All data is made up.
final class MapStoreTests: XCTestCase {
    func testSQLCipherIsTheSQLiteInUse() throws {
        let db = try Database(folder: nil, key: nil, sensitiveKey: nil)
        guard case .text(let version) = try db.scalar("SELECT sqlite_version()") else { return XCTFail("no version") }
        XCTAssertEqual(version, "3.54.1")
        let parts = version.split(separator: ".").compactMap { Int($0) }
        XCTAssertTrue(parts.lexicographicallyPrecedes([3, 42]) == false, "a real delete needs SQLite 3.42 or later")
        guard case .text(let cipher) = try db.scalar("PRAGMA cipher_version") else { return XCTFail("no cipher_version") }
        XCTAssertTrue(cipher.hasPrefix("4.20.0"))
    }

    func testSettingsReachBothFiles() throws {
        let db = try Database(folder: nil, key: nil, sensitiveKey: nil)
        XCTAssertEqual(try db.scalar("PRAGMA main.secure_delete"), .int(1))
        XCTAssertEqual(try db.scalar("PRAGMA s.secure_delete"), .int(1))
        XCTAssertEqual(try db.scalar("PRAGMA temp_store"), .int(2))
        XCTAssertEqual(try db.scalar("SELECT count(*) FROM main.sqlite_master WHERE name IN ('nodes','edges','events','terms','forgets')"), .int(5))
        XCTAssertEqual(try db.scalar("SELECT count(*) FROM s.sqlite_master WHERE name IN ('nodes','edges','events','forgets')"), .int(4))
        XCTAssertEqual(try db.scalar("SELECT count(*) FROM s.sqlite_master WHERE name = 'terms'"), .int(0))
    }

    func testTermsAndForgetsCreateAndRead() throws {
        let db = try Database(folder: nil, key: nil, sensitiveKey: nil)
        try db.query("INSERT INTO main.terms (name, query) VALUES ('due_soon', 'SELECT 1')")
        XCTAssertEqual(try db.scalar("SELECT query FROM main.terms WHERE name = 'due_soon'"), .text("SELECT 1"))
        for file in ["main", "s"] {
            let id = try db.nextID()
            try db.query("INSERT INTO \(file).forgets (id, time, label) VALUES (?, '2026-11-14T10:00:00Z', 'Forgot Zeppa')", [.int(id)])
            XCTAssertEqual(try db.scalar("SELECT label FROM \(file).forgets WHERE id = ?", [.int(id)]), .text("Forgot Zeppa"))
        }
    }

    func testEveryClassIsWrittenAndRead() async throws {
        let store = try MapStore()
        for mapClass in MapClass.allCases where mapClass != .me {
            let id = try await store.add(MapNode(mapClass: mapClass, kind: "made up", name: "Sample \(mapClass.rawValue)",
                                                 aliases: ["Alt \(mapClass.rawValue)"], text: mapClass == .note ? "A made-up sentence." : "",
                                                 origin: .observed))
            let read = try await store.node(id)
            XCTAssertEqual(read?.mapClass, mapClass)
            XCTAssertEqual(read?.name, "Sample \(mapClass.rawValue)")
            XCTAssertEqual(read?.aliases, ["Alt \(mapClass.rawValue)"])
            XCTAssertEqual(read?.confidence, 0.6, "confidence comes from the origin, set by code")
        }
        let me = try await meID(store)
        XCTAssertNotNil(me, "Me is made when the Map is created")
    }

    func testEverySevenLinksIsWrittenAndRead() async throws {
        let store = try MapStore()
        func add(_ c: MapClass, _ name: String) async throws -> Int64 { try await store.add(MapNode(mapClass: c, name: name, origin: .told)) }
        let project = try await add(.project, "Acme rebrand")
        let task = try await add(.task, "Poster brief")
        let topic = try await add(.topic, "Kerning")
        let person = try await add(.person, "Marta")
        let tool = try await add(.tool, "Figma")
        let event = try await add(.event, "Review with Marta")
        let place = try await add(.place, "Milan office")
        let note = try await add(.note, "")
        let me = try await meID(store)!
        let links: [(Int64, MapLink, Int64)] = [(task, .partOf, project), (note, .about, task), (task, .requires, topic),
                                                (project, .involves, person), (project, .uses, tool), (event, .at, place),
                                                (me, .understands, topic)]
        for (from, link, to) in links {
            let id = try await store.add(MapEdge(from: from, to: to, link: link, strength: 0.3, origin: .told))
            let read = try await store.edge(XCTUnwrap(id))
            XCTAssertEqual(read?.link, link)
            XCTAssertEqual(read?.from, from)
            XCTAssertEqual(read?.to, to)
            XCTAssertEqual(read?.strength, link == .understands ? 0.3 : nil, "strength only on understands")
        }
        // Ends not allowed by 5.4 are dropped.
        let bad = try await store.add(MapEdge(from: tool, to: topic, link: .understands, origin: .told))
        XCTAssertNil(bad)
        let alsoBad = try await store.add(MapEdge(from: person, to: tool, link: .uses, origin: .told))
        XCTAssertNil(alsoBad)
    }

    func testEventsAreWrittenReadAndSearched() async throws {
        let store = try MapStore()
        let id = try await store.add(MapEvent(app: "Figma", kind: .ask, summary: "Asked how to export the logo for print", mentions: [1]))
        let read = try await store.event(id)
        XCTAssertEqual(read?.summary, "Asked how to export the logo for print")
        XCTAssertEqual(read?.mentions, [1])
        let found = await store.searchEvents(["How do I export?"])
        XCTAssertEqual(found.map(\.id), [id])
    }

    func testSearchHandlesEveryKindOfQuestion() async throws {
        let store = try MapStore()
        let logo = try await store.add(MapNode(mapClass: .document, kind: "design file", name: "logo-v3.fig", origin: .observed))
        let uni = try await store.add(MapNode(mapClass: .organization, kind: "school", name: "Università di Brera", origin: .told))
        let note = try await store.add(MapNode(mapClass: .note, kind: "decision", text: "The client approved the blue logo", origin: .told))

        let sentence = await store.search(["Which file has the logo version they approved?"])
        XCTAssertTrue(sentence.map(\.id).contains(logo))
        XCTAssertTrue(sentence.map(\.id).contains(note))
        let file = await store.search(["logo-v3.fig"])
        XCTAssertEqual(file.first?.id, logo)
        let title = await store.search(["Figma: logo-v3 — Edited"])
        XCTAssertEqual(title.first?.id, logo)
        let apostrophe = await store.search(["dov'è l'università?"])
        XCTAssertEqual(apostrophe.first?.id, uni)
        let noAccent = await store.search(["universita"])
        XCTAssertEqual(noAccent.map(\.id), [uni])
        let empty = await store.search([""])
        XCTAssertTrue(empty.isEmpty)
        let punctuation = await store.search(["?! - : . a"])
        XCTAssertTrue(punctuation.isEmpty)
        let quotes = await store.search(["\"logo\" AND OR NOT *"])
        XCTAssertTrue(quotes.map(\.id).contains(logo))
    }

    func testMatchQueryShape() {
        XCTAssertEqual(MapStore.matchQuery(["logo-v3.fig"]), "\"logo\"* OR \"v3\"* OR \"fig\"*")
        XCTAssertNil(MapStore.matchQuery(["", "a b"]))
        XCTAssertEqual(MapStore.matchQuery([String(repeating: "ab ", count: 50)])?.components(separatedBy: " OR ").count, 30)
    }

    func testOnlyCurrentFactsAreFound() async throws {
        let store = try MapStore()
        let living = try await store.add(MapNode(mapClass: .task, name: "Poster brief", origin: .told))
        try await store.add(MapNode(mapClass: .task, name: "Poster brief draft", origin: .told,
                                    validTo: "2026-11-10T00:00:00Z", supersededBy: living))
        let found = await store.search(["poster"])
        XCTAssertEqual(found.map(\.id), [living])
    }

    func testSensitiveMoveLeavesTheRowInExactlyOneFile() async throws {
        let store = try MapStore()
        let person = try await store.add(MapNode(mapClass: .person, name: "Quillon", origin: .told))
        let project = try await store.add(MapNode(mapClass: .project, name: "Garden plan", origin: .told))
        let history = try await store.add(MapNode(mapClass: .person, name: "Quill", origin: .told, validTo: "2026-11-01T00:00:00Z", supersededBy: person))
        let link = try await store.add(MapEdge(from: project, to: person, link: .involves, origin: .told))
        let question = try await store.add(MapEvent(kind: .ask, summary: "Asked about Quillon", mentions: [person]))

        try await store.setSensitive(person, true)
        for id in [person, history] { try await assertIn(store, "nodes", id, sensitive: true) }
        try await assertIn(store, "edges", XCTUnwrap(link), sensitive: true)
        try await assertIn(store, "events", question, sensitive: true)
        let marked = try await store.node(person)
        XCTAssertEqual(marked?.sensitive, true)
        let found = await store.search(["Quillon"])
        XCTAssertEqual(found.first?.id, person, "still found from the sensitive index")

        try await store.setSensitive(person, false)
        for id in [person, history] { try await assertIn(store, "nodes", id, sensitive: false) }
        try await assertIn(store, "edges", XCTUnwrap(link), sensitive: false)
        try await assertIn(store, "events", question, sensitive: false)
        let back = await store.search(["Quillon"])
        XCTAssertEqual(back.map(\.id), [person], "one index entry, not two")
    }

    /// R10: a past question filed under a sensitive Project, mentioning nothing, goes under the second lock and out of
    /// an export that leaves sensitive facts out; marking the Project later moves its earlier questions too.
    func testPastQuestionsOfASensitiveProjectAreSensitive() async throws {
        let store = try MapStore()
        let loan = try await store.add(MapNode(mapClass: .project, name: "Made-up loan", origin: .told, sensitive: true))
        let asked = try await store.add(MapEvent(kind: .ask, summary: "Asked which papers the bank wants", project: loan))
        try await assertIn(store, "events", asked, sensitive: true)
        let left = await store.export(includeSensitive: false)
        XCTAssertFalse(left.contains("papers the bank wants"))
        let ticked = await store.export(includeSensitive: true)
        XCTAssertTrue(ticked.contains("papers the bank wants"))

        let garden = try await store.add(MapNode(mapClass: .project, name: "Garden plan", origin: .told))
        let earlier = try await store.add(MapEvent(kind: .ask, summary: "Asked about tulip bulbs", project: garden))
        try await assertIn(store, "events", earlier, sensitive: false)
        try await store.setSensitive(garden, true)
        try await assertIn(store, "events", earlier, sensitive: true)
        try await store.setSensitive(garden, false)
        try await assertIn(store, "events", earlier, sensitive: false)
    }

    /// R10: what is already stored moves when the Map opens, on a temporary Map; a second open moves nothing more.
    func testStoredQuestionsOfASensitiveProjectMoveWhenTheMapOpens() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "phew-r10-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let (key1, key2) = (String(repeating: "a1b2", count: 16), String(repeating: "c3d4", count: 16))
        var store = try MapStore(folder: folder, key: key1, sensitiveKey: key2)
        let loan = try await store.add(MapNode(mapClass: .project, name: "Made-up loan", origin: .told, sensitive: true))
        // As an older build wrote it: in the normal file, not marked.
        let id: Int64 = 9_000
        try await store.db.query("INSERT INTO main.events (id, time, app, kind, summary, project, mentions, sensitive) VALUES (?, '2026-11-01T10:00:00Z', 'Mail', 'ask', 'Asked which papers the bank wants', ?, '[]', 0)",
                                 [.int(id), .int(loan)])
        try await assertIn(store, "events", id, sensitive: false)
        await store.close()
        for _ in 1...2 {
            store = try MapStore(folder: folder, key: key1, sensitiveKey: key2)
            try await assertIn(store, "events", id, sensitive: true)
            let left = await store.export(includeSensitive: false)
            XCTAssertFalse(left.contains("papers the bank wants"))
            let found = await store.searchEvents(["bank papers"])
            XCTAssertEqual(found.map(\.id), [id], "one index entry, in the sensitive file")
            await store.close()
        }
    }

    func testProvisionKeyNeverReplacesAKeyForAnExistingFile() throws {
        var keychain: String?
        let key = try MapStore.provisionKey(fileExists: false, read: { keychain }, save: { keychain = $0 })
        XCTAssertEqual(key.count, 64)
        XCTAssertNoThrow(try Database.rawKey(key))
        XCTAssertEqual(try MapStore.provisionKey(fileExists: true, read: { keychain }, save: { _ in XCTFail("no new key") }), key)
        XCTAssertThrowsError(try MapStore.provisionKey(fileExists: true, read: { nil }, save: { _ in XCTFail("no new key") }))
        XCTAssertThrowsError(try MapStore.provisionKey(fileExists: false, read: { nil }, save: { _ in }), "a key that does not read back")
        XCTAssertThrowsError(try MapStore.provisionKey(fileExists: false, read: { "secret" }, save: { _ in }), "a malformed stored key")
    }

    func testTheRealMapDoesNotOpenUnderTests() {
        XCTAssertThrowsError(try MapStore.openOnMac()) { XCTAssertEqual($0 as? MapError, .underTests) }
    }

    // MARK: - Helpers

    private func meID(_ store: MapStore) async throws -> Int64? {
        for id in Int64(1)...3 { if try await store.node(id)?.mapClass == .me { return id } }
        return nil
    }

    private func assertIn(_ store: MapStore, _ table: String, _ id: Int64, sensitive: Bool, line: UInt = #line) async throws {
        let counts = try await store.fileCounts(table, id)
        XCTAssertEqual(counts.main, sensitive ? 0 : 1, "\(table) \(id) in map", line: line)
        XCTAssertEqual(counts.sensitive, sensitive ? 1 : 0, "\(table) \(id) in sensitive", line: line)
    }
}
