import AppKit

/// Senses' one entry point. Reads only when called: nothing here runs in the background. The one exception is the
/// screen watch during a guide (`ScreenWatch`), which never reads text and never calls the model.
enum Senses {
    /// Call the moment the shortcut fires, before any Phew panel appears: the panel opens under the
    /// cursor and would hide the user's element. The cursor read happens now, on the main thread;
    /// the window walk and the screenshot run in the returned task.
    /// `app` defaults to the front app; the debug self-check may name another running app.
    @MainActor
    static func capture(app: NSRunningApplication? = nil) -> Task<ContextPacket?, Never> {
        let start = Date()
        guard let app = app ?? NSWorkspace.shared.frontmostApplication else { return Task { nil } }
        let pid = app.processIdentifier, name = app.localizedName ?? "", bundleID = app.bundleIdentifier ?? "unknown"
        let (cursor, point) = WindowReader.elementUnderCursor(pid: pid)
        let cursorMS = ms(since: start)

        return Task.detached(priority: .userInitiated) {
            // An Electron tree was still empty 0.5 s after the first ask, and full on the next capture.
            // shortcut: one fixed 1 s wait, the first time per app process; poll until the text stops growing if too short.
            if WindowReader.askForFullTree(pid: pid) { try? await Task.sleep(for: .seconds(1)) }
            let walkStart = Date()
            let window = WindowReader.readWindow(pid: pid)
            let walkMS = ms(since: walkStart)
            // Filter before trimming, so a cut cannot leave half a key behind.
            let texts = window.texts.map { WindowReader.Text(string: SecretsFilter.clean($0.string), frame: $0.frame) }
            var packet = ContextPacket(appName: name, bundleID: bundleID, windowTitle: window.title,
                                       visibleText: ContextPacket.trim(texts, near: point), cursor: cursor,
                                       windowFrame: window.frame, pointables: ContextPacket.select(window.pointables, near: point),
                                       mouse: point, documentPath: window.documentPath)
            // The cursor element's id when it is listed: the same frame, clipped and rounded the same way.
            // shortcut: no id when the walk's limits stopped before reaching it; walk the cursor's branch first if seen.
            let cursorFrame = WindowReader.pointableFrame(cursor?.frame, clip: window.frame)
            packet.cursor?.id = packet.pointables.first { $0.frame == cursorFrame }?.id
            packet = packet.filtered()
            // Text and picture together, every time.
            // shortcut: screenshot pixels are not filtered (a key on screen stays visible); OCR redaction if that matters.
            if let shot = await ScreenCapture.picture(pid: pid, windowFrame: window.frame, mouse: point) {
                packet.screenshot = shot.png
                packet.screenshotFrame = shot.frame
            }
            #if DEBUG
            packet.logStats(pointablesFound: window.pointables.count, cursorMS: cursorMS, walkMS: walkMS,
                            totalMS: ms(since: start))
            if ContextPacket.debugDump { packet.writeDebugFiles() }
            #endif
            return packet
        }
    }

    private static func ms(since start: Date) -> Int { Int(Date().timeIntervalSince(start) * 1000) }
}
