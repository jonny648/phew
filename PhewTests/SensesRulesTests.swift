import XCTest
@testable import Phew

final class SensesRulesTests: XCTestCase {
    private let longText = String(repeating: "menu ", count: 100)  // 500 characters, over the threshold

    private func packet(text: String, cursor: CursorElement?) -> ContextPacket {
        ContextPacket(appName: "App", bundleID: "id", windowTitle: "t", visibleText: text, cursor: cursor)
    }

    private func cursor(label: String = "", value: String = "") -> CursorElement {
        CursorElement(role: "AXGroup", label: label, value: value, frame: nil)
    }

    func testScreenshotWhenTextIsShort() {
        XCTAssertTrue(packet(text: "Slide\nFormat", cursor: cursor(label: "Title")).needsScreenshot)
    }

    func testScreenshotWhenCursorElementHasNoText() {
        XCTAssertTrue(packet(text: longText, cursor: cursor()).needsScreenshot)  // Figma canvas
        XCTAssertTrue(packet(text: longText, cursor: nil).needsScreenshot)
    }

    func testNoScreenshotWhenTextAndCursorTextAreThere() {
        XCTAssertFalse(packet(text: longText, cursor: cursor(label: "Share")).needsScreenshot)
        XCTAssertFalse(packet(text: longText, cursor: cursor(value: "Thesis.pdf")).needsScreenshot)
    }

    func testImageDataIsDropped() {
        let notion = "/7ImToAAAAAGSURBVAMA6fsjUHFG33gAAAAASUVORK5CYII="  // seen in Notion's tree
        XCTAssertEqual(WindowReader.removeJunk(notion), "")
        XCTAssertEqual(WindowReader.removeJunk("Logo \(notion) below"), "Logo  below")
        let dataURI = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
        XCTAssertEqual(WindowReader.removeJunk("img \(dataURI)"), "img ")
    }

    func testOrdinaryStringsSurvive() {
        let kept = [
            "https://www.notion.so/Thesis-Notes-1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d?pvs=4",
            "/Users/student/Documents/Thesis2026/Chapter3/FiguresAndTables/Final",
            "mario.rossi2026@studenti.university.it",
            "Rechtsschutzversicherungsgesellschaften",
            "NSAccessibilityVisibleCharacterRangeAttribute",
            "da39a3ee5e6b4b0d3255bfef95601890afd80709",  // a commit hash: no upper case
            "Exam on 2026-11-12, room 204: bring the slides.",
        ]
        for text in kept { XCTAssertEqual(WindowReader.removeJunk(text), text, text) }
    }
}
