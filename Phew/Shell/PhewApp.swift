import SwiftUI
import os

@main
struct PhewApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    /// The "Let Phew act" switch: on unless turned off here.
    @AppStorage(Hand.allowedKey) private var allowed = true

    // No main window (hard rule): the menu bar item is the only scene.
    var body: some Scene {
        MenuBarExtra {
            // 15.5 D, as far as built: no "Saved reports…" yet.
            Button { delegate.shortcut() } label: {
                Text("Ask Phew")
                Text("right ⌥ + right ⌘")  // shown as the entry's second line: the shortcut has no key equivalent
            }
            Divider()
            TaskEntries(tasks: delegate.tasks) { delegate.openTask($0) }
            // Off: he guides instead.
            Toggle("Let Phew act", isOn: $allowed)
            NeverReadEntry(front: delegate.front) { delegate.neverReadFrontApp() }
            Divider()
            Menu("Memory") {
                Button("Recently deleted…") { delegate.showRecentlyDeleted() }
                Button("Export the Map…") { delegate.showExport() }
                Button("Never-read apps…") { delegate.showNeverRead() }
            }
            Menu("Reports") {
                Button("Choose reports folder…") { delegate.chooseReportsFolder() }
            }
            Divider()
            Button("API Key…") { delegate.setup.showKey() }
            Button("About Phew") { delegate.menuPanel.show(title: "About Phew", AboutView()) }
            Button("Quit Phew") { NSApp.terminate(nil) }
        } label: {
            MenuIcon(model: delegate.card.model, tasks: delegate.tasks)
        }
    }
}

/// Working (each task's Stop, with its progress as the entry's second line) and Ready (a click opens the report on
/// the card), 15.5 D. Each heading only while it has entries.
// Not `Section`: in the menu each one adds a separator before and after, so the menu showed them doubled.
private struct TaskEntries: View {
    @ObservedObject var tasks: TaskList
    let open: (Int) -> Void

    var body: some View {
        if !tasks.running.isEmpty {
            Text("Working")
            ForEach(tasks.running) { item in
                Button { tasks.stop(item.id) } label: {
                    Text("Stop “\(item.title)”")
                    Text(item.progress)
                }
            }
        }
        if !tasks.waiting.isEmpty {
            Text("Ready")
            ForEach(tasks.waiting) { item in Button(item.title) { open(item.id) } }
        }
        if !tasks.running.isEmpty || !tasks.waiting.isEmpty { Divider() }
    }
}

/// "Never read Notes": names the app in front, which keeps the front while the menu is open.
private struct NeverReadEntry: View {
    @ObservedObject var front: FrontApp
    let action: () -> Void

    var body: some View {
        Button(front.name.map { "Never read \($0)" } ?? "Never read this app", action: action).disabled(front.name == nil)
    }
}

/// The name of the app in front, never Phew's own. A label only.
@MainActor
final class FrontApp: ObservableObject {
    @Published private(set) var name: String?
    private var observer: Any?

    init() {
        update(NSWorkspace.shared.frontmostApplication)
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { self?.update(app) }
        }
    }

    private func update(_ app: NSRunningApplication?) {
        guard let app, app != .current else { return }  // the folder window makes Phew active for a moment
        name = app.localizedName
    }
}

/// The menu bar icon (15.5 D), a template symbol: resting, or acting for the whole job; then the number of tasks
/// running, and a dot while a result waits. It never animates.
// shortcut: the label draws as template text beside the symbol, so the dot follows it in the menu bar's colour, not
// at its top right in accent; draw one image if the look matters.
private struct MenuIcon: View {
    @ObservedObject var model: CardModel
    @ObservedObject var tasks: TaskList

    var body: some View {
        let running = tasks.running.count, waiting = !tasks.waiting.isEmpty
        HStack(spacing: 2) {
            Image(systemName: model.acting ? "cursorarrow.motionlines" : "cursorarrow.rays")
            if running > 0 { Text(verbatim: "\(running)") }
            if waiting { Text(verbatim: "•") }
        }
        .accessibilityLabel(["Phew", model.acting ? "acting" : nil, running > 0 ? "\(running) working" : nil,
                             waiting ? "a result waits" : nil].compactMap { $0 }.joined(separator: ", "))
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// The one place the Brain is made. Everything else in the Shell sees only the `Brain` protocol.
    var brain: any Brain = {
        #if DEBUG
        // A test copy under another bundle id: no Map maintenance at launch, so it never touches the user's Map folder.
        if CommandLine.arguments.contains("--debug-no-map") { return ClaudeBrain(map: BrainMap(maintenance: false)) }
        #endif
        return ClaudeBrain()
    }()
    let panel = InputPanel()
    let card = TextCard()
    /// First run, and the key row alone from "API Key…".
    let setup = SetupPanel()
    /// Recently deleted, Export the Map, Never-read apps or About: one small panel at a time.
    let menuPanel = MenuPanel()
    let front = FrontApp()
    /// The research tasks of this run (PA.2).
    lazy var tasks = TaskList(brain: brain)
    /// The context read at the shortcut, kept only until the question is asked or the panel closes without one.
    var capture: Task<ContextPacket?, Never>?
    /// The ask panel's top-left corner: the card opens there, in its place.
    var anchor = NSPoint.zero
    private lazy var hotKey = HotKey { [unowned self] in shortcut() }

    func applicationDidFinishLaunching(_ notification: Notification) {
        hotKey.install()
        // Re-install once Accessibility is granted, so the shortcut works without a relaunch.
        setup.onAccessibilityGranted = { [unowned self] in hotKey.install() }
        card.onTask = { [unowned self] in tasks.start($0, packet: $1) }
        #if DEBUG
        runDebugChecks()
        // Made-up states only: no look at the Keychain or the permissions, and no first-run panel taking the keyboard.
        if ["--debug-first-run", "--debug-report", "--debug-menu"].contains(where: CommandLine.arguments.contains) { return }
        #endif
        setup.showAtLaunch()
    }

    /// The conversation's turns do not outlive the app (closing the card also forgets them).
    func applicationWillTerminate(_ notification: Notification) {
        brain.forgetTurns()
        tasks.stopAll()
        shellLog("quit: turns dropped")
    }

    /// A waiting result, opened from the menu: on the card near the menu bar, as a finished answer.
    func openTask(_ number: Int) {
        guard let item = tasks.open(number) else { return }
        let mouse = NSEvent.mouseLocation
        let visible = (NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.screens[0]).visibleFrame
        let failure: BrainError? = if case .failed(let error) = item.state { error } else { nil }
        // A report whose files could not be written still shows, with one line saying so.
        let unsaved = item.report != nil && item.report?.saved == nil ? "\n\nThis report could not be saved as a file." : ""
        card.showResult(item.words, text: (item.report?.markdown ?? "") + unsaved, problem: failure.map(TextCard.sentence(for:)),
                        saved: item.report?.saved?.pdf, at: NSPoint(x: visible.maxX - Design.Size.width - 16, y: visible.maxY - 8),
                        brain: brain) { [unowned self] error in setup.showKey(rejected: error == .badKey) }
    }

    /// The system folder window, the one focus exception (CLAUDE.md): Phew is active only while it is open, then the
    /// app that was in front is made active again. Cancel changes nothing.
    func chooseReportsFolder() {
        let front = NSWorkspace.shared.frontmostApplication
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message = "Phew saves each report as a new PDF in this folder."
        panel.directoryURL = TaskList.chosenFolder() ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        NSApp.activate()
        panel.begin { response in
            if response == .OK, let url = panel.url { UserDefaults.standard.set(url.path, forKey: TaskList.folderKey) }
            let back = front.map { $0 != .current && $0.activate(from: .current, options: []) } ?? false
            shellLog("reports folder: window closed, \(response == .OK ? "chosen" : "unchanged"), front app active again \(back)")
        }
    }

    func showRecentlyDeleted() {
        menuPanel.show(title: "Recently deleted", DeletedView(list: DeletedList(brain: brain)))
    }

    func showExport() {
        menuPanel.show(title: "Export the Map", ExportView(exporter: MapExporter(brain: brain)))
    }

    /// Adds the app in front (opening the menu bar menu does not take the front from it), then shows the list.
    func neverReadFrontApp() {
        if let app = NSWorkspace.shared.frontmostApplication, app != .current, let bundleID = app.bundleIdentifier {
            NeverReadList.shared.add(name: app.localizedName ?? bundleID, bundleID: bundleID)
        }
        showNeverRead()
    }

    func showNeverRead() {
        menuPanel.show(title: "Never-read apps", NeverReadView(model: NeverReadModel()))
    }

    /// The shortcut, and "Ask Phew" in the menu.
    func shortcut() {
        // The panel is already open: a second capture would read Phew's own panel.
        guard !panel.isOpen else { return }  // not `isVisible`: it may still be fading out
        // 3.10: while a conversation is open the shortcut goes back to its reply field; no second card.
        if card.isVisible && card.model.open { return card.shortcutPressed() }
        card.dismiss()  // off screen first, so the capture reads the user's app and not the card
        shellLog("shortcut fired, phew front \(phewIsFront)")
        capture = Senses.capture()  // before the panel: it opens under the cursor
        panel.open { [unowned self] question in
            if let question { ask(question) } else { capture = nil }
        }
        anchor = NSPoint(x: panel.frame.minX, y: panel.frame.maxY)  // 15.5 A: the card takes the panel's place
    }

    /// An empty question is fine: the Brain then explains what is under the cursor.
    func ask(_ question: String) {
        card.show(at: anchor, question: question, capture: capture, brain: brain) { [unowned self] error in
            setup.showKey(rejected: error == .badKey)  // the student asks again himself once the key is saved
        }
        capture = nil
    }
}

// MARK: - Debug evidence. Release builds log nothing.

/// True would break a hard rule: Phew never takes the front from the user's app.
var phewIsFront: Bool {
    NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier
}

#if DEBUG
/// Unit tests read the log lines here, to check no words go into them.
nonisolated(unsafe) var shellLogTap: (@Sendable (String) -> Void)?
#endif

/// Counts, timings, route names and error classes only: never the question, the answer or captured context.
func shellLog(_ message: String) {
    #if DEBUG
    shellLogTap?(message)
    Logger(subsystem: "com.gianlucatroietto.Phew", category: "shell").info("\(message, privacy: .public)")
    #endif
}
