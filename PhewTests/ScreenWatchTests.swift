import XCTest
@testable import Phew

/// The screen watch during a guide (PS.6, PS.2). Made-up pixels and times only; no stream is started.
final class ScreenWatchTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 1000)
    private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }
    private let main = ObjectIdentifier(Int.self), second = ObjectIdentifier(String.self)  // two made-up displays
    private let page: [UInt8] = [10, 20, 30, 255, 10, 20, 30, 255]
    private let ticked: [UInt8] = [10, 20, 30, 255, 10, 20, 31, 255]  // one channel of one pixel differs

    func testTheScreenSettlesAfterTheCalm() {
        var frames = WatchFrames()
        frames.open(markFirst: true)
        XCTAssertTrue(frames.settled(at: at(0)))  // nothing seen yet
        frames.add(page, from: main, at: at(0))
        XCTAssertTrue(frames.settled(at: at(0)))  // the first frame is not a change
        frames.add(ticked, from: main, at: at(1))
        XCTAssertFalse(frames.settled(at: at(1.2)))
        frames.add(ticked, from: main, at: at(1.25))  // the same pixels again: no change
        XCTAssertFalse(frames.settled(at: at(1.29)))
        XCTAssertTrue(frames.settled(at: at(1.31)))
    }

    func testAnUnchangedScreenIsSeenAsUnchanged() {
        var frames = WatchFrames()
        frames.open(markFirst: true)
        frames.add(page, from: main, at: at(0))
        frames.add(page, from: second, at: at(0))
        XCTAssertFalse(frames.changed)  // a click on empty space: no look
        frames.add(ticked, from: second, at: at(1))
        XCTAssertTrue(frames.changed)  // one channel of one pixel on another display is enough
        frames.mark()  // a look starts on it
        XCTAssertFalse(frames.changed)
        frames.add(page, from: second, at: at(2))  // back as it was before that look: a change again
        XCTAssertTrue(frames.changed)
    }

    func testAFrameAfterTheActionIsNeverTheReference() {
        var frames = WatchFrames()
        frames.open(markFirst: true)
        frames.actionSeen()  // the user acted before the first frame came
        frames.add(ticked, from: main, at: at(0))
        XCTAssertTrue(frames.changed)  // nothing to compare with: the look goes ahead
        frames.open(markFirst: false)  // an idle stop, then an action starts the watch again
        frames.add(page, from: main, at: at(1))
        XCTAssertTrue(frames.changed)
    }

    func testUnknownMeansChanged() {
        var frames = WatchFrames()
        XCTAssertTrue(frames.changed)  // not open, no frame
        frames.add(page, from: main, at: at(0))  // a frame after a stop is ignored
        XCTAssertTrue(frames.isEmpty)
        frames.open(markFirst: true)
        frames.add(page, from: main, at: at(0))
        frames.blind = true  // a stream failed: changes cannot be seen
        XCTAssertTrue(frames.changed)
    }

    func testWithoutAStreamEveryLookGoesAhead() {
        let watch = ScreenWatch(screen: false)
        watch.start(markFirst: true)
        watch.receive(page, from: main, at: at(0))
        XCTAssertTrue(watch.changed())
        watch.stop("test")
    }

    func testStopDropsTheFramesAndIgnoresLateOnes() {
        let watch = ScreenWatch(screen: false)
        watch.start(markFirst: true)
        watch.receive(page, from: main, at: at(0))
        watch.mark()
        XCTAssertTrue(watch.holdsFrames)
        watch.stop("following stopped")
        XCTAssertFalse(watch.running)
        XCTAssertFalse(watch.holdsFrames)
        watch.receive(page, from: main, at: at(1))  // a frame still on its way
        XCTAssertFalse(watch.holdsFrames)
        XCTAssertTrue(watch.changed())
    }

    func testTwoMinutesWithoutAnActionStopTheWatchAndAnActionStartsItAgain() {
        let watch = ScreenWatch(screen: false)
        watch.start(markFirst: true)
        watch.acted(at: t0)
        XCTAssertEqual(watch.checkIdle(at: at(30))!, ScreenWatch.idleLimit - 30, accuracy: 1e-9)
        watch.acted(at: at(100))  // any action, a scroll or a press too, starts the two minutes again
        XCTAssertNotNil(watch.checkIdle(at: at(219)))
        XCTAssertTrue(watch.running)
        XCTAssertNil(watch.checkIdle(at: at(220)))
        XCTAssertFalse(watch.running)
        XCTAssertFalse(watch.holdsFrames)
        XCTAssertNil(watch.checkIdle(at: at(221)))  // stopped stays stopped
        watch.acted(at: at(300))
        XCTAssertTrue(watch.running)
        watch.stop("test")
        XCTAssertFalse(watch.running)
    }

    func testTheWatchNeverStartsTwice() {
        let watch = ScreenWatch(screen: false)
        watch.start(markFirst: true)
        watch.receive(page, from: main, at: at(0))
        watch.start(markFirst: true)  // a second start keeps what is held
        XCTAssertTrue(watch.holdsFrames)
        watch.stop("test")
        watch.stop("test")  // a second stop is harmless
        XCTAssertFalse(watch.running)
    }
}
