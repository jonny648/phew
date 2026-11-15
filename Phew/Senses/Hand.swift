import AppKit
import ApplicationServices
import Carbon.HIToolbox

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

    fileprivate init(number: Int) { self.number = number }

    var end: HandEnd? { lock.withLock { ended } }

    /// The card's Stop or the shortcut. Takes effect before the next action; the one in flight is cut by `Hand.timeout`.
    func stop() { finish(.stopped) }

    /// A mouse or key event seen while the job runs: the user's own ends the job. Phew's own clicks carry `Hand.mark`.
    func seen(_ event: CGEvent) {
        if !Hand.isOwn(event) { finish(.userInput) }
    }

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
                                        chars: step.kind == .set && end == .done ? step.text.count : 0))
        return HandResult(end: end, marked: marked)
    }

    /// Under `lock`. Every guard, then the action.
    private func check(_ step: HandStep, job: HandJob, role: inout String, marked: inout Bool) -> HandEnd {
        guard allowed else { return .off }
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
        // The ceilings.
        let time = now()
        recent.removeAll { time.timeIntervalSince($0) >= 60 }
        if let end = Self.ceiling(actedInJob: job.acted, recent: recent, now: time) { return end }
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
    func bundleID(_ pid: pid_t) -> String? { NSRunningApplication(processIdentifier: pid)?.bundleIdentifier }
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
