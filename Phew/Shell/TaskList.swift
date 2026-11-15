import AppKit

/// The research tasks of this run of the app (PA.2, docs/03-experience.md 3.5 and 3.6): at most 3 at once, each with
/// its Stop, its result waiting in the menu bar until the user opens it. Nothing pops up when a task ends.
/// Memory only: the user's words and the reports live here until Quit; the report files are on disk.
/// The one screen read of a task is the capture taken when the panel opened: it goes into `runTask` and is dropped
/// when the task ends or is stopped.
/// A task acts only through `add_item`, in the background (PA.4): a script that adds, through `Hand.act`, in a job
/// that does not watch the user. Never a click, never another app brought to the front.
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
        update(number) { $0.state = .stopped }
        shellLog("task \(number): stopped")
    }

    /// The user opens a waiting result: it leaves the Ready list.
    func open(_ number: Int) -> Item? {
        update(number) { $0.opened = true }
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

    /// Runs the Runner's item through the Hand: a script that adds, nothing else, in a job that does not watch the
    /// user and is closed at once. A sheet is a new workbook, then its cells. Returns the Hand's fixed word.
    func add(_ script: HandScript, task number: Int) async -> String {
        let scripts: [HandScript]
        switch script {
        case .note, .reminder, .event: scripts = [script]
        case .cells: scripts = [.workbook, script]
        case .append, .workbook: return AddItemTool.refused  // only whole new items
        }
        guard tasks[number] != nil else { return HandEnd.stopped.rawValue }
        let hand = hand, job = hand.begin(watchUser: false)
        jobs[number] = job
        var end = HandEnd.done
        for script in scripts where end == .done {
            // `kind: .script` always: no target on screen, no click, no app brought to the front.
            let step = HandStep(kind: .script, pid: 0, script: script)
            end = await Task.detached { hand.act(step, in: job) }.value.end
        }
        hand.close(job)
        jobs[number] = nil
        shellLog("task \(number): item \(end.rawValue)")
        return end.rawValue
    }
}

#if DEBUG
extension TaskList {
    /// A made-up entry for the menu and report checks: no task runs, nothing is called.
    func debugAdd(_ item: Item) { items.append(item) }
}
#endif
