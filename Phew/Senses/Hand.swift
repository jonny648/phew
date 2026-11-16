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
    /// Notes: lines added at the end of the note this job made.
    case append(text: String)
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
        case let .append(text), let .rename(_, _, text), let .noteBody(_, text): text.count
        case let .reminder(title, _), let .event(title, _, _): title.count
        case .workbook, .complete, .move, .delete, .restore: 0
        case let .cells(_, rows), let .changeCells(_, _, rows): rows.joined().reduce(0) { $0 + $1.count }
        }
    }

    /// A change, delete or restore of what exists: run by `HandSurface.change`, not `run`.
    var changes: Bool {
        switch self {
        case .note, .append, .reminder, .event, .workbook, .cells: false
        default: true
        }
    }

    /// The item a change or delete names, by kind and exact title; nil for the rest.
    var target: (HandItem, String)? {
        switch self {
        case let .rename(item, title, _), let .delete(item, title): (item, title)
        case let .noteBody(title, _): (.note, title)
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
    /// What the "cannot be undone" class needs: invitations go out, a repeat cannot be put back whole.
    var guests = false
    var repeats = false
}

/// What a change or delete replaced, kept in its job so Undo puts it back (N2.3). Memory only: never written to disk
/// or a log, dropped with the job.
enum HandKept: Sendable, Equatable {
    /// A note's body as Notes' HTML, and its title for the read-back. `deleted`: Undo makes it again.
    case note(id: String, title: String, body: String, deleted: Bool = false)
    case entry(HandItem, HandEntry, deleted: Bool = false)
    /// What the cells held, row by row, as typed.
    case cells(book: String, range: String, width: Int, values: [String])

    var app: String {
        switch self {
        case .note: HandItem.note.app
        case let .entry(item, _, _): item.app
        case .cells: "com.microsoft.Excel"
        }
    }

    /// The item's id in its app; nil for cells.
    var id: String? {
        switch self {
        case let .note(id, _, _, _): id
        case let .entry(_, entry, _): entry.id
        case .cells: nil
        }
    }

    /// The same, for the item now under `id`: one deleted and made again by Undo has a new id.
    func with(id: String) -> HandKept {
        switch self {
        case let .note(_, title, body, deleted): return .note(id: id, title: title, body: body, deleted: deleted)
        case let .entry(item, entry, deleted):
            var entry = entry
            entry.id = id
            return .entry(item, entry, deleted: deleted)
        case .cells: return self
        }
    }
}

/// What the code reads of an item before changing or deleting it, for the "cannot be undone" class.
struct HandFacts: Sendable, Equatable {
    var guests = false
    var repeats = false
}

/// How an action ended: `done`, or why not, in one fixed word (written to actions.log as is).
enum HandEnd: String, Sendable, CaseIterable {
    case done
    /// Acting is not allowed (the switch is off).
    case off
    /// The Never list (NeverList).
    case secureField, secureInput, neverReadApp, neverActApp, ownApp, password, paying, signIn
    /// The runaway brake.
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
}

/// One job: the steps of one request. Ends once, for good: on Stop, on the user's own input, or on the first step
/// that does not end `done`. Every later step then returns that end without acting, so nothing is ever retried.
final class HandJob: @unchecked Sendable {  // state under `lock`
    let number: Int
    private let lock = NSLock()
    private var ended: HandEnd?
    fileprivate var steps = 0
    fileprivate var acted = 0
    fileprivate var dialogs: [pid_t: Int] = [:]
    fileprivate var windowExpected = false
    fileprivate var monitors: [Any] = []
    /// What this job's scripts made, oldest first: `append` and `cells` act only on these.
    fileprivate(set) var made: [HandMade] = []
    /// The app the job began in: where the user was, and where `Hand.back` returns at the end.
    let start: pid_t
    private var current: pid_t  // under `lock`
    /// A research agent's job (PA.4), not one the user watches: what cannot be undone waits for a confirm.
    let agent: Bool
    private var keptValues: [HandKept] = []  // under `lock`

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
    func windowTitle(of element: AnyObject) -> String
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
    /// The app whose window or menu is at `point` (where a click lands), nil when not known. Reads only the owner.
    func owner(at point: CGPoint) -> pid_t?
    /// The app with this bundle id, when it runs.
    func running(_ bundleID: String) -> pid_t?
    /// Brings the app to the front, launching it if needed, and waits until it is in front, or `stop`, at most
    /// `Hand.frontTimeout`. Returns how it ended and the app's pid.
    func activate(_ bundleID: String, stop: @escaping () -> Bool) -> (HandEnd, pid_t?)
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
    private let lock = NSLock()
    private var recent: [Date] = []
    private var jobs = 0
    #if DEBUG
    /// Every script run in this process, how it ended and what it made: for the live tests' report and clean-up
    /// (`removeTestItems`). Memory only.
    private(set) var ranHere: [(script: HandScript, end: HandEnd, made: HandMade?)] = []
    #endif

    /// Tests pass a throwaway defaults suite, a fake surface or clock, and may stand in for Phew's own pid.
    init(defaults: UserDefaults = .standard, surface: HandSurface = AXSurface(), list: NeverReadList = .shared,
         ownPID: pid_t = getpid(), now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.surface = surface
        self.list = list
        self.ownPID = ownPID
        self.now = now
    }

    /// On unless the menu's switch turned it off (the user's word of 15 November: no Allow to press).
    var allowed: Bool { defaults.object(forKey: Self.allowedKey) as? Bool ?? true }

    /// Starts a job in `app`, the app the user asked in. With `watchUser`, the user's own mouse down or key down in
    /// the app the job works in ends it (`seen`). `agent`: a research agent's job, in the background.
    @MainActor
    func begin(watchUser: Bool = true, in app: pid_t = 0, agent: Bool = false) -> HandJob {
        let job = lock.withLock { jobs += 1; return HandJob(number: jobs, app: app, agent: agent) }
        if watchUser {
            let events: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .keyDown]
            if let global = NSEvent.addGlobalMonitorForEvents(matching: events, handler: { [weak self, weak job] in
                if let e = $0.cgEvent, let job { self?.seen(e, by: job) }
            }) { job.monitors.append(global) }
        }
        return job
    }

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

    /// The runaway brake: a pure rule, so the counters are unit-tested.
    static func ceiling(actedInJob: Int, recent: [Date], now: Date) -> HandEnd? {
        if actedInJob >= perJob { return .jobCeiling }
        if recent.filter({ now.timeIntervalSince($0) < 60 }).count >= perMinute { return .minuteCeiling }
        return nil
    }

    /// The one acting function. Blocks for at most about `timeout`: call it off the main thread, one step at a time.
    func act(_ step: HandStep, in job: HandJob) -> HandResult {
        if let end = job.end { return HandResult(end: end) }  // the job is over: no step, no retry
        let start = Date()
        var role = step.role
        var marked = false, final = false
        let end = lock.withLock { () -> HandEnd in
            job.steps += 1
            let end = check(step, job: job, role: &role, marked: &marked, final: &final)
            if end != .done { job.finish(end) }
            return end
        }
        // The level, as before: marked or in the class. No word of what changed.
        ActionLog.record(ActionLog.line(job: job.number, step: job.steps, kind: step.kind, role: role, ended: end,
                                        marked: marked || final, ms: Int(Date().timeIntervalSince(start) * 1000),
                                        chars: end != .done ? 0 : step.kind == .set ? step.text.count : step.script?.chars ?? 0))
        return HandResult(end: end, marked: marked, final: final)
    }

    /// Under `lock`. Every guard, then the action.
    private func check(_ step: HandStep, job: HandJob, role: inout String, marked: inout Bool, final: inout Bool) -> HandEnd {
        guard allowed else { return .off }
        if step.kind == .script { return script(step, job: job, final: &final) }
        if step.kind == .front { return front(step.app, job: job) }
        // The Never list, first the app, before anything of it is read.
        if let end = NeverList.refusal(bundleID: surface.bundleID(step.pid), pid: step.pid, ownPID: ownPID,
                                       secureInput: surface.secureInput(), list: list) { return end }
        let point = CGPoint(x: step.frame.midX, y: step.frame.midY)
        let element = step.kind == .pick ? surface.menuItem(step.menuPath, pid: step.pid) : surface.element(at: point, pid: step.pid)
        let seen = element.flatMap(surface.read)
        // A click on a bare canvas may find no element; anything else needs one.
        if seen == nil && !(step.kind == .click && step.role.isEmpty) { return .gone }
        if let seen { role = seen.role }
        let texts = [step.name, seen?.name ?? "", element.map(surface.windowTitle) ?? ""] + step.menuPath
        if let end = NeverList.refusal(role: seen?.role ?? "", subrole: seen?.subrole ?? "",
                                       focusedSecure: surface.focusedIsSecure(step.pid), texts: texts) { return end }
        marked = NeverList.careful(name: step.kind == .pick ? step.menuPath.last ?? "" : step.name, texts: texts)
        final = NeverList.final(step, names: [step.name, seen?.name ?? ""] + step.menuPath,
                                replaces: step.kind == .set && !(seen?.value ?? "").isEmpty, agent: job.agent)
        if final, job.agent { return .needsConfirm }
        let time = now()
        if let end = brake(job, time) { return end }
        // What is there now against what the look saw.
        guard surface.frontPID() == step.pid else { return .frontChanged }
        let dialogs = surface.dialogs(step.pid)
        if job.windowExpected || job.dialogs[step.pid] == nil {
            job.dialogs[step.pid] = dialogs
        } else if dialogs > job.dialogs[step.pid]! {
            return .surprise
        }
        if let seen, step.kind != .pick, !matches(seen, step) { return .moved }
        // Stop pressed meanwhile: nothing is sent.
        if let end = job.end { return end }
        job.acted += 1
        job.windowExpected = step.opensWindow
        recent.append(time)
        let sent = surface.send(step, to: element)
        guard sent == .done else { return sent }
        // A set value is read back; the look after the step checks the rest (PH.7).
        if step.kind == .set, let element, surface.read(element)?.value != step.text { return .checkFailed }
        return .done
    }

    /// Under `lock`. The ceilings.
    private func brake(_ job: HandJob, _ time: Date) -> HandEnd? {
        recent.removeAll { time.timeIntervalSince($0) >= 60 }
        return Self.ceiling(actedInJob: job.acted, recent: recent, now: time)
    }

    /// Under `lock`. A script: the Never list for the app it acts in (it is not the front app, and no control is
    /// involved), the ceilings, the "cannot be undone" class (an agent's waits for a confirm), then the script, read
    /// back by the surface. Nothing on screen is compared.
    private func script(_ step: HandStep, job: HandJob, final: inout Bool) -> HandEnd {
        guard let script = step.script else { return .failed }
        if let end = NeverList.refusal(bundleID: script.app, pid: 0, ownPID: ownPID, secureInput: surface.secureInput(),
                                       list: list) { return end }
        let time = now()
        if let end = brake(job, time) { return end }
        if let end = job.end { return end }
        final = NeverList.final(step, facts: script.target == nil ? HandFacts() : surface.facts(script), agent: job.agent)
        if final, job.agent { return .needsConfirm }
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
        ranHere.append((script, end, made))
        #endif
        return end
    }

    /// Undo on the card (N2.3): puts back what the job's changes and deletes replaced, newest first, each a `restore`
    /// script through `act` in a job of its own, so every gate holds. Once: the kept values go with it. Blocks: off
    /// the main thread.
    func undo(_ job: HandJob) -> HandEnd {
        var kept = Array(job.takeKept().reversed())
        let undo = lock.withLock { jobs += 1; return HandJob(number: jobs, app: 0) }
        var end = HandEnd.done
        for i in kept.indices where end == .done {
            end = act(HandStep(kind: .script, pid: 0, script: .restore(kept[i])), in: undo).end
            // A deleted item made again has a new id: its older changes are put back on that one, never a copy.
            if let made = undo.takeKept().first?.id, let old = kept[i].id {
                for j in kept.indices.dropFirst(i + 1) where kept[j].id == old { kept[j] = kept[j].with(id: made) }
            }
        }
        undo.finish(.stopped)
        return end
    }

    /// Under `lock`. Another app to the front, the one focus exception (CLAUDE.md): the Never list for that app before
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
    /// the front. Not when the user took over (their own input, or another app they brought to the front): he
    /// leaves them where they are. The switch and own-app check apply and it is logged like any action; no ceiling,
    /// so a job stopped at one still returns; no Never list, as the user was in that app and nothing of it is read.
    /// Nil when there is nothing to return. Blocks up to `frontTimeout`: off the main thread.
    @discardableResult
    func back(_ job: HandJob) -> HandEnd? {
        let (home, app) = (job.start, job.app)
        guard home != 0, app != home, job.end != .userInput, surface.frontPID() == app else { return nil }
        let begun = Date()
        let end = lock.withLock { () -> HandEnd in
            job.steps += 1
            guard allowed else { return .off }
            if home == ownPID { return .ownApp }
            guard let bundle = surface.bundleID(home) else { return .failed }
            let (end, pid) = surface.activate(bundle, stop: { false })
            if end == .done, let pid { job.moved(to: pid) }
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
        if !SecretsFilter.isSecure(role: seen.role, subrole: seen.subrole) {
            seen.value = attribute(el, kAXValueAttribute) as? String
        }
        return seen
    }

    func windowTitle(of object: AnyObject) -> String {
        attribute(object as! AXUIElement, kAXWindowAttribute).flatMap(asElement).flatMap { attribute($0, kAXTitleAttribute) as? String } ?? ""
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
            guard let (window, bounds) = Self.window(of: step.pid, at: point) else { return .failed }
            let location = Self.clickLocation(point, in: bounds, mainHeight: NSScreen.screens.first?.frame.height ?? 0)
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                guard let event = NSEvent.mouseEvent(with: type, location: location, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                                     windowNumber: window, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)?.cgEvent
                else { return .failed }
                event.setIntegerValueField(.eventSourceUserData, value: Hand.mark)
                event.postToPid(step.pid)
            }
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

    /// The point inside `bounds` (both top-left origin) as `NSEvent.mouseEvent` must be given it for another app's
    /// window: flipped against the main screen's height, as if the window sat at its top-left corner (measured, PL.1).
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
        case let .append(text):
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
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/osascript")
        process.arguments = source.split(separator: "\n").flatMap { ["-e", String($0)] } + args
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        do { try process.run() } catch { return (.failed, "") }
        let deadline = Date() + Hand.scriptTimeout
        while process.isRunning {
            if stop() { process.terminate(); return (.stopped, "") }
            if Date() > deadline { process.terminate(); return (.timeout, "") }
            Thread.sleep(forTimeInterval: 0.05)
        }
        guard process.terminationStatus == 0 else {
            let error = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            #if DEBUG
            // Only the error's number and the script line it hit, never its words (they can quote a value).
            let number = error.firstMatch(of: /\((-?[0-9]+)\)\s*$/).map { String($0.1) } ?? "none"
            let at = error.firstMatch(of: /([0-9]+):[0-9]+: execution error/).map { String($0.1) } ?? "?"
            shellLog("script failed: error \(number) at char \(at)")
            #endif
            return (error.contains("-1743") ? .noAccess : .failed, "")
        }
        return (.done, String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines))
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
            return (.failed, nil)  // adds go through `run`
        }
    }

    /// Notes: found by title in Notes, then picked here by the exact title; changed by id. `check` gets the name and
    /// plain text read back after the change ("gone" for a delete).
    private func note(_ title: String, _ mode: String, _ value: String, check: (String, String) -> Bool) -> (HandEnd, HandKept?) {
        let (found, list) = script(Self.findNotes, [title])
        guard found == .done else { return (found, nil) }
        let notes = list.isEmpty ? [] : list.components(separatedBy: "\u{1F}").compactMap { pair -> (id: String, name: String)? in
            let parts = pair.components(separatedBy: "\u{1E}")
            return parts.count == 2 ? (parts[0], parts[1]) : nil
        }
        let (hit, match) = Hand.one(notes, titled: title) { $0.name }
        guard let id = hit?.id else { return (match, nil) }
        let (end, out) = script(Self.changeNote, [id, mode, value])
        guard end == .done else { return (end, nil) }
        // The old body, the old name, then the read-back.
        let parts = out.split(separator: "\u{1F}", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3 else { return (.checkFailed, nil) }
        let kept = HandKept.note(id: id, title: parts[1], body: parts[0], deleted: mode == "delete")
        let back = parts[2].split(separator: "\u{1E}", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        return (check(back[0], back.count == 2 ? back[1] : back[0]) ? .done : .checkFailed, kept)
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
        return (Self.same(items.one(item.id, kind), item) ? .done : .checkFailed, .entry(kind, old))
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
        return (write(name, range, width, values), .cells(book: name, range: range, width: width, values: old))
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
        case let .note(id, title, body, deleted):
            let (end, out) = script(Self.restoreNote, [deleted ? "" : id, body])
            guard end == .done else { return (end, nil) }
            let back = out.split(separator: "\u{1E}", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
            guard back.count == 2, back[1] == title else { return (.checkFailed, nil) }
            return (.done, deleted ? .note(id: back[0], title: title, body: body) : nil)
        case let .entry(kind, old, deleted):
            var want = old
            if deleted { want.id = "" }
            guard let id = items.save(want, kind) else { return (.failed, nil) }
            want.id = id
            guard Self.same(items.one(id, kind), want) else { return (.checkFailed, nil) }
            return (.done, deleted ? .entry(kind, want) : nil)
        case let .cells(book, range, width, values):
            return (write(book, range, width, values), nil)
        }
    }

    /// The read-back of a reminder or event: what a change sets.
    static func same(_ back: HandEntry?, _ want: HandEntry) -> Bool {
        guard let back else { return false }
        return back.title == want.title && back.done == want.done && back.start == want.start && back.end == want.end
    }

    /// argv: the title. Every note Notes finds by that name, as id and name; the exact one is picked in Swift.
    static let findNotes = """
        on run argv
        tell application id "com.apple.Notes"
        set found to every note whose name is (item 1 of argv)
        set out to {}
        repeat with n in found
        set end of out to (id of n) & (ASCII character 30) & (name of n)
        end repeat
        end tell
        set AppleScript's text item delimiters to (ASCII character 31)
        return out as text
        end run
        """
    /// argv: the id, the change (name, body, delete), the new value. Returns the old body, the old name, then the
    /// name and plain text read back, or for a delete "gone" unless the note is still in its folder.
    static let changeNote = """
        on run argv
        tell application id "com.apple.Notes"
        set n to note id (item 1 of argv)
        set heldBody to body of n
        set heldName to name of n
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
        else
        set body of n to item 3 of argv
        end if
        set seen to (name of n) & (ASCII character 30) & (plaintext of n)
        end if
        end tell
        return heldBody & (ASCII character 31) & heldName & (ASCII character 31) & seen
        end run
        """
    /// argv: the id (empty: the note was deleted, made again) and the old body. Returns its id and the name read back.
    static let restoreNote = """
        on run argv
        tell application id "com.apple.Notes"
        if (item 1 of argv) is "" then
        set n to make new note with properties {body:item 2 of argv}
        else
        set n to note id (item 1 of argv)
        set body of n to item 2 of argv
        end if
        return (id of n) & (ASCII character 30) & (name of n)
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
/// pile up under the same names); events from 30 days back to a year ahead.
// shortcut: a fixed window for events; widen it if a live job needs an event further out.
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
            let now = Date()
            let window = store.predicateForEvents(withStart: now.addingTimeInterval(-30 * 86_400), end: now.addingTimeInterval(365 * 86_400), calendars: nil)
            return store.events(matching: window).map(Self.entry)
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
            let item = (entry.id.isEmpty ? nil : store.calendarItem(withIdentifier: entry.id) as? EKReminder) ?? EKReminder(eventStore: store)
            item.title = entry.title
            item.isCompleted = entry.done
            item.dueDateComponents = entry.due
            item.notes = entry.notes
            if item.calendar == nil { item.calendar = store.calendar(withIdentifier: entry.calendar) ?? store.defaultCalendarForNewReminders() }
            do { try store.save(item, commit: true) } catch { return nil }
            return item.calendarItemIdentifier
        case .event:
            guard let start = entry.start, let end = entry.end else { return nil }
            let item = (entry.id.isEmpty ? nil : store.event(withIdentifier: entry.id)) ?? EKEvent(eventStore: store)
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
                  notes: item.notes, calendar: item.calendar?.calendarIdentifier ?? "", repeats: item.hasRecurrenceRules)
    }

    private static func entry(_ item: EKEvent) -> HandEntry {
        HandEntry(id: item.eventIdentifier ?? "", title: item.title ?? "", start: item.startDate, end: item.endDate, allDay: item.isAllDay,
                  location: item.location, notes: item.notes, calendar: item.calendar?.calendarIdentifier ?? "",
                  guests: item.hasAttendees, repeats: item.hasRecurrenceRules)
    }
}

extension Hand {
    /// The one item titled exactly `title` (case kept, spaces at the ends aside): `notFound` for none, `manyFound`
    /// for more than one. Never a guess.
    static func one<T>(_ items: [T], titled title: String, _ name: (T) -> String) -> (T?, HandEnd) {
        let want = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let hits = items.filter { name($0).trimmingCharacters(in: .whitespacesAndNewlines) == want }
        return hits.count == 1 ? (hits[0], .done) : (nil, hits.isEmpty ? .notFound : .manyFound)
    }
}

extension Hand {
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
