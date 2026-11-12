import AppKit
import ScreenCaptureKit

/// Screenshot of one window of the front app, for when Accessibility exposes too little.
enum ScreenCapture {
    /// PNG of the app's window that matches `frame` (the focused window, Accessibility coordinates).
    /// One pixel per point, to keep it small. Nil without Screen Recording permission or on failure.
    static func window(pid: pid_t, frame: CGRect?) async -> Data? {
        guard CGPreflightScreenCaptureAccess() else { return nil }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            let windows = content.windows.filter { $0.owningApplication?.processID == pid && $0.windowLayer == 0 }
            // SCWindow frames use the same top-left origin as Accessibility.
            let match = frame.map { f in windows.min { gap($0.frame, f) < gap($1.frame, f) } }
                ?? windows.max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
            guard let window = match else { return nil }

            let filter = SCContentFilter(desktopIndependentWindow: window)  // that window only, nothing on top
            // shortcut: 1 pixel per point halves Retina detail; capture at 2x if small text is misread.
            let config = SCStreamConfiguration()
            config.width = Int(filter.contentRect.width)
            config.height = Int(filter.contentRect.height)
            config.showsCursor = false
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        } catch {
            shellLog("screenshot failed: \(error.localizedDescription)")
            return nil
        }
    }

    private static func gap(_ a: CGRect, _ b: CGRect) -> CGFloat {
        abs(a.minX - b.minX) + abs(a.minY - b.minY) + abs(a.width - b.width) + abs(a.height - b.height)
    }
}
