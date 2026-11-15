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
}

/// What a script makes in Notes, Reminders, Calendar or Excel (docs/13-hand.md 13.2, methods 3 and 4). It works behind
/// the app: nothing is clicked, nothing comes to the front, and it only adds. Each is read back after.
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

    /// The app it acts in, for the Never list.
    var app: String {
        switch self {
        case .note, .append: "com.apple.Notes"
        case .reminder: "com.apple.reminders"
        case .event: "com.apple.iCal"
        case .workbook, .cells: "com.microsoft.Excel"
        }
    }

    /// Characters written, for actions.log.
    var chars: Int {
        switch self {
        case let .note(title, body): title.count + body.count
        case let .append(text): text.count
        case let .reminder(title, _), let .event(title, _, _): title.count
        case .workbook: 0
        case let .cells(_, rows): rows.joined().reduce(0) { $0 + $1.count }
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
}

struct HandResult: Equatable, Sendable {
    var end: HandEnd
    /// The code could not judge it by words (no name, a language with no word list): shown with a mark on the card.
    var marked = false
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

    fileprivate init(number: Int) { self.number = number }

    var end: HandEnd? { lock.withLock { ended } }

    /// The card's Stop or the shortcut. Takes effect before the next action; the one in flight is cut by `Hand.timeout`.
    func stop() { finish(.stopped) }

    /// A mouse or key event seen while the job runs: the user's own ends the job. Phew's own clicks carry `Hand.mark`.
    /// Not while a script runs: it works behind the app, so the user's clicks cannot race it, and the click that
    /// answers macOS's one-time "Phew wants to…" question must not end the job it was asked for (measured, PH.6).
    func seen(_ event: CGEvent) {
        if !Hand.isOwn(event), !lock.withLock({ scripting }) { finish(.userInput) }
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

    var allowed: Bool { defaults.bool(forKey: Self.allowedKey) }

    /// Starts a job. With `watchUser`, the user's own mouse down or key down anywhere ends it.
    @MainActor
    func begin(watchUser: Bool = true) -> HandJob {
        let job = lock.withLock { jobs += 1; return HandJob(number: jobs) }
        if watchUser {
            // shortcut: any app, not only the one acted in; the user touching anything takes the job back.
            let events: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .keyDown]
            if let global = NSEvent.addGlobalMonitorForEvents(matching: events, handler: { [weak job] in
                if let e = $0.cgEvent { job?.seen(e) }
            }) { job.monitors.append(global) }
        }
        return job
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
        var marked = false
        let end = lock.withLock { () -> HandEnd in
            job.steps += 1
            let end = check(step, job: job, role: &role, marked: &marked)
            if end != .done { job.finish(end) }
            return end
        }
        ActionLog.record(ActionLog.line(job: job.number, step: job.steps, kind: step.kind, role: role, ended: end,
                                        marked: marked, ms: Int(Date().timeIntervalSince(start) * 1000),
                                        chars: end != .done ? 0 : step.kind == .set ? step.text.count : step.script?.chars ?? 0))
        return HandResult(end: end, marked: marked)
    }

    /// Under `lock`. Every guard, then the action.
    private func check(_ step: HandStep, job: HandJob, role: inout String, marked: inout Bool) -> HandEnd {
        guard allowed else { return .off }
        if step.kind == .script { return script(step.script, job: job) }
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
    /// involved), the ceilings, then the script, read back by the surface. Nothing on screen is compared.
    private func script(_ script: HandScript?, job: HandJob) -> HandEnd {
        guard let script else { return .failed }
        if let end = NeverList.refusal(bundleID: script.app, pid: 0, ownPID: ownPID, secureInput: surface.secureInput(),
                                       list: list) { return end }
        let time = now()
        if let end = brake(job, time) { return end }
        if let end = job.end { return end }
        job.acted += 1
        recent.append(time)
        job.script(true)
        let (end, made) = surface.run(script, made: job.made, stop: { job.end != nil })
        job.script(false)
        if let made { job.made.append(made) }
        #if DEBUG
        ranHere.append((script, end, made))
        #endif
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
            let source = CGEventSource(stateID: .hidSystemState)
            for type in [CGEventType.leftMouseDown, .leftMouseUp] {
                guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left)
                else { return .failed }
                event.setIntegerValueField(.eventSourceUserData, value: Hand.mark)
                event.postToPid(step.pid)
            }
            return .done
        case .script:
            return .failed  // scripts go through `run`
        }
        switch result {
        case .success: return .done
        case .cannotComplete: return .timeout
        default: return .failed
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
        }
    }

    /// Asks macOS once, the first time, and waits for the user's answer, or Stop, at most `Hand.scriptTimeout`.
    private static func access(_ type: EKEntityType, stop: () -> Bool) -> Bool {
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
