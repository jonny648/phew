import AppKit
import Combine
import SwiftUI

/// The one plain screen that asks for Accessibility and Screen Recording.
/// Shown at launch only if one is missing; closes itself when both are granted.
@MainActor
final class PermissionsWindow {
    private var panel: NSPanel?

    func showIfMissing(onAccessibilityGranted: @escaping () -> Void) {
        guard !(AXIsProcessTrusted() && CGPreflightScreenCaptureAccess()) else { return }

        // Non-activating, so clicking its buttons does not make Phew the front app.
        let panel = NSPanel(contentRect: .zero, styleMask: [.titled, .closable, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Phew"
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(rootView: PermissionsView(
            onAccessibilityGranted: onAccessibilityGranted,
            onAllGranted: { [weak self] in
                self?.panel?.contentView = nil  // stops the recheck timer
                self?.panel?.close()
                self?.panel = nil
            }))
        panel.setContentSize(panel.contentView?.fittingSize ?? NSSize(width: 380, height: 180))
        panel.center()
        panel.orderFrontRegardless()
        self.panel = panel
    }
}

private struct PermissionsView: View {
    let onAccessibilityGranted: () -> Void
    let onAllGranted: () -> Void

    @State private var accessibility = AXIsProcessTrusted()
    @State private var screenRecording = CGPreflightScreenCaptureAccess()
    private let recheck = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Phew needs two permissions to see what is on your screen.")
            // shortcut: macOS shows each prompt only once; after a refusal the user must open
            // System Settings > Privacy & Security by hand. Add a Settings link if that bites.
            row("Accessibility", granted: accessibility) {
                let prompt = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                _ = AXIsProcessTrustedWithOptions(prompt)
            }
            row("Screen Recording", granted: screenRecording) {
                _ = CGRequestScreenCaptureAccess()
            }
            Text("Screen Recording may only take effect after you quit and reopen Phew.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 380, alignment: .leading)
        .onReceive(recheck) { _ in
            let trusted = AXIsProcessTrusted()
            if trusted && !accessibility { onAccessibilityGranted() }
            accessibility = trusted
            screenRecording = CGPreflightScreenCaptureAccess()
            if accessibility && screenRecording { onAllGranted() }
        }
    }

    private func row(_ name: String, granted: Bool, request: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? .green : .secondary)
                .accessibilityLabel(granted ? "Granted" : "Not granted")
            Text(name)
            Spacer()
            Button("Allow", action: request).disabled(granted)
        }
    }
}
