import SwiftUI
import os

@main
struct PhewApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    /// The "Let Phew act" switch: nil until Allow on the consent screen (PH.3), then the menu shows it.
    @AppStorage(Hand.allowedKey) private var allowed: Bool?

    // No main window (hard rule): the menu bar item is the only scene.
    var body: some Scene {
        MenuBarExtra {
            Button("API Key…") { delegate.keyWindow.show() }
            Button("Recently deleted…") { delegate.showRecentlyDeleted() }
            Button("Export the Map…") { delegate.showExport() }
            if let allowed {
                // Off: he guides instead, and the consent screen is not shown again; this is the way back on.
                Toggle("Let Phew act", isOn: Binding(get: { allowed }, set: { self.allowed = $0 }))
            }
            Button("Never read this app") { delegate.neverReadFrontApp() }
            Button("Never-read apps…") { delegate.showNeverRead() }
            Divider()
            Button("About and licences") { delegate.menuPanel.show(title: "About Phew", AboutView()) }
            Button("Quit Phew") { NSApp.terminate(nil) }
        } label: {
            MenuIcon(model: delegate.card.model)
        }
    }
}

/// The menu bar icon (15.5 D), a template symbol: resting, or acting for the whole job. It never animates.
/// The research count and the waiting result arrive with phase PA.
private struct MenuIcon: View {
    @ObservedObject var model: CardModel

    var body: some View {
        Image(systemName: model.acting ? "cursorarrow.motionlines" : "cursorarrow.rays")
            .accessibilityLabel(model.acting ? "Phew, acting" : "Phew")
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// The one place the Brain is made. Everything else in the Shell sees only the `Brain` protocol.
    var brain: any Brain = ClaudeBrain()
    let panel = InputPanel()
    let card = TextCard()
    let keyWindow = KeyWindow()
    /// Recently deleted, Export the Map, Never read or About: one small panel at a time.
    let menuPanel = MenuPanel()
    private let permissions = PermissionsWindow()
    /// The context read at the shortcut, kept only until the question is asked or the panel closes without one.
    var capture: Task<ContextPacket?, Never>?
    /// The ask panel's top-left corner: the card opens there, in its place.
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

    /// The conversation's turns do not outlive the app (closing the card also forgets them).
    func applicationWillTerminate(_ notification: Notification) {
        brain.forgetTurns()
        shellLog("quit: turns dropped")
    }

    func showRecentlyDeleted() {
        menuPanel.show(title: "Recently deleted", DeletedView(list: DeletedList(brain: brain)))
    }

    func showExport() {
        menuPanel.show(title: "Export the Map", ExportView(exporter: MapExporter(brain: brain)))
    }

    /// Adds the app in front (opening the menu bar menu does not take the front from it), then shows the list.
    func neverReadFrontApp() {
        if let app = NSWorkspace.shared.frontmostApplication, app != .current, let bundleID = app.bundleIdentifier {
            NeverReadList.shared.add(name: app.localizedName ?? bundleID, bundleID: bundleID)
        }
        showNeverRead()
    }

    func showNeverRead() {
        menuPanel.show(title: "Never read", NeverReadView(model: NeverReadModel()))
    }

    private func shortcut() {
        // The panel is already open: a second capture would read Phew's own panel.
        guard !panel.isOpen else { return }  // not `isVisible`: it may still be fading out
        // 3.10: while a conversation is open the shortcut goes back to its reply field; no second card.
        if card.isVisible && card.model.open { return card.shortcutPressed() }
        card.dismiss()  // off screen first, so the capture reads the user's app and not the card
        shellLog("shortcut fired, phew front \(phewIsFront)")
        capture = Senses.capture()  // before the panel: it opens under the cursor
        panel.open { [unowned self] question in
            if let question { ask(question) } else { capture = nil }
        }
        anchor = NSPoint(x: panel.frame.minX, y: panel.frame.maxY)  // 15.5 A: the card takes the panel's place
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
