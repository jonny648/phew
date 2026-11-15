import AppKit

/// The guide on the card: the current step, the pointer at its target, and the end of the guide.
/// Split out of TextCard.swift; the stored state stays on `TextCard`.
extension TextCard {
    /// A click on a step line: the quiet fallback when following misses. The pointer goes to that step's last known
    /// place, or rests beside the card.
    func jump(to step: Int) {
        guard targets.indices.contains(step), step != model.current else { return }
        model.current = step
        pointAtCurrentStep()
    }

    func startGuide(_ steps: [GuideStep], targets: [CGRect?]) {
        self.steps = steps
        self.targets = targets
        model.current = 0
        let screen = NSScreen.screens.first { $0.frame.contains(frame.origin) } ?? NSScreen.screens[0]
        overlay = PointerOverlay(on: screen)
        // Observe only: the event still reaches the app, and Phew never makes one.
        actionMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp, .keyUp, .scrollWheel]) { [weak self] _ in
            self?.userActed()
        }
        shellLog("guide started: \(targets.count) steps, \(targets.compactMap { $0 }.count) with a target, following \(actionMonitor != nil)")
        pointAtCurrentStep()
    }

    func pointAtCurrentStep() {
        let step = model.current, count = targets.count, target = targets[step]
        moveAside(from: target)  // 3.10: the card never covers the spot it marks
        overlay?.point(at: target, beside: frame) {
            shellLog("guide: pointer arrived, step \(step + 1) of \(count), \(target == nil ? "beside the card" : target!.isEmpty ? "point ring" : "element ring")")
        }
    }

    /// Where a target points, AppKit screen coordinates, measured in the packet it was named in.
    static func rect(for target: StepTarget?, in packet: ContextPacket?) -> CGRect? {
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        return target.flatMap { packet?.screenRect(for: $0) }?.flipped(mainHeight: mainHeight)
    }

    /// Following stops, the pointer goes home and the overlay lets go; the steps and rects are dropped.
    func endGuide() {
        stopFollowing()
        rule = FollowRule()
        steps = []
        targets = []
        guard let overlay else { return }
        overlay.goHome()
        self.overlay = nil
        shellLog("guide ended")
    }
}
