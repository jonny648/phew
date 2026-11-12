import AppKit
import SwiftUI

/// Asks for the Claude API key. Shown only when an answer needs a key (none saved, or not accepted) or from the
/// menu bar's "API Key…". The key goes straight to the Keychain and is never logged or shown back.
@MainActor
final class KeyWindow {
    private var panel: NSPanel?

    var isShown: Bool { panel?.isVisible ?? false }

    func show(rejected: Bool = false) {
        dismiss()
        // Non-activating like the other panels: typing and pasting do not make Phew the front app.
        let panel = EditPanel(contentRect: .zero, styleMask: [.titled, .closable, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Phew"
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .floating  // stays above the browser while the student copies the key
        panel.contentView = NSHostingView(rootView: KeyView(rejected: rejected, onSaved: { [weak self] in self?.dismiss() }))
        panel.setContentSize(panel.contentView?.fittingSize ?? NSSize(width: 380, height: 170))
        panel.center()
        panel.orderFrontRegardless()
        panel.makeKey()
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.makeFirstResponder(panel.contentView?.firstTextField)  // so Command+V pastes at once
        self.panel = panel
        shellLog("key window shown, rejected \(rejected), key \(panel.isKeyWindow), field focused \(panel.firstResponder is NSTextView), phew front \(phewIsFront)")
    }

    func dismiss() {
        panel?.contentView = nil  // drops the typed key with the view
        panel?.close()
        panel = nil
    }
}

private struct KeyView: View {
    let rejected: Bool
    let onSaved: () -> Void
    @State private var key = ""
    @State private var problem: String?
    @State private var saving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(rejected ? "Claude did not accept the saved API key. Paste a new one."
                          : "Phew needs your Claude API key to answer.")
            SecureField("API key", text: $key)
                .onSubmit(save)
            HStack {
                // Always works, even if keyboard shortcuts do not reach the field.
                Button("Paste") { key = NSPasteboard.general.string(forType: .string) ?? key }
                Spacer()
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(saving || key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Text(problem ?? "The key is stored only in this Mac's Keychain.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 380, alignment: .leading)
    }

    private func save() {
        guard !saving, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        saving = true
        let key = key
        Task {
            // Off the main thread: the Keychain call can block.
            let result = await Task.detached { Result { try KeyStore().save(key) } }.value
            saving = false
            switch result {
            case .success:
                shellLog("key saved")
                onSaved()
            case .failure(let error):
                let status = (error as? KeyStore.Failure)?.status ?? 0
                shellLog("key not saved, keychain status \(status)")
                problem = "The Keychain did not save the key (error \(status)). Please try again."
            }
        }
    }
}
