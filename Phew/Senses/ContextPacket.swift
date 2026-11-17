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
    /// The screenshot is the whole display, not cut to a window: the Brain sends it smaller (A3,
    /// `ScreenshotSize.sent`). Its pixels and `screenshotFrame` stay as captured.
    var wholeDisplay = false
    /// The captured pixels behind `screenshot`, full size: a guide look cuts from them without decoding the PNG
    /// (R58). A window's are at the screen's full sharpness (R9), for `sharpCrop`. Memory only, gone with the packet;
    /// never sent or written as they are.
    var image: CGImage? = nil
    /// R10: the window text read but not in `visibleText`, in reading order, up to `readCap` with it. Filtered like it.
    /// The Guide's `read_more` sends it in pieces. Memory only, gone with the packet, left out of the JSON.
    var moreText = ""
    /// The open document's file path or page address, when the app gives one (`WindowReader.documentPath`).
    /// A label for project detection (docs/05-map.md 5.11), not capture: the Map may keep it.
    var documentPath: String? = nil
    /// The app is on the user's "Never read this app" list (`NeverReadList`): nothing of its screen was read, and
    /// every field but the app's name and bundle id is empty.
    var neverRead = false
    /// The app's menu bar commands (`MenuReader`), read once per job and per app on the act route; empty otherwise.
    /// App labels, but they live and go with the capture, and are left out of the JSON like the screenshot.
    var menus = ""

    private enum CodingKeys: String, CodingKey {
        case appName, bundleID, windowTitle, documentPath, visibleText, cursor, windowFrame, pointables, mouse, screenshotFrame
    }

    static let textCap = 4000
    /// R10: the most window text read, nearest the cursor first; `textCap` of it is sent, the rest only by `read_more`.
    static let readCap = 20000
    static let pointableCap = 80
    static let labelCap = 60
    /// R9: the most the sharp crop covers, in points, and never more than the window. N4.3: was 800 by 600 (about
    /// 2,500 tokens at 2 pixels per point, half a cent on the main model); 560 by 420 is about 1,200.
    static let cropCap = CGSize(width: 560, height: 420)

    /// R9: a close-up around the element under the mouse (around the mouse when there is none, or when the element is
    /// larger than `cropCap`), cut from the captured pixels at the screen's full sharpness. Only for a window picture
    /// with the mouse inside it, captured sharper than the PNG; nil otherwise, and for an app never read. In memory only.
    func sharpCrop() -> Data? {
        guard !neverRead, !wholeDisplay, let image, let frame = screenshotFrame, let mouse, frame.contains(mouse),
              CGFloat(image.width) > frame.width, let rect = Self.cropRect(frame: frame, mouse: mouse, element: cursor?.frame)
        else { return nil }
        return ScreenshotSize.cut(image, points: frame.width, rect: rect, sharp: true)
    }

    /// The crop in points from the picture's top-left: `cropCap` or the picture if smaller, centred on the element's
    /// middle when it fits within the cap, else on the mouse, and kept inside the picture.
    static func cropRect(frame: CGRect, mouse: CGPoint, element: CGRect?) -> CGRect? {
        let (w, h) = (min(cropCap.width, frame.width).rounded(.down), min(cropCap.height, frame.height).rounded(.down))
        guard w >= 1, h >= 1 else { return nil }
        var centre = mouse
        if let e = element, e.width <= w, e.height <= h, frame.contains(CGPoint(x: e.midX, y: e.midY)) {
            centre = CGPoint(x: e.midX, y: e.midY)
        }
        let x = min(max((centre.x - frame.minX - w / 2).rounded(), 0), frame.width - w)
        let y = min(max((centre.y - frame.minY - h / 2).rounded(), 0), frame.height - h)
        return CGRect(x: x, y: y, width: w, height: h)
    }

    /// N4.4: the labels of the controls one can point at, as the guide's code check compares them, kept in memory
    /// while the guide runs. Nil when the list was cut at `pointableCap`, so a control missing from it may still have
    /// been on screen, or for an app never read.
    var controlLabels: Set<String>? {
        neverRead || pointables.count >= Self.pointableCap ? nil : Set(pointables.map { Self.controlLabel($0.label) })
    }

    static func controlLabel(_ label: String) -> String { label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

    /// Where a guide step points, in screen points, top-left origin: an element's frame, or a zero-size rect at a
    /// screenshot point. Nil for an id not in `pointables`, or a point without a `screenshotFrame`.
    func screenRect(for target: StepTarget) -> CGRect? {
        switch target {
        case .element(let id):
            pointables.first { $0.id == id }?.frame
        case .point(let x, let y):
            screenshotFrame.map { CGRect(x: $0.minX + CGFloat(x), y: $0.minY + CGFloat(y), width: 0, height: 0) }
        }
    }

    /// Runs the secrets filter over every string. The last step before a packet leaves Senses.
    func filtered() -> ContextPacket {
        var p = self
        p.appName = SecretsFilter.clean(appName)
        p.bundleID = SecretsFilter.clean(bundleID)
        p.windowTitle = SecretsFilter.clean(windowTitle)
        p.documentPath = documentPath.map(SecretsFilter.clean)
        p.visibleText = SecretsFilter.clean(visibleText)
        p.moreText = SecretsFilter.clean(moreText)
        p.menus = SecretsFilter.clean(menus)
        p.cursor?.label = SecretsFilter.clean(cursor?.label ?? "")
        p.cursor?.value = SecretsFilter.clean(cursor?.value ?? "")
        // The field's name and value together, as the model reads them (R2): "Password" and "hunter2" apart pass.
        if let raw = cursor, let clean = p.cursor, !raw.value.isEmpty,
           SecretsFilter.clean("\(raw.label): \(raw.value)") != "\(clean.label): \(clean.value)" {
            p.cursor?.value = SecretsFilter.secretMarker
        }
        for i in p.pointables.indices { p.pointables[i].label = SecretsFilter.clean(p.pointables[i].label) }
        return p
    }

    /// Keeps the texts nearest `point` until `cap` characters are used, then restores reading order.
    static func trim(_ texts: [WindowReader.Text], near point: CGPoint, cap: Int = textCap) -> String {
        let kept = nearest(texts, near: point, cap: cap)
        return texts.indices.compactMap { kept[$0] }.joined(separator: "\n")
    }

    /// R10: what `trim` leaves out of the `read` characters nearest `point`, in reading order: the lines it dropped,
    /// and the end of the line it cut.
    static func rest(_ texts: [WindowReader.Text], near point: CGPoint, sent: Int = textCap, read: Int = readCap) -> String {
        let (all, kept) = (nearest(texts, near: point, cap: read), nearest(texts, near: point, cap: sent))
        return texts.indices.compactMap { i in
            all[i].flatMap { $0.count > (kept[i]?.count ?? 0) ? $0.dropFirst(kept[i]?.count ?? 0) : nil }
        }.joined(separator: "\n")
    }

    /// The start of each text kept, nearest `point` first, until `cap` characters are used.
    private static func nearest(_ texts: [WindowReader.Text], near point: CGPoint, cap: Int) -> [Int: Substring] {
        func distance(_ f: CGRect?) -> CGFloat { WindowReader.distance(f, point) }
        let nearestFirst = texts.indices.sorted { (distance(texts[$0].frame), $0) < (distance(texts[$1].frame), $1) }
        var kept: [Int: Substring] = [:]
        var room = cap
        for i in nearestFirst where room > 0 {
            kept[i] = texts[i].string.prefix(room)
            room -= kept[i]!.count + 1  // + the line break
        }
        return kept
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

extension ContextPacket {
    /// Where a Debug build launched with `--debug-dump` writes its evidence.
    static let debugFolder = URL.applicationSupportDirectory.appending(path: "Phew/debug")

    /// R44, in every build: at launch without the dump flag, what an earlier test run dumped is deleted.
    static func sweepDebugFiles(arguments: [String] = CommandLine.arguments, folder: URL = debugFolder) {
        guard !arguments.contains(where: { $0 == "--debug-dump" || $0 == "--debug-capture" }) else { return }
        try? FileManager.default.removeItem(at: folder)
    }
}

#if DEBUG
extension ContextPacket {
    /// `--debug-dump`, or `--debug-capture` which implies it. Without it no capture touches the disk (hard rule).
    static let debugDump = CommandLine.arguments.contains { $0 == "--debug-dump" || $0 == "--debug-capture" }

    /// Counts and timings only, never captured text: safe in the log.
    func logStats(pointablesFound: Int, cursorMS: Int, walkMS: Int, totalMS: Int) {
        let shot = screenshotFrame.map { "\(Int($0.width))×\(Int($0.height)) points" }
        let path = documentPath.map { $0.hasPrefix("/") ? "file" : "address" } ?? "none"
        shellLog("packet: title \(windowTitle.count) chars, document path \(path), text \(visibleText.count) chars, pointables \(pointables.count) of \(pointablesFound) found, cursor \(cursor?.role ?? "none") inside its frame \(mouse.map { cursor?.frame?.contains($0) ?? false } ?? false), cursor listed \(cursor?.id != nil), cursor text \((cursor?.label.count ?? 0) + (cursor?.value.count ?? 0)) chars, screenshot \(shot ?? "none"), cursor read \(cursorMS) ms, window walk \(walkMS) ms, total \(totalMS) ms")
    }

    /// Debug evidence only, with `debugDump`: the latest packet per app in ~/Library/Application Support/Phew/debug.
    /// Never shown.
    func writeDebugFiles() {
        let dir = Self.debugFolder
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try? encoder.encode(self).write(to: dir.appending(path: "packet-\(bundleID).json"))
        let shot = dir.appending(path: "shot-\(bundleID).png")
        if let screenshot { try? screenshot.write(to: shot) } else { try? FileManager.default.removeItem(at: shot) }
    }

    /// PH.10: a live acting test may send a look only at a window the test itself made, holding only made-up content.
    /// Its title carries the test's made-up marker ("Phew test " and a number), the picture is that window and nothing
    /// around it, and it lists no rows (no sidebar, no list of other notes or files). It comes from the test's own app
    /// (`app`, a bundle id), and an element under the mouse lies inside that window. Nil when the look may go;
    /// otherwise one fixed word saying why not, for the log.
    func notTestWindow(marker: String, app: String) -> String? {
        guard marker.range(of: #"^Phew test [0-9]{3,}"#, options: .regularExpression) != nil else { return "marker" }
        guard bundleID == app else { return "app" }  // the test's own app, never the one the user has in front
        if neverRead { return "neverRead" }
        guard windowTitle.contains(marker) else { return "title" }
        guard screenshot != nil, let shot = screenshotFrame, let window = windowFrame,
              abs(shot.minX - window.minX) <= 4, abs(shot.minY - window.minY) <= 4,
              abs(shot.width - window.width) <= 4, abs(shot.height - window.height) <= 4 else { return "picture" }
        if pointables.contains(where: { $0.role == "AXRow" }) { return "list" }
        // The element under the mouse rides along only from inside that window (the same app may have others open).
        if let cursor, !(cursor.frame.map { window.insetBy(dx: -4, dy: -4).contains($0) } ?? false) { return "cursor" }
        return nil
    }
}
#endif
