import SwiftUI
import UniformTypeIdentifiers
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
                Button("Import Claude memory…") { delegate.importClaudeMemory() }
                Button("Paste a memory list…") { delegate.importMemory() }
                Button("Import from a project folder…") { delegate.importFromFolder() }
                UndoImportEntry(undo: delegate.importUndo) { delegate.undoLastImport() }
                Divider()
                Button("Recently deleted…") { delegate.showRecentlyDeleted() }
                Button("Export the Map…") { delegate.showExport() }
                Button("Never-read apps…") { delegate.showNeverRead() }
            }
            Menu("Reports") {
                Button("Choose reports folder…") { delegate.chooseReportsFolder() }
            }
            Button("Limits…") { delegate.showLimits() }
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
        // N2.4: one row per task whose action waits; Confirm runs exactly that action, Dismiss drops it.
        ForEach(tasks.confirms) { item in
            Menu(item.waits.map(TaskList.asks) ?? "") {
                Button("Confirm") { Task { await tasks.confirm(item.id) } }
                Button("Dismiss") { tasks.dismiss(item.id) }
            }
        }
        if !tasks.running.isEmpty || !tasks.waiting.isEmpty || !tasks.confirms.isEmpty { Divider() }
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

/// "Undo last import", off while there is nothing to undo.
private struct UndoImportEntry: View {
    @ObservedObject var undo: ImportUndo
    let action: () -> Void

    var body: some View {
        Button(undo.title, action: action).disabled(undo.last == nil)
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
        if CommandLine.arguments.contains("--debug-no-map") { return ClaudeBrain(map: BrainMap(maintenance: false), limits: Limits()) }
        #endif
        return ClaudeBrain(limits: Limits())
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
    /// The menu's "Undo last import" (PB.3).
    lazy var importUndo = ImportUndo(brain: brain)
    /// The context read at the shortcut, kept only until the question is asked or the panel closes without one.
    var capture: Task<ContextPacket?, Never>?
    /// The ask panel's top-left corner: the card opens there, in its place.
    var anchor = NSPoint.zero
    /// The recogniser (P6.1): the microphone, Italian and English on this Mac. Nil: a hold behaves like a short press.
    var listener: (any Listening)? = AppleListener()
    /// Hold the shortcut to talk (P6).
    lazy var talk = makeTalk()
    /// What a hold shows, at the notch.
    let notch = NotchListening()
    private lazy var hotKey = makeHotKey()

    func applicationDidFinishLaunching(_ notification: Notification) {
        ClaudeExportReader.sweep()
        #if DEBUG
        // The notch check runs beside the user's own Phew, which owns the shortcut.
        let ownsShortcut = !CommandLine.arguments.contains("--debug-notch")
        #else
        let ownsShortcut = true
        #endif
        if ownsShortcut {
            hotKey.install()
            // Re-install once Accessibility is granted, so the shortcut works without a relaunch.
            setup.onAccessibilityGranted = { [unowned self] in hotKey.install() }
        }
        setup.voicePermissions = { VoicePermissions.now }
        setup.askMicrophone = { Task { _ = await ListenPermissions.askMicrophone() } }
        card.onTask = { [unowned self] in tasks.start($0, packet: $1, spoken: $2) }
        card.onUnclear = { [unowned self] in unclear($0, packet: $1) }
        importUndo.watchMenus()
        #if DEBUG
        runDebugChecks()
        // Made-up states only: no look at the Keychain or the permissions, and no first-run panel taking the keyboard.
        if ["--debug-first-run", "--debug-report", "--debug-menu", "--debug-import", "--debug-notch"].contains(where: CommandLine.arguments.contains) { return }
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
        chooseFolder("reports folder", message: "Phew saves each report as a new PDF in this folder.", create: true,
                     from: TaskList.chosenFolder() ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first) {
            UserDefaults.standard.set($0.path, forKey: TaskList.folderKey)
        }
    }

    /// `log`: fixed words naming the use, for the log line. `files`: file types that may be chosen besides a folder.
    /// `chosen` runs after the front app is active again.
    private func chooseFolder(_ log: String, message: String, create: Bool, from start: URL?, files: [UTType] = [],
                              _ chosen: @escaping (URL) -> Void) {
        let front = NSWorkspace.shared.frontmostApplication
        let panel = NSOpenPanel()
        panel.canChooseFiles = !files.isEmpty
        if !files.isEmpty { panel.allowedContentTypes = files }
        panel.canChooseDirectories = true
        panel.canCreateDirectories = create
        panel.prompt = "Choose"
        panel.message = message
        panel.directoryURL = start
        NSApp.activate()
        panel.begin { response in
            let back = front.map { $0 != .current && $0.activate(from: .current, options: []) } ?? false
            shellLog("\(log): window closed, \(response == .OK ? "chosen" : "unchanged"), front app active again \(back)")
            if response == .OK, let url = panel.url { chosen(url) }
        }
    }

    // MARK: Imported memory (PB)

    /// The main way in: the system folder window, where the export's folder or its ZIP is chosen; then the panel lists
    /// its groups. Nothing is sent before Sort.
    func importClaudeMemory() {
        chooseFolder("claude export", message: "Choose your Claude memory export: its folder, or the ZIP you downloaded.", create: false,
                     from: FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first, files: [.zip]) { [unowned self] url in
            Task {
                let model = ImportModel(brain: brain)
                await model.read(export: url)
                showImport(model, title: "Import Claude memory")
            }
        }
    }

    func importMemory() { showImport(ImportModel(brain: brain), title: "Paste a memory list") }

    /// The system folder window first; then the panel lists the files found. Nothing is sent before Sort.
    func importFromFolder() {
        chooseFolder("project folder", message: "Phew reads only this folder's CLAUDE.md and its Claude Code memory files.",
                     create: false, from: nil) { [unowned self] folder in
            let model = ImportModel(brain: brain)
            model.read(folder: folder)
            showImport(model, title: "Import from a project folder")
        }
    }

    func undoLastImport() {
        Task {
            let line = await importUndo.undo()
            showImport(ImportModel(brain: brain, stage: .line(line)), title: "Undo last import")
        }
    }

    func showImport(_ model: ImportModel, title: String) {
        model.onClose = { [unowned self] in menuPanel.close() }
        model.onKeyProblem = { [unowned self] in setup.showKey(rejected: $0 == .badKey) }
        model.onImported = { [unowned self] in Task { await importUndo.refresh() } }
        // After SwiftUI has drawn the new stage, so the fit reads its size.
        model.onStage = { [unowned self] stage in DispatchQueue.main.async { self.menuPanel.fit(keyboard: stage == .paste) } }
        menuPanel.show(title: title, ImportView(model: model), onClose: { model.drop() })
        menuPanel.fit(keyboard: model.stage == .paste)
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

    func showLimits() {
        let model = LimitsModel(brain: brain)
        menuPanel.show(title: "Limits", LimitsView(model: model))
        Task { await model.refresh() }
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

    /// An empty question is fine: the Brain then explains what is under the cursor. `spoken`: every hearing of a
    /// question said aloud, best first; empty when typed.
    func ask(_ question: String, spoken: [Hearing] = []) {
        card.show(at: anchor, question: question, spoken: spoken, capture: capture, brain: brain) { [unowned self] error in
            setup.showKey(rejected: error == .badKey)  // the student asks again himself once the key is saved
        }
        capture = nil
    }

    // MARK: Hold to talk (P6)

    private func makeHotKey() -> HotKey {
        let key = HotKey { [unowned self] in shortcut() }
        key.holdStart = { [unowned self] in holdStart() }
        key.holdEnd = { [unowned self] in talk.holdEnd() }
        key.holdCancel = { [unowned self] in talk.holdCancel() }
        return key
    }

    private func makeTalk() -> Talk {
        let talk = Talk()
        talk.names = { [brain] in await brain.spokenNames() }
        talk.capture = { [unowned self] in
            card.dismiss()  // off screen first, so the capture reads the user's app and not the card
            anchor = NSEvent.mouseLocation  // the card opens where the ask panel would have
            return Senses.capture()
        }
        talk.show = { [unowned self] in notch.show($0) }
        talk.send = { [unowned self] question, spoken, capture in
            self.capture = capture
            ask(question, spoken: spoken)
        }
        talk.missing = { [unowned self] in setup.showVoice() }
        talk.permissions = { [unowned self] in setup.voicePermissions() }
        return talk
    }

    /// Held long enough to talk. Without a listener, or while the panel or a conversation is open, the shortcut's
    /// press instead.
    private func holdStart() {
        talk.listener = listener
        guard listener != nil, !panel.isOpen, !(card.isVisible && card.model.open) else { return shortcut() }
        shellLog("shortcut held, phew front \(phewIsFront)")
        talk.holdStart()
    }

    /// P6.3: neither hearing made sense. The ask panel in its typing state where the card was, holding the best
    /// hearing and one grey line; the turn's capture goes with it, dropped if the panel closes without a question.
    private func unclear(_ heard: String, packet: ContextPacket?) {
        shellLog("talk: not caught, panel opened to fix, \(heard.count) characters")
        capture = Task { packet }
        panel.open(text: heard, line: Self.notCaught, at: anchor) { [unowned self] question in
            if let question { ask(question) } else { capture = nil }
        }
    }

    static let notCaught = "I did not catch that. Fix it and press Return."
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
