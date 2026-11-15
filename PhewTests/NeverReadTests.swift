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
            "guide": [#"{"explanation":"ok","steps":[]}"#],
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
