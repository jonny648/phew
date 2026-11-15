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
    /// A press and release further apart than this, in points, is a drag: never a direct hit.
    static let dragSlop: CGFloat = 4

    /// The student acted since the last look started.
    private(set) var acted = false
    private(set) var inFlight = false
    private(set) var looks = 0
    private var lastAction = Date.distantPast
    private(set) var lastStart = Date.distantPast
    private var lastScroll = Date.distantPast
    /// Where the left button went down, AppKit screen coordinates. Nil when no press is being made.
    private var press: CGPoint?
    /// The earliest step a direct hit moved on from, waiting for a look to confirm it (PS.3). Nil when none waits.
    private(set) var guessed: Int?

    var exhausted: Bool { looks >= Self.ceiling }

    mutating func pressed(at point: CGPoint) { press = point }

    /// A press and its release make a direct hit on `target`: no drag, and the release inside the marked element,
    /// or inside the ring around a marked point (a zero-size rect). AppKit screen coordinates.
    static func directHit(down: CGPoint, up: CGPoint, on target: CGRect) -> Bool {
        guard hypot(up.x - down.x, up.y - down.y) <= dragSlop else { return false }
        return target.isEmpty ? hypot(up.x - target.midX, up.y - target.midY) <= PointerOverlay.pointRadius : target.contains(up)
    }

    /// The button went up. True when the card moves on at once: a direct hit on the target of a step that needs only
    /// a click, and not the last step, so the card never closes on a guess. The step it leaves waits for the next
    /// look to confirm it. Typing, dragging and choosing steps wait for the look, as do hits once no look is left.
    mutating func released(at point: CGPoint, step: Int, count: Int, click: Bool, target: CGRect?) -> Bool {
        defer { press = nil }
        guard click, step < count - 1, !exhausted, let press, let target, Self.directHit(down: press, up: point, on: target) else { return false }
        guessed = min(guessed ?? step, step)
        return true
    }

    /// Where the next look judges from: the step a direct hit left while its confirm waits, else the card's step.
    func lookFrom(_ shown: Int) -> Int { min(guessed ?? shown, shown) }

    /// A step line was picked: the student's choice wins, no guess waits any more.
    mutating func settle() { guessed = nil }

    /// What the card does with a look's answer.
    enum Outcome: Equatable {
        /// The card's step changed during the look (a step line, a direct hit): the newer state wins.
        case drop
        /// The same step; only its target may move.
        case stay
        /// To this step: on, or back when a direct hit's step was not done.
        case move(Int)
        /// Every step done.
        case done
    }

    /// A look ended. `shown`: the card's step when it started, `now`: the card's step at its end. A look with a
    /// judgement settles a waiting guess; one without (`checked` false) leaves the card and the guess as they are.
    mutating func judged(_ result: GuideProgress, shown: Int, now: Int, count: Int) -> Outcome {
        guard now == shown else { return .drop }
        guard result.checked else { return .stay }
        guessed = nil
        let step = min(max(result.current, 0), count)
        return step >= count ? .done : step == shown ? .stay : .move(step)
    }

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
    /// Never while a direct hit waits for its confirm: the look must judge it.
    mutating func skip() -> Bool {
        guard acted, !inFlight, !exhausted, guessed == nil else { return false }
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
