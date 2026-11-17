import AppKit
import ApplicationServices
import Carbon.HIToolbox
import EventKit

/// One action Phew is asked to make, as the look saw its target. Coordinates are Accessibility ones (top-left origin).
struct HandStep: Sendable {
    /// Fixed words, also written to actions.log.
    enum Kind: String, Sendable, CaseIterable {
        /// AXPress on a named control.
        case press
        /// Set the value of a field: the text goes in through Accessibility, never as key presses.
        case set
        /// A menu bar item, by its path ("Format", "Font", "Bold").
        case pick
        /// One click at the centre of `frame`, only where no named control exists (a canvas). No drag.
        case click
        /// The app's own scripting or the system's reminders and calendar access (`script`), behind the app.
        case script
        /// Brings the app `app` to the front for the job (docs/13-hand.md 13.4, 7); `Hand.back` returns at its end.
        case front
        /// R1 (NA.5): two clicks at the centre of `frame`, as one double click.
        case doubleClick
        /// One click of the second button: the control's context menu opens.
        case rightClick
        /// The wheel, `amount` lines (down positive), at the centre of `frame`.
        case scroll
        /// The mouse down at the centre of `frame`, moved to `to`, up there: inside one window of the job's app.
        case drag
        /// A key or shortcut (`chord`), or `text` typed through keys, posted to the job's app only.
        case keys

        /// The kinds that may land on a bare point with no control under it (a canvas).
        var pointed: Bool { [.click, .doubleClick, .rightClick, .scroll, .drag].contains(self) }
    }

    var kind: Kind
    /// The app acted in.
    var pid: pid_t
    /// The control as the look saw it: role, name and frame. For `click` on a bare canvas, role and name may be
    /// empty and `frame` a zero-size rect at the point.
    var role = ""
    var name = ""
    var frame = CGRect.zero
    /// For `pick`: the menu path from the menu bar.
    var menuPath: [String] = []
    /// For `set`: what goes in. Held in memory only, never logged.
    var text = ""
    /// The job calls for a window or sheet after this step (a Save dialog): the next step takes it as expected.
    var opensWindow = false
    /// For `script`: what it makes. Held in memory only, never logged.
    var script: HandScript? = nil
    /// For `front`: the bundle id of the app brought to the front (`name` is its plain name, for the card). Never logged.
    var app = ""
    /// For `keys`: the key or shortcut; nil when `text` is typed instead. Never logged.
    var chord: HandChord? = nil
    /// For `scroll`: lines, down positive.
    var amount = 0
    /// For `drag`: where it ends, Accessibility coordinates.
    var to: CGPoint? = nil
}

/// A key, alone or with modifiers, named from a fixed vocabulary (NA.5). Built only by `parse`, so no word of the
/// model's ever becomes an event. There is no fn or globe key: it is not in the vocabulary, so it is never sent.
struct HandChord: Sendable, Hashable {
    enum Modifier: String, CaseIterable, Sendable { case control, option, shift, cmd }
    let key: String
    let modifiers: Set<Modifier>

    /// Key names and their virtual key codes.
    // shortcut: letters and digits at their US positions; on a layout that moves them (AZERTY) a shortcut may land on
    // another letter. Map through the keyboard layout if a live run shows the need.
    static let codes: [String: Int] = {
        var codes = ["a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D, "e": kVK_ANSI_E, "f": kVK_ANSI_F,
                     "g": kVK_ANSI_G, "h": kVK_ANSI_H, "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
                     "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P, "q": kVK_ANSI_Q, "r": kVK_ANSI_R,
                     "s": kVK_ANSI_S, "t": kVK_ANSI_T, "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
                     "y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
                     "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3, "4": kVK_ANSI_4, "5": kVK_ANSI_5,
                     "6": kVK_ANSI_6, "7": kVK_ANSI_7, "8": kVK_ANSI_8, "9": kVK_ANSI_9,
                     "return": kVK_Return, "tab": kVK_Tab, "space": kVK_Space, "escape": kVK_Escape, "delete": kVK_Delete,
                     "forwarddelete": kVK_ForwardDelete, "up": kVK_UpArrow, "down": kVK_DownArrow, "left": kVK_LeftArrow,
                     "right": kVK_RightArrow]
        for (n, code) in [kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12].enumerated() {
            codes["f\(n + 1)"] = code
        }
        return codes
    }()

    /// "cmd+B", "shift+tab", "return": one key name from `codes`, after modifiers, each once, joined by "+". Any case.
    /// Nil for anything else.
    static func parse(_ text: String) -> HandChord? {
        let aliases = ["command": "cmd", "ctrl": "control", "opt": "option", "alt": "option"]
        let parts = text.lowercased().split(separator: "+", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        guard let key = parts.last, codes[key] != nil else { return nil }
        var modifiers = Set<Modifier>()
        for part in parts.dropLast() {
            guard let modifier = Modifier(rawValue: aliases[part] ?? part), modifiers.insert(modifier).inserted else { return nil }
        }
        return HandChord(key: key, modifiers: modifiers)
    }

    /// As a Mac menu shows it, for the card: "⌘B", "⇧⇥".
    var symbols: String {
        let marks: [Modifier: String] = [.control: "⌃", .option: "⌥", .shift: "⇧", .cmd: "⌘"]
        let names = ["return": "↩", "tab": "⇥", "space": "Space", "escape": "⎋", "delete": "⌫", "forwarddelete": "⌦",
                     "up": "↑", "down": "↓", "left": "←", "right": "→"]
        return Modifier.allCases.filter(modifiers.contains).compactMap { marks[$0] }.joined() + (names[key] ?? key.uppercased())
    }

    var flags: CGEventFlags {
        let each: [Modifier: CGEventFlags] = [.control: .maskControl, .option: .maskAlternate, .shift: .maskShift, .cmd: .maskCommand]
        return modifiers.reduce(into: CGEventFlags()) { $0.insert(each[$1]!) }
    }
}

/// The things a change or delete names by their exact title (N2.2).
enum HandItem: String, Sendable, Equatable {
    case note, reminder, event

    var app: String {
        switch self {
        case .note: "com.apple.Notes"
        case .reminder: "com.apple.reminders"
        case .event: "com.apple.iCal"
        }
    }
}

/// What a script makes or changes in Notes, Reminders, Calendar or Excel (docs/13-hand.md 13.2, methods 3 and 4). It
/// works behind the app: nothing is clicked, nothing comes to the front. Each is read back after.
/// A change or delete names its target by its exact title: none, or more than one, and nothing is done (`notFound`,
/// `manyFound`). What it replaces is kept in the job (`HandKept`), so Undo puts it back.
enum HandScript: Sendable, Equatable {
    /// Notes: a new note in the default folder, `title` its first line.
    case note(title: String, body: String)
    /// Notes: lines added at the end of the note this job made; with a `title`, of the note already there with that
    /// exact title (R6): then a change, kept for Undo.
    case append(text: String, title: String = "")
    /// Reminders, through EventKit: a new reminder in the default list. `due` with or without a time.
    case reminder(title: String, due: DateComponents?)
    /// Calendar, through EventKit: a new event, no guests, in the default calendar.
    case event(title: String, start: Date, end: Date)
    /// Excel: a new empty workbook.
    case workbook
    /// Excel: cells of the workbook this job made, from `top` ("B2") right and down, as typed (a leading = is a formula).
    case cells(top: String, rows: [[String]])
    /// The note, reminder or event titled `title` gets the title `to`.
    case rename(HandItem, title: String, to: String)
    /// Notes: the lines under the note's title replaced by `body`; the title stays.
    case noteBody(title: String, body: String)
    /// Reminders: ticked done.
    case complete(title: String)
    /// Calendar: moved to `start`; with no `end` it keeps its length.
    case move(title: String, start: Date, end: Date?)
    /// Excel: cells of the open workbook named `book` written over, from `top`, as typed.
    case changeCells(book: String, top: String, rows: [[String]])
    /// Deletes the note, reminder or event titled `title`.
    case delete(HandItem, title: String)
    /// Undo: puts back what a change or delete replaced.
    case restore(HandKept)

    /// The app it acts in, for the Never list.
    var app: String {
        switch self {
        case .note, .append, .noteBody: "com.apple.Notes"
        case .reminder, .complete: "com.apple.reminders"
        case .event, .move: "com.apple.iCal"
        case .workbook, .cells, .changeCells: "com.microsoft.Excel"
        case let .rename(item, _, _), let .delete(item, _): item.app
        case let .restore(kept): kept.app
        }
    }

    /// Characters written, for actions.log.
    var chars: Int {
        switch self {
        case let .note(title, body): title.count + body.count
        case let .append(text, _), let .rename(_, _, text), let .noteBody(_, text): text.count
        case let .reminder(title, _), let .event(title, _, _): title.count
        case .workbook, .complete, .move, .delete, .restore: 0
        case let .cells(_, rows), let .changeCells(_, _, rows): rows.joined().reduce(0) { $0 + $1.count }
        }
    }

    /// Undo's put-back.
    var restores: Bool { if case .restore = self { true } else { false } }

    /// A change, delete or restore of what exists: run by `HandSurface.change`, not `run`.
    var changes: Bool {
        switch self {
        case let .append(_, title): !title.isEmpty
        case .note, .reminder, .event, .workbook, .cells: false
        default: true
        }
    }

    /// The titles it makes or names, for the Never words (F3). Not Undo's put-back: it brings back what was there.
    var titles: [String] {
        switch self {
        case let .note(title, _), let .reminder(title, _), let .event(title, _, _), let .noteBody(title, _),
             let .complete(title), let .move(title, _, _), let .delete(_, title): [title]
        case let .rename(_, title, to): [title, to]
        case let .changeCells(book, _, _): [book]
        case let .append(_, title): title.isEmpty ? [] : [title]
        case .workbook, .cells, .restore: []
        }
    }

    /// The item a change or delete names, by kind and exact title; nil for the rest.
    var target: (HandItem, String)? {
        switch self {
        case let .rename(item, title, _), let .delete(item, title): (item, title)
        case let .noteBody(title, _): (.note, title)
        case let .append(_, title) where !title.isEmpty: (.note, title)
        case let .complete(title): (.reminder, title)
        case let .move(title, _, _): (.event, title)
        default: nil
        }
    }
}

/// Something a script made, by the id the app gave back at creation. Memory only.
struct HandMade: Sendable, Equatable {
    /// A fixed word: note, reminder, event, workbook.
    var kind: String
    var id: String
    var title = ""
}

/// A reminder or an event as plain values: what a change reads, keeps and writes back. Memory only.
struct HandEntry: Sendable, Equatable {
    /// The app's id; empty for one not made yet.
    var id = ""
    var title = ""
    /// Reminders.
    var done = false
    var due: DateComponents?
    /// Events.
    var start: Date?
    var end: Date?
    var allDay = false
    var location: String?
    var notes: String?
    /// The list or calendar it is in, by id, to make it again in the same place.
    var calendar = ""
    /// That list's or calendar's name, for the choices shown when several items share a title (R6). Card only.
    var calendarName = ""
    /// What the "cannot be undone" class needs: invitations go out, a repeat cannot be put back whole.
    var guests = false
    var repeats = false
    /// What a deleted one gets back on Undo too (R17): its alerts by time, its priority (reminders) and its web link.
    var alarms: [HandAlarm] = []
    var priority = 0
    var url: URL?
}

/// An alert of a reminder or event: at a date, or an offset in seconds from its due time or start. Location alerts
/// are not kept (`HandUndo.lost`).
struct HandAlarm: Sendable, Equatable {
    var date: Date?
    var offset: TimeInterval = 0
}

/// What Undo did, for the card: how it ended, the items it left because they changed since the job (R16), and what
/// an item deleted and made again cannot bring back (R17), in fixed words.
struct HandUndo: Sendable, Equatable {
    var end: HandEnd
    var changedSince = 0
    var lost: [String] = []

    static let changedSinceLine = "Something I changed was changed again since, so I left it as it is now."

    /// What EventKit and Notes' scripting cannot set on an item made again.
    static func lost(_ item: HandItem) -> String {
        switch item {
        case .note: "A deleted note comes back without its pictures and attachments."
        case .reminder: "A deleted reminder comes back without its flag, tags, subtasks, pictures and location alerts."
        case .event: "A deleted event comes back without its attachments, travel time and location alerts."
        }
    }

    /// The card's lines beside "Put back as it was." or the reason it stopped.
    var lines: [String] { (changedSince > 0 ? [Self.changedSinceLine] : []) + lost }
}

/// What a change or delete replaced, kept in its job so Undo puts it back (N2.3). Memory only: never written to disk
/// or a log, dropped with the job.
/// Each also holds what the job left (`after`), so Undo puts nothing back over a later edit of the user's (R16); nil
/// when the change was cut before its read-back.
enum HandKept: Sendable, Equatable {
    /// A note's body as Notes' HTML, and its title for the read-back. `deleted`: Undo makes it again, in `folder`.
    /// `after`: its name and plain text as the job left them.
    case note(id: String, title: String, body: String, deleted: Bool = false, folder: String = "", after: String? = nil)
    case entry(HandItem, HandEntry, deleted: Bool = false, after: HandEntry? = nil)
    /// What the cells held, row by row, as typed; `after`, what the job wrote there.
    case cells(book: String, range: String, width: Int, values: [String], after: [String]? = nil)

    var app: String {
        switch self {
        case .note: HandItem.note.app
        case let .entry(item, _, _, _): item.app
        case .cells: "com.microsoft.Excel"
        }
    }

    /// The item's id in its app; nil for cells.
    var id: String? {
        switch self {
        case let .note(id, _, _, _, _, _): id
        case let .entry(_, entry, _, _): entry.id
        case .cells: nil
        }
    }

    /// What a deleted item made again cannot bring back, in fixed words (R17); nil for a change.
    var lost: String? {
        switch self {
        case let .note(_, _, _, deleted, _, _): deleted ? HandUndo.lost(.note) : nil
        case let .entry(item, _, deleted, _): deleted ? HandUndo.lost(item) : nil
        case .cells: nil
        }
    }

    /// A note's, with what the job left: its name and plain text read back.
    func after(_ seen: String) -> HandKept {
        guard case let .note(id, title, body, deleted, folder, _) = self else { return self }
        return .note(id: id, title: title, body: body, deleted: deleted, folder: folder, after: seen)
    }

    /// The same, for the item now under `id`: one deleted and made again by Undo has a new id, and holds what it held.
    func with(id: String) -> HandKept {
        switch self {
        case let .note(_, title, body, deleted, folder, after):
            return .note(id: id, title: title, body: body, deleted: deleted, folder: folder, after: after)
        case let .entry(item, entry, deleted, after):
            var entry = entry
            entry.id = id
            return .entry(item, entry, deleted: deleted, after: after.map { var a = $0; a.id = id; return a })
        case .cells: return self
        }
    }
}

/// What the code reads of an item before changing or deleting it, for the "cannot be undone" class.
struct HandFacts: Sendable, Equatable {
    var guests = false
    var repeats = false
    /// Before a put-back (R16): the item no longer holds what the job left, or it already holds what it held again.
    var changedSince = false
    var unchanged = false
}

/// How an action ended: `done`, or why not, in one fixed word (written to actions.log as is).
enum HandEnd: String, Sendable, CaseIterable {
    case done
    /// Acting is not allowed (the switch is off).
    case off
    /// The Never list (NeverList).
    case secureField, secureInput, neverReadApp, neverActApp, ownApp, password, paying, signIn
    /// A shortcut on the fixed never-send list (`NeverList.neverSend`): quit, log out, lock, force quit, empty the
    /// Trash, or one that leaves the app.
    case neverKeys
    /// The runaway brake. `minuteCeiling` no longer ends a job: the Hand pauses until the minute has room (R5).
    case jobCeiling, minuteCeiling
    /// Not as the look saw it: nothing there now, something else there, a window the job did not call for, another
    /// app in front.
    case gone, moved, surprise, frontChanged
    /// The app refused, did not answer within `timeout`, or the read-back does not show the change.
    case failed, timeout, checkFailed
    /// macOS has not let Phew script that app or use reminders or the calendar.
    case noAccess
    /// Stop, or the user's own click or key.
    case stopped, userInput
    /// A change or delete: no item has that exact title, or more than one has. Nothing was done, nothing guessed.
    case notFound, manyFound
    /// An agent's action that cannot be undone or leaves the Mac: not done, it waits in the menu bar for one confirm.
    case needsConfirm
}

struct HandResult: Equatable, Sendable {
    var end: HandEnd
    /// The code could not judge it by words (no name, a language with no word list): shown with a mark on the card.
    var marked = false
    /// In the "cannot be undone or leaves your Mac" class (`NeverList.final`): tagged on the card.
    var final = false
    /// A put-back of Undo left the item as it is: it was changed again since the job (R16).
    var left = false
    /// `manyFound`: the items that share the title, at most 5, in plain words (R6). Built from the user's own items:
    /// for the card only, never a log.
    var choices: [String] = []
}

/// One job: the steps of one request. Ends once, for good: on Stop, on the user's own input, or on the first step
/// that does not end `done`. Every later step then returns that end without acting, so nothing is ever retried.
final class HandJob: @unchecked Sendable {  // state under `lock`
    let number: Int
    private let lock = NSLock()
    private var ended: HandEnd?
    fileprivate var steps = 0
    /// Actions made, for the per-job ceiling; an agent's task carries it from one job to the next (F3). Written under
    /// the Hand's `acting`; read once the job is closed.
    fileprivate(set) var acted = 0
    fileprivate var dialogs: [pid_t: Int] = [:]
    fileprivate var windowExpected = false
    fileprivate var monitors: [Any] = []
    /// The user's own mouse and keys are watched (`Hand.begin(watchUser:)`), until `Hand.close`.
    var watching: Bool { !monitors.isEmpty }
    /// What this job's scripts made, oldest first: `append` and `cells` act only on these.
    fileprivate(set) var made: [HandMade] = []
    /// The app the job began in: where the user was, and where `Hand.back` returns at the end.
    let start: pid_t
    /// That app's focused window when the job began (N2.8), so `Hand.back` returns to it, not only to the app. An
    /// opaque handle: nothing of it is read. Memory only, gone with the job.
    fileprivate var window: AnyObject?
    private var current: pid_t  // under `lock`
    /// A research agent's job (PA.4), not one the user watches: what cannot be undone waits for a confirm.
    let agent: Bool
    private var keptValues: [HandKept] = []  // under `lock`
    /// R5: told true when the Hand pauses at the minute ceiling and false when it goes on, off the main thread. Set
    /// once by the caller before the first action.
    var pausing: ((Bool) -> Void)?

    fileprivate init(number: Int, app: pid_t, agent: Bool = false) {
        self.number = number
        start = app
        current = app
        self.agent = agent
    }

    var end: HandEnd? { lock.withLock { ended } }

    /// What this job's changes and deletes replaced, oldest first, for Undo. Memory only, gone with the job.
    var kept: [HandKept] { lock.withLock { keptValues } }
    fileprivate func keep(_ old: HandKept) { lock.withLock { keptValues.append(old) } }
    /// Undo takes them once.
    fileprivate func takeKept() -> [HandKept] { lock.withLock { defer { keptValues = [] }; return keptValues } }

    /// The app the job works in now: where it began, then each app the Hand brought to the front (PH.7).
    var app: pid_t { lock.withLock { current } }
    fileprivate func moved(to pid: pid_t) { lock.withLock { current = pid } }

    /// The card's Stop or the shortcut. Takes effect before the next action; the one in flight is cut by `Hand.timeout`.
    func stop() { finish(.stopped) }

    /// A mouse or key event seen while the job runs, and the app it lands in (nil: not known, counted as his app).
    /// The user's own in the app he works in ends the job; in another app it does not (the user's word, PH.7): if
    /// that app comes to the front, the next action stops on `frontChanged`. Phew's own clicks carry `Hand.mark`.
    /// Not while a script runs: it works behind the app, so the user's clicks cannot race it, and the click that
    /// answers macOS's one-time "Phew wants to…" question must not end the job it was asked for (measured, PH.6).
    func seen(_ event: CGEvent, in pid: pid_t?) {
        guard !Hand.isOwn(event) else { return }
        lock.withLock {
            if !scripting, pid == nil || pid == current, ended == nil { ended = .userInput }
        }
    }

    fileprivate var scripting = false  // under `lock`
    fileprivate func script(_ on: Bool) { lock.withLock { scripting = on } }

    fileprivate func finish(_ end: HandEnd) { lock.withLock { if ended == nil { ended = end } } }
}

/// What the Hand reads and acts through. The real one is `AXSurface`; unit tests give a fake.
protocol HandSurface {
    func frontPID() -> pid_t?
    func bundleID(_ pid: pid_t) -> String?
    func secureInput() -> Bool
    func focusedIsSecure(_ pid: pid_t) -> Bool
    /// The element of app `pid` at `point` now, or the menu item at `path`. Opaque to the Hand.
    func element(at point: CGPoint, pid: pid_t) -> AnyObject?
    func menuItem(_ path: [String], pid: pid_t) -> AnyObject?
    func read(_ element: AnyObject) -> HandSeen?
    /// The element with the keyboard focus in app `pid`, as a handle; nil when none. Reading only (NA.5).
    func focused(_ pid: pid_t) -> AnyObject?
    /// Whether `element` is the default button of the sheet or dialog it sits in. Reading only (F4).
    func isDefault(_ element: AnyObject) -> Bool
    /// Sheets and dialogs the app shows now.
    func dialogs(_ pid: pid_t) -> Int
    /// The action itself, once. Returns done, failed or timeout.
    func send(_ step: HandStep, to element: AnyObject?) -> HandEnd
    /// A script, once, then read back. `made`: what this job made before. Ends `stopped` as soon as `stop` says so.
    /// Returns how it ended and, when it made something, what.
    func run(_ script: HandScript, made: [HandMade], stop: @escaping () -> Bool) -> (HandEnd, HandMade?)
    /// Before a change or delete, reading only: what the class needs of the one item it names (guests, a repeat).
    func facts(_ script: HandScript) -> HandFacts
    /// A change, delete or restore (`HandScript.changes`), once, then read back. Returns how it ended and what it
    /// replaced, for Undo.
    func change(_ script: HandScript, stop: @escaping () -> Bool) -> (HandEnd, HandKept?)
    /// After `manyFound`, reading only: the items that share the title, in plain words, at most 5 (R6).
    func choices(_ script: HandScript) -> [String]
    /// The app whose window or menu is at `point` (where a click lands), nil when not known. Reads only the owner.
    func owner(at point: CGPoint) -> pid_t?
    /// The app with this bundle id, when it runs.
    func running(_ bundleID: String) -> pid_t?
    /// Brings the app to the front, launching it if needed, and waits until it is in front, or `stop`, at most
    /// `Hand.frontTimeout`. Returns how it ended and the app's pid.
    func activate(_ bundleID: String, stop: @escaping () -> Bool) -> (HandEnd, pid_t?)
    /// The app's focused window now, as a handle; nil when it has none. Reads nothing of it (N2.8).
    func focusedWindow(_ pid: pid_t) -> AnyObject?
    /// Raises that window in its app, once; false when it is gone or refused.
    func raise(_ window: AnyObject) -> Bool
}

extension HandSurface {
    func focusedWindow(_ pid: pid_t) -> AnyObject? { nil }
    func raise(_ window: AnyObject) -> Bool { false }
    func focused(_ pid: pid_t) -> AnyObject? { nil }
    func isDefault(_ element: AnyObject) -> Bool { false }
    func choices(_ script: HandScript) -> [String] { [] }
}

/// An element as read at the moment of acting. `value` is never read from a secure field.
struct HandSeen: Equatable {
    var role = "", subrole = "", name = ""
    var frame: CGRect?
    var value: String?
}

/// The one acting function (docs/13-hand.md 13.6). Every action Phew makes in another app goes through `act`, and
/// nothing else in the app may send one: `HandTests.testOnlyHandActs` fails the build otherwise.
/// Each action, in order: the off switch, the Never list, the ceilings, what is there now against what the look saw,
/// the action, the log. One try only.
final class Hand: @unchecked Sendable {  // mutable state under `lock`
    static let shared = Hand()
    /// The switch the consent screen turns on (PH.5). Off when never set.
    static let allowedKey = "handAllowed"
    /// The runaway brake (13.9 a, first proposal).
    static let perJob = 40
    static let perMinute = 20
    /// The most text one `keys` step types (NA.5), and the most lines one `scroll` step turns.
    static let mostTyped = 2_000
    static let mostScroll = 50
    /// The longest Phew waits for an app to take one action: Stop then still ends the job within a second.
    static let timeout: Float = 0.5
    /// The longest a script may take. Long enough for macOS's one-time "Phew wants to control…" question and an app's
    /// cold start; Stop still ends the job within a second (the script is cut, though the app may finish what it got).
    static let scriptTimeout: TimeInterval = 60
    /// The longest an app may take to come to the front, a cold launch included. Stop still ends the wait at once.
    static let frontTimeout: TimeInterval = 30
    /// A target whose frame moved more than this, in points, is no longer where the look saw it.
    static let tolerance: CGFloat = 4
    /// Written into every event Phew posts, so the user's own clicks and keys are told apart from his.
    static let mark: Int64 = 0x5048_4557  // "PHEW"

    private let defaults: UserDefaults
    private let surface: HandSurface
    private let list: NeverReadList
    private let ownPID: pid_t
    private let now: () -> Date
    /// The pause's wait (R5): never on the main thread. Tests advance their clock instead.
    private let sleep: (TimeInterval) -> Void
    /// Only the job counter and `ranHere`: never held while an app or a script works, so `begin` on the main thread
    /// never waits for an action (R30).
    private let lock = NSLock()
    /// One action at a time, held for the whole action (a script up to `scriptTimeout`). Never taken on the main thread.
    private let acting = NSLock()
    private var recent: [Date] = []  // under `acting`
    private var jobs = 0
    #if DEBUG
    /// Every script run in this process, how it ended and what it made: for the live tests' report and clean-up
    /// (`removeTestItems`). Memory only.
    private(set) var ranHere: [(script: HandScript, end: HandEnd, made: HandMade?)] = []
    #endif

    /// Tests pass a throwaway defaults suite, a fake surface or clock, and may stand in for Phew's own pid.
    init(defaults: UserDefaults = .standard, surface: HandSurface = AXSurface(), list: NeverReadList = .shared,
         ownPID: pid_t = getpid(), now: @escaping () -> Date = Date.init,
         sleep: @escaping (TimeInterval) -> Void = { Thread.sleep(forTimeInterval: $0) }) {
        self.defaults = defaults
        self.surface = surface
        self.list = list
        self.ownPID = ownPID
        self.now = now
        self.sleep = sleep
    }

    /// On unless the menu's switch turned it off (the user's word of 15 November: no Allow to press).
    var allowed: Bool { defaults.object(forKey: Self.allowedKey) as? Bool ?? true }

    /// Starts a job in `app`, the app the user asked in. With `watchUser`, the user's own mouse down or key down in
    /// the app the job works in ends it (`seen`). `agent`: a research agent's job, in the background. `counted`: the
    /// actions its task already made in earlier jobs, so one task never passes the per-job ceiling (F3).
    @MainActor
    func begin(watchUser: Bool = true, in app: pid_t = 0, agent: Bool = false, counted: Int = 0) -> HandJob {
        let job = lock.withLock { jobs += 1; return HandJob(number: jobs, app: app, agent: agent) }
        job.acted = counted
        if app != 0 { job.window = surface.focusedWindow(app) }
        if watchUser {
            if let global = NSEvent.addGlobalMonitorForEvents(matching: Self.userEvents, handler: { [weak self, weak job] in
                if let e = $0.cgEvent, let job { self?.seen(e, by: job) }
            }) { job.monitors.append(global) }
        }
        return job
    }

    /// What of the user's ends a job: a click, either button, or a key.
    static let userEvents: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .keyDown]

    /// The user's own event, with the app it lands in: a key in the front app, a click in the app under it.
    func seen(_ event: CGEvent, by job: HandJob) {
        guard !Self.isOwn(event) else { return }
        job.seen(event, in: event.type == .keyDown ? surface.frontPID() : surface.owner(at: event.location))
    }

    /// Ends the job and its watch. A step after this returns `stopped`.
    @MainActor
    func close(_ job: HandJob) {
        job.finish(.stopped)
        job.monitors.forEach(NSEvent.removeMonitor)
        job.monitors = []
    }

    /// Phew's own posted events carry `mark`.
    static func isOwn(_ event: CGEvent) -> Bool { event.getIntegerValueField(.eventSourceUserData) == mark }

    /// The runaway brake: a pure rule, so the counters are unit-tested. At `minuteCeiling` a job pauses (`room`).
    static func ceiling(actedInJob: Int, recent: [Date], now: Date) -> HandEnd? {
        if actedInJob >= perJob { return .jobCeiling }
        if recent.filter({ now.timeIntervalSince($0) < 60 }).count >= perMinute { return .minuteCeiling }
        return nil
    }

    /// R5: how long until the last minute holds fewer than `perMinute` actions; nil when it does now.
    static func room(recent: [Date], now: Date) -> TimeInterval? {
        let inside = recent.filter { now.timeIntervalSince($0) < 60 }.sorted()
        guard inside.count >= perMinute else { return nil }
        return max(0.01, 60 - now.timeIntervalSince(inside[inside.count - perMinute]))
    }

    /// The one acting function. Blocks for at most about `timeout`, or for a pause at the minute ceiling (R5): call it
    /// off the main thread, one step at a time.
    func act(_ step: HandStep, in job: HandJob) -> HandResult {
        if let end = job.end { return HandResult(end: end) }  // the job is over: no step, no retry
        let start = Date()
        var role = step.role
        var marked = false, final = false, left = false
        var end = HandEnd.minuteCeiling
        while end == .minuteCeiling {
            end = acting.withLock { () -> HandEnd in
                let end = check(step, job: job, role: &role, marked: &marked, final: &final, left: &left)
                guard end != .minuteCeiling else { return end }  // nothing sent: every gate again after the pause
                job.steps += 1
                if end != .done { job.finish(end) }
                return end
            }
            if end == .minuteCeiling, let over = pause(job) {
                end = over
                acting.withLock { job.steps += 1 }
            }
        }
        // The level, as before: marked or in the class. No word of what changed.
        ActionLog.record(ActionLog.line(job: job.number, step: job.steps, kind: step.kind, role: role, ended: end,
                                        marked: marked || final, ms: Int(Date().timeIntervalSince(start) * 1000),
                                        chars: end != .done ? 0 : step.kind == .set || step.kind == .keys ? step.text.count : step.script?.chars ?? 0))
        var result = HandResult(end: end, marked: marked, final: final, left: left)
        if end == .manyFound, let script = step.script { result.choices = Array(surface.choices(script).prefix(5)) }
        return result
    }

    /// R5: at the minute ceiling he waits, outside `acting`, until the minute has room again, then the step goes on.
    /// Stop and the user's own input end the wait within 0.1 s, as at any time. Nil: go on; else the job's end.
    private func pause(_ job: HandJob) -> HandEnd? {
        job.pausing?(true)
        defer { job.pausing?(false) }
        while true {
            if let end = job.end { return end }
            guard let left = acting.withLock({ Self.room(recent: recent, now: now()) }) else { return nil }
            sleep(min(left, 0.1))
        }
    }

    /// Under `acting`. Every guard, then the action.
    private func check(_ step: HandStep, job: HandJob, role: inout String, marked: inout Bool, final: inout Bool,
                       left: inout Bool) -> HandEnd {
        guard allowed else { return .off }
        if step.kind == .script { return script(step, job: job, final: &final, left: &left) }
        // An agent in the background acts only through scripts: it never clicks, types or switches app, whoever asks.
        if job.agent { return .failed }
        if step.kind == .front { return front(step.app, job: job) }
        if step.kind == .keys { return keys(step, job: job, role: &role, final: &final) }
        // The Never list, first the app, before anything of it is read.
        if let end = NeverList.refusal(bundleID: surface.bundleID(step.pid), pid: step.pid, ownPID: ownPID,
                                       secureInput: surface.secureInput(), list: list) { return end }
        let point = CGPoint(x: step.frame.midX, y: step.frame.midY)
        let element = step.kind == .pick ? surface.menuItem(step.menuPath, pid: step.pid) : surface.element(at: point, pid: step.pid)
        let seen = element.flatMap(surface.read)
        // A click, scroll or drag on a bare canvas may find no element; anything else needs one.
        if seen == nil && !(step.kind.pointed && step.role.isEmpty) { return .gone }
        if let seen { role = seen.role }
        if step.kind == .scroll, !(1...Self.mostScroll).contains(abs(step.amount)) { return .failed }
        // R1: a drag ends inside the job's app, and what it ends on is judged as the control it starts on.
        var under: HandSeen?
        if step.kind == .drag {
            guard let to = step.to, surface.owner(at: to) == step.pid else { return .failed }
            under = surface.element(at: to, pid: step.pid).flatMap(surface.read)
            if let under, SecretsFilter.isSecure(role: under.role, subrole: under.subrole) { return .secureField }
        }
        // R3 (17 November): the words on the control and its menu path, never the window's title.
        let names = [step.name, seen?.name ?? "", under?.name ?? ""] + step.menuPath
        if let end = NeverList.refusal(role: seen?.role ?? "", subrole: seen?.subrole ?? "",
                                       focusedSecure: surface.focusedIsSecure(step.pid), texts: names) { return end }
        marked = NeverList.careful(name: step.kind == .pick ? step.menuPath.last ?? "" : step.name, texts: names)
        // F4: the default button of a sheet or dialog, read at the moment of acting.
        let isDefault = [.press, .click, .doubleClick].contains(step.kind) && element.map(surface.isDefault) == true
        final = NeverList.final(step, names: names, replaces: step.kind == .set && !(seen?.value ?? "").isEmpty,
                                agent: job.agent, isDefault: isDefault)
        if final, job.agent { return .needsConfirm }
        let time = now()
        if let end = brake(job, time) { return end }
        // What is there now against what the look saw.
        guard surface.frontPID() == step.pid else { return .frontChanged }
        if surprised(step.pid, job) { return .surprise }
        if let seen, step.kind != .pick, !matches(seen, step) { return .moved }
        // Stop pressed meanwhile: nothing is sent.
        if let end = job.end { return end }
        job.acted += 1
        job.windowExpected = step.opensWindow
        recent.append(time)
        let sent = surface.send(step, to: element)
        guard sent == .done else { return sent }
        // A set value is read back; the look after the step checks the rest (PH.7): a click, double or right click,
        // a scroll and a drag change what the next look shows, and the job judges it there. A drag on a canvas may
        // change nothing a look can read: no code check is possible for it, only the picture.
        if step.kind == .set, let element, !Self.sameValue(surface.read(element)?.value, step.text) { return .checkFailed }
        return .done
    }

    /// R4: what a field shows after a set against what was typed. The same once both are normalised: ends trimmed,
    /// runs of white space as one space, one Unicode form, curly quotes as straight ones. Or, when both read as a
    /// number or as a date in the user's locale, the same value written another way ("1000" and "1,000.00").
    static func sameValue(_ shown: String?, _ typed: String, locale: Locale = .current) -> Bool {
        guard let shown else { return false }
        func plain(_ s: String) -> String {
            s.precomposedStringWithCanonicalMapping
                .replacing(/[‘’‚‛′]/, with: "'").replacing(/[“”„‟″]/, with: "\"")
                .replacing(/\s+/, with: " ").trimmingCharacters(in: .whitespaces)
        }
        let (a, b) = (plain(shown), plain(typed))
        if a == b { return true }
        let number = NumberFormatter()
        number.locale = locale
        number.numberStyle = .decimal
        // A leading zero is part of a code (a ZIP, a phone number, an id), not of a number: "02134" is not "2134".
        let coded = { (s: String) in s.wholeMatch(of: /[-+]?0\d.*/) != nil }
        if !coded(a), !coded(b), let x = number.number(from: a), let y = number.number(from: b) { return x == y }
        func day(_ s: String) -> Date? {
            [DateFormatter.Style.short, .medium, .long].lazy.compactMap { style in
                let date = DateFormatter()
                date.locale = locale
                date.dateStyle = style
                date.timeStyle = .none
                return date.date(from: s)
            }.first
        }
        if let x = day(a), let y = day(b) { return Calendar.current.isDate(x, inSameDayAs: y) }
        return false
    }

    /// Under `acting`. The ceilings.
    private func brake(_ job: HandJob, _ time: Date) -> HandEnd? {
        recent.removeAll { time.timeIntervalSince($0) >= 60 }
        return Self.ceiling(actedInJob: job.acted, recent: recent, now: time)
    }

    /// Under `acting`. A sheet or dialog more than the job last saw in `pid`, which no step called for.
    private func surprised(_ pid: pid_t, _ job: HandJob) -> Bool {
        let dialogs = surface.dialogs(pid)
        guard !job.windowExpected, let before = job.dialogs[pid] else {
            job.dialogs[pid] = dialogs
            return false
        }
        return dialogs > before
    }

    /// Under `acting`. A key, a shortcut or text typed through keys (R1): the Never list for the app, which holds
    /// secure input; no key at all while a secure field has focus; the never words on the focused control, as on a
    /// pressed one; never a shortcut of `NeverList.neverSend`; only to the job's own app, while it is in front.
    /// Posted to that app's pid, never to the whole Mac. The check after is the next look, as for a click: a key
    /// leaves nothing the code can read back in general (a canvas, a web editor).
    private func keys(_ step: HandStep, job: HandJob, role: inout String, final: inout Bool) -> HandEnd {
        if let end = NeverList.refusal(bundleID: surface.bundleID(step.pid), pid: step.pid, ownPID: ownPID,
                                       secureInput: surface.secureInput(), list: list) { return end }
        guard step.pid == job.app else { return .frontChanged }
        let focus = surface.focused(step.pid).flatMap(surface.read)
        if let focus { role = focus.role }
        if let end = NeverList.refusal(role: focus?.role ?? "", subrole: focus?.subrole ?? "",
                                       focusedSecure: surface.focusedIsSecure(step.pid), texts: [focus?.name ?? ""]) { return end }
        if let chord = step.chord {
            if NeverList.neverSend.contains(chord) { return .neverKeys }
        } else if step.text.isEmpty || step.text.count > Self.mostTyped
                    || step.text.unicodeScalars.contains(where: { $0.properties.generalCategory == .control && $0 != "\n" && $0 != "\t" }) {
            // Control characters (escape, delete, end of text) are keys in disguise: only a new line and a tab are typed.
            return .failed
        }
        final = NeverList.final(step, names: [focus?.name ?? ""], agent: job.agent, dialogOpen: surface.dialogs(step.pid) > 0)
        if final, job.agent { return .needsConfirm }
        let time = now()
        if let end = brake(job, time) { return end }
        guard surface.frontPID() == step.pid else { return .frontChanged }
        if surprised(step.pid, job) { return .surprise }
        if let end = job.end { return end }
        job.acted += 1
        job.windowExpected = step.opensWindow  // R4: cmd+S and its kind open a sheet (`ActJob.opens`)
        recent.append(time)
        return surface.send(step, to: nil)
    }

    /// Under `acting`. A script: the Never list for the app it acts in (it is not the front app, and no control is
    /// involved), the ceilings, the "cannot be undone" class (an agent's waits for a confirm), then the script, read
    /// back by the surface. Nothing on screen is compared.
    /// A put-back of Undo: no ceiling holds it, as none holds `back`, since it only undoes what Phew did (R6); an item
    /// changed again since the job is left as it is (`left`, R16), and one that already holds what it held is not
    /// written.
    private func script(_ step: HandStep, job: HandJob, final: inout Bool, left: inout Bool) -> HandEnd {
        guard let script = step.script else { return .failed }
        if let end = NeverList.refusal(bundleID: script.app, pid: 0, ownPID: ownPID, secureInput: surface.secureInput(),
                                       list: list) { return end }
        // F3: the titles it makes or names, against the password and paying words, as a control's name is.
        if let end = NeverList.refusal(titles: script.titles) { return end }
        let time = now()
        if !script.restores, let end = brake(job, time) { return end }
        if let end = job.end { return end }
        let facts = script.target == nil && !script.restores ? HandFacts() : surface.facts(script)
        final = NeverList.final(step, facts: facts, agent: job.agent)
        if final, job.agent { return .needsConfirm }
        if facts.changedSince || facts.unchanged {
            left = facts.changedSince
            return .done
        }
        job.acted += 1
        recent.append(time)
        job.script(true)
        var end = HandEnd.failed, made: HandMade?, kept: HandKept?
        if script.changes {
            (end, kept) = surface.change(script, stop: { job.end != nil })
            // With guests or a repeat there is no whole way back: nothing is offered. A restore hands back what it made
            // again, for `undo`.
            if let kept, !final { job.keep(kept) }
        } else {
            (end, made) = surface.run(script, made: job.made, stop: { job.end != nil })
        }
        job.script(false)
        if let made { job.made.append(made) }
        #if DEBUG
        lock.withLock { ranHere.append((script, end, made)) }
        #endif
        return end
    }

    /// Undo on the card (N2.3): puts back what the job's changes and deletes replaced, newest first, each a `restore`
    /// script through `act` in a job of its own, so every gate holds. What is put back goes; what is not (it stopped)
    /// stays with the job for another Undo (R6). Blocks: off the main thread.
    func undo(_ job: HandJob) -> HandEnd { restore(job).end }

    /// `undo`, with what the card says beside it (`HandUndo`): items left because they changed since (R16), and what
    /// a deleted item made again lacks (R17).
    func restore(_ job: HandJob) -> HandUndo {
        var kept = Array(job.takeKept().reversed())
        let undo = lock.withLock { jobs += 1; return HandJob(number: jobs, app: 0) }
        var result = HandUndo(end: .done), i = 0
        while i < kept.count {
            let put = act(HandStep(kind: .script, pid: 0, script: .restore(kept[i])), in: undo)
            guard put.end == .done else { result.end = put.end; break }
            if put.left { result.changedSince += 1 }
            if let again = undo.takeKept().first {
                if let line = again.lost, !result.lost.contains(line) { result.lost.append(line) }
                // A deleted item made again has a new id: its older changes are put back on that one, never a copy.
                if let made = again.id, let old = kept[i].id {
                    for j in kept.indices.dropFirst(i + 1) where kept[j].id == old { kept[j] = kept[j].with(id: made) }
                }
            }
            i += 1
        }
        kept[i...].reversed().forEach(job.keep)
        undo.finish(.stopped)
        return result
    }

    /// Under `acting`. Another app to the front, the one focus exception (CLAUDE.md): the Never list for that app before
    /// anything of it is read, the ceilings, the job's own app still in front (a change he did not make stops the
    /// job), then the switch. The app brought becomes the job's app. Phew itself never becomes the active app.
    private func front(_ app: String, job: HandJob) -> HandEnd {
        guard !app.isEmpty else { return .failed }
        if let end = NeverList.refusal(bundleID: app, pid: surface.running(app) ?? 0, ownPID: ownPID,
                                       secureInput: surface.secureInput(), list: list) { return end }
        let time = now()
        if let end = brake(job, time) { return end }
        guard surface.frontPID() == job.app else { return .frontChanged }
        if let end = job.end { return end }
        job.acted += 1
        recent.append(time)
        let (end, pid) = surface.activate(app, stop: { job.end != nil })
        guard end == .done, let pid else { return end == .done ? .failed : end }
        job.moved(to: pid)
        return .done
    }

    /// At the job's end, however it ended: brings back the app the job began in, when the job brought another to
    /// the front, and in it the window that was in front when the job began (N2.8); when that window is gone, the app
    /// as it comes. Not when the user took over (their own input, or another app they brought to the front): he
    /// leaves them where they are. The switch and own-app check apply and it is logged like any action; no ceiling,
    /// so a job stopped at one still returns; no Never list, as the user was in that app and nothing of it is read.
    /// Nil when there is nothing to return. Blocks up to `frontTimeout`: off the main thread.
    @discardableResult
    func back(_ job: HandJob) -> HandEnd? {
        let (home, app) = (job.start, job.app)
        guard home != 0, app != home, job.end != .userInput, surface.frontPID() == app else { return nil }
        let begun = Date()
        let end = acting.withLock { () -> HandEnd in
            job.steps += 1
            guard allowed else { return .off }
            if home == ownPID { return .ownApp }
            guard let bundle = surface.bundleID(home) else { return .failed }
            let (end, pid) = surface.activate(bundle, stop: { false })
            if end == .done, let pid {
                job.moved(to: pid)
                if let window = job.window { _ = surface.raise(window) }  // gone: the app as it came, as before N2.8
            }
            return end
        }
        ActionLog.record(ActionLog.line(job: job.number, step: job.steps, kind: .front, role: "", ended: end, marked: false,
                                        ms: Int(Date().timeIntervalSince(begun) * 1000), chars: 0))
        return end
    }

    /// Same role, same name when both have one, frame within `tolerance`.
    private func matches(_ seen: HandSeen, _ step: HandStep) -> Bool {
        if !step.role.isEmpty, seen.role != step.role { return false }
        if !step.name.isEmpty, !seen.name.isEmpty, NeverList.fold(seen.name) != NeverList.fold(step.name) { return false }
        guard !step.frame.isEmpty, let f = seen.frame else { return true }
        return abs(f.minX - step.frame.minX) <= Self.tolerance && abs(f.minY - step.frame.minY) <= Self.tolerance
            && abs(f.width - step.frame.width) <= Self.tolerance && abs(f.height - step.frame.height) <= Self.tolerance
    }
}

/// The real surface: the Accessibility API, and one posted click for canvases.
struct AXSurface: HandSurface {
    /// The front app. Tests of the practice window stand the test process in.
    var front: () -> pid_t? = { NSWorkspace.shared.frontmostApplication?.processIdentifier }

    func frontPID() -> pid_t? { front() }
    /// The own process through `.current`: a lookup by pid came back nil for a moment in a just-launched test host
    /// (PH.9). In the product Phew's own pid is refused before this matters (`ownApp`).
    func bundleID(_ pid: pid_t) -> String? {
        (pid == getpid() ? NSRunningApplication.current : NSRunningApplication(processIdentifier: pid))?.bundleIdentifier
    }
    func secureInput() -> Bool { IsSecureEventInputEnabled() }

    func focusedIsSecure(_ pid: pid_t) -> Bool {
        guard let focused = attribute(app(pid), kAXFocusedUIElementAttribute).flatMap(asElement) else { return false }
        return SecretsFilter.isSecure(role: attribute(focused, kAXRoleAttribute) as? String ?? "",
                                      subrole: attribute(focused, kAXSubroleAttribute) as? String ?? "")
    }

    func element(at point: CGPoint, pid: pid_t) -> AnyObject? {
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(app(pid), Float(point.x), Float(point.y), &hit) == .success, let hit else { return nil }
        var owner: pid_t = 0
        AXUIElementGetPid(hit, &owner)
        return owner == pid ? hit : nil
    }

    func menuItem(_ path: [String], pid: pid_t) -> AnyObject? {
        guard !path.isEmpty, var level = attribute(app(pid), kAXMenuBarAttribute).flatMap(asElement) else { return nil }
        for (i, title) in path.enumerated() {
            // Under the menu bar the items sit directly; under an item, inside its one menu.
            let items = i == 0 ? children(level) : children(level).flatMap(children)
            guard let item = items.first(where: { name(of: $0) == clean(title) }) else { return nil }
            level = item
        }
        return level
    }

    func read(_ object: AnyObject) -> HandSeen? {
        let el = object as! AXUIElement
        var raw: CFArray?
        let names = [kAXRoleAttribute, kAXSubroleAttribute, kAXPositionAttribute, kAXSizeAttribute] as CFArray
        guard AXUIElementCopyMultipleAttributeValues(el, names, [], &raw) == .success, let v = raw as? [AnyObject],
              v.count == 4, let role = v[0] as? String else { return nil }
        var seen = HandSeen(role: role, subrole: v[1] as? String ?? "", name: name(of: el))
        var origin = CGPoint.zero, size = CGSize.zero
        if axValue(v[2], .cgPoint, &origin), axValue(v[3], .cgSize, &size) { seen.frame = CGRect(origin: origin, size: size) }
        seen.value = SecretsFilter.unlessSecure(role: seen.role, subrole: seen.subrole) { attribute(el, kAXValueAttribute) as? String }
        return seen
    }

    func focused(_ pid: pid_t) -> AnyObject? { attribute(app(pid), kAXFocusedUIElementAttribute).flatMap(asElement) }

    /// Up from the element to the nearest sheet or dialog, and whether that one names it as its default button. An
    /// ordinary window's own default button is not counted: only a sheet's or a dialog's (13.5).
    func isDefault(_ object: AnyObject) -> Bool {
        let el = object as! AXUIElement
        var node = el
        for _ in 0..<20 {
            guard let parent = attribute(node, kAXParentAttribute).flatMap(asElement) else { return false }
            let role = attribute(parent, kAXRoleAttribute) as? String ?? ""
            let subrole = attribute(parent, kAXSubroleAttribute) as? String ?? ""
            if role == kAXSheetRole || (role == kAXWindowRole && ["AXDialog", "AXSystemDialog"].contains(subrole)) {
                return attribute(parent, kAXDefaultButtonAttribute).flatMap(asElement).map { CFEqual($0, el) } ?? false
            }
            if role == kAXWindowRole { return false }
            node = parent
        }
        return false
    }

    func dialogs(_ pid: pid_t) -> Int {
        let windows = (attribute(app(pid), kAXWindowsAttribute) as? [AXUIElement]) ?? []
        return windows.reduce(0) { count, window in
            let subrole = attribute(window, kAXSubroleAttribute) as? String ?? ""
            let sheets = children(window).filter { attribute($0, kAXRoleAttribute) as? String == kAXSheetRole }.count
            return count + sheets + (["AXDialog", "AXSystemDialog"].contains(subrole) ? 1 : 0)
        }
    }

    func send(_ step: HandStep, to object: AnyObject?) -> HandEnd {
        let result: AXError
        switch step.kind {
        case .press, .pick:
            let el = object as! AXUIElement
            AXUIElementSetMessagingTimeout(el, Hand.timeout)
            result = AXUIElementPerformAction(el, kAXPressAction as CFString)
        case .set:
            let el = object as! AXUIElement
            AXUIElementSetMessagingTimeout(el, Hand.timeout)
            result = AXUIElementSetAttributeValue(el, kAXValueAttribute as CFString, step.text as CFString)
        case .click:
            // Posted to the target app only, so a click can never land in another app that moved on top.
            let point = CGPoint(x: step.frame.midX, y: step.frame.midY)
            // A click posted to the pid reaches its window only as AppKit makes it: with the window's number and the
            // point inside that window. A bare CGEvent arrives with no window, or at the window's corner, and is dropped
            // (measured in PL.1). Phew's AppKit cannot see the other app's window, so it takes the point as if the
            // window sat at the main screen's top-left corner; it is given in those terms.
            guard let (window, bounds) = Self.window(of: step.pid, at: point),
                  let events = Self.clickEvents(Self.clickLocation(point, in: bounds, mainHeight: NSScreen.screens.first?.frame.height ?? 0),
                                                window: window) else { return .failed }
            events.forEach { $0.postToPid(step.pid) }
            return .done
        case .doubleClick, .rightClick, .drag:
            // Made as the click is, by AppKit, in the window under the start; a drag stays in that one window.
            let point = CGPoint(x: step.frame.midX, y: step.frame.midY)
            let height = NSScreen.screens.first?.frame.height ?? 0
            guard let (window, bounds) = Self.window(of: step.pid, at: point) else { return .failed }
            let at = Self.clickLocation(point, in: bounds, mainHeight: height)
            let moves: [(NSEvent.EventType, NSPoint, Int)]
            switch step.kind {
            case .doubleClick: moves = [(.leftMouseDown, at, 1), (.leftMouseUp, at, 1), (.leftMouseDown, at, 2), (.leftMouseUp, at, 2)]
            case .rightClick: moves = [(.rightMouseDown, at, 1), (.rightMouseUp, at, 1)]
            default:
                guard let to = step.to, let (same, _) = Self.window(of: step.pid, at: to), same == window else { return .failed }
                let end = Self.clickLocation(to, in: bounds, mainHeight: height)
                let path = (1...10).map { NSPoint(x: at.x + (end.x - at.x) * CGFloat($0) / 10, y: at.y + (end.y - at.y) * CGFloat($0) / 10) }
                moves = [(.leftMouseDown, at, 1)] + path.map { (.leftMouseDragged, $0, 1) } + [(.leftMouseUp, end, 1)]
            }
            guard let events = Self.mouseEvents(moves, window: window) else { return .failed }
            for event in events {
                event.postToPid(step.pid)
                if step.kind == .drag { Thread.sleep(forTimeInterval: 0.01) }  // an app's drag loop takes its time
            }
            return .done
        case .scroll:
            // shortcut: a line wheel posted to the pid with the window under it named; whether every app scrolls the
            // view under the point this way, and in which direction with natural scrolling, only a live run shows.
            let point = CGPoint(x: step.frame.midX, y: step.frame.midY)
            guard let (window, _) = Self.window(of: step.pid, at: point),
                  let event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: Int32(-step.amount), wheel2: 0, wheel3: 0)
            else { return .failed }
            event.location = point
            event.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: Int64(window))
            event.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent, value: Int64(window))
            event.setIntegerValueField(.eventSourceUserData, value: Hand.mark)
            event.postToPid(step.pid)
            return .done
        case .keys:
            guard let events = step.chord.map(Self.keyEvents) ?? Self.typeEvents(step.text) else { return .failed }
            events.forEach { $0.postToPid(step.pid) }
            return .done
        case .script, .front:
            return .failed  // scripts go through `run`, fronts through `activate`
        }
        switch result {
        case .success: return .done
        case .cannotComplete: return .timeout
        default: return .failed
        }
    }

    /// One click, down then up, at `location` in window `window`, each event marked as Phew's own (`Hand.mark`), so
    /// the watch never takes his click for the user's. Nil when macOS makes no event.
    static func clickEvents(_ location: NSPoint, window: Int) -> [CGEvent]? {
        mouseEvents([(.leftMouseDown, location, 1), (.leftMouseUp, location, 1)], window: window)
    }

    /// Mouse events in window `window`, each a type, a point inside the window and a click count, each marked as
    /// Phew's own. Nil when macOS makes one of them not.
    static func mouseEvents(_ moves: [(NSEvent.EventType, NSPoint, Int)], window: Int) -> [CGEvent]? {
        let events = moves.compactMap { type, location, count in
            NSEvent.mouseEvent(with: type, location: location, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                               windowNumber: window, context: nil, eventNumber: 0, clickCount: count, pressure: 1)?.cgEvent
        }
        guard events.count == moves.count else { return nil }
        events.forEach { $0.setIntegerValueField(.eventSourceUserData, value: Hand.mark) }
        return events
    }

    /// A key down and up with its modifiers, marked as Phew's own. Made here, posted by `send` to one pid only.
    static func keyEvents(_ chord: HandChord) -> [CGEvent]? {
        guard let code = HandChord.codes[chord.key] else { return nil }
        let events = [true, false].compactMap { CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(code), keyDown: $0) }
        guard events.count == 2 else { return nil }
        events.forEach {
            $0.flags = chord.flags
            $0.setIntegerValueField(.eventSourceUserData, value: Hand.mark)
        }
        return events
    }

    /// Text as key events, one character each, down and up, marked as Phew's own: the character rides in the event,
    /// so no keyboard layout is involved. Nil for empty text or more than `Hand.mostTyped`.
    static func typeEvents(_ text: String) -> [CGEvent]? {
        guard !text.isEmpty, text.count <= Hand.mostTyped else { return nil }
        var events: [CGEvent] = []
        for character in text {
            let units = Array(String(character).utf16)
            for down in [true, false] {
                guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: down) else { return nil }
                event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
                event.setIntegerValueField(.eventSourceUserData, value: Hand.mark)
                events.append(event)
            }
        }
        return events
    }

    /// The point inside `bounds` (both top-left origin) as `NSEvent.mouseEvent` must be given it for another app's
    /// window: flipped against the main screen's height, as if the window sat at its top-left corner (measured, PL.1).
    /// On any display (N2.9): `point` and `bounds` are both global, top-left origin of the main display, so a window
    /// on a display to the left or above (negative coordinates) gives the same offset inside it. `mainHeight` is the
    /// main display's (`NSScreen.screens[0]`, the one with the menu bar), never the window's own display.
    static func clickLocation(_ point: CGPoint, in bounds: CGRect, mainHeight: CGFloat) -> NSPoint {
        NSPoint(x: point.x - bounds.minX, y: mainHeight - (point.y - bounds.minY))
    }

    /// The window server's number and bounds (top-left origin) of the topmost on-screen window of `pid` containing
    /// `point`, or nil. Reads only window numbers, owners and bounds, never a title.
    static func window(of pid: pid_t, at point: CGPoint) -> (Int, CGRect)? {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        for info in windows where info[kCGWindowOwnerPID as String] as? pid_t == pid && info[kCGWindowLayer as String] as? Int == 0 {  // front to back
            guard let bounds = (info[kCGWindowBounds as String] as? NSDictionary).flatMap({ CGRect(dictionaryRepresentation: $0 as CFDictionary) }),
                  bounds.contains(point), let number = info[kCGWindowNumber as String] as? Int else { continue }
            return (number, bounds)
        }
        return nil
    }

    /// Phew's own pid is "not known": a click through his pointer ring lands in the app under it, so it counts.
    func owner(at point: CGPoint) -> pid_t? {
        let wide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(wide, Hand.timeout)
        var hit: AXUIElement?, owner: pid_t = 0
        guard AXUIElementCopyElementAtPosition(wide, Float(point.x), Float(point.y), &hit) == .success, let hit,
              AXUIElementGetPid(hit, &owner) == .success, owner != getpid() else { return nil }
        return owner
    }

    func focusedWindow(_ pid: pid_t) -> AnyObject? { attribute(app(pid), kAXFocusedWindowAttribute).flatMap(asElement) }

    func raise(_ window: AnyObject) -> Bool {
        let window = window as! AXUIElement
        AXUIElementSetMessagingTimeout(window, Hand.timeout)
        return AXUIElementPerformAction(window, kAXRaiseAction as CFString) == .success
    }

    func running(_ bundleID: String) -> pid_t? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first?.processIdentifier
    }

    /// A running app is asked to the front through Accessibility; one not running is launched by LaunchServices.
    func activate(_ bundleID: String, stop: @escaping () -> Bool) -> (HandEnd, pid_t?) {
        if running(bundleID) == nil {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return (.failed, nil) }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        }
        var asked: pid_t?
        let deadline = Date() + Hand.frontTimeout
        while true {
            if let pid = running(bundleID) {
                if front() == pid { return (.done, pid) }
                if asked != pid {  // once per process
                    asked = pid
                    AXUIElementSetAttributeValue(app(pid), kAXFrontmostAttribute as CFString, kCFBooleanTrue)
                }
            }
            if stop() { return (.stopped, nil) }
            if Date() > deadline { return (.timeout, nil) }
            Thread.sleep(forTimeInterval: 0.05)
        }
    }

    // MARK: - Accessibility helpers

    private func app(_ pid: pid_t) -> AXUIElement {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, Hand.timeout)
        return app
    }

    private func attribute(_ el: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(el, name as CFString, &value) == .success ? value : nil
    }

    private func asElement(_ value: CFTypeRef) -> AXUIElement? {
        CFGetTypeID(value) == AXUIElementGetTypeID() ? (value as! AXUIElement) : nil
    }

    private func children(_ el: AXUIElement) -> [AXUIElement] { attribute(el, kAXChildrenAttribute) as? [AXUIElement] ?? [] }

    /// Title, else description, else placeholder: what the look calls the control (WindowReader's name).
    private func name(of el: AXUIElement) -> String {
        let name = [kAXTitleAttribute, kAXDescriptionAttribute, kAXPlaceholderValueAttribute]
            .lazy.compactMap { attribute(el, $0) as? String }.first { !$0.isEmpty }
        return clean(name ?? "")
    }

    /// A menu title without its trailing dots, so "Export…" and "Export..." are one.
    private func clean(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: #"(\.\.\.|…)$"#, with: "", options: .regularExpression)
    }

    private func axValue(_ object: AnyObject, _ type: AXValueType, _ out: UnsafeMutableRawPointer) -> Bool {
        CFGetTypeID(object) == AXValueGetTypeID() && AXValueGetValue(object as! AXValue, type, out)
    }
}

// MARK: - Scripts: Notes and Excel through their own scripting, Reminders and Calendar through EventKit

extension AXSurface {
    /// One store for the process, as Apple advises.
    fileprivate static let store = EKEventStore()

    func run(_ script: HandScript, made: [HandMade], stop: @escaping () -> Bool) -> (HandEnd, HandMade?) {
        switch script {
        case let .note(title, body):
            let (end, out) = Self.osascript(Self.makeNote, [Self.html([title] + body.components(separatedBy: .newlines))], stop: stop)
            let lines = out.components(separatedBy: "\n")
            guard end == .done, let id = lines.first, !id.isEmpty else { return (end == .done ? .failed : end, nil) }
            let note = HandMade(kind: "note", id: id, title: title)
            return (lines.dropFirst().joined() == title.trimmingCharacters(in: .whitespaces) ? .done : .checkFailed, note)
        case let .append(text, _):
            guard let note = made.last(where: { $0.kind == "note" }) else { return (.gone, nil) }
            let lines = text.components(separatedBy: .newlines)
            guard let last = lines.last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else { return (.failed, nil) }
            let (end, out) = Self.osascript(Self.appendNote, [note.id, Self.html(lines), last.trimmingCharacters(in: .whitespaces)], stop: stop)
            return (end == .done && out != "ok" ? .checkFailed : end, nil)
        case let .reminder(title, due):
            guard Self.access(.reminder, stop: stop) else { return (stop() ? .stopped : .noAccess, nil) }
            let reminder = EKReminder(eventStore: Self.store)
            reminder.title = title
            guard let list = Self.store.defaultCalendarForNewReminders() else { return (.failed, nil) }
            reminder.calendar = list
            if let due {
                reminder.dueDateComponents = due
                // A due time also reminds, as one set in Reminders does.
                if due.hour != nil, let date = Calendar.current.date(from: due) { reminder.addAlarm(EKAlarm(absoluteDate: date)) }
            }
            do { try Self.store.save(reminder, commit: true) } catch { return (.failed, nil) }
            let made = HandMade(kind: "reminder", id: reminder.calendarItemIdentifier, title: title)
            let back = Self.store.calendarItem(withIdentifier: made.id) as? EKReminder
            let sameDue = back?.dueDateComponents.flatMap(Calendar.current.date(from:)) == due.flatMap(Calendar.current.date(from:))
            return (back?.title == title && sameDue ? .done : .checkFailed, made)
        case let .event(title, start, end):
            guard Self.access(.event, stop: stop) else { return (stop() ? .stopped : .noAccess, nil) }
            let event = EKEvent(eventStore: Self.store)
            event.title = title
            event.startDate = start
            event.endDate = end
            guard let calendar = Self.store.defaultCalendarForNewEvents else { return (.failed, nil) }
            event.calendar = calendar
            do { try Self.store.save(event, span: .thisEvent, commit: true) } catch { return (.failed, nil) }
            guard let id = event.eventIdentifier else { return (.checkFailed, nil) }
            let back = Self.store.event(withIdentifier: id)
            return (back?.title == title && back?.startDate == start ? .done : .checkFailed, HandMade(kind: "event", id: id, title: title))
        case .workbook:
            let (end, name) = Self.osascript(Self.makeWorkbook, [], stop: stop)
            guard end == .done else { return (end, nil) }
            return name.isEmpty ? (.checkFailed, nil) : (.done, HandMade(kind: "workbook", id: name))
        case let .cells(top, rows):
            guard let book = made.last(where: { $0.kind == "workbook" }) else { return (.gone, nil) }
            let width = rows.map(\.count).max() ?? 0
            guard let range = Hand.range(top: top, rows: rows.count, columns: width) else { return (.failed, nil) }
            let values = rows.flatMap { $0 + Array(repeating: "", count: width - $0.count) }
            let (end, out) = Self.osascript(Self.fillCells, [book.id, range, String(width)] + values, stop: stop)
            guard end == .done else { return (end, nil) }
            return (Hand.sameCells(out.components(separatedBy: "\u{1F}"), values) ? .done : .checkFailed, nil)
        case .rename, .noteBody, .complete, .move, .changeCells, .delete, .restore:
            return (.failed, nil)  // changes go through `change`
        }
    }

    func facts(_ script: HandScript) -> HandFacts { changes(stop: { false }).facts(script) }

    func change(_ script: HandScript, stop: @escaping () -> Bool) -> (HandEnd, HandKept?) { changes(stop: stop).run(script) }

    func choices(_ script: HandScript) -> [String] { changes(stop: { false }).choices(script) }

    private func changes(stop: @escaping () -> Bool) -> HandChanges {
        HandChanges(script: { Self.osascript($0, $1, stop: stop) }, items: EventKitItems(stop: stop))
    }

    /// Asks macOS once, the first time, and waits for the user's answer, or Stop, at most `Hand.scriptTimeout`.
    fileprivate static func access(_ type: EKEntityType, stop: () -> Bool) -> Bool {
        if EKEventStore.authorizationStatus(for: type) == .notDetermined {
            let answered = DispatchSemaphore(value: 0)
            let done: EKEventStoreRequestAccessCompletionHandler = { _, _ in answered.signal() }
            if type == .reminder { store.requestFullAccessToReminders(completion: done) } else { store.requestFullAccessToEvents(completion: done) }
            let deadline = Date() + Hand.scriptTimeout
            while answered.wait(timeout: .now() + 0.05) == .timedOut, !stop(), Date() < deadline {}
        }
        return EKEventStore.authorizationStatus(for: type) == .fullAccess
    }

    /// Lines as Notes' HTML, each in its own block, every sign escaped: the words stay text.
    static func html(_ lines: [String]) -> String {
        lines.map { line in
            let text = line.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            return "<div>\(text.isEmpty ? "<br>" : text)</div>"
        }.joined()
    }

    /// Runs one of the fixed scripts below with `args` as its run handler's list, so no word ever becomes script code.
    /// Returns its output, trimmed. The error text is dropped unread, but for macOS's "not allowed" number.
    static func osascript(_ source: String, _ args: [String], stop: () -> Bool) -> (HandEnd, String) {
        run("/usr/bin/osascript", arguments(source, args), stop: stop)
    }

    /// osascript's arguments: each script line after its own `-e`, then "--", then the words. Without "--" a first
    /// word starting with a dash ("-e…") is read as one of osascript's options and becomes script code (R4).
    static func arguments(_ source: String, _ args: [String]) -> [String] {
        source.split(separator: "\n").flatMap { ["-e", String($0)] } + ["--"] + args
    }

    /// Runs a system tool with no window, at most `timeout`, cut by `stop`. Returns its output, trimmed.
    /// Both outputs are read while it runs: a long answer (a note's whole body) would otherwise fill the pipe, and the
    /// tool would wait on it until the time limit (R5).
    static func run(_ tool: String, _ arguments: [String], timeout: TimeInterval = Hand.scriptTimeout, stop: () -> Bool) -> (HandEnd, String) {
        let process = Process()
        process.executableURL = URL(filePath: tool)
        process.arguments = arguments
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        do { try process.run() } catch { return (.failed, "") }
        final class Read: @unchecked Sendable { var data = Data() }  // written once, before the group leaves
        let outRead = Read(), errRead = Read(), reading = DispatchGroup()
        for (pipe, read) in [(out, outRead), (err, errRead)] {
            DispatchQueue.global(qos: .userInitiated).async(group: reading) { read.data = pipe.fileHandleForReading.readDataToEndOfFile() }
        }
        let deadline = Date() + timeout
        while process.isRunning {
            if stop() { process.terminate(); return (.stopped, "") }
            if Date() > deadline { process.terminate(); return (.timeout, "") }
            Thread.sleep(forTimeInterval: 0.05)
        }
        // Ended: its pipes close, unless something it started still holds them.
        guard reading.wait(timeout: .now() + 2) == .success else { return (.failed, "") }
        guard process.terminationStatus == 0 else {
            let error = String(decoding: errRead.data, as: UTF8.self)
            #if DEBUG
            // Only the error's number and the script line it hit, never its words (they can quote a value).
            let number = error.firstMatch(of: /\((-?[0-9]+)\)\s*$/).map { String($0.1) } ?? "none"
            let at = error.firstMatch(of: /([0-9]+):[0-9]+: execution error/).map { String($0.1) } ?? "?"
            shellLog("script failed: error \(number) at char \(at)")
            #endif
            return (error.contains("-1743") ? .noAccess : .failed, "")
        }
        return (.done, String(decoding: outRead.data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static let makeNote = """
        on run argv
        tell application id "com.apple.Notes"
        set n to make new note with properties {body:item 1 of argv}
        return (id of n) & linefeed & (name of n)
        end tell
        end run
        """
    static let appendNote = """
        on run argv
        tell application id "com.apple.Notes"
        set n to note id (item 1 of argv)
        set body of n to (body of n) & (item 2 of argv)
        if plaintext of n contains (item 3 of argv) then return "ok"
        return "differs"
        end tell
        end run
        """
    static let makeWorkbook = """
        on run argv
        tell application id "com.microsoft.Excel"
        set w to make new workbook
        return name of w
        end tell
        end run
        """
    /// argv: the workbook's name, the range, the row width, then every value row by row. Returns what the cells hold.
    static let fillCells = """
        on run argv
        tell application id "com.microsoft.Excel"
        set r to range (item 2 of argv) of worksheet 1 of workbook (item 1 of argv)
        set n to (item 3 of argv) as integer
        set vals to items 4 thru -1 of argv
        if (count of vals) is 1 then
        set formula of r to item 1 of vals
        else
        set rowsList to {}
        repeat with i from 1 to (count of vals) by n
        set end of rowsList to items i thru (i + n - 1) of vals
        end repeat
        set formula of r to rowsList
        end if
        set held to formula of r
        end tell

        """ + readBack + "\nend run"
    /// `held`, what Excel's cells hold, as one text, cell by cell: rows of cells, or one value for one cell. Not named
    /// `back`: that is an AppleScript word (the last item), and the read-back failed with -1700.
    static let readBack = """
        if class of held is not list then set held to {held}
        set flat to {}
        repeat with rw in held
        if class of rw is list then
        repeat with c in rw
        set end of flat to (c as text)
        end repeat
        else
        set end of flat to (rw as text)
        end if
        end repeat
        set AppleScript's text item delimiters to (ASCII character 31)
        return flat as text
        """
}

// MARK: - Changes and deletes of what exists, and their Undo (N2.2, N2.3)

/// Reminders and events, as `HandChanges` reads and writes them: EventKit in the app, a fake in unit tests.
protocol HandItems {
    /// Every open reminder, or every event in the window; nil when macOS gives no access.
    func all(_ kind: HandItem) -> [HandEntry]?
    func one(_ id: String, _ kind: HandItem) -> HandEntry?
    /// Writes `entry` over the item with its id, or makes a new one when the id is empty or the item is gone.
    /// Returns its id; nil when the app refused.
    func save(_ entry: HandEntry, _ kind: HandItem) -> String?
    func remove(_ id: String, _ kind: HandItem) -> Bool
}

/// The change logic, reached only through `HandSurface.change` inside `Hand.act`. `script` runs one of the fixed
/// AppleScripts below (Notes, Excel) with its words as arguments; `items` is reminders and events. Both are seams, so
/// unit tests run this logic on fakes and never touch the user's apps.
/// Each change finds the one item with the exact title, reads what it holds (kept for Undo), writes, then reads back.
struct HandChanges {
    var script: (String, [String]) -> (HandEnd, String)
    var items: HandItems

    func facts(_ script: HandScript) -> HandFacts {
        if case let .restore(kept) = script { return now(kept) }
        guard let (kind, title) = script.target, kind != .note, let all = items.all(kind),
              let item = Hand.one(all, titled: title, \.title).0 else { return HandFacts() }
        return HandFacts(guests: item.guests, repeats: item.repeats)
    }

    func run(_ script: HandScript) -> (HandEnd, HandKept?) {
        switch script {
        case .rename(.note, let title, let to):
            return note(title, "name", to) { name, _ in name == to.trimmingCharacters(in: .whitespacesAndNewlines) }
        case let .noteBody(title, body):
            let lines = body.components(separatedBy: .newlines)
            let last = lines.last { !$0.trimmingCharacters(in: .whitespaces).isEmpty }?.trimmingCharacters(in: .whitespaces)
            return note(title, "body", AXSurface.html([title] + lines)) { name, text in
                name == title && (last.map(text.contains) ?? true)
            }
        case let .append(text, title) where !title.isEmpty:
            // R6: lines added at the end of a note already there; its title and what it held stay as they were.
            let lines = text.components(separatedBy: .newlines)
            let last = lines.last { !$0.trimmingCharacters(in: .whitespaces).isEmpty }?.trimmingCharacters(in: .whitespaces)
            return note(title, "append", AXSurface.html(lines)) { name, plain in
                name == title && (last.map(plain.contains) ?? true)
            }
        case .delete(.note, let title):
            return note(title, "delete", "") { _, text in text == "gone" }
        case let .rename(kind, title, to):
            return entry(kind, title) { $0.title = to }
        case let .complete(title):
            return entry(.reminder, title) { $0.done = true }
        case let .move(title, start, end):
            return entry(.event, title) { item in
                var length: TimeInterval = 3600
                if let from = item.start, let to = item.end { length = to.timeIntervalSince(from) }
                (item.start, item.end) = (start, end ?? start.addingTimeInterval(length))
            }
        case let .delete(kind, title):
            return entry(kind, title, delete: true)
        case let .changeCells(book, top, rows):
            return cells(book, top, rows)
        case let .restore(kept):
            return restore(kept)
        case .note, .append, .reminder, .event, .workbook, .cells:
            return (.failed, nil)  // adds go through `run`; an append to a note named by title is above
        }
    }

    /// Notes: found by title in Notes, then picked here by the exact title; changed by id. `check` gets the name and
    /// plain text read back after the change ("gone" for a delete).
    private func note(_ title: String, _ mode: String, _ value: String, check: (String, String) -> Bool) -> (HandEnd, HandKept?) {
        let (found, notes) = find(title)
        guard found == .done else { return (found, nil) }
        let (hit, match) = Hand.one(notes, titled: title) { $0.name }
        guard let id = hit?.id else { return (match, nil) }
        // What it holds, kept first, by a script of its own: what Undo needs never rides on the change's output (R5).
        let (read, held) = script(Self.readNote, [id])
        guard read == .done else { return (read, nil) }
        let was = Self.noteParts(held)
        guard was.count == 4 else { return (.failed, nil) }
        let kept = HandKept.note(id: id, title: was[1], body: was[0], deleted: mode == "delete", folder: was[2])
        let (end, out) = script(Self.changeNote, [id, mode, value])
        // Cut by Stop or the time limit: the app may have taken the change, so what it held stays kept.
        guard end == .done else { return (end, [.stopped, .timeout].contains(end) ? kept : nil) }
        let back = out.split(separator: "\u{1E}", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        let ok = check(back[0], back.count == 2 ? back[1] : back[0])
        return (ok ? .done : .checkFailed, mode == "delete" ? kept : kept.after(out))
    }

    /// A note Notes found by name: its id, name, folder's name and the seconds since it was last changed.
    private struct Found { var id: String, name: String, folder = "", ago: TimeInterval = 0 }

    /// Every note Notes finds by `title` (`findNotes`), the exact one still to be picked.
    private func find(_ title: String) -> (HandEnd, [Found]) {
        let (end, list) = script(Self.findNotes, [title])
        guard end == .done else { return (end, []) }
        return (.done, list.isEmpty ? [] : list.components(separatedBy: "\u{1F}").compactMap { row in
            let parts = row.components(separatedBy: "\u{1E}")
            guard parts.count >= 2 else { return nil }
            return Found(id: parts[0], name: parts[1], folder: parts.count > 2 ? parts[2] : "",
                         ago: parts.count > 3 ? TimeInterval(parts[3]) ?? 0 : 0)
        })
    }

    /// R6: after `manyFound`, reading only: the items that share the exact title, as plain words for the card, at
    /// most 5. Notes by folder and last change, reminders by list and due date, events by calendar and start.
    func choices(_ script: HandScript, now: Date = Date()) -> [String] {
        guard let (kind, title) = script.target else { return [] }
        if kind == .note {
            return Hand.all(find(title).1, titled: title) { $0.name }.prefix(5).map {
                "the note in \($0.folder.isEmpty ? "a folder" : "“\($0.folder)”"), last changed "
                    + now.addingTimeInterval(-$0.ago).formatted(date: .abbreviated, time: .omitted)
            }
        }
        return Hand.all(items.all(kind) ?? [], titled: title) { $0.title }.prefix(5).map { item in
            let place = item.calendarName.isEmpty ? "" : " in “\(item.calendarName)”"
            if kind == .event {
                return "the event\(place) on " + (item.start?.formatted(date: .abbreviated, time: .shortened) ?? "no date")
            }
            let due = item.due.flatMap { Calendar.current.date(from: $0) }
                .map { "due " + $0.formatted(date: .abbreviated, time: item.due?.hour == nil ? .omitted : .shortened) }
            return "the reminder\(place), " + (due ?? "no due date")
        }
    }

    /// `readNote`'s answer: body, name, folder id, plain text; empty when no note has the id.
    private static func noteParts(_ out: String) -> [String] {
        out.isEmpty ? [] : out.split(separator: "\u{1F}", maxSplits: 3, omittingEmptySubsequences: false).map(String.init)
    }

    /// Before a put-back (R16): whether the item still holds what the job left, or already holds what it held. A
    /// change cut before its read-back has nothing to compare with, and is put back.
    private func now(_ kept: HandKept) -> HandFacts {
        switch kept {
        case let .note(id, _, body, deleted, folder, after):
            let (end, out) = script(Self.readNote, [id])
            guard end == .done else { return HandFacts() }  // the put-back then says why
            let now = Self.noteParts(out)
            // Still in its folder: the delete never landed.
            if deleted { return HandFacts(unchanged: now.count == 4 && now[2] == folder) }
            guard now.count == 4 else { return HandFacts(changedSince: true) }  // deleted since
            if now[0] == body { return HandFacts(unchanged: true) }
            return HandFacts(changedSince: after.map { $0 != now[1] + "\u{1E}" + now[3] } ?? false)
        case let .entry(kind, old, deleted, after):
            let now = items.one(old.id, kind)
            if deleted { return HandFacts(unchanged: now != nil) }
            guard let now else { return HandFacts(changedSince: true) }
            if now == old { return HandFacts(unchanged: true) }
            return HandFacts(changedSince: after.map { $0 != now } ?? false)
        case let .cells(book, range, _, values, after):
            let (end, held) = script(Self.readCells, [book, range])
            guard end == .done else { return HandFacts() }
            let now = held.components(separatedBy: "\u{1F}")
            if Hand.sameCells(now, values) { return HandFacts(unchanged: true) }
            return HandFacts(changedSince: after.map { !Hand.sameCells(now, $0) } ?? false)
        }
    }

    /// Reminders and events. `change` edits the found item; a delete keeps it whole, so Undo makes it again.
    private func entry(_ kind: HandItem, _ title: String, delete: Bool = false, change: (inout HandEntry) -> Void = { _ in }) -> (HandEnd, HandKept?) {
        guard let all = items.all(kind) else { return (.noAccess, nil) }
        let (hit, match) = Hand.one(all, titled: title, \.title)
        guard var item = hit else { return (match, nil) }
        let old = item
        if delete {
            guard items.remove(item.id, kind) else { return (.failed, nil) }
            return (items.one(old.id, kind) == nil ? .done : .checkFailed, .entry(kind, old, deleted: true))
        }
        change(&item)
        guard items.save(item, kind) != nil else { return (.failed, nil) }
        let back = items.one(item.id, kind)
        return (Self.same(back, item) ? .done : .checkFailed, .entry(kind, old, after: back))
    }

    /// Excel: the open workbook picked by its exact name, what the cells hold read first, then written over.
    // shortcut: the first sheet only, as `fillCells`; take the active sheet when a live run shows the need.
    private func cells(_ book: String, _ top: String, _ rows: [[String]]) -> (HandEnd, HandKept?) {
        let width = rows.map(\.count).max() ?? 0
        guard let range = Hand.range(top: top, rows: rows.count, columns: width) else { return (.failed, nil) }
        let (listed, names) = script(Self.workbooks, [])
        guard listed == .done else { return (listed, nil) }
        let (hit, match) = Hand.one(names.isEmpty ? [] : names.components(separatedBy: "\u{1F}"), titled: book) { $0 }
        guard let name = hit else { return (match, nil) }
        let (read, held) = script(Self.readCells, [name, range])
        guard read == .done else { return (read, nil) }
        let old = held.components(separatedBy: "\u{1F}")
        guard old.count == rows.count * width else { return (.failed, nil) }
        let values = rows.flatMap { $0 + Array(repeating: "", count: width - $0.count) }
        return (write(name, range, width, values), .cells(book: name, range: range, width: width, values: old, after: values))
    }

    private func write(_ book: String, _ range: String, _ width: Int, _ values: [String]) -> HandEnd {
        let (end, out) = script(AXSurface.fillCells, [book, range, String(width)] + values)
        guard end == .done else { return end }
        return Hand.sameCells(out.components(separatedBy: "\u{1F}"), values) ? .done : .checkFailed
    }

    /// Puts back what was kept. A deleted item is made again: it comes back with its new id, so older changes of it
    /// go to that one (`Hand.undo`).
    private func restore(_ kept: HandKept) -> (HandEnd, HandKept?) {
        switch kept {
        case let .note(id, title, body, deleted, folder, _):
            let (end, out) = script(Self.restoreNote, [id, body, folder, deleted ? "again" : "body"])
            guard end == .done else { return (end, nil) }
            let back = out.split(separator: "\u{1E}", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
            guard back.count == 3, back[1] == title else { return (.checkFailed, nil) }
            // Moved back from Recently Deleted it is whole; made again it lacks what `HandUndo.lost` says.
            return (.done, deleted ? .note(id: back[0], title: title, body: body, deleted: back[2] == "made", folder: folder) : nil)
        case let .entry(kind, old, deleted, _):
            var want = old
            if deleted { want.id = "" }
            guard let id = items.save(want, kind) else { return (.failed, nil) }
            want.id = id
            guard Self.same(items.one(id, kind), want) else { return (.checkFailed, nil) }
            return (.done, deleted ? .entry(kind, want, deleted: true) : nil)
        case let .cells(book, range, width, values, _):
            return (write(book, range, width, values), nil)
        }
    }

    /// The read-back of a reminder or event: what a change sets.
    static func same(_ back: HandEntry?, _ want: HandEntry) -> Bool {
        guard let back else { return false }
        return back.title == want.title && back.done == want.done && back.start == want.start && back.end == want.end
    }

    /// argv: the title. Every note Notes finds by that name, as id, name, its folder's name and the seconds since it
    /// was last changed (for the choices, R6); the exact one is picked in Swift.
    static let findNotes = """
        on run argv
        tell application id "com.apple.Notes"
        set found to every note whose name is (item 1 of argv)
        set out to {}
        repeat with n in found
        set end of out to (id of n) & (ASCII character 30) & (name of n) & (ASCII character 30) & (name of container of n) & (ASCII character 30) & (((current date) - (modification date of n)) as text)
        end repeat
        end tell
        set AppleScript's text item delimiters to (ASCII character 31)
        return out as text
        end run
        """
    /// argv: the id. Its body, name, folder id and plain text; empty when no note has that id.
    static let readNote = """
        on run argv
        tell application id "com.apple.Notes"
        try
        set n to note id (item 1 of argv)
        on error
        return ""
        end try
        return (body of n) & (ASCII character 31) & (name of n) & (ASCII character 31) & (id of container of n) & (ASCII character 31) & (plaintext of n)
        end tell
        end run
        """
    /// argv: the id, the change (name, body, append, delete), the new value. Returns the name and plain text read
    /// back, or for a delete "gone" unless the note is still in its folder. What it held is read before, by `readNote`.
    static let changeNote = """
        on run argv
        tell application id "com.apple.Notes"
        set n to note id (item 1 of argv)
        set folderID to id of container of n
        if (item 2 of argv) is "delete" then
        delete n
        set seen to "gone"
        try
        if id of container of note id (item 1 of argv) is folderID then set seen to "still"
        end try
        else
        if (item 2 of argv) is "name" then
        set name of n to item 3 of argv
        else if (item 2 of argv) is "append" then
        set body of n to (body of n) & (item 3 of argv)
        else
        set body of n to item 3 of argv
        end if
        set seen to (name of n) & (ASCII character 30) & (plaintext of n)
        end if
        end tell
        return seen
        end run
        """
    /// argv: the id, the old body, its folder's id, and "body" (the body put back) or "again" (it was deleted: moved
    /// back to its folder from Recently Deleted, whole, or else made again there, or in the default folder when that
    /// folder is gone). Returns its id, the name read back, and how: body, moved or made.
    static let restoreNote = """
        on run argv
        tell application id "com.apple.Notes"
        set how to "body"
        if (item 4 of argv) is "again" then
        set n to missing value
        try
        move note id (item 1 of argv) to folder id (item 3 of argv)
        set n to note id (item 1 of argv)
        if id of container of n is not (item 3 of argv) then set n to missing value
        on error
        set n to missing value
        end try
        set how to "moved"
        if n is missing value then
        set how to "made"
        try
        set n to make new note at folder id (item 3 of argv) with properties {body:item 2 of argv}
        on error
        set n to make new note with properties {body:item 2 of argv}
        end try
        end if
        else
        set n to note id (item 1 of argv)
        set body of n to item 2 of argv
        end if
        return (id of n) & (ASCII character 30) & (name of n) & (ASCII character 30) & how
        end tell
        end run
        """
    static let workbooks = """
        on run argv
        tell application id "com.microsoft.Excel"
        set names to name of every workbook
        end tell
        set AppleScript's text item delimiters to (ASCII character 31)
        return names as text
        end run
        """
    /// argv: the workbook's name, the range. Returns what the cells hold, as `fillCells` reads back.
    static let readCells = """
        on run argv
        tell application id "com.microsoft.Excel"
        set held to formula of range (item 2 of argv) of worksheet 1 of workbook (item 1 of argv)
        end tell

        """ + AXSurface.readBack + "\nend run"
}

/// Reminders and events through EventKit: the real `HandItems`. Only open reminders are matched by title (done ones
/// pile up under the same names); events in `Hand.eventWindow` (R6).
struct EventKitItems: HandItems {
    let stop: () -> Bool
    private var store: EKEventStore { AXSurface.store }

    func all(_ kind: HandItem) -> [HandEntry]? {
        switch kind {
        case .note: return nil
        case .reminder:
            guard AXSurface.access(.reminder, stop: stop) else { return nil }
            final class Found: @unchecked Sendable { var reminders: [EKReminder] = [] }  // written once, before the signal
            let fetched = DispatchSemaphore(value: 0), found = Found()
            store.fetchReminders(matching: store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)) {
                found.reminders = $0 ?? []
                fetched.signal()
            }
            guard fetched.wait(timeout: .now() + Hand.scriptTimeout) == .success else { return nil }
            return found.reminders.map(Self.entry)
        case .event:
            guard AXSurface.access(.event, stop: stop) else { return nil }
            // EventKit matches at most four years per search: one search per span, an event crossing two spans once.
            var seen = Set<String>()
            return Hand.spans(Hand.eventWindow()).flatMap { span in
                store.events(matching: store.predicateForEvents(withStart: span.start, end: span.end, calendars: nil))
            }.filter { seen.insert("\($0.eventIdentifier ?? "")|\($0.startDate.timeIntervalSince1970)").inserted }.map(Self.entry)
        }
    }

    func one(_ id: String, _ kind: HandItem) -> HandEntry? {
        switch kind {
        case .note: nil
        case .reminder: (store.calendarItem(withIdentifier: id) as? EKReminder).map(Self.entry)
        case .event: store.event(withIdentifier: id).map(Self.entry)
        }
    }

    func save(_ entry: HandEntry, _ kind: HandItem) -> String? {
        switch kind {
        case .note:
            return nil
        case .reminder:
            let found = entry.id.isEmpty ? nil : store.calendarItem(withIdentifier: entry.id) as? EKReminder
            let item = found ?? EKReminder(eventStore: store)
            if found == nil { Self.setWhole(item, entry) }
            item.title = entry.title
            item.isCompleted = entry.done
            item.dueDateComponents = entry.due
            item.notes = entry.notes
            if item.calendar == nil { item.calendar = store.calendar(withIdentifier: entry.calendar) ?? store.defaultCalendarForNewReminders() }
            do { try store.save(item, commit: true) } catch { return nil }
            return item.calendarItemIdentifier
        case .event:
            guard let start = entry.start, let end = entry.end else { return nil }
            let found = entry.id.isEmpty ? nil : store.event(withIdentifier: entry.id)
            let item = found ?? EKEvent(eventStore: store)
            if found == nil { Self.setWhole(item, entry) }
            item.title = entry.title
            item.startDate = start
            item.endDate = end
            item.isAllDay = entry.allDay
            item.location = entry.location
            item.notes = entry.notes
            if item.calendar == nil { item.calendar = store.calendar(withIdentifier: entry.calendar) ?? store.defaultCalendarForNewEvents }
            do { try store.save(item, span: .thisEvent, commit: true) } catch { return nil }
            return item.eventIdentifier
        }
    }

    func remove(_ id: String, _ kind: HandItem) -> Bool {
        switch kind {
        case .note: return false
        case .reminder:
            guard let item = store.calendarItem(withIdentifier: id) as? EKReminder else { return false }
            return (try? store.remove(item, commit: true)) != nil
        case .event:
            guard let item = store.event(withIdentifier: id) else { return false }
            return (try? store.remove(item, span: .thisEvent, commit: true)) != nil
        }
    }

    private static func entry(_ item: EKReminder) -> HandEntry {
        HandEntry(id: item.calendarItemIdentifier, title: item.title ?? "", done: item.isCompleted, due: item.dueDateComponents,
                  notes: item.notes, calendar: item.calendar?.calendarIdentifier ?? "", calendarName: item.calendar?.title ?? "",
                  repeats: item.hasRecurrenceRules, alarms: alarms(item), priority: item.priority, url: item.url)
    }

    private static func entry(_ item: EKEvent) -> HandEntry {
        HandEntry(id: item.eventIdentifier ?? "", title: item.title ?? "", start: item.startDate, end: item.endDate, allDay: item.isAllDay,
                  location: item.location, notes: item.notes, calendar: item.calendar?.calendarIdentifier ?? "",
                  calendarName: item.calendar?.title ?? "", guests: item.hasAttendees, repeats: item.hasRecurrenceRules,
                  alarms: alarms(item), url: item.url)
    }

    /// Alerts by time; location alerts cannot be carried, and `HandUndo.lost` says so.
    private static func alarms(_ item: EKCalendarItem) -> [HandAlarm] {
        (item.alarms ?? []).filter { $0.structuredLocation == nil }.map { HandAlarm(date: $0.absoluteDate, offset: $0.relativeOffset) }
    }

    /// An item made again (a delete undone) gets what EventKit lets be set (R17). Never on an item that exists: its
    /// location alerts would go.
    private static func setWhole(_ item: EKCalendarItem, _ entry: HandEntry) {
        item.alarms = entry.alarms.map { $0.date.map(EKAlarm.init(absoluteDate:)) ?? EKAlarm(relativeOffset: $0.offset) }
        item.url = entry.url
        (item as? EKReminder)?.priority = entry.priority
    }
}

extension Hand {
    /// The one item titled exactly `title` (case kept, spaces at the ends aside): `notFound` for none, `manyFound`
    /// for more than one. Never a guess.
    static func one<T>(_ items: [T], titled title: String, _ name: (T) -> String) -> (T?, HandEnd) {
        let hits = all(items, titled: title, name)
        return hits.count == 1 ? (hits[0], .done) : (nil, hits.isEmpty ? .notFound : .manyFound)
    }

    /// Every item titled exactly `title`, by the same rule as `one`.
    static func all<T>(_ items: [T], titled title: String, _ name: (T) -> String) -> [T] {
        let want = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.filter { name($0).trimmingCharacters(in: .whitespacesAndNewlines) == want }
    }

    /// R6: where an event is looked for, made or moved to: two years back to five years ahead.
    static func eventWindow(_ now: Date = Date()) -> DateInterval {
        let calendar = Calendar.current
        return DateInterval(start: calendar.date(byAdding: .year, value: -2, to: now)!, end: calendar.date(byAdding: .year, value: 5, to: now)!)
    }

    /// `window` cut into spans of at most one year each: EventKit searches at most four years at once.
    static func spans(_ window: DateInterval) -> [DateInterval] {
        var spans: [DateInterval] = [], start = window.start
        while start < window.end {
            let end = min(Calendar.current.date(byAdding: .year, value: 1, to: start)!, window.end)
            spans.append(DateInterval(start: start, end: end))
            start = end
        }
        return spans
    }
}

extension Hand {
    /// NA.6: the apps on this Mac named `name` (`named(_:in:)`): running ones by their shown name, and those in the
    /// system's application folders (and one folder down) by their shown or file name. Reading only: nothing is
    /// opened or brought forward; `act` does that, after the Never lists, by bundle id.
    static func apps(named name: String) -> [(name: String, bundleID: String)] {
        let want = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !want.isEmpty else { return [] }
        var all = NSWorkspace.shared.runningApplications.compactMap { app in
            app.bundleIdentifier.map { (name: app.localizedName ?? "", bundleID: $0) }
        }
        let files = FileManager.default
        var folders = files.urls(for: .applicationDirectory, in: [.localDomainMask, .systemDomainMask, .userDomainMask])
        folders += folders.map { $0.appending(path: "Utilities") }
        func look(in folder: URL, deeper: Bool) {
            for url in (try? files.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.localizedNameKey])) ?? [] {
                guard url.pathExtension == "app" else {
                    if deeper, (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true { look(in: url, deeper: false) }
                    continue
                }
                let names = [try? url.resourceValues(forKeys: [.localizedNameKey]).localizedName, url.lastPathComponent].compactMap { $0 }
                // Only a name that holds the words is opened for its bundle id.
                guard names.contains(where: { $0.localizedCaseInsensitiveContains(want) }), let id = Bundle(url: url)?.bundleIdentifier else { continue }
                all += names.map { (name: $0, bundleID: id) }
            }
        }
        folders.forEach { look(in: $0, deeper: true) }
        return named(name, in: all)
    }

    /// The apps of `apps` named exactly `name`, any case, ".app" aside; when none is, those whose name ends with
    /// " " + `name` or starts with `name` + " " ("Excel" finds "Microsoft Excel"). One entry per bundle id, under the
    /// first name given for it. A pure rule: more than one entry and the caller stops.
    static func named(_ name: String, in apps: [(name: String, bundleID: String)]) -> [(name: String, bundleID: String)] {
        let want = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !want.isEmpty else { return [] }
        let plain = apps.map { (name: $0.name.hasSuffix(".app") ? String($0.name.dropLast(4)) : $0.name, bundleID: $0.bundleID) }
        var hits = plain.filter { $0.name.lowercased() == want }
        if hits.isEmpty { hits = plain.filter { $0.name.lowercased().hasSuffix(" " + want) || $0.name.lowercased().hasPrefix(want + " ") } }
        var found: [String: String] = [:]
        for hit in hits where found[hit.bundleID] == nil { found[hit.bundleID] = hit.name }
        return found.map { ($0.value, $0.key) }.sorted { $0.bundleID < $1.bundleID }
    }

    /// "B2" and a size as an Excel range ("B2:D5"). Nil for anything but a plain cell address.
    static func range(top: String, rows: Int, columns: Int) -> String? {
        let top = top.uppercased().trimmingCharacters(in: .whitespaces)
        guard rows > 0, columns > 0, top.range(of: #"^[A-Z]{1,3}[1-9][0-9]{0,6}$"#, options: .regularExpression) != nil else { return nil }
        let letters = top.prefix { $0.isLetter }
        guard let row = Int(top.dropFirst(letters.count)) else { return nil }
        let column = letters.unicodeScalars.reduce(0) { $0 * 26 + Int($1.value) - 64 }
        let last = column + columns - 1, lastRow = row + rows - 1
        guard last <= 16_384, lastRow <= 1_048_576 else { return nil }
        var name = "", n = last
        while n > 0 { name = String(UnicodeScalar(UInt8(65 + (n - 1) % 26))) + name; n = (n - 1) / 26 }
        return rows == 1 && columns == 1 ? top : "\(top):\(name)\(lastRow)"
    }

    /// What the cells hold against what was written: the same text, or the same number written another way ("3.50").
    static func sameCells(_ back: [String], _ written: [String]) -> Bool {
        back.count == written.count && zip(back, written).allSatisfy { a, b in
            a == b || (Double(a).map { $0 == Double(b) } ?? false)
        }
    }

    #if DEBUG
    /// Live tests only, never a job's action: removes exactly what scripts made in this process, each by the id its
    /// app gave back at creation, never by a name. Returns the kinds removed and those that could not be.
    func removeTestItems() -> (removed: [String], failed: [String]) {
        var removed: [String] = [], failed: [String] = []
        for made in lock.withLock({ ranHere.compactMap(\.made) }) {
            if AXSurface.remove(made) { removed.append(made.kind) } else { failed.append(made.kind) }
        }
        lock.withLock { ranHere = [] }
        return (removed, failed)
    }

    /// Live tests only: shows a note this process made in its own window (no sidebar, no list), in front.
    func showTestNote(_ id: String) -> Bool {
        guard lock.withLock({ ranHere.contains { $0.made?.kind == "note" && $0.made?.id == id } }) else { return false }
        return AXSurface.osascript("""
            on run argv
            tell application id "com.apple.Notes"
            activate
            show note id (item 1 of argv) separately true
            end tell
            end run
            """, [id], stop: { false }).0 == .done
    }

    /// Live tests only: whether macOS lets Phew act in `app` now, without asking. A fixed word.
    static func permission(_ app: String) -> String {
        switch app {
        case "com.apple.reminders", "com.apple.iCal":
            switch EKEventStore.authorizationStatus(for: app == "com.apple.iCal" ? .event : .reminder) {
            case .fullAccess: return "allowed"
            case .notDetermined: return "notAsked"
            case .writeOnly: return "writeOnly"
            default: return "denied"
            }
        default:
            let target = NSAppleEventDescriptor(bundleIdentifier: app)
            switch AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, false) {
            case noErr: return "allowed"
            case OSStatus(errAEEventWouldRequireUserConsent): return "notAsked"
            case OSStatus(errAEEventNotPermitted): return "denied"
            case OSStatus(procNotFound): return "notRunning"
            case let status: return "status \(status)"
            }
        }
    }
    #endif
}

#if DEBUG
extension AXSurface {
    /// By id only. Notes keeps a deleted note in its Recently Deleted folder for 30 days.
    static func remove(_ made: HandMade) -> Bool {
        switch made.kind {
        case "note":
            return osascript("""
                on run argv
                tell application id "com.apple.Notes" to delete note id (item 1 of argv)
                end run
                """, [made.id], stop: { false }).0 == .done
        case "reminder":
            guard let item = store.calendarItem(withIdentifier: made.id) as? EKReminder else { return false }
            return (try? store.remove(item, commit: true)) != nil
        case "event":
            guard let item = store.event(withIdentifier: made.id) else { return false }
            return (try? store.remove(item, span: .thisEvent, commit: true)) != nil
        case "workbook":
            return osascript("""
                on run argv
                tell application id "com.microsoft.Excel" to close workbook (item 1 of argv) saving no
                end run
                """, [made.id], stop: { false }).0 == .done
        default:
            return false
        }
    }
}
#endif
