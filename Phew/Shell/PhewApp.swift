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
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let panel = InputPanel()
    private let permissions = PermissionsWindow()
    private lazy var hotKey = HotKey { [unowned self] in
        guard !Shell.shared.paused else { return }
        shellLog("shortcut fired, front app \(frontAppID)")
        panel.open()
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
