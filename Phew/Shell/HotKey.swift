import AppKit

/// Global shortcut: Right Option + Right Command pressed together.
/// Modifier keys only, so it is watched through flagsChanged events.
/// A press (released before `Design.Motion.hold`) opens the ask panel; a hold talks (P6.1): `holdStart` once it has
/// been held that long, `holdEnd` when either key is released, `holdCancel` on Escape. A hold never also fires the press.
@MainActor
final class HotKey {
    /// Starts a one-shot timer and returns its cancel. Injected so tests do not sleep.
    typealias Schedule = (TimeInterval, @escaping @MainActor () -> Void) -> () -> Void

    private let press: () -> Void
    var holdStart: () -> Void = {}
    var holdEnd: () -> Void = {}
    var holdCancel: () -> Void = {}
    private let schedule: Schedule
    private var monitors: [Any] = []
    /// Key presses are watched only while the chord is down, to catch Escape. Never otherwise.
    private var escapeMonitors: [Any] = []
    private var isDown = false
    /// Cancels the hold timer while the chord is down and not yet a hold.
    private var pending: (() -> Void)?
    private(set) var holding = false

    init(schedule: @escaping Schedule = HotKey.timer, action: @escaping () -> Void) {
        self.press = action
        self.schedule = schedule
        assert(Self.bothRightKeys(0x50) && !Self.bothRightKeys(0x40) && !Self.bothRightKeys(0x10))
        assert(!Self.bothRightKeys(0x28), "left Option + left Command must not trigger")
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
    }

    /// Device-dependent bits: 0x40 right Option (NX_DEVICERALTKEYMASK), 0x10 right Command (NX_DEVICERCMDKEYMASK).
    static func bothRightKeys(_ rawFlags: UInt) -> Bool {
        rawFlags & 0x50 == 0x50
    }

    nonisolated static func timer(_ delay: TimeInterval, _ fire: @escaping @MainActor () -> Void) -> () -> Void {
        // Common modes, so it fires while a menu tracks too.
        let timer = Timer(timeInterval: delay, repeats: false) { _ in MainActor.assumeIsolated(fire) }
        RunLoop.main.add(timer, forMode: .common)
        return timer.invalidate
    }

    private func watchEscape(_ on: Bool) {
        escapeMonitors.forEach(NSEvent.removeMonitor)
        escapeMonitors = []
        guard on else { return }
        let isEscape: (NSEvent) -> Void = { [weak self] event in if event.keyCode == 53 { self?.escape() } }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: isEscape) { escapeMonitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { isEscape($0); return $0 }) { escapeMonitors.append(local) }
    }

    /// A flagsChanged event's raw flags.
    func flags(_ raw: UInt) {
        let both = Self.bothRightKeys(raw)
        defer { isDown = both }
        if both != isDown { watchEscape(both) }
        if both && !isDown {
            // Fire once, not again until one key is released.
            pending = schedule(Design.Motion.hold) { [weak self] in
                guard let self, isDown, pending != nil else { return }
                pending = nil
                holding = true
                holdStart()
            }
        } else if !both && isDown {
            if let cancel = pending {
                cancel()
                pending = nil
                press()
            } else if holding {
                holding = false
                holdEnd()
            }
            // Neither: Escape already ended the hold; the release does nothing.
        }
    }

    /// Escape: ends a hold without sending. Not a press either, while the chord is still down before the hold.
    func escape() {
        if holding {
            holding = false
            holdCancel()
        } else if let cancel = pending {
            cancel()
            pending = nil
        }
    }
}
