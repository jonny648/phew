import AppKit

/// Global shortcut: Right Option + Right Command pressed together, and nothing else (R11).
/// Modifier keys only, so it is watched through flagsChanged events.
/// A press (released before `Design.Motion.hold`) opens the ask panel; a hold talks (P6.1): `holdStart` once it has
/// been held that long, `holdEnd` when either key is released, `holdCancel` on any other key or modifier, `holdLimit`
/// at `longestHold`. A hold never also fires the press. Another key or modifier with the two is another app's
/// shortcut: nothing starts, nothing is sent, and nothing starts again until both keys are up.
@MainActor
final class HotKey {
    /// Starts a one-shot timer and returns its cancel. Injected so tests do not sleep.
    typealias Schedule = (TimeInterval, @escaping @MainActor () -> Void) -> () -> Void

    /// A hold longer than this ends by itself (R35): the release may never be seen (sleep, lock).
    static let longestHold: TimeInterval = 60

    private let press: () -> Void
    var holdStart: () -> Void = {}
    var holdEnd: () -> Void = {}
    var holdCancel: () -> Void = {}
    /// The hold reached `longestHold`.
    var holdLimit: () -> Void = {}
    private let schedule: Schedule
    private var monitors: [Any] = []
    /// Key presses are watched only while the chord is down, to cancel on any of them. Never otherwise; the key
    /// itself is never kept.
    private var keyMonitors: [Any] = []
    /// Sleep, screen sleep, a switch of user and the screen lock: each ends a hold or a press under way.
    private var sleepObservers: [Any] = []
    private var isDown = false
    /// Another key or modifier came with the two: nothing until both are up again.
    private var spoiled = false
    /// Cancels the hold timer while the chord is down and not yet a hold.
    private var pending: (() -> Void)?
    /// Cancels the ceiling timer during a hold.
    private var ceiling: (() -> Void)?
    private(set) var holding = false

    init(schedule: @escaping Schedule = HotKey.timer, action: @escaping () -> Void) {
        self.press = action
        self.schedule = schedule
        assert(Self.bothRightKeys(0x50) && !Self.bothRightKeys(0x40) && !Self.bothRightKeys(0x10))
        assert(!Self.bothRightKeys(0x28), "left Option + left Command must not trigger")
        assert(!Self.bothRightKeys(0x52) && !Self.bothRightKeys(0x58), "a third modifier must not trigger")
    }

    /// Safe to call again: the global monitor only delivers once Accessibility is granted.
    func install() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        // Global: events going to other apps. Local: events going to Phew's own panels.
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { self.flags($0.modifierFlags.rawValue) }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { self.flags($0.modifierFlags.rawValue); return $0 }) {
            monitors.append(local)
        }
        guard sleepObservers.isEmpty else { return }
        // The Mac sleeps or the screen locks: the release may never be seen (R35).
        let interrupt: @Sendable (Notification) -> Void = { [weak self] _ in MainActor.assumeIsolated { self?.interrupt() } }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            sleepObservers.append(workspace.addObserver(forName: name, object: nil, queue: .main, using: interrupt))
        }
        sleepObservers.append(DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main, using: interrupt))
    }

    /// Device-dependent bits: 0x40 right Option (NX_DEVICERALTKEYMASK), 0x10 right Command (NX_DEVICERCMDKEYMASK).
    private static let rightKeys: UInt = 0x50
    /// Every other key held as a modifier: left Control, left and right Shift, left Command, left Option, right
    /// Control (0x01, 0x02, 0x04, 0x08, 0x20, 0x2000), and Shift, Control and fn. Caps Lock is a lock, not a key held.
    private static let otherKeys: UInt = 0x01 | 0x02 | 0x04 | 0x08 | 0x20 | 0x2000
        | NSEvent.ModifierFlags.shift.rawValue | NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.function.rawValue

    /// Right Option and right Command down, and no other modifier.
    static func bothRightKeys(_ rawFlags: UInt) -> Bool {
        rawFlags & rightKeys == rightKeys && rawFlags & otherKeys == 0
    }

    nonisolated static func timer(_ delay: TimeInterval, _ fire: @escaping @MainActor () -> Void) -> () -> Void {
        // Common modes, so it fires while a menu tracks too.
        let timer = Timer(timeInterval: delay, repeats: false) { _ in MainActor.assumeIsolated(fire) }
        RunLoop.main.add(timer, forMode: .common)
        return timer.invalidate
    }

    private func watchKeys(_ on: Bool) {
        keyMonitors.forEach(NSEvent.removeMonitor)
        keyMonitors = []
        guard on else { return }
        let key: (NSEvent) -> Void = { [weak self] event in self?.keyDown(event.keyCode, isRepeat: event.isARepeat) }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: key) { keyMonitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { key($0); return $0 }) { keyMonitors.append(local) }
    }

    /// A flagsChanged event's raw flags.
    func flags(_ raw: UInt) {
        if raw & Self.rightKeys != Self.rightKeys { spoiled = false }
        if isDown {
            guard !Self.bothRightKeys(raw) else { return }
            // Both still down: a modifier joined, so it is another app's shortcut. Otherwise one was released.
            if raw & Self.rightKeys == Self.rightKeys { spoil() } else { release() }
        } else if Self.bothRightKeys(raw), !spoiled {
            isDown = true
            watchKeys(true)
            // Fire once, not again until one key is released.
            pending = schedule(Design.Motion.hold) { [weak self] in
                guard let self, isDown, pending != nil else { return }
                pending = nil
                holding = true
                ceiling = schedule(Self.longestHold) { [weak self] in self?.limit() }
                holdStart()
            }
        }
    }

    /// Any key pressed while the chord is down, Escape among them: ends a hold without sending, and is not a press
    /// either before the hold. The key code is not kept. A repeat is a key already held before the shortcut, not a
    /// new press: it blocks nothing.
    func keyDown(_ code: UInt16, isRepeat: Bool = false) {
        guard isDown, !isRepeat else { return }
        spoil()
    }

    /// The Mac sleeps or the screen locks (R35): a hold ends unsent, as on any other key, and a press does not fire.
    func interrupt() {
        guard isDown else { return }
        spoil()
    }

    private func release() {
        isDown = false
        watchKeys(false)
        if let cancel = pending {
            cancel()
            pending = nil
            press()
        } else if holding {
            endHold()
            holdEnd()
        }
    }

    /// Not Phew's shortcut after all: nothing is sent, and nothing starts until both keys are up.
    private func spoil() {
        isDown = false
        spoiled = true
        watchKeys(false)
        if holding {
            endHold()
            holdCancel()
        } else if let cancel = pending {
            cancel()
            pending = nil
        }
    }

    /// The ceiling: the hold ends as `holdLimit` says, and the keys, maybe still down, start nothing new.
    private func limit() {
        guard holding else { return }
        ceiling = nil
        holding = false
        spoil()
        holdLimit()
    }

    private func endHold() {
        holding = false
        ceiling?()
        ceiling = nil
    }
}
