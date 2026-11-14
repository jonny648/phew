import XCTest
@testable import Phew

/// P5.14: the two Map files are encrypted, each with its own key, and a real delete leaves no word behind
/// (docs/05-map.md 5.12, "Encryption: the design"). Temporary folders and made-up keys only: never the real
/// Keychain or map.sqlite.
final class MapEncryptionTests: XCTestCase {
    private let key1 = String(repeating: "3f9a", count: 16)
    private let key2 = String(repeating: "c071", count: 16)
    private let otherKey = String(repeating: "5d2e", count: 16)
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appending(path: "PhewMapTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    func testNoPlainTextInEitherFileOrJournal() async throws {
        let store = try MapStore(folder: folder, key: key1, sensitiveKey: key2)
        let person = try await store.add(MapNode(mapClass: .person, kind: "client", name: "Zorvane Plimpet", origin: .told))
        let fact = try await store.add(MapNode(mapClass: .note, kind: "identity", text: "Zorvane has Brindlecough syndrome",
                                               origin: .observed, sensitive: true))
        let found = await store.search(["Zorvane"])
        XCTAssertEqual(Set(found.map(\.id)), [person, fact], "search reads both encrypted indexes")
        let sensitiveOnly = await store.search(["brindlecough"])
        XCTAssertEqual(sensitiveOnly.map(\.id), [fact])
        await store.close()

        // Hold a change open so both rollback journals exist, holding the old pages.
        let db = try Database(folder: folder, key: key1, sensitiveKey: key2)
        try db.query("BEGIN IMMEDIATE")
        try db.query("UPDATE main.nodes SET name = 'Someone else' WHERE id = ?", [.int(person)])
        try db.query("UPDATE s.nodes SET text = 'Something else' WHERE id = ?", [.int(fact)])
        let journals = ["map.sqlite-journal", "map-sensitive.sqlite-journal"]
        for journal in journals {
            let bytes = try Data(contentsOf: folder.appending(path: journal))
            XCTAssertFalse(bytes.isEmpty, journal)
            assertAbsent(["Zorvane", "Plimpet", "Brindlecough"], in: bytes, journal)
        }
        try db.query("ROLLBACK")
        db.close()

        for file in ["map.sqlite", "map-sensitive.sqlite"] {
            let bytes = try Data(contentsOf: folder.appending(path: file))
            XCTAssertFalse(bytes.starts(with: Data("SQLite format 3".utf8)), "\(file) must not be a plain SQLite file")
            assertAbsent(["Zorvane", "Plimpet", "Brindlecough", "client", "syndrome"], in: bytes, file)
        }
        for journal in journals {
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appending(path: journal).path), "rollback journal removed")
        }
    }

    func testWrongKeyFails() async throws {
        let store = try MapStore(folder: folder, key: key1, sensitiveKey: key2)
        await store.close()
        XCTAssertThrowsError(try Database(folder: folder, key: otherKey, sensitiveKey: key2)) {
            XCTAssertEqual(($0 as? Database.Failure)?.step, "key check")
        }
        XCTAssertThrowsError(try Database(folder: folder, key: key1, sensitiveKey: otherKey))
        XCTAssertThrowsError(try Database(folder: folder, key: nil, sensitiveKey: nil), "no key opens nothing")
        XCTAssertThrowsError(try Database(folder: folder, key: "x'00'", sensitiveKey: key2)) {
            XCTAssertEqual(($0 as? Database.Failure)?.step, "key format")
        }
        XCTAssertNoThrow(try Database(folder: folder, key: key1, sensitiveKey: key2), "the right keys still open it")
    }

    func testSettingsOnTheEncryptedFiles() throws {
        let db = try Database(folder: folder, key: key1, sensitiveKey: key2)
        XCTAssertEqual(try db.scalar("PRAGMA s.secure_delete"), .int(1))
        XCTAssertEqual(try db.scalar("PRAGMA main.secure_delete"), .int(1))
        XCTAssertEqual(try db.scalar("PRAGMA s.journal_mode"), .text("delete"))
        XCTAssertEqual(try db.scalar("PRAGMA main.journal_mode"), .text("delete"))
        XCTAssertEqual(try db.scalar("PRAGMA temp_store"), .int(2))
        XCTAssertEqual(try db.scalar("SELECT sqlite_version()"), .text("3.54.1"))
    }

    func testMergedRankingPutsNameMatchesFirst() async throws {
        let store = try MapStore(folder: folder, key: key1, sensitiveKey: key2)
        let note = try await store.add(MapNode(mapClass: .note, text: "We spoke about Bramblewick and many other made-up things today",
                                               origin: .told))
        let topic = try await store.add(MapNode(mapClass: .topic, name: "Bramblewick", origin: .observed))
        let person = try await store.add(MapNode(mapClass: .person, name: "Bramblewick", origin: .told, sensitive: true))
        let found = await store.search(["bramblewick"])
        XCTAssertEqual(found.count, 3)
        XCTAssertEqual(Set(found.prefix(2).map(\.id)), [topic, person], "name matches from both files come first")
        XCTAssertEqual(found.last?.id, note)
        await store.close()
    }

    /// Secure delete on a plain file (no key), with the same settings as the Map: SQLCipher encrypts below the page
    /// layer, so a keyed file's decrypted pages hold exactly what this file holds.
    func testRealDeleteLeavesNoWordInThePlainFile() throws {
        let name = "Wobbleknapf"
        var db = try Database(folder: folder, key: nil, sensitiveKey: nil)
        for file in ["main", "s"] {
            for n in 0..<20 {   // other rows, so the deleted one shares pages and index segments with them
                try db.query("""
                    INSERT INTO \(file).nodes (id, class, name, text, origin, confidence, valid_from, created, updated)
                    VALUES (?, 'Person', ?, ?, 'told', 0.9, 'now', 'now', 'now')
                    """, [.int(db.nextID()), .text("Filler \(n)"), .text("Filler sentence number \(n)")])
            }
            try db.query("""
                INSERT INTO \(file).nodes (id, class, name, text, origin, confidence, valid_from, created, updated)
                VALUES (?, 'Person', ?, ?, 'told', 0.9, 'now', 'now', 'now')
                """, [.int(db.nextID()), .text(name), .text("\(name) lives near the canal")])
            try db.query("INSERT INTO \(file).events (id, time, kind, summary) VALUES (?, 'now', 'ask', ?)",
                         [.int(db.nextID()), .text("Asked about \(name)")])
        }
        db.close()
        let plain = try Data(contentsOf: folder.appending(path: "map.sqlite"))
        XCTAssertTrue(plain.starts(with: Data("SQLite format 3".utf8)), "this test file must be plain")
        XCTAssertNotNil(plain.range(of: Data(name.utf8)), "the word is there before the delete")

        db = try Database(folder: folder, key: nil, sensitiveKey: nil)
        for file in ["main", "s"] {
            try db.query("DELETE FROM \(file).nodes WHERE name = ?", [.text(name)])
            try db.query("DELETE FROM \(file).events WHERE summary LIKE ?", [.text("%\(name)%")])
        }
        let gone = try db.scalar("SELECT count(*) FROM all_nodes WHERE name = ?", [.text(name)])
        XCTAssertEqual(gone, .int(0))
        db.close()

        for file in ["map.sqlite", "map-sensitive.sqlite", "map.sqlite-journal", "map-sensitive.sqlite-journal"] {
            guard let bytes = try? Data(contentsOf: folder.appending(path: file)) else { continue }
            assertAbsent([name, "canal"], in: bytes, file)
        }
    }

    private func assertAbsent(_ words: [String], in bytes: Data, _ file: String, line: UInt = #line) {
        for word in words {
            for form in [word, word.lowercased()] {
                XCTAssertNil(bytes.range(of: Data(form.utf8)), "\(form) found in \(file)", line: line)
            }
        }
    }
}
