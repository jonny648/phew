import AppKit

/// The act route on the card (PH.5): Phew does the job in the front app, each action listed as a plain line as it
/// happens, then the summary or the plain reason he stopped. Stop is Escape, the close control or closing the card
/// (`dismiss`), and the user's own click or key anywhere (`Hand.begin`). The styled list, the mark and the Stop
/// footer come with PX.4. Split out of TextCard.swift; the stored state stays on `TextCard`.
extension TextCard {
    /// One fixed line above a guide given instead of acting, while acting is off (the seam for the consent screen).
    static let actingOff = "Acting is off, so here is how to do it."

    /// Runs the job in the app in front now. Returns when it ends; the Hand's watch goes with it.
    func act(_ request: String) async {
        guard let brain, let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier, pid != getpid() else { return }
        let job = Hand.shared.begin()
        handJob = job
        let start = Date()
        var count = 0
        shellLog("act: job \(job.number) started")
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        let run = ActJob(brain: brain, hand: .shared, pid: pid, capture: { await Senses.capture().value },
                         aside: { [weak self] rect in self?.moveAside(from: rect.flipped(mainHeight: mainHeight)) })
        let outcome = await run.run(request, job: job) { [weak self] line in
            count += 1
            guard let self, !Task.isCancelled else { return }
            model.apply(.text((model.text.isEmpty ? "" : "\n") + line))
        }
        Hand.shared.close(job)
        handJob = nil
        let kind = switch outcome { case .done: "done"; case .stuck: "stuck"; case .ended(let end): end.rawValue; case .failed(let error): "error \(error)" }
        shellLog("act: job \(job.number) ended \(kind), \(count) actions, \(Int(Date().timeIntervalSince(start) * 1000)) ms")
        guard !Task.isCancelled else { return }  // the card was closed: nothing more to show
        switch outcome {
        case .done(let line): model.apply(.text((model.text.isEmpty ? "" : "\n\n") + (line.isEmpty ? "Done." : line)))
        case .stuck(let line): model.problem = line.isEmpty ? "I could not go on, so I stopped." : line
        case .ended(let end): model.problem = ActJob.sentence(for: end)
        case .failed(let error): model.problem = Self.sentence(for: error)
        }
    }
}
