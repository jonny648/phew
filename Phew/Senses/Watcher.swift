import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// NA.15 (D4): the watcher for one named thing, off until the user switches it on in the menu. It watches ONE thing:
/// the control under the pointer when the user asked (its text or value, read as `WindowReader` reads the cursor
/// element), or, with no control with text there, the title of that window. Every `interval` it reads that one thing
/// again and compares it with the text at the start. No screenshot, no walk of the window, no model call, no network.
/// It fires once, when the text changes or the thing is gone, then stops. It never acts: it only reads.
/// The text lives in memory only; the log says only that it started or ended, with fixed words.
@MainActor
final class Watcher {
    static let shared = Watcher()
    static let interval: TimeInterval = 5
    /// Two hours at most (D4), decided by code.
    static let most: TimeInterval = 2 * 60 * 60

    /// Why a watch was not started.
    enum Refusal: Equatable { case nothing, secure, neverRead, ownApp, secureInput }

    /// How a watch ended. `changed` and `gone` are the watcher firing; the others end it without a change.
    enum End: Equatable {
        case changed(before: String, now: String)
        case gone(before: String)
        case stopped, replaced, timeUp, asleep, neverRead, secureInput

        var fired: Bool {
            switch self {
            case .changed, .gone: true
            default: false
            }
        }

        /// Fixed words for the log, never the text.
        var word: String {
            switch self {
            case .changed: "changed"
            case .gone: "gone"
            case .stopped: "stopped"
            case .replaced: "replaced"
            case .timeUp: "two hours"
            case .asleep: "sleep or lock"
            case .neverRead: "never read"
            case .secureInput: "secure input"
            }
        }
    }

    struct Watch {
        let app: String
        let bundleID: String
        let target: WatchTarget
        let since: Date
    }

    private(set) var watch: Watch?
    /// The Shell's: a row in the menu, and a notification when they are on.
    var onEnd: ((Watch, End) -> Void)?
    private let surface: any WatchSurface
    private let list: NeverReadList
    private let ownPID: pid_t
    /// False in tests: they call `check(at:)` themselves.
    private let ticks: Bool
    private var loop: Task<Void, Never>?
    private var observers: [(NotificationCenter, Any)] = []

    init(surface: any WatchSurface = AXWatchSurface(), list: NeverReadList = .shared, ownPID: pid_t = getpid(), ticks: Bool = true) {
        self.surface = surface
        self.list = list
        self.ownPID = ownPID
        self.ticks = ticks
    }

    /// Starts watching the thing under `point` (Accessibility coordinates) in the app `bundleID`; nil when it started.
    /// A watch already running is ended first (one at a time), after the checks pass.
    func start(app: String, bundleID: String, at point: CGPoint, now: Date = Date()) -> Refusal? {
        guard !list.refuses(bundleID) else { return .neverRead }
        guard let pid = surface.pid(of: bundleID) else { return .nothing }
        guard pid != ownPID else { return .ownApp }
        guard !surface.secureInput() else { return .secureInput }
        guard let target = surface.target(at: point, pid: pid) else { return .nothing }
        guard !target.secure else { return .secure }
        end(.replaced)
        watch = Watch(app: app, bundleID: bundleID, target: target, since: now)
        shellLog("watcher started, \(target.window ? "a window title" : "a control")")
        if ticks {
            loop = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(Self.interval))
                    guard !Task.isCancelled, let self, check(at: Date()) == nil, watch != nil else { return }
                }
            }
        }
        // The Mac sleeps, the screen locks or another user takes it: the watch ends (as the shortcut's hold does, R35).
        let asleep: @Sendable (Notification) -> Void = { [weak self] _ in MainActor.assumeIsolated { self?.end(.asleep) } }
        let workspace = NSWorkspace.shared.notificationCenter, distributed = DistributedNotificationCenter.default()
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append((workspace, workspace.addObserver(forName: name, object: nil, queue: .main, using: asleep)))
        }
        observers.append((distributed, distributed.addObserver(forName: Notification.Name("com.apple.screenIsLocked"), object: nil,
                                                               queue: .main, using: asleep)))
        return nil
    }

    /// One look at the one thing. Ends the watch and returns how, or nil while it goes on (or none runs).
    /// A refused app and secure input are checked before anything is read.
    @discardableResult
    func check(at now: Date) -> End? {
        guard let watch else { return nil }
        let before = watch.target.text
        let end: End?
        if now.timeIntervalSince(watch.since) >= Self.most {
            end = .timeUp
        } else if list.refuses(watch.bundleID) {
            end = .neverRead
        } else if surface.secureInput() {
            end = .secureInput
        } else if let text = surface.read(watch.target) {
            end = text == before ? nil : .changed(before: before, now: text)
        } else {
            end = .gone(before: before)
        }
        if let end { self.end(end) }
        return end
    }

    /// Ends the watch, if one runs: Stop, Quit, sleep or lock, a replacement, or `check`. The text goes with it.
    func end(_ end: End) {
        guard let watch else { return }
        self.watch = nil
        loop?.cancel()
        loop = nil
        observers.forEach { $0.0.removeObserver($0.1) }
        observers = []
        shellLog("watcher ended: \(end.word)")
        onEnd?(watch, end)
    }
}

/// The one thing watched, and its text at the start. Memory only.
struct WatchTarget {
    /// The text when the watch started.
    var text: String
    /// The window's title is watched: no control with text was under the pointer.
    var window = false
    /// A secure field: never watched, its text never read.
    var secure = false
    /// The Accessibility element read again; nil for a fake.
    var element: AXUIElement? = nil
}

/// What the watcher reads, behind a protocol so tests use a fake surface.
protocol WatchSurface {
    func pid(of bundleID: String) -> pid_t?
    /// The thing under `point` in app `pid`: the control there when it has text, else its window's title. Nil: nothing.
    func target(at point: CGPoint, pid: pid_t) -> WatchTarget?
    /// Its text now; nil once the control or its window is gone.
    func read(_ target: WatchTarget) -> String?
    func secureInput() -> Bool
}

/// The real surface: one element, through the Accessibility API, read only.
struct AXWatchSurface: WatchSurface {
    func pid(of bundleID: String) -> pid_t? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first?.processIdentifier
    }

    func target(at point: CGPoint, pid: pid_t) -> WatchTarget? {
        // The app's own element at the point: never another app's, never a refused app's (`WindowReader.element`).
        guard let element = WindowReader.element(at: point, pid: pid), let control = Self.control(element) else { return nil }
        if control.role == "AXSecureTextField" { return WatchTarget(text: "", secure: true) }
        let text = Self.text(control)
        if !text.isEmpty { return WatchTarget(text: text, element: element) }
        guard let value = Self.attribute(element, kAXWindowAttribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        let window = value as! AXUIElement  // its type checked above
        guard let title = Self.attribute(window, kAXTitleAttribute) as? String, !title.isEmpty else { return nil }
        return WatchTarget(text: title, window: true, element: window)
    }

    func read(_ target: WatchTarget) -> String? {
        guard let element = target.element else { return nil }
        var role: CFTypeRef?
        switch AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) {
        case .success: break
        // shortcut: a busy app (no answer within the messaging timeout) counts as unchanged this time; it is read
        // again in 5 seconds. Gone only when the element is invalid or its app has quit.
        case .cannotComplete where Self.running(element): return target.text
        default: return nil
        }
        if target.window { return Self.attribute(element, kAXTitleAttribute) as? String ?? "" }
        return Self.control(element).map(Self.text)
    }

    func secureInput() -> Bool { IsSecureEventInputEnabled() }

    /// The element as `WindowReader` keeps the cursor element: a secure field is named, never read.
    private static func control(_ element: AXUIElement) -> CursorElement? {
        guard let role = attribute(element, kAXRoleAttribute) as? String else { return nil }
        let label = attribute(element, kAXTitleAttribute) as? String ?? attribute(element, kAXDescriptionAttribute) as? String ?? ""
        return WindowReader.cursor(role: role, subrole: attribute(element, kAXSubroleAttribute) as? String ?? "", label: label, frame: nil) {
            let value = attribute(element, kAXValueAttribute)
            return value as? String ?? (value as? NSNumber)?.stringValue
        }
    }

    private static func text(_ control: CursorElement) -> String {
        [control.label, control.value].filter { !$0.isEmpty }.joined(separator: "\n")
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }

    private static func running(_ element: AXUIElement) -> Bool {
        var pid: pid_t = 0
        return AXUIElementGetPid(element, &pid) == .success && NSRunningApplication(processIdentifier: pid) != nil
    }
}
