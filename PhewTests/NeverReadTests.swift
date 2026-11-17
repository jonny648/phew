import AppKit
import XCTest
@testable import Phew

/// "Never read this app" (PS.9), with a made-up app on a list kept in a throwaway UserDefaults suite.
@MainActor
final class NeverReadTests: XCTestCase {
    private let madeUp = (name: "Made Up Notes", bundleID: "com.example.madeup-notes")
    private var suite = ""
    private var list: NeverReadList!

    override func setUp() {
        suite = "PhewTests.neverRead.\(UUID().uuidString)"
        list = NeverReadList(defaults: UserDefaults(suiteName: suite)!)
    }

    override func tearDown() {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }

    func testTheListStoresNamesAndBundleIDsOnly() throws {
        list.add(name: madeUp.name, bundleID: madeUp.bundleID)
        list.add(name: madeUp.name, bundleID: madeUp.bundleID)  // twice: one entry
        let raw = try XCTUnwrap(list.defaults.data(forKey: NeverReadList.key))
        let stored = try XCTUnwrap(JSONSerialization.jsonObject(with: raw) as? [[String: String]])
        XCTAssertEqual(stored, [["name": madeUp.name, "bundleID": madeUp.bundleID]])
        XCTAssertEqual(list.defaults.dictionaryRepresentation().keys.filter { $0 == NeverReadList.key }.count, 1)
    }

    /// R1: a whole-display picture leaves out Phew, every app on the Never read list, and the password managers and
    /// terminals of the Never list, wherever their windows lie; the app Phew was called on stays, as in a window picture.
    func testTheWholeDisplayPictureLeavesOutListedAppsPasswordManagersAndTerminals() {
        list.add(name: madeUp.name, bundleID: madeUp.bundleID)
        let front: pid_t = 501
        func hides(_ pid: pid_t, _ bundleID: String?) -> Bool { ScreenCapture.hides(pid: pid, bundleID: bundleID, front: front, list: list) }
        XCTAssertTrue(hides(getpid(), "com.example.anything"), "Phew's own windows")
        XCTAssertTrue(hides(600, madeUp.bundleID), "on the Never read list")
        for bundleID in NeverList.passwordApps.union(NeverList.terminals) { XCTAssertTrue(hides(601, bundleID), bundleID) }
        XCTAssertTrue(NeverList.passwordApps.isSubset(of: NeverList.apps) && NeverList.terminals.isSubset(of: NeverList.apps),
                      "one list, never two")
        XCTAssertTrue(NeverList.passwordApps.contains("com.1password.1password") && NeverList.terminals.contains("com.apple.Terminal"))
        XCTAssertFalse(hides(602, "com.apple.Safari"))
        XCTAssertFalse(hides(603, nil))
        XCTAssertFalse(hides(front, "com.apple.Terminal"), "the app Phew was called on")
    }

    /// The real gate: Senses.capture on a listed app reads nothing and gives back only its name and bundle id.
    func testCaptureOfAListedAppReadsNothing() async throws {
        let app = NSRunningApplication.current  // the test host stands in for the made-up app
        let bundleID = try XCTUnwrap(app.bundleIdentifier)
        list.add(name: madeUp.name, bundleID: bundleID)
        let captured = await Senses.capture(app: app, list: list).value
        let packet = try XCTUnwrap(captured)
        XCTAssertTrue(packet.neverRead)
        XCTAssertEqual(packet.bundleID, bundleID)
        XCTAssertEqual(packet.windowTitle, "")
        XCTAssertEqual(packet.visibleText, "")
        XCTAssertNil(packet.cursor)
        XCTAssertTrue(packet.pointables.isEmpty)
        XCTAssertNil(packet.screenshot)
        XCTAssertNil(packet.screenshotFrame)
        XCTAssertNil(packet.mouse)
        XCTAssertNil(packet.documentPath)
    }

    func testACallOnAListedAppSendsNoScreenTextAndNoPicture() async throws {
        list.add(name: madeUp.name, bundleID: madeUp.bundleID)
        let packet = try XCTUnwrap(list.packet(appName: madeUp.name, bundleID: madeUp.bundleID))
        let fake = BrainAgentsTests.FakeProvider([
            "conductor": [#"{"route":"explain"}"#],
            "guide": [#"{"explanation":"Okay.","steps":[]}"#],
        ])
        for try await _ in ClaudeBrain(provider: fake).answer("What is this?", packet: packet) {}
        XCTAssertFalse(fake.requests.isEmpty)
        for request in fake.requests {
            XCTAssertNil(request.image, request.agent)
            XCTAssertFalse(request.text.contains("Under the mouse pointer"), request.agent)
            XCTAssertFalse(request.text.contains("Elements you can point at"), request.agent)
        }
        let guide = try XCTUnwrap(fake.requests.first { $0.agent == "guide" })
        XCTAssertTrue(guide.text.contains("Screenshot: none.\nVisible text:\n(none)"))
        XCTAssertTrue(guide.text.contains("Window: \n"))
    }

    // MARK: D9 (F2): never read by default

    /// Keychain Access and the password managers are never read with nothing on the user's list; any other app is.
    func testPasswordManagersAreNeverReadByDefault() {
        XCTAssertTrue(list.apps.isEmpty)
        for bundleID in ["com.apple.keychainaccess", "com.apple.Passwords", "com.1password.1password"] {
            XCTAssertTrue(list.refuses(bundleID), bundleID)
            XCTAssertEqual(list.packet(appName: "Made Up", bundleID: bundleID)?.neverRead, true, "the capture: text, cursor, picture")
            XCTAssertTrue(ScreenCapture.hides(pid: 700, bundleID: bundleID, front: 700, list: list), "left out even when called on")
            let watch = ScreenWatch(screen: false, list: list, front: { bundleID })
            watch.start(markFirst: true)
            XCTAssertFalse(watch.running, bundleID)
        }
        XCTAssertFalse(list.refuses("com.apple.Safari"))
        XCTAssertNil(list.packet(appName: "Safari", bundleID: "com.apple.Safari"))
        XCTAssertFalse(list.refuses("com.apple.Terminal"), "a terminal is never acted in, not never read")
        let watch = ScreenWatch(screen: false, list: list, front: { "com.apple.Safari" })
        watch.start(markFirst: true)
        XCTAssertTrue(watch.running)
        watch.stop("test")
    }

    /// The real reads of an app never read by default, with the test host standing in for a password manager:
    /// the capture (window text, cursor element, picture), the menu names and the guide's element give nothing.
    func testEveryReadOfAnAppNeverReadByDefaultGivesNothing() async throws {
        let app = NSRunningApplication.current
        let bundleID = try XCTUnwrap(app.bundleIdentifier)
        var refusing: NeverReadList = list
        refusing.always = [bundleID]
        XCTAssertTrue(refusing.apps.isEmpty, "not on the user's list")
        let captured = await Senses.capture(app: app, list: refusing).value
        let packet = try XCTUnwrap(captured)
        XCTAssertTrue(packet.neverRead)
        XCTAssertEqual(packet.visibleText, "")
        XCTAssertNil(packet.cursor)
        XCTAssertNil(packet.screenshot)
        XCTAssertEqual(MenuReader.names(pid: getpid(), list: refusing), "")
        XCTAssertNil(WindowReader.element(at: .zero, pid: getpid(), list: refusing))
        XCTAssertTrue(refusing.refuses(pid: getpid()))
        XCTAssertFalse(list.refuses(pid: getpid()), "the same app is read when not refused")
    }

    func testThePanelDoesNotListTheDefaults() {
        list.add(name: "Passwords", bundleID: "com.apple.Passwords")
        list.add(name: "Keychain Access", bundleID: "com.apple.keychainaccess")
        XCTAssertTrue(list.apps.isEmpty, "a default is never a row")
        XCTAssertTrue(NeverReadModel(list: list).apps.isEmpty)
        XCTAssertTrue(NeverReadView.help.contains("Keychain Access and password managers are always left out"))
    }

    func testTheWatchDoesNotStartOnAListedApp() {
        list.add(name: madeUp.name, bundleID: madeUp.bundleID)
        let watch = ScreenWatch(screen: false, list: list, front: { self.madeUp.bundleID })
        watch.start(markFirst: true)
        XCTAssertFalse(watch.running)
        watch.acted()  // an action in the listed app does not start it either
        XCTAssertFalse(watch.running)
        list.remove(madeUp.bundleID)
        watch.start(markFirst: true)
        XCTAssertTrue(watch.running)
        watch.stop("test")
    }

    func testRemovingTheAppMakesItReadableAgain() {
        list.add(name: madeUp.name, bundleID: madeUp.bundleID)
        list.add(name: "Other Made Up", bundleID: "com.example.other")
        XCTAssertNotNil(list.packet(appName: madeUp.name, bundleID: madeUp.bundleID))
        let model = NeverReadModel(list: list)
        model.remove(madeUp.bundleID)
        XCTAssertEqual(model.apps.map(\.bundleID), ["com.example.other"])
        XCTAssertNil(list.packet(appName: madeUp.name, bundleID: madeUp.bundleID))
        XCTAssertFalse(list.contains(madeUp.bundleID))
        XCTAssertFalse(list.contains(nil))
    }

    func testTheCardSaysSoInOneLine() {
        let note = CardModel.neverReadNote(madeUp.name)
        XCTAssertTrue(note.hasPrefix(madeUp.name))
        XCTAssertFalse(note.contains("\n"))
        let model = CardModel()
        model.note = note
        model.begin("next")
        XCTAssertNil(model.note)  // each turn says it again only if its own capture was skipped
    }

    /// The panel is a non-activating MenuPanel, and its code never activates Phew.
    func testThePanelNeverActivates() throws {
        let source = try String(contentsOf: URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().appending(path: "Phew/Shell/NeverReadPanel.swift"), encoding: .utf8)
        XCTAssertFalse(source.contains("activate("))
        XCTAssertFalse(source.contains("NSApp.activate"))
        let panel = MenuPanel()
        panel.show(title: "Never read", NeverReadView(model: NeverReadModel(list: list)))
        XCTAssertEqual(panel.panel?.styleMask.contains(.nonactivatingPanel), true)
        XCTAssertFalse(NSRunningApplication.current.isActive && panel.panel?.isKeyWindow == true)
        panel.close()
    }
}
