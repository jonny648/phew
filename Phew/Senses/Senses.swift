import AppKit

/// Senses' one entry point. Reads only when called: nothing here runs in the background. The one exception is the
/// screen watch during a guide (`ScreenWatch`), which never reads text and never calls the model.
enum Senses {
    /// Call the moment the shortcut fires, before any Phew panel appears: the panel opens under the
    /// cursor and would hide the user's element. The cursor read happens now, on the main thread;
    /// the window walk and the screenshot run in the returned task.
    /// `app` defaults to the front app; the debug self-check may name another running app.
    /// `windowOnly`: the picture is the front window whatever the mouse, never the whole display (live acting tests).
    @MainActor
    static func capture(app: NSRunningApplication? = nil, list: NeverReadList = .shared, windowOnly: Bool = false) -> Task<ContextPacket?, Never> {
        let start = Date()
        guard let app = app ?? NSWorkspace.shared.frontmostApplication else { return Task { nil } }
        let pid = app.processIdentifier, name = app.localizedName ?? "", bundleID = app.bundleIdentifier ?? "unknown"
        // Before any read: an app on the never-read list gives no window text, no cursor element and no picture.
        if let packet = list.packet(appName: name, bundleID: bundleID) {
            shellLog("capture skipped: app on the never-read list")
            return Task { packet.filtered() }
        }
        let (cursor, point) = WindowReader.elementUnderCursor(pid: pid)
        let cursorMS = ms(since: start)

        return Task.detached(priority: .userInitiated) {
            // An Electron tree was still empty 0.5 s after the first ask, and full on the next capture.
            // shortcut: one fixed 1 s wait, the first time per app process; poll until the text stops growing if too short.
            // The app is not on the Never read list (checked above), so the ask is never for one that is.
            let tree = WindowReader.askForFullTree(pid: pid)
            if tree.wait { try? await Task.sleep(for: .seconds(1)) }
            let walkStart = Date()
            let window = WindowReader.readWindow(pid: pid)
            let walkMS = ms(since: walkStart)
            // VoiceOver's flag slows the app's window animations and window managers: off again once read.
            // shortcut: the 1 s wait is only the first time per process; with the flag set back, a canvas tree
            // (Keynote) may need it each time; wait each time if a live run shows a thin tree.
            if tree.restore { WindowReader.setBack(pid: pid) }
            var packet = Senses.packet(appName: name, bundleID: bundleID, window: window, cursor: cursor, mouse: point)
            // Text and picture together, every time.
            // shortcut: screenshot pixels are not filtered (a key on screen stays visible); OCR redaction if that matters.
            if let shot = await ScreenCapture.picture(pid: pid, windowFrame: window.frame, mouse: point, windowOnly: windowOnly, list: list) {
                packet.screenshot = shot.png
                packet.screenshotFrame = shot.frame
                packet.wholeDisplay = shot.display
            }
            #if DEBUG
            packet.logStats(pointablesFound: window.pointables.count, cursorMS: cursorMS, walkMS: walkMS,
                            totalMS: ms(since: start))
            if ContextPacket.debugDump { packet.writeDebugFiles() }
            #endif
            return packet
        }
    }

    /// The packet from what was read, through the secrets filter: no screen read here, so it is unit-tested (R20).
    static func packet(appName: String, bundleID: String, window: WindowReader.Window, cursor: CursorElement?,
                       mouse point: CGPoint) -> ContextPacket {
        // Filter before trimming, so a cut cannot leave half a key behind.
        let texts = window.texts.map { WindowReader.Text(string: SecretsFilter.clean($0.string), frame: $0.frame) }
        var packet = ContextPacket(appName: appName, bundleID: bundleID, windowTitle: window.title,
                                   visibleText: ContextPacket.trim(texts, near: point), cursor: cursor,
                                   windowFrame: window.frame, pointables: ContextPacket.select(window.pointables, near: point),
                                   mouse: point, documentPath: window.documentPath)
        // The cursor element's id when it is listed: the same frame, clipped and rounded the same way.
        // shortcut: no id when the walk's limits stopped before reaching it; walk the cursor's branch first if seen.
        let cursorFrame = WindowReader.pointableFrame(cursor?.frame, clip: window.frame)
        packet.cursor?.id = packet.pointables.first { $0.frame == cursorFrame }?.id
        return packet.filtered()
    }

    private static func ms(since start: Date) -> Int { Int(Date().timeIntervalSince(start) * 1000) }
}
