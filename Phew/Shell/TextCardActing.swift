import AppKit
import SwiftUI

/// The act route on the card (PH.5, look in docs/15-design.md 15.5 B and C): Phew does the job in the front app.
/// Each action is a row on the card as it happens, ticked when it lands; the pointer presses on the spot and the ring
/// stays there; the footer holds Stop. Then the summary, or the plain reason he stopped. Stop is the footer's button,
/// Escape or closing the card (`dismiss`), and the user's own click or key in the app he works in (`Hand.begin`).
/// A job may bring another app to the front (PH.7); the Hand brings the user's app back at the end.
/// Split out of TextCard.swift; the stored state stays on `TextCard`.
extension TextCard {
    /// One fixed line above a guide given instead of acting, while acting is off.
    static let actingOff = "Acting is off, so here is how to do it."

    #if DEBUG
    /// PH.10: set only by `--debug-act`. The app of the test's own made-up window, and every look of the job at the app
    /// it works in now (PH.7), already checked to be a window the test made; nil when it is not, so nothing is sent.
    static var testWindow: (pid: pid_t, look: (pid_t) async -> ContextPacket?)?
    #endif

    /// Runs the job in `app`, the app the user asked in. Returns when it ends; the Hand's watch goes with it.
    /// If another app has come to the front meanwhile, it stops before any look, so no other app's screen is read.
    func act(_ request: String, spoken: [Hearing] = [], in app: NSRunningApplication?) async {
        var app = app
        // Each look reads the app the job works in, never whatever came to the front meanwhile (the Hand stops then).
        var look: ((pid_t) async -> ContextPacket?)?
        var watchUser = true
        #if DEBUG
        // A live test acts in its own made-up app while the user works in others: their clicks are not a take-over.
        if let test = Self.testWindow { (app, look, watchUser) = (NSRunningApplication(processIdentifier: test.pid), test.look, false) }
        #endif
        guard let brain, let app, app.processIdentifier != getpid() else { return }
        guard look != nil || NSWorkspace.shared.frontmostApplication == app else {
            shellLog("act: not started, another app came to the front")
            model.problem = ActJob.sentence(for: .frontChanged)
            return
        }
        // The app the job works in now, by pid; one no longer running gives no look, never the front app's.
        let capture: (pid_t) async -> ContextPacket? = look ?? { pid in
            guard let app = NSRunningApplication(processIdentifier: pid) else { return nil }
            return await Senses.capture(app: app).value
        }
        let job = Hand.shared.begin(watchUser: watchUser, in: app.processIdentifier)
        handJob = job
        model.startActing(in: app.localizedName ?? "")
        let start = Date()
        var count = 0
        shellLog("act: job \(job.number) started")
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        let screen = NSScreen.screens.first { $0.frame.contains(frame.origin) } ?? NSScreen.screens[0]
        let pointer = PointerOverlay(on: screen)
        overlay = pointer
        var run = ActJob(brain: brain, hand: .shared, capture: capture,
                         aside: { [weak self] rect in
                             let spot = rect.flipped(mainHeight: mainHeight)
                             self?.moveAside(from: spot)
                             pointer.act(on: spot)
                         })
        run.spoken = spoken
        run.starting = { [weak self] line in self?.model.actions.append(CardModel.Action(line: line)) }
        let outcome = await run.run(request, job: job) { [weak self] line in
            count += 1
            guard let self, !model.actions.isEmpty else { return }
            model.actions[model.actions.count - 1].line = line
            model.actions[model.actions.count - 1].state = .done
        }
        Hand.shared.close(job)
        handJob = nil
        if overlay === pointer {
            pointer.goHome()
            overlay = nil
        }
        let kind = switch outcome { case .done: "done"; case .stuck: "stuck"; case .ended(let end): end.rawValue; case .failed(let error): "error \(error)" }
        shellLog("act: job \(job.number) ended \(kind), \(count) actions, \(Int(Date().timeIntervalSince(start) * 1000)) ms")
        guard !Task.isCancelled, isVisible else { return }  // the card was closed: nothing more to show
        model.acting = false
        // A row still under way did not land: the Hand refused it, or the job ended before it was sent.
        if let last = model.actions.indices.last, model.actions[last].state == .now { model.actions[last].state = .failed }
        switch outcome {
        case .done(let line): model.text = line.isEmpty ? "Done." : line
        case .stuck(let line): model.problem = line.isEmpty ? "I could not go on, so I stopped." : line
        // Stopped by the user: a plain line, no symbol.
        case .ended(let end) where end == .stopped || end == .userInput: model.ended = ActJob.sentence(for: end)
        case .ended(let end): model.problem = ActJob.sentence(for: end)
        case .failed(let error): model.problem = Self.sentence(for: error)
        }
    }
}

/// The "Let Phew act" switch, `Hand.allowedKey` in the defaults: on when never set, off only from the menu.
struct ActConsent {
    var defaults: UserDefaults = .standard

    var allowed: Bool { defaults.object(forKey: Hand.allowedKey) as? Bool ?? true }
    /// The consent screen is never shown since 15 November (the user's word: no Allow to press). Acting is on
    /// unless the menu's switch is off.
    var asks: Bool { false }
}
