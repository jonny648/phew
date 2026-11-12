import AppKit
import SwiftUI

/// Small typing panel at the cursor. Non-activating: the front app stays frontmost.
final class InputPanel: EditPanel {
    /// Set while open. Gets the question on Return, nil when the panel closes without one.
    private var onClose: ((String?) -> Void)?

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        level = .floating
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    // Borderless windows refuse key status by default; typing needs it.
    override var canBecomeKey: Bool { true }

    func open(onClose: @escaping (String?) -> Void) {
        self.onClose = onClose
        // A fresh view each time: empty text, focus on the field.
        contentView = NSHostingView(rootView: InputField(onSubmit: { [weak self] text in
            shellLog("submitted: \(text.count) characters")
            self?.dismiss(text)
        }))
        setFrame(topLeft: NSEvent.mouseLocation, size: contentView?.fittingSize ?? NSSize(width: 320, height: 44))

        orderFrontRegardless()
        makeKey()
        // SwiftUI's own focus request only works on the first open, so focus the AppKit field directly.
        // Layout first: SwiftUI creates the NSTextField lazily.
        contentView?.layoutSubtreeIfNeeded()
        makeFirstResponder(contentView?.firstTextField)
        shellLog("panel opened, phew front \(phewIsFront)")
    }

    func dismiss(_ question: String? = nil) {
        guard let onClose else { return }
        self.onClose = nil  // first: orderOut resigns key, which comes back here
        orderOut(nil)
        shellLog("panel closed, phew front \(phewIsFront)")
        onClose(question)
    }

    // Escape.
    override func cancelOperation(_ sender: Any?) { dismiss() }

    // Click elsewhere.
    override func resignKey() {
        super.resignKey()
        dismiss()
    }
}

private struct InputField: View {
    let onSubmit: (String) -> Void
    @State private var text = ""

    var body: some View {
        TextField("Ask Phew", text: $text)
            .textFieldStyle(.plain)
            .onSubmit { onSubmit(text) }
            .onChange(of: text) { shellLog("typing, phew front \(phewIsFront)") }
            .padding(12)
            .frame(width: 320)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
