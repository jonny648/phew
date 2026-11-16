import XCTest
@testable import Phew

final class SensesRulesTests: XCTestCase {
    /// R44: at launch without the dump flag, an earlier run's debug files are deleted; with it they stay.
    func testDebugFilesAreDeletedAtLaunchWithoutTheFlag() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "phew-debug-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("made-up".utf8).write(to: folder.appending(path: "packet-com.example.made-up.json"))
        ContextPacket.sweepDebugFiles(arguments: ["Phew", "--debug-dump"], folder: folder)
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path), "kept while the test runs")
        ContextPacket.sweepDebugFiles(arguments: ["Phew"], folder: folder)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
    }

    func testPictureIsTheWindowOnlyWhenTheMouseIsInsideIt() {
        let window = CGRect(x: 100, y: 50, width: 800, height: 600)
        XCTAssertTrue(ScreenCapture.picksWindow(mouse: CGPoint(x: 400, y: 300), windowFrame: window))
        XCTAssertTrue(ScreenCapture.picksWindow(mouse: CGPoint(x: 100, y: 50), windowFrame: window))  // top-left corner
        XCTAssertFalse(ScreenCapture.picksWindow(mouse: CGPoint(x: 1200, y: 300), windowFrame: window))  // desktop
        XCTAssertFalse(ScreenCapture.picksWindow(mouse: CGPoint(x: 400, y: 10), windowFrame: window))  // menu bar
        XCTAssertFalse(ScreenCapture.picksWindow(mouse: CGPoint(x: 400, y: 880), windowFrame: window))  // Dock
        XCTAssertFalse(ScreenCapture.picksWindow(mouse: CGPoint(x: 400, y: 300), windowFrame: nil))  // no window found
    }

    func testImageDataIsDropped() {
        let notion = "/7ImToAAAAAGSURBVAMA6fsjUHFG33gAAAAASUVORK5CYII="  // seen in Notion's tree
        XCTAssertEqual(WindowReader.removeJunk(notion), "")
        XCTAssertEqual(WindowReader.removeJunk("Logo \(notion) below"), "Logo  below")
        let dataURI = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
        XCTAssertEqual(WindowReader.removeJunk("img \(dataURI)"), "img ")
    }

    private func pointable(_ label: String, x: CGFloat, role: String = "AXButton") -> Pointable {
        Pointable(role: role, label: label, frame: CGRect(x: x, y: 0, width: 20, height: 20))
    }

    func testPointablesKeepNearestThenReadingOrder() {
        let found = [pointable("Far", x: 900), pointable("Near", x: 100), pointable("Middle", x: 400), pointable("Nearest", x: 0)]
        let kept = ContextPacket.select(found, near: CGPoint(x: 5, y: 5), cap: 2)
        XCTAssertEqual(kept.map(\.label), ["Near", "Nearest"])  // the two nearest, in reading order
        XCTAssertEqual(kept.map(\.id), ["e1", "e2"])
        XCTAssertEqual(ContextPacket.select(found, near: .zero).map(\.label), ["Far", "Near", "Middle", "Nearest"])
    }

    func testPointablesDropDuplicates() {
        let found = [pointable("Share", x: 0), pointable("Share", x: 0), pointable("Share", x: 50),
                     pointable("Share", x: 0, role: "AXLink")]
        let kept = ContextPacket.select(found, near: .zero)
        XCTAssertEqual(kept.map(\.id), ["e1", "e2", "e3"])  // same role, label and frame once; any difference stays
        XCTAssertEqual(kept.map(\.frame.minX), [0, 50, 0])
    }

    func testPointableLabelsAreOneShortLine() {
        let kept = ContextPacket.select([pointable("Add\nnew page " + String(repeating: "x", count: 100), x: 0)], near: .zero)
        XCTAssertEqual(kept[0].label.count, ContextPacket.labelCap)
        XCTAssertTrue(kept[0].label.hasPrefix("Add new page x"))
    }

    func testPointableFrameIsClippedRoundedAndNotASliver() {
        let window = CGRect(x: 0, y: 30, width: 500, height: 400)
        XCTAssertEqual(WindowReader.pointableFrame(CGRect(x: 10.5, y: 20, width: 20, height: 30), clip: window),
                       CGRect(x: 10, y: 30, width: 21, height: 20))
        XCTAssertNil(WindowReader.pointableFrame(CGRect(x: 10, y: 157, width: 220, height: 1), clip: window))  // scrolled out
        XCTAssertNil(WindowReader.pointableFrame(CGRect(x: 600, y: 40, width: 20, height: 20), clip: window))  // outside
        XCTAssertNil(WindowReader.pointableFrame(nil, clip: window))
    }

    func testCapturesStayOffDiskWithoutTheFlag() {
        XCTAssertFalse(ContextPacket.debugDump)  // the test host runs without --debug-dump
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

    func testDocumentPathFromFileURL() {
        let url = "file:///Users/someone/Made%20Up/notes.txt" as CFString
        XCTAssertEqual(WindowReader.documentPath(url), "/Users/someone/Made Up/notes.txt")
        XCTAssertEqual(WindowReader.documentPath(URL(fileURLWithPath: "/tmp/made-up.pdf") as CFURL), "/tmp/made-up.pdf")
        XCTAssertEqual(WindowReader.documentPath("/tmp/plain.md" as CFString), "/tmp/plain.md")
    }

    func testWebAddressLosesQueryFragmentAndLogin() {
        func path(_ s: String) -> String? { WindowReader.documentPath(s as CFString) }
        XCTAssertEqual(path("https://example.com/docs/page?id=7&q=secret#part"), "https://example.com/docs/page")
        XCTAssertEqual(path("https://example.com/a#top"), "https://example.com/a")
        XCTAssertEqual(path("http://user:pass@example.com/b?x=1"), "http://example.com/b")
        XCTAssertEqual(WindowReader.documentPath(URL(string: "https://example.org/x?y=1")! as CFURL), "https://example.org/x")
    }

    func testNoDocumentPathStaysNil() {
        XCTAssertNil(WindowReader.documentPath(nil))
        XCTAssertNil(WindowReader.documentPath("" as CFString))
        XCTAssertNil(WindowReader.documentPath("about:blank" as CFString))
        XCTAssertNil(WindowReader.documentPath(42 as CFNumber))
        // An Electron app's own page is not the user's document.
        XCTAssertNil(WindowReader.documentPath("file:///Applications/Made%20Up.app/Contents/Resources/index.html" as CFString))
        let packet = ContextPacket(appName: "App", bundleID: "id", windowTitle: "t", visibleText: "", cursor: nil).filtered()
        XCTAssertNil(packet.documentPath)
    }
}
