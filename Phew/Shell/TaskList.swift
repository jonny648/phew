import AppKit

/// The research tasks of this run of the app (PA.2, docs/03-experience.md 3.5 and 3.6): at most 3 at once, each with
/// its Stop, its result waiting in the menu bar until the user opens it. Nothing pops up when a task ends.
/// R8: a fourth waits for a free place, up to 5 waiting, and starts by itself when one ends; Stop removes it.
/// Memory only: the user's words and the reports live here until Quit; the report files are on disk.
/// The one screen read of a task is the capture taken when the panel opened: it goes into `runTask` and is dropped
/// when the task ends or is stopped.
/// A task acts only through `add_item`, in the background (PA.4): a script, through `Hand.act`, in an agent's job
/// that does not watch the user. Never a click, never another app brought to the front. What cannot be undone or
/// leaves the Mac waits in the menu for one confirm (N2.4); several may wait, each its own row, with Confirm all (R7).
@MainActor
final class TaskList: ObservableObject {
    static let most = 3
    static let started = "On it. The result will wait in the menu bar."
    static let full = "Three tasks are already running. Stop one, or wait."
    /// R8: at most this many wait for a free place; one more is refused with `full`.
    static let mostQueued = 5
    static let queued = "Three tasks are running. This one starts by itself when one ends."
    static let queuedProgress = "Waiting for a free place"
    /// R7: at most this many changes wait for a confirm per task; one more is refused. A ceiling kept by code.
    static let mostWaits = 20
    /// The folder the user chose for the PDFs, as a path (Phew is not sandboxed). Unset: Downloads.
    static let folderKey = "reportsFolder"

    enum State: Equatable { case queued, running, ready, stopped, failed(BrainError) }

    /// One action waiting for the user's confirm, with its own row in the menu.
    struct Waiting: Identifiable, Equatable {
        let id: Int
        let script: HandScript
    }

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
        /// R8: runs at the deep size.
        var deep = false
        /// Actions that cannot be undone or leave the Mac, each waiting for the user's confirm in the menu (N2.4, R7).
        /// At most `mostWaits` per task, oldest first, memory only.
        var waits: [Waiting] = []
        /// The jobs of the changes the user confirmed, oldest first, each holding what it replaced, so the menu can
        /// undo them, newest first, until the result is opened (R29). Memory only.
        var undo: [HandJob] = []

        /// The menu's second line: the progress, and the size when it is deep.
        var line: String { deep ? "Deep task. \(progress)" : progress }

        /// The task's first words, for the menu.
        var title: String {
            let first = words.split(whereSeparator: \.isWhitespace).prefix(5).joined(separator: " ")
            return first.count < words.trimmingCharacters(in: .whitespacesAndNewlines).count ? first + "…" : first
        }
    }

    @Published private(set) var items: [Item] = []
    var running: [Item] { items.filter { $0.state == .running } }
    /// Waiting for a free place (R8), oldest first.
    var queue: [Item] { items.filter { $0.state == .queued } }
    /// Finished, not opened yet: the menu's Ready list and the waiting dot.
    var waiting: [Item] { items.filter { !$0.opened && ![.queued, .running, .stopped].contains($0.state) } }
    /// Tasks with actions waiting for a confirm: one row per action in the menu.
    var confirms: [Item] { items.filter { !$0.waits.isEmpty } }
    /// Tasks with a confirmed change that can still be put back: one Undo row each.
    var undos: [Item] { items.filter { !$0.undo.isEmpty } }

    private let brain: any Brain
    private let hand: Hand
    private let folder: () -> URL?
    private var tasks: [Int: Task<Void, Never>] = [:]
    /// The Hand job of an `add_item` under way, per task: Stop ends it too.
    private var jobs: [Int: HandJob] = [:]
    /// A waiting task's one screen read and hearings, in memory until it starts (then the task holds them) or is
    /// stopped (then they are dropped).
    private(set) var held: [Int: (packet: ContextPacket?, spoken: [Hearing])] = [:]
    /// F3: the actions each task's agent jobs made so far: one task is one job for the per-job ceiling.
    private var acted: [Int: Int] = [:]
    private var last = 0
    private var lastWait = 0

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

    /// Starts a task; returns the one line for the card. A fourth while three run waits for a free place (R8); one
    /// more while five wait is not started. `spoken`: every hearing of a task given aloud (P6.3); empty when typed.
    func start(_ words: String, packet: ContextPacket?, spoken: [Hearing] = []) -> String {
        guard running.count < Self.most || queue.count < Self.mostQueued else {
            shellLog("task: not started, \(running.count) running, \(queue.count) waiting")
            return Self.full
        }
        // Unique across runs, so calls.log's lines of an earlier run never add to this task's cost.
        // shortcut: a clock set back can repeat a number; a persisted counter if that ever matters.
        let number = max(last + 1, Int(Date().timeIntervalSince1970))
        last = number
        guard running.count < Self.most else {
            items.append(Item(id: number, words: words, state: .queued, progress: Self.queuedProgress))
            held[number] = (packet, spoken)
            shellLog("task \(number): waiting for a free place, \(queue.count) waiting")
            return Self.queued
        }
        items.append(Item(id: number, words: words))
        begin(number, words: words, packet: packet, spoken: spoken)
        return Self.started
    }

    /// The task's run: its stream from the Brain, its progress, its end.
    private func begin(_ number: Int, words: String, packet: ContextPacket?, spoken: [Hearing]) {
        let stream = brain.runTask(words, packet: packet, number: number, folder: folder(), spoken: spoken) { [weak self] script in
            await self?.add(script, task: number) ?? HandEnd.stopped.rawValue
        }
        tasks[number] = Task { [weak self] in
            var report: TaskReport?, failure: BrainError?
            do {
                for try await event in stream {
                    if case .done(let done) = event { report = done }
                    self?.update(number) {
                        if event == .deep { $0.deep = true }
                        $0.progress = Self.progress(event, $0.progress)
                    }
                }
            } catch {
                failure = BrainError(error)
            }
            guard !Task.isCancelled else { return }  // stopped: nothing reported
            let cost = await Task.detached { CallLog.cost(ofTask: number) }.value
            self?.finish(number, report: report, failure: failure, cost: cost)
        }
        shellLog("task \(number): started, \(running.count) running")
    }

    /// R8: the oldest waiting tasks take the free places, with the screen read held for them.
    private func startNext() {
        while running.count < Self.most, let next = queue.first {
            let (packet, spoken) = held.removeValue(forKey: next.id) ?? (nil, [])
            update(next.id) { $0.state = .running; $0.progress = "Starting" }
            begin(next.id, words: next.words, packet: packet, spoken: spoken)
        }
    }

    /// Stop: the stream is cancelled (the Runner's request with it) and an `add_item` under way ends. Within 2 s.
    /// A waiting task is removed, its screen read dropped. A place freed goes to the oldest waiting task.
    func stop(_ number: Int) {
        tasks.removeValue(forKey: number)?.cancel()
        jobs[number]?.stop()
        held[number] = nil
        acted[number] = nil
        update(number) { $0.state = .stopped; $0.waits = [] }
        shellLog("task \(number): stopped")
        startNext()
    }

    /// The user opens a waiting result: it leaves the Ready list.
    func open(_ number: Int) -> Item? {
        update(number) { $0.opened = true; $0.undo = [] }
        return items.first { $0.id == number }
    }

    /// The waiting ones first, so stopping a running one starts none of them.
    func stopAll() { (queue + running).forEach { stop($0.id) } }

    private func finish(_ number: Int, report: TaskReport?, failure: BrainError?, cost: Double) {
        tasks[number] = nil
        acted[number] = nil
        update(number) {
            $0.report = report
            $0.cost = cost
            $0.state = report != nil ? .ready : .failed(failure ?? .badOutput)
        }
        shellLog("task \(number): \(report != nil ? "ready" : "failed"), waiting in the menu, $\(String(format: "%.4f", cost))")
        startNext()
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
        case .deep, .done: before
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
        // R7: each waits in its own row, up to `mostWaits`; one more is refused, never queued unseen. The Hand did
        // nothing either way.
        let refused = end == .needsConfirm && (items.first(where: { $0.id == number })?.waits.count ?? 0) >= Self.mostWaits
        if end == .needsConfirm, !refused {
            lastWait += 1
            let wait = Waiting(id: lastWait, script: script)
            update(number) { $0.waits.append(wait) }
        }
        shellLog("task \(number): item \(refused ? AddItemTool.refused : end.rawValue)")
        return refused ? AddItemTool.refused : end.rawValue
    }

    /// The menu's Confirm of one row (`only`), or Confirm all (nil): runs exactly the stored actions, one after
    /// another in one job through the Hand, now as the user's own, and drops them. The first that does not end done
    /// ends the job; it is dropped, never retried, and the ones after it stay waiting. Returns the Hand's fixed word.
    @discardableResult
    func confirm(_ number: Int, only id: Int? = nil) async -> HandEnd {
        let chosen = items.first(where: { $0.id == number })?.waits.filter { id == nil || $0.id == id } ?? []
        guard !chosen.isEmpty else { return .stopped }
        update(number) { $0.waits.removeAll(where: chosen.contains) }
        let (end, job, tried) = await run(chosen.map(\.script), agent: false, task: number)
        if tried < chosen.count { update(number) { $0.waits.insert(contentsOf: chosen[tried...], at: 0) } }
        if !job.kept.isEmpty { update(number) { $0.undo.append(job) } }
        shellLog("task \(number): confirmed \(tried) of \(chosen.count), \(end.rawValue)")
        return end
    }

    /// The menu's Undo of a confirmed change (R29): what the newest confirm replaced, put back through the Hand. What
    /// was not put back stays for another Undo, as on the card (R6); the earlier confirms stay for the next Undo.
    @discardableResult
    func undo(_ number: Int) async -> HandUndo? {
        guard let job = items.first(where: { $0.id == number })?.undo.last else { return nil }
        update(number) { $0.undo.removeLast() }
        let hand = hand
        let undo = await Task.detached { hand.restore(job) }.value
        if !job.kept.isEmpty { update(number) { $0.undo.append(job) } }
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

    /// The menu's Dismiss of one row (`only`), or of all (nil): the stored actions are dropped, nothing runs.
    func dismiss(_ number: Int, only id: Int? = nil) {
        update(number) { item in item.waits.removeAll { id == nil || $0.id == id } }
        shellLog("task \(number): waiting item dismissed")
    }

    /// `tried`: how many scripts reached the Hand, the last one ending `end`.
    private func run(_ scripts: [HandScript], agent: Bool, task number: Int) async -> (end: HandEnd, job: HandJob, tried: Int) {
        let hand = hand, job = hand.begin(watchUser: false, agent: agent, counted: agent ? acted[number] ?? 0 : 0)
        jobs[number] = job
        var end = HandEnd.done, tried = 0
        for script in scripts where end == .done {
            // `kind: .script` always: no target on screen, no click, no app brought to the front.
            let step = HandStep(kind: .script, pid: 0, script: script)
            end = await Task.detached { hand.act(step, in: job) }.value.end
            tried += 1
        }
        hand.close(job)
        jobs[number] = nil
        if agent { acted[number] = job.acted }
        return (end, job, tried)
    }
}

#if DEBUG
extension TaskList {
    /// A made-up entry for the menu and report checks: no task runs, nothing is called.
    func debugAdd(_ item: Item) { items.append(item) }
}
#endif
