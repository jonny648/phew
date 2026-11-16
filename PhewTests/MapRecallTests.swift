import XCTest
@testable import Phew

/// Stage S2 of P5: the defined terms (P5.9), project detection (P5.6), recall (P5.3), the rules (P5.11), the profile
/// (P5.7) and `search_map`. A plain Map in memory, a fixed clock, and made-up data only.
final class MapRecallTests: XCTestCase {
    private let now = try! Date("2026-11-14T12:00:00Z", strategy: .iso8601)

    /// A time `days` from now, as stored.
    private func at(_ days: Double) -> String { MapStore.iso(now.addingTimeInterval(days * 86_400)) }
    /// A day alone, `days` from now.
    private func day(_ days: Double) -> String { String(at(days).prefix(10)) }

    @discardableResult
    private func add(_ store: MapStore, _ mapClass: MapClass, _ name: String = "", kind: String = "", text: String = "",
                     values: [String: Any] = [:], origin: Origin = .told, seen: Double = -1, validTo: String? = nil,
                     supersededBy: Int64? = nil) async throws -> Int64 {
        let properties = String(decoding: try JSONSerialization.data(withJSONObject: values.mapValues { ["value": $0, "origin": "told"] }), as: UTF8.self)
        return try await store.add(MapNode(mapClass: mapClass, kind: kind, name: name, text: text, properties: properties,
                                           origin: origin, validFrom: at(seen), validTo: validTo, supersededBy: supersededBy,
                                           created: at(seen), updated: at(seen)))
    }

    private func link(_ store: MapStore, _ from: Int64, _ link: MapLink, _ to: Int64) async throws {
        let id = try await store.add(MapEdge(from: from, to: to, link: link, origin: .told, created: at(-1)))
        XCTAssertNotNil(id, "link \(link) allowed")
    }

    @discardableResult
    private func ask(_ store: MapStore, _ summary: String, project: Int64? = nil, mentions: [Int64] = [], kind: EventKind = .ask,
                     days: Double = -1, app: String = "Figma") async throws -> Int64 {
        try await store.add(MapEvent(time: at(days), app: app, kind: kind, summary: summary, project: project, mentions: mentions))
    }

    // MARK: - P5.9 the eight defined terms

    /// R27: a corrected heard word helps the recogniser only; it is never an other name for detection or matching.
    func testAHeardWordIsNotAnOtherName() async throws {
        let store = try MapStore()
        let id = try await store.add(MapNode(mapClass: .project, kind: "made up", name: "Phew", origin: .told))
        let learned = try await store.addHeardAs("few", name: "Phew")
        XCTAssertTrue(learned)
        let node = try await store.node(id)
        XCTAssertEqual(node?.aliases, [])
        let heard = try await store.heardAs()
        XCTAssertEqual(heard, ["few": "Phew"])
        let detected = await store.detectProject(appName: "Notes", windowTitle: "few made-up notes", documentPath: nil)
        XCTAssertNil(detected, "a heard word never detects the Project")
        let read = try XCTUnwrap(node)
        XCTAssertFalse(MapStore.sameName(read, "few"), "never matched as the same thing")
    }

    func testCurrentAndOpen() async throws {
        let store = try MapStore()
        let open = try await add(store, .task, "Poster brief")
        let done = try await add(store, .task, "Logo sketch", values: ["done": true])
        let old = try await add(store, .task, "Poster draft", validTo: at(-2), supersededBy: open)
        let current = await store.term("current", now: now)
        XCTAssertTrue(current.contains(open) && current.contains(done))
        XCTAssertFalse(current.contains(old), "a history row is not current")
        let openTasks = await store.term("open", now: now)
        XCTAssertEqual(openTasks, [open])
    }

    func testActive() async throws {
        let store = try MapStore()
        let recent = try await add(store, .project, "Acme rebrand")
        let quiet = try await add(store, .project, "Old thesis")
        _ = try await add(store, .project, "Never asked")
        try await ask(store, "Asked about the logo", project: recent, days: -3)
        try await ask(store, "Asked about chapter 2", project: quiet, days: -20)
        let active = await store.term("active", now: now)
        XCTAssertEqual(active, [recent])
    }

    func testDueSoonIncludesALateTaskAndMarksIt() async throws {
        let store = try MapStore()
        let soon = try await add(store, .task, "Poster brief", values: ["due": day(3)])
        _ = try await add(store, .task, "Annual report", values: ["due": day(10)])
        let late = try await add(store, .task, "Invoice Acme", values: ["due": day(-2)])
        let today = try await add(store, .task, "Call printer", values: ["due": day(0)])
        _ = try await add(store, .task, "Send files", values: ["due": day(1), "done": true])
        _ = try await add(store, .task, "Someday idea")
        let dueSoon = await store.term("due_soon", now: now)
        XCTAssertEqual(dueSoon, [late, today, soon], "late first, earliest date first")

        let lines = await store.searchMap(MapSearchArguments(list: "due_soon"), now: now).components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 3)
        XCTAssertTrue(lines[0].contains("Invoice Acme") && lines[0].contains(", late."), lines[0])
        XCTAssertFalse(lines[1].contains("late"), "a day alone lasts until its end: \(lines[1])")
        XCTAssertFalse(lines[2].contains("late"))
    }

    func testComingUp() async throws {
        let store = try MapStore()
        let review = try await add(store, .event, "Review with Marta", values: ["start": at(2)])
        _ = try await add(store, .event, "Launch party", values: ["start": at(10)])
        _ = try await add(store, .event, "Kickoff", values: ["start": at(-1)])
        let todayAllDay = try await add(store, .event, "Studio day", values: ["start": day(0)])
        let comingUp = await store.term("coming_up", now: now)
        XCTAssertEqual(comingUp, [todayAllDay, review])
    }

    func testStale() async throws {
        let store = try MapStore()
        let stale = try await add(store, .note, text: "The printer is on Via Vela", origin: .observed, seen: -100)
        _ = try await add(store, .note, text: "My studio is in Milan", origin: .told, seen: -100)
        _ = try await add(store, .note, text: "The printer closes at six", origin: .observed, seen: -10)
        _ = try await add(store, .note, text: "Old printer address", origin: .imported, seen: -200, validTo: at(-150))
        let found = await store.term("stale", now: now)
        XCTAssertEqual(found, [stale])
        let text = await store.searchMap(MapSearchArguments(query: "printer"), now: now)
        let line = text.components(separatedBy: "\n").first { $0.contains("Via Vela") }
        XCTAssertTrue(line?.contains("May be outdated.") == true, text)
        XCTAssertFalse(text.components(separatedBy: "\n").first { $0.contains("six") }?.contains("outdated") ?? true)
    }

    func testOpenPointAndItsProject() async throws {
        let store = try MapStore()
        let acme = try await add(store, .project, "Acme rebrand")
        let school = try await add(store, .project, "Typography 2")
        let kerning = try await add(store, .topic, "Kerning")
        let once = try await add(store, .topic, "Leading")
        let understood = try await add(store, .topic, "Grids")
        let toldOnly = try await add(store, .topic, "Ligatures")
        for topic in [kerning, understood] {
            try await ask(store, "Asked about a topic", project: acme, mentions: [topic], days: -3)
            try await ask(store, "Asked again about a topic", project: acme, mentions: [topic], kind: .guide, days: -2)
            try await store.moveUnderstanding(topic: topic, said: nil, asked: true, now: now)
            try await store.moveUnderstanding(topic: topic, said: nil, asked: true, now: now)
        }
        try await store.moveUnderstanding(topic: understood, said: true, asked: false, now: now)
        try await ask(store, "Asked once", project: acme, mentions: [once])
        try await ask(store, "Told one thing", mentions: [toldOnly], kind: .tell)
        try await ask(store, "Told another", mentions: [toldOnly], kind: .tell)

        let all = await store.term("open_point", now: now)
        XCTAssertEqual(all, [kerning])
        let ofAcme = await store.term("open_point", now: now, project: acme)
        XCTAssertEqual(ofAcme, [kerning], "mentioned in a past question on Acme")
        let ofSchool = await store.term("open_point", now: now, project: school)
        XCTAssertEqual(ofSchool, [])
        let poster = try await add(store, .task, "Poster brief")
        try await link(store, poster, .partOf, school)
        try await link(store, poster, .requires, kerning)
        let required = await store.term("open_point", now: now, project: school)
        XCTAssertEqual(required, [kerning], "required by one of its Tasks")
    }

    func testNextStepInTheOrderOfTheDefinition() async throws {
        let store = try MapStore()
        let acme = try await add(store, .project, "Acme rebrand")
        try await ask(store, "Asked how to export the logo for print", project: acme, days: -2)
        guard case .question(let last)? = await store.nextStep(project: acme, now: now) else { return XCTFail("last question") }
        XCTAssertEqual(last.summary, "Asked how to export the logo for print")

        let newer = try await add(store, .task, "Pick paper", seen: -1)
        let older = try await add(store, .task, "Brief the printer", seen: -5)
        let closed = try await add(store, .task, "Old chore", values: ["done": true], seen: -9)
        for task in [newer, older, closed] { try await link(store, task, .partOf, acme) }
        guard case .task(let oldest)? = await store.nextStep(project: nil, now: now) else { return XCTFail("open task") }
        XCTAssertEqual(oldest.id, older, "oldest last seen, in the Project of the latest past question")

        let due = try await add(store, .task, "Pay invoice", values: ["due": day(4)])
        guard case .task(let first)? = await store.nextStep(project: acme, now: now) else { return XCTFail("due soon") }
        XCTAssertEqual(first.id, due, "a Task due soon comes first, even outside the Project")
    }

    func testUnderstandingStrengthMoves() async throws {
        let store = try MapStore()
        let topic = try await add(store, .topic, "Kerning")
        var strengths: [Double?] = []
        for _ in 0..<5 { strengths.append(try await store.moveUnderstanding(topic: topic, said: nil, asked: true, now: now)) }
        XCTAssertEqual(strengths, [0.3, 0.2, 0.1, 0, 0], "0.3 at first, then 0.1 less per question, down to 0")
        let unchanged = try await store.moveUnderstanding(topic: topic, said: nil, asked: false, now: now)
        XCTAssertEqual(unchanged, 0, "nothing asked, nothing said: no change")
        let yes = try await store.moveUnderstanding(topic: topic, said: true, asked: true, now: now)
        XCTAssertEqual(yes, 0.9, "what was said wins, with no 0.1 taken off")
        let no = try await store.moveUnderstanding(topic: topic, said: false, asked: true, now: now)
        XCTAssertEqual(no, 0)
        let fresh = try await add(store, .topic, "Grids")
        let toldFirst = try await store.moveUnderstanding(topic: fresh, said: true, asked: false, now: now)
        XCTAssertEqual(toldFirst, 0.9)
        XCTAssertEqual(MapStore.nextStrength(0.3, said: nil), 0.2)
    }

    // MARK: - P5.6 project detection

    func testProjectDetection() async throws {
        let store = try MapStore()
        let acme = try await add(store, .project, "Acme rebrand")
        let logo = try await add(store, .document, "logo-v3.fig", values: ["path": "/Users/made-up/Acme/logo-v3.fig"])
        try await link(store, logo, .partOf, acme)
        let launch = try await add(store, .project, "Phew launch")
        let page = try await add(store, .document, "Pricing page", kind: "web page", values: ["address": "https://example.com/pricing"])
        try await link(store, page, .partOf, launch)
        _ = try await add(store, .project, "Typography 2")

        let byPath = await store.detectProject(appName: "Figma", windowTitle: "Untitled", documentPath: "/Users/made-up/Acme/logo-v3.fig")
        XCTAssertEqual(byPath?.name, "Acme rebrand")
        let byAddress = await store.detectProject(appName: "Safari", windowTitle: "Welcome",
                                                  documentPath: "https://example.com/pricing?ref=mail#top")
        XCTAssertEqual(byAddress?.name, "Phew launch")
        let byTitle = await store.detectProject(appName: "Preview", windowTitle: "Typography 2 – reading list.pdf", documentPath: nil)
        XCTAssertEqual(byTitle?.name, "Typography 2")
        let byDocumentName = await store.detectProject(appName: "Safari", windowTitle: "Pricing page — draft", documentPath: nil)
        XCTAssertEqual(byDocumentName?.name, "Phew launch")
        let none = await store.detectProject(appName: "Calculator", windowTitle: "Calculator", documentPath: "/Applications/Calculator.app")
        XCTAssertNil(none, "no guess when nothing matches")
    }

    func testProjectCorrectionSticks() async throws {
        let store = try MapStore()
        let path = "/Users/made-up/beds.numbers"
        let before = await store.detectProject(appName: "Numbers", windowTitle: "beds", documentPath: path)
        XCTAssertNil(before)
        let garden = try await store.setProject(named: "Garden plan", windowTitle: "beds", documentPath: path, now: now)
        let after = await store.detectProject(appName: "Numbers", windowTitle: "beds", documentPath: path)
        XCTAssertEqual(after?.name, "Garden plan")
        let again = try await store.setProject(named: "garden PLAN", windowTitle: "beds", documentPath: path, now: now)
        XCTAssertEqual(again?.id, garden?.id, "same name ignoring capitals: reused")

        try await store.setProject(named: "Allotment", windowTitle: "beds", documentPath: path, now: now)
        let moved = await store.detectProject(appName: "Numbers", windowTitle: "beds", documentPath: path)
        XCTAssertEqual(moved?.name, "Allotment", "the newer correction wins")
        let history = await store.searchMap(MapSearchArguments(query: "beds"), now: now)
        XCTAssertTrue(history.contains("Part of Allotment") && !history.contains("Garden plan"), history)

        try await store.setProject(named: "Recipes", windowTitle: "Pasta notes", documentPath: nil, now: now)
        let noPath = await store.detectProject(appName: "Notes", windowTitle: "Pasta notes", documentPath: nil)
        XCTAssertEqual(noPath?.name, "Recipes", "with no path, the window title is the label")
    }

    // MARK: - P5.3 recall and P5.11 rules 1 to 3

    /// Acme rebrand with a logo file, a Task due soon that requires Kerning (an open point), and a stale Note.
    private func acmeMap() async throws -> (MapStore, poster: Int64) {
        let store = try MapStore()
        let acme = try await add(store, .project, "Acme rebrand", kind: "client job", seen: -12)
        let logo = try await add(store, .document, "logo-v3.fig", values: ["path": "/Users/made-up/Acme/logo-v3.fig"])
        try await link(store, logo, .partOf, acme)
        let poster = try await add(store, .task, "Poster brief", kind: "delivery", values: ["due": day(3)])
        let kerning = try await add(store, .topic, "Kerning", kind: "skill")
        try await link(store, poster, .partOf, acme)
        try await link(store, poster, .requires, kerning)
        let source = try await ask(store, "Asked how kerning works", project: acme, mentions: [kerning], days: -5)
        try await ask(store, "Asked again about kerning pairs", project: acme, mentions: [kerning], days: -2)
        try await store.moveUnderstanding(topic: kerning, said: nil, asked: true, now: now)
        try await store.moveUnderstanding(topic: kerning, said: nil, asked: true, now: now)
        let paper = try await store.add(MapNode(mapClass: .note, kind: "preference", text: "The client prefers matte paper",
                                                origin: .observed, sourceEvent: source, validFrom: at(-120), created: at(-120), updated: at(-120)))
        try await link(store, paper, .about, acme)
        return (store, poster)
    }

    private let originAndDate = try! NSRegularExpression(pattern: #"(Told|Observed|Imported|Asked|Corrected|Task given) on \d{1,2} [A-Z][a-z]{2}"#)

    private func assertOriginAndDate(_ text: String, line: UInt = #line) {
        let lines = text.components(separatedBy: "\n").filter { $0.hasPrefix("- ") }
        XCTAssertFalse(lines.isEmpty, line: line)
        for item in lines {
            XCTAssertNotNil(originAndDate.firstMatch(in: item, range: NSRange(item.startIndex..., in: item)), "no origin and date: \(item)", line: line)
        }
    }

    func testRecallHandsTheGuideTheRules() async throws {
        let (store, _) = try await acmeMap()
        let text = await store.recall(question: "How should I space the poster title?", appName: "Figma", windowTitle: "Untitled",
                                      documentPath: "/Users/made-up/Acme/logo-v3.fig", now: now)
        XCTAssertTrue(text.contains("Project:\n- Acme rebrand (Project, client job)."), text)
        XCTAssertTrue(text.contains("Start from (open point):\n- Kerning (Topic, skill)."), "rule 1: \(text)")
        XCTAssertTrue(text.contains("Next step:\n- Poster brief (Task, delivery). Due "), "rule 2: \(text)")
        XCTAssertTrue(text.contains("Last past questions:\n- Past question. Asked on 12 Nov in Figma, on Acme rebrand: Asked again about kerning pairs"), text)
        let paper = text.components(separatedBy: "\n").filter { $0.contains("matte paper") }
        XCTAssertFalse(paper.isEmpty)
        for item in paper { XCTAssertTrue(item.lowercased().contains("may be outdated"), "rule 3: \(item)") }
        XCTAssertTrue(text.contains("observed on 17 Jul in Figma, may be outdated"), text)
        assertOriginAndDate(text)
        XCTAssertLessThanOrEqual(text.count, MapStore.recallLimit)
    }

    func testRecallShowsBothDisagreeingFactsOfTheSameOrigin() async throws {
        let (store, poster) = try await acmeMap()
        for sentence in ["The poster is due on the 20th", "The poster is due on the 22nd"] {
            let note = try await add(store, .note, kind: "decision", text: sentence)
            try await link(store, note, .about, poster)
        }
        let text = await store.recall(question: "When is the poster due?", appName: "Mail", windowTitle: "Inbox", documentPath: nil, now: now)
        XCTAssertTrue(text.contains("due on the 20th") && text.contains("due on the 22nd"), "rule 4 needs both on lines: \(text)")
        assertOriginAndDate(text)
    }

    func testAKeyStoredInAFactIsRemovedFromEveryText() async throws {
        let store = try MapStore()
        let key = "sk-ant-api03-MADEUPmadeupMADEUPmadeup0123456789"
        let note = try await add(store, .note, kind: "reference", text: "The staging key is \(key)")
        try await link(store, note, .about, 1)   // Me is the first row of a new Map
        let recall = await store.recall(question: "What is the staging key?", appName: "Terminal", windowTitle: "zsh", documentPath: nil, now: now)
        let search = await store.searchMap(MapSearchArguments(query: "staging key"), now: now)
        let profile = await store.profile(now: now)
        for text in [recall, search, profile] {
            XCTAssertTrue(text.contains("The staging key is \(SecretsFilter.keyMarker)"), text)
            XCTAssertFalse(text.contains("sk-ant"), text)
        }
    }

    func testRecallIsEmptyOnAnEmptyMap() async throws {
        let store = try MapStore()
        let text = await store.recall(question: "What is this?", appName: "Finder", windowTitle: "Desktop", documentPath: nil, now: now)
        XCTAssertEqual(text, "")
    }

    // MARK: - P5.7 profile

    private func profileMap() async throws -> MapStore {
        let store = try MapStore()
        let me = 1 as Int64
        for (sentence, origin, days) in [("Prefers short answers", Origin.observed, -3.0), ("Answer in Italian", .told, -1.0),
                                         ("Uses a dark theme", .imported, -6.0), ("Works in the morning", .told, -8.0)] {
            let note = try await add(store, .note, kind: "preference", text: sentence, origin: origin, seen: days)
            try await link(store, note, .about, me)
        }
        let acme = try await add(store, .project, "Acme rebrand")
        let poster = try await add(store, .task, "Poster brief", values: ["due": day(2)])
        try await link(store, poster, .partOf, acme)
        try await ask(store, "Asked about the poster", project: acme)
        _ = try await add(store, .project, "Old thesis")
        return store
    }

    func testProfileIsTheSameTextForTheSameFacts() async throws {
        let store = try await profileMap()
        let first = await store.profile(now: now)
        let second = await store.profile(now: now)
        XCTAssertEqual(first, second)
        let rebuilt = await (try profileMap()).profile(now: now)
        XCTAssertEqual(first, rebuilt, "same facts, same text")

        let lines = first.components(separatedBy: "\n")
        let order = ["Works in the morning", "Answer in Italian", "Prefers short answers", "Uses a dark theme"].map { sentence in
            lines.firstIndex { $0.contains(sentence) } ?? -1
        }
        XCTAssertEqual(order, order.sorted(), "told first, then observed, then imported: \(first)")
        XCTAssertFalse(order.contains(-1))
        XCTAssertTrue(first.contains("Active projects:\n- Acme rebrand (Project)."), first)
        XCTAssertTrue(first.contains("  - Due soon: Poster brief (Task). Due "), first)
        XCTAssertFalse(first.contains("Old thesis"), "not active")
        assertOriginAndDate(first)
    }

    // MARK: - search_map

    /// The live P5.4 failure: the model searched "this month" with a query and `since` but no class, and got the
    /// Project only. With no class, past questions come back too, beside the things.
    func testSearchMapWithNoClassFindsPastQuestions() async throws {
        let store = try MapStore()
        let project = try await add(store, .project, "Orchard Bakery website", kind: "client job", seen: -12)
        for (n, summary) in ["Asked how to set up the colour palette for the Orchard Bakery website.",
                             "Asked which fonts to use for the Orchard Bakery menu page.",
                             "Asked how to export the Orchard Bakery hero banner."].enumerated() {
            try await ask(store, summary, project: project, days: Double(n * 3 - 10))
        }
        for input in [#"{"query":"Orchard Bakery website","since":"\#(day(-13))","past":true}"#,
                      #"{"query":"Orchard Bakery","since":"\#(day(-13))"}"#,
                      #"{"query":"","since":"\#(day(-13))"}"#,
                      #"{"query":"work done this month","since":"\#(day(-13))"}"#] {
            let text = await store.searchMap(input: Data(input.utf8), now: now)
            XCTAssertTrue(text.contains("palette") && text.contains("fonts"), "\(input): \(text)")
        }
        let things = await store.searchMap(MapSearchArguments(query: "Orchard Bakery"), now: now)
        XCTAssertTrue(things.hasPrefix("- Orchard Bakery website (Project"), "things first: \(things)")
        let onlyProjects = await store.searchMap(MapSearchArguments(query: "Orchard Bakery", mapClass: "Project"), now: now)
        XCTAssertFalse(onlyProjects.contains("Past question"), "one class of things: no past questions")
        let nothing = await store.searchMap(MapSearchArguments(), now: now)
        XCTAssertEqual(nothing, "", "no query, no class, no since, no list")
        let noMatch = await store.searchMap(MapSearchArguments(query: "work done this month"), now: now)
        XCTAssertEqual(noMatch, "", "words that match nothing, with no period, find nothing")
        let tooLate = await store.searchMap(MapSearchArguments(query: "work done", since: day(1)), now: now)
        XCTAssertEqual(tooLate, "", "nothing in the period, nothing found")
    }

    func testSearchMapListsClassesHistoryAndOddInput() async throws {
        let (store, _) = try await acmeMap()
        let due = await store.searchMap(input: Data(#"{"query":"","list":"DUE_SOON"}"#.utf8), now: now)
        XCTAssertTrue(due.hasPrefix("- Poster brief (Task, delivery)."), due)
        let points = await store.searchMap(MapSearchArguments(list: "open_points"), now: now)
        XCTAssertTrue(points.contains("Kerning"))
        let next = await store.searchMap(MapSearchArguments(list: "next_step"), now: now)
        XCTAssertTrue(next.contains("Poster brief"))
        let stale = await store.searchMap(MapSearchArguments(list: "stale"), now: now)
        XCTAssertTrue(stale.contains("matte paper"))
        let history = await store.searchMap(MapSearchArguments(query: "", mapClass: "history", since: day(-3)), now: now)
        XCTAssertTrue(history.contains("kerning pairs") && !history.contains("how kerning works"), history)
        let tasks = await store.searchMap(MapSearchArguments(query: "", mapClass: "task"), now: now)
        XCTAssertTrue(tasks.hasPrefix("- Poster brief"), tasks)
        let onlyTopics = await store.searchMap(MapSearchArguments(query: "kerning poster", mapClass: "Topic"), now: now)
        XCTAssertTrue(onlyTopics.contains("Kerning") && !onlyTopics.contains("Poster brief (Task"), onlyTopics)
        assertOriginAndDate(due + "\n" + history + "\n" + tasks)

        let unknownList = await store.searchMap(MapSearchArguments(list: "everything"), now: now)
        XCTAssertEqual(unknownList, "")
        let unknownClass = await store.searchMap(MapSearchArguments(query: "poster", mapClass: "Robot"), now: now)
        XCTAssertEqual(unknownClass, "")
        for raw in ["", "[]", "\"x\"", "null", "{}", #"{"query": 5, "past": "yes", "class": 7}"#,
                    #"{"query":"\"*) OR NOT (","since":"not a date"}"#, #"{"query":"poster","since":"2026-13-45","past":true}"#,
                    "\u{0}\u{1}garbage"] {
            _ = await store.searchMap(input: Data(raw.utf8), now: now)
        }
        let oddSince = await store.searchMap(input: Data(#"{"query":"poster","since":"soon"}"#.utf8), now: now)
        XCTAssertTrue(oddSince.contains("Poster brief"), "an unreadable date is ignored")
        let wide = await store.searchMap(MapSearchArguments(query: "a b c d e f g h i j k l poster kerning the"), now: now)
        XCTAssertLessThanOrEqual(wide.components(separatedBy: "\n").count, 10)
    }

    func testSearchMapPastVersionsAndRunnerAddresses() async throws {
        let store = try MapStore()
        let living = try await add(store, .task, "Poster brief", values: ["due": day(6)])
        _ = try await add(store, .task, "Poster brief", values: ["due": day(2)], seen: -9, validTo: at(-3), supersededBy: living)
        let current = await store.searchMap(MapSearchArguments(query: "poster"), now: now)
        XCTAssertEqual(current.components(separatedBy: "\n").count, 1)
        let past = await store.searchMap(MapSearchArguments(query: "poster", past: true), now: now)
        XCTAssertTrue(past.contains("Old version, true until 11 Nov."), past)

        let page = try await add(store, .document, "Brief page", kind: "web page")
        let note = try await add(store, .note, text: "The brief is at https://example.com/brief?token=1")
        try await link(store, note, .about, page)
        let guide = await store.searchMap(MapSearchArguments(query: "brief page"), now: now)
        XCTAssertTrue(guide.contains("https://example.com/brief"))
        let runner = await store.searchMap(MapSearchArguments(query: "brief page"), now: now, forRunner: true)
        XCTAssertFalse(runner.contains("example.com"), runner)
    }

    // MARK: - Ids

    func testAnIdIsNeverHandedOutTwice() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "phew-ids-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        var db = try Database(folder: folder, key: nil, sensitiveKey: nil)
        _ = try db.nextID()
        let top = try db.nextID()
        try db.query("INSERT INTO main.nodes (id, class, origin, confidence, valid_from, created, updated) VALUES (?, 'Topic', 'told', 0.9, 'x', 'x', 'x')", [.int(top)])
        try db.query("DELETE FROM main.nodes WHERE id = ?", [.int(top)])
        XCTAssertEqual(try db.nextID(), top + 1)
        db.close()
        db = try Database(folder: folder, key: nil, sensitiveKey: nil)
        XCTAssertEqual(try db.nextID(), top + 2, "the top row was wiped, its id is still not handed out again")

        // A Map from before the stored counter: the counter starts from the highest stored id.
        try db.query("DELETE FROM main.counter")
        try db.query("INSERT INTO s.events (id, time, kind) VALUES (500, 'x', 'ask')")
        db.close()
        db = try Database(folder: folder, key: nil, sensitiveKey: nil)
        XCTAssertEqual(try db.nextID(), 501)
        db.close()
    }
}
