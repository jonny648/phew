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
    /// PNG of the front window, only when the app exposes too little text.
    /// Left out of the JSON to keep it small: the Brain attaches it as an image.
    var screenshot: Data? = nil

    private enum CodingKeys: String, CodingKey { case appName, bundleID, windowTitle, visibleText, cursor }

    static let textCap = 4000
    /// Below this many characters of visible text the app exposes too little: a screenshot is added.
    static let screenshotBelow = 300

    /// The one screenshot rule: the app exposes too little text, or nothing about the element under the cursor
    /// (a canvas in Figma or Keynote, whose menus and panels alone pass the threshold).
    var needsScreenshot: Bool {
        visibleText.count < Self.screenshotBelow || ((cursor?.label ?? "").isEmpty && (cursor?.value ?? "").isEmpty)
    }

    /// Runs the secrets filter over every string. The last step before a packet leaves Senses.
    func filtered() -> ContextPacket {
        var p = self
        p.appName = SecretsFilter.clean(appName)
        p.bundleID = SecretsFilter.clean(bundleID)
        p.windowTitle = SecretsFilter.clean(windowTitle)
        p.visibleText = SecretsFilter.clean(visibleText)
        p.cursor?.label = SecretsFilter.clean(cursor?.label ?? "")
        p.cursor?.value = SecretsFilter.clean(cursor?.value ?? "")
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
}

/// The element under the mouse when Phew was called.
struct CursorElement: Codable {
    var role: String
    var label: String
    var value: String
    /// Screen points, top-left origin of the main display (Accessibility coordinates).
    var frame: CGRect?
}

#if DEBUG
extension ContextPacket {
    /// Debug evidence only: the latest packet per app in ~/Library/Application Support/Phew/debug. Never shown.
    func writeDebugFiles(mouse: CGPoint, cursorMS: Int, totalMS: Int) {
        let dir = URL.applicationSupportDirectory.appending(path: "Phew/debug")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try? encoder.encode(self).write(to: dir.appending(path: "packet-\(bundleID).json"))
        let shot = dir.appending(path: "shot-\(bundleID).png")
        if let screenshot { try? screenshot.write(to: shot) } else { try? FileManager.default.removeItem(at: shot) }
        shellLog("packet \(bundleID): title \(windowTitle.count) chars, text \(visibleText.count) chars, cursor \(cursor?.role ?? "none") at \(Int(mouse.x)),\(Int(mouse.y)) inside its frame \(cursor?.frame?.contains(mouse) ?? false), cursor text \((cursor?.label.count ?? 0) + (cursor?.value.count ?? 0)) chars, rule wants screenshot \(needsScreenshot), screenshot \(screenshot != nil), cursor read \(cursorMS) ms, total \(totalMS) ms")
    }
}
#endif
