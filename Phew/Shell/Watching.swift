import AppKit

/// NA.15 (D4): the Shell's side of the watcher. "Let Phew watch one thing" in the menu, off until switched on; the
/// card's one line when a watch is asked for; while it runs, a Stop row in the menu; when it ends by itself, one row
/// that opens a card. The watched text is shown to the user only on that card, and is never sent to the model.
@MainActor
final class Watching: ObservableObject {
    static let key = "letPhewWatch"
    static let off = "Watching is off. Turn on “Let Phew watch one thing” in the menu."
    static let started = "I'm watching it. When it changes, it will wait in the menu bar."
    static let nothing = "There is nothing under the pointer I can watch."
    static let secure = "That is a password or other secure field. I never watch it."
    static let ownApp = "I don't watch my own windows."
    static let secureInput = "Secure typing is on, so I can't watch now."
    static func neverRead(_ app: String) -> String { "I never read \(app), so I can't watch anything there." }
    static func replaced(_ app: String) -> String {
        "I stopped watching the thing in \(app) and watch this one now. When it changes, it will wait in the menu bar."
    }

    /// A watch that ended by itself, waiting in the menu until opened: its row and the card's text. Memory only.
    struct Result: Equatable {
        let row: String
        let text: String
    }

    /// The app of the watch running now, for the Stop row.
    @Published private(set) var app: String?
    @Published private(set) var result: Result?
    let watcher: Watcher
    private let notices: Notices
    private let defaults: UserDefaults

    init(watcher: Watcher, notices: Notices, defaults: UserDefaults = .standard) {
        self.watcher = watcher
        self.notices = notices
        self.defaults = defaults
        watcher.onEnd = { [weak self] in self?.ended($0, $1) }
    }

    var allowed: Bool { defaults.bool(forKey: Self.key) }

    /// The menu switch. Off stops a watch that runs.
    func allow(_ on: Bool) {
        defaults.set(on, forKey: Self.key)
        if !on { stop() }
    }

    /// The watch route, from the card: the thing under the pointer when the user asked (`packet.mouse`). The card's line.
    func start(_ packet: ContextPacket?) -> String {
        guard allowed else { return Self.off }
        guard let packet else { return Self.nothing }
        if packet.neverRead { return Self.neverRead(packet.appName) }
        guard let mouse = packet.mouse else { return Self.nothing }
        let before = watcher.watch?.app
        switch watcher.start(app: packet.appName, bundleID: packet.bundleID, at: mouse) {
        case .neverRead: return Self.neverRead(packet.appName)
        case .nothing: return Self.nothing
        case .secure: return Self.secure
        case .ownApp: return Self.ownApp
        case .secureInput: return Self.secureInput
        case nil:
            app = packet.appName
            return before.map(Self.replaced) ?? Self.started
        }
    }

    /// The menu's Stop, the switch turned off, and Quit: no row.
    func stop() { watcher.end(.stopped) }

    /// The user opens the row: it leaves the menu.
    func open() -> Result? {
        defer { result = nil }
        return result
    }

    private func ended(_ watch: Watcher.Watch, _ end: Watcher.End) {
        app = watcher.watch?.app
        if let result = Self.result(app: watch.app, end) { self.result = result }
        if end.fired { notices.watcherFired(app: watch.app) }
    }

    /// What waits in the menu after a watch ended by itself; nil when the user ended it.
    static func result(app: String, _ end: Watcher.End) -> Result? {
        let changed = "What you watched in \(app) changed"
        func stopped(_ why: String) -> String { "Stopped watching in \(app): \(why)" }
        return switch end {
        case let .changed(before, now): Result(row: changed, text: "It changed.\n\nBefore: “\(before)”\n\nNow: “\(now)”")
        case let .gone(before): Result(row: changed, text: "It is gone: the control or its window closed.\n\nBefore: “\(before)”")
        case .timeUp: Result(row: stopped("two hours passed"), text: "I watched it for two hours, the most I watch. It did not change.")
        case .asleep: Result(row: stopped("the Mac slept or locked"), text: "I stopped watching when the Mac went to sleep or the screen locked. It had not changed.")
        case .neverRead: Result(row: stopped("it is never read"), text: "\(app) is never read now, so I stopped watching. It had not changed.")
        case .secureInput: Result(row: stopped("secure typing came on"), text: "Secure typing came on, so I stopped watching. It had not changed.")
        case .stopped, .replaced: nil
        }
    }
}
