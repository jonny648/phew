import XCTest
@testable import Phew

/// The Map wired into the Brain (P5 stage S4): recall and profile before every answer with no model call, the Map
/// search tool, the Librarian after the answer, the remember route, forget, Recently deleted and the purge. A fake
/// provider and a Map in memory with made-up data. No network, never the real Map.
final class BrainMapTests: XCTestCase {
    typealias FakeProvider = BrainAgentsTests.FakeProvider
    typealias Reply = FakeProvider.Reply

    private let answer = Reply(pieces: [#"{"explanation":"Made-up answer.","steps":[]}"#])

    private func packet(window: String = "Orchard Bakery – home page", text: String = "SCREEN-TEXT-ONLY") -> ContextPacket {
        ContextPacket(appName: "Figma", bundleID: "com.example.made-up", windowTitle: window, visibleText: text, cursor: nil,
                      windowFrame: CGRect(x: 0, y: 0, width: 800, height: 600))
    }

    private func brain(_ provider: any ModelProvider, _ store: MapStore) -> ClaudeBrain {
        ClaudeBrain(provider: provider, map: BrainMap(open: { store }))
    }

    private func events(_ brain: ClaudeBrain, _ question: String, _ packet: ContextPacket?) async throws -> [BrainEvent] {
        var all: [BrainEvent] = []
        for try await event in brain.answer(question, packet: packet) { all.append(event) }
        _ = await brain.map.ready()  // the Librarian's run has ended
        return all
    }

    private func me(_ store: MapStore) async throws -> Int64 {
        let nodes = await store.visibleNodes()
        return try XCTUnwrap(nodes.first { $0.mapClass == .me }).id
    }

    /// A made-up Map: a told preference about Me, a Project and one past question on it.
    private func seeded() async throws -> MapStore {
        let store = try MapStore()
        let note = try await store.add(MapNode(mapClass: .note, kind: "preference", text: "Prefers short answers.", origin: .told))
        try await store.add(MapEdge(from: note, to: try await me(store), link: .about, origin: .told))
        let project = try await store.add(MapNode(mapClass: .project, kind: "client job", name: "Orchard Bakery", origin: .told))
        try await store.add(MapEvent(app: "Figma", kind: .ask, summary: "Asked how to pick the palette.", project: project))
        return store
    }

    // MARK: P5.3, P5.7: recall and profile before the answer

    func testProfileAndRecallReachTheGuideWithNoModelCall() async throws {
        let store = try await seeded()
        let fake = FakeProvider(rounds: ["conductor": [Reply(pieces: [#"{"route":"explain"}"#])], "guide": [answer]])
        _ = try await events(brain(fake, store), "What did I do here last time?", packet())

        let guide = try XCTUnwrap(fake.requests.first { $0.agent == "guide" })
        XCTAssertTrue(guide.text.hasPrefix("<map>\nAbout you:\n- \"Prefers short answers.\""))  // the profile on top
        XCTAssertTrue(guide.text.contains("Project:\n- Orchard Bakery (Project, client job)."))  // detected from the title
        XCTAssertTrue(guide.text.contains("Asked how to pick the palette."))
        XCTAssertEqual(guide.system, Guide.system)
        XCTAssertEqual(guide.tools, [.searchMap])  // the Map is open: the Guide can search it
        // No model call for the recall: the conductor, the Guide, then the Librarian after the answer. Nothing else.
        XCTAssertEqual(fake.requests.map(\.agent), ["conductor", "guide", "librarian"])
    }

    func testAKeyStoredInAFactNeverReachesARequest() async throws {
        let key = "sk-" + "ant-api03-" + String(repeating: "Qm4v", count: 10)  // made up, built from pieces
        let store = try MapStore()
        try await store.add(MapNode(mapClass: .note, kind: "reference", text: "The deploy key is \(key)", origin: .told))
        let fake = FakeProvider(rounds: ["conductor": [Reply(pieces: [#"{"route":"explain"}"#])], "guide": [answer]])
        _ = try await events(brain(fake, store), "Where is the deploy key?", packet())

        let guide = try XCTUnwrap(fake.requests.first { $0.agent == "guide" })
        XCTAssertTrue(guide.text.contains("deploy key"))  // the fact was recalled…
        XCTAssertTrue(guide.text.contains(SecretsFilter.keyMarker))  // …without the key
        for request in fake.requests { XCTAssertFalse(request.text.contains(key), request.agent) }
    }

    func testTheGuideSearchesTheMapItself() async throws {
        let store = try await seeded()
        let round = Reply(blocks: #"[{"type":"tool_use","id":"toolu_1","name":"search_map","input":{"query":"palette","class":"History"}}]"#,
                          stop: "tool_use")
        let fake = FakeProvider(rounds: ["guide": [round, answer]])
        _ = try await events(brain(fake, store), "", packet(window: "Untitled"))
        let guide = fake.requests.filter { $0.agent == "guide" }
        XCTAssertEqual(guide.count, 2)
        let result = try XCTUnwrap((JSONSerialization.jsonObject(with: guide[1].after[1].content) as? [[String: Any]])?.first)
        XCTAssertTrue((result["content"] as? String ?? "").contains("Asked how to pick the palette."))
    }

    // MARK: P5.2: the Librarian after the answer

    func testTheLibrarianLearnsFromTheAnswerTextAfterTheAnswer() async throws {
        let store = try MapStore()
        let fake = FakeProvider(rounds: [
            "conductor": [Reply(pieces: [#"{"route":"guide"}"#])],
            "guide": [Reply(pieces: [#"{"explanation":"Use the Kerning field.","steps":[{"instruction":"Click Text","element":null,"point":null}]}"#])],
            "librarian": [Reply(pieces: [Made.reply(things: [Made.thing("t1", "Topic", "Kerning")], summary: "Asked about kerning.")])],
        ])
        _ = try await events(brain(fake, store), "How do I tighten these letters?", packet())

        let librarian = try XCTUnwrap(fake.requests.first { $0.agent == "librarian" })
        XCTAssertTrue(librarian.text.contains("Answer:\nUse the Kerning field.\nSteps:\n1. Click Text"))
        XCTAssertFalse(librarian.text.contains("SCREEN-TEXT-ONLY"))  // labels only, never the window text
        XCTAssertNil(librarian.image)
        let nodes = await store.visibleNodes()
        XCTAssertTrue(nodes.contains { $0.mapClass == .topic && $0.name == "Kerning" })
        let past = await store.visibleEvents()
        XCTAssertEqual(past.count, 1)
    }

    /// Delays only the Librarian, so the next question starts while it still runs.
    struct SlowLibrarian: ModelProvider {
        let base: FakeProvider
        func stream(_ request: ModelRequest) -> AsyncThrowingStream<ModelEvent, Error> {
            guard request.agent == "librarian" else { return base.stream(request) }
            return AsyncThrowingStream { continuation in
                Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    do {
                        for try await event in base.stream(request) { continuation.yield(event) }
                        continuation.finish()
                    } catch { continuation.finish(throwing: error) }
                }
            }
        }
    }

    func testTheNextRecallWaitsForTheLibrarian() async throws {
        let store = try MapStore()
        let fake = FakeProvider(rounds: [
            "conductor": [Reply(pieces: [#"{"route":"explain"}"#])], "guide": [answer],
            "librarian": [Reply(pieces: [Made.reply(things: [Made.thing("t1", "Topic", "Quokka grammar")], summary: "Asked about it.")]),
                          Reply(pieces: [Made.reply()])],
        ])
        let brain = brain(SlowLibrarian(base: fake), store)
        // The first answer ends at once; its Librarian is still running when the second question arrives.
        for try await _ in brain.answer("What is quokka grammar?", packet: packet()) {}
        _ = try await events(brain, "Tell me more about quokka grammar", packet())
        let second = try XCTUnwrap(fake.requests.last { $0.agent == "guide" })
        XCTAssertTrue(second.text.contains("Quokka grammar (Topic)"))
    }

    // MARK: P5.8: the remember route and forget

    func testRememberShowsTheLibrariansCardAndStoresTheFact() async throws {
        let store = try MapStore()
        let reply = Made.reply(notes: [Made.note("Prefers answers in Italian.", about: ["me"], kind: "preference", origin: "told")],
                               summary: "Told a preference.", card: "Stored: you prefer answers in Italian.")
        let fake = FakeProvider(rounds: ["conductor": [Reply(pieces: [#"{"route":"remember"}"#])], "librarian": [Reply(pieces: [reply])]])
        let all = try await events(brain(fake, store), "Remember that I prefer answers in Italian", packet())
        XCTAssertEqual(all, [.route(.remember), .text("Stored: you prefer answers in Italian."), .done])
        XCTAssertFalse(fake.requests.contains { $0.agent == "guide" })
        let nodes = await store.visibleNodes()
        XCTAssertTrue(nodes.contains { $0.text == "Prefers answers in Italian." && $0.origin == .told })
    }

    func testForgetActsAtOnceClearsTheTurnsAndRecallNoLongerShowsIt() async throws {
        let store = try MapStore()
        try await store.add(MapNode(mapClass: .topic, kind: "skill", name: "Kerning", origin: .observed))
        let fake = FakeProvider(rounds: [
            "conductor": [Reply(pieces: [#"{"route":"remember"}"#]), Reply(pieces: [#"{"route":"explain"}"#])],
            "librarian": [Reply(pieces: [Made.reply(forget: ["f1"])]), Reply(pieces: [Made.reply()])],
            "guide": [answer],
        ])
        let brain = brain(fake, store)
        brain.memory.add(Turn(question: "Question: What is kerning?", answer: "The space between two letters."))
        let all = try await events(brain, "Forget kerning", packet())
        guard case .text(let card)? = all.dropFirst().first else { return XCTFail("no card") }
        XCTAssertTrue(card.hasPrefix("Forgot Kerning"))
        XCTAssertTrue(brain.memory.turns.isEmpty)

        _ = try await events(brain, "What is kerning?", packet())
        let guide = try XCTUnwrap(fake.requests.last { $0.agent == "guide" })
        XCTAssertFalse(guide.text.contains("Kerning ("))
    }

    // MARK: P5.15: Recently deleted and the purge

    func testRecentlyDeletedRestoreAndDeleteNow() async throws {
        let store = try MapStore()
        let a = try await store.add(MapNode(mapClass: .person, name: "Zeppelina", origin: .told))
        let b = try await store.add(MapNode(mapClass: .person, name: "Brontolo", origin: .told))
        try await store.forget([a])
        try await store.forget([b])
        let brain = brain(FakeProvider([:]), store)

        let listed = await brain.recentlyDeleted()
        XCTAssertEqual(listed.count, 2)
        XCTAssertTrue(listed.allSatisfy { $0.daysLeft == 30 })
        let zeppelina = try XCTUnwrap(listed.first { $0.label.contains("Zeppelina") })
        let brontolo = try XCTUnwrap(listed.first { $0.label.contains("Brontolo") })

        let restored = await brain.restore(zeppelina.id)
        XCTAssertTrue(restored)
        let back = try await store.node(a)
        XCTAssertEqual(back?.name, "Zeppelina")
        let deleted = await brain.deleteNow(brontolo.id)
        XCTAssertTrue(deleted)
        let left = try await store.count("SELECT count(*) FROM all_nodes WHERE id = ?", [.int(b)])
        XCTAssertEqual(left, 0)
        let after = await brain.recentlyDeleted()
        XCTAssertTrue(after.isEmpty)
        let again = await brain.restore(brontolo.id)
        XCTAssertFalse(again)
    }

    func testWithoutAMapRecentlyDeletedIsEmpty() async {
        let brain = ClaudeBrain(provider: FakeProvider([:]))  // under tests the real Map never opens
        let listed = await brain.recentlyDeleted()
        let restored = await brain.restore(1)
        XCTAssertTrue(listed.isEmpty)
        XCTAssertFalse(restored)
    }

    func testThePurgeRunsWhenTheBrainStarts() async throws {
        let store = try MapStore()
        let old = try await store.add(MapNode(mapClass: .person, name: "Zeppelina", origin: .told))
        let recent = try await store.add(MapNode(mapClass: .person, name: "Brontolo", origin: .told))
        try await store.forget([old], now: .now.addingTimeInterval(-31 * 86_400))
        try await store.forget([recent])
        let before = await store.recentlyDeleted()
        XCTAssertEqual(before.count, 2)

        let map = BrainMap(open: { store }, maintenance: true)
        var tries = 0
        while await store.recentlyDeleted().count != 1, tries < 100 {
            tries += 1
            try await Task.sleep(for: .milliseconds(20))
        }
        let kept = await store.recentlyDeleted()
        XCTAssertEqual(kept.map(\.label).filter { $0.contains("Brontolo") }.count, 1)
        let wiped = try await store.count("SELECT count(*) FROM all_nodes WHERE id = ?", [.int(old)])
        XCTAssertEqual(wiped, 0)
        _ = map
    }
}
