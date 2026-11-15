import AppKit
import QuartzCore

/// Phew's second cursor while he guides or acts: a clear panel over one display that every click goes straight
/// through. It holds a small pointer and a ring around the spot. Made for one guide or one job: once the pointer is
/// back at the menu bar it orders itself out and is let go. The look is docs/15-design.md 15.5 C: Phew's own colour,
/// a white outline and a dark shadow, so it shows on any content.
final class PointerOverlay: NSPanel {
    /// The ring around a screenshot point, which has no frame of its own.
    static let pointRadius: CGFloat = 22
    /// Room around the ring's line inside its layer, for the white edge and the shadow.
    private static let margin: CGFloat = 8

    private let pointer = CAShapeLayer()
    /// The ring: its accent line and the white edge outside it, with one shadow, framed to the spot.
    private let ring = CALayer()
    private let ringLine = CAShapeLayer()
    private let ringEdge = CAShapeLayer()
    /// Where the pointer's tip is, AppKit screen coordinates.
    private var tip: NSPoint
    /// Counts moves, so a travel that was overtaken (a new step mid-way) does not show its ring late.
    private var moves = 0

    init(on screen: NSScreen) {
        tip = Self.home(on: screen)
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        ignoresMouseEvents = true  // clicks pass through to the app below
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver  // above the app, its full screen, the card and the menu bar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let view = NSView()
        view.wantsLayer = true
        contentView = view
        let accent = Design.Ink.onScreen.cgColor
        ringLine.fillColor = nil
        ringLine.strokeColor = accent
        ringLine.lineWidth = 3
        ringEdge.fillColor = nil
        ringEdge.strokeColor = NSColor.white.withAlphaComponent(0.8).cgColor
        ringEdge.lineWidth = 1
        ring.addSublayer(ringEdge)
        ring.addSublayer(ringLine)
        ring.shadowColor = NSColor.black.cgColor  // contrast on a white page; no coloured glow
        ring.shadowOpacity = 0.35
        ring.shadowRadius = 3
        ring.shadowOffset = .zero
        ring.opacity = 0
        pointer.path = Self.arrow
        pointer.fillColor = accent
        pointer.strokeColor = NSColor.white.cgColor
        pointer.lineWidth = 1.5
        pointer.lineJoin = .round
        pointer.shadowOpacity = 0.3
        pointer.shadowRadius = 2
        pointer.shadowOffset = CGSize(width: 0, height: -1)
        view.layer?.addSublayer(ring)
        view.layer?.addSublayer(pointer)
        place()
    }

    /// Travels to `target` and rings it: an element's frame, or a zero-size rect that is a screenshot point. The tip
    /// rests on the ring's bottom right. Without a target it rests beside `card`, with no ring. AppKit coordinates.
    func point(at target: NSRect?, beside card: NSRect, arrived: @escaping () -> Void) {
        let goal = target.map { Self.spot(on: $0) } ?? NSPoint(x: card.maxX + 6, y: card.maxY - 6)  // or beside the card's top-right corner
        go(to: goal, ring: target, arrived: arrived)
    }

    /// Acting (15.5 C): the tip on the centre of `target`, the ring around it, then one press. The ring stays on the
    /// spot between actions: it is the acting mark on screen. An action never waits for motion: when the pointer is
    /// still travelling, it jumps.
    func act(on target: NSRect) {
        let goal = NSPoint(x: target.midX, y: target.midY)
        if pointer.animation(forKey: "travel") != nil {
            moves += 1
            pointer.removeAnimation(forKey: "travel")
            tip = onScreen(goal)
            place()
            showRing(around: target)
            return press()
        }
        go(to: goal, ring: target) { [weak self] in self?.press() }
    }

    /// The press of one action: the pointer 1 to 0.88 to 1, the ring fills with accent at 25%. With Reduce Motion,
    /// the ring's fill only.
    func press() {
        if !Design.Motion.reduce {
            let squeeze = CAKeyframeAnimation(keyPath: "transform.scale")
            squeeze.values = [1, 0.88, 1]
            squeeze.duration = Design.Motion.press
            squeeze.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            pointer.add(squeeze, forKey: "press")
        }
        let fill = Design.Ink.onScreen.withAlphaComponent(0.25).cgColor
        let fade = CABasicAnimation(keyPath: "fillColor")
        fade.fromValue = NSColor.clear.cgColor
        fade.toValue = fill
        fade.duration = Design.Motion.pressFill
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ringLine.fillColor = fill
        ringLine.add(fade, forKey: "press")
        CATransaction.commit()
    }

    /// Moves the pointer and its ring with the target at once, without travel: the content scrolled under them.
    func follow(_ target: NSRect) {
        moves += 1  // a travel still under way must not put the ring back at the old place
        pointer.removeAnimation(forKey: "travel")
        tip = onScreen(Self.spot(on: target))
        place()
        showRing(around: target)
    }

    /// The "looking" motion: the pointer breathes from its tip (`breathe`, scale to 1.12 and opacity to 0.4) while a
    /// look confirms the step a direct hit moved on to. With Reduce Motion, opacity only.
    func looking(_ on: Bool) {
        guard on else { return pointer.removeAnimation(forKey: "looking") }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0.4
        let grow = CABasicAnimation(keyPath: "transform.scale")
        grow.fromValue = 1
        grow.toValue = 1.12
        let breathe = CAAnimationGroup()
        breathe.animations = Design.Motion.reduce ? [fade] : [fade, grow]
        breathe.duration = Design.Motion.breatheHalf
        breathe.autoreverses = true
        breathe.repeatCount = .infinity
        breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pointer.add(breathe, forKey: "looking")
    }

    var isLooking: Bool { pointer.animation(forKey: "looking") != nil }

    /// Back to the menu bar, then off screen. The travel holds the overlay until it is over; then it is let go.
    func goHome() {
        looking(false)
        moves += 1
        hideRing()
        travel(to: screen.map(Self.home) ?? tip) { [self] in
            orderOut(nil)
            shellLog("pointer home, overlay ordered out")
        }
    }

    /// The ring: the frame with a little room, or a point's circle.
    static func ringRect(around target: NSRect) -> NSRect {
        target.isEmpty
            ? NSRect(x: target.midX - pointRadius, y: target.midY - pointRadius, width: pointRadius * 2, height: pointRadius * 2)
            : target.insetBy(dx: -4, dy: -4)
    }

    /// A point gets a circle, a frame softly rounded corners.
    private static func corner(for target: NSRect) -> CGFloat {
        target.isEmpty ? pointRadius : min(8, ringRect(around: target).height / 2)
    }

    /// Where the tip rests for `target` in a guide: on the ring, bottom right.
    private static func spot(on target: NSRect) -> NSPoint {
        let rect = ringRect(around: target), corner = corner(for: target)
        return NSPoint(x: rect.maxX - corner * 0.29, y: rect.minY + corner * 0.29)
    }

    /// The ring leaves (`leave`), the pointer travels, then the ring appears at the new spot (`appear`).
    private func go(to goal: NSPoint, ring target: NSRect?, arrived: @escaping () -> Void) {
        moves += 1
        let move = moves
        hideRing()
        // A target on another display: the overlay moves there and the pointer sets off from that menu bar.
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(goal) }), screen.frame != frame {
            setFrame(screen.frame, display: false)
            tip = Self.home(on: screen)
            pointer.removeAllAnimations()
            place()
        }
        orderFrontRegardless()
        travel(to: onScreen(goal)) { [weak self] in
            guard let self, moves == move else { return }
            if let target { showRing(around: target) }
            arrived()
        }
    }

    private func showRing(around target: NSRect) {
        let rect = local(Self.ringRect(around: target)), corner = Self.corner(for: target), m = Self.margin
        let inner = CGRect(x: m, y: m, width: rect.width, height: rect.height)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ring.removeAllAnimations()
        ring.frame = rect.insetBy(dx: -m, dy: -m)
        ringLine.removeAllAnimations()
        ringLine.fillColor = nil
        ringLine.path = CGPath(roundedRect: inner, cornerWidth: corner, cornerHeight: corner, transform: nil)
        // The white line sits just outside the accent one: half of 3, plus half of 1.
        ringEdge.path = CGPath(roundedRect: inner.insetBy(dx: -2, dy: -2), cornerWidth: corner + 2, cornerHeight: corner + 2, transform: nil)
        ring.opacity = 1
        CATransaction.commit()
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = Design.Motion.appearScale
        scale.toValue = 1
        let appear = CAAnimationGroup()
        appear.animations = Design.Motion.reduce ? [fade] : [fade, scale]
        appear.duration = Design.Motion.appear
        appear.timingFunction = CAMediaTimingFunction(name: .easeOut)
        ring.add(appear, forKey: "appear")
    }

    private func hideRing() {
        guard ring.opacity > 0 else { return }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = ring.presentation()?.opacity ?? 1
        fade.toValue = 0
        fade.duration = Design.Motion.leave
        fade.timingFunction = CAMediaTimingFunction(name: .easeIn)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ring.opacity = 0
        ring.add(fade, forKey: "appear")
        CATransaction.commit()
    }

    /// Keeps the whole arrow on screen when the target sits at an edge.
    private func onScreen(_ point: NSPoint) -> NSPoint {
        NSPoint(x: min(max(point.x, frame.minX), frame.maxX - 14), y: min(max(point.y, frame.minY + 22), frame.maxY))
    }

    /// The menu bar icon on `screen`, or the top right of that screen's menu bar when the icon is not there.
    static func home(on screen: NSScreen) -> NSPoint {
        // shortcut: SwiftUI's MenuBarExtra keeps its status item to itself, so the icon's window is found by class
        // name (public API, no private calls); own an NSStatusItem if that name changes. The fallback covers it.
        let icon = NSApp.windows.lazy.filter { $0.className == "NSStatusBarWindow" }.map(\.frame)
            .first { screen.frame.contains(NSPoint(x: $0.midX, y: $0.midY)) }
        if let icon { return NSPoint(x: icon.midX, y: icon.midY) }
        return NSPoint(x: screen.frame.maxX - 40, y: screen.frame.maxY - NSStatusBar.system.thickness / 2)
    }

    /// A plain arrow, tip at the origin, pointing up and left like the system cursor.
    private static let arrow: CGPath = {
        let path = CGMutablePath()
        path.addLines(between: [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: -17), CGPoint(x: 4, y: -13), CGPoint(x: 7, y: -20),
                                CGPoint(x: 10, y: -19), CGPoint(x: 7, y: -12), CGPoint(x: 12, y: -12)])
        path.closeSubpath()
        return path
    }()

    /// `travel`: a spring from where the pointer shows now (also mid-way) to `goal`. With Reduce Motion the pointer
    /// fades out where it is (`leave`) and in at the goal (`appear`). Explicit, not implicit: a layer that has not been
    /// drawn yet (the first step) does not animate implicitly.
    private func travel(to goal: NSPoint, then done: @escaping () -> Void) {
        let from = pointer.presentation()?.position ?? pointer.position
        tip = goal
        let to = local(tip)
        let animation: CAAnimation
        if Design.Motion.reduce {
            let total = Design.Motion.leave + Design.Motion.appear, half = NSNumber(value: Design.Motion.leave / total)
            let jump = CAKeyframeAnimation(keyPath: "position")
            jump.values = [from, to]
            jump.keyTimes = [0, half, 1]
            jump.calculationMode = .discrete
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [1, 0, 1]
            fade.keyTimes = [0, half, 1]
            let group = CAAnimationGroup()
            group.animations = [jump, fade]
            group.duration = total
            animation = group
        } else {
            let spring = Design.Motion.travel()
            spring.fromValue = from
            spring.toValue = to
            animation = spring
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock(done)
        pointer.position = to
        pointer.add(animation, forKey: "travel")
        CATransaction.commit()
    }

    /// The pointer at `tip` at once, without travel.
    private func place() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        pointer.position = local(tip)
        CATransaction.commit()
    }

    private func local(_ point: NSPoint) -> CGPoint { CGPoint(x: point.x - frame.minX, y: point.y - frame.minY) }
    private func local(_ rect: NSRect) -> CGRect { rect.offsetBy(dx: -frame.minX, dy: -frame.minY) }
}

extension CGRect {
    /// Between Accessibility's top-left origin and AppKit's bottom-left one (the same flip both ways). Both are
    /// measured from the main display, the one with the menu bar, so this holds on every display.
    func flipped(mainHeight: CGFloat) -> CGRect {
        CGRect(x: minX, y: mainHeight - maxY, width: width, height: height)
    }
}
