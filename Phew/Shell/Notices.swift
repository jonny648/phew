import AppKit
import UserNotifications

/// NA.16 (D5): "Notify me", off until the user switches it on in the menu. Then, and only then, Phew posts a
/// notification through the system's own notification centre in two cases: a research task ended (done, at a limit,
/// or failed) and the watcher fired. Title "Phew" and one line: the task's title as the menu shows it, or the
/// watcher's fixed sentence and the app's name. No screen text, no report, no question; no sound. The result still
/// waits in the menu as before: a click on the notification does nothing.
@MainActor
final class Notices: ObservableObject {
    static let shared = Notices()
    static let key = "notifyMe"
    static let title = "Phew"
    static let watched = "What you asked me to watch has changed."
    static let refusedLine = "Notifications are not allowed for Phew. You can allow them in System Settings, Notifications."
    /// The task's title is cut to this.
    static let titleCap = 80

    /// The system said no when the switch was turned on: one plain line in the menu, until the switch is touched again.
    @Published private(set) var refused = false
    private let defaults: UserDefaults
    private let poster: any NoticePoster

    init(defaults: UserDefaults = .standard, poster: any NoticePoster = SystemNotices.shared) {
        self.defaults = defaults
        self.poster = poster
    }

    var on: Bool { defaults.bool(forKey: Self.key) }

    /// The menu switch. On asks the system (its own prompt, the first time); a refusal turns it back off.
    func set(_ on: Bool) async {
        refused = false
        defaults.set(on, forKey: Self.key)
        guard on, !(await poster.allow()) else { return }
        defaults.set(false, forKey: Self.key)
        refused = true
        shellLog("notices: not allowed by the system, switch off")
    }

    /// A research task ended by itself. Nothing when the switch is off or the user stopped it.
    func task(_ title: String, ended state: TaskList.State) {
        guard on, let line = Self.line(task: title, ended: state) else { return }
        poster.post(title: Self.title, line: line)
        shellLog("notices: task ended, posted")
    }

    /// The watcher fired. Its fixed sentence and the app's name: never the watched text.
    func watcherFired(app: String) {
        guard on else { return }
        poster.post(title: Self.title, line: Self.line(watched: app))
        shellLog("notices: watcher fired, posted")
    }

    static func line(task title: String, ended state: TaskList.State) -> String? {
        let how: String
        switch state {
        case .ready: how = "done"
        case .failed(.limited): how = "stopped at a limit"
        case .failed: how = "failed"
        case .queued, .running, .stopped: return nil
        }
        return "\(title.prefix(titleCap)): \(how)"
    }

    static func line(watched app: String) -> String { "\(watched) In \(app)." }
}

/// The one door to the system's notification centre, so tests use a fake.
protocol NoticePoster {
    /// The system's own permission prompt the first time; its stored answer after.
    func allow() async -> Bool
    func post(title: String, line: String)
}

/// The system's notification centre. A click on a notification does nothing: Phew is not made active and no window
/// opens; the result waits in the menu. If the system made Phew active for the click, the front goes back at once.
final class SystemNotices: NSObject, NoticePoster, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = SystemNotices()

    /// At launch while the switch is on, so a click on an earlier notification is handled here too.
    func listen() { UNUserNotificationCenter.current().delegate = self }

    func allow() async -> Bool {
        listen()
        return (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])) ?? false
    }

    func post(title: String, line: String) {
        listen()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = line
        content.sound = nil  // no sound by default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        await MainActor.run {
            if NSApp.isActive { NSApp.deactivate() }
            shellLog("notices: clicked, nothing opened")
        }
    }

    /// Shown as a banner even while a Phew panel is in front.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }
}
