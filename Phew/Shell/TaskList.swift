import AppKit

/// The research tasks of this run of the app (PA.2, docs/03-experience.md 3.5 and 3.6): at most 3 at once, each with
/// its Stop, its result waiting in the menu bar until the user opens it. Nothing pops up when a task ends.
/// Memory only: the user's words and the reports live here until Quit; the report files are on disk.
/// The one screen read of a task is the capture taken when the panel opened: it goes into `runTask` and is dropped
/// when the task ends or is stopped.
/// A task acts only through `add_item`, in the background (PA.4): a script, through `Hand.act`, in an agent's job
/// that does not watch the user. Never a click, never another app brought to the front. What cannot be undone or
/// leaves the Mac waits in the menu for one confirm (N2.4).
@MainActor
final class TaskList: ObservableObject {
    static let most = 3
    static let started = "On it. The result will wait in the menu bar."
    static let full = "Three tasks are already running. Stop one, or wait."
    /// The folder the user chose for the PDFs, as a path (Phew is not sandboxed). Unset: Downloads.
    static let folderKey = "reportsFolder"

    enum State: Equatable { case running, ready, stopped, failed(BrainError) }

    struct Item: Identifiable {
        /// The task number, also in calls.log.
        let id: Int
        /// The user's words, in memory only.
        let words: String
        var state = State.running
        /// Fixed words and counts, from the task's events.
        var progress = "Starting"
        var report: TaskReport?
        var cost: Double?
        var opened = false
        /// An action that cannot be undone or leaves the Mac, waiting for the user's one confirm in the menu (N2.4).
        /// At most one per task, memory only.
        var waits: HandScript?
        /// The job of a change the user confirmed, holding what it replaced, so the menu can undo it until the
        /// result is opened (R29). Memory only.
        var undo: HandJob?

        /// The task's first words, for the menu.
        var title: String {
            let first = words.split(whereSeparator: \.isWhitespace).prefix(5).joined(separator: " ")
            return first.count < words.trimmingCharacters(in: .whitespacesAndNewlines).count ? first + "…" : first
        }
    }

    @Published private(set) var items: [Item] = []
    var running: [Item] { items.filter { $0.state == .running } }
    /// Finished, not opened yet: the menu's Ready list and the waiting dot.
    var waiting: [Item] { items.filter { !$0.opened && $0.state != .running && $0.state != .stopped } }
    /// Tasks with an action waiting for a confirm: one row each in the menu.
    var confirms: [Item] { items.filter { $0.waits != nil } }
    /// Tasks with a confirmed change that can still be put back: one Undo row each.
    var undos: [Item] { items.filter { $0.undo != nil } }

    private let brain: any Brain
    private let hand: Hand
    private let folder: () -> URL?
    private var tasks: [Int: Task<Void, Never>] = [:]
    /// The Hand job of an `add_item` under way, per task: Stop ends it too.
    private var jobs: [Int: HandJob] = [:]
    private var last = 0

    init(brain: any Brain, hand: Hand = .shared, folder: @escaping () -> URL? = TaskList.chosenFolder) {
        self.brain = brain
        self.hand = hand
        self.folder = folder
    }

    /// The folder chosen in the menu, while it still exists; nil: Downloads.
    static func chosenFolder() -> URL? {
        guard let path = UserDefaults.standard.string(forKey: folderKey) else { return nil }
        var folder: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &folder) && folder.boolValue ? URL(filePath: path) : nil
    }

    /// Starts a task; returns the one line for the card. A fourth while three run is not started.
    /// `spoken`: every hearing of a task given aloud (P6.3); empty when typed.
    func start(_ words: String, packet: ContextPacket?, spoken: [Hearing] = []) -> String {
        guard running.count < Self.most else {
            shellLog("task: not started, \(running.count) running")
            return Self.full
        }
        // Unique across runs, so calls.log's lines of an earlier run never add to this task's cost.
        // shortcut: a clock set back can repeat a number; a persisted counter if that ever matters.
        let number = max(last + 1, Int(Date().timeIntervalSince1970))
        last = number
        items.append(Item(id: number, words: words))
        let stream = brain.runTask(words, packet: packet, number: number, folder: folder(), spoken: spoken) { [weak self] script in
            await self?.add(script, task: number) ?? HandEnd.stopped.rawValue
        }
        tasks[number] = Task { [weak self] in
            var report: TaskReport?, failure: BrainError?
            do {
                for try await event in stream {
                    if case .done(let done) = event { report = done }
                    self?.update(number) { $0.progress = Self.progress(event, $0.progress) }
                }
            } catch {
                failure = BrainError(error)
            }
            guard !Task.isCancelled else { return }  // stopped: nothing reported
            let cost = await Task.detached { CallLog.cost(ofTask: number) }.value
            self?.finish(number, report: report, failure: failure, cost: cost)
        }
        shellLog("task \(number): started, \(running.count) running")
        return Self.started
    }

    /// Stop: the stream is cancelled (the Runner's request with it) and an `add_item` under way ends. Within 2 s.
    func stop(_ number: Int) {
        tasks.removeValue(forKey: number)?.cancel()
        jobs[number]?.stop()
        update(number) { $0.state = .stopped; $0.waits = nil }
        shellLog("task \(number): stopped")
    }

    /// The user opens a waiting result: it leaves the Ready list.
    func open(_ number: Int) -> Item? {
        update(number) { $0.opened = true; $0.undo = nil }
        return items.first { $0.id == number }
    }

    func stopAll() { running.forEach { stop($0.id) } }

    private func finish(_ number: Int, report: TaskReport?, failure: BrainError?, cost: Double) {
        tasks[number] = nil
        update(number) {
            $0.report = report
            $0.cost = cost
            $0.state = report != nil ? .ready : .failed(failure ?? .badOutput)
        }
        shellLog("task \(number): \(report != nil ? "ready" : "failed"), waiting in the menu, $\(String(format: "%.4f", cost))")
    }

    private func update(_ number: Int, _ change: (inout Item) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == number }) else { return }
        change(&items[index])
    }

    static func progress(_ event: TaskEvent, _ before: String) -> String {
        switch event {
        case .searching(let n): "Searching, \(n) search\(n == 1 ? "" : "es")"
        case .reading(let n): "Reading, \(n) page\(n == 1 ? "" : "s")"
        case .writing: "Writing the report"
        case .done: before
        }
    }

    // MARK: add_item, in the background (PA.4)

    /// Runs the Runner's item through the Hand: a script, nothing else, in an agent's job that does not watch the
    /// user and is closed at once. A sheet is a new workbook, then its cells. Returns the Hand's fixed word.
    /// What cannot be undone or leaves the Mac is not done (`needsConfirm`): it waits in the menu for one confirm.
    func add(_ script: HandScript, task number: Int) async -> String {
        let scripts: [HandScript]
        switch script {
        case .note, .reminder, .event, .rename, .noteBody, .complete, .move, .delete: scripts = [script]
        case .cells: scripts = [.workbook, script]
        // Only whole new items, and changes or deletes of one named note, reminder or event.
        case .append, .workbook, .changeCells, .restore: return AddItemTool.refused
        }
        guard tasks[number] != nil else { return HandEnd.stopped.rawValue }
        let end = await run(scripts, agent: true, task: number).end
        // One waits at a time: a second is refused, never queued unseen. The Hand did nothing either way.
        let refused = end == .needsConfirm && items.first(where: { $0.id == number })?.waits != nil
        if end == .needsConfirm, !refused { update(number) { $0.waits = script } }
        shellLog("task \(number): item \(refused ? AddItemTool.refused : end.rawValue)")
        return refused ? AddItemTool.refused : end.rawValue
    }

    /// The menu's Confirm: runs exactly the one stored action through the Hand, now as the user's own, then drops it.
    /// Returns the Hand's fixed word.
    @discardableResult
    func confirm(_ number: Int) async -> HandEnd {
        guard let script = items.first(where: { $0.id == number })?.waits else { return .stopped }
        update(number) { $0.waits = nil }
        let (end, job) = await run([script], agent: false, task: number)
        if !job.kept.isEmpty { update(number) { $0.undo = job } }
        shellLog("task \(number): confirmed item \(end.rawValue)")
        return end
    }

    /// The menu's Undo of a confirmed change (R29): what it replaced, put back through the Hand. What was not put
    /// back stays for another Undo, as on the card (R6).
    @discardableResult
    func undo(_ number: Int) async -> HandUndo? {
        guard let job = items.first(where: { $0.id == number })?.undo else { return nil }
        update(number) { $0.undo = nil }
        let hand = hand
        let undo = await Task.detached { hand.restore(job) }.value
        if !job.kept.isEmpty { update(number) { $0.undo = job } }
        shellLog("task \(number): undo of the confirmed item \(undo.end.rawValue)")
        return undo
    }

    /// The confirm row: what happens once confirmed, with what a change writes (R29): the new text's first line, the
    /// new time. Memory only, never logged.
    static func asks(_ script: HandScript) -> String {
        let what: String = switch script {
        case let .delete(item, title): "Delete the \(item.rawValue) “\(title)”"
        case let .rename(item, title, to): "Rename the \(item.rawValue) “\(title)” to “\(to)”"
        case let .noteBody(title, body):
            firstLine(body).map { "Rewrite the note “\(title)” with “\($0)”" } ?? "Empty the note “\(title)”"
        case let .complete(title): "Tick the reminder “\(title)” done"
        case let .move(title, start, end):
            "Move the event “\(title)” to \(start.formatted(date: .abbreviated, time: .shortened))"
                + (end.map { " until \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "")
        default: ActJob.line(HandStep(kind: .script, pid: 0, script: script))
        }
        return "Waiting for you: \(what)?"
    }

    /// A new text's first line with words, at most 60 characters; "…" when more follows. Nil when it has none.
    private static func firstLine(_ text: String) -> String? {
        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard let first = lines.first else { return nil }
        if first.count > 60 { return first.prefix(60) + "…" }
        return lines.count > 1 ? first + " …" : first
    }

    /// The menu's Dismiss: the stored action is dropped, nothing runs.
    func dismiss(_ number: Int) {
        update(number) { $0.waits = nil }
        shellLog("task \(number): waiting item dismissed")
    }

    private func run(_ scripts: [HandScript], agent: Bool, task number: Int) async -> (end: HandEnd, job: HandJob) {
        let hand = hand, job = hand.begin(watchUser: false, agent: agent)
        jobs[number] = job
        var end = HandEnd.done
        for script in scripts where end == .done {
            // `kind: .script` always: no target on screen, no click, no app brought to the front.
            let step = HandStep(kind: .script, pid: 0, script: script)
            end = await Task.detached { hand.act(step, in: job) }.value.end
        }
        hand.close(job)
        jobs[number] = nil
        return (end, job)
    }
}

#if DEBUG
extension TaskList {
    /// A made-up entry for the menu and report checks: no task runs, nothing is called.
    func debugAdd(_ item: Item) { items.append(item) }
}
#endif
