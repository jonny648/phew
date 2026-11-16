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

    // MARK: Links (R12)

    private func links(_ markdown: String) -> [URL] {
        CardMarkdown.attributed(markdown).runs.compactMap(\.link)
    }

    private func shown(_ markdown: String) -> String {
        String(CardMarkdown.attributed(markdown).characters)
    }

    func testOnlyWebLinksAreClickable() {
        for planted in ["[Read the full study](file:///Applications/MadeUp.app)", "[Source](javascript:alert(1))",
                        "[Source](shortcuts://run-shortcut?name=MadeUp)", "<smb://made-up-host/share>",
                        "[Open](madeupapp://do-something)", "[Here](//made-up.example/x)", "[Here](relative/path)"] {
            XCTAssertEqual(links(planted), [], "\(planted) must be plain text")
        }
        XCTAssertEqual(shown("[Read the full study](file:///Applications/MadeUp.app)"), "Read the full study")
        XCTAssertEqual(links("[Source](https://made-up.example/a)"), [URL(string: "https://made-up.example/a")!])
        XCTAssertEqual(links("[Source](HTTP://made-up.example/a)").count, 1)
    }

    func testALinkShowsWhereItReallyGoes() {
        XCTAssertEqual(shown("See [Read the full study](https://made-up.example/x) now."),
                       "See Read the full study (made-up.example) now.")
        // The words name one site, the link goes to another.
        XCTAssertEqual(shown("[https://bank.example](https://made-up.example/login)"),
                       "https://bank.example (made-up.example)")
        // A name before an @ is not the host.
        XCTAssertEqual(shown("<https://bank.example@made-up.example/login>"),
                       "https://bank.example@made-up.example/login (made-up.example)")
        // Look-alike letters: the real host in plain ASCII.
        XCTAssertEqual(shown("<https://\u{0430}pple.example/login>"), "https://\u{0430}pple.example/login (xn--pple-43d.example)")
        XCTAssertEqual(shown("[Apple](https://\u{0430}pple.example)"), "Apple (xn--pple-43d.example)")
        // An address shown whole, plain ASCII, needs nothing more.
        XCTAssertEqual(shown("<https://made-up.example/a>"), "https://made-up.example/a")
        // The added host is plain text, never part of the link.
        let card = CardMarkdown.attributed("[Source](https://made-up.example/a)")
        XCTAssertEqual(card.runs.filter { $0.link != nil }.map { String(card[$0.range].characters) }, ["Source"])
    }

    // MARK: Parsed once (R51)

    func testTheSameTextIsParsedOnce() {
        let text = "A **made-up** answer \(UUID().uuidString)"
        let before = CardMarkdown.parses
        let first = CardMarkdown.attributed(text)
        for _ in 0..<20 { XCTAssertEqual(CardMarkdown.attributed(text), first) }
        XCTAssertEqual(CardMarkdown.parses - before, 1, "a redraw with the same words must not parse again")
    }
}
