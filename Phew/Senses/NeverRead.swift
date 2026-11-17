import AppKit

/// The apps the user told Phew never to read (PS.9). Names and bundle identifiers only: labels, never capture.
/// Read from UserDefaults on every check, so a change from the menu holds at once, on any thread.
/// D9 (F2): Keychain Access and the password managers are never read either, by default (`always`): not rows of the
/// list, never added or removed. Every reading path asks `refuses`, the one check for both.
struct NeverReadList: @unchecked Sendable {  // UserDefaults is thread-safe
    struct App: Codable, Equatable, Identifiable {
        var name: String
        var bundleID: String
        var id: String { bundleID }
    }

    static let shared = NeverReadList(defaults: .standard)
    static let key = "neverReadApps"
    let defaults: UserDefaults
    /// Never read whatever the list holds: Keychain Access and the password managers. Tests may name another app.
    var always: Set<String> = NeverList.passwordApps

    var apps: [App] {
        (defaults.data(forKey: Self.key)).flatMap { try? JSONDecoder().decode([App].self, from: $0) } ?? []
    }

    func contains(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return apps.contains { $0.bundleID == bundleID }
    }

    /// The one check of every read (window text, cursor element, picture, menu names, screen watch): an app on the
    /// list or never read by default. `contains` alone is the user's rows, for the panel and the Hand's own reason.
    func refuses(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return always.contains(bundleID) || contains(bundleID)
    }

    func refuses(pid: pid_t) -> Bool {
        refuses(NSRunningApplication(processIdentifier: pid)?.bundleIdentifier)
    }

    func add(name: String, bundleID: String) {
        guard !refuses(bundleID) else { return }  // a default is never a row
        save(apps + [App(name: name, bundleID: bundleID)])
    }

    func remove(_ bundleID: String) {
        save(apps.filter { $0.bundleID != bundleID })
    }

    private func save(_ apps: [App]) {
        defaults.set(try? JSONEncoder().encode(apps), forKey: Self.key)
    }

    /// What a capture of a refused app gives instead of a reading: its name and bundle id, and nothing read from its
    /// screen. Nil when the app is read, so the capture goes ahead.
    func packet(appName: String, bundleID: String) -> ContextPacket? {
        guard refuses(bundleID) else { return nil }
        var packet = ContextPacket(appName: appName, bundleID: bundleID, windowTitle: "", visibleText: "", cursor: nil)
        packet.neverRead = true
        return packet
    }
}
