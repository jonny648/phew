import AppKit
import ScreenCaptureKit

/// The picture that goes with the text on every call: the front app's window, or the whole screen under the mouse.
enum ScreenCapture {
    /// The one picture rule: the front window when the mouse is inside it; otherwise (desktop, menu bar, Dock,
    /// another app's window, no window) the whole display under the mouse.
    /// shortcut: another app's window lying over the front window still picks the front window; check the
    /// cursor element's owner if that case shows up.
    static func picksWindow(mouse: CGPoint, windowFrame: CGRect?) -> Bool {
        windowFrame?.contains(mouse) == true
    }

    /// PNG of the picture `picksWindow` chooses, and where it sits on screen (screen points, top-left origin,
    /// Accessibility coordinates). One pixel per point, so frame origin + picture pixel = screen point.
    /// Phew's own windows are left out. Nil without Screen Recording permission or on failure.
    /// `windowOnly` (live acting tests, PH.10): the front window wherever the mouse is, and never the whole display.
    /// `display`: the picture is the whole display, which the Brain sends smaller (A3); captured at full size here.
    static func picture(pid: pid_t, windowFrame: CGRect?, mouse: CGPoint, windowOnly: Bool = false,
                        list: NeverReadList = .shared) async -> (png: Data, frame: CGRect, display: Bool)? {
        guard CGPreflightScreenCaptureAccess() else { return nil }
        do {
            // Off-screen windows too: Phew's panel or card, still being ordered in, must be listed to be left out.
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
            let filter: SCContentFilter, origin: CGPoint, whole: Bool
            // SCWindow frames use the same top-left origin as Accessibility.
            if windowOnly || picksWindow(mouse: mouse, windowFrame: windowFrame), let frame = windowFrame,
               // windowOnly: also on another Space, as a test's window is while the user works in a full-screen app.
               let window = content.windows.filter({ ($0.isOnScreen || windowOnly) && $0.owningApplication?.processID == pid && $0.windowLayer == 0 })
                   .min(by: { gap($0.frame, frame) < gap($1.frame, frame) }) {
                filter = SCContentFilter(desktopIndependentWindow: window)  // that window only, nothing on top
                origin = window.frame.origin
                whole = false
            } else if windowOnly {
                return nil
            } else {
                var id: CGDirectDisplayID = 0, count: UInt32 = 0
                CGGetDisplaysWithPoint(mouse, 1, &id, &count)  // global display coordinates: top-left origin too
                guard let display = content.displays.first(where: { $0.displayID == id }) ?? content.displays.first
                else { return nil }
                // Wallpaper, menu bar and Dock included; every window of Phew left out.
                let hidden = content.applications.filter { hides(pid: $0.processID, bundleID: $0.bundleIdentifier, front: pid, list: list) }
                filter = SCContentFilter(display: display, excludingApplications: hidden, exceptingWindows: [])
                origin = CGDisplayBounds(display.displayID).origin
                whole = true
            }
            // shortcut: 1 pixel per point halves Retina detail; capture at 2x if small text is misread.
            let config = SCStreamConfiguration()
            config.width = Int(filter.contentRect.width)
            config.height = Int(filter.contentRect.height)
            config.showsCursor = false
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return nil }
            return (png, CGRect(origin: origin, size: filter.contentRect.size), whole)
        } catch {
            shellLog("screenshot failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Whether a whole-display picture leaves out the app `pid` (`bundleID`), when Phew was called on `front` (R1):
    /// Phew, every app on the Never read list, and the Never list's password managers and terminals, wherever their
    /// windows lie. Not the app Phew was called on: its window picture shows it too.
    static func hides(pid: pid_t, bundleID: String?, front: pid_t, list: NeverReadList) -> Bool {
        if pid == getpid() || list.contains(bundleID) { return true }
        guard pid != front, let bundleID else { return false }
        return NeverList.passwordApps.contains(bundleID) || NeverList.terminals.contains(bundleID)
    }

    private static func gap(_ a: CGRect, _ b: CGRect) -> CGFloat {
        abs(a.minX - b.minX) + abs(a.minY - b.minY) + abs(a.width - b.width) + abs(a.height - b.height)
    }
}
