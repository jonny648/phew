#if DEBUG
import AppKit

/// Self-checks for the checker, who cannot press keys or click. Each runs only with its launch flag.
extension AppDelegate {
    func runDebugChecks() {
        let arguments = CommandLine.arguments
        if arguments.contains("--debug-open-panel") { Task { await checkPanel() } }
        // Senses: captures the front app, with a screenshot, into the debug files.
        // An optional bundle id after the flag reads that running app instead, without bringing it forward.
        if let flag = arguments.firstIndex(of: "--debug-capture") {
            let target = arguments.dropFirst(flag + 1).first
                .flatMap { NSRunningApplication.runningApplications(withBundleIdentifier: $0).first }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { _ = Senses.capture(app: target) }
        }
        if arguments.contains("--debug-brain-check") { BrainSelfCheck.run() }  // real API calls, made-up data
        if arguments.contains("--debug-card") { Task { await checkCard() } }
        if arguments.contains("--debug-guide") { Task { await checkGuide() } }
    }

    /// Opens the panel twice (the second open is the usual case in real use), then closes it as Escape does.
    private func checkPanel() async {
        try? await Task.sleep(for: .seconds(1))
        NSApp.deactivate()  // real use: another app is active when the shortcut fires
        shellLog("self-check before open: appActive=\(NSRunningApplication.current.isActive) phewFront=\(phewIsFront) windows=\(NSApp.windows.map(\.className))")
        for _ in 0..<2 {
            panel.open { question in shellLog("self-check: panel closed, question \(question == nil ? "none" : "given")") }
            try? await Task.sleep(for: .seconds(1))
            let responder = panel.firstResponder.map { String(describing: type(of: $0)) } ?? "none"
            // The edit actions the panel sends for Command+A, C, V, X reach the field through the responder chain.
            let editor = panel.firstResponder as? NSTextView
            editor?.insertText("check", replacementRange: NSRange(location: NSNotFound, length: 0))
            let routed = NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: panel)
            shellLog("self-check: key=\(panel.isKeyWindow) appActive=\(NSRunningApplication.current.isActive) phewFront=\(phewIsFront) firstResponder=\(responder) selectAll routed=\(routed) selected=\(editor?.selectedRange().length ?? -1) of \(editor?.string.count ?? -1)")
            NSApp.sendAction(#selector(NSResponder.cancelOperation(_:)), to: nil, from: nil)
            try? await Task.sleep(for: .seconds(1))
        }
    }

    /// Plays a fake Brain through the real ask path: an answer with steps, an error sentence, and a missing key
    /// (the card closes and the key window opens). Closes everything at the end.
    private func checkCard() async {
        try? await Task.sleep(for: .seconds(1))
        NSApp.deactivate()
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let realBrain = brain
        for failure in [nil, BrainError.overloaded, .noKey] {
            let name = failure.map { "\($0)" } ?? "answer"
            brain = FakeBrain(failure: failure)
            capture = Task<ContextPacket?, Never> { nil }
            anchor = NSEvent.mouseLocation
            ask("")
            shellLog("card check \(name): appeared=\(card.isVisible) key=\(card.isKeyWindow) thinking=\(card.model.thinking)")
            try? await Task.sleep(for: .seconds(2))
            let frontUnchanged = NSWorkspace.shared.frontmostApplication?.processIdentifier == front
            shellLog("card check \(name): visible=\(card.isVisible) pieces=\(card.model.pieces) steps=\(card.model.steps.count) thinking=\(card.model.thinking) problem=\(card.model.problem ?? "none") keyWindow=\(keyWindow.isShown) frontUnchanged=\(frontUnchanged) phewFront=\(phewIsFront) \(cardFrames)")
            card.dismiss()
            keyWindow.dismiss()
        }
        brain = realBrain
        let frontUnchanged = NSWorkspace.shared.frontmostApplication?.processIdentifier == front
        shellLog("card check done: card visible=\(card.isVisible) keyWindow=\(keyWindow.isShown) frontUnchanged=\(frontUnchanged)")
    }

    /// Plays a made-up four-step guide through the real card and overlay: a made-up element, a screenshot point,
    /// a step without a target, the element again. First it follows: it calls `userActed`, the action monitor's own
    /// entry point (no event is made), and each look captures whatever app is front and asks the fake Brain, which
    /// moves one step per look, until the last look finds every step done. Then it starts again, picks a step line
    /// and closes the card with a look waiting, as Escape, the close control and the shortcut do. Last, a look that
    /// fails: overloaded keeps the guide without following, no key closes it and opens the key window. No model calls.
    /// The action monitor is real: the user's own clicks, keys and scrolls during the check also make looks.
    private func checkGuide() async {
        try? await Task.sleep(for: .seconds(1))
        NSApp.deactivate()
        let realBrain = brain
        let main = NSScreen.screens[0].frame
        let display = CGDisplayBounds(CGMainDisplayID())  // top-left origin, as Senses measures
        var packet = ContextPacket(appName: "Made Up", bundleID: "com.example.madeup", windowTitle: "Made up",
                                   visibleText: "", cursor: nil)
        packet.pointables = [Pointable(id: "e1", role: "AXButton", label: "Made up",
                                       frame: CGRect(x: display.midX - 160, y: display.midY - 60, width: 120, height: 28))]
        packet.screenshotFrame = display
        let targets: [StepTarget?] = [.element("e1"), .point(x: Int(display.width / 2) + 60, y: Int(display.height / 2) + 40), nil, .element("e1")]
        for (ending, failure) in [("follow", nil), ("cancel", nil), ("overloaded", BrainError.overloaded), ("noKey", .noKey)] {
            brain = FakeBrain(targets: targets, lookFailure: failure)
            capture = Task<ContextPacket?, Never> { packet }
            anchor = NSPoint(x: main.midX - 600, y: main.midY + 160)  // a made-up cursor, left of the targets
            ask("")
            try? await Task.sleep(for: .seconds(2))  // the fake answer streams, then step 1 starts
            weak let overlay = card.overlay
            shellLog("guide check \(ending): menu bar icon found=\(NSApp.windows.contains { $0.className == "NSStatusBarWindow" }) following=\(card.actionMonitor != nil)")
            try? await Task.sleep(for: .seconds(3))  // step 1's glide and ring
            func state(_ moment: String) {
                shellLog("guide check \(ending) \(moment): step=\(card.model.current + 1) looks=\(card.rule.looks) lookPending=\(card.lookPending) overlay ignoresMouse=\(overlay?.ignoresMouseEvents ?? false) visible=\(overlay?.isVisible ?? false) key=\(overlay?.isKeyWindow ?? false) canBecomeKey=\(overlay?.canBecomeKey ?? true) cardKey=\(card.isKeyWindow) phewFront=\(phewIsFront) appActive=\(NSRunningApplication.current.isActive)")
            }
            state("step 1")
            if ending == "follow" {
                // Does Accessibility's hit test take the clear overlay for content? The card's centre is the control.
                shellLog("guide check follow: hit test lands on Phew, inside the card=\(Self.hitIsPhew(NSPoint(x: card.frame.midX, y: card.frame.midY))) on the overlay away from the card=\(Self.hitIsPhew(NSPoint(x: main.midX + 300, y: main.midY - 200)))")
                try? await Task.sleep(for: .seconds(3))
                state("after 3 s without an action")
                card.userActed()
                await until { !self.card.lookPending }
                state("after one action")
                card.userActed()
                await until { self.card.rule.inFlight }
                card.userActed(); card.userActed()  // two more while that look runs
                shellLog("guide check follow: two actions during look \(card.rule.looks), in flight=\(card.rule.inFlight)")
                await until { !self.card.lookPending }
                try? await Task.sleep(for: .seconds(3))  // room for any extra look
                state("after an action and two during its look, then 3 s")
                card.userActed()  // the last look finds every step done
                await until { !self.card.lookPending }
            } else if failure != nil {
                card.userActed()
                await until { !self.card.lookPending }
                state("after a look that failed")
                card.jump(to: 1)  // step lines still work
                shellLog("guide check \(ending): card visible=\(card.isVisible) following=\(card.actionMonitor != nil) step after picking line 2=\(card.model.current + 1) keyWindow=\(keyWindow.isShown)")
                card.dismiss()
                keyWindow.dismiss()
            } else {
                card.jump(to: 2)  // what a click on step line 3 calls
                card.userActed()
                try? await Task.sleep(for: .seconds(1))  // the glide, with a look still waiting
                state("after picking step line 3 and an action")
                card.dismiss()  // what Escape, the close control and the shortcut call
            }
            try? await Task.sleep(for: .seconds(1))  // the glide home
            card.userActed()  // after the end nothing may follow
            let left = NSApp.windows.filter { $0 is PointerOverlay }.count
            shellLog("guide check \(ending) end: card visible=\(card.isVisible) overlay released=\(overlay == nil) overlay windows left=\(left) phewFront=\(phewIsFront) cardKey=\(card.isKeyWindow) monitor removed=\(card.actionMonitor == nil) lookPending=\(card.lookPending) looks=\(card.rule.looks)")
        }
        brain = realBrain
    }

    /// Polls `done` every 50 ms, for at most 10 s.
    private func until(_ done: () -> Bool) async {
        for _ in 0..<200 where !done() { try? await Task.sleep(for: .milliseconds(50)) }
    }

    /// Whether Accessibility's hit test at `point` (AppKit coordinates) lands on one of Phew's windows. Reads only
    /// the owner's process id.
    private static func hitIsPhew(_ point: NSPoint) -> String {
        var hit: AXUIElement?
        let y = (NSScreen.screens.first?.frame.height ?? 0) - point.y
        guard AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(point.x), Float(y), &hit) == .success,
              let hit else { return "no element" }
        var owner: pid_t = 0
        AXUIElementGetPid(hit, &owner)
        return "\(owner == getpid())"
    }

    /// The card's frame as the window server has it (top-left origin), and whether it lies inside the screen.
    private var cardFrames: String {
        let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
        guard card.isVisible,
              let info = windows.first(where: { $0[kCGWindowNumber as String] as? Int == card.windowNumber }),
              let bounds = info[kCGWindowBounds as String] as? NSDictionary,
              let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return "windowServer=none" }
        var ids = [CGDirectDisplayID](repeating: 0, count: 16), count: UInt32 = 0
        CGGetActiveDisplayList(16, &ids, &count)
        let inDisplay = ids.prefix(Int(count)).contains { CGDisplayBounds($0).contains(rect) }
        let inVisibleFrame = NSScreen.screens.contains { $0.visibleFrame.contains(card.frame) }
        return "windowServer=\(rect) insideDisplay=\(inDisplay) insideVisibleFrame=\(inVisibleFrame)"
    }
}

/// A stand-in Brain for the card and guide checks: a guide answer in pieces with three steps (pointing at
/// `targets`), or `failure` after two pieces.
struct FakeBrain: Brain {
    var failure: BrainError?
    var targets: [StepTarget?] = [nil, nil, nil]
    /// Thrown by `progress`, as a look that fails.
    var lookFailure: BrainError?

    func answer(_ question: String, packet: ContextPacket?) -> AsyncThrowingStream<BrainEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                let pieces = ["This is a fake answer ", "from the card check. ", "It arrives ", "in small pieces, ",
                              "like a real one, ", "then three steps follow."]
                continuation.yield(.route(.guide))
                for piece in pieces.prefix(failure == nil ? pieces.count : 2) {
                    try? await Task.sleep(for: .milliseconds(200))
                    continuation.yield(.text(piece))
                }
                if let failure { return continuation.finish(throwing: failure) }
                continuation.yield(.steps(targets.enumerated().map { GuideStep(instruction: "Fake step \($0.offset + 1).", target: $0.element) }))
                continuation.yield(.done)
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// One step further per call, pointing where that step pointed, after half a second, as a short model call.
    func progress(steps: [GuideStep], current: Int, packet: ContextPacket?) async throws -> GuideProgress {
        try await Task.sleep(for: .milliseconds(500))
        if let lookFailure { throw lookFailure }
        let next = min(max(current + 1, 0), steps.count)
        return GuideProgress(current: next, target: next < steps.count ? steps[next].target : nil)
    }
}
#endif
