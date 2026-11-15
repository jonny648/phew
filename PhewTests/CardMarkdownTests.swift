import XCTest
@testable import Phew

final class CardMarkdownTests: XCTestCase {
    func testAReportIsDrawnWithoutItsMarks() {
        let shown = String(CardMarkdown.attributed("# Made-up title\n\nA **bold** word.\n- first\n- second").characters)
        XCTAssertEqual(shown, "Made-up title\n\nA bold word.\n• first\n• second")
    }

    func testPlainTextIsUnchanged() {
        let plain = "Press Bold, then Save.\n1. Fake step 1."
        XCTAssertEqual(String(CardMarkdown.attributed(plain).characters), plain)
    }
}
