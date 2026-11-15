import AppKit
import SwiftUI

/// The act route on the card (PH.5, look in docs/15-design.md 15.5 B and C): Phew does the job in the front app.
/// Each action is a row on the card as it happens, ticked when it lands; the pointer presses on the spot and the ring
/// stays there; the footer holds Stop. Then the summary, or the plain reason he stopped. Stop is the footer's button,
/// Escape or closing the card (`dismiss`), and the user's own click or key anywhere (`Hand.begin`).
/// The first time, the consent screen asks first (PH.3). Split out of TextCard.swift; the stored state stays on `TextCard`.
extension TextCard {
    /// One fixed line above a guide given instead of acting, while acting is off.
    static let actingOff = "Acting is off, so here is how to do it."

    #if DEBUG
    /// PH.10: set only by `--debug-act`. The app of the test's own made-up window, and every look of the job, already
    /// checked to be that window; nil when it is not, so nothing is sent.
    static var testWindow: (pid: pid_t, look: () async -> ContextPacket?)?
    #endif

    /// Runs the job in `app`, the app the user asked in. Returns when it ends; the Hand's watch goes with it.
    /// If another app has come to the front meanwhile, it stops before any look, so no other app's screen is read.
    func act(_ request: String, in app: NSRunningApplication?) async {
        var app = app
        // Each look reads the app the job works in, never whatever came to the front meanwhile (the Hand stops then).
        var look: (() async -> ContextPacket?)?
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
        let pid = app.processIdentifier
        let capture = look ?? { await Senses.capture(app: app).value }
        let job = Hand.shared.begin(watchUser: watchUser)
        handJob = job
        model.startActing(in: app.localizedName ?? "")
        let start = Date()
        var count = 0
        shellLog("act: job \(job.number) started")
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        let screen = NSScreen.screens.first { $0.frame.contains(frame.origin) } ?? NSScreen.screens[0]
        let pointer = PointerOverlay(on: screen)
        overlay = pointer
        var run = ActJob(brain: brain, hand: .shared, pid: pid, capture: capture,
                         aside: { [weak self] rect in
                             let spot = rect.flipped(mainHeight: mainHeight)
                             self?.moveAside(from: spot)
                             pointer.act(on: spot)
                         })
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

    /// The consent screen (15.5 F, text of docs/13-hand.md 13.8), and the user's choice: true for Allow, which turns
    /// acting on. Escape (the card closes), the close button and Not now mean Not now: nothing is written, so the
    /// screen comes back next time. Non-activating: the front app keeps the keyboard; neither button answers Return.
    func askConsent() async -> Bool {
        await withCheckedContinuation { continuation in
            var observer: Any?
            let choose: (Bool) -> Void = { [weak self] allow in
                guard let self, consentChoice != nil else { return }
                consentChoice = nil
                observer.map(NotificationCenter.default.removeObserver)
                if allow { consent.answer(true) }
                shellLog("consent: \(allow ? "allow" : "not now"), phew front \(phewIsFront)")
                consentPanel.fadeOut()
                continuation.resume(returning: allow)
            }
            consentChoice = choose
            consentPanel.show(title: "", ConsentView(onAllow: { choose(true) }, onNotNow: { choose(false) }))
            observer = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: consentPanel.panel,
                                                              queue: .main) { _ in MainActor.assumeIsolated { choose(false) } }
            shellLog("consent: shown, key \(consentPanel.panel?.isKeyWindow ?? false), phew front \(phewIsFront)")
        }
    }
}

/// The "Let Phew act" switch (PH.3), `Hand.allowedKey` in the defaults. Off when never set. Allow on the consent
/// screen turns it on; Not now writes nothing, so the screen comes back. Once set, true or false, the screen is not
/// shown again: the menu's switch is the way back on.
struct ActConsent {
    var defaults: UserDefaults = .standard

    var allowed: Bool { defaults.object(forKey: Hand.allowedKey) as? Bool ?? true }
    /// The consent screen is never shown since 15 November (the user's word: no Allow to press). Acting is on
    /// unless the menu's switch is off.
    var asks: Bool { false }

    func answer(_ allow: Bool) { if allow { defaults.set(true, forKey: Hand.allowedKey) } }
}

/// One shape for the consent screens, 440 wide (15.5 F). The acting text exactly as approved in docs/13-hand.md 13.8.
struct ConsentView: View {
    let onAllow: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Space.s12) {
            Text("Phew can do things for you.")
                .font(Design.Text.title)
                .padding(.bottom, Design.Space.s4)
            Text("When you ask, he clicks, types and picks menus in your apps by himself, and lists what he did. He never types passwords, pays, or changes system settings. Stop always works.")
            Text("Text on a web page or in a document can mislead him. He may then do a wrong thing, including sending or deleting.")
            HStack(spacing: Design.Space.s8) {
                Spacer()
                Button("Not now", action: onNotNow).buttonStyle(QuietButton())
                Button("Allow", action: onAllow).buttonStyle(MainButton())
            }
            .padding(.top, Design.Space.s12)
        }
        .font(Design.Text.body)
        .lineSpacing(Design.Text.bodySpacing)
        .foregroundStyle(Design.Ink.primary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(Design.Space.s24)
        .frame(width: Design.Size.consentWidth)
        .background(Color(nsColor: .windowBackgroundColor))  // `panel`
    }
}
