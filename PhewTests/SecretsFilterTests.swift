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

    // Made-up passwords, written in ordinary text: the value goes, the word stays, the marker shows where.
    func testPasswordsInPlainTextAreRemoved() {
        let cases = [
            ("the password Brisk-Otter-77", "Brisk-Otter-77"), ("password: x", "x"), ("pw x", "x"), ("pwd: tango", "tango"),
            ("pin 4421", "4421"), ("PIN = 4421", "4421"), ("The wifi password is Tangerine", "Tangerine"),
            ("passcode 99-ab", "99-ab"), ("passphrase - lunar", "lunar"), ("la password è gattonero", "gattonero"),
            ("La password è Gatto77", "Gatto77"), ("codice PIN 1234", "1234"), ("la parola d'ordine è mela", "mela"),
            ("Password \"Fiume_12\" saved", "Fiume_12"), ("PIN: [4421]", "4421"),
        ]
        for (text, value) in cases {
            let out = SecretsFilter.clean(text)
            XCTAssertFalse(out.contains(value), text)
            XCTAssertTrue(out.contains(SecretsFilter.secretMarker), text)
        }
        XCTAssertEqual(SecretsFilter.clean("the password Brisk-Otter-77 works"), "the password [secret removed] works")
    }

    func testOrdinaryPasswordPhrasesAreKept() {
        for text in ["Open the password manager", "Click the password field", "Forgot password?", "Reset the PIN code from settings",
                     "Use a strong password.", "Pin this tab", "Pinterest board", "Change the password in Settings",
                     "The file is password-protected", "Il codice è pronto", "Parola chiave: scarpe rosse", "input_tokens: 25"] {
            XCTAssertEqual(SecretsFilter.clean(text), text)
        }
    }

    func testAKeyOrCardAfterAPasswordWordIsOneMarker() {
        XCTAssertEqual(SecretsFilter.clean("token: sk-\(filler)"), "token: \(SecretsFilter.keyMarker)")
        XCTAssertEqual(SecretsFilter.clean("PIN 4111 1111 1111 1111"), "PIN \(SecretsFilter.cardMarker)")
        let once = SecretsFilter.clean("password: hunter2")
        XCTAssertEqual(SecretsFilter.clean(once), once, "filtering twice changes nothing")
    }

    func testOnePasswordInALongScreenText() {
        let text = """
        Studio Lumen — Onboarding checklist
        Welcome to the team! Before Monday, please finish the steps below.
        1. Install the design apps from the Self Service portal.
        2. Open the password manager and accept the shared vault invite.
        3. Join the #brand-refresh channel and say hello.
        4. Wi-Fi in the office: network LumenGuest, the password is Copper-Kettle-58 (changes every month).
        5. Book a desk for Thursday, room 204, from 09:30 to 17:00.
        If you forgot your password, use "Forgot password?" on the login page or call +39 333 123 4567.
        Reset the PIN code from settings if the badge reader asks for it.
        """
        let out = SecretsFilter.clean(text)
        XCTAssertFalse(out.contains("Copper"))
        XCTAssertFalse(out.contains("Kettle-58"))
        XCTAssertEqual(out, text.replacingOccurrences(of: "password is Copper-Kettle-58", with: "password \(SecretsFilter.secretMarker)"))
    }

    func testSecureFieldsAreRecognised() {
        XCTAssertTrue(SecretsFilter.isSecure(role: "AXTextField", subrole: "AXSecureTextField"))
        XCTAssertTrue(SecretsFilter.isSecure(role: "AXSecureTextField", subrole: ""))
        XCTAssertFalse(SecretsFilter.isSecure(role: "AXTextField", subrole: "AXSearchField"))
    }

    func testPacketFilterCoversEveryString() {
        let key = "sk-" + filler
        let packet = ContextPacket(appName: "App", bundleID: "id", windowTitle: "t \(key)", visibleText: "v \(key)",
                                   cursor: CursorElement(role: "AXStaticText", label: "l \(key)", value: "4111 1111 1111 1111", frame: nil),
                                   pointables: [Pointable(role: "AXLink", label: "p \(key)", frame: .zero)])
            .filtered()
        XCTAssertEqual(packet.windowTitle, "t [key removed]")
        XCTAssertEqual(packet.visibleText, "v [key removed]")
        XCTAssertEqual(packet.cursor?.label, "l [key removed]")
        XCTAssertEqual(packet.cursor?.value, "[card removed]")
        XCTAssertEqual(packet.pointables.first?.label, "p [key removed]")
    }

    func testDocumentPathIsFiltered() {
        let key = "sk-" + filler
        let packet = ContextPacket(appName: "App", bundleID: "id", windowTitle: "t", visibleText: "", cursor: nil,
                                   documentPath: "/Users/someone/keys/\(key).txt").filtered()
        XCTAssertEqual(packet.documentPath, "/Users/someone/keys/[key removed].txt")
    }

    func testPointableLabelIsFilteredBeforeItIsCut() {
        // The key starts before the label cap and ends after it: a cut first would leave half a key behind.
        let label = String(repeating: "a", count: ContextPacket.labelCap - 10) + " sk-" + filler
        let kept = ContextPacket.select([Pointable(role: "AXLink", label: label, frame: .zero)], near: .zero)
        XCTAssertFalse(kept[0].label.contains("sk-"))
        XCTAssertFalse(kept[0].label.contains("aB3x"))
    }

    /// R2: the field under the mouse is filtered as its name and value together, as the model reads them.
    func testAFieldNameAndItsValueAreFilteredTogether() {
        for (label, value) in [("Password", "hunter2"), ("PIN", "4421"), ("Token", "madeuptoken"), ("API key", "9f8e7d6c5b4a"),
                               ("Wi-Fi password", "Tangerine"), ("DB_PASSWORD", "correcthorse")] {
            let packet = ContextPacket(appName: "App", bundleID: "id", windowTitle: "", visibleText: "",
                                       cursor: CursorElement(role: "AXTextField", label: label, value: value, frame: nil)).filtered()
            XCTAssertEqual(packet.cursor?.value, SecretsFilter.secretMarker, label)
            XCTAssertEqual(packet.cursor?.label, label)
        }
        for (label, value) in [("Search", "Made-up recipe"), ("Name", "Made Up"), ("Password manager", ""), ("Pin this tab", "")] {
            let packet = ContextPacket(appName: "App", bundleID: "id", windowTitle: "", visibleText: "",
                                       cursor: CursorElement(role: "AXTextField", label: label, value: value, frame: nil)).filtered()
            XCTAssertEqual([packet.cursor?.label, packet.cursor?.value], [label, value])
        }
    }

    /// R24: settings files and JSON write their secret names with underscores or dashes.
    func testSecretsNamedWithUnderscoresAreRemoved() {
        let cases = [
            ("DB_PASSWORD=correcthorse1", "correcthorse1"),
            ("AWS_SECRET_ACCESS_KEY=" + "wJalrXUtnFEMI" + "K7MDENGbPxRfiCYEXAMPLE", "wJalrXUtnFEMI"),
            ("API_KEY=9f8e7d6c5b4a", "9f8e7d6c5b4a"),
            (#""access_token": "ya29.madeupvalue""#, "ya29"),
            ("client_secret=abc123", "abc123"),
            ("apikey: madeup42", "madeup42"),
            ("AUTH-TOKEN=madeuptoken", "madeuptoken"),
            ("private_key = madeupvalue", "madeupvalue"),
            ("DJANGO_SECRET: madeupvalue", "madeupvalue"),
            ("export STRIPE_API_SECRET=madeupvalue", "madeupvalue"),
        ]
        for (text, value) in cases {
            let out = SecretsFilter.clean(text)
            XCTAssertFalse(out.contains(value), text)
            XCTAssertTrue(out.contains(SecretsFilter.secretMarker), text)
        }
        for text in ["input_tokens: 25", "max_tokens = 1024", "token_count: 3", "The secret garden is open", "Keep it secret, keep it safe",
                     "PASSWORD_HASH_ROUNDS: 12", "Spin 4421 times"] {
            XCTAssertEqual(SecretsFilter.clean(text), text)
        }
    }

    /// R19: a password field's value is never read: the reader is not even asked, in the window walk, under the mouse
    /// or by the Hand. Made-up values.
    func testSecureFieldsAreNeverRead() {
        let marker = "Made-up-secret-4242"
        var asked = 0
        XCTAssertNil(SecretsFilter.unlessSecure(role: "AXSecureTextField", subrole: "") { asked += 1; return marker })
        XCTAssertNil(SecretsFilter.unlessSecure(role: "AXTextField", subrole: "AXSecureTextField") { asked += 1; return marker })
        let frame = CGRect(x: 10, y: 20, width: 200, height: 24)
        let cursor = WindowReader.cursor(role: "AXTextField", subrole: "AXSecureTextField", label: "Made-up label", frame: frame) {
            asked += 1
            return marker
        }
        XCTAssertEqual(asked, 0, "the value was never asked for")
        XCTAssertEqual([cursor.role, cursor.label, cursor.value], ["AXSecureTextField", "", ""])
        XCTAssertEqual(cursor.frame, frame, "only its frame, so Phew can point at it")
        XCTAssertEqual(SecretsFilter.unlessSecure(role: "AXTextField", subrole: "") { marker }, marker)
        let plain = WindowReader.cursor(role: "AXTextField", subrole: "", label: "Made-up label", frame: frame) { marker }
        XCTAssertEqual([plain.label, plain.value], ["Made-up label", marker])
    }

    /// R20: what a capture read is filtered before the packet leaves Senses: every string, as assembled for the model.
    func testACaptureFiltersEveryStringItRead() throws {
        let key = "sk-" + filler
        let frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        let window: WindowReader.Window = (title: "t \(key)", frame: frame, documentPath: "/Users/someone/\(key).txt",
                                           texts: [WindowReader.Text(string: "v \(key)", frame: frame)],
                                           pointables: [Pointable(role: "AXLink", label: "p \(key)", frame: CGRect(x: 10, y: 10, width: 20, height: 20))])
        let cursor = CursorElement(role: "AXStaticText", label: "l \(key)", value: "4111 1111 1111 1111", frame: nil)
        let packet = Senses.packet(appName: "App \(key)", bundleID: "id", window: window, cursor: cursor, mouse: .zero)
        let json = try XCTUnwrap(String(data: JSONEncoder().encode(packet), encoding: .utf8))
        XCTAssertFalse(json.contains("aB3x"), json)
        XCTAssertFalse(json.contains("4111"), json)
        XCTAssertEqual(packet.appName, "App [key removed]")
        XCTAssertEqual(packet.visibleText, "v [key removed]")
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
