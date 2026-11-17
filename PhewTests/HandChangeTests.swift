import XCTest
@testable import Phew

/// Made-up Notes and Excel answering Phew's fixed scripts, told apart by which script it is. No osascript, no app.
final class FakeScripts: @unchecked Sendable {
    /// `folder` and `attachments`: what a note made again by script gets or loses, as in Notes (R17).
    struct Note: Equatable { var id: String, name: String, body: String, text: String, folder = "folder-default", attachments = 0 }
    var notes: [Note] = []
    var folders: Set<String> = ["folder-default"]
    /// The script, by its short name, that is cut (Stop or the time limit) after the app took the change (R5).
    var cut: String?
    /// The title each find was given, as the script got it.
    private(set) var found: [String] = []
    var books: [String] = []
    /// What a range holds, by "book|range".
    var cells: [String: [String]] = [:]
    /// The app writes something other than what was asked: the read-back must catch it.
    var wrongWrite = false
    /// Which scripts ran, by a short name.
    private(set) var ran: [String] = []
    private var next = 0

    func add(_ title: String, _ lines: [String] = [], folder: String = "folder-default", attachments: Int = 0) {
        next += 1
        folders.insert(folder)
        notes.append(Note(id: "note-\(next)", name: "", body: "", text: "", folder: folder, attachments: attachments))
        set(notes.count - 1, AXSurface.html([title] + lines))
    }

    /// The user edits a note in Notes after the job.
    func edit(_ i: Int, _ lines: [String]) { set(i, AXSurface.html(lines)) }

    func run(_ source: String, _ args: [String]) -> (HandEnd, String) {
        switch source {
        case HandChanges.findNotes:
            ran.append("find")
            found.append(args[0])
            // Notes matches names without case: the exact one is picked in Swift.
            // With its folder's name and the seconds since it changed: a day per note made before it.
            let found = notes.enumerated().filter { $0.element.name.lowercased() == args[0].lowercased() }
            return (.done, found.map { "\($1.id)\u{1E}\($1.name)\u{1E}\($1.folder)\u{1E}\((notes.count - $0) * 86_400)" }.joined(separator: "\u{1F}"))
        case HandChanges.readNote:
            ran.append("read")
            guard let note = notes.first(where: { $0.id == args[0] }) else { return (.done, "") }
            return (.done, [note.body, note.name, note.folder, note.text].joined(separator: "\u{1F}"))
        case HandChanges.changeNote:
            ran.append("change")
            guard let i = notes.firstIndex(where: { $0.id == args[0] }) else { return (.failed, "") }
            let old = notes[i]
            var seen = wrongWrite ? "still" : "gone"
            if args[1] == "delete" {
                notes.remove(at: i)  // as if Recently Deleted were emptied: Undo makes it again
            } else {
                if args[1] == "name" {
                    var lines = old.text.components(separatedBy: "\n")
                    lines[0] = wrongWrite ? "Something else" : args[2]
                    set(i, AXSurface.html(lines))
                } else if args[1] == "append" {
                    set(i, old.body + (wrongWrite ? AXSurface.html(["Something else"]) : args[2]))
                } else {
                    set(i, wrongWrite ? AXSurface.html(["Something else"]) : args[2])
                }
                seen = "\(notes[i].name)\u{1E}\(notes[i].text)"
            }
            // Cut: the app took the change, the answer never came.
            return cut == "change" ? (.timeout, "") : (.done, seen)
        case HandChanges.restoreNote:
            ran.append("restore")
            var how = "body"
            if args[3] == "again" {
                if let i = notes.firstIndex(where: { $0.id == args[0] }) {
                    notes[i].folder = args[2]
                    how = "moved"
                } else {
                    // Made again: in its folder when it still exists, with no attachment, as Notes' scripting does.
                    add("", folder: folders.contains(args[2]) ? args[2] : "folder-default")
                    how = "made"
                }
            }
            guard let i = how == "made" ? notes.count - 1 : notes.firstIndex(where: { $0.id == args[0] }) else { return (.failed, "") }
            if how != "moved" { set(i, args[1]) }
            return (.done, "\(notes[i].id)\u{1E}\(notes[i].name)\u{1E}\(how)")
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
    /// What EventKit holds but cannot hand over or set (a reminder's flag, subtasks, a location alert), by item id:
    /// kept by a save under the same id, lost by one made again (R13, R17).
    var hidden: [String: Set<String>] = [:]
    /// Ids whose save the app refuses.
    var refuse: Set<String> = []
    var access = true
    /// The app saves something else, or keeps what it was told to remove: the read-back must catch it.
    var wrongWrite = false
    private var next = 0

    func all(_ kind: HandItem) -> [HandEntry]? { access ? entries[kind] ?? [] : nil }
    func one(_ id: String, _ kind: HandItem) -> HandEntry? { entries[kind]?.first { $0.id == id } }

    func save(_ entry: HandEntry, _ kind: HandItem) -> String? {
        var entry = entry
        if refuse.contains(entry.id) { return nil }
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
        if !wrongWrite { entries[kind]!.remove(at: i); hidden[id] = nil }
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
        XCTAssertEqual(kept, .note(id: "note-1", title: "Made-up plan", body: "<div>Made-up plan</div><div>First made-up line</div>",
                                   folder: "folder-default", after: "Made-up plan two\u{1E}Made-up plan two\nFirst made-up line"))
        (end, kept) = changes.run(.noteBody(title: "Made-up plan two", body: "New made-up line\nLast made-up line"))
        XCTAssertEqual(end, .done)
        XCTAssertEqual(fake.apps.notes[0].text, "Made-up plan two\nNew made-up line\nLast made-up line", "the title stays")
        XCTAssertEqual(kept, .note(id: "note-1", title: "Made-up plan two", body: "<div>Made-up plan two</div><div>First made-up line</div>",
                                   folder: "folder-default",
                                   after: "Made-up plan two\u{1E}Made-up plan two\nNew made-up line\nLast made-up line"))
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
        XCTAssertEqual(kept, .cells(book: "Made-up budget.xlsx", range: "B2:C2", width: 2, values: ["10", "=B2*2"], after: ["12", "13"]))
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
        XCTAssertEqual(kept, .cells(book: "Made-up budget.xlsx", range: "A1", width: 1, values: ["1"], after: ["2"]))
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
                       .complete(title: "Made-up"), .move(title: "Made-up", start: Date(timeIntervalSince1970: 0), end: nil),
                       .changeCells(book: "x", top: "A1", rows: [["1"]])] {
            XCTAssertTrue(NeverList.final(step(script), agent: true), "an agent has no Undo: \(script)")
        }
        XCTAssertFalse(NeverList.final(step(.changeCells(book: "x", top: "A1", rows: [["1"]]))), "a watched job keeps what they held")
        for script in [HandScript.note(title: "Made-up", body: ""), .restore(.note(id: "", title: "x", body: ""))] {
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

    // MARK: NA.8: what the user already has (R6)

    /// Lines added to a note already there, named by its exact title: read back, kept, and Undo puts the note back.
    func testAppendToANoteByItsExactTitleAndUndo() {
        fake.apps.add("Made-up groceries", ["Made-up milk"])
        fake.apps.add("made-up groceries", ["Not this one"])  // the same but for case: not a match
        let hand = hand(), job = hand.begin(watchUser: false)
        let append = HandScript.append(text: "Made-up eggs\nMade-up bread", title: "Made-up groceries")
        XCTAssertTrue(append.changes)
        XCTAssertEqual(hand.act(step(append), in: job), HandResult(end: .done))
        XCTAssertEqual(fake.apps.notes.map(\.text), ["Made-up groceries\nMade-up milk\nMade-up eggs\nMade-up bread",
                                                     "made-up groceries\nNot this one"])
        XCTAssertEqual(fake.changed, [append], "a change, not an add: never `run`")
        XCTAssertEqual(job.kept.count, 1)
        XCTAssertEqual(hand.undo(job), .done)
        XCTAssertEqual(fake.apps.notes.map(\.text), ["Made-up groceries\nMade-up milk", "made-up groceries\nNot this one"])
        // None with that title: nothing done. The note this job made is still `append` with no title, an add.
        XCTAssertEqual(changes.run(.append(text: "x", title: "Made-up nothing")).0, .notFound)
        XCTAssertFalse(HandScript.append(text: "x").changes)
        // A wrong write is caught by the read-back.
        fake.apps.wrongWrite = true
        XCTAssertEqual(changes.run(.append(text: "Made-up eggs", title: "Made-up groceries")).0, .checkFailed)
        // An agent's append to a note already there waits for one confirm, as every change; to its own note it does not.
        XCTAssertTrue(NeverList.final(step(append), agent: true))
        XCTAssertFalse(NeverList.final(step(append)))
        XCTAssertFalse(NeverList.final(step(.append(text: "x")), agent: true))
        XCTAssertEqual(hand.act(step(append), in: hand.begin(watchUser: false, agent: true)).end, .needsConfirm)
        // Its title passes the password words, as a change's does.
        XCTAssertEqual(hand.act(step(.append(text: "x", title: "Made-up password list")), in: hand.begin(watchUser: false)).end, .password)
    }

    /// Several items share the title: nothing is changed, and the result lists them (at most 5) by folder and last
    /// change, list and due date, calendar and start. Never in actions.log.
    func testSeveralMatchesChangeNothingAndListTheChoices() throws {
        fake.apps.add("Made-up twin", ["One"], folder: "Made-up Work")
        fake.apps.add("Made-up twin", ["Two"], folder: "Made-up Home")
        let due = DateComponents(year: 2031, month: 3, day: 9)
        fake.items.entries[.reminder] = [HandEntry(id: "r1", title: "Made-up call", due: due, calendarName: "Made-up Errands"),
                                         HandEntry(id: "r2", title: "Made-up call", calendarName: "Made-up Family")]
        fake.items.entries[.event] = (1...7).map { HandEntry(id: "e\($0)", title: "Made-up review", start: start + Double($0) * 86_400,
                                                             end: start + Double($0) * 86_400 + 1800, calendarName: "Made-up Cal \($0)") }
        let hand = hand()
        let note = hand.act(step(.append(text: "Three", title: "Made-up twin")), in: hand.begin(watchUser: false))
        XCTAssertEqual(note.end, .manyFound)
        XCTAssertEqual(note.choices.count, 2)
        XCTAssertTrue(note.choices[0].hasPrefix("the note in “Made-up Work”, last changed "), note.choices[0])
        XCTAssertTrue(note.choices[1].hasPrefix("the note in “Made-up Home”, last changed "), note.choices[1])
        let reminder = hand.act(step(.complete(title: "Made-up call")), in: hand.begin(watchUser: false))
        XCTAssertEqual(reminder.choices, ["the reminder in “Made-up Errands”, due "
                                            + Calendar.current.date(from: due)!.formatted(date: .abbreviated, time: .omitted),
                                          "the reminder in “Made-up Family”, no due date"])
        let event = hand.act(step(.delete(.event, title: "Made-up review")), in: hand.begin(watchUser: false))
        XCTAssertEqual(event.choices.count, 5, "at most 5")
        XCTAssertEqual(event.choices[0], "the event in “Made-up Cal 1” on " + (start + 86_400).formatted(date: .abbreviated, time: .shortened))
        // Nothing changed anywhere.
        XCTAssertEqual(fake.apps.notes.map(\.text), ["Made-up twin\nOne", "Made-up twin\nTwo"])
        XCTAssertEqual(fake.items.entries[.reminder]?.map(\.done), [false, false])
        XCTAssertEqual(fake.items.entries[.event]?.count, 7)
        XCTAssertFalse(fake.apps.ran.contains("change"))
        // One match, or none: no choices.
        XCTAssertEqual(hand.act(step(.complete(title: "Made-up nothing")), in: hand.begin(watchUser: false)).choices, [])
        ActionLog.flush()
        let text = try String(contentsOf: log, encoding: .utf8)
        XCTAssertFalse(text.contains("Made-up") || text.contains("“"), text)
    }

    /// Events are found two years back to five ahead, searched in spans EventKit takes; one two years ahead is moved.
    func testAnEventTwoYearsAheadIsFoundAndMoved() {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let calendar = Calendar.current
        func years(_ n: Int, _ days: Int = 0) -> Date { calendar.date(byAdding: DateComponents(year: n, day: days), to: now)! }
        let window = Hand.eventWindow(now)
        for inside in [years(2), years(-2, 1), years(5, -1), now] { XCTAssertTrue(window.contains(inside), "\(inside)") }
        for outside in [years(-2, -1), years(5, 1), years(6)] { XCTAssertFalse(window.contains(outside), "\(outside)") }
        let spans = Hand.spans(window)
        XCTAssertEqual(spans.count, 7)
        XCTAssertEqual(spans.first?.start, window.start)
        XCTAssertEqual(spans.last?.end, window.end)
        XCTAssertTrue(zip(spans, spans.dropFirst()).allSatisfy { $0.end == $1.start }, "no gap, no overlap")
        XCTAssertTrue(spans.allSatisfy { $0.duration <= 366 * 86_400 }, "under EventKit's four years each")
        // Through the Hand, on made-up events: found two years ahead and moved a day on, then put back.
        let ahead = years(2)
        fake.items.entries[.event] = [HandEntry(id: "e1", title: "Made-up far review", start: ahead, end: ahead + 3600)]
        let hand = hand(), job = hand.begin(watchUser: false)
        XCTAssertEqual(hand.act(step(.move(title: "Made-up far review", start: ahead + 86_400, end: nil)), in: job).end, .done)
        XCTAssertEqual(fake.items.one("e1", .event)?.end, ahead + 86_400 + 3600)
        XCTAssertEqual(hand.undo(job), .done)
        XCTAssertEqual(fake.items.one("e1", .event)?.start, ahead)
    }

    // MARK: NR: Undo after review (R5, R6, R13, R16, R17)

    /// R5: a change cut after Notes took it (Stop, the time limit) still keeps what the note held, for Undo.
    func testACutNoteChangeKeepsWhatItHeld() {
        fake.apps.add("Made-up plan", ["A made-up line"])
        fake.apps.cut = "change"
        let (end, kept) = changes.run(.noteBody(title: "Made-up plan", body: "Another made-up line"))
        XCTAssertEqual(end, .timeout)
        XCTAssertEqual(kept?.id, "note-1", "what it held is kept")
        if case let .note(_, title, body, deleted, _, _)? = kept {
            XCTAssertEqual([title, body], ["Made-up plan", "<div>Made-up plan</div><div>A made-up line</div>"])
            XCTAssertFalse(deleted)
        }
    }

    /// R6: a put-back is not held by the per-minute ceiling: it only puts back what Phew changed.
    func testUndoIsNotHeldByTheMinuteCeiling() {
        fake.items.entries[.reminder] = (1...12).map { HandEntry(id: "r\($0)", title: "Made-up call \($0)") }
        let hand = hand(), job = hand.begin(watchUser: false)
        for n in 1...12 {
            XCTAssertEqual(hand.act(step(.rename(.reminder, title: "Made-up call \(n)", to: "Made-up later \(n)")), in: job).end, .done)
        }
        XCTAssertEqual(hand.undo(job), .done, "24 actions in a minute, yet every one put back")
        XCTAssertEqual(fake.items.entries[.reminder]?.map(\.title), (1...12).map { "Made-up call \($0)" })
    }

    /// R6: an Undo that stops keeps what it did not put back, so a second Undo can.
    func testAFailedUndoKeepsWhatItDidNotPutBack() {
        fake.items.entries[.reminder] = (1...3).map { HandEntry(id: "r\($0)", title: "Made-up call \($0)") }
        let hand = hand(), job = hand.begin(watchUser: false)
        for n in 1...3 {
            XCTAssertEqual(hand.act(step(.rename(.reminder, title: "Made-up call \(n)", to: "Made-up later \(n)")), in: job).end, .done)
        }
        fake.secureInputOn = true  // a password field has the keyboard somewhere
        XCTAssertEqual(hand.undo(job), .secureInput)
        XCTAssertEqual(job.kept.count, 3, "nothing put back, nothing lost")
        fake.secureInputOn = false
        fake.items.refuse = ["r2"]  // newest first: r3 goes back, r2 is refused, r1 is not tried
        XCTAssertEqual(hand.undo(job), .failed)
        XCTAssertEqual(fake.items.entries[.reminder]?.map(\.title), ["Made-up later 1", "Made-up later 2", "Made-up call 3"])
        XCTAssertEqual(job.kept.count, 2)
        fake.items.refuse = []
        XCTAssertEqual(hand.undo(job), .done)
        XCTAssertEqual(fake.items.entries[.reminder]?.map(\.title), (1...3).map { "Made-up call \($0)" })
        XCTAssertTrue(job.kept.isEmpty)
    }

    /// R16: what the user changed after the job is left as it is, and the card says so; the rest is put back.
    func testUndoLeavesWhatTheUserChangedSince() {
        fake.apps.add("Made-up plan", ["A made-up line"])
        fake.items.entries[.reminder] = [HandEntry(id: "r1", title: "Made-up call")]
        fake.items.entries[.event] = [HandEntry(id: "e1", title: "Made-up review", start: start, end: start + 1800)]
        fake.apps.books = ["Made-up budget.xlsx"]
        fake.apps.cells["Made-up budget.xlsx|B2:C2"] = ["10", "20"]
        let hand = hand(), job = hand.begin(watchUser: false)
        for script in [HandScript.rename(.note, title: "Made-up plan", to: "Made-up plan two"),
                       .rename(.reminder, title: "Made-up call", to: "Made-up call later"),
                       .move(title: "Made-up review", start: start + 3600, end: nil),
                       .changeCells(book: "Made-up budget.xlsx", top: "B2", rows: [["12", "13"]])] {
            XCTAssertEqual(hand.act(step(script), in: job).end, .done)
        }
        // The user works on three of them after the job.
        fake.apps.edit(0, ["Made-up plan two", "A line the user added"])
        fake.items.entries[.reminder]![0].notes = "A made-up note of the user's"
        fake.apps.cells["Made-up budget.xlsx|B2:C2"] = ["12", "99"]
        let undo = hand.restore(job)
        XCTAssertEqual(undo, HandUndo(end: .done, changedSince: 3))
        XCTAssertEqual(undo.lines, [HandUndo.changedSinceLine])
        XCTAssertEqual(fake.apps.notes[0].text, "Made-up plan two\nA line the user added")
        XCTAssertEqual(fake.items.one("r1", .reminder)?.title, "Made-up call later")
        XCTAssertEqual(fake.items.one("r1", .reminder)?.notes, "A made-up note of the user's")
        XCTAssertEqual(fake.apps.cells["Made-up budget.xlsx|B2:C2"], ["12", "99"])
        XCTAssertEqual(fake.items.one("e1", .event)?.start, start, "the untouched one is put back")
    }

    /// R13, R17: a deleted item comes back with all its app lets be set (alerts, priority, link, folder), and the card
    /// says what cannot come back. The fakes lose what EventKit and Notes lose.
    func testADeletedItemComesBackWholeAndTheRestIsSaid() throws {
        let link = try XCTUnwrap(URL(string: "https://example.com/made-up"))
        let reminder = HandEntry(id: "r1", title: "Made-up call", due: DateComponents(year: 2033, month: 5, day: 18, hour: 10),
                                 notes: "Made-up notes", calendar: "list-1",
                                 alarms: [HandAlarm(date: start), HandAlarm(offset: -600)], priority: 1, url: link)
        let event = HandEntry(id: "e1", title: "Made-up review", start: start, end: start + 1800, location: "Made-up room",
                              calendar: "cal-1", alarms: [HandAlarm(offset: -900)], url: link)
        fake.items.entries[.reminder] = [reminder]
        fake.items.entries[.event] = [event]
        fake.items.hidden = ["r1": ["flag", "subtasks"], "e1": ["attachment"]]
        fake.apps.add("Made-up plan", ["A made-up line"], folder: "folder-work", attachments: 1)
        let hand = hand(), job = hand.begin(watchUser: false)
        for (item, title) in [(HandItem.note, "Made-up plan"), (.reminder, "Made-up call"), (.event, "Made-up review")] {
            XCTAssertEqual(hand.act(step(.delete(item, title: title)), in: job).end, .done)
        }
        let undo = hand.restore(job)
        XCTAssertEqual(undo.end, .done)
        XCTAssertEqual(Set(undo.lost), Set([HandUndo.lost(.note), HandUndo.lost(.reminder), HandUndo.lost(.event)]))
        let back = try XCTUnwrap(fake.items.entries[.reminder]?.first)
        var want = reminder
        want.id = back.id
        XCTAssertEqual(back, want, "alerts, priority and link come back")
        let backEvent = try XCTUnwrap(fake.items.entries[.event]?.first)
        want = event
        want.id = backEvent.id
        XCTAssertEqual(backEvent, want)
        XCTAssertNil(fake.items.hidden[back.id], "made again: what EventKit cannot set is gone, and the card said so")
        XCTAssertEqual(fake.apps.notes.map(\.folder), ["folder-work"], "back in its folder")
        XCTAssertEqual(fake.apps.notes.map(\.attachments), [0])
    }
}
