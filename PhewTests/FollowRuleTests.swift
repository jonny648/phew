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
}
