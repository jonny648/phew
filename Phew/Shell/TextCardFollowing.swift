import AppKit

/// Following: after the student acts, a calm wait, then a look (capture and Brain check) that moves the guide on.
/// Split out of TextCard.swift; the stored state stays on `TextCard`.
extension TextCard {
    /// The current step's target, tied to the element of the front app under its centre when the pointer went there,
    /// so a scroll moves the pointer with it. Frames only. Nil without a target or such an element.
    /// Static: an extension cannot add stored properties, and there is one card.
    static var anchor: (step: Int, rect: CGRect, element: AXUIElement, frame: CGRect)?

    /// When the guide's steps are shown: the action monitor, and the screen watch (docs/04-architecture.md 4.6).
    func startFollowing() {
        // Observe only: the event still reaches the app, and Phew never makes one.
        actionMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp, .keyUp, .scrollWheel]) { [weak self] event in
            self?.observe(event)
        }
        if actionMonitor != nil { ScreenWatch.shared.start(markFirst: true) }
    }

    /// A press may start a drag, and a scroll only moves the content: neither makes a look. A release or a key does.
    /// Both still count as actions for the watch's two minutes.
    private func observe(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            ScreenWatch.shared.acted()
        case .scrollWheel:
            ScreenWatch.shared.acted()
            rule.scrolled(at: Date())
            followScroll()
        default:
            userActed()
        }
    }

    /// The student clicked or typed in another app (the action monitor), or the debug check says so.
    /// After a calm moment Phew looks again. Events in Phew's own windows never reach a global monitor, so a click
    /// on the card is not an action.
    func userActed() {
        guard actionMonitor != nil else { return }
        ScreenWatch.shared.acted()
        guard let wait = rule.userActed(at: Date()) else { return }
        schedule(after: wait)
    }

    /// Ties the current step's target to the element under its centre. Called whenever the pointer goes to a step.
    func anchorTarget() {
        Self.anchor = nil
        guard targets.indices.contains(model.current), let rect = targets[model.current],
              let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier, pid != getpid() else { return }
        let centre = CGPoint(x: rect.midX, y: (NSScreen.screens.first?.frame.height ?? 0) - rect.midY)
        guard let element = WindowReader.element(at: centre, pid: pid), let frame = WindowReader.frame(of: element) else { return }
        Self.anchor = (model.current, rect, element, frame)
    }

    /// The content scrolled: the pointer moves with its target, read again from the anchored element. No look.
    // shortcut: one frame read per scroll event, on the main thread (at most 0.1 s on a hung app); throttle if it stutters.
    private func followScroll() {
        guard let anchor = Self.anchor, anchor.step == model.current, targets.indices.contains(anchor.step),
              let now = WindowReader.frame(of: anchor.element) else { return }
        let rect = FollowRule.moved(anchor.rect, anchorWas: anchor.frame, anchorNow: now)
        guard rect != targets[anchor.step] else { return }
        targets[anchor.step] = rect
        overlay?.follow(rect)
    }

    private func schedule(after wait: TimeInterval) {
        waitTask?.cancel()
        waitTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else { return }
            self?.look()
        }
    }

    /// Captures the front app (never Phew: it is never front), asks the Brain which step the student is on, applies
    /// the answer. The packet is dropped when this ends; only the resolved rect stays.
    private func look() {
        waitTask = nil
        guard let brain, !phewIsFront else { return shellLog("guide: look skipped, phew front \(phewIsFront)") }
        let watch = ScreenWatch.shared, now = Date()
        // No look during a drag or a scroll, nor while the screen still changes.
        switch rule.hold(at: now, pressing: NSEvent.pressedMouseButtons & 1 != 0, settled: watch.settled(at: now)) {
        case .drop: return shellLog("guide: look held, a button is down")
        case .wait(let wait): return schedule(after: wait)
        case .go: break
        }
        if !watch.changed(), rule.skip() { return shellLog("guide: look skipped, the screen did not change") }
        let since = rule.looks > 0 ? Int(now.timeIntervalSince(rule.lastStart) * 1000) : nil
        guard rule.startLook(at: now) else { return }
        watch.mark()
        let from = model.current, steps = steps, look = rule.looks
        shellLog("guide: look \(look) of \(FollowRule.ceiling) starts on step \(from + 1) of \(steps.count)\(since.map { ", \($0) ms after the last start" } ?? "")")
        let capture = Senses.capture()
        lookTask = Task { [weak self] in
            let packet = await capture.value
            let captureMS = Int(Date().timeIntervalSince(now) * 1000)
            guard !Task.isCancelled, let self else { return }
            let result: GuideProgress
            do {
                result = try await brain.progress(steps: steps, current: from, packet: packet)
            } catch {
                guard !Task.isCancelled else { return }
                return lookFailed(BrainError(error))
            }
            guard !Task.isCancelled else { return }
            lookTask = nil
            let kind = switch result.target { case .element: "element"; case .point: "point"; case nil: "none" }
            shellLog("guide: look \(look) ended, step \(from + 1) to \(result.current + 1) of \(steps.count), target \(kind), capture \(captureMS) ms, total \(Int(Date().timeIntervalSince(now) * 1000)) ms")
            apply(result, from: from, packet: packet)
            guard actionMonitor != nil else { return }  // the guide is done, or stopped
            if let wait = rule.lookEnded(at: Date()) {
                schedule(after: wait)
            } else if rule.exhausted {
                stopFollowing()
                shellLog("guide: \(FollowRule.ceiling) looks reached, following stopped")
            }
        }
    }

    /// Moves the guide to what the look saw. Never moves the card.
    private func apply(_ result: GuideProgress, from: Int, packet: ContextPacket?) {
        // The student picked a step on the card during the look: their choice wins.
        guard model.current == from else { return shellLog("guide: look result dropped, a step was picked on the card") }
        let now = min(max(result.current, 0), targets.count)
        guard now < targets.count else { return guideDone() }  // every step done: pointer home; an open thread stays
        let rect = Self.rect(for: result.target, in: packet)
        if now == from {
            // No target: the check failed or nothing fits, so the pointer stays where it is.
            guard let rect, rect != targets[now] else { return }
        } else {
            model.current = now
        }
        targets[now] = rect
        pointAtCurrentStep()
    }

    /// `.noKey` and `.badKey` close the card and ask for the key, as an answer does; anything else only stops
    /// following, and the guide stays with its step lines.
    private func lookFailed(_ error: BrainError) {
        lookTask = nil
        shellLog("guide: look failed, error \(error), following stopped")
        guard error == .noKey || error == .badKey else { return stopFollowing() }
        dismiss()
        onKeyProblem?(error)
    }

    /// The monitor and the screen watch go; no look waits or runs. The card and the pointer stay.
    func stopFollowing() {
        actionMonitor.map(NSEvent.removeMonitor)
        actionMonitor = nil
        waitTask?.cancel()
        waitTask = nil
        lookTask?.cancel()  // the Brain then cancels its request; the packet goes with the task
        lookTask = nil
        Self.anchor = nil
        ScreenWatch.shared.stop("following stopped")  // its frames go with it
    }
}
