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

    /// The student acted since the last look started.
    private(set) var acted = false
    private(set) var inFlight = false
    private(set) var looks = 0
    private var lastAction = Date.distantPast
    private(set) var lastStart = Date.distantPast

    var exhausted: Bool { looks >= Self.ceiling }

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
