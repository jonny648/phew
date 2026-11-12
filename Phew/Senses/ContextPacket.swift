import CoreGraphics
import Foundation

/// What Senses hands to the rest of Phew. Every string has passed the secrets filter.
struct ContextPacket: Codable {
    var appName: String
    var bundleID: String
    var windowTitle: String
    /// Visible text of the front window in reading order, trimmed to `textCap` keeping text nearest the cursor.
    var visibleText: String
    var cursor: CursorElement?
    /// The front window, screen points, top-left origin (Accessibility coordinates).
    var windowFrame: CGRect? = nil
    /// What Phew can point at, in reading order, at most `pointableCap`, the ones nearest the cursor kept.
    var pointables: [Pointable] = []
    /// The mouse when Phew was called, screen points, same coordinates as `windowFrame`. Never logged.
    var mouse: CGPoint? = nil
    /// PNG taken with the text on every call: the front window when the mouse is inside it, else the whole
    /// display under the mouse (`ScreenCapture.picksWindow`). Nil only without permission or on failure.
    /// Left out of the JSON to keep it small: the Brain attaches it as an image.
    var screenshot: Data? = nil
    /// Where the screenshot sits on screen, same coordinates as `windowFrame`. The screenshot is 1 pixel per
    /// point, so this origin + screenshot pixel = screen point.
    var screenshotFrame: CGRect? = nil

    private enum CodingKeys: String, CodingKey {
        case appName, bundleID, windowTitle, visibleText, cursor, windowFrame, pointables, mouse, screenshotFrame
    }

    static let textCap = 4000
    static let pointableCap = 80
    static let labelCap = 60

    /// Runs the secrets filter over every string. The last step before a packet leaves Senses.
    func filtered() -> ContextPacket {
        var p = self
        p.appName = SecretsFilter.clean(appName)
        p.bundleID = SecretsFilter.clean(bundleID)
        p.windowTitle = SecretsFilter.clean(windowTitle)
        p.visibleText = SecretsFilter.clean(visibleText)
        p.cursor?.label = SecretsFilter.clean(cursor?.label ?? "")
        p.cursor?.value = SecretsFilter.clean(cursor?.value ?? "")
        for i in p.pointables.indices { p.pointables[i].label = SecretsFilter.clean(p.pointables[i].label) }
        return p
    }

    /// Keeps the texts nearest `point` until `cap` characters are used, then restores reading order.
    static func trim(_ texts: [WindowReader.Text], near point: CGPoint, cap: Int = textCap) -> String {
        func distance(_ f: CGRect?) -> CGFloat { WindowReader.distance(f, point) }
        let nearestFirst = texts.indices.sorted { (distance(texts[$0].frame), $0) < (distance(texts[$1].frame), $1) }
        var kept: [Int: Substring] = [:]
        var room = cap
        for i in nearestFirst where room > 0 {
            kept[i] = texts[i].string.prefix(room)
            room -= kept[i]!.count + 1  // + the line break
        }
        return texts.indices.compactMap { kept[$0] }.joined(separator: "\n")
    }

    /// One of each element (same role, label and frame), the `cap` nearest `point`, back in reading order,
    /// numbered e1, e2… Labels become one line, filtered before they are cut, so a cut cannot leave half a key behind.
    static func select(_ found: [Pointable], near point: CGPoint, cap: Int = pointableCap) -> [Pointable] {
        var seen: Set<String> = []
        let unique = found.map { p in
            var p = p
            p.label = String(SecretsFilter.clean(p.label).split(whereSeparator: \.isNewline).joined(separator: " ").prefix(labelCap))
            return p
        }.filter { seen.insert("\($0.role)\n\($0.label)\n\($0.frame)").inserted }
        func distance(_ i: Int) -> CGFloat { WindowReader.distance(unique[i].frame, point) }
        let kept = unique.indices.sorted { (distance($0), $0) < (distance($1), $1) }.prefix(cap).sorted()
        return kept.enumerated().map { n, i in
            var p = unique[i]
            p.id = "e\(n + 1)"
            return p
        }
    }
}

/// The element under the mouse when Phew was called.
struct CursorElement: Codable {
    var role: String
    var label: String
    var value: String
    /// Screen points, top-left origin of the main display (Accessibility coordinates).
    var frame: CGRect?
    /// The id of this same element (same frame) in `ContextPacket.pointables`, when it is listed there.
    var id: String? = nil
}

/// An element Phew can point at: a button, link, field, tab… The Guide cites it by `id`.
struct Pointable: Codable, Equatable {
    /// Short and stable within one packet: e1, e2… in reading order.
    var id = ""
    var role: String
    /// Title or description; for a field its placeholder, for a pop-up its chosen item. Empty for a secure field.
    var label: String
    /// Screen points, top-left origin (Accessibility coordinates), clipped to the window.
    var frame: CGRect
}

#if DEBUG
extension ContextPacket {
    /// `--debug-dump`, or `--debug-capture` which implies it. Without it no capture touches the disk (hard rule).
    static let debugDump = CommandLine.arguments.contains { $0 == "--debug-dump" || $0 == "--debug-capture" }

    /// Counts and timings only, never captured text: safe in the log.
    func logStats(pointablesFound: Int, cursorMS: Int, walkMS: Int, totalMS: Int) {
        let shot = screenshotFrame.map { "\(Int($0.width))×\(Int($0.height)) points" }
        shellLog("packet: title \(windowTitle.count) chars, text \(visibleText.count) chars, pointables \(pointables.count) of \(pointablesFound) found, cursor \(cursor?.role ?? "none") inside its frame \(mouse.map { cursor?.frame?.contains($0) ?? false } ?? false), cursor listed \(cursor?.id != nil), cursor text \((cursor?.label.count ?? 0) + (cursor?.value.count ?? 0)) chars, screenshot \(shot ?? "none"), cursor read \(cursorMS) ms, window walk \(walkMS) ms, total \(totalMS) ms")
    }

    /// Debug evidence only, with `debugDump`: the latest packet per app in ~/Library/Application Support/Phew/debug.
    /// Never shown.
    func writeDebugFiles() {
        let dir = URL.applicationSupportDirectory.appending(path: "Phew/debug")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try? encoder.encode(self).write(to: dir.appending(path: "packet-\(bundleID).json"))
        let shot = dir.appending(path: "shot-\(bundleID).png")
        if let screenshot { try? screenshot.write(to: shot) } else { try? FileManager.default.removeItem(at: shot) }
    }
}
#endif
