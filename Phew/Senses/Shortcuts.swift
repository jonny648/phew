import Foundation

/// NB.5: one run of one of the user's Shortcuts, asked for by an agent. Held in memory only; the input is never logged.
struct ShortcutCall: Sendable, Equatable {
    /// The shortcut's name exactly as `shortcuts list` gave it.
    var name: String
    /// Text handed to the shortcut as its input; empty for none.
    var input = ""
}

/// NB.5: the user's ticks in "Shortcuts he may run", by name, in UserDefaults. Off by default: a shortcut not ticked
/// can never run, whatever the model asks; the Hand reads this list itself at the moment of running (Phew's code
/// decides, never the model). "Safe" is the user's second mark: such a shortcut runs at once even for a background
/// task; any other is in the "cannot be undone or leaves your Mac" class. Names only, never what a shortcut did.
struct ShortcutTicks: @unchecked Sendable {  // UserDefaults is thread-safe
    static let allowedKey = "shortcutsAllowed", safeKey = "shortcutsSafe"
    var defaults: UserDefaults = .standard

    var allowed: [String] { defaults.stringArray(forKey: Self.allowedKey) ?? [] }
    /// Only ticked ones count as safe.
    var safe: [String] { (defaults.stringArray(forKey: Self.safeKey) ?? []).filter(allowed.contains) }

    func isAllowed(_ name: String) -> Bool { allowed.contains(name) }
    func isSafe(_ name: String) -> Bool { safe.contains(name) }

    /// Unticking also takes the safe mark away; safe without the tick is not kept.
    func set(_ name: String, allowed on: Bool, safe: Bool) {
        let ticked = allowed.filter { $0 != name } + (on ? [name] : [])
        let marked = (defaults.stringArray(forKey: Self.safeKey) ?? []).filter { $0 != name } + (on && safe ? [name] : [])
        defaults.set(ticked, forKey: Self.allowedKey)
        defaults.set(marked, forKey: Self.safeKey)
    }
}
