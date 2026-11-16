import XCTest
@testable import Phew

/// Where the pointer goes. Made-up packets and displays only.
final class PointerTests: XCTestCase {
    /// R43: `NSScreen.screens` is empty for a moment while displays change; indexing it then quits Phew.
    func testNoShellCodeTakesTheFirstDisplayBlindly() throws {
        let shell = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appending(path: "Phew/Shell")
        let files = try FileManager.default.contentsOfDirectory(at: shell, includingPropertiesForKeys: nil).filter { $0.pathExtension == "swift" }
        XCTAssertFalse(files.isEmpty)
        for file in files {
            XCTAssertFalse(try String(contentsOf: file, encoding: .utf8).contains("screens[0]"), "\(file.lastPathComponent) indexes NSScreen.screens")
        }
    }

    /// R52: a trackpad's tens of scroll events a second make one frame read at a time, and the last scroll is read.
    func testScrollsMakeOneReadAtATimeAndTheLastIsRead() {
        var reads = ScrollReads()
        XCTAssertTrue(reads.scrolled(), "the first scroll reads at once")
        for _ in 0..<30 { XCTAssertFalse(reads.scrolled(), "no second read while one runs") }
        XCTAssertTrue(reads.ended(), "one more read for the scrolls that came meanwhile")
        XCTAssertFalse(reads.ended(), "then the reads stop")
        XCTAssertTrue(reads.scrolled(), "and the next scroll reads at once again")
        XCTAssertEqual(ScrollReads.gap, .milliseconds(66), "about 15 reads a second at most")
    }

    func testStepTargetsBecomeScreenRects() {
        var packet = ContextPacket(appName: "Notes", bundleID: "com.example.notes", windowTitle: "Draft",
                                   visibleText: "", cursor: nil)
        packet.pointables = [Pointable(id: "e1", role: "AXButton", label: "Share", frame: CGRect(x: 40, y: 60, width: 80, height: 24))]
        XCTAssertEqual(packet.screenRect(for: .element("e1")), CGRect(x: 40, y: 60, width: 80, height: 24))
        XCTAssertNil(packet.screenRect(for: .element("e9")))  // not in the packet
        XCTAssertNil(packet.screenRect(for: .point(x: 10, y: 20)))  // no screenshot to measure from

        packet.screenshotFrame = CGRect(x: 1440, y: -200, width: 1920, height: 1080)  // a display to the right, higher up
        let point = packet.screenRect(for: .point(x: 100, y: 50))
        XCTAssertEqual(point, CGRect(x: 1540, y: -150, width: 0, height: 0))
        XCTAssertEqual(point?.isEmpty, true)  // zero size: the Shell circles it
    }

    func testTopLeftRectsFlipToAppKitOnEveryDisplay() {
        let mainHeight: CGFloat = 900  // the display with the menu bar, 1440 × 900
        // On the main display: 100 points from the top is 800 from the bottom.
        XCTAssertEqual(CGRect(x: 10, y: 100, width: 50, height: 20).flipped(mainHeight: mainHeight),
                       CGRect(x: 10, y: 780, width: 50, height: 20))
        // A 1920 × 1080 display above and to the left: top-left origin (-1920, -1080), AppKit frame y 900…1980.
        let element = CGRect(x: -1000, y: -500, width: 100, height: 40).flipped(mainHeight: mainHeight)
        XCTAssertEqual(element, CGRect(x: -1000, y: 1360, width: 100, height: 40))
        XCTAssertTrue(CGRect(x: -1920, y: 900, width: 1920, height: 1080).contains(element))
    }

    /// N2.9: an Accessibility rect on a display to the left, right or above lands, flipped, on that display's AppKit
    /// frame, and the overlay picks that display. Main 1440 × 900; left 1920 × 1080 with its top 100 above the main
    /// one's; right 1280 × 800 with its bottom level with the main one's; above 1600 × 1000, centred.
    func testPointerFindsTheDisplayLeftRightAndAbove() {
        let mainHeight: CGFloat = 900
        let main = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let left = NSRect(x: -1920, y: -80, width: 1920, height: 1080)   // AX top-left (-1920, -100)
        let right = NSRect(x: 1440, y: 0, width: 1280, height: 800)      // AX top-left (1440, 100)
        let above = NSRect(x: -80, y: 900, width: 1600, height: 1000)    // AX top-left (-80, -1000)
        let displays = [main, left, right, above]
        let cases: [(CGRect, NSRect)] = [
            (CGRect(x: -1000, y: -50, width: 100, height: 40), left),
            (CGRect(x: 1500, y: 700, width: 100, height: 40), right),
            (CGRect(x: 200, y: -900, width: 100, height: 40), above),
            (CGRect(x: 200, y: 300, width: 100, height: 40), main),
        ]
        for (ax, display) in cases {
            let target = ax.flipped(mainHeight: mainHeight)
            XCTAssertTrue(display.contains(target), "\(ax)")
            XCTAssertEqual(PointerOverlay.display(for: NSPoint(x: target.midX, y: target.midY), among: displays), display, "\(ax)")
        }
        // Below the right display's bottom, outside every display: none.
        XCTAssertNil(PointerOverlay.display(for: NSPoint(x: 1500, y: -10), among: displays))
    }
}
