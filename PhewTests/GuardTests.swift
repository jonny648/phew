import XCTest

/// R38: guards on taking the focus, checked by reading the sources, as `testOnlyHandActs` does for acting.
final class GuardTests: XCTestCase {
    /// He never activates the app. The two allowed places are the system folder window (your choice of 14 November)
    /// in MenuPanels.swift and PhewApp.swift; a third `NSApp.activate` fails here. Every panel is non-activating.
    func testOnlyTheFolderWindowActivatesAndEveryPanelIsNonActivating() throws {
        let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appending(path: "Phew")
        var activates: [String: Int] = [:], panels = 0, offenders: [String] = []
        let all = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        for case let url as URL in all where url.pathExtension == "swift" {
            let relative = String(url.path.dropFirst(root.path.count + 1))
            for (n, text) in try String(contentsOf: url, encoding: .utf8).split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let line = text.trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("//") { continue }
                if line.contains("NSApp.activate") || line.contains("NSApplication.shared.activate") { activates[relative, default: 0] += 1 }
                if line.contains("styleMask:") {
                    panels += 1
                    if !line.contains(".nonactivatingPanel") { offenders.append("\(relative):\(n + 1)") }
                }
            }
        }
        XCTAssertEqual(activates, ["Shell/MenuPanels.swift": 1, "Shell/PhewApp.swift": 1], "only the folder window may take the focus")
        XCTAssertGreaterThanOrEqual(panels, 6, "the scan found the panels")
        XCTAssertEqual(offenders, [], "every panel is non-activating")
    }
}
