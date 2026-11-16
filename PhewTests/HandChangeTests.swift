import XCTest
@testable import Phew

/// Made-up Notes and Excel answering Phew's fixed scripts, told apart by which script it is. No osascript, no app.
final class FakeScripts: @unchecked Sendable {
    struct Note: Equatable { var id: String, name: String, body: String, text: String }
    var notes: [Note] = []
    var books: [String] = []
    /// What a range holds, by "book|range".
    var cells: [String: [String]] = [:]
    /// The app writes something other than what was asked: the read-back must catch it.
    var wrongWrite = false
    /// Which scripts ran, by a short name.
    private(set) var ran: [String] = []
    private var next = 0

    func add(_ title: String, _ lines: [String] = []) {
        next += 1
        notes.append(Note(id: "note-\(next)", name: "", body: "", text: ""))
        set(notes.count - 1, AXSurface.html([title] + lines))
    }

    func run(_ source: String, _ args: [String]) -> (HandEnd, String) {
        switch source {
        case HandChanges.findNotes:
            ran.append("find")
            // Notes matches names without case: the exact one is picked in Swift.
            let found = notes.filter { $0.name.lowercased() == args[0].lowercased() }
            return (.done, found.map { "\($0.id)\u{1E}\($0.name)" }.joined(separator: "\u{1F}"))
        case HandChanges.changeNote:
            ran.append("change")
            guard let i = notes.firstIndex(where: { $0.id == args[0] }) else { return (.failed, "") }
            let old = notes[i]
            var seen = wrongWrite ? "still" : "gone"
            if args[1] == "delete" {
                notes.remove(at: i)
            } else {
                if args[1] == "name" {
                    var lines = old.text.components(separatedBy: "\n")
                    lines[0] = wrongWrite ? "Something else" : args[2]
                    set(i, AXSurface.html(lines))
                } else {
                    set(i, wrongWrite ? AXSurface.html(["Something else"]) : args[2])
                }
                seen = "\(notes[i].name)\u{1E}\(notes[i].text)"
            }
            return (.done, "\(old.body)\u{1F}\(old.name)\u{1F}\(seen)")
        case HandChanges.restoreNote:
            ran.append("restore")
            if args[0].isEmpty { add("") }
            guard let i = args[0].isEmpty ? notes.count - 1 : notes.firstIndex(where: { $0.id == args[0] }) else { return (.failed, "") }
            set(i, args[1])
            return (.done, "\(notes[i].id)\u{1E}\(notes[i].name)")
        case HandChanges.workbooks:
            return (.done, books.joined(separator: "\u{1F}"))
        case HandChanges.readCells:
            return (.done, (cells["\(args[0])|\(args[1])"] ?? [""]).joined(separator: "\u{1F}"))
        case AXSurface.fillCells:
            ran.append("fill")
            let values = Array(args.dropFirst(3))
            cells["\(args[0])|\(args[1])"] = wrongWrite ? values.map { $0 + "x" } : values
            return (.done, cells["\(args[0])|\(args[1])"]!.joined(separator: "\u{1F}"))
        default:
            return (.failed, "")
        }
    }

    /// As Notes keeps a body: the name is its first line, the plain text has no tags.
    private func set(_ i: Int, _ body: String) {
        let text = body.replacingOccurrences(of: "<br>", with: "").replacingOccurrences(of: "<div>", with: "")
            .replacingOccurrences(of: "</div>", with: "\n").trimmingCharacters(in: .newlines)
        notes[i].body = body
        notes[i].text = text
        notes[i].name = text.components(separatedBy: "\n")[0]
    }
}

/// Made-up reminders and events in memory: the fake `HandItems`. No EventKit.
final class FakeItems: HandItems, @unchecked Sendable {
    var entries: [HandItem: [HandEntry]] = [:]
    var access = true
    /// The app saves something else, or keeps what it was told to remove: the read-back must catch it.
    var wrongWrite = false
    private var next = 0

    func all(_ kind: HandItem) -> [HandEntry]? { access ? entries[kind] ?? [] : nil }
    func one(_ id: String, _ kind: HandItem) -> HandEntry? { entries[kind]?.first { $0.id == id } }

    func save(_ entry: HandEntry, _ kind: HandItem) -> String? {
        var entry = entry
        if wrongWrite { entry.title += " (not this)" }
        if !entry.id.isEmpty, let i = entries[kind]?.firstIndex(where: { $0.id == entry.id }) {
            entries[kind]![i] = entry
            return entry.id
        }
        next += 1
        entry.id = "\(kind.rawValue)-new-\(next)"
        entries[kind, default: []].append(entry)
        return entry.id
    }

    func remove(_ id: String, _ kind: HandItem) -> Bool {
        guard let i = entries[kind]?.firstIndex(where: { $0.id == id }) else { return false }
        if !wrongWrite { entries[kind]!.remove(at: i) }
        return true
    }
}

/// N2.2 to N2.4 on made-up items: changes and deletes found by their exact title, read back, kept for Undo, and the
/// "cannot be undone" class. Through the real Hand on the fake surface; no app, no osascript, no EventKit.
@MainActor
final class HandChangeTests: XCTestCase {
    private var suite = ""
    private var defaults: UserDefaults!
    private var fake: FakeSurface!
    private var savedLog: URL!
    private var log: URL!
    private let start = Date(timeIntervalSince1970: 2_000_000_000)

    override func setUp() {
        suite = "PhewTests.change.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.set(true, forKey: Hand.allowedKey)
        fake = FakeSurface()
        savedLog = ActionLog.url
        log = FileManager.default.temporaryDirectory.appending(path: "phew-actions-\(UUID().uuidString).log")
        ActionLog.url = log  // never the user's real actions.log
    }

    override func tearDown() {
        ActionLog.flush()
        try? FileManager.default.removeItem(at: log)
        ActionLog.url = savedLog
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }

    private func hand() -> Hand { Hand(defaults: defaults, surface: fake, list: NeverReadList(defaults: defaults)) }
    private func step(_ script: HandScript) -> HandStep { HandStep(kind: .script, pid: 0, script: script) }
    private var changes: HandChanges { HandChanges(script: fake.apps.run, items: fake.items) }

    // MARK: The exact title

    func testOneExactTitleOrNothing() {
        let names = ["Made-up plan", "made-up plan", " Made-up list ", "Made-up list", "Made-up planning"]
        XCTAssertEqual(Hand.one(names, titled: "Made-up plan") { $0 }.0, "Made-up plan")
        XCTAssertEqual(Hand.one(names, titled: " Made-up plan\n") { $0 }.1, .done, "spaces at the ends aside")
        XCTAssertEqual(Hand.one(names, titled: "Made-up list") { $0 }.1, .manyFound)
        XCTAssertEqual(Hand.one(names, titled: "MADE-UP PLAN") { $0 }.1, .notFound, "case kept")
        XCTAssertEqual(Hand.one(names, titled: "Made-up") { $0 }.1, .notFound, "never a part of a title")
        XCTAssertEqual(Hand.one([String](), titled: "Made-up") { $0 }.1, .notFound)
    }

    // MARK: N2.2 Changes, read back

    func testNoteRenameAndBodyAreReadBackAndKept() throws {
        fake.apps.add("Made-up plan", ["First made-up line"])
        fake.apps.add("made-up plan")  // the same but for case: not a match
        var (end, kept) = changes.run(.rename(.note, title: "Made-up plan", to: "Made-up plan two"))
        XCTAssertEqual(end, .done)
        XCTAssertEqual(fake.apps.notes.map(\.name), ["Made-up plan two", "made-up plan"])
        XCTAssertEqual(kept, .note(id: "note-1", title: "Made-up plan", body: "<div>Made-up plan</div><div>First made-up line</div>"))
        (end, kept) = changes.run(.noteBody(title: "Made-up plan two", body: "New made-up line\nLast made-up line"))
        XCTAssertEqual(end, .done)
        XCTAssertEqual(fake.apps.notes[0].text, "Made-up plan two\nNew made-up line\nLast made-up line", "the title stays")
        XCTAssertEqual(kept, .note(id: "note-1", title: "Made-up plan two", body: "<div>Made-up plan two</div><div>First made-up line</div>"))
    }

    func testNoneOrManyChangesNothing() {
        fake.apps.add("Made-up twin")
        fake.apps.add("Made-up twin")
        fake.items.entries[.reminder] = [HandEntry(id: "r1", title: "Made-up call"), HandEntry(id: "r2", title: "Made-up call")]
        XCTAssertEqual(changes.run(.rename(.note, title: "Made-up twin", to: "x")).0, .manyFound)
        XCTAssertEqual(changes.run(.delete(.note, title: "Made-up nothing")).0, .notFound)
        XCTAssertEqual(changes.run(.complete(title: "Made-up call")).0, .manyFound)
        XCTAssertEqual(changes.run(.move(title: "Made-up nothing", start: start, end: nil)).0, .notFound)
        XCTAssertEqual(fake.apps.ran, ["find", "find"], "found, never changed")
        XCTAssertEqual(fake.apps.notes.map(\.name), ["Made-up twin", "Made-up twin"])
        XCTAssertEqual(fake.items.entries[.reminder]?.map(\.done), [false, false])
        fake.items.access = false
        XCTAssertEqual(changes.run(.complete(title: "Made-up call")).0, .noAccess)
    }

    func testReminderEventAndCellChangesAreReadBack() {
        fake.items.entries[.reminder] = [HandEntry(id: "r1", title: "Made-up call", calendar: "list-1")]
        fake.items.entries[.event] = [HandEntry(id: "e1", title: "Made-up review", start: start, end: start + 1800)]
        fake.apps.books = ["Made-up budget.xlsx"]
        fake.apps.cells["Made-up budget.xlsx|B2:C2"] = ["10", "=B2*2"]
        XCTAssertEqual(changes.run(.complete(title: "Made-up call")).0, .done)
        XCTAssertEqual(changes.run(.rename(.reminder, title: "Made-up call", to: "Made-up call later")).0, .done)
        XCTAssertEqual(fake.items.one("r1", .reminder)?.title, "Made-up call later")
        XCTAssertEqual(fake.items.one("r1", .reminder)?.done, true)
        XCTAssertEqual(changes.run(.move(title: "Made-up review", start: start + 86_400, end: nil)).0, .done)
        XCTAssertEqual(fake.items.one("e1", .event)?.end, start + 86_400 + 1800, "it keeps its length")
        let (end, kept) = changes.run(.changeCells(book: "Made-up budget.xlsx", top: "b2", rows: [["12", "13"]]))
        XCTAssertEqual(end, .done)
        XCTAssertEqual(kept, .cells(book: "Made-up budget.xlsx", range: "B2:C2", width: 2, values: ["10", "=B2*2"]))
        XCTAssertEqual(changes.run(.changeCells(book: "made-up budget.xlsx", top: "B2", rows: [["1"]])).0, .notFound, "the exact name")
    }

    func testTheReadBackCatchesAWrongWrite() {
        fake.apps.add("Made-up plan")
        fake.items.entries[.reminder] = [HandEntry(id: "r1", title: "Made-up call")]
        fake.items.entries[.event] = [HandEntry(id: "e1", title: "Made-up review", start: start, end: start + 1800)]
        fake.apps.books = ["Made-up budget.xlsx"]
        fake.apps.cells["Made-up budget.xlsx|A1"] = ["1"]
        fake.apps.wrongWrite = true
        fake.items.wrongWrite = true
        var (end, kept) = changes.run(.rename(.note, title: "Made-up plan", to: "Made-up plan two"))
        XCTAssertEqual(end, .checkFailed)
        XCTAssertNotNil(kept, "it was written: what it held stays kept, for Undo")
        XCTAssertEqual(changes.run(.noteBody(title: "Something else", body: "Made-up")).0, .checkFailed)
        XCTAssertEqual(changes.run(.rename(.reminder, title: "Made-up call", to: "Made-up call later")).0, .checkFailed)
        XCTAssertEqual(changes.run(.delete(.event, title: "Made-up review")).0, .checkFailed, "still there after the delete")
        (end, kept) = changes.run(.changeCells(book: "Made-up budget.xlsx", top: "A1", rows: [["2"]]))
        XCTAssertEqual(end, .checkFailed)
        XCTAssertEqual(kept, .cells(book: "Made-up budget.xlsx", range: "A1", width: 1, values: ["1"]))
    }

    // MARK: N2.3 Delete, and Undo through the Hand

    func testADeletedItemComesBackOnUndo() {
        fake.apps.add("Made-up plan", ["A made-up line"])
        fake.items.entries[.reminder] = [HandEntry(id: "r1", title: "Made-up call", due: DateComponents(year: 2033, month: 5, day: 18),
                                                   notes: "Made-up notes", calendar: "list-1")]
        fake.items.entries[.event] = [HandEntry(id: "e1", title: "Made-up review", start: start, end: start + 1800, location: "Made-up room",
                                                calendar: "cal-1")]
        let hand = hand(), job = hand.begin(watchUser: false)
        for item in [HandItem.note, .reminder, .event] {
            let title = ["note": "Made-up plan", "reminder": "Made-up call", "event": "Made-up review"][item.rawValue]!
            let result = hand.act(step(.delete(item, title: title)), in: job)
            XCTAssertEqual(result, HandResult(end: .done), "kept, so it can be undone: no tag")
        }
        XCTAssertTrue(fake.apps.notes.isEmpty)
        XCTAssertEqual(fake.items.entries[.reminder], [])
        XCTAssertEqual(fake.items.entries[.event], [])
        XCTAssertEqual(job.kept.count, 3)
        hand.close(job)
        XCTAssertEqual(hand.undo(job), .done)
        XCTAssertEqual(fake.apps.notes.map(\.text), ["Made-up plan\nA made-up line"])
        let reminder = fake.items.entries[.reminder]?.first
        XCTAssertEqual([reminder?.title, reminder?.notes, reminder?.calendar], ["Made-up call", "Made-up notes", "list-1"])
        XCTAssertEqual(reminder?.due, DateComponents(year: 2033, month: 5, day: 18))
        let event = fake.items.entries[.event]?.first
        XCTAssertEqual([event?.title, event?.location, event?.calendar], ["Made-up review", "Made-up room", "cal-1"])
        XCTAssertEqual([event?.start, event?.end], [start, start + 1800])
        XCTAssertTrue(job.kept.isEmpty, "Undo takes them once")
        XCTAssertEqual(fake.changed.filter { if case .restore = $0 { true } else { false } }.count, 3, "each put back through the Hand")
    }

    func testAChangedValueIsPutBackNewestFirst() {
        fake.apps.add("Made-up plan", ["A made-up line"])
        fake.items.entries[.reminder] = [HandEntry(id: "r1", title: "Made-up call")]
        fake.items.entries[.event] = [HandEntry(id: "e1", title: "Made-up review", start: start, end: start + 1800)]
        fake.apps.books = ["Made-up budget.xlsx"]
        fake.apps.cells["Made-up budget.xlsx|B2:C2"] = ["10", "=B2*2"]
        let hand = hand(), job = hand.begin(watchUser: false)
        for script in [HandScript.rename(.note, title: "Made-up plan", to: "Made-up plan two"),
                       .noteBody(title: "Made-up plan two", body: "Another made-up line"),
                       .complete(title: "Made-up call"), .move(title: "Made-up review", start: start + 3600, end: start + 7200),
                       .changeCells(book: "Made-up budget.xlsx", top: "B2", rows: [["12", "13"]])] {
            XCTAssertEqual(hand.act(step(script), in: job).end, .done)
        }
        XCTAssertEqual(job.kept.count, 5)
        XCTAssertEqual(hand.undo(job), .done)
        XCTAssertEqual(fake.apps.notes.map(\.text), ["Made-up plan\nA made-up line"], "two changes of one note, back to the first")
        XCTAssertEqual(fake.items.one("r1", .reminder)?.done, false, "un-completed")
        XCTAssertEqual([fake.items.one("e1", .event)?.start, fake.items.one("e1", .event)?.end], [start, start + 1800])
        XCTAssertEqual(fake.apps.cells["Made-up budget.xlsx|B2:C2"], ["10", "=B2*2"])
    }

    func testUndoPassesTheGates() {
        fake.items.entries[.reminder] = [HandEntry(id: "r1", title: "Made-up call")]
        let hand = hand(), job = hand.begin(watchUser: false)
        XCTAssertEqual(hand.act(step(.complete(title: "Made-up call")), in: job).end, .done)
        defaults.set(false, forKey: Hand.allowedKey)  // the menu's switch, off
        XCTAssertEqual(hand.undo(job), .off)
        XCTAssertEqual(fake.items.one("r1", .reminder)?.done, true, "nothing put back with acting off")
    }

    // MARK: N2.4 The class, by code

    func testTheClassIsDecidedByCode() {
        func press(_ name: String) -> HandStep { HandStep(kind: .press, pid: 1, name: name) }
        for name in ["Send", "Invia", "Delete", "Elimina", "Publish", "Pubblica", "Share…", "Condividi", "Don’t Save", "Non salvare",
                     "Replace All", "Sostituisci tutto", "Empty Trash", "Svuota il cestino", "Post", "Cancella"] {
            XCTAssertTrue(NeverList.final(press(name)), name)
        }
        for name in ["Bold", "Grassetto", "Save", "Salva", "Sender details", "Deleted items", "Inviato"] {
            XCTAssertFalse(NeverList.final(press(name)), name)
        }
        XCTAssertTrue(NeverList.final(HandStep(kind: .pick, pid: 1, menuPath: ["File", "Share", "Mail"])))
        XCTAssertFalse(NeverList.final(HandStep(kind: .pick, pid: 1, menuPath: ["Format", "Font", "Bold"])))
        XCTAssertTrue(NeverList.final(HandStep(kind: .set, pid: 1, name: "Title"), replaces: true), "over text already there")
        XCTAssertFalse(NeverList.final(HandStep(kind: .set, pid: 1, name: "Send to"), replaces: false), "into an empty field")
        XCTAssertFalse(NeverList.final(HandStep(kind: .front, pid: 0, name: "Mail")))
        // Scripts: a delete with its way back kept is not, but an agent's always is; guests or a repeat always are.
        let delete = step(.delete(.note, title: "Made-up"))
        XCTAssertFalse(NeverList.final(delete))
        XCTAssertTrue(NeverList.final(delete, agent: true))
        XCTAssertTrue(NeverList.final(step(.delete(.event, title: "Made-up")), facts: HandFacts(guests: true)))
        XCTAssertTrue(NeverList.final(step(.rename(.event, title: "Made-up", to: "x")), facts: HandFacts(guests: true)))
        XCTAssertTrue(NeverList.final(step(.complete(title: "Made-up")), facts: HandFacts(repeats: true)))
        XCTAssertFalse(NeverList.final(step(.rename(.reminder, title: "Made-up", to: "x"))), "kept: undoable")
        for script in [HandScript.rename(.reminder, title: "Made-up", to: "x"), .noteBody(title: "Made-up", body: "x"),
                       .complete(title: "Made-up"), .move(title: "Made-up", start: Date(timeIntervalSince1970: 0), end: nil)] {
            XCTAssertTrue(NeverList.final(step(script), agent: true), "an agent has no Undo: \(script)")
        }
        for script in [HandScript.note(title: "Made-up", body: ""), .changeCells(book: "x", top: "A1", rows: [["1"]]),
                       .restore(.note(id: "", title: "x", body: ""))] {
            XCTAssertFalse(NeverList.final(step(script), agent: true), "\(script)")
        }
    }

    func testAnAgentWaitsAndAWatchedJobRunsTagged() {
        fake.apps.add("Made-up plan")
        fake.items.entries[.event] = [HandEntry(id: "e1", title: "Made-up launch", start: start, end: start + 1800, guests: true)]
        fake.items.entries[.reminder] = [HandEntry(id: "r1", title: "Made-up call")]
        fake.add("Elimina", frame: CGRect(x: 20, y: 20, width: 100, height: 30))
        let hand = hand()
        // An agent: what cannot be undone is not done.
        let agent = hand.begin(watchUser: false, agent: true)
        XCTAssertEqual(hand.act(step(.delete(.note, title: "Made-up plan")), in: agent), HandResult(end: .needsConfirm, final: true))
        for script in [HandScript.rename(.event, title: "Made-up launch", to: "x"), .delete(.reminder, title: "Made-up call")] {
            XCTAssertEqual(hand.act(step(script), in: hand.begin(watchUser: false, agent: true)).end, .needsConfirm)
        }
        var press = HandStep(kind: .press, pid: FakeSurface.pid, role: "AXButton", name: "Elimina", frame: CGRect(x: 20, y: 20, width: 100, height: 30))
        XCTAssertEqual(hand.act(press, in: hand.begin(watchUser: false, agent: true)).end, .needsConfirm)
        XCTAssertEqual(fake.changed, [], "nothing reached the apps")
        XCTAssertEqual(fake.sentCount, 0)
        XCTAssertEqual(fake.apps.notes.count, 1)
        // An agent's plain change waits too: a background task has no card, so no Undo.
        XCTAssertEqual(hand.act(step(.rename(.reminder, title: "Made-up call", to: "Made-up call later")),
                               in: hand.begin(watchUser: false, agent: true)), HandResult(end: .needsConfirm, final: true))
        XCTAssertEqual(fake.changed, [], "nothing reached the apps")
        // The user watches: it runs, tagged; with guests there is no whole way back, so nothing is kept.
        let watched = hand.begin(watchUser: false)
        XCTAssertEqual(hand.act(step(.rename(.event, title: "Made-up launch", to: "Made-up launch two")), in: watched),
                       HandResult(end: .done, final: true))
        XCTAssertTrue(watched.kept.isEmpty)
        press.name = "Elimina"
        let pressed = hand.act(press, in: hand.begin(watchUser: false))
        XCTAssertEqual([pressed.end == .done, pressed.final], [true, true])
        XCTAssertEqual(fake.sentCount, 1)
    }

    func testARenameThenDeleteOfOneItemIsUndoneWithoutACopy() {
        fake.items.entries[.reminder] = [HandEntry(id: "r1", title: "Made-up call")]
        let hand = hand(), job = hand.begin(watchUser: false)
        XCTAssertEqual(hand.act(step(.rename(.reminder, title: "Made-up call", to: "Made-up call later")), in: job).end, .done)
        XCTAssertEqual(hand.act(step(.delete(.reminder, title: "Made-up call later")), in: job).end, .done)
        XCTAssertEqual(hand.undo(job), .done)
        XCTAssertEqual(fake.items.entries[.reminder]?.map(\.title), ["Made-up call"], "made again once, under its first name")
    }

    func testChangeLogLinesHoldNoWords() throws {
        let planted = "Planted Title 4242"
        fake.apps.add(planted, ["Planted body 4242"])
        let hand = hand(), job = hand.begin(watchUser: false)
        XCTAssertEqual(hand.act(step(.rename(.note, title: planted, to: "Planted New 4242")), in: job).end, .done)
        XCTAssertEqual(hand.act(step(.delete(.note, title: "Planted New 4242")), in: job).end, .done)
        XCTAssertEqual(hand.undo(job), .done)
        ActionLog.flush()
        let text = try String(contentsOf: log, encoding: .utf8)
        XCTAssertFalse(text.contains("Planted") || text.contains("4242") || text.contains("note-"), text)
        for line in text.split(separator: "\n") {
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
            XCTAssertEqual(Set(json.keys), ["ts", "job", "step", "kind", "role", "ended", "marked", "ms", "chars"])
            XCTAssertEqual(json["kind"] as? String, "script")
        }
        XCTAssertEqual(text.split(separator: "\n").count, 4, "two changes, two put back")
    }
}
