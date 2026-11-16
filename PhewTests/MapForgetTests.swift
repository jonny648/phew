import XCTest
@testable import Phew

/// P5.8: origin and date on facts, told beats observed beats imported, corrections kept as history, forget,
/// Recently deleted, restore and the real delete (docs/05-map.md 5.5, 5.12). Made-up data, Maps in memory or in a
/// temporary folder.
final class MapForgetTests: XCTestCase {
    private let now = Made.now
    private func days(_ n: Double) -> Date { now.addingTimeInterval(n * 86_400) }

    // MARK: - Origin, priority, corrections

    func testAToldFactKeepsItsOriginAndDate() async throws {
        let store = try MapStore()
        let (out, _) = try await Made.learn(store, Made.reply(
            notes: [Made.note("I prefer short answers", about: ["me"], kind: "preference", origin: "told", date: "2026-11-09")],
            summary: "Told a preference.", card: "Stored: you prefer short answers."),
            question: "Remember that since Monday I prefer short answers", route: .remember)
        XCTAssertEqual(out.card, "Stored: you prefer short answers.")
        let nodes = await store.visibleNodes()
        let note = try XCTUnwrap(nodes.first { $0.mapClass == .note })
        XCTAssertEqual(note.origin, .told)
        XCTAssertEqual(note.confidence, 0.9)
        XCTAssertEqual(note.validFrom, "2026-11-09", "true from the date the user's words gave")
        XCTAssertEqual(note.sourceEvent, out.event)
        let told = try await store.event(XCTUnwrap(out.event))
        XCTAssertEqual(told?.kind, .tell)
        let profile = await store.profile(now: now)
        XCTAssertTrue(profile.contains("\"I prefer short answers\" (Note, preference). Told on 14 Nov. True from 9 Nov."), profile)

        let (nothing, _) = try await Made.learn(store, Made.reply(), question: "Remember this", route: .remember)
        XCTAssertEqual(nothing.card, "Nothing was stored.")
        XCTAssertNil(nothing.event)
    }

    func testACorrectionEndsTheOldFactAndKeepsItAsHistory() async throws {
        let store = try MapStore()
        let first = try await Made.learn(store, Made.reply(
            things: [Made.thing("t1", "Task", "Poster brief", due: "2026-11-20", origin: "told")]),
            question: "Remember the poster brief is due on the 20th", route: .remember, now: days(-2)).0
        let task = try XCTUnwrap(first.stored.first)
        let (fix, _) = try await Made.learn(store, Made.reply(
            things: [Made.thing("t1", "Task", "Poster brief", due: "2026-11-22", status: "replaces", origin: "told")]),
            question: "No, the poster brief is due on the 22nd", route: .remember)
        XCTAssertEqual(fix.replaced, [task])
        let read = try await store.node(task)
        let living = try XCTUnwrap(read)
        XCTAssertEqual(MapStore.values(living.properties)["due"] as? String, "2026-11-22")
        XCTAssertEqual(living.id, task, "a thing keeps one row and one id")
        let history = await store.history(task)
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(MapStore.values(history[0].properties)["due"] as? String, "2026-11-20")
        XCTAssertEqual(history[0].validTo, MapStore.iso(now), "its end date")
        XCTAssertEqual(history[0].supersededBy, task, "the fact that replaced it")
        let event = try await store.event(XCTUnwrap(fix.event))
        XCTAssertEqual(event?.kind, .correction)
        let past = await store.searchMap(MapSearchArguments(query: "poster", past: true), now: now)
        XCTAssertTrue(past.contains("Due 20 Nov") && past.contains("Old version, true until 14 Nov") && past.contains("Due 22 Nov"), past)
        let current = await store.searchMap(MapSearchArguments(query: "poster"), now: now)
        XCTAssertFalse(current.contains("Due 20 Nov"), "only current facts unless the past is asked for")

        // A Note: the old row ends, the new one replaces it, the old Note's links end with it.
        let roomQuestion = "Remember the review of the poster brief is in room B12"
        let taskNumber = try await XCTUnwrapAsync(await Made.fact(store, task, question: roomQuestion, route: .remember))
        let room = try await Made.learn(store, Made.reply(notes: [Made.note("The review is in room B12", about: [taskNumber], origin: "told")]),
                                        question: roomQuestion, route: .remember).0
        let old = try XCTUnwrap(room.stored.first)
        let number = try await XCTUnwrapAsync(await Made.fact(store, old, question: "review room", route: .remember))
        let (moved, _) = try await Made.learn(store, Made.reply(
            notes: [Made.note("The review is in room B14", status: "replaces", fact: number, origin: "told")]),
            question: "No, the review room is B14", route: .remember)
        let new = try XCTUnwrap(moved.stored.first)
        XCTAssertEqual(moved.replaced, [old])
        let ended = await store.history(new)
        XCTAssertEqual(ended.map(\.id), [old])
        XCTAssertEqual(ended.first?.supersededBy, new)
        XCTAssertNotNil(ended.first?.validTo)
        let edges = await store.visibleEdges(currentOnly: false)
        XCTAssertTrue(edges.filter { $0.from == old }.allSatisfy { $0.validTo != nil }, "the old Note's links end with it")
        XCTAssertTrue(edges.contains { $0.from == new && $0.to == task && $0.validTo == nil }, "the new Note is about what the old one was about")
    }

    /// R26: a doubt written in the same reply that first marks its thing sensitive goes to the sensitive file too.
    func testADoubtAboutAThingJustMarkedSensitiveIsSensitive() async throws {
        let store = try MapStore()
        _ = try await Made.learn(store, Made.reply(things: [Made.thing("t1", "Task", "Pay the made-up invoice", due: "2026-11-20", origin: "told")]),
                                 question: "Remember to pay the invoice by the 20th", route: .remember)
        let (seen, _) = try await Made.learn(store, Made.reply(
            things: [Made.thing("t1", "Task", "Pay the made-up invoice", due: "2026-11-25", origin: "observed", sensitive: true)]))
        let doubtID = try XCTUnwrap(seen.unconfirmed.first)
        let files = try await store.fileCounts("nodes", doubtID)
        XCTAssertEqual(files.main, 0, "the doubt names the thing: never in the normal file")
        XCTAssertEqual(files.sensitive, 1)
    }

    func testAWeakerSourceNeverReplacesAStrongerOne() async throws {
        let store = try MapStore()
        let task = try await Made.learn(store, Made.reply(things: [Made.thing("t1", "Task", "Poster brief", due: "2026-11-20", origin: "told")]),
                                        question: "Remember the poster brief is due on the 20th", route: .remember).0.stored[0]
        // Seen while answering: another date, and done. Nobody stated "done", so that one is filled.
        let (seen, _) = try await Made.learn(store, Made.reply(
            things: [Made.thing("t1", "Task", "Poster brief", due: "2026-11-25", done: "yes", status: "replaces", origin: "observed")]))
        let read = try await store.node(task)
        let living = try XCTUnwrap(read)
        let values = MapStore.values(living.properties)
        XCTAssertEqual(values["due"] as? String, "2026-11-20", "told beats observed")
        XCTAssertEqual(values["done"] as? Bool, true, "a value nobody stated can be filled by any source")
        XCTAssertEqual(living.origin, .told)
        let doubtID = try XCTUnwrap(seen.unconfirmed.first)
        let doubtRead = try await store.node(doubtID)
        let doubt = try XCTUnwrap(doubtRead)
        XCTAssertEqual(doubt.kind, "unconfirmed")
        XCTAssertEqual(doubt.origin, .observed)
        XCTAssertEqual(doubt.confidence, 0.6)
        XCTAssertTrue(doubt.text.contains("2026-11-25"), doubt.text)
        let about = await store.visibleEdges().filter { $0.from == doubtID }.map(\.to)
        XCTAssertEqual(about, [task], "kept beside it, about the same thing")
        let history = await store.history(task)
        XCTAssertTrue(history.isEmpty, "nothing was replaced")

        // Notes: an observed one never replaces a told one; observed by observed, the newer wins.
        let told = try await Made.learn(store, Made.reply(notes: [Made.note("Answer in Italian", about: ["me"], kind: "preference", origin: "told")]),
                                        question: "Remember: answer in Italian", route: .remember).0.stored[0]
        let number = try await XCTUnwrapAsync(await Made.fact(store, told, question: "answer italian"))
        let (weaker, _) = try await Made.learn(store, Made.reply(
            notes: [Made.note("Answer in English", kind: "preference", status: "replaces", fact: number)]), question: "answer italian")
        let toldNow = try await store.node(told)
        XCTAssertNil(toldNow?.validTo, "the told Note stays current")
        XCTAssertEqual(weaker.replaced, [])
        let english = try await store.node(XCTUnwrap(weaker.unconfirmed.first))
        XCTAssertEqual(english?.kind, "unconfirmed")

        let observed = try await Made.learn(store, Made.reply(notes: [Made.note("The printer is on floor 2", about: ["t1"])])).0.stored[0]
        let printer = try await XCTUnwrapAsync(await Made.fact(store, observed, question: "printer floor"))
        let (newer, _) = try await Made.learn(store, Made.reply(
            notes: [Made.note("The printer is on floor 3", status: "replaces", fact: printer)]), question: "printer floor")
        XCTAssertEqual(newer.replaced, [observed], "equal origins: the newer one replaces the older one")
    }

    // MARK: - Forget and restore

    /// Zeppelina with a past version, a link to Acme, a Note about her with its past version, and past questions:
    /// one about her only, one about her and Acme, one about Acme only, one that is the source of another fact.
    private func zeppelinaMap(_ store: MapStore) async throws -> (person: Int64, note: Int64, oldNote: Int64, acme: Int64,
                                                                   events: (only: Int64, both: Int64, acmeOnly: Int64, source: Int64)) {
        let acme = try await store.add(MapNode(mapClass: .organization, name: "Acme Biscotti", origin: .told))
        let person = try await store.add(MapNode(mapClass: .person, kind: "client", name: "Zeppelina Quorn", origin: .told))
        try await store.add(MapNode(mapClass: .person, name: "Zeppelina Q.", origin: .observed, validTo: MapStore.iso(days(-3)), supersededBy: person))
        try await store.add(MapEdge(from: person, to: acme, link: .partOf, origin: .told))
        let note = try await store.add(MapNode(mapClass: .note, text: "Zeppelina prefers calls in the morning", origin: .told))
        let oldNote = try await store.add(MapNode(mapClass: .note, text: "Zeppelina prefers calls after lunch", origin: .told,
                                                  validTo: MapStore.iso(days(-1)), supersededBy: note))
        try await store.add(MapEdge(from: note, to: person, link: .about, origin: .told))
        let only = try await store.add(MapEvent(time: MapStore.iso(days(-2)), app: "Mail", kind: .ask, summary: "Asked who Zeppelina is", mentions: [person]))
        let both = try await store.add(MapEvent(time: MapStore.iso(days(-2)), app: "Mail", kind: .ask, summary: "Asked about Zeppelina at Acme",
                                                mentions: [person, acme]))
        let acmeOnly = try await store.add(MapEvent(time: MapStore.iso(days(-2)), app: "Mail", kind: .ask, summary: "Asked about the Acme invoice",
                                                    mentions: [acme]))
        let source = try await store.add(MapEvent(time: MapStore.iso(days(-2)), app: "Mail", kind: .ask, summary: "Zeppelina sent the brief",
                                                  mentions: [person]))
        try await store.add(MapNode(mapClass: .note, text: "Acme pays in 30 days", origin: .observed, sourceEvent: source))
        return (person, note, oldNote, acme, (only, both, acmeOnly, source))
    }

    private func indexed(_ store: MapStore, _ word: String) async throws -> Int64 {
        var total: Int64 = 0
        for file in ["main", "s"] {
            total += try await store.count("SELECT count(*) FROM \(file).nodes_fts WHERE nodes_fts MATCH ?", [.text(word)])
            total += try await store.count("SELECT count(*) FROM \(file).events_fts WHERE events_fts MATCH ?", [.text(word)])
        }
        return total
    }

    func testForgetHidesEverythingAndRestoreBringsItAllBack() async throws {
        let store = try MapStore()
        let z = try await zeppelinaMap(store)
        let indexedBefore = try await indexed(store, "zeppelina")
        XCTAssertEqual(indexedBefore, 7, "2 versions of her, 2 Notes, 3 past questions")
        let all = await store.visibleNodes()
        let me = try XCTUnwrap(all.first { $0.mapClass == .me })
        let refused = try await store.forget([me.id], now: now)
        XCTAssertNil(refused, "Me is never forgotten")

        let forgot = try await store.forget([z.person], now: now)
        let forgotten = try XCTUnwrap(forgot)
        XCTAssertEqual(forgotten.label, "Forgot Zeppelina Quorn: 1 person, 1 note, 2 links, 3 past questions. In Recently deleted for 30 days.")
        // Hidden from every read.
        let person = try await store.node(z.person)
        let note = try await store.node(z.note)
        XCTAssertNil(person)
        XCTAssertNil(note)
        let history = await store.history(z.person)
        XCTAssertTrue(history.isEmpty)
        let found = await store.search(["Zeppelina"], past: true)
        XCTAssertTrue(found.isEmpty)
        let foundEvents = await store.searchEvents(["Zeppelina"])
        XCTAssertTrue(foundEvents.isEmpty)
        let tool = await store.searchMap(MapSearchArguments(query: "Zeppelina", past: true), now: now)
        XCTAssertEqual(tool, "")
        let historyTool = await store.searchMap(MapSearchArguments(mapClass: "History"), now: now)
        XCTAssertFalse(historyTool.contains("Zeppelina"), historyTool)
        XCTAssertTrue(historyTool.contains("Acme invoice"), "a past question about something else stays")
        let recall = await store.recall(question: "Who is Zeppelina at Acme?", appName: "Mail", windowTitle: "Acme Biscotti", documentPath: nil, now: now)
        XCTAssertFalse(recall.contains("Zeppelina"), recall)
        XCTAssertTrue(recall.contains("Acme Biscotti"), "things only linked to her stay")
        let acmeLine = await store.searchMap(MapSearchArguments(query: "Acme Biscotti"), now: now)
        XCTAssertFalse(acmeLine.contains("Zeppelina"), "without the link: \(acmeLine)")
        let edges = await store.visibleEdges(currentOnly: false)
        XCTAssertFalse(edges.contains { [z.person, z.note].contains($0.from) || [z.person, z.note].contains($0.to) })
        let indexedDuring = try await indexed(store, "zeppelina")
        XCTAssertEqual(indexedDuring, 0, "out of both text indexes")
        let recent = await store.recentlyDeleted(now: days(10))
        XCTAssertEqual(recent.map(\.label), [forgotten.label])
        XCTAssertEqual(recent.first?.daysLeft, 20)

        let restored = try await store.restore(forgotten.id)
        XCTAssertTrue(restored)
        let back = try await store.node(z.person)
        XCTAssertEqual(back?.name, "Zeppelina Quorn")
        let backHistory = await store.history(z.person)
        XCTAssertEqual(backHistory.count, 1)
        let backNoteHistory = await store.history(z.note)
        XCTAssertEqual(backNoteHistory.map(\.id), [z.oldNote])
        let indexedAfter = try await indexed(store, "zeppelina")
        XCTAssertEqual(indexedAfter, indexedBefore, "back in both indexes")
        let foundAgain = await store.searchMap(MapSearchArguments(query: "Zeppelina"), now: now)
        XCTAssertTrue(foundAgain.contains("Zeppelina Quorn (Person, client)") && foundAgain.contains("Part of Acme Biscotti"), foundAgain)
        let empty = await store.recentlyDeleted(now: now)
        XCTAssertTrue(empty.isEmpty)
    }

    func testRestoreRemovesOnlyItsOwnForget() async throws {
        let store = try MapStore()
        let a = try await store.add(MapNode(mapClass: .person, name: "Ottilie Brack", origin: .told))
        let b = try await store.add(MapNode(mapClass: .person, name: "Fenwick Sallow", origin: .told))
        let note = try await store.add(MapNode(mapClass: .note, text: "Ottilie and Fenwick share an office", origin: .told))
        try await store.add(MapEdge(from: note, to: a, link: .about, origin: .told))
        try await store.add(MapEdge(from: note, to: b, link: .about, origin: .told))
        let forgotA = try await store.forget([a], now: now)
        let forgotB = try await store.forget([b], now: now)
        let first = try XCTUnwrap(forgotA), second = try XCTUnwrap(forgotB)
        try await store.restore(first.id)
        let ottilie = try await store.node(a)
        var shared = try await store.node(note)
        XCTAssertNotNil(ottilie)
        XCTAssertNil(shared, "still hidden by the other forget")
        try await store.restore(second.id)
        shared = try await store.node(note)
        XCTAssertNotNil(shared)
    }

    func testForgetOnTheRememberRouteOnlyAndAQuestionBackForgetsNothing() async throws {
        let store = try MapStore()
        let person = try await store.add(MapNode(mapClass: .person, name: "Zeppelina Quorn", origin: .told))
        let number = try await XCTUnwrapAsync(await Made.fact(store, person, question: "forget Zeppelina", route: .remember))

        let (explained, _) = try await Made.learn(store, Made.reply(summary: "Made-up.", forget: [number]), question: "forget Zeppelina")
        XCTAssertNil(explained.forgot, "a forget is read only on the remember route")
        let (unsure, _) = try await Made.learn(store, Made.reply(forget: [], askBack: "Do you mean Zeppelina Quorn or her company?"),
                                               question: "forget her", route: .remember)
        XCTAssertEqual(unsure.askBack, "Do you mean Zeppelina Quorn or her company?")
        var still = try await store.node(person)
        XCTAssertNotNil(still, "he never guesses")

        let eventsBefore = await store.visibleEvents().count
        let (gone, _) = try await Made.learn(store, Made.reply(forget: [number]), question: "forget Zeppelina", route: .remember)
        XCTAssertEqual(gone.card, gone.forgot?.label)
        XCTAssertTrue(gone.card.hasPrefix("Forgot Zeppelina Quorn: 1 person"), gone.card)
        still = try await store.node(person)
        XCTAssertNil(still)
        let eventsAfter = await store.visibleEvents().count
        XCTAssertEqual(eventsAfter, eventsBefore, "no trace of the request: no past question written")
        XCTAssertNil(gone.event)
    }

    // MARK: - The real delete

    func testTheRealDeleteKeepsWhatOthersNeed() async throws {
        let store = try MapStore()
        let z = try await zeppelinaMap(store)
        let nodes = await store.visibleNodes()
        let other = try XCTUnwrap(nodes.first { $0.text == "Acme pays in 30 days" })
        let forgot = try await store.forget([z.person], now: now)
        let forgotten = try XCTUnwrap(forgot)
        let deleted = try await store.deleteNow(forgotten.id)
        XCTAssertTrue(deleted)

        for id in [z.person, z.note, z.oldNote] {
            let rows = try await store.count("SELECT count(*) FROM all_nodes WHERE id = ?", [.int(id)])
            XCTAssertEqual(rows, 0, "wiped, not hidden")
        }
        let versions = try await store.count("SELECT count(*) FROM all_nodes WHERE name LIKE 'Zeppelina%' OR text LIKE '%Zeppelina%'")
        XCTAssertEqual(versions, 0)
        let only = try await store.count("SELECT count(*) FROM all_events WHERE id = ?", [.int(z.events.only)])
        XCTAssertEqual(only, 0, "a past question about her only, needed by nothing, is deleted")
        let both = try await store.event(z.events.both)
        XCTAssertEqual(both?.summary, "", "it loses its summary")
        XCTAssertEqual(both?.mentions, [z.acme], "and the mention, keeping what else it mentions")
        let source = try await store.event(z.events.source)
        XCTAssertEqual(source?.summary, "")
        XCTAssertEqual(source?.mentions, [])
        let kept = try await store.node(other.id)
        XCTAssertEqual(kept?.sourceEvent, z.events.source, "other facts keep their source")
        let acme = try await store.node(z.acme)
        XCTAssertNotNil(acme, "a thing only linked to her stays")
        let acmeOnly = try await store.event(z.events.acmeOnly)
        XCTAssertEqual(acmeOnly?.summary, "Asked about the Acme invoice")

        // No id points at a wiped row any more.
        let wiped = MapStore.json([z.person, z.note, z.oldNote])
        let dangling = try await store.count("""
            SELECT (SELECT count(*) FROM all_nodes WHERE superseded_by IN (SELECT value FROM json_each(?1)))
                 + (SELECT count(*) FROM all_edges WHERE from_node IN (SELECT value FROM json_each(?1)) OR to_node IN (SELECT value FROM json_each(?1)))
                 + (SELECT count(*) FROM all_events WHERE project IN (SELECT value FROM json_each(?1))
                      OR EXISTS (SELECT 1 FROM json_each(mentions) m WHERE m.value IN (SELECT value FROM json_each(?1))))
                 + (SELECT count(*) FROM all_nodes WHERE deleted != '') + (SELECT count(*) FROM all_edges WHERE deleted != '')
                 + (SELECT count(*) FROM all_events WHERE deleted != '')
                 + (SELECT count(*) FROM main.forgets) + (SELECT count(*) FROM s.forgets)
            """, [.text(wiped)])
        XCTAssertEqual(dangling, 0)
        let recall = await store.recall(question: "Acme", appName: "Mail", windowTitle: "", documentPath: nil, now: now)
        XCTAssertFalse(recall.contains("Zeppelina"))
        let again = try await store.deleteNow(forgotten.id)
        XCTAssertFalse(again)
    }

    func testPurgeWipesOnlyAfterThirtyDays() async throws {
        let store = try MapStore()
        let person = try await store.add(MapNode(mapClass: .person, name: "Quillon Marsh", origin: .told))
        let forgot = try await store.forget([person], now: now)
        let forgotten = try XCTUnwrap(forgot)
        var wiped = try await store.purge(now: days(29.9))
        XCTAssertEqual(wiped, 0)
        let list = await store.recentlyDeleted(now: days(29.9))
        XCTAssertEqual(list.map(\.id), [forgotten.id])
        XCTAssertEqual(list.first?.daysLeft, 1)
        try await store.restore(forgotten.id)   // still restorable on day 29
        let back = try await store.node(person)
        XCTAssertNotNil(back)

        let forgotAgain = try await store.forget([person], now: now)
        let again = try XCTUnwrap(forgotAgain)
        wiped = try await store.purge(now: days(31))
        XCTAssertEqual(wiped, 1)
        let rows = try await store.count("SELECT count(*) FROM all_nodes WHERE id = ?", [.int(person)])
        XCTAssertEqual(rows, 0)
        let gone = await store.recentlyDeleted(now: days(31))
        XCTAssertTrue(gone.isEmpty)
        let restored = try await store.restore(again.id)
        XCTAssertFalse(restored, "nothing left to restore")
    }

    func testAForgetOfASensitiveThingKeepsItsLineInTheSensitiveFile() async throws {
        let store = try MapStore()
        let fact = try await store.add(MapNode(mapClass: .note, text: "Brindlecough diagnosis in March", origin: .told, sensitive: true))
        let forgot = try await store.forget([fact], now: now)
        let forgotten = try XCTUnwrap(forgot)
        let inMain = try await store.count("SELECT count(*) FROM main.forgets")
        let inSensitive = try await store.count("SELECT count(*) FROM s.forgets WHERE id = ?", [.int(forgotten.id)])
        XCTAssertEqual(inMain, 0, "the line names a sensitive fact")
        XCTAssertEqual(inSensitive, 1)
        XCTAssertTrue(forgotten.label.hasPrefix("Forgot \"Brindlecough diagnosis in March\": 1 note."), forgotten.label)
    }

    /// The real delete on plain files in a temporary folder (no key, so the pages can be read): the made-up name is
    /// in neither file nor any journal afterwards, read as raw bytes (5.12).
    func testTheRealDeleteLeavesTheNameInNoFileOrJournal() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "PhewForgetTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let name = "Wobblequist"
        var store = try MapStore(database: Database(folder: folder, key: nil, sensitiveKey: nil))
        for n in 0..<20 {   // other rows, so the forgotten ones share pages and index segments with them
            try await store.add(MapNode(mapClass: .person, name: "Filler \(n)", text: "Filler sentence \(n)", origin: .told, sensitive: n % 2 == 0))
            try await store.add(MapEvent(app: "Mail", kind: .ask, summary: "Filler question \(n)"))
        }
        let (out, _) = try await Made.learn(store, Made.reply(
            things: [Made.thing("t1", "Person", name, kind: "client", other: ["\(name) Jr"])],
            notes: [Made.note("\(name) lives near the canal boats", about: ["t1"]),
                    Made.note("\(name) owes the bank 200 euros", about: ["t1"], sensitive: true)],
            summary: "Asked who \(name) is."), question: "Who is \(name)?")
        let person = try XCTUnwrap(out.stored.first)
        let number = try await XCTUnwrapAsync(await Made.fact(store, person, question: "Who is \(name)?"))
        let (renamed, _) = try await Made.learn(store, Made.reply(things: [Made.thing("t1", "Person", "\(name) Senior", status: "replaces",
                                                                                     fact: number, origin: "told")]), question: "Who is \(name)?")
        XCTAssertEqual(renamed.replaced, [person], "a history row with the old name")
        let forgot = try await store.forget([person], now: now)
        let forgotten = try XCTUnwrap(forgot)
        XCTAssertTrue(forgotten.label.contains(name))
        await store.close()
        let hidden = try Data(contentsOf: folder.appending(path: "map.sqlite"))
        XCTAssertTrue(hidden.starts(with: Data("SQLite format 3".utf8)), "this test file must be plain")
        XCTAssertNotNil(hidden.range(of: Data(name.utf8)), "a forget only hides: the name is still in the file")

        store = try MapStore(database: Database(folder: folder, key: nil, sensitiveKey: nil))
        let deleted = try await store.deleteNow(forgotten.id)
        XCTAssertTrue(deleted)
        let fillers = await store.visibleNodes().filter { $0.name.hasPrefix("Filler") }.count
        XCTAssertEqual(fillers, 20)
        await store.close()

        for file in ["map.sqlite", "map-sensitive.sqlite", "map.sqlite-journal", "map-sensitive.sqlite-journal"] {
            guard let bytes = try? Data(contentsOf: folder.appending(path: file)) else { continue }
            for word in [name, name.lowercased(), "canal boats", "owes the bank"] {
                XCTAssertNil(bytes.range(of: Data(word.utf8)), "\(word) found in \(file)")
            }
        }
    }
}

/// `XCTUnwrap` for a value an `await` gave.
func XCTUnwrapAsync<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) async throws -> T {
    try XCTUnwrap(value, file: file, line: line)
}
