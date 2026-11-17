import Foundation

/// The only door from Shell and Senses into the Brain, so it can move to a backend later.
protocol Brain: Sendable {
    /// `question` may be empty: then Phew explains what is under the cursor. Events arrive in this order:
    /// `.route`, `.text` pieces as they stream, `.steps` (guide route only), `.done`.
    /// Errors are `BrainError`; `.noKey` means the Shell should ask for the API key.
    func answer(_ question: String, packet: ContextPacket?) -> AsyncThrowingStream<BrainEvent, Error>

    /// The same, with what only the Shell knows of Phew's own state, for questions about himself (PS.14).
    func answer(_ question: String, packet: ContextPacket?, state: ShellState) -> AsyncThrowingStream<BrainEvent, Error>

    /// The same for a question said aloud (P6.3): `question` is the best hearing, as shown on the card, and `spoken`
    /// holds every hearing, best first, for the model to read against the screen. Empty: a typed question. Only a
    /// spoken question can come back `.route(.unclear)`.
    func answer(_ question: String, packet: ContextPacket?, state: ShellState, spoken: [Hearing]) -> AsyncThrowingStream<BrainEvent, Error>

    /// D7 "Send as it is": a typed `answer` whose `question` goes to the Guide as the user wrote it, past the secrets
    /// filter, for this one request. Only after the user pressed the card's button, never on the model's word. The
    /// screen, the Map, project memory and tool results are filtered as always; the turn kept for follow-ups and what
    /// the Librarian learns hold the filtered words. A Brain without it filters as usual.
    func answerAsItIs(_ question: String, packet: ContextPacket?, state: ShellState) -> AsyncThrowingStream<BrainEvent, Error>

    /// Names from the Map for the recogniser (P6.3): Projects, People, Tools and Organizations, the most recently
    /// changed first, at most 30. Names only, never a fact; nothing sensitive. Empty without a Map.
    func spokenNames() async -> [String]

    /// N3.2: words heard before for those names and corrected by the user, heard words to name. Empty without a Map.
    func heardAs() async -> [String: String]
    /// N3.2: the user changed a heard text shown first (`heard`) into `meant` before sending. When the change is one
    /// word or a pair and the new words are a name in the Map, the old words are kept as "also heard as" of that name.
    /// True when something was kept. Never logged.
    func learnHeard(_ heard: String, meant: String) async -> Bool

    /// During a guide, after the user acts: looks at a fresh `packet` and says which of `steps` the user is on
    /// now, starting from `current` (0-based), so the guide moves on by itself. A runaway or bad answer is tried
    /// once more (PS.5). A refusal or a second bad answer does not end the guide: it returns `current` with no
    /// target, not `checked`. Key, network and rate errors throw
    /// `BrainError` like `answer`.
    func progress(steps: [GuideStep], current: Int, packet: ContextPacket?) async throws -> GuideProgress

    /// During a job on the act route (PH.5): from a fresh `packet` and the actions made so far (`done`, one plain line
    /// each, oldest first), the next single action, or that the job is done, or stuck. The Brain never acts: the
    /// Shell carries the action out through the Hand. Errors are `BrainError`, like `answer`.
    func nextAction(_ request: String, packet: ContextPacket?, done: [String]) async throws -> NextAction
    /// The same for a job asked aloud: `spoken` as in `answer`.
    func nextAction(_ request: String, packet: ContextPacket?, done: [String], spoken: [Hearing]) async throws -> NextAction
    /// NC.9: the same, with what the job's last skill run gave (`skillStep`, its `<skill>` block), for the model as
    /// data. Nil: none ran.
    func nextAction(_ request: String, packet: ContextPacket?, done: [String], spoken: [Hearing], skill: String?) async throws -> NextAction
    /// NC.9: a skill step of a job on the act route, written or run in the closed box only: never through the Hand,
    /// nothing on the Mac. `ok`: it worked. `line`: how it ended, for the next round; a run that worked gives its
    /// result in its `<skill>` block. `stop` is asked while a skill runs. A Brain without skills says so.
    func skillStep(_ step: SkillStep, stop: @escaping @Sendable () -> Bool) async -> (ok: Bool, line: String)

    /// Drops the earlier questions and answers of the conversation. The Shell calls it when the card closes and on Quit.
    func forgetTurns()

    /// Each forget waiting in Recently deleted, for the menu's list.
    func recentlyDeleted() async -> [DeletedItem]
    /// Puts a forget back as it was. False if it could not.
    func restore(_ id: Int64) async -> Bool
    /// Wipes a forget for real at once. False if it could not.
    func deleteNow(_ id: Int64) async -> Bool

    /// The Map as one Markdown document (P5.10), sensitive facts only when asked. Nil when there is no Map to read.
    func exportMap(includeSensitive: Bool) async -> String?

    /// A research task on the task route (PA.1): the Runner works alone from `words`, the one screen read made when
    /// the task was given (`packet`, dropped when the task ends), the Map and the web, then the report is saved as a
    /// new PDF in `folder` (nil: Downloads) with a Markdown copy in Phew's storage. Events: `.searching` and
    /// `.reading` counts and `.writing` while it works, then `.done` with the report. Cancelling the stream is Stop:
    /// within 2 seconds, nothing saved, no event after. `number` names the task in calls.log. Errors are `BrainError`.
    /// `add` (PA.4): the Shell's door for the Runner's `add_item`; the Brain never acts. Nil: no `add_item` tool.
    func runTask(_ words: String, packet: ContextPacket?, number: Int, folder: URL?, add: AddItem?) -> AsyncThrowingStream<TaskEvent, Error>
    /// The same for a task given aloud: `spoken` as in `answer`.
    func runTask(_ words: String, packet: ContextPacket?, number: Int, folder: URL?, spoken: [Hearing], add: AddItem?) -> AsyncThrowingStream<TaskEvent, Error>

    /// A turn the Shell showed without asking (a task's report opened from the menu), so a reply can follow it.
    func keepTurn(_ question: String, answer: String)

    // MARK: Imported memory (docs/05-map.md 5.10, phase PB)

    /// The paste box, after the user confirms: the text is filtered, then sorted into candidate facts by the small
    /// model, as data. Writes nothing; candidates live in memory only. Errors are `BrainError`.
    func sortImport(_ text: String, source: ImportSource) async throws -> ImportSort
    /// A project folder the user chose: reads only its CLAUDE.md files and that project's Claude Code memory files,
    /// into memory, and remembers the folder so its files can be read again when a question or a task is about that
    /// project. Sends nothing: show the file names and sizes, then call `sortImport(_:)` on confirm.
    func projectMemory(folder: URL) -> ProjectMemory
    /// The files of `projectMemory`, sorted like a paste, one call per file, source Claude Code.
    func sortImport(_ memory: ProjectMemory) async throws -> ImportSort
    /// Claude's memory export, the main way in: a folder or a `.zip` the user chose, read on this Mac into memory (a
    /// ZIP through a private temporary folder, deleted before this returns). Sends nothing: show the groups, then call
    /// `sortImport(_:progress:)` on Sort. `problem` is set when it is not an export.
    func claudeExport(at url: URL) async -> ClaudeExport
    /// The export's files, one small-model call per file, a few at once; candidates carry their group. Cancelling the
    /// task sends nothing more. `progress`: files done and the total, from any thread. Writes nothing.
    func sortImport(_ export: ClaudeExport, progress: @escaping @Sendable (Int, Int) -> Void) async throws -> ImportSort
    /// N2.11: a finished task's report, only when the user opens its list from the menu: filtered, then sorted by the
    /// small model in one call, counted by the limits. Every candidate starts unticked, source `.report`. Writes nothing.
    func sortReport(_ markdown: String) async throws -> ImportSort
    /// Writes only the candidates with `ticked` true, as one import. Errors are `BrainError`.
    func keepImport(_ candidates: [ImportCandidate]) async throws -> ImportKept
    /// The last import while it can be undone, for the menu entry. Nil: the entry is off.
    func lastImport() async -> ImportInfo?
    /// "Undo last import": the card's one line, or nil when there was nothing to undo. Restore is `restore(_:)`.
    func undoLastImport() async -> String?
    /// True while the Map cannot be opened, for the menu's one fixed line (R28). Asking tries the open again.
    func memoryOff() async -> Bool
    /// NC: the skills Phew wrote for himself, for the menu's list, and deleting one by name.
    func skills() async -> [Skill]
    func deleteSkill(_ name: String) async

    // MARK: Limits

    /// Today's spend and started requests against the ceilings, for the Limits panel. Nil: this Brain has no limits.
    func limitsToday() async -> LimitsToday?
    /// The daily dollar ceiling, from the next request on. 0: no limit.
    func setDayLimit(usd: Double)
    /// NA.13: the request ceilings, from the next request on, kept within `Limits.dayBounds` and `minuteBounds`.
    func setDayLimit(requests: Int)
    func setMinuteLimit(requests: Int)
}

extension Brain {
    func answer(_ question: String, packet: ContextPacket?, state: ShellState) -> AsyncThrowingStream<BrainEvent, Error> {
        answer(question, packet: packet)
    }
    /// A Brain that does not read hearings answers the best one as if typed.
    func answer(_ question: String, packet: ContextPacket?, state: ShellState, spoken: [Hearing]) -> AsyncThrowingStream<BrainEvent, Error> {
        answer(question, packet: packet, state: state)
    }
    func answerAsItIs(_ question: String, packet: ContextPacket?, state: ShellState) -> AsyncThrowingStream<BrainEvent, Error> {
        answer(question, packet: packet, state: state)
    }
    func spokenNames() async -> [String] { [] }
    func heardAs() async -> [String: String] { [:] }
    func learnHeard(_ heard: String, meant: String) async -> Bool { false }
    func forgetTurns() {}
    func nextAction(_ request: String, packet: ContextPacket?, done: [String]) async throws -> NextAction { .stuck("") }
    func nextAction(_ request: String, packet: ContextPacket?, done: [String], spoken: [Hearing]) async throws -> NextAction {
        try await nextAction(request, packet: packet, done: done)
    }
    func nextAction(_ request: String, packet: ContextPacket?, done: [String], spoken: [Hearing], skill: String?) async throws -> NextAction {
        try await nextAction(request, packet: packet, done: done, spoken: spoken)
    }
    func skillStep(_ step: SkillStep, stop: @escaping @Sendable () -> Bool) async -> (ok: Bool, line: String) { (false, SkillTools.none) }
    func recentlyDeleted() async -> [DeletedItem] { [] }
    func restore(_ id: Int64) async -> Bool { false }
    func deleteNow(_ id: Int64) async -> Bool { false }
    func exportMap(includeSensitive: Bool) async -> String? { nil }
}

struct DeletedItem: Sendable, Identifiable { let id: Int64; let label: String; let daysLeft: Int }

struct GuideProgress: Sendable, Equatable {
    /// The step the user is on now, 0-based. `steps.count` means every step is done.
    var current: Int
    /// Where that step points on the fresh screen, validated like `GuideStep.target`: an id in this packet, or a
    /// point inside its screenshot. Nil when the guide is done, nothing safe fits, or the check failed.
    var target: StepTarget?
    /// False when the check gave no usable answer (a refusal, a bad or runaway answer twice): `current` is then only
    /// the step it was asked about, not a judgement, so a step a direct hit moved on from is not stepped back.
    var checked = true
}

enum Route: String, Sendable, CaseIterable {
    /// `act` (PH.4): the user's words ask Phew to do it. The answer stream then ends after `.route`, and the Shell runs
    /// the job; with acting off (`ShellState.acting` false) the Brain answers it as a guide instead.
    case explain, guide, remember, act
    /// `task` (PA.2): work handed over to be done alone and reported back. The answer stream ends after `.route`;
    /// the Shell starts the task with `runTask`.
    case task
    /// `unclear` (P6.3): a spoken question where neither hearing makes sense. Nothing is answered and nothing acts:
    /// the stream ends after `.route`, and the Shell shows what was heard in the ask panel, ready to fix. Never for a
    /// typed question.
    case unclear
    /// `watch` (NA.15, D4): tell the user when the thing under the pointer changes. The stream ends after `.route`; the
    /// Shell starts the watcher, only while "Let Phew watch one thing" is on, else it says in one line that it is off.
    case watch
}

/// The next step of a job on the act route, as the Brain chose it from a fresh look (PH.5).
enum NextAction: Sendable, Equatable {
    /// One action. `target`: for press and set the id of one of the packet's pointables; for click that, or a point
    /// in screenshot pixels. Validated like `GuideStep.target`. `menu`: for pick, the path from the menu bar.
    /// `text`: for set, what the field holds afterwards.
    case act(HandStep.Kind, target: StepTarget?, menu: [String] = [], text: String = "")
    /// R1 (NA.5): a scroll, a drag or keys. `target` as for a click (where the scroll or the drag starts); `to` where
    /// the drag ends; `keys` a key or shortcut from the fixed vocabulary, else `text` typed through keys; `amount` the
    /// scroll's lines, down positive.
    case input(HandStep.Kind, target: StepTarget? = nil, to: StepTarget? = nil, keys: HandChord? = nil, text: String = "", amount: Int = 0)
    /// One action through an app's own scripting or the system's reminders and calendar access: no target on screen.
    case script(HandScript)
    /// Another app to the front, to go on there (PH.7): its bundle id, found by its name on this Mac (`Doer.installed`,
    /// NA.6), and its plain name for the card. The Hand checks the bundle id against the Never lists.
    case front(bundleID: String, name: String)
    /// NC.9: a skill written or run, as a step of the job: it only computes, in the closed box, and acts on nothing.
    case skill(SkillStep)
    /// The job is finished: one short line for the card, in the user's language.
    case done(String)
    /// The next action is not possible: one short plain reason for the card. Empty when there is none.
    case stuck(String)
}

/// NC.9: what the Doer asked of a skill, as the model gave it; `SkillStore` checks it.
enum SkillStep: Sendable, Equatable {
    case write(name: String, about: String, code: String, testInput: String, expected: String)
    case run(name: String, input: String)
}

enum BrainEvent: Sendable, Equatable {
    /// A spoken question as the Conductor understood it, misheard words put right (P6.3): shown as the question on
    /// the card in place of the raw hearing. Before `.route`, and only for a spoken question.
    case heard(String)
    case route(Route)
    /// The next piece of the explanation, to append to the card.
    case text(String)
    /// Validated: every element id exists in the packet, every point lies inside the screenshot.
    case steps([GuideStep])
    case done
}

struct GuideStep: Sendable, Equatable {
    var instruction: String
    /// Nil when there is nothing safe to point at.
    var target: StepTarget?
    /// The step needs only one plain click on its target (PS.3): a direct hit there moves the guide on at once.
    /// False for typing, dragging or choosing, and whenever the Guide did not say.
    var click = false
}

enum StepTarget: Sendable, Equatable {
    /// The `id` of one of the packet's pointables, e.g. "e12".
    case element(String)
    /// Screenshot pixels: 1 pixel per screen point, origin at the window's top-left.
    case point(x: Int, y: Int)
}

/// The small, readable set of things that go wrong. Never carries text from the request, the answer or the key.
enum BrainError: Error, Sendable, Equatable {
    case noKey
    case badKey
    case rateLimited
    case overloaded
    case network
    case refused
    /// The model's answer was cut off or did not match its schema.
    case badOutput
    /// The answer ran over its request's time cap and was cancelled (PS.5).
    case runaway
    /// Any other HTTP status from the API (400, 402, 403, 404, 413…).
    case failed(status: Int)
    /// One of Phew's own ceilings (`Limits`) was reached: nothing was sent.
    case limited(Limit)

    enum Limit: Sendable, Equatable {
        /// Too many requests in one minute.
        case minute
        /// Today's dollars, with the ceiling.
        case dayUSD(Double)
        /// Today's requests, with the ceiling.
        case dayRequests(Int)

        /// A fixed word for the log.
        var word: String {
            switch self {
            case .minute: "minute"
            case .dayUSD: "day dollars"
            case .dayRequests: "day requests"
            }
        }
    }
}

extension BrainError {
    init(status: Int) {
        switch status {
        case 401: self = .badKey
        case 429: self = .rateLimited
        case 500...: self = .overloaded  // 500 api_error, 529 overloaded_error
        default: self = .failed(status: status)
        }
    }

    init(_ error: Error) {
        switch error {
        case let error as BrainError: self = error
        case is DecodingError: self = .badOutput
        default: self = .network  // URLError and cancellation
        }
    }
}

extension Brain {
    /// A Brain without agents runs no task.
    func runTask(_ words: String, packet: ContextPacket?, number: Int, folder: URL?, add: AddItem?) -> AsyncThrowingStream<TaskEvent, Error> {
        AsyncThrowingStream { $0.finish(throwing: BrainError.failed(status: 0)) }
    }
    func runTask(_ words: String, packet: ContextPacket?, number: Int, folder: URL?) -> AsyncThrowingStream<TaskEvent, Error> {
        runTask(words, packet: packet, number: number, folder: folder, add: nil)
    }
    func runTask(_ words: String, packet: ContextPacket?, number: Int, folder: URL?, spoken: [Hearing], add: AddItem?) -> AsyncThrowingStream<TaskEvent, Error> {
        runTask(words, packet: packet, number: number, folder: folder, add: add)
    }
    func keepTurn(_ question: String, answer: String) {}

    /// A Brain without a Map imports nothing.
    func sortImport(_ text: String, source: ImportSource) async throws -> ImportSort { ImportSort() }
    func projectMemory(folder: URL) -> ProjectMemory { ProjectMemory(projectName: folder.lastPathComponent) }
    func sortImport(_ memory: ProjectMemory) async throws -> ImportSort { ImportSort() }
    func claudeExport(at url: URL) async -> ClaudeExport { ClaudeExport(problem: ClaudeExport.notExport) }
    func sortImport(_ export: ClaudeExport, progress: @escaping @Sendable (Int, Int) -> Void) async throws -> ImportSort { ImportSort() }
    func sortReport(_ markdown: String) async throws -> ImportSort { ImportSort() }
    func keepImport(_ candidates: [ImportCandidate]) async throws -> ImportKept { ImportKept() }
    func lastImport() async -> ImportInfo? { nil }
    func undoLastImport() async -> String? { nil }
    func memoryOff() async -> Bool { false }
    func skills() async -> [Skill] { [] }
    func deleteSkill(_ name: String) async {}

    func limitsToday() async -> LimitsToday? { nil }
    func setDayLimit(usd: Double) {}
    func setDayLimit(requests: Int) {}
    func setMinuteLimit(requests: Int) {}
}
