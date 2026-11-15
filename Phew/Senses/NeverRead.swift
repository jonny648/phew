import Foundation

/// The apps the user told Phew never to read (PS.9). Names and bundle identifiers only: labels, never capture.
/// Read from UserDefaults on every check, so a change from the menu holds at once, on any thread.
struct NeverReadList: @unchecked Sendable {  // UserDefaults is thread-safe
    struct App: Codable, Equatable, Identifiable {
        var name: String
        var bundleID: String
        var id: String { bundleID }
    }

    static let shared = NeverReadList(defaults: .standard)
    static let key = "neverReadApps"
    let defaults: UserDefaults

    var apps: [App] {
        (defaults.data(forKey: Self.key)).flatMap { try? JSONDecoder().decode([App].self, from: $0) } ?? []
    }

    func contains(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return apps.contains { $0.bundleID == bundleID }
    }

    func add(name: String, bundleID: String) {
        guard !contains(bundleID) else { return }
        save(apps + [App(name: name, bundleID: bundleID)])
    }

    func remove(_ bundleID: String) {
        save(apps.filter { $0.bundleID != bundleID })
    }

    private func save(_ apps: [App]) {
        defaults.set(try? JSONEncoder().encode(apps), forKey: Self.key)
    }

    /// What a capture of a listed app gives instead of a reading: its name and bundle id, and nothing read from its
    /// screen. Nil when the app is not on the list, so the capture goes ahead.
    func packet(appName: String, bundleID: String) -> ContextPacket? {
        guard contains(bundleID) else { return nil }
        var packet = ContextPacket(appName: appName, bundleID: bundleID, windowTitle: "", visibleText: "", cursor: nil)
        packet.neverRead = true
        return packet
    }
}
