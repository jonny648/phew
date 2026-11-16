import AppKit

/// Scroll events during a guide (R52): at most one frame read in flight; scrolls meanwhile make one more read when it
/// ends, so the last place is always read. A trackpad's tens of events a second become at most one read per `gap`.
struct ScrollReads {
    static let gap: Duration = .milliseconds(66)
    private var reading = false, again = false

    /// A scroll: true when a read starts now.
    mutating func scrolled() -> Bool {
        if reading { again = true; return false }
        reading = true
        return true
    }

    /// A read ended (and its gap passed): true when one more starts.
    mutating func ended() -> Bool {
        if again { again = false; return true }
        reading = false
        return false
    }
}

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
            rule.pressed(at: NSEvent.mouseLocation)
        case .leftMouseUp:
            directHit()
            userActed()
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

    /// A release on the current step's target (PS.3). On a step that needs only a click, and not the last, the card
    /// moves on at once and the pointer shows it is looking; the look that follows confirms it or steps back.
    /// Internal for the debug check, which cannot click.
    func directHit(at point: NSPoint = NSEvent.mouseLocation) {
        let step = model.current
        guard steps.indices.contains(step), targets.indices.contains(step),
              rule.released(at: point, step: step, count: steps.count, click: steps[step].click, target: targets[step]) else { return }
        model.current = step + 1
        shellLog("guide: direct hit on step \(step + 1) of \(steps.count), on to step \(step + 2) before the look")
        pointAtCurrentStep()
        overlay?.looking(true)
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

    /// Scroll events, gated so a read runs at most once at a time (R52).
    static var scrolls = ScrollReads()

    /// The content scrolled: the pointer moves with its target, read again from the anchored element. No look.
    /// One read at a time, off the main thread, at most one per `ScrollReads.gap`; the last scroll is always read.
    private func followScroll() {
        guard Self.scrolls.scrolled() else { return }
        Task { [weak self] in
            repeat {
                await self?.readScroll()
                try? await Task.sleep(for: ScrollReads.gap)
            } while Self.scrolls.ended()
        }
    }

    private func readScroll() async {
        guard let anchor = Self.anchor, anchor.step == model.current, targets.indices.contains(anchor.step) else { return }
        let element = anchor.element
        // The other app answers off Phew's main thread, so a slow one never holds up Stop, Escape or the pointer.
        guard let now = await Task.detached(operation: { WindowReader.frame(of: element) }).value,
              let still = Self.anchor, still.step == anchor.step, still.element == element, targets.indices.contains(still.step) else { return }
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
        // After a direct hit the look judges from the step the hit left, so it can confirm it or step back.
        let shown = model.current, from = rule.lookFrom(shown), steps = steps, look = rule.looks
        shellLog("guide: look \(look) of \(FollowRule.ceiling) starts on step \(from + 1) of \(steps.count)\(from != shown ? ", confirming a direct hit" : "")\(since.map { ", \($0) ms after the last start" } ?? "")")
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
            apply(result, shown: shown, packet: packet)
            guard actionMonitor != nil else { return }  // the guide is done, or stopped
            if let wait = rule.lookEnded(at: Date()) {
                schedule(after: wait)
            } else if rule.exhausted {
                stopFollowing()
                shellLog("guide: \(FollowRule.ceiling) looks reached, following stopped")
            }
        }
    }

    /// Moves the guide to what the look saw: on, or back to a step a direct hit left undone. Never moves the card.
    private func apply(_ result: GuideProgress, shown: Int, packet: ContextPacket?) {
        let outcome = rule.judged(result, shown: shown, now: model.current, count: targets.count)
        guard outcome != .drop else { return shellLog("guide: look result dropped, the step changed during the look") }
        overlay?.looking(false)
        let rect = Self.rect(for: result.target, in: packet)
        switch outcome {
        case .drop: return
        case .done: return guideDone()  // every step done: pointer home; an open thread stays
        case .stay:
            // No target: the check failed or nothing fits, so the pointer stays where it is.
            guard let rect, rect != targets[shown] else { return }
            targets[shown] = rect
        case .move(let step):
            if step < shown { shellLog("guide: the look found step \(step + 1) not done, back to it") }
            // Back to a step, its last known place stays when the look names none.
            targets[step] = rect ?? (step < shown ? targets[step] : nil)
            model.current = step
        }
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
        overlay?.looking(false)
        ScreenWatch.shared.stop("following stopped")  // its frames go with it
    }
}
