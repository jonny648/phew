import XCTest
@testable import Phew

/// The notch while he listens (P6): its geometry on made-up screens and its states. Nothing is put on screen.
final class NotchTests: XCTestCase {
    /// A made-up 14-inch laptop: 1512 by 982, a notch 184 wide and 32 high in the middle of the top edge.
    private let laptop = CGRect(x: 0, y: 0, width: 1512, height: 982)
    private let left = CGRect(x: 0, y: 950, width: 664, height: 32), right = CGRect(x: 848, y: 950, width: 664, height: 32)

    func testTheNotchComesFromTheAreasBesideIt() throws {
        let notch = try XCTUnwrap(NotchGeometry.notch(frame: laptop, safeTop: 32, left: left, right: right))
        XCTAssertEqual(notch, CGRect(x: 664, y: 950, width: 184, height: 32))
        // A second screen to the right, its own coordinates.
        let moved = laptop.offsetBy(dx: 1920, dy: 0)
        XCTAssertEqual(NotchGeometry.notch(frame: moved, safeTop: 32, left: left, right: right)?.minX, 1920 + 664)
        XCTAssertNil(NotchGeometry.notch(frame: laptop, safeTop: 0, left: left, right: right), "no safe area: no notch")
        XCTAssertNil(NotchGeometry.notch(frame: laptop, safeTop: 32, left: nil, right: nil))
        XCTAssertNil(NotchGeometry.notch(frame: laptop, safeTop: 32, left: CGRect(x: 0, y: 0, width: 800, height: 32),
                                         right: CGRect(x: 0, y: 0, width: 800, height: 32)), "areas that overlap are no notch")
    }

    func testTheShapeStartsAsTheNotchAndGrowsOutOfIt() throws {
        let notch = try XCTUnwrap(NotchGeometry.notch(frame: laptop, safeTop: 32, left: left, right: right))
        let g = NotchGeometry(frame: laptop, visible: CGRect(x: 0, y: 0, width: 1512, height: 950), notch: notch)
        XCTAssertEqual(g.start, notch, "it starts exactly as the notch")
        XCTAssertEqual(g.band, 32)
        for grown in [g.grown, g.tall] {
            XCTAssertEqual(grown.midX, notch.midX, "centred on the notch")
            XCTAssertEqual(grown.maxY, laptop.maxY, "hangs from the top edge")
            XCTAssertGreaterThan(grown.width, notch.width)
            XCTAssertGreaterThan(grown.height, notch.height)
            XCTAssertTrue(laptop.contains(grown))
        }
        XCTAssertGreaterThan(g.tall.height, g.grown.height, "taller for the problem line")
        XCTAssertTrue(laptop.contains(g.window))
        XCTAssertTrue(g.window.contains(g.tall) && g.window.contains(g.start))
        XCTAssertEqual(g.window.width, g.tall.width + 2 * NotchGeometry.shoulder, "the panel is the shape, nothing more")
        XCTAssertEqual(g.window.height, g.tall.height)
        // A notch an odd number of points wide: the panel is in whole points, as AppKit places it, and still centred.
        let odd = CGRect(x: 663.5, y: 950, width: 185, height: 32)
        let w = NotchGeometry(frame: laptop, visible: laptop, notch: odd).window
        XCTAssertEqual(w, w.integral)
        XCTAssertEqual(w.midX, odd.midX, accuracy: 0.5)
        XCTAssertTrue(w.contains(NotchGeometry(frame: laptop, visible: laptop, notch: odd).tall))
    }

    func testWithoutANotchAPillDropsUnderTheMenuBar() {
        let display = CGRect(x: 1512, y: -98, width: 1920, height: 1080)
        let visible = CGRect(x: 1512, y: -98, width: 1920, height: 1055)  // a 25-point menu bar
        let g = NotchGeometry(frame: display, visible: visible, notch: nil)
        XCTAssertEqual(g.band, 0)
        XCTAssertEqual(g.grown.midX, display.midX)
        XCTAssertEqual(g.grown.maxY, visible.maxY - 8, "under the menu bar, not on it")
        XCTAssertLessThan(g.start.width, g.grown.width)
        XCTAssertTrue(display.contains(g.window))
        // Full screen: no menu bar, the pill comes from the top edge.
        let full = NotchGeometry(frame: display, visible: display, notch: nil)
        XCTAssertEqual(full.grown.maxY, display.maxY - 8)
    }

    func testTheGrownShapeStaysInsideASmallScreen() {
        let small = CGRect(x: 0, y: 0, width: 200, height: 300)
        let notch = NotchGeometry.notch(frame: small, safeTop: 30, left: CGRect(x: 0, y: 270, width: 40, height: 30),
                                        right: CGRect(x: 160, y: 270, width: 40, height: 30))
        for g in [NotchGeometry(frame: small, visible: small, notch: notch), NotchGeometry(frame: small, visible: small, notch: nil)] {
            XCTAssertTrue(small.contains(g.window), "\(g.window)")
        }
    }

    @MainActor
    func testListeningThenSent() {
        let model = NotchModel()
        model.reset()
        model.grow()
        XCTAssertTrue(model.listening)
        XCTAssertTrue(model.silent, "nothing heard yet: the bars rest, the dot breathes")
        model.take(0.9)
        XCTAssertEqual(model.level, 0.54, accuracy: 0.001, "rises fast")
        XCTAssertFalse(model.silent)
        model.take(0)
        XCTAssertEqual(model.level, 0.405, accuracy: 0.001, "falls slower")
        XCTAssertEqual(model.beat, 2)
        model.hear("made-up words")
        XCTAssertEqual(model.words, "made-up words")
        model.end(.sent)
        XCTAssertFalse(model.open)
        XCTAssertEqual(model.ended, .sent)
        model.take(1)
        model.hear("late words")
        XCTAssertEqual(model.words, "made-up words", "nothing moves once it closes")
        XCTAssertEqual(model.beat, 2)
    }

    @MainActor
    func testCancelledAndModelMissing() {
        let model = NotchModel()
        model.grow()
        model.take(0.8)
        model.say("A made-up problem line.")
        XCTAssertEqual(model.line, "A made-up problem line.")
        XCTAssertFalse(model.listening, "the line replaces listening")
        XCTAssertEqual(model.level, 0, "the bars rest")
        model.take(1)
        XCTAssertEqual(model.level, 0)
        model.end(.cancelled)
        XCTAssertEqual(model.ended, .cancelled)
        model.say("Late line.")
        XCTAssertEqual(model.line, "A made-up problem line.")
        // A new hold starts clean.
        model.reset()
        model.grow()
        XCTAssertTrue(model.listening)
        XCTAssertNil(model.line)
        XCTAssertNil(model.ended)
        XCTAssertEqual(model.words, "")
    }

    func testReduceMotionCrossFadesAndNeverGrows() {
        XCTAssertTrue(NotchModel.style(reduce: false, notched: true) == (grows: true, fades: false), "out of the notch")
        XCTAssertTrue(NotchModel.style(reduce: false, notched: false) == (grows: true, fades: true), "the pill fades as it drops")
        XCTAssertTrue(NotchModel.style(reduce: true, notched: true) == (grows: false, fades: true))
        XCTAssertTrue(NotchModel.style(reduce: true, notched: false) == (grows: false, fades: true))
    }

    @MainActor
    func testTheBarsStayInTheirBand() {
        for beat in 0..<50 {
            for bar in LevelBars.weights.indices {
                XCTAssertEqual(LevelBars.height(bar, level: 0, beat: beat), LevelBars.rest, "quiet: resting")
                for level in [0.3, 1, 7] {
                    let height = LevelBars.height(bar, level: level, beat: beat)
                    XCTAssertGreaterThanOrEqual(height, LevelBars.rest)
                    XCTAssertLessThanOrEqual(height, LevelBars.tall)
                }
            }
        }
    }
}
