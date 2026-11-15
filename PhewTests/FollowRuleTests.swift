import XCTest
@testable import Phew

/// When a guide looks again. Made-up times only.
final class FollowRuleTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 1000)
    private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    func testNoLookWithoutAnAction() {
        var rule = FollowRule()
        XCTAssertFalse(rule.startLook(at: at(0)))
        XCTAssertEqual(rule.looks, 0)
        XCTAssertNil(rule.lookEnded(at: at(1)))
    }

    func testOneActionOneLookAfterTheCalm() {
        var rule = FollowRule()
        XCTAssertEqual(rule.userActed(at: at(0)), FollowRule.quiet)
        XCTAssertEqual(rule.userActed(at: at(0.4)), FollowRule.quiet)  // a later action restarts the calm
        XCTAssertTrue(rule.startLook(at: at(1.4)))
        XCTAssertFalse(rule.startLook(at: at(1.5)))  // one at a time
        XCTAssertNil(rule.lookEnded(at: at(3)))  // nothing done since: no more looks
        XCTAssertFalse(rule.startLook(at: at(10)))
        XCTAssertEqual(rule.looks, 1)
    }

    func testActionsDuringALookMakeExactlyOneMore() {
        var rule = FollowRule()
        _ = rule.userActed(at: at(0))
        XCTAssertTrue(rule.startLook(at: at(1)))
        XCTAssertNil(rule.userActed(at: at(1.2)))  // in flight: its end schedules the next one
        XCTAssertNil(rule.userActed(at: at(1.3)))
        // Ends at 1.5: the calm after 1.3 runs to 2.3, the gap after the start at 1 to 2.5. The later wins.
        XCTAssertEqual(rule.lookEnded(at: at(1.5))!, 1, accuracy: 1e-9)
        XCTAssertTrue(rule.startLook(at: at(2.5)))
        XCTAssertFalse(rule.startLook(at: at(2.6)))
        XCTAssertNil(rule.lookEnded(at: at(4)))
        XCTAssertEqual(rule.looks, 2)
    }

    func testLookStartsAreAtLeastTheGapApart() {
        var rule = FollowRule()
        _ = rule.userActed(at: at(0))
        XCTAssertTrue(rule.startLook(at: at(1)))
        XCTAssertNil(rule.lookEnded(at: at(1.1)))
        // An action right after a quick look: the calm says 1 s, the gap 1.4 s.
        XCTAssertEqual(rule.userActed(at: at(1.1))!, FollowRule.gap - 0.1, accuracy: 1e-9)
        // Long after: only the calm counts.
        var later = rule
        XCTAssertEqual(later.userActed(at: at(60)), FollowRule.quiet)
    }

    func testTheGuideStopsFollowingAtTheCeiling() {
        var rule = FollowRule()
        for n in 0..<FollowRule.ceiling {
            let t = TimeInterval(n) * 10
            XCTAssertNotNil(rule.userActed(at: at(t)))
            XCTAssertTrue(rule.startLook(at: at(t + 1)))
            if n == FollowRule.ceiling - 1 { _ = rule.userActed(at: at(t + 2)) }  // during the last look: no more
            XCTAssertNil(rule.lookEnded(at: at(t + 3)))
        }
        XCTAssertTrue(rule.exhausted)
        XCTAssertEqual(rule.looks, FollowRule.ceiling)
        XCTAssertNil(rule.userActed(at: at(1000)))
        XCTAssertFalse(rule.startLook(at: at(1001)))
        XCTAssertFalse(rule.skip())  // nothing to skip either
    }

    // MARK: - PS.1, PS.2, PS.6: drags, scrolls, a settling screen, an unchanged one

    func testNoLookWhileAButtonIsHeld() {
        var rule = FollowRule()
        _ = rule.userActed(at: at(0))
        XCTAssertEqual(rule.hold(at: at(1), pressing: true, settled: true), .drop)  // a drag: the release schedules it
        XCTAssertEqual(rule.hold(at: at(1), pressing: false, settled: true), .go)
    }

    func testAScrollMakesNoLookAndHoldsAWaitingOne() {
        var rule = FollowRule()
        rule.scrolled(at: at(0))
        XCTAssertFalse(rule.startLook(at: at(5)))  // a scroll alone is not an action
        XCTAssertEqual(rule.looks, 0)
        _ = rule.userActed(at: at(10))
        rule.scrolled(at: at(10.8))
        guard case .wait(let wait) = rule.hold(at: at(11), pressing: false, settled: true) else { return XCTFail() }
        XCTAssertEqual(wait, FollowRule.scrollCalm - 0.2, accuracy: 1e-9)  // until the scrolling has stopped 0.5 s
        XCTAssertEqual(rule.hold(at: at(11.3), pressing: false, settled: true), .go)
    }

    func testALookWaitsForTheScreenToSettleUpToTheCap() {
        var rule = FollowRule()
        _ = rule.userActed(at: at(0))
        XCTAssertEqual(rule.hold(at: at(1), pressing: false, settled: false), .wait(FollowRule.settlePoll))
        XCTAssertEqual(rule.hold(at: at(1.5), pressing: false, settled: true), .go)
        // A screen that never settles (a video) holds it at most `settleCap` after the calm.
        XCTAssertEqual(rule.hold(at: at(2.9), pressing: false, settled: false), .wait(FollowRule.settlePoll))
        XCTAssertEqual(rule.hold(at: at(FollowRule.quiet + FollowRule.settleCap), pressing: false, settled: false), .go)
    }

    func testAnUnchangedScreenSkipsTheLookWithoutCountingIt() {
        var rule = FollowRule()
        XCTAssertFalse(rule.skip())  // no action, nothing waiting
        _ = rule.userActed(at: at(0))
        XCTAssertTrue(rule.skip())
        XCTAssertEqual(rule.looks, 0)
        XCTAssertFalse(rule.startLook(at: at(1)))  // the skipped action makes no look later either
        _ = rule.userActed(at: at(2))
        XCTAssertTrue(rule.startLook(at: at(3)))
        XCTAssertFalse(rule.skip())  // a look in flight is never skipped
    }

    func testTheTargetMovesWithTheScrolledElement() {
        let target = CGRect(x: 100, y: 500, width: 80, height: 20)  // AppKit, y up
        // The element moved 120 points up the screen (Accessibility y down) and 10 to the right.
        let moved = FollowRule.moved(target, anchorWas: CGRect(x: 90, y: 300, width: 100, height: 30),
                                     anchorNow: CGRect(x: 100, y: 180, width: 100, height: 30))
        XCTAssertEqual(moved, CGRect(x: 110, y: 620, width: 80, height: 20))
        XCTAssertEqual(FollowRule.moved(target, anchorWas: .zero, anchorNow: .zero), target)
    }

    // MARK: - PS.3: a direct hit on a click step

    private let button = CGRect(x: 100, y: 200, width: 80, height: 24)  // a made-up element, AppKit coordinates
    private let point = CGRect(x: 400, y: 300, width: 0, height: 0)  // a marked point: its ring is 22 points

    /// A press at `down`, a release at `up`, on step `step` of 4.
    private func release(_ rule: inout FollowRule, down: CGPoint, up: CGPoint? = nil, step: Int = 0, click: Bool = true,
                         target: CGRect?) -> Bool {
        rule.pressed(at: down)
        return rule.released(at: up ?? down, step: step, count: 4, click: click, target: target)
    }

    func testADirectHitIsAPressAndReleaseInsideTheElementOrTheRing() {
        XCTAssertTrue(FollowRule.directHit(down: CGPoint(x: 120, y: 210), up: CGPoint(x: 122, y: 211), on: button))
        XCTAssertFalse(FollowRule.directHit(down: CGPoint(x: 120, y: 210), up: CGPoint(x: 150, y: 210), on: button))  // a drag
        XCTAssertFalse(FollowRule.directHit(down: CGPoint(x: 190, y: 210), up: CGPoint(x: 190, y: 210), on: button))  // beside it
        XCTAssertTrue(FollowRule.directHit(down: CGPoint(x: 415, y: 315), up: CGPoint(x: 415, y: 315), on: point))  // 21.2 from it
        XCTAssertFalse(FollowRule.directHit(down: CGPoint(x: 417, y: 317), up: CGPoint(x: 417, y: 317), on: point))  // 24 from it
        XCTAssertFalse(FollowRule.directHit(down: CGPoint(x: 400, y: 300), up: CGPoint(x: 406, y: 300), on: point))  // a short drag
    }

    func testAHitOnAClickStepMovesOnAndTheLookJudgesFromTheStepItLeft() {
        var rule = FollowRule()
        XCTAssertFalse(rule.released(at: CGPoint(x: 120, y: 210), step: 0, count: 4, click: true, target: button))  // no press seen
        XCTAssertFalse(release(&rule, down: CGPoint(x: 110, y: 210), up: CGPoint(x: 160, y: 210), target: button))  // a drag
        XCTAssertNil(rule.guessed)
        XCTAssertTrue(release(&rule, down: CGPoint(x: 120, y: 210), target: button))
        XCTAssertEqual(rule.guessed, 0)
        XCTAssertEqual(rule.lookFrom(1), 0)  // the card shows step 2, the look confirms step 1
        // A second hit before the look: the look still judges from the first step left.
        XCTAssertTrue(release(&rule, down: CGPoint(x: 400, y: 300), step: 1, target: point))
        XCTAssertEqual(rule.lookFrom(2), 0)
        // Its confirm is never skipped, even on a screen that looks unchanged.
        _ = rule.userActed(at: at(0))
        XCTAssertFalse(rule.skip())
    }

    func testTypingStepsTheLastStepAndMissingTargetsWaitForTheLook() {
        var rule = FollowRule()
        // A click into a text field on a typing step.
        XCTAssertFalse(release(&rule, down: CGPoint(x: 120, y: 210), step: 1, click: false, target: button))
        // The last step, so the card never closes on a guess.
        XCTAssertFalse(release(&rule, down: CGPoint(x: 120, y: 210), step: 3, target: button))
        XCTAssertFalse(release(&rule, down: CGPoint(x: 120, y: 210), step: 0, target: nil))
        XCTAssertNil(rule.guessed)
        XCTAssertEqual(rule.lookFrom(2), 2)
    }

    func testNoHitMovesOnOnceNoLookIsLeft() {
        var rule = FollowRule()
        for n in 0..<FollowRule.ceiling {
            _ = rule.userActed(at: at(TimeInterval(n) * 10))
            _ = rule.startLook(at: at(TimeInterval(n) * 10 + 1))
            _ = rule.lookEnded(at: at(TimeInterval(n) * 10 + 2))
        }
        XCTAssertFalse(release(&rule, down: CGPoint(x: 120, y: 210), target: button))
    }

    func testTheLookConfirmsOrStepsBack() {
        var rule = FollowRule()
        _ = release(&rule, down: CGPoint(x: 120, y: 210), target: button)  // the card moves on to step 2 (index 1)
        // The look finds step 1 not done: back to it, and the guess is settled.
        XCTAssertEqual(rule.judged(GuideProgress(current: 0, target: nil), shown: 1, now: 1, count: 4), .move(0))
        XCTAssertNil(rule.guessed)

        _ = release(&rule, down: CGPoint(x: 120, y: 210), target: button)
        XCTAssertEqual(rule.judged(GuideProgress(current: 1, target: nil), shown: 1, now: 1, count: 4), .stay)  // confirmed
        XCTAssertNil(rule.guessed)

        _ = release(&rule, down: CGPoint(x: 120, y: 210), target: button)
        XCTAssertEqual(rule.judged(GuideProgress(current: 3, target: nil), shown: 1, now: 1, count: 4), .move(3))  // further on
        XCTAssertEqual(rule.judged(GuideProgress(current: 9, target: nil), shown: 3, now: 3, count: 4), .done)

        // A look with no judgement leaves the card and the guess as they are.
        _ = release(&rule, down: CGPoint(x: 120, y: 210), target: button)
        XCTAssertEqual(rule.judged(GuideProgress(current: 0, target: nil, checked: false), shown: 1, now: 1, count: 4), .stay)
        XCTAssertEqual(rule.guessed, 0)
        // The card's step changed during the look (a newer hit, a step line): its answer is dropped, the guess waits.
        XCTAssertEqual(rule.judged(GuideProgress(current: 0, target: nil), shown: 1, now: 2, count: 4), .drop)
        XCTAssertEqual(rule.guessed, 0)
        rule.settle()  // a step line was picked
        XCTAssertNil(rule.guessed)
    }
}
