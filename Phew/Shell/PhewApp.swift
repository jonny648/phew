import SwiftUI
import os

@main
struct PhewApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @ObservedObject private var shell = Shell.shared

    // No main window (hard rule): the menu bar item is the only scene.
    var body: some Scene {
        MenuBarExtra {
            Button(shell.paused ? "Resume" : "Pause") { shell.paused.toggle() }
            Divider()
            Button("Quit Phew") { NSApp.terminate(nil) }
        } label: {
            Image(systemName: shell.paused ? "pause.circle" : "cursorarrow.rays")
                .accessibilityLabel(shell.paused ? "Phew, paused" : "Phew")
        }
    }
}

final class Shell: ObservableObject {
    static let shared = Shell()
    /// While paused the shortcut does nothing.
    @Published var paused = false
    /// Latest context from Senses. The Brain takes it from here in P3.
    var latestPacket: ContextPacket?
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let panel = InputPanel()
    private let permissions = PermissionsWindow()
    private lazy var hotKey = HotKey { [unowned self] in
        guard !Shell.shared.paused else { return }
        shellLog("shortcut fired, front app \(frontAppID)")
        let capture = Senses.capture()  // first: the panel opens under the cursor
        panel.open()
        Task { Shell.shared.latestPacket = await capture.value }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        hotKey.install()
        // Re-install once Accessibility is granted, so the shortcut works without a relaunch.
        permissions.showIfMissing(onAccessibilityGranted: { [unowned self] in hotKey.install() })

        #if DEBUG
        // Self-check for the checker, who cannot press keys: opens the panel, then sends Escape's action.
        if CommandLine.arguments.contains("--debug-open-panel") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [unowned self] in
                NSApp.deactivate()  // real use: another app is active when the shortcut fires
                shellLog("self-check before open: appActive=\(NSRunningApplication.current.isActive) front=\(frontAppID) windows=\(NSApp.windows.map(\.className))")
                // Twice: the second open is the usual case in real use (panel already shown once).
                for delay in [0.0, 2.0] {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [unowned self] in
                        panel.open()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [unowned self] in
                            let responder = panel.firstResponder.map { String(describing: type(of: $0)) } ?? "none"
                            shellLog("self-check: key=\(panel.isKeyWindow) appActive=\(NSRunningApplication.current.isActive) front=\(frontAppID) firstResponder=\(responder)")
                            NSApp.sendAction(#selector(NSResponder.cancelOperation(_:)), to: nil, from: nil)
                        }
                    }
                }
            }
        }
        // Self-check for Senses: captures the front app, with a screenshot, into the debug files.
        // An optional bundle id after the flag reads that running app instead, without bringing it forward.
        if let flag = CommandLine.arguments.firstIndex(of: "--debug-capture") {
            let target = CommandLine.arguments.dropFirst(flag + 1).first
                .flatMap { NSRunningApplication.runningApplications(withBundleIdentifier: $0).first }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                let capture = Senses.capture(forceScreenshot: true, app: target)
                Task { Shell.shared.latestPacket = await capture.value }
            }
        }
        if CommandLine.arguments.contains("--debug-brain-check") { BrainSelfCheck.run() }  // real API calls, made-up data
        #endif
    }
}

// MARK: - Debug evidence. Release builds log nothing.

var frontAppID: String {
    NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "none"
}

func shellLog(_ message: String) {
    #if DEBUG
    Logger(subsystem: "com.gianlucatroietto.Phew", category: "shell").info("\(message, privacy: .public)")
    #endif
}
