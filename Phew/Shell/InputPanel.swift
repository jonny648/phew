import AppKit
import SwiftUI

/// Small typing panel at the cursor (docs/15-design.md 15.5 A). Non-activating: the front app stays frontmost.
/// On Return it goes at once and the card takes its place at the same corner and width, so the eye sees one box.
final class InputPanel: EditPanel {
    /// Set while open. Gets the question on Return, nil when the panel closes without one.
    private var onClose: ((String?) -> Void)?
    /// Open for typing. False while it fades out after closing without a question.
    var isOpen: Bool { onClose != nil }

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
        setFrame(topLeft: NSEvent.mouseLocation, size: NSSize(width: Design.Size.width, height: Design.Size.ask))

        // `appear`; typing never waits for it.
        alphaValue = 0
        orderFrontRegardless()
        makeKey()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Design.Motion.appear
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
        }
        // SwiftUI's own focus request only works on the first open, so focus the AppKit field directly.
        // Layout first: SwiftUI creates the NSTextField lazily.
        contentView?.layoutSubtreeIfNeeded()
        makeFirstResponder(contentView?.firstTextField)
        shellLog("panel opened, phew front \(phewIsFront)")
    }

    /// With a question the panel goes at once, as the card appears in its place. Without one it fades (`leave`).
    func dismiss(_ question: String? = nil) {
        guard let onClose else { return }
        self.onClose = nil  // first: orderOut resigns key, which comes back here
        if question == nil {
            // shortcut: the panel keeps the keyboard for the 0.12 s of the fade; order out first if a typed key is lost.
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = Design.Motion.leave
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                guard let self, !isOpen else { return }  // opened again during the fade
                orderOut(nil)
            })
        } else {
            orderOut(nil)
        }
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
    @State private var shown = false

    var body: some View {
        HStack(spacing: Design.Space.s12) {
            PresenceDot()
            TextField("Ask Phew", text: $text)
                .textFieldStyle(.plain)
                .font(Design.Text.ask)
                .foregroundStyle(Design.Ink.primary)
                .onSubmit { onSubmit(text) }
                .onChange(of: text) { shellLog("typing, phew front \(phewIsFront)") }
        }
        .padding(.horizontal, Design.Space.s16)
        .frame(width: Design.Size.width, height: Design.Size.ask)
        .surface()
        // The scale half of `appear`; the window fades. Opacity only with Reduce Motion.
        .scaleEffect(shown || Design.Motion.reduce ? 1 : Design.Motion.appearScale)
        .onAppear { withAnimation(.easeOut(duration: Design.Motion.appear)) { shown = true } }
    }
}
