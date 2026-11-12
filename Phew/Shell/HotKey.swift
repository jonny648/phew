import AppKit

/// Global shortcut: Right Option + Right Command pressed together.
/// Modifier keys only, so it is watched through flagsChanged events.
@MainActor
final class HotKey {
    private let action: () -> Void
    private var monitors: [Any] = []
    private var isDown = false

    init(action: @escaping () -> Void) {
        self.action = action
        assert(Self.bothRightKeys(0x50) && !Self.bothRightKeys(0x40) && !Self.bothRightKeys(0x10))
        assert(!Self.bothRightKeys(0x28), "left Option + left Command must not trigger")
    }

    /// Safe to call again: the global monitor only delivers once Accessibility is granted.
    func install() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        // Global: events going to other apps. Local: events going to Phew's own panels.
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { self.handle($0) }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { self.handle($0); return $0 }) {
            monitors.append(local)
        }
    }

    /// Device-dependent bits: 0x40 right Option (NX_DEVICERALTKEYMASK), 0x10 right Command (NX_DEVICERCMDKEYMASK).
    static func bothRightKeys(_ rawFlags: UInt) -> Bool {
        rawFlags & 0x50 == 0x50
    }

    private func handle(_ event: NSEvent) {
        let both = Self.bothRightKeys(event.modifierFlags.rawValue)
        if both && !isDown { action() }  // fire once, not again until one key is released
        isDown = both
    }
}
