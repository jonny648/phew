import AppKit

/// One job on the act route (PH.5), run by the Shell: a fresh look, the Brain's next action, the Hand carries it out,
/// and again, until the Brain says done or stuck, or the Hand ends any way but done (Stop, the user's own click or
/// key, the Never list, a surprise, a ceiling). The Brain never acts, and nothing here acts by itself: every action
/// goes through `Hand.act`, whose ceilings are the brake. Each look lives for one round only and is never kept.
/// The job works in `job.app`: the app the user asked in, then each app the Hand brought to the front (PH.7). At the
/// end the Hand brings back the app the user was in (`Hand.back`).
@MainActor
struct ActJob {
    let brain: any Brain
    let hand: Hand
    /// A fresh look at the app the job works in now (its pid), once per round.
    let capture: (pid_t) async -> ContextPacket?
    /// Before each action, where it acts, screen points with a top-left origin: the card moves out of its way.
    var aside: (CGRect) -> Void = { _ in }
    /// Before each action, its line as it happens ("Pressing Bold"): the card lists it at once (15.5 B).
    var starting: (String) -> Void = { _ in }

    enum Outcome: Equatable {
        case done(String)
        case stuck(String)
        case ended(HandEnd)
        case failed(BrainError)
    }

    /// `listed` gets one plain line per action the Hand made, as it happens. The caller closes `job`.
    func run(_ request: String, job: HandJob, listed: (String) -> Void) async -> Outcome {
        let outcome = await work(request, job: job, listed: listed)
        // Done, stuck, stopped or refused: back to where the user was, unless they took over.
        let hand = hand
        _ = await Task.detached { hand.back(job) }.value
        return outcome
    }

    private func work(_ request: String, job: HandJob, listed: (String) -> Void) async -> Outcome {
        var done: [String] = []  // for the Brain: what was made, by name, and how it ended
        var last = "", repeats = 0  // the same action on the same spot, in a row
        while true {
            if let end = job.end { return .ended(end) }
            let packet = await capture(job.app)
            if let end = job.end { return .ended(end) }
            let next: NextAction
            do {
                next = try await brain.nextAction(request, packet: packet, done: done)
            } catch {
                return job.end.map(Outcome.ended) ?? .failed(BrainError(error))
            }
            // Stop or the user's own input during the call: nothing is sent.
            if let end = job.end { return .ended(end) }
            let step: HandStep
            switch next {
            case .done(let line): return .done(line)
            case .stuck(let line): return .stuck(line)
            case .script(let script):
                step = HandStep(kind: .script, pid: 0, script: script)  // behind the app: nothing on screen to move aside from
            case let .front(app, name):
                step = HandStep(kind: .front, pid: 0, name: name, app: app)  // the Hand checks the app before anything of it is read
            case let .act(kind, target, menu, text):
                guard let packet, let found = Self.step(kind, target: target, menu: menu, text: text, packet: packet, pid: job.app)
                else { return .stuck(Self.noTarget) }
                step = found
                if kind != .pick { aside(step.frame) }
            }
            // Seen live on 15 November: a click that did not land was asked for 11 times. The same action a third time
            // in a row means nothing changed: he stops, in code, whatever the model says.
            let same = "\(step.kind.rawValue) \(Self.line(step)) \(step.frame)"
            repeats = same == last ? repeats + 1 : 0
            last = same
            guard repeats < 2 else { return .stuck(Self.noChange) }
            starting(Self.line(step, doing: true))
            let hand = hand
            // Off the main thread: an app that hangs blocks for at most `Hand.timeout`.
            let result = await Task.detached { hand.act(step, in: job) }.value
            let line = Self.line(step)
            done.append("\(line): \(result.end.rawValue)")
            guard result.end == .done else { return .ended(result.end) }
            listed(line)
        }
    }

    static let noChange = "I did the same thing twice and nothing changed, so I stopped."
    static let noTarget = "I could not find that control on the screen, so I stopped."

    /// The Brain's action as the Hand takes it: role, name and frame as this look saw the element. A name cut to the
    /// packet's label length is left out, so it is not taken for a renamed control. A point (screenshot pixels, put on
    /// the screen by `screenRect`) is for clicks only, and only inside the window of the app the job works in.
    static func step(_ kind: HandStep.Kind, target: StepTarget?, menu: [String], text: String, packet: ContextPacket, pid: pid_t) -> HandStep? {
        if kind == .pick {
            guard !menu.isEmpty else { return nil }
            return HandStep(kind: .pick, pid: pid, role: "AXMenuItem", name: menu.last!, menuPath: menu, opensWindow: opens(menu.last!))
        }
        guard [.press, .set, .click].contains(kind), let target, let frame = packet.screenRect(for: target) else { return nil }
        guard case .element(let id) = target, let element = packet.pointables.first(where: { $0.id == id }) else {
            guard kind == .click, packet.windowFrame?.contains(frame.origin) == true else { return nil }
            return HandStep(kind: .click, pid: pid, frame: frame)
        }
        let name = element.label.count < ContextPacket.labelCap ? element.label : ""
        return HandStep(kind: kind, pid: pid, role: element.role, name: name, frame: frame, text: text, opensWindow: opens(name))
    }

    /// A Mac command whose name ends in an ellipsis opens a window or sheet: the next step takes it as expected.
    static func opens(_ name: String) -> Bool { name.hasSuffix("…") || name.hasSuffix("...") }

    /// One plain line for the card (docs/13-hand.md 13.4): a fixed word and the control's name. `doing`: while it
    /// happens ("Pressing Bold"). Memory only, never logged.
    static func line(_ step: HandStep, doing: Bool = false) -> String {
        let name = step.name.isEmpty ? nil : step.name
        switch step.kind {
        case .press: return "\(doing ? "Pressing" : "Pressed") \(name ?? "a control")"
        case .set: return "\(doing ? "Typing" : "Typed") \(step.text.count) character\(step.text.count == 1 ? "" : "s") in \(name ?? "a field")"
        case .pick: return "\(doing ? "Picking" : "Picked") \(step.menuPath.joined(separator: " > "))"
        case .click: return "\(doing ? "Clicking" : "Clicked") \(name ?? "a spot")"
        case .front: return "\(doing ? "Switching" : "Switched") to \(name ?? "another app")"
        case .script:
            switch step.script {
            case .note(let title, _): return "Made the note “\(title)” in Notes"
            case .append(let text): return "Added \(text.count) character\(text.count == 1 ? "" : "s") to the note"
            case .reminder(let title, _): return "Added the reminder “\(title)”"
            case .event(let title, _, _): return "Added the event “\(title)” to Calendar"
            case .workbook: return "Made a new workbook in Excel"
            case let .cells(top, rows): return "Filled \(rows.joined().count) cells from \(top) in Excel"
            case nil: return "Ran a script"
            }
        }
    }

    /// Why the job stopped, in plain words (13.4).
    static func sentence(for end: HandEnd) -> String {
        switch end {
        case .done: "Done."
        case .stopped: "Stopped."
        case .userInput: "You took over, so the job is yours now."
        case .off: "Acting is off, so I did nothing."
        case .secureField, .secureInput: "That is a password or other secure field. I never type there."
        case .neverReadApp: "This app is on your Never read list, so I did nothing in it."
        case .neverActApp: "I never act in this app."
        case .ownApp: "I never act on Phew's own windows."
        case .password: "I never touch passwords."
        case .paying: "I never pay or enter card details."
        case .signIn: "I never sign in or change account settings."
        case .jobCeiling: "I reached the most actions one job may take, so I stopped."
        case .minuteCeiling: "I reached the most actions in one minute, so I stopped."
        case .gone: "The control is not there any more. I stopped."
        case .moved: "The control is not where it was. I stopped."
        case .surprise: "A window the job did not call for appeared. I stopped."
        case .frontChanged: "Another app came to the front. I stopped."
        case .failed: "I could not do it. Nothing changed, as far as I can see."
        case .timeout: "The app did not answer in time. I stopped."
        case .checkFailed: "I acted, but I could not see the change. Check before going on."
        case .noAccess: "macOS has not allowed me to use that app. You can allow it in System Settings, Privacy & Security."
        }
    }
}
