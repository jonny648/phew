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

    /// Plays a made-up three-step guide through the real card and overlay: a made-up element, a screenshot point,
    /// a step without a target. First it advances with the Next button's own call and goes past the last step;
    /// then it starts again and closes the card at step 1, as Escape and the close control do. No model calls.
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
        brain = FakeBrain(targets: [.element("e1"), .point(x: Int(display.width / 2) + 60, y: Int(display.height / 2) + 40), nil])
        for ending in ["finish", "cancel"] {
            capture = Task<ContextPacket?, Never> { packet }
            anchor = NSPoint(x: main.midX - 600, y: main.midY + 160)  // a made-up cursor, left of the targets
            ask("")
            try? await Task.sleep(for: .seconds(2))  // the fake answer streams, then step 1 starts
            weak let overlay = card.overlay
            shellLog("guide check \(ending): menu bar icon found=\(NSApp.windows.contains { $0.className == "NSStatusBarWindow" })")
            for step in 1...3 {
                try? await Task.sleep(for: .seconds(step == 1 ? 3 : 1))
                shellLog("guide check \(ending) step \(step): current=\(card.model.current + 1) overlay ignoresMouse=\(overlay?.ignoresMouseEvents ?? false) visible=\(overlay?.isVisible ?? false) key=\(overlay?.isKeyWindow ?? false) canBecomeKey=\(overlay?.canBecomeKey ?? true) cardKey=\(card.isKeyWindow) phewFront=\(phewIsFront) appActive=\(NSRunningApplication.current.isActive)")
                if ending == "cancel" { card.dismiss(); break }  // what Escape, the close control and the shortcut call
                card.next()  // what the Next (and Done) button calls
            }
            try? await Task.sleep(for: .seconds(1))  // the glide home
            let left = NSApp.windows.filter { $0 is PointerOverlay }.count
            shellLog("guide check \(ending) end: card visible=\(card.isVisible) overlay released=\(overlay == nil) overlay windows left=\(left) phewFront=\(phewIsFront) cardKey=\(card.isKeyWindow)")
        }
        brain = realBrain
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
}
#endif
