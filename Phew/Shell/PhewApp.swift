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
            Button("API Key…") { delegate.keyWindow.show() }
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
    /// The one place the Brain is made. Everything else in the Shell sees only the `Brain` protocol.
    var brain: any Brain = ClaudeBrain()
    let panel = InputPanel()
    let card = TextCard()
    let keyWindow = KeyWindow()
    private let permissions = PermissionsWindow()
    /// The context read at the shortcut, kept only until the question is asked or the panel closes without one.
    var capture: Task<ContextPacket?, Never>?
    /// Where the cursor was at the shortcut: the card opens beside it.
    var anchor = NSPoint.zero
    private lazy var hotKey = HotKey { [unowned self] in shortcut() }

    func applicationDidFinishLaunching(_ notification: Notification) {
        hotKey.install()
        // Re-install once Accessibility is granted, so the shortcut works without a relaunch.
        permissions.showIfMissing(onAccessibilityGranted: { [unowned self] in hotKey.install() })
        #if DEBUG
        runDebugChecks()
        #endif
    }

    private func shortcut() {
        // Paused, or the panel is already open (a second capture would read Phew's own panel).
        guard !Shell.shared.paused, !panel.isVisible else { return }
        card.dismiss()  // off screen first, so the capture reads the user's app and not the card
        shellLog("shortcut fired, phew front \(phewIsFront)")
        capture = Senses.capture()  // before the panel: it opens under the cursor
        anchor = NSEvent.mouseLocation
        panel.open { [unowned self] question in
            if let question { ask(question) } else { capture = nil }
        }
    }

    /// An empty question is fine: the Brain then explains what is under the cursor.
    func ask(_ question: String) {
        card.show(at: anchor, question: question, capture: capture, brain: brain) { [unowned self] error in
            keyWindow.show(rejected: error == .badKey)  // the student asks again himself once the key is saved
        }
        capture = nil
    }
}

// MARK: - Debug evidence. Release builds log nothing.

/// True would break a hard rule: Phew never takes the front from the user's app.
var phewIsFront: Bool {
    NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier
}

/// Counts, timings, route names and error classes only: never the question, the answer or captured context.
func shellLog(_ message: String) {
    #if DEBUG
    Logger(subsystem: "com.gianlucatroietto.Phew", category: "shell").info("\(message, privacy: .public)")
    #endif
}
