import XCTest
@testable import Phew

/// N2.6 and N2.7 without a real app: the menu names from a made-up menu bar, and the choice of which flag asks an app
/// for its full tree, through a fake. No test here reads a running app's menus or sets a flag on one.
final class MenuAndTreeTests: XCTestCase {
    typealias Node = MenuReader.Node

    private func menu(_ title: String, _ items: [Node], enabled: Bool = true) -> Node { Node(title: title, enabled: enabled, children: items) }
    private func item(_ title: String, enabled: Bool = true, _ sub: [Node] = []) -> Node { Node(title: title, enabled: enabled, children: sub) }

    /// A made-up app's menu bar: the Apple menu first, then its own menus, recent files, a window list, a history.
    private var bar: [Node] {
        [
            menu("Apple", [item("About This Mac"), item("System Settings…")]),
            menu("Practice", [item("About Practice"), item("Services", [item("Made-up Service")]), item("Quit Practice")]),
            menu("File", [item("New"), item("Open…"),
                          item("Open Recent", [item("made-up-plan.txt"), item("Clear Menu")]),
                          item("Apri recenti", [item("progetto-finto.txt")]),
                          item("Save", enabled: false), item(""), item("Export…")]),
            menu("Format", [item("Font", [item("Bold"), item("Italic"), item("Underline", enabled: false)]),
                            item("Show History"), item("Text", enabled: false, [item("Align Left")])]),
            menu("History", [item("Made-up page one"), item("Made-up page two")]),
            menu("Cronologia", [item("Pagina finta")]),
            menu("Bookmarks", [item("Made-up bookmark")]),
            menu("Profiles", [item("Made-up Person")]),
            menu("Window", [item("Minimize"), item("Made-up document.txt")]),
            menu("Finestra", [item("Documento finto.txt")]),
            menu("Help", [item("Practice Help")]),
            menu("Disabled", [item("Never shown")], enabled: false),
        ]
    }

    func testNamesOnlyWithoutPrivateMenus() {
        let names = MenuReader.names(bar)
        XCTAssertEqual(names, """
            Practice: About Practice | Quit Practice
            File: New | Open… | Export…
            Format: Font > [Bold | Italic] | Show History
            Help: Practice Help
            """)
        for left in ["Apple", "About This Mac", "made-up-plan", "progetto-finto", "Made-up page", "Pagina finta", "Made-up bookmark",
                     "Made-up Person", "Made-up document", "Documento finto", "Minimize", "Made-up Service", "Save",
                     "Underline", "Align Left", "Never shown"] {
            XCTAssertFalse(names.contains(left), left)
        }
    }

    func testCapIsHardAndCutsAtALineEnd() {
        let many = (1...200).map { n in menu("Menu \(n)", (1...10).map { item("Made-up command \(n).\($0)") }) }
        let names = MenuReader.names([menu("Apple", [])] + many)
        XCTAssertLessThanOrEqual(names.count, MenuReader.cap)
        XCTAssertTrue(names.hasPrefix("Menu 1: Made-up command 1.1"))
        XCTAssertTrue(names.hasSuffix(".10"), "whole lines only")
        XCTAssertLessThanOrEqual(MenuReader.names([menu("Apple", []), menu("Long", [item(String(repeating: "x", count: 500))])], cap: 20).count, 20)
        // One title is cut to a label's length.
        XCTAssertEqual(MenuReader.names([menu("Apple", []), menu("A", [item(String(repeating: "y", count: 500))])]),
                       "A: " + String(repeating: "y", count: ContextPacket.labelCap))
    }

    func testSecretsAreFiltered() {
        let key = "sk-ant-" + String(repeating: "a1B2", count: 8)
        let names = MenuReader.names([menu("Apple", []), menu("Edit", [item("Paste \(key)"), item("Copy")])])
        XCTAssertFalse(names.contains(key))
        XCTAssertTrue(names.contains(SecretsFilter.keyMarker))
        var packet = ContextPacket(appName: "Practice", bundleID: "com.example.practice", windowTitle: "", visibleText: "", cursor: nil)
        packet.menus = "Edit: Paste \(key)"
        XCTAssertFalse(packet.filtered().menus.contains(key))
        XCTAssertFalse(String(decoding: try! JSONEncoder().encode(packet), as: UTF8.self).contains("Paste"), "not in the JSON")
    }

    func testPrivateMenuWords() {
        for title in ["Open Recent", "Apri recenti", "Recent Projects", "History", "Cronologia", "Bookmarks", "Segnalibri",
                      "Favorites", "Preferiti", "Profiles", "People", "Window", "Finestra", "Services", "Servizi"] {
            XCTAssertTrue(MenuReader.isPrivate(title), title)
        }
        for title in ["File", "Format", "New Window", "View", "Edit", "Font"] { XCTAssertFalse(MenuReader.isPrivate(title), title) }
    }

    // MARK: - N2.7: which flag, for which app, set back or not

    /// A made-up app's flags: what it accepts, what it reports, and every set in order.
    private final class Flags {
        var acceptsManual = false
        var enhanced: Bool?
        /// Keynote's case: the set reports a failure yet takes the value.
        var takesEnhancedSilently = false
        var sets: [String] = []
        var flags: WindowReader.TreeFlags {
            WindowReader.TreeFlags(set: { [self] name, on in
                sets.append("\(name)=\(on)")
                if name == WindowReader.manual { return acceptsManual }
                if enhanced != nil { enhanced = on }
                return !takesEnhancedSilently && enhanced != nil
            }, get: { [self] name in name == WindowReader.enhanced ? enhanced : nil })
        }
    }

    func testChromiumAndElectronGetTheManualFlagOnlyAndNoRestore() {
        let app = Flags()
        app.acceptsManual = true
        app.enhanced = false
        XCTAssertTrue(WindowReader.askForFullTree(app.flags, neverRead: false) == (true, false))
        XCTAssertEqual(app.sets, ["AXManualAccessibility=true"], "the enhanced flag is never touched")
    }

    func testEnhancedOnlyWhereManualIsRefusedAndOffAndThenSetBack() {
        let keynote = Flags()
        keynote.enhanced = false
        keynote.takesEnhancedSilently = true
        XCTAssertTrue(WindowReader.askForFullTree(keynote.flags, neverRead: false) == (true, true))
        XCTAssertEqual(keynote.sets, ["AXManualAccessibility=true", "AXEnhancedUserInterface=true"])
        // Already on (VoiceOver): not Phew's, never set back.
        let voiceOver = Flags()
        voiceOver.enhanced = true
        XCTAssertTrue(WindowReader.askForFullTree(voiceOver.flags, neverRead: false) == (false, false))
        XCTAssertEqual(voiceOver.sets, ["AXManualAccessibility=true"])
        // No such flag at all (a plain native app): nothing set, nothing to set back.
        let native = Flags()
        XCTAssertTrue(WindowReader.askForFullTree(native.flags, neverRead: false) == (false, false))
        XCTAssertEqual(native.sets, ["AXManualAccessibility=true"])
    }

    func testNeverReadAppGetsNoFlag() {
        let app = Flags()
        app.acceptsManual = true
        app.enhanced = false
        XCTAssertTrue(WindowReader.askForFullTree(app.flags, neverRead: true) == (false, false))
        XCTAssertEqual(app.sets, [])
    }
}
