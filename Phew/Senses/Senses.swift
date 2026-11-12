import AppKit

/// Senses' one entry point. Reads only when called: nothing here runs in the background.
enum Senses {
    /// Call the moment the shortcut fires, before any Phew panel appears: the panel opens under the
    /// cursor and would hide the user's element. The cursor read happens now, on the main thread;
    /// the window walk and any screenshot run in the returned task.
    /// `app` defaults to the front app; the debug self-check may name another running app.
    @MainActor
    static func capture(forceScreenshot: Bool = false, app: NSRunningApplication? = nil) -> Task<ContextPacket?, Never> {
        let start = Date()
        guard let app = app ?? NSWorkspace.shared.frontmostApplication else { return Task { nil } }
        let pid = app.processIdentifier, name = app.localizedName ?? "", bundleID = app.bundleIdentifier ?? "unknown"
        let (cursor, point) = WindowReader.elementUnderCursor(pid: pid)
        let cursorMS = ms(since: start)

        return Task.detached(priority: .userInitiated) {
            // An Electron tree was still empty 0.5 s after the first ask, and full on the next capture.
            // shortcut: one fixed 1 s wait, the first time per app process; poll until the text stops growing if too short.
            if WindowReader.askForFullTree(pid: pid) { try? await Task.sleep(for: .seconds(1)) }
            let window = WindowReader.readWindow(pid: pid)
            // Filter before trimming, so a cut cannot leave half a key behind.
            let texts = window.texts.map { WindowReader.Text(string: SecretsFilter.clean($0.string), frame: $0.frame) }
            var packet = ContextPacket(appName: name, bundleID: bundleID, windowTitle: window.title,
                                       visibleText: ContextPacket.trim(texts, near: point), cursor: cursor).filtered()
            // shortcut: screenshot pixels are not filtered (a key on screen stays visible); OCR redaction if that matters.
            if forceScreenshot || packet.needsScreenshot {
                packet.screenshot = await ScreenCapture.window(pid: pid, frame: window.frame)
            }
            #if DEBUG
            packet.writeDebugFiles(mouse: point, cursorMS: cursorMS, totalMS: ms(since: start))
            #endif
            return packet
        }
    }

    private static func ms(since start: Date) -> Int { Int(Date().timeIntervalSince(start) * 1000) }
}
