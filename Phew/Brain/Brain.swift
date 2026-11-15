/// The only door from Shell and Senses into the Brain, so it can move to a backend later.
protocol Brain: Sendable {
    /// `question` may be empty: then Phew explains what is under the cursor. Events arrive in this order:
    /// `.route`, `.text` pieces as they stream, `.steps` (guide route only), `.done`.
    /// Errors are `BrainError`; `.noKey` means the Shell should ask for the API key.
    func answer(_ question: String, packet: ContextPacket?) -> AsyncThrowingStream<BrainEvent, Error>

    /// The same, with what only the Shell knows of Phew's own state, for questions about himself (PS.14).
    func answer(_ question: String, packet: ContextPacket?, state: ShellState) -> AsyncThrowingStream<BrainEvent, Error>

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
}

extension Brain {
    func answer(_ question: String, packet: ContextPacket?, state: ShellState) -> AsyncThrowingStream<BrainEvent, Error> {
        answer(question, packet: packet)
    }
    func forgetTurns() {}
    func nextAction(_ request: String, packet: ContextPacket?, done: [String]) async throws -> NextAction { .stuck("") }
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
}

/// The next step of a job on the act route, as the Brain chose it from a fresh look (PH.5).
enum NextAction: Sendable, Equatable {
    /// One action. `target`: for press and set the id of one of the packet's pointables; for click that, or a point
    /// in screenshot pixels. Validated like `GuideStep.target`. `menu`: for pick, the path from the menu bar.
    /// `text`: for set, what the field holds afterwards.
    case act(HandStep.Kind, target: StepTarget?, menu: [String] = [], text: String = "")
    /// One action through an app's own scripting or the system's reminders and calendar access: no target on screen.
    case script(HandScript)
    /// The job is finished: one short line for the card, in the user's language.
    case done(String)
    /// The next action is not possible: one short plain reason for the card. Empty when there is none.
    case stuck(String)
}

enum BrainEvent: Sendable, Equatable {
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
