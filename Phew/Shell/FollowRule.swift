import Foundation

/// When a guide looks at the screen again to follow the student. Pure, so its limits are unit-tested.
/// Hard rule: a look happens only after the student acts. There is no timer that looks on its own.
struct FollowRule {
    /// Calm after the last action before a look: a click or a word is often one part of a longer gesture.
    static let quiet: TimeInterval = 1
    /// Least time between two look starts: each look is one main-model call, about 2 s and 0.25 cents.
    static let gap: TimeInterval = 1.5
    /// Looks per guide at most (about 10 cents). Then the guide stops following; its step lines still work.
    static let ceiling = 40
    /// No look until the scrolling has stopped this long. A scroll alone is not an action: it makes no look.
    static let scrollCalm: TimeInterval = 0.5
    /// A screen that keeps changing (a video, a spinner) holds a look at most this long after the calm.
    static let settleCap: TimeInterval = 2
    /// How often a held look asks again whether the screen has settled.
    static let settlePoll: TimeInterval = 0.1

    /// The student acted since the last look started.
    private(set) var acted = false
    private(set) var inFlight = false
    private(set) var looks = 0
    private var lastAction = Date.distantPast
    private(set) var lastStart = Date.distantPast
    private var lastScroll = Date.distantPast

    var exhausted: Bool { looks >= Self.ceiling }

    /// What a waiting look does now.
    enum Hold: Equatable {
        case go
        case wait(TimeInterval)
        /// A button is held, maybe a drag: its release is an action and schedules the look.
        case drop
    }

    /// A scroll moved the content. No look comes of it; a waiting look holds off until it stops.
    mutating func scrolled(at now: Date) { lastScroll = now }

    /// Before a waiting look starts: no look while a button is held, while scrolling, or while the screen still
    /// changes, up to `settleCap` after the calm.
    func hold(at now: Date, pressing: Bool, settled: Bool) -> Hold {
        if pressing { return .drop }
        let scroll = lastScroll.timeIntervalSince(now) + Self.scrollCalm
        if scroll > 0 { return .wait(scroll) }
        if !settled && now < lastAction.addingTimeInterval(Self.quiet + Self.settleCap) { return .wait(Self.settlePoll) }
        return .go
    }

    /// The screen is as it was at the last look: no look, nothing counted. True when a waiting look was skipped.
    mutating func skip() -> Bool {
        guard acted, !inFlight, !exhausted else { return false }
        acted = false
        return true
    }

    /// Where a target is after a scroll: moved as the element under it moved. Frames in Accessibility coordinates
    /// (y down), the target in AppKit's (y up).
    static func moved(_ target: CGRect, anchorWas: CGRect, anchorNow: CGRect) -> CGRect {
        target.offsetBy(dx: anchorNow.minX - anchorWas.minX, dy: anchorWas.minY - anchorNow.minY)
    }

    /// The student acted. Returns the wait before the next look; nil while a look runs (its end schedules the next
    /// one, however many actions came meanwhile) or once the ceiling is reached.
    mutating func userActed(at now: Date) -> TimeInterval? {
        guard !exhausted else { return nil }
        acted = true
        lastAction = now
        return inFlight ? nil : wait(now)
    }

    /// The wait is over. True when a look starts now: only after an action, one at a time, under the ceiling.
    mutating func startLook(at now: Date) -> Bool {
        guard acted, !inFlight, !exhausted else { return false }
        acted = false
        inFlight = true
        looks += 1
        lastStart = now
        return true
    }

    /// The look is over. Returns the wait before one more look when the student acted during it, else nil.
    mutating func lookEnded(at now: Date) -> TimeInterval? {
        inFlight = false
        return acted && !exhausted ? wait(now) : nil
    }

    private func wait(_ now: Date) -> TimeInterval {
        max(lastAction.timeIntervalSince(now) + Self.quiet, lastStart.timeIntervalSince(now) + Self.gap, 0)
    }
}
