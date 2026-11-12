import XCTest
@testable import Phew

/// Where the pointer goes. Made-up packets and displays only.
final class PointerTests: XCTestCase {
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
}
