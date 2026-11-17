import AppKit
import Carbon.HIToolbox

/// Global shortcut: Right Option + Right Command pressed together, and nothing else (R11), unless the user set
/// another in the Shortcut panel (NA.13): other modifier keys, watched the same way, or modifiers with one key, which
/// the system hands over as a hot key (so the key never reaches the front app).
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
    /// The keys that call him; changed only through `use`.
    private(set) var shortcut: Shortcut
    /// While the Shortcut panel records: nothing starts, and a key shortcut is given back to the system.
    var paused = false {
        didSet { registerKey() }
    }
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init(shortcut: Shortcut = .default, schedule: @escaping Schedule = HotKey.timer, action: @escaping () -> Void) {
        self.press = action
        self.schedule = schedule
        self.shortcut = shortcut
        let right = Shortcut.default
        assert(right.exact(0x50) && !right.exact(0x40) && !right.exact(0x10))
        assert(!right.exact(0x28), "left Option + left Command must not trigger")
        assert(!right.exact(0x52) && !right.exact(0x58), "a third modifier must not trigger")
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
        registerKey()
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

    /// Switches to `new`, from the next press on. False, and the old one kept, when the system will not give its
    /// key to Phew (another app holds it).
    func use(_ new: Shortcut) -> Bool {
        let old = shortcut
        shortcut = new
        if registerKey() { return true }
        shortcut = old
        registerKey()
        return false
    }

    /// A key shortcut is the system's hot key: it reports the press and the release, and keeps the key from the front
    /// app. Modifier-only shortcuts need none. True when there is nothing to register or it registered.
    @discardableResult
    private func registerKey() -> Bool {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
        guard let key = shortcut.key, !paused else { return true }
        if handlerRef == nil {
            let kinds = [kEventHotKeyPressed, kEventHotKeyReleased].map { EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32($0)) }
            InstallEventHandler(GetEventDispatcherTarget(), { _, event, data in
                guard let event, let data else { return OSStatus(eventNotHandledErr) }
                let pressed = GetEventKind(event) == UInt32(kEventHotKeyPressed)
                let hotKey = Unmanaged<HotKey>.fromOpaque(data).takeUnretainedValue()  // lives as long as the app
                MainActor.assumeIsolated { pressed ? hotKey.keyPressed() : hotKey.keyReleased() }
                return noErr
            }, kinds.count, kinds, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
        }
        let id = EventHotKeyID(signature: 0x5068_6577, id: 1)  // "Phew"
        return RegisterEventHotKey(UInt32(key), shortcut.carbonModifiers, id, GetEventDispatcherTarget(), 0, &hotKeyRef) == noErr
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
        let held = shortcut.held(raw)
        if !held { spoiled = false }
        if isDown {
            guard !shortcut.exact(raw) else { return }
            // All still down: a modifier joined, so it is another app's shortcut. Otherwise one was released.
            if held { spoil() } else { release() }
        } else if shortcut.key == nil, shortcut.exact(raw), !spoiled {
            begin()
        }
    }

    /// A key shortcut's press, from the system's hot key: its modifiers, exactly, with its key.
    func keyPressed() {
        guard shortcut.key != nil, !isDown, !spoiled else { return }
        begin()
    }

    /// A key shortcut's key released; letting go of one of its modifiers first is seen by `flags`.
    func keyReleased() {
        guard isDown else { return }
        release()
    }

    private func begin() {
        guard !paused else { return }
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

/// NA.13: the keys that call Phew. Stored in UserDefaults as a setting: which keys, never anything typed. A setting
/// the rules below refuse, or none, is the fixed one: right Option + right Command.
struct Shortcut: Codable, Equatable {
    /// Device-dependent modifier bits: which keys exactly, left or right.
    var keys: UInt
    /// The one key with them, its key code; nil: modifiers only.
    var key: UInt16?
    /// The key's name as it was pressed, for the panel.
    var keyName: String?

    static let `default` = Shortcut(keys: 0x50)
    static let storeKey = "shortcut"

    /// Left Control 0x01, left Shift 0x02, right Shift 0x04, left Command 0x08, right Command 0x10, left Option 0x20,
    /// right Option 0x40, right Control 0x2000.
    static let deviceKeys: UInt = 0x01 | 0x02 | 0x04 | 0x08 | 0x10 | 0x20 | 0x40 | 0x2000
    private static let control = NSEvent.ModifierFlags.control.rawValue, shift = NSEvent.ModifierFlags.shift.rawValue,
                       option = NSEvent.ModifierFlags.option.rawValue, command = NSEvent.ModifierFlags.command.rawValue
    /// Every modifier as the system names it, without left or right; fn among them. Caps Lock is a lock, not a key held.
    private static let anyModifier = control | shift | option | command | NSEvent.ModifierFlags.function.rawValue

    /// The side-free modifiers its keys make.
    var modifiers: UInt {
        [(UInt(0x01 | 0x2000), Self.control), (0x02 | 0x04, Self.shift), (0x20 | 0x40, Self.option), (0x08 | 0x10, Self.command)]
            .reduce(0) { keys & $1.0 != 0 ? $0 | $1.1 : $0 }
    }

    /// All its modifier keys are down, maybe with others.
    func held(_ raw: UInt) -> Bool {
        key == nil ? raw & keys == keys : raw & modifiers == modifiers
    }

    /// Its modifier keys and no other. A key shortcut cannot tell left from right: the system's hot key does not.
    func exact(_ raw: UInt) -> Bool {
        held(raw) && raw & Self.anyModifier & ~modifiers == 0 && (key != nil || raw & Self.deviceKeys == keys)
    }

    var carbonModifiers: UInt32 {
        [(Self.control, controlKey), (Self.shift, shiftKey), (Self.option, optionKey), (Self.command, cmdKey)]
            .reduce(UInt32(0)) { modifiers & $1.0 != 0 ? $0 | UInt32($1.1) : $0 }
    }

    /// Command with Space, Tab, Q, W, C, V, X, Z, A or S: the Mac's and every app's own.
    private static let commandKeys: Set<UInt16> = [49, 48, 12, 13, 8, 9, 7, 6, 0, 1]

    /// Why it cannot be used, in one plain line; nil when it can.
    var refusal: String? {
        guard let key else {
            return keys.nonzeroBitCount < 2 ? "One key alone is too easy to press by chance. Use two or more." : nil
        }
        if modifiers & (Self.control | Self.option | Self.command) == 0 { return "Hold ⌃, ⌥ or ⌘ with the key." }
        if modifiers == Self.command, Self.commandKeys.contains(key) { return "The Mac and most apps already use that one. Try another." }
        return nil
    }

    /// As the panel writes it: "right ⌥ + right ⌘", or "⌃⌥K".
    var name: String {
        if let key {
            let symbols = [(Self.control, "⌃"), (Self.option, "⌥"), (Self.shift, "⇧"), (Self.command, "⌘")]
                .filter { modifiers & $0.0 != 0 }.map(\.1).joined()
            return symbols + (keyName ?? "key \(key)")
        }
        let names: [(UInt, String)] = [(0x01, "left ⌃"), (0x2000, "right ⌃"), (0x20, "left ⌥"), (0x40, "right ⌥"),
                                       (0x02, "left ⇧"), (0x04, "right ⇧"), (0x08, "left ⌘"), (0x10, "right ⌘")]
        return names.filter { keys & $0.0 != 0 }.map(\.1).joined(separator: " + ")
    }

    /// A key's name from its code and the characters it typed: Space, Return, Tab, Delete, Escape, or the letter.
    static func keyName(_ code: UInt16, characters: String?) -> String {
        if let name = [49: "Space", 36: "Return", 48: "Tab", 51: "Delete", 53: "Escape"][code] { return name }
        // From 0xF700 on: the arrow and F keys.
        guard let characters, characters.count == 1, let scalar = characters.unicodeScalars.first,
              scalar.value > 0x20, scalar.value < 0xF700 else { return "key \(code)" }
        return characters.uppercased()
    }

    static func stored(_ defaults: UserDefaults = .standard) -> Shortcut {
        guard let data = defaults.data(forKey: storeKey), let shortcut = try? JSONDecoder().decode(Shortcut.self, from: data),
              shortcut.refusal == nil else { return .default }
        return shortcut
    }

    /// Stores it; the fixed one is stored as nothing.
    func store(_ defaults: UserDefaults = .standard) {
        if self == .default { defaults.removeObject(forKey: Self.storeKey) } else { defaults.set(try? JSONEncoder().encode(self), forKey: Self.storeKey) }
    }
}
