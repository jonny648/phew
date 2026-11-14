import XCTest
@testable import Phew

/// Made-up Librarian replies in the fixed form (docs/05-map.md 5.9). Every field is always present, as the
/// structured output guarantees; these helpers fill the ones a test does not care about.
enum Made {
    static let now = try! Date("2026-11-14T12:00:00Z", strategy: .iso8601)

    static func thing(_ label: String, _ mapClass: String, _ name: String, kind: String = "", other: [String] = [], due: String = "",
                      done: String = "", start: String = "", end: String = "", path: String = "", understood: String = "not said",
                      status: String = "new", fact: String = "", origin: String = "observed", date: String = "",
                      sensitive: Bool = false) -> [String: Any] {
        ["label": label, "class": mapClass, "kind": kind, "name": name, "other_names": other, "due": due, "done": done, "start": start,
         "end": end, "path": path, "understood": understood, "status": status, "fact": fact, "origin": origin, "date": date,
         "sensitive": sensitive]
    }

    static func note(_ text: String, about: [String] = [], kind: String = "decision", status: String = "new", fact: String = "",
                     origin: String = "observed", date: String = "", sensitive: Bool = false) -> [String: Any] {
        ["text": text, "kind": kind, "about": about, "status": status, "fact": fact, "origin": origin, "date": date, "sensitive": sensitive]
    }

    static func link(_ from: String, _ link: String, _ to: String, status: String = "new", fact: String = "",
                     origin: String = "observed") -> [String: Any] {
        ["from": from, "link": link, "to": to, "status": status, "fact": fact, "origin": origin, "date": ""]
    }

    static func reply(things: [[String: Any]] = [], notes: [[String: Any]] = [], links: [[String: Any]] = [], summary: String = "",
                      project: String = "", forget: [String] = [], askBack: String = "", card: String = "",
                      windowProject: String = "") -> String {
        let object: [String: Any] = ["things": things, "notes": notes, "links": links, "summary": summary, "project": project,
                                     "forget": forget, "ask_back": askBack, "card": card, "window_project": windowProject]
        return String(decoding: try! JSONSerialization.data(withJSONObject: object), as: UTF8.self)
    }

    static func packet(app: String = "Figma", window: String = "Poster draft", path: String? = nil, text: String = "") -> ContextPacket {
        ContextPacket(appName: app, bundleID: "com.example.made-up", windowTitle: window, visibleText: text, cursor: nil, documentPath: path)
    }

    /// One Librarian run with a canned reply. Returns the outcome and the request that was sent.
    @discardableResult
    static func learn(_ store: MapStore, _ reply: String, question: String = "What is this?", answer: String = "An answer.",
                      route: Route = .explain, packet: ContextPacket? = Made.packet(), lastTurn: Turn? = nil,
                      now: Date = Made.now) async throws -> (LibrarianOutcome, ModelRequest?) {
        let fake = BrainAgentsTests.FakeProvider(["librarian": [reply]])
        let outcome = try await store.learn(question: question, answer: answer, route: route, packet: packet, lastTurn: lastTurn,
                                            provider: fake, now: now)
        return (outcome, fake.requests.first)
    }

    /// The fact number ("f3") the Librarian is sent for `id`, with these words.
    static func fact(_ store: MapStore, _ id: Int64, question: String, route: Route = .explain,
                     packet: ContextPacket? = Made.packet()) async -> String? {
        await store.librarianBrief(question: question, answer: "", route: route, packet: packet, now: now).facts.first { $0.value == id }?.key
    }
}

/// P5.2: the Librarian's prompt and request, and every code check on its reply, with made-up replies and a fake
/// provider. No network.
final class LibrarianTests: XCTestCase {
    private func only(_ nodes: [MapNode], _ mapClass: MapClass) -> [MapNode] { nodes.filter { $0.mapClass == mapClass } }

    func testEveryWritableClassAndLinkGivesItsRows() async throws {
        let store = try MapStore()
        let reply = Made.reply(
            things: [Made.thing("t1", "Project", "Acme rebrand", kind: "client job"),
                     Made.thing("t2", "Task", "Poster brief", kind: "delivery", due: "2026-11-20", done: "no"),
                     Made.thing("t3", "Topic", "Kerning", kind: "skill"),
                     Made.thing("t4", "Document", "logo-v3.fig", kind: "design file", path: "/Users/made-up/Acme/logo-v3.fig"),
                     Made.thing("t5", "Person", "Marta Vellani", kind: "client", other: ["Marta"]),
                     Made.thing("t6", "Organization", "Acme Biscotti", kind: "client"),
                     Made.thing("t7", "Tool", "Figma", kind: "app"),
                     Made.thing("t8", "Event", "Design review", kind: "review", start: "2026-11-20T15:00", end: "2026-11-20T16:00"),
                     Made.thing("t9", "Place", "Room B12", kind: "room")],
            notes: [Made.note("The client approved logo v3", about: ["t4"])],
            links: [Made.link("t2", "part_of", "t1"), Made.link("t5", "part_of", "t6"), Made.link("t4", "about", "t3"),
                    Made.link("t2", "requires", "t3"), Made.link("t1", "involves", "t5"), Made.link("t1", "uses", "t7"),
                    Made.link("t8", "at", "t9")],
            summary: "Asked what changed in the Acme logo; Phew explained the approved v3.", project: "t1")
        let (out, _) = try await Made.learn(store, reply, question: "What did the client approve?")
        XCTAssertEqual(out.dropped, 0)

        let nodes = await store.visibleNodes()
        for mapClass in MapClass.allCases {
            XCTAssertEqual(only(nodes, mapClass).count, 1, "one \(mapClass.rawValue)")
        }
        let eventID = try XCTUnwrap(out.event)
        let read = try await store.event(eventID)
        let event = try XCTUnwrap(read)
        let acme = try XCTUnwrap(only(nodes, .project).first)
        XCTAssertEqual(event.kind, .ask)
        XCTAssertEqual(event.app, "Figma")
        XCTAssertEqual(event.project, acme.id, "the Librarian's Project, since code detected none")
        XCTAssertEqual(event.summary, "Asked what changed in the Acme logo; Phew explained the approved v3.")
        XCTAssertEqual(Set(event.mentions), Set(nodes.filter { $0.mapClass != .me }.map(\.id)))
        for node in nodes where node.mapClass != .me {
            XCTAssertEqual(node.origin, .observed)
            XCTAssertEqual(node.confidence, 0.6, "set by code from the origin")
            XCTAssertEqual(node.sourceEvent, event.id, "the past question is the source")
            XCTAssertFalse(node.sensitive)
        }
        let task = try XCTUnwrap(only(nodes, .task).first)
        XCTAssertEqual(task.properties, #"{"done":{"origin":"observed","value":false},"due":{"origin":"observed","value":"2026-11-20"}}"#)
        let start = try XCTUnwrap(MapStore.values(only(nodes, .event)[0].properties)["start"] as? String)
        XCTAssertEqual(MapDate.say(start, now: Made.now, withTime: true), "20 Nov 15:00", "a local time, stored as ISO 8601")
        XCTAssertEqual(MapStore.values(only(nodes, .document)[0].properties)["path"] as? String, "/Users/made-up/Acme/logo-v3.fig")
        XCTAssertEqual(only(nodes, .person)[0].aliases, ["Marta"])

        let edges = await store.visibleEdges()
        for link in MapLink.allCases where link != .understands {
            XCTAssertFalse(edges.filter { $0.link == link }.isEmpty, "a \(link.rawValue) row")
        }
        XCTAssertEqual(edges.filter { $0.link != .understands }.count, 8, "7 links and the Note's about")
        let understands = try XCTUnwrap(edges.first { $0.link == .understands })
        XCTAssertEqual(understands.strength, 0.3, "the first question about a Topic, set by code")
    }

    func testNeverASecondMeAndAnythingOutsideTheListIsDropped() async throws {
        let store = try MapStore()
        let reply = Made.reply(
            things: [Made.thing("t1", "Me", "Pat Example"), Made.thing("t2", "Course", "Typography 2"),
                     Made.thing("t3", "Note", "A note as a thing"), Made.thing("t4", "PROJECT", "Garden plan"),
                     Made.thing("t5", "Person", "Ilaria"), Made.thing("t6", "topic", "Grids")],
            notes: [Made.note("Pat is the user's name", about: ["me"], kind: "identity"), Made.note("About an unknown fact", about: ["f42"])],
            links: [Made.link("t5", "part_of", "t4"),        // Person to Project: ends not allowed
                    Made.link("t4", "related_to", "t6"),     // not one of the links
                    Made.link("me", "understands", "t6"),    // never written by the Librarian
                    Made.link("t4", "involves", "t99"),      // unknown label
                    Made.link("t1", "involves", "t5"),       // the dropped Me thing
                    Made.link("T4", "Involves", "t5")],      // capitals ignored: kept
            summary: "Made-up.")
        let (out, _) = try await Made.learn(store, reply)
        let nodes = await store.visibleNodes()
        XCTAssertEqual(only(nodes, .me).count, 1, "never a second Me")
        XCTAssertEqual(Set(nodes.filter { $0.mapClass != .me && $0.mapClass != .note }.map(\.name)), ["Garden plan", "Ilaria", "Grids"])
        XCTAssertEqual(only(nodes, .note).map(\.text), ["Pat is the user's name", "About an unknown fact"])
        let me = try XCTUnwrap(only(nodes, .me).first)
        XCTAssertEqual(me.name, "", "the Librarian never names Me as a thing")
        let edges = await store.visibleEdges()
        XCTAssertEqual(edges.filter { $0.link == .involves }.count, 1)
        XCTAssertTrue(edges.contains { $0.link == .about && $0.to == me.id }, "a Note about me")
        XCTAssertFalse(edges.contains { $0.link == .understands && $0.strength != 0.3 })
        XCTAssertEqual(out.dropped, 3 + 1 + 5, "3 things, 1 unknown fact number, 5 links")
    }

    func testUnderstandsIsSetByCodeFromWhatTheReplySays() async throws {
        let store = try MapStore()
        // A number in the reply is not part of the form and is ignored.
        var kerning = Made.thing("t1", "Topic", "Kerning", kind: "skill")
        kerning["strength"] = 0.95
        func strength() async -> Double? { await store.visibleEdges().first { $0.link == .understands }?.strength }
        try await Made.learn(store, Made.reply(things: [kerning]), question: "What is kerning?")
        var value = await strength()
        XCTAssertEqual(value, 0.3)
        try await Made.learn(store, Made.reply(things: [Made.thing("t1", "Topic", "kerning")]), question: "And kerning pairs?")
        value = await strength()
        XCTAssertEqual(value, 0.2, "each later question takes 0.1 off")
        try await Made.learn(store, Made.reply(things: [Made.thing("t1", "Topic", "Kerning", understood: "yes", origin: "told")]),
                             question: "I understand kerning now", route: .remember)
        value = await strength()
        XCTAssertEqual(value, 0.9, "what the user said wins")
        try await Made.learn(store, Made.reply(things: [Made.thing("t1", "Topic", "Kerning", understood: "no", origin: "told")]),
                             question: "I still don't get kerning, explain again")
        value = await strength()
        XCTAssertEqual(value, 0, "said not understood, in a question: 0, and no 0.1 step")
        let topics = await store.visibleNodes().filter { $0.mapClass == .topic }
        XCTAssertEqual(topics.count, 1, "the same Topic every time")
    }

    func testReuseOnlyWhenNameClassAndProjectMatch() async throws {
        let store = try MapStore()
        let acme = try await store.add(MapNode(mapClass: .project, name: "Acme rebrand", origin: .told))
        let poster = try await store.add(MapNode(mapClass: .task, name: "Poster brief", origin: .told))
        try await store.add(MapEdge(from: poster, to: acme, link: .partOf, origin: .told))
        let jose = try await store.add(MapNode(mapClass: .person, name: "José Pérez", origin: .told))
        let logo = try await store.add(MapNode(mapClass: .document, name: "logo-v3.fig",
                                               properties: MapStore.properties(["path": ("/Users/made-up/Acme/logo-v3.fig", Origin.told)]), origin: .told))

        // Same class, name ignoring capitals and accents, same Project: reused, whatever the model said.
        let (same, _) = try await Made.learn(store, Made.reply(
            things: [Made.thing("p", "Project", "acme REBRAND"), Made.thing("t", "Task", "poster BRIEF"), Made.thing("j", "Person", "jose perez"),
                     Made.thing("d", "Document", "Final logo", path: "/Users/made-up/Acme/logo-v3.fig")],
            links: [Made.link("t", "part_of", "p")]))
        XCTAssertEqual(same.stored, [], "nothing new")
        XCTAssertEqual(Set(same.seen), [acme, poster, jose, logo], "the path decides for a Document, not the name")

        // The same Task name in another Project, and the same name in another class: new things.
        let (other, _) = try await Made.learn(store, Made.reply(
            things: [Made.thing("p", "Project", "Typography 2"), Made.thing("t", "Task", "Poster brief"), Made.thing("x", "Topic", "Poster brief")],
            links: [Made.link("t", "part_of", "p")]))
        let nodes = await store.visibleNodes()
        let tasks = nodes.filter { $0.mapClass == .task }
        XCTAssertEqual(tasks.count, 2, "another Project: another Task")
        XCTAssertEqual(nodes.filter { $0.name == "Poster brief" && $0.mapClass == .topic }.count, 1, "another class: another thing")
        XCTAssertEqual(other.stored.count, 3)

        // With no Project given, any Project matches.
        let (any, _) = try await Made.learn(store, Made.reply(things: [Made.thing("t", "Task", "Poster Brief", done: "yes")]))
        XCTAssertEqual(any.stored, [])
        XCTAssertEqual(any.seen.count, 1)
    }

    func testTheRequestHoldsNoWindowTextNoPictureNoElements() async throws {
        let store = try MapStore()
        try await store.add(MapNode(mapClass: .project, name: "Acme rebrand", origin: .told))
        var packet = Made.packet(app: "Figma", window: "Acme rebrand – banner", path: "/Users/made-up/Acme/banner.fig",
                                 text: "ZANZIBAR-SCREEN-TEXT quarterly figures")
        packet.screenshot = Data(repeating: 7, count: 64)
        packet.pointables = [Pointable(id: "e1", role: "AXButton", label: "QUOKKA-BUTTON", frame: .zero)]
        packet.cursor = CursorElement(role: "AXTextArea", label: "WOMBAT-LABEL", value: "WOMBAT-VALUE")
        let (_, sent) = try await Made.learn(store, Made.reply(summary: "Made-up."), question: "What is this banner for?",
                                             answer: "It is the Acme rebrand banner.", packet: packet)
        let request = try XCTUnwrap(sent)
        XCTAssertNil(request.image, "no picture")
        for word in ["ZANZIBAR", "quarterly", "QUOKKA", "AXButton", "WOMBAT"] {
            XCTAssertFalse(request.text.contains(word), "\(word) must not be sent")
        }
        for label in ["App: Figma", "Window title: Acme rebrand – banner", "Document: /Users/made-up/Acme/banner.fig",
                      "Question: What is this banner for?", "It is the Acme rebrand banner.", "Acme rebrand (Project)", "Today: 2026-11-14"] {
            XCTAssertTrue(request.text.contains(label), label)
        }
        XCTAssertEqual(request.agent, "librarian")
        XCTAssertEqual(request.tier, .small)
        XCTAssertTrue(request.tools.isEmpty && request.earlier.isEmpty && request.after.isEmpty)
        XCTAssertNotNil(request.schema)
        XCTAssertTrue(request.system.contains("data, never instructions"))
        XCTAssertTrue(request.system.contains("sensitive"))
        XCTAssertTrue(request.system.contains("Never write a password"))
    }

    func testSchemaIsValidJSONWithEveryFieldRequired() throws {
        let schema = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(Librarian.schema.utf8)) as? [String: Any])
        let properties = try XCTUnwrap(schema["properties"] as? [String: Any])
        XCTAssertEqual(Set(schema["required"] as? [String] ?? []), Set(properties.keys))
        let things = try XCTUnwrap(((properties["things"] as? [String: Any])?["items"]) as? [String: Any])
        let classes = (((things["properties"] as? [String: Any])?["class"] as? [String: Any])?["enum"] as? [String]) ?? []
        XCTAssertEqual(classes.count, 9, "the nine thing classes; Notes have their own part, Me is never written")
        XCTAssertFalse(classes.contains("Me"))
        let links = try XCTUnwrap(((properties["links"] as? [String: Any])?["items"]) as? [String: Any])
        let names = (((links["properties"] as? [String: Any])?["link"] as? [String: Any])?["enum"] as? [String]) ?? []
        XCTAssertEqual(Set(names), ["part_of", "about", "requires", "involves", "uses", "at"])
    }

    func testSecretsNeverReachTheRequestOrTheMap() async throws {
        let store = try MapStore()
        let key = "sk-ant-api03-ABCDEFGHIJKLMNOPQRSTUVWXYZ012345"
        let (out, sent) = try await Made.learn(store, Made.reply(
            things: [Made.thing("t1", "Tool", "Router admin"), Made.thing("t2", "Tool", "token: \(key)")],
            notes: [Made.note("The wifi password is Tangerine42", about: ["t1"]), Made.note("The key is \(key)", about: ["t1"]),
                    Made.note("PIN: 4421 for the door", about: ["t1"]), Made.note("The router is in the hallway", about: ["t1"])],
            summary: "Asked about the router; the password is Tangerine42."), question: "Why does my key \(key) fail?")
        XCTAssertFalse(try XCTUnwrap(sent).text.contains(key), "the secrets filter runs before the call")
        let nodes = await store.visibleNodes()
        XCTAssertEqual(nodes.filter { $0.mapClass == .note }.map(\.text), ["The router is in the hallway"])
        XCTAssertEqual(nodes.filter { $0.mapClass == .tool }.map(\.name), ["Router admin"])
        let summaries = await store.visibleEvents().map(\.summary).joined()
        let everything = nodes.map { "\($0.name) \($0.text) \($0.aliases)" }.joined() + summaries
        for secret in ["Tangerine42", "4421", key, "sk-ant"] { XCTAssertFalse(everything.contains(secret), secret) }
        XCTAssertEqual(out.dropped, 4)
    }

    func testSensitiveFactsGoToTheSensitiveFile() async throws {
        let store = try MapStore()
        let (out, _) = try await Made.learn(store, Made.reply(
            things: [Made.thing("t1", "Person", "Luca Ferrandi", kind: "friend")],
            notes: [Made.note("The current account balance is 3,214.50 euros", about: ["me"], kind: "reference", sensitive: true),
                    Made.note("Luca wrote privately that he is unwell", about: ["t1"], kind: "reference", sensitive: true),
                    Made.note("Luca is a friend from school", about: ["t1"], kind: "identity")],
            summary: "Asked what the page shows."), question: "What is on this page?")
        let notes = await store.visibleNodes().filter { $0.mapClass == .note }
        for note in notes {
            let files = try await store.fileCounts("nodes", note.id)
            let sensitive = !note.text.contains("friend from school")
            XCTAssertEqual(note.sensitive, sensitive, note.text)
            XCTAssertEqual(files.sensitive, sensitive ? 1 : 0, note.text)
            XCTAssertEqual(files.main, sensitive ? 0 : 1, note.text)
        }
        let event = try XCTUnwrap(out.event)
        let eventFiles = try await store.fileCounts("events", event)
        XCTAssertEqual(eventFiles.sensitive, 1, "a past question that mentions a sensitive fact is sensitive")
        let found = await store.search(["balance"])
        XCTAssertEqual(found.count, 1, "found from its own index")

        // A stored thing the reply marks sensitive moves to the sensitive file.
        let (_, _) = try await Made.learn(store, Made.reply(things: [Made.thing("t1", "Person", "Luca Ferrandi", sensitive: true)]))
        let people = await store.visibleNodes()
        let luca = try XCTUnwrap(people.first { $0.name == "Luca Ferrandi" })
        let lucaFiles = try await store.fileCounts("nodes", luca.id)
        XCTAssertEqual(lucaFiles.sensitive, 1)
        XCTAssertEqual(lucaFiles.main, 0)
    }

    func testAReplyNotInTheFormWritesNothing() async throws {
        let store = try MapStore()
        let nodesBefore = await store.visibleNodes().count
        for bad in ["not json", #"{"things":[],"notes":[]}"#, #"{"things":[{"label":"t1"}],"notes":[],"links":[],"summary":"","project":"","forget":[],"ask_back":"","card":""}"#] {
            do {
                try await Made.learn(store, bad)
                XCTFail("must throw")
            } catch {
                XCTAssertEqual(error as? BrainError, .badOutput)
            }
        }
        let nodesAfter = await store.visibleNodes().count
        let events = await store.visibleEvents().count
        XCTAssertEqual(nodesBefore, nodesAfter)
        XCTAssertEqual(events, 0)
    }

    func testNoteRulesAndWebAddresses() async throws {
        let store = try MapStore()
        let acme = try await store.add(MapNode(mapClass: .project, name: "Acme rebrand", origin: .told))
        let packet = Made.packet(app: "Figma", window: "Acme rebrand – logo")
        let (first, _) = try await Made.learn(store, Made.reply(
            things: [Made.thing("t1", "Document", "Pricing page", kind: "web page", path: "https://example.com/pricing?ref=mail#top")],
            notes: [Made.note("The client approved logo v3")], summary: "Made-up."), packet: packet)
        let eventID = try XCTUnwrap(first.event)
        let read = try await store.event(eventID)
        let event = try XCTUnwrap(read)
        XCTAssertEqual(event.project, acme, "the Project code detected")
        let written = await store.visibleNodes()
        let note = try XCTUnwrap(written.first { $0.mapClass == .note })
        let about = await store.visibleEdges().filter { $0.from == note.id && $0.link == .about }.map(\.to)
        XCTAssertEqual(about, [acme], "a Note about nothing is about the Project of the question")
        let page = try XCTUnwrap(written.first { $0.mapClass == .document })
        XCTAssertEqual(MapStore.values(page.properties)["address"] as? String, "https://example.com/pricing")

        let (again, _) = try await Made.learn(store, Made.reply(notes: [Made.note("the CLIENT approved lógo v3")]), packet: packet)
        XCTAssertEqual(again.stored, [])
        XCTAssertEqual(again.seen, [note.id], "the same sentence is seen again, not stored twice")
        let seen = try await store.node(note.id)
        XCTAssertEqual(seen?.confidence, 0.7)
    }

    func testProjectDetectionIgnoresShortAndCommonWords() async throws {
        let store = try MapStore()
        let rotonda = try await store.add(MapNode(mapClass: .project, name: "La Rotonda", origin: .told))
        try await store.add(MapNode(mapClass: .project, name: "The Plan", origin: .told))
        try await store.add(MapNode(mapClass: .project, name: "Di Marco", origin: .told))
        let none = await store.detectProject(appName: "Preview", windowTitle: "La bella estate.pdf", documentPath: nil, question: "di cosa parla questa pagina?")
        XCTAssertNil(none, "la, di, cosa, questa never name a Project")
        let english = await store.detectProject(appName: "Safari", windowTitle: "The weather today", documentPath: nil, question: "what is this about?")
        XCTAssertNil(english)
        let hit = await store.detectProject(appName: "Numbers", windowTitle: "Rotonda budget", documentPath: nil)
        XCTAssertEqual(hit?.id, rotonda)
        XCTAssertEqual(MapStore.detectionWords(["La bella estate.pdf", "di cosa parla?"]), "bella estate pdf parla")
    }

    func testLooksSecret() {
        for text in ["The wifi password is Tangerine42", "Password: hunter2", "pin = 4421", "La password è gatto99",
                     "Your API key is abc", "token: x1", SecretsFilter.keyMarker, "card \(SecretsFilter.cardMarker)"] {
            XCTAssertTrue(Librarian.looksSecret(text), text)
        }
        for text in ["The client approved logo v3", "Pinterest board for the moodboard", "Answer in Italian", "Spinning class on Monday",
                     "Change the password in Settings", "Use a password manager", "Reset the PIN code from settings"] {
            XCTAssertFalse(Librarian.looksSecret(text), text)
        }
        // No "is" or ":": a value with a digit or a symbol right after the word is still a password.
        for text in ["The login box shows the password Quiet-Heron-42 typed in a normal field", "pin 4421", "La password \"gatto_99\" è sbagliata"] {
            XCTAssertTrue(Librarian.looksSecret(text), text)
            XCTAssertFalse(Librarian.scrub(text).contains(where: \.isNumber), text)
        }
    }

    /// "Known person reused": a reply with only a Note about a stored person and a link to her still makes the past
    /// question mention her and the Project, never Me.
    func testThePastQuestionMentionsWhatItsNotesAndLinksAreAbout() async throws {
        let store = try MapStore()
        let acme = try await store.add(MapNode(mapClass: .project, name: "Acme rebrand", origin: .told))
        let marta = try await store.add(MapNode(mapClass: .person, name: "Zeppelina", origin: .told))
        let question = "What does Zeppelina want changed?"
        let packet = Made.packet(app: "Mail", window: "Re: launch – Acme rebrand")
        let mFact = await Made.fact(store, marta, question: question, packet: packet)
        let aFact = await Made.fact(store, acme, question: question, packet: packet)
        let m = try XCTUnwrap(mFact), a = try XCTUnwrap(aFact)
        let (out, _) = try await Made.learn(store, Made.reply(
            notes: [Made.note("Zeppelina wants the launch in December", about: [m]), Made.note("Short answers", about: ["me"])],
            links: [Made.link(a, "involves", m)]), question: question, packet: packet)
        let event = try await store.event(try XCTUnwrap(out.event))
        let mentions = Set(try XCTUnwrap(event).mentions)
        XCTAssertTrue(mentions.isSuperset(of: [marta, acme]))
        let me = await store.visibleNodes().first { $0.mapClass == .me }?.id
        XCTAssertFalse(mentions.contains(try XCTUnwrap(me)))
        XCTAssertEqual(event?.project, acme)
    }

    /// P5.2 sensitive case, whatever the model does: a password shown in a normal field never reaches the request,
    /// and a reply that still carries one (in a thing, a Note or the summary) leaves no trace in the Map.
    func testAPasswordWithoutIsNeverReachesTheRequestOrTheMap() async throws {
        let store = try MapStore()
        let password = "Quiet-Heron-42"
        let (_, sent) = try await Made.learn(store, Made.reply(
            things: [Made.thing("t1", "Document", "Login with password \(password)")],
            notes: [Made.note("The login box shows the password \(password) in a normal text field"),
                    Made.note("The balance is 1,020.00 euros", kind: "reference", sensitive: true)],
            summary: "Asked what the page shows; it shows the password \(password)."),
            question: "What is on this page?", answer: "The login box below shows the password \(password) typed in a normal text field.")
        let request = try XCTUnwrap(sent)
        XCTAssertFalse(request.text.contains("Heron"), "scrubbed before the call")
        XCTAssertTrue(request.text.contains(Librarian.secretMarker))
        let everything = await store.visibleNodes(currentOnly: false).map { "\($0.name) \($0.text) \($0.properties) \($0.aliases)" }.joined()
            + store.visibleEvents().map(\.summary).joined()
        XCTAssertFalse(everything.contains("Heron"))
        XCTAssertTrue(everything.contains("1,020.00"), "the rest is still stored")
    }

    /// The live check's harness runs end to end on a fake that proposes nothing: every case fails, nothing crashes.
    /// The real run (10 interactions and the sensitive case) is for the owner to approve: it costs money.
    func testSelfCheckHarnessRunsWithoutTheNetwork() async {
        let fake = BrainAgentsTests.FakeProvider(["librarian": [Made.reply(summary: "Made-up.")]])
        let result = await LibrarianSelfCheck.run(provider: fake, now: Made.now)
        XCTAssertEqual(result.total, 10)
        XCTAssertEqual(result.passed, 0)
        XCTAssertFalse(result.sensitive, "nothing stored: no sensitive fact")
    }

    // MARK: P5.6 "this is the X project"

    func testThisIsTheProjectLinksTheFileAndASecondCorrectionWins() async throws {
        let store = try MapStore()
        let path = "/Users/someone/Acme/logo-v3.fig"
        let (first, request) = try await Made.learn(store, Made.reply(windowProject: "Acme rebrand"), question: "This is the Acme rebrand project",
                                                    route: .remember, packet: Made.packet(window: "logo-v3", path: path, text: "SCREEN-TEXT"))
        XCTAssertEqual(first.card, "This window is now in Acme rebrand.")
        XCTAssertFalse(try XCTUnwrap(request).text.contains("SCREEN-TEXT"))  // labels only
        // The next call from the same file names it, whatever the title says.
        let found = await store.detectProject(appName: "Figma", windowTitle: "Untitled", documentPath: path)
        XCTAssertEqual(found?.name, "Acme rebrand")
        XCTAssertEqual(found?.origin, .told)

        let (second, _) = try await Made.learn(store, Made.reply(windowProject: "Orchard Bakery"), question: "No, questo è il progetto Orchard Bakery",
                                               route: .remember, packet: Made.packet(window: "logo-v3", path: path))
        XCTAssertEqual(second.card, "This window is now in Orchard Bakery.")
        let now = await store.detectProject(appName: "Figma", windowTitle: "Untitled", documentPath: path)
        XCTAssertEqual(now?.name, "Orchard Bakery")
        // The old link ended and is kept as history; one Document, one current part_of.
        let edges = await store.visibleEdges(currentOnly: false).filter { $0.link == .partOf }
        XCTAssertEqual(edges.count, 2)
        XCTAssertEqual(edges.filter { $0.validTo == nil }.count, 1)
        let documents = await store.visibleNodes().filter { $0.mapClass == .document }
        XCTAssertEqual(documents.count, 1)
    }

    func testThisIsTheProjectWithATitleOnly() async throws {
        let store = try MapStore()
        let (outcome, _) = try await Made.learn(store, Made.reply(windowProject: "Thesis"), question: "This is the Thesis project",
                                                route: .remember, packet: Made.packet(app: "Pages", window: "Chapter 3 draft"))
        XCTAssertEqual(outcome.card, "This window is now in Thesis.")
        let found = await store.detectProject(appName: "Pages", windowTitle: "Chapter 3 draft", documentPath: nil)
        XCTAssertEqual(found?.name, "Thesis")
    }

    func testWindowProjectIsReadOnlyOnTheRememberRoute() async throws {
        let store = try MapStore()
        try await Made.learn(store, Made.reply(summary: "Asked.", windowProject: "Acme rebrand"), route: .explain,
                             packet: Made.packet(path: "/Users/someone/Acme/logo-v3.fig"))
        let projects = await store.visibleNodes().filter { $0.mapClass == .project }
        XCTAssertTrue(projects.isEmpty)
    }
}
