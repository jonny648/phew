import XCTest
@testable import Phew

final class SecretsFilterTests: XCTestCase {
    // Fake keys are built from pieces, so no key-shaped literal sits in the repository.
    private let filler = String(repeating: "aB3x", count: 10)  // 40 characters

    func testEachKindOfKeyIsRemoved() {
        let keys = [
            "sk-" + "ant-api03-" + filler,           // Anthropic
            "sk-" + "proj-" + filler,                // OpenAI
            "sk-" + filler,
            "ghp" + "_" + filler,                    // GitHub classic token
            "github" + "_pat_" + filler,             // GitHub fine-grained token
            "AKIA" + "ABCDEFGHIJKLMNOP",             // AWS access key id
            "xoxb" + "-1234567890-" + filler,        // Slack bot
            "xoxp" + "-1234567890-" + filler,        // Slack user
            "AIza" + String(filler.prefix(35)),      // Google
            "sk_" + "live_" + filler,                // Stripe
            "eyJ" + "hbGciOiJIUzI1NiJ9" + ".eyJ" + "zdWIiOiIxMjM0In0" + "." + filler,  // JWT
            "Bearer " + filler,
            "-----BEGIN RSA PRIVATE" + " KEY-----\n" + filler + "\n-----END RSA PRIVATE" + " KEY-----",
        ]
        for key in keys {
            XCTAssertEqual(SecretsFilter.clean("my key: \(key) ok"), "my key: \(SecretsFilter.keyMarker) ok", key)
        }
    }

    func testLuhnValidCardsAreRemoved() {
        let cards = ["4111 1111 1111 1111", "5555-5555-5555-4444", "378282246310005", "4012888888881881"]
        for card in cards {
            XCTAssertEqual(SecretsFilter.clean("card \(card), thanks"), "card \(SecretsFilter.cardMarker), thanks", card)
        }
    }

    func testLuhnInvalidNumberIsKept() {
        let text = "ref 4111 1111 1111 1112 and 5555-5555-5555-4445"
        XCTAssertEqual(SecretsFilter.clean(text), text)
    }

    func testOrdinaryTextAndNumbersAreKept() {
        let text = """
        Exam on 2026-11-12 at 14:30 in room 204, 12/11/2026. Call +39 333 123 4567 or +1 (415) 555-2671 \
        or 0039 333 1234567. Student id 1234567, matricola 897654. Price 1,299.00 EUR, 3.14159, \
        timestamp 1731405600000. Ask the task-list skill, sk-learn, gh_pages, a JWT is eyJ.short.
        """
        XCTAssertEqual(SecretsFilter.clean(text), text)
    }

    func testSeveralSecretsInOneText() {
        let text = "keys sk-\(filler) and ghp_\(filler); card 4111-1111-1111-1111; date 2026-11-12."
        XCTAssertEqual(SecretsFilter.clean(text),
                       "keys [key removed] and [key removed]; card [card removed]; date 2026-11-12.")
    }

    func testSecureFieldsAreRecognised() {
        XCTAssertTrue(SecretsFilter.isSecure(role: "AXTextField", subrole: "AXSecureTextField"))
        XCTAssertTrue(SecretsFilter.isSecure(role: "AXSecureTextField", subrole: ""))
        XCTAssertFalse(SecretsFilter.isSecure(role: "AXTextField", subrole: "AXSearchField"))
    }

    func testPacketFilterCoversEveryString() {
        let key = "sk-" + filler
        let packet = ContextPacket(appName: "App", bundleID: "id", windowTitle: "t \(key)", visibleText: "v \(key)",
                                   cursor: CursorElement(role: "AXStaticText", label: "l \(key)", value: "4111 1111 1111 1111", frame: nil))
            .filtered()
        XCTAssertEqual(packet.windowTitle, "t [key removed]")
        XCTAssertEqual(packet.visibleText, "v [key removed]")
        XCTAssertEqual(packet.cursor?.label, "l [key removed]")
        XCTAssertEqual(packet.cursor?.value, "[card removed]")
    }

    func testTrimKeepsNearestTextInReadingOrder() {
        let texts = [
            WindowReader.Text(string: "far text", frame: CGRect(x: 1000, y: 1000, width: 10, height: 10)),
            WindowReader.Text(string: "near", frame: CGRect(x: 0, y: 0, width: 10, height: 10)),
            WindowReader.Text(string: "nowhere", frame: nil),
        ]
        let out = ContextPacket.trim(texts, near: CGPoint(x: 5, y: 5), cap: 20)
        XCTAssertEqual(out, "far text\nnear\nnowher")
        XCTAssertEqual(ContextPacket.trim(texts, near: CGPoint(x: 5, y: 5), cap: 4), "near")
    }
}
