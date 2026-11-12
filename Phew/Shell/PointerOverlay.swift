import AppKit
import QuartzCore

/// Phew's second cursor while he guides: a clear panel over one display that every click goes straight through.
/// It holds a small pointer and a soft ring around the current step's target. Made for one guide: once the
/// pointer is back at the menu bar it orders itself out and is let go.
final class PointerOverlay: NSPanel {
    /// Seconds for one glide: gentle and short.
    static let glide = 0.4
    /// The ring around a screenshot point, which has no frame of its own.
    static let pointRadius: CGFloat = 22

    private let pointer = CAShapeLayer()
    private let ring = CAShapeLayer()
    /// Where the pointer's tip is, AppKit screen coordinates.
    private var tip: NSPoint
    /// Counts moves, so a glide that was overtaken (a new step mid-way) does not show its ring late.
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
        let accent = NSColor.controlAccentColor.cgColor
        ring.fillColor = nil
        ring.strokeColor = accent
        ring.lineWidth = 3
        ring.shadowColor = accent  // the soft edge
        ring.shadowRadius = 6
        ring.shadowOpacity = 0.7
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

    /// Glides to `target` and rings it: an element's frame, or a zero-size rect that is a screenshot point.
    /// Without a target it rests beside `card`, with no ring. AppKit screen coordinates.
    func point(at target: NSRect?, beside card: NSRect, arrived: @escaping () -> Void) {
        moves += 1
        let move = moves
        fadeRing(in: false)
        var from = pointer.presentation()?.position  // where it shows now, also mid-glide
        var goal = NSPoint(x: card.maxX + 6, y: card.maxY - 6)  // beside the card's top-right corner
        var corner: CGFloat = 0
        if let target {
            let rect = Self.ringRect(around: target)
            corner = target.isEmpty ? Self.pointRadius : min(8, rect.height / 2)  // a point gets a circle
            goal = NSPoint(x: rect.maxX - corner * 0.29, y: rect.minY + corner * 0.29)  // on the ring, bottom right
        }
        // A target on another display: the overlay moves there and the pointer sets off from that menu bar.
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(goal) }), screen.frame != frame {
            setFrame(screen.frame, display: false)
            tip = Self.home(on: screen)
            place()
            from = nil
        }
        orderFrontRegardless()
        // Keep the whole arrow on screen when the target sits at an edge.
        goal.x = min(max(goal.x, frame.minX), frame.maxX - 14)
        goal.y = min(max(goal.y, frame.minY + 22), frame.maxY)
        let ringPath = target.map {
            CGPath(roundedRect: local(Self.ringRect(around: $0)), cornerWidth: corner, cornerHeight: corner, transform: nil)
        }
        glide(from: from, to: goal) { [weak self] in
            guard let self, moves == move else { return }
            if let ringPath {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                ring.path = ringPath
                CATransaction.commit()
                fadeRing(in: true)
            }
            arrived()
        }
    }

    /// Back to the menu bar, then off screen. The glide holds the overlay until it is over; then it is let go.
    func goHome() {
        moves += 1
        fadeRing(in: false)
        glide(from: pointer.presentation()?.position, to: screen.map(Self.home) ?? tip) { [self] in
            orderOut(nil)
            shellLog("guide: pointer home, overlay ordered out")
        }
    }

    /// The ring: the frame with a little room, or a point's circle.
    static func ringRect(around target: NSRect) -> NSRect {
        target.isEmpty
            ? NSRect(x: target.midX - pointRadius, y: target.midY - pointRadius, width: pointRadius * 2, height: pointRadius * 2)
            : target.insetBy(dx: -4, dy: -4)
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

    /// Explicit, not implicit: a layer that has not been drawn yet (the first step) does not animate implicitly.
    private func glide(from: CGPoint?, to goal: NSPoint, then done: @escaping () -> Void) {
        let glide = CABasicAnimation(keyPath: "position")
        glide.fromValue = from ?? pointer.position
        glide.duration = Self.glide
        glide.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        tip = goal
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock(done)
        pointer.position = local(tip)
        if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { pointer.add(glide, forKey: "glide") }  // Reduce Motion: no glide
        CATransaction.commit()
    }

    private func fadeRing(in visible: Bool) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(visible ? 0.2 : 0.1)
        ring.opacity = visible ? 1 : 0
        CATransaction.commit()
    }

    /// The pointer at `tip` at once, without a glide.
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
