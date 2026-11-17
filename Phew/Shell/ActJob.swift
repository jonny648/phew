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
    /// A fresh look at the app the job works in now (its pid), once per round; not in round 1 when `firstLook` is
    /// given, nor after a step behind the app (R53, R54).
    let capture: (pid_t) async -> ContextPacket?
    /// Before each action, where it acts, screen points with a top-left origin: the card moves out of its way.
    var aside: (CGRect) -> Void = { _ in }
    /// Before each action, its line as it happens ("Pressing Bold"): the card lists it at once (15.5 B).
    var starting: (String) -> Void = { _ in }
    /// Every hearing of a job asked aloud, best first (P6.3); empty when typed.
    var spoken: [Hearing] = []
    /// Each action that landed, with how: the card ticks its row, tags it, and follows a switch (N2.5).
    var landed: (HandStep, HandResult) -> Void = { _, _ in }
    /// NC.9: a skill step ended, its line and whether it worked: the card ticks its row or marks it not done.
    var skilled: (String, Bool) -> Void = { _, _ in }
    /// The names of an app's menu commands (`MenuReader.names(pid:)`), read once per job and per app (N2.6).
    var menus: (pid_t) async -> String = { _ in "" }
    /// The look taken at the shortcut, of the app the job starts in: round 1 uses it instead of a second screen read
    /// (R53). The Hand's own checks (gone, moved, front changed) stop a step this look no longer fits. Gone with the job.
    var firstLook: ContextPacket?
    /// R5: true while he waits for room at the minute ceiling, false when he goes on: the card shows `pausedLine`.
    var paused: (Bool) -> Void = { _ in }
    /// The job's own clock and wait, for its count of steps (skill steps too). Tests advance a made-up clock.
    var clock: () -> Date = Date.init
    var wait: (TimeInterval) async -> Void = { try? await Task.sleep(for: .seconds($0)) }

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
        var menuNames: [pid_t: String] = [:]  // once per app, gone with the job
        // R54: after a step behind the app, the last look again without its picture: the step does not show on the
        // screen, and the Hand already read it back. Each is used for one round only.
        var reuse = firstLook
        // NC.9: when each step of the job ran, a skill step's too, so the Hand's ceilings count them all; the last
        // skill result, for the next rounds; and the skill steps that failed. Gone with the job.
        var ran: [Date] = []
        var skill: String?
        var skillsFailed = 0
        // R5: the Hand's own pause, told off the main thread, shown on the card on it.
        let paused = paused
        job.pausing = { on in Task { @MainActor in paused(on) } }
        // N4.5: the rest of the last call's plan, made on `planned`; what the action just made should show (nil: nothing
        // to check); and the look that action was made on. Gone with the job.
        var plan: [PlannedAction] = []
        var planned: ContextPacket?
        var expect: String?
        var before: ContextPacket?
        while true {
            if let end = job.end { return .ended(end) }
            let app = job.app
            var packet: ContextPacket?
            let next: NextAction
            if !plan.isEmpty {
                // The plan goes on only when what the last action should show has appeared since the look before it.
                // Anything else drops the rest and asks again on this fresh look: asked again, never a step on a stale plan.
                if let want = expect {
                    let fresh = await capture(app)
                    if let end = job.end { return .ended(end) }
                    guard let fresh, fresh.shows(want), before?.shows(want) != true else {
                        shellLog("act: plan dropped, \(plan.count) actions left, asked again")
                        plan = []
                        reuse = fresh
                        continue
                    }
                    before = fresh
                }
                packet = planned
                let item = plan.removeFirst()
                (next, expect) = (item.action, item.expect)
            } else {
                packet = reuse
                reuse = nil
                if packet == nil { packet = await capture(app) }
                // Not for an app on the Never read list: its look came back empty, and so do its menus.
                if packet?.neverRead == false {
                    if menuNames[app] == nil { menuNames[app] = await menus(app) }
                    packet?.menus = SecretsFilter.clean(menuNames[app] ?? "")
                }
                if let end = job.end { return .ended(end) }
                do {
                    plan = try await brain.nextActions(request, packet: packet, done: done, spoken: spoken, skill: skill)
                } catch {
                    return job.end.map(Outcome.ended) ?? .failed(BrainError(error))
                }
                guard !plan.isEmpty else { return .failed(.badOutput) }
                let item = plan.removeFirst()
                (next, expect) = (item.action, item.expect)
                (planned, before) = (packet, packet)
            }
            // Stop or the user's own input during the call: nothing is sent.
            if let end = job.end { return .ended(end) }
            // NC.9: a skill step only computes, in the Brain's closed box: it never goes to the Hand.
            if case .skill(let step) = next {
                let same = "skill \(step)"
                repeats = same == last ? repeats + 1 : 0
                last = same
                guard repeats < 2 else { return .stuck(Self.noChange) }
                if let end = await brake(ran, job) { return .ended(end) }
                ran.append(clock())
                starting(Self.line(step, doing: true))
                let (ok, said) = await brain.skillStep(step, stop: { job.end != nil })  // Stop ends a running skill
                if let end = job.end { return .ended(end) }
                let line = Self.line(step)
                skilled(line, ok)
                if ok, case .run = step {
                    skill = said
                    done.append("\(line): done")
                } else {
                    done.append("\(line): \(said)")
                }
                if !ok { skillsFailed += 1 }
                guard skillsFailed < 3 else { return .stuck(Self.skillsFailed) }
                reuse = Self.withoutPicture(packet)  // nothing changed on the screen
                plan = []  // its result is for the next call to use
                continue
            }
            let step: HandStep
            switch next {
            case .done(let line): return .done(line)
            case .stuck(let line): return .stuck(line)
            case .skill: continue  // handled above
            case .script(let script):
                step = HandStep(kind: .script, pid: 0, script: script)  // behind the app: nothing on screen to move aside from
            case let .front(app, name):
                step = HandStep(kind: .front, pid: 0, name: name, app: app)  // the Hand checks the app before anything of it is read
            case let .act(kind, target, menu, text):
                guard let packet, let found = Self.step(kind, target: target, menu: menu, text: text, packet: packet, pid: job.app)
                else { return .stuck(Self.noTarget) }
                step = found
                if kind != .pick { aside(step.frame) }
            case let .input(kind, target, to, keys, text, amount):
                guard let found = Self.input(kind, target: target, to: to, keys: keys, text: text, amount: amount, packet: packet, pid: job.app)
                else { return .stuck(Self.noTarget) }
                step = found
                if kind != .keys { aside(step.frame) }
            }
            // Seen live on 15 November: a click that did not land was asked for 11 times. The same action a third time
            // in a row means nothing changed: he stops, in code, whatever the model says. A key or a scroll repeated
            // is normal (arrow down, scroll down): the eleventh in a row stops.
            let same = "\(step.kind.rawValue) \(Self.line(step)) \(step.frame)"
            repeats = same == last ? repeats + 1 : 0
            last = same
            guard repeats < ([.keys, .scroll].contains(step.kind) ? Self.sameKeys : 2) else { return .stuck(Self.noChange) }
            // The Hand counts only its own steps; this counts the job's skill steps too.
            if let end = await brake(ran, job) { return .ended(end) }
            starting(Self.line(step, doing: true))
            let hand = hand
            // Off the main thread: an app that hangs blocks for at most `Hand.timeout`, a pause at the minute ceiling
            // for up to a minute.
            let result = await Task.detached { hand.act(step, in: job) }.value
            ran.append(clock())
            let line = Self.line(step)
            done.append("\(line): \(result.end.rawValue)")
            // R6: the items that share the title, on the card only.
            if result.end == .manyFound, !result.choices.isEmpty { return .stuck(Self.choose(result.choices)) }
            guard result.end == .done else { return .ended(result.end) }
            listed(line)
            landed(step, result)
            if step.kind == .script {
                reuse = Self.withoutPicture(packet)
                expect = nil  // N4.5: behind the app, nothing to see; the Hand read it back
            }
            // N4.5: nothing goes past an action that cannot be undone or leaves the Mac (or that code could not judge),
            // keys or a switch of app, whatever the plan said: Phew's code decides, as the Hand judged it.
            if result.final || result.marked || [.keys, .front].contains(step.kind) { plan = [] }
        }
    }

    /// The job's own ceilings, over all its steps: 40 ends it; at 20 in a minute he waits for room (R5), with one line
    /// on the card. Stop and the user's touch end the wait within 0.1 s. Waits without holding the main thread.
    private func brake(_ ran: [Date], _ job: HandJob) async -> HandEnd? {
        if ran.count >= Hand.perJob { return .jobCeiling }
        var said = false
        defer { if said { paused(false) } }
        while let left = Hand.room(recent: ran, now: clock()) {
            if let end = job.end { return end }
            if !said { said = true; paused(true) }
            await wait(min(left, 0.1))
        }
        return job.end
    }

    /// R5: the card's line while he waits.
    static let pausedLine = "Waiting a moment: I make at most 20 actions a minute."

    /// The same key or scroll in a row, at most this many (17 November); any other step, two.
    static let sameKeys = 10

    /// R6: several items share the title: the plain reason and the choices, so the user can say which. Card only.
    static func choose(_ choices: [String]) -> String {
        sentence(for: .manyFound) + " I found " + choices.joined(separator: "; ") + ". Tell me which one."
    }

    /// The last look without its picture, for one more round (R54).
    private static func withoutPicture(_ packet: ContextPacket?) -> ContextPacket? {
        guard var last = packet else { return nil }
        last.screenshot = nil
        last.image = nil  // the raw pixels go with the picture
        return last
    }

    static let skillsFailed = "My skills failed three times, so I stopped."

    /// NC.9: a skill step's line on the card, by the name the model gave. Memory only, never logged.
    static func line(_ step: SkillStep, doing: Bool = false) -> String {
        switch step {
        case .write(let name, _, _, _, _): return "\(doing ? "Writing" : "Wrote") the skill \(name.prefix(40))"
        case .run(let name, _): return "\(doing ? "Running" : "Ran") the skill \(name.prefix(40))"
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
        let clicks: [HandStep.Kind] = [.click, .doubleClick, .rightClick]
        guard ([.press, .set] + clicks).contains(kind), let target, let frame = packet.screenRect(for: target) else { return nil }
        guard case .element(let id) = target, let element = packet.pointables.first(where: { $0.id == id }) else {
            guard clicks.contains(kind), packet.windowFrame?.contains(frame.origin) == true else { return nil }
            return HandStep(kind: kind, pid: pid, frame: frame)
        }
        let name = element.label.count < ContextPacket.labelCap ? element.label : ""
        return HandStep(kind: kind, pid: pid, role: element.role, name: name, frame: frame, text: text, opensWindow: opens(name))
    }

    /// R1: a scroll, a drag or keys as the Hand takes them. Keys need no target: they go to the job's app. A scroll or
    /// a drag starts on an element of the look or a point inside the job's window, as a click does; a drag ends on
    /// one too.
    static func input(_ kind: HandStep.Kind, target: StepTarget?, to: StepTarget?, keys: HandChord?, text: String, amount: Int,
                      packet: ContextPacket?, pid: pid_t) -> HandStep? {
        if kind == .keys {
            guard keys != nil || !text.isEmpty else { return nil }
            return HandStep(kind: .keys, pid: pid, text: keys == nil ? text : "", opensWindow: keys.map(opens) ?? false, chord: keys)
        }
        guard [.scroll, .drag].contains(kind), let packet, var step = step(.click, target: target, menu: [], text: "", packet: packet, pid: pid)
        else { return nil }
        step.kind = kind
        step.opensWindow = false
        if kind == .scroll {
            step.amount = amount
            return amount == 0 ? nil : step
        }
        guard let to, let end = packet.screenRect(for: to) else { return nil }
        if case .point = to, packet.windowFrame?.contains(end.origin) != true { return nil }
        step.to = CGPoint(x: end.midX, y: end.midY)
        return step
    }

    /// A Mac command whose name ends in an ellipsis, or is one of `sheetNames`, opens a window or sheet: the next step
    /// takes it as expected (R4). Decided here from the control's own name as read, never by the model.
    static func opens(_ name: String) -> Bool {
        name.hasSuffix("…") || name.hasSuffix("...") || sheetNames.contains(NeverList.fold(name))
    }

    /// The commands that open a sheet or dialog with no "…" in some apps, English and Italian, folded.
    static let sheetNames: Set<String> = [
        "save", "save as", "export", "open", "print", "share", "new", "rename", "insert", "format", "find", "go to",
        "salva", "salva con nome", "esporta", "apri", "stampa", "condividi", "nuovo", "nuova", "rinomina", "inserisci",
        "formato", "trova", "cerca", "vai a",
    ]

    /// The shortcuts that open a sheet: save, open, print, save as (R4).
    static func opens(_ chord: HandChord) -> Bool { sheetChords.contains(chord) }
    static let sheetChords: Set<HandChord> = Set(["cmd+s", "cmd+o", "cmd+p", "cmd+shift+s"].compactMap(HandChord.parse))

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
        case .doubleClick: return "\(doing ? "Double-clicking" : "Double-clicked") \(name ?? "a spot")"
        case .rightClick: return "\(doing ? "Right-clicking" : "Right-clicked") \(name ?? "a spot")"
        case .scroll:
            let lines = abs(step.amount)
            return "\(doing ? "Scrolling" : "Scrolled") \(step.amount < 0 ? "up" : "down") \(lines) line\(lines == 1 ? "" : "s")\(name.map { " in \($0)" } ?? "")"
        case .drag: return "\(doing ? "Dragging" : "Dragged") \(name ?? "from a spot")"
        case .keys:
            if let chord = step.chord { return "\(doing ? "Pressing" : "Pressed") \(chord.symbols)" }
            return "\(doing ? "Typing" : "Typed") \(step.text.count) character\(step.text.count == 1 ? "" : "s")"
        case .connector:
            return "\(doing ? "Writing" : "Wrote") in \(step.connector?.name ?? "a connected tool")\(step.connector.map { " (\($0.tool))" } ?? "")"
        case .script:
            switch step.script {
            case .note(let title, _): return "Made the note “\(title)” in Notes"
            case let .append(text, title):
                return "Added \(text.count) character\(text.count == 1 ? "" : "s") to the note\(title.isEmpty ? "" : " “\(title)”")"
            case .reminder(let title, _): return "Added the reminder “\(title)”"
            case .event(let title, _, _): return "Added the event “\(title)” to Calendar"
            case .workbook: return "Made a new workbook in Excel"
            case let .cells(top, rows): return "Filled \(rows.joined().count) cells from \(top) in Excel"
            case let .rename(item, title, to): return "Renamed the \(item.rawValue) “\(title)” to “\(to)”"
            case let .noteBody(title, _): return "Rewrote the note “\(title)”"
            case let .complete(title): return "Ticked the reminder “\(title)” done"
            case let .move(title, _, _): return "Moved the event “\(title)”"
            case let .changeCells(book, top, rows): return "Wrote over \(rows.joined().count) cells from \(top) in “\(book)”"
            case let .delete(item, title): return "Deleted the \(item.rawValue) “\(title)”"
            case .restore: return "Put back what was there"
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
        case .neverKeys: "I never press that shortcut: it quits, logs out, locks, empties the Trash or leaves the app."
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
        case .notFound: "I found nothing with that exact name, so I changed nothing."
        case .manyFound: "More than one thing has that exact name, so I changed nothing."
        case .needsConfirm: "That cannot be undone, so it waits in the menu bar for your confirm."
        }
    }
}
