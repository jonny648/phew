import SwiftUI
import UniformTypeIdentifiers
import os

@main
struct PhewApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    /// The "Let Phew act" switch: on unless turned off here.
    @AppStorage(Hand.allowedKey) private var allowed = true
    /// NA.15, NA.16: off until switched on here.
    @AppStorage(Watching.key) private var watchOn = false
    @AppStorage(Notices.key) private var notify = false

    // No main window (hard rule): the menu bar item is the only scene.
    var body: some Scene {
        MenuBarExtra {
            // 15.5 D, as far as built: no "Saved reports…" yet.
            Button { delegate.shortcut() } label: {
                Text("Ask Phew")
                Text(Shortcut.stored().name)  // the entry's second line: the shortcut has no key equivalent; yours when you set one
            }
            Divider()
            TaskEntries(tasks: delegate.tasks) { delegate.openTask($0) }
            WatchEntries(watching: delegate.watching) { delegate.openWatched() }
            // Off: he guides instead.
            Toggle("Let Phew act", isOn: $allowed)
            Toggle("Let Phew watch one thing", isOn: Binding(get: { watchOn }, set: { delegate.watching.allow($0) }))
            Toggle("Notify me", isOn: Binding(get: { notify }, set: { on in Task { await delegate.notices.set(on) } }))
            NoticesLine(notices: delegate.notices)
            NeverReadEntry(front: delegate.front) { delegate.neverReadFrontApp() }
            Divider()
            MemoryOffEntry(undo: delegate.importUndo)
            Menu("Memory") {
                Button("Import Claude memory…") { delegate.importClaudeMemory() }
                Button("Paste a memory list…") { delegate.importMemory() }
                Button("Import from a project folder…") { delegate.importFromFolder() }
                UndoImportEntry(undo: delegate.importUndo) { delegate.undoLastImport() }
                Divider()
                Button("Conversations…") { delegate.showConversations() }
                Button("Recently deleted…") { delegate.showRecentlyDeleted() }
                Button("Export the Map…") { delegate.showExport() }
                Button("Never-read apps…") { delegate.showNeverRead() }
                Button("Skills…") { delegate.showSkills() }
                Button("Shortcuts he may run…") { delegate.showShortcuts() }
                Button("Folders he may read…") { delegate.showReadFolders() }
            }
            Button("Connections…") { delegate.showConnections() }
            Menu("Reports") {
                Button("Choose reports folder…") { delegate.chooseReportsFolder() }
                ReportFactsEntries(tasks: delegate.tasks) { delegate.reportFacts($0) }
            }
            Button("Limits…") { delegate.showLimits() }
            Button("Shortcut…") { delegate.showShortcut() }
            Divider()
            Button("API Key…") { delegate.setup.showKey() }
            Button("About Phew") { delegate.menuPanel.show(title: "About Phew", AboutView()) }
            Button("Quit Phew") { NSApp.terminate(nil) }
        } label: {
            MenuIcon(model: delegate.card.model, tasks: delegate.tasks, watching: delegate.watching)
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
        if !tasks.running.isEmpty || !tasks.queue.isEmpty {
            Text("Working")
            ForEach(tasks.running + tasks.queue) { item in
                Button { tasks.stop(item.id) } label: {
                    Text("Stop “\(item.title)”")
                    Text(item.line)
                }
            }
        }
        if !tasks.waiting.isEmpty {
            Text("Ready")
            ForEach(tasks.waiting) { item in Button(item.title) { open(item.id) } }
        }
        // N2.4, R7: one row per waiting action; Confirm runs exactly that action, Dismiss drops it. Confirm all, for a
        // task with more than one waiting, runs them one after another.
        ForEach(tasks.confirms) { item in
            ForEach(item.waits) { wait in
                Menu(wait.script.map(TaskList.asks) ?? wait.file.map(TaskList.asks) ?? wait.connector.map(TaskList.asks) ?? wait.shortcut.map(TaskList.asks) ?? "") {
                    // What a write or a shortcut will send, whole, when the row had to cut it. On the Mac only.
                    if let whole = wait.connector.flatMap(TaskList.whole) ?? wait.shortcut.flatMap(TaskList.whole) {
                        Menu("All it will send") { ForEach(Array(whole.enumerated()), id: \.offset) { Text($0.element) } }
                    }
                    Button("Confirm") { Task { await tasks.confirm(item.id, only: wait.id) } }
                    Button("Dismiss") { tasks.dismiss(item.id, only: wait.id) }
                }
            }
            if item.waits.count > 1 {
                Button("Confirm all \(item.waits.count) for “\(item.title)”") { Task { await tasks.confirm(item.id) } }
            }
        }
        // R29: a change the user confirmed can be put back until the task's result is opened.
        ForEach(tasks.undos) { item in
            Button("Undo the change confirmed for “\(item.title)”") { Task { await tasks.undo(item.id) } }
        }
        // NA.12: how confirmed file changes ended, until the result is opened or the line is clicked.
        ForEach(tasks.fileLines) { item in
            ForEach(Array(item.fileLines.enumerated()), id: \.offset) { _, line in Button(line) { tasks.clearFileLines(item.id) } }
        }
        if !tasks.running.isEmpty || !tasks.queue.isEmpty || !tasks.waiting.isEmpty || !tasks.confirms.isEmpty || !tasks.undos.isEmpty
            || !tasks.fileLines.isEmpty { Divider() }
    }
}

/// NA.15: while a watch runs, its Stop; when it ended by itself, one row that opens it on the card.
private struct WatchEntries: View {
    @ObservedObject var watching: Watching
    let open: () -> Void

    var body: some View {
        if let app = watching.app { Button("Watching one thing in \(app)… Stop") { watching.stop() } }
        if let result = watching.result { Button(result.row, action: open) }
        if watching.app != nil || watching.result != nil { Divider() }
    }
}

/// NA.16: one plain line when the system did not allow notifications.
private struct NoticesLine: View {
    @ObservedObject var notices: Notices

    var body: some View {
        if notices.refused { Text(Notices.refusedLine) }
    }
}

/// N2.11: one entry per finished task with a report. A click opens its facts in the import's tick list; nothing is
/// sent before.
private struct ReportFactsEntries: View {
    @ObservedObject var tasks: TaskList
    let open: (Int) -> Void

    var body: some View {
        let done = tasks.items.filter { $0.report != nil }
        if !done.isEmpty {
            Divider()
            ForEach(done) { item in Button("Keep facts from “\(item.title)”…") { open(item.id) } }
        }
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

/// One fixed line while the Map cannot be opened (R28): answers go on without memory.
private struct MemoryOffEntry: View {
    @ObservedObject var undo: ImportUndo

    var body: some View {
        if undo.memoryOff { Text(ImportUndo.memoryOffLine) }
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

/// The menu bar icon (15.5 D, 22.6): the small mark as a template image, in the menu bar's one colour: a line at
/// rest, full while he acts for the whole job and while a result waits; then the number of tasks running, and a dot
/// beside it while a result waits. It never animates.
private struct MenuIcon: View {
    @ObservedObject var model: CardModel
    @ObservedObject var tasks: TaskList
    @ObservedObject var watching: Watching

    var body: some View {
        let running = tasks.running.count, results = tasks.waiting.count + (watching.result == nil ? 0 : 1), waiting = results > 0
        HStack(spacing: 2) {
            Image(nsImage: Brand.menuImage(Brand.inMenuBar(acting: model.acting, waiting: results)))
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
    /// `answerEarly` (R57) is built and off: on, every typed question would also send the screen to the main model
    /// before the route is known, also for "remember" and jobs, and pay for a dropped call. Decided 16 November 2026: off (docs/07-decisions.md 7.1).
    var brain: any Brain = {
        #if DEBUG
        // A test copy under another bundle id: no Map maintenance at launch, so it never touches the user's Map folder.
        if CommandLine.arguments.contains("--debug-no-map") { return ClaudeBrain(map: BrainMap(maintenance: false), limits: Limits(), answerEarly: false) }
        #endif
        return ClaudeBrain(skills: SkillTools(), limits: Limits(), answerEarly: false, connections: .shared, claudeCode: .shared, shortcutTicks: ShortcutTicks())
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
    /// "Notify me" (NA.16) and the watcher for one thing (NA.15), both off until switched on in the menu.
    let notices = Notices.shared
    lazy var watching = Watching(watcher: .shared, notices: notices)
    /// The menu's "Undo last import" (PB.3).
    lazy var importUndo = ImportUndo(brain: brain)
    /// The context read at the shortcut, kept only until the question is asked or the panel closes without one.
    var capture: Task<ContextPacket?, Never>?
    /// The ask panel's top-left corner: the card opens there, in its place.
    var anchor = NSPoint.zero
    /// The recogniser (P6.1): the microphone, Italian and English on this Mac. Nil: a hold behaves like a short press.
    var listener = AppDelegate.listener(canHear: { if #available(macOS 26, *) { true } else { false } }())
    /// None before macOS 26, which has no on-device analyzer: a hold is then the press, and the Microphone is never
    /// asked for a voice that cannot work (R36).
    static func listener(canHear: Bool) -> (any Listening)? { canHear ? AppleListener() : nil }
    /// Hold the shortcut to talk (P6).
    lazy var talk = makeTalk()
    /// What a hold shows, at the notch.
    let notch = NotchListening()
    private lazy var hotKey = makeHotKey()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Hand.shared.connector = brain.connector  // NB.3: connector writes go only through the Hand
        ClaudeExportReader.sweep()
        ContextPacket.sweepDebugFiles()
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
        card.onHold = { [unowned self] in tasks.hold($0, words: $1) }
        card.onUnclear = { [unowned self] in unclear($0, packet: $1) }
        card.onWatch = { [unowned self] in watching.start($0) }
        tasks.onEnd = { [unowned self] in notices.task($0.title, ended: $0.state) }
        if notices.on { SystemNotices.shared.listen() }  // a click on an earlier notification is handled, by doing nothing
        card.onUnsure = { [unowned self] heard, doubtful, packet in showFirst(heard, doubtful: doubtful, capture: Task { packet }) }
        importUndo.watchMenus()
        #if DEBUG
        runDebugChecks()
        // Made-up states only: no look at the Keychain or the permissions, and no first-run panel taking the keyboard.
        if ["--debug-first-run", "--debug-report", "--debug-menu", "--debug-import", "--debug-notch"].contains(where: CommandLine.arguments.contains) { return }
        #endif
        setup.showAtLaunch()
    }

    /// N4.6: the longest Quit waits for the Librarian to learn from the conversation still open.
    static let quitWait: TimeInterval = 5
    private var quitAnswered = false

    /// N4.6: the conversation's facts are learned before the app ends, waited for `quitWait` at most.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let brain = brain
        let answer: @MainActor () -> Void = { [weak self] in
            guard let self, !quitAnswered else { return }
            quitAnswered = true
            sender.reply(toApplicationShouldTerminate: true)
        }
        Task { @MainActor in
            await brain.finishLearning()
            answer()
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.quitWait))
            answer()
        }
        return .terminateLater
    }

    /// The conversation's turns do not outlive the app (closing the card also forgets them).
    func applicationWillTerminate(_ notification: Notification) {
        brain.forgetTurns()
        tasks.stopAll()
        watching.stop()
        shellLog("quit: turns dropped")
    }

    /// A waiting result, opened from the menu: on the card near the menu bar, as a finished answer.
    func openTask(_ number: Int) {
        let mouse = NSEvent.mouseLocation
        // No display for a moment while displays change (R43): the result stays waiting in the menu.
        guard let visible = (NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.screens.first)?.visibleFrame,
              let item = tasks.open(number) else { return }
        let failure: BrainError? = if case .failed(let error) = item.state { error } else { nil }
        // A report whose files could not be written still shows, with one line saying so.
        let unsaved = item.report != nil && item.report?.saved == nil ? "\n\nThis report could not be saved as a file." : ""
        card.showResult(item.words, text: (item.report?.markdown ?? "") + unsaved, problem: failure.map(TextCard.sentence(for:)),
                        saved: item.report?.saved?.pdf, at: NSPoint(x: visible.maxX - Design.Size.width - 16, y: visible.maxY - 8),
                        brain: brain) { [unowned self] error in setup.showKey(rejected: error == .badKey) }
    }

    /// A watch's result, opened from the menu (NA.15): on the card near the menu bar. Not kept as a turn: the watched
    /// text is never sent to the model.
    func openWatched() {
        let mouse = NSEvent.mouseLocation
        guard let visible = (NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.screens.first)?.visibleFrame,
              let result = watching.open() else { return }
        card.showResult(result.row, text: result.text, problem: nil, saved: nil,
                        at: NSPoint(x: visible.maxX - Design.Size.width - 16, y: visible.maxY - 8), brain: brain, keep: false) { [unowned self] error in
            setup.showKey(rejected: error == .badKey)
        }
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

    /// N2.11: a finished task's facts, opened by the user from the menu: the report is sorted now, in one call, and
    /// shown in the import's tick list, every fact unticked. Only ticked facts are written.
    func reportFacts(_ number: Int) {
        guard let markdown = tasks.items.first(where: { $0.id == number })?.report?.markdown else { return }
        let model = ImportModel(brain: brain)
        model.sort(report: markdown)  // first, so the panel opens on Sorting and never takes the keyboard
        showImport(model, title: "Facts from a report")
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

    /// D3: the saved conversations; Open shows one on the card near the menu bar, where a reply continues it.
    func showConversations() {
        let list = ConversationsList(brain: brain)
        list.onOpen = { [unowned self] id in
            let mouse = NSEvent.mouseLocation
            guard let visible = (NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.screens.first)?.visibleFrame else { return }
            Task {
                await card.showThread(id, at: NSPoint(x: visible.maxX - Design.Size.width - 16, y: visible.maxY - 8), brain: brain) { [unowned self] error in
                    setup.showKey(rejected: error == .badKey)
                }
            }
        }
        menuPanel.show(title: "Conversations", ConversationsView(list: list))
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

    /// NB.7: the tools he may reach. Connect opens the sign-in page in the browser, only on the user's press.
    func showConnections() {
        let model = ConnectionsModel(brain: brain, open: { url in DispatchQueue.main.async { Hand.openSignIn(url) } })
        model.changed = { [unowned self] in DispatchQueue.main.async { self.menuPanel.fit(keyboard: false) } }
        menuPanel.show(title: "Connections", ConnectionsView(model: model))
    }

    /// NB.5: the user's Shortcuts, each with a tick (off by default) and "safe to run without asking".
    func showShortcuts() {
        let model = ShortcutsModel(ticks: ShortcutTicks(), list: { Hand.shared.shortcuts?.list() ?? [] })
        model.changed = { [unowned self] in DispatchQueue.main.async { self.menuPanel.fit(keyboard: false) } }
        menuPanel.show(title: "Shortcuts he may run", ShortcutsView(model: model))
    }

    func showSkills() {
        menuPanel.show(title: "Skills", SkillsView(model: SkillsModel(brain: brain)))
    }

    /// NA.11: the folders a research task may read. A folder is added through the system folder window.
    func showReadFolders() {
        let model = ReadFoldersModel(brain: brain)
        // After SwiftUI has drawn the new list, so the fit reads its size.
        model.changed = { [unowned self] in DispatchQueue.main.async { self.menuPanel.fit(keyboard: false) } }
        menuPanel.show(title: "Folders he may read", ReadFoldersView(model: model) { [unowned self] in
            chooseFolder("read folder", message: "A research task may read the files in this folder when it needs them.",
                         create: false, from: nil) { model.add($0) }
        })
    }

    func showLimits() {
        let model = LimitsModel(brain: brain)
        menuPanel.show(title: "Limits", LimitsView(model: model))
        Task { await model.refresh() }
    }

    func showShortcut() {
        let model = ShortcutModel(current: hotKey.shortcut)
        model.apply = { [unowned self] in hotKey.use($0) }
        model.pause = { [unowned self] in hotKey.paused = $0 }
        model.keyboard = { [unowned self] in menuPanel.fit(keyboard: $0) }
        menuPanel.show(title: "Shortcut", ShortcutView(model: model), onClose: { model.closed() })
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
        let key = HotKey(shortcut: .stored()) { [unowned self] in shortcut() }
        key.holdStart = { [unowned self] in holdStart() }
        key.holdEnd = { [unowned self] in talk.holdEnd() }
        key.holdCancel = { [unowned self] in talk.holdCancel() }
        key.holdLimit = { [unowned self] in talk.holdEnd(atLimit: true) }
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
        talk.heardAs = { [brain] in await brain.heardAs() }
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

    /// N3.3, N3.7: the recogniser was unsure or a name doubtful, and the Conductor routed the sentence to something
    /// that changes things (`SendOrShow.held`). The ask panel holds the heard text, the doubtful words named on its grey
    /// line, the capture kept as for `unclear`. Sent as typed once the user presses Return, so never held again; a
    /// changed name is learnt (N3.2).
    private func showFirst(_ heard: String, doubtful: [String], capture: Task<ContextPacket?, Never>?) {
        self.capture = capture
        panel.open(text: heard, line: Self.checkLine(doubtful), at: anchor) { [unowned self] question in
            guard let question else { return self.capture = nil }
            if question != heard { Task { [brain] in _ = await brain.learnHeard(heard, meant: question) } }
            ask(question)
        }
    }

    /// The grey line of a sentence shown first: the doubtful words in quotes, or the whole sentence.
    nonisolated static func checkLine(_ doubtful: [String]) -> String {
        doubtful.isEmpty ? "Is this what you said? Fix it and press Return."
            : "Did I hear \(doubtful.map { "“\($0)”" }.joined(separator: " and ")) right? Fix it and press Return."
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
