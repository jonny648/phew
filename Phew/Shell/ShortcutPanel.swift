import SwiftUI

/// NA.13: the Shortcut panel records another set of keys to call Phew, or puts the fixed one back. While it records
/// the panel takes the keyboard (the front app stays active), so the keys tried reach no app, and the key watcher
/// pauses. The keys are compared and stored, never logged.
@MainActor
final class ShortcutModel: ObservableObject {
    @Published private(set) var current: Shortcut
    @Published private(set) var recording = false
    /// Why the last keys were refused, in one plain line.
    @Published private(set) var problem: String?
    let defaults: UserDefaults
    /// Hands a shortcut to the key watcher; false when the system will not give Phew its key.
    var apply: (Shortcut) -> Bool = { _ in true }
    /// The key watcher stops while the panel records, and starts again after.
    var pause: (Bool) -> Void = { _ in }
    /// The panel takes the keyboard while it records, and gives it back after.
    var keyboard: (Bool) -> Void = { _ in }
    /// Every modifier key held since recording started: let go of all, and these are the shortcut.
    private var peak: UInt = 0
    private var monitor: Any?

    init(current: Shortcut, defaults: UserDefaults = .standard) {
        self.current = current
        self.defaults = defaults
    }

    func record() {
        guard !recording else { return }
        (problem, peak, recording) = (nil, 0, true)
        pause(true)
        keyboard(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.type == .flagsChanged { flags(event.modifierFlags.rawValue); return event }
            keyDown(event.keyCode, flags: event.modifierFlags.rawValue, characters: event.charactersIgnoringModifiers)
            return nil  // a key tried here does nothing anywhere
        }
    }

    func flags(_ raw: UInt) {
        guard recording else { return }
        let keys = raw & Shortcut.deviceKeys
        if keys != 0 { peak |= keys } else if peak != 0 { finish(Shortcut(keys: peak)) }
    }

    func keyDown(_ code: UInt16, flags raw: UInt, characters: String?) {
        guard recording else { return }
        let keys = raw & Shortcut.deviceKeys
        if code == 53, keys == 0 { return stop() }  // Escape alone: nothing changes
        finish(Shortcut(keys: keys, key: code, keyName: Shortcut.keyName(code, characters: characters)))
    }

    func useDefault() {
        stop()
        save(.default)
    }

    func stop() {
        if end() { keyboard(false) }
    }

    /// The panel closed: the key watcher starts again; the keyboard went back with the panel.
    func closed() { _ = end() }

    private func end() -> Bool {
        guard recording else { return false }
        monitor.map(NSEvent.removeMonitor)
        monitor = nil
        recording = false
        pause(false)
        return true
    }

    private func finish(_ shortcut: Shortcut) {
        stop()
        if let refusal = shortcut.refusal { problem = refusal } else { save(shortcut) }
    }

    private func save(_ shortcut: Shortcut) {
        guard apply(shortcut) else {
            problem = "Another app already uses that one. Try another."
            return
        }
        shortcut.store(defaults)
        (current, problem) = (shortcut, nil)
        shellLog("shortcut changed")
    }
}

/// Shown in a `MenuPanel`: non-activating; it takes the keyboard only while it records.
struct ShortcutView: View {
    @ObservedObject var model: ShortcutModel

    var body: some View {
        PanelList(isEmpty: false, emptyLine: "",
                  help: "Press to type, hold to talk. Use two modifier keys, or ⌃, ⌥ or ⌘ with one other key.",
                  problem: model.problem) {
            Row(title: model.recording ? "Press the new keys…" : model.current.name,
                detail: model.recording ? "Escape to stop" : nil) {
                Button(model.recording ? "Stop" : "Record") { model.recording ? model.stop() : model.record() }
                    .buttonStyle(QuietButton())
            }
            if model.current != .default {
                Row(title: Shortcut.default.name, detail: "The default") {
                    Button("Use the default") { model.useDefault() }.buttonStyle(QuietButton())
                }
            }
        }
    }
}
