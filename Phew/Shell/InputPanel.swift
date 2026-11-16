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

    /// `text`: what the field holds at first, the cursor after it. `line`: one grey line under the field, such as
    /// "I did not catch that." `point`: the top-left corner; nil, the cursor.
    func open(text: String = "", line: String? = nil, at point: NSPoint? = nil, onClose: @escaping (String?) -> Void) {
        self.onClose = onClose
        // A fresh view each time: empty text, focus on the field.
        contentView = NSHostingView(rootView: InputField(text: text, line: line, onSubmit: { [weak self] text in
            shellLog("submitted: \(text.count) characters")
            self?.dismiss(text)
        }))
        setFrame(topLeft: point ?? NSEvent.mouseLocation, size: NSSize(width: Design.Size.width, height: fittedHeight))

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
        let field = contentView?.firstTextField
        makeFirstResponder(field)
        // Pre-filled: the cursor after the words, ready to fix, not every word selected.
        field?.currentEditor()?.selectedRange = NSRange(location: (field?.stringValue as NSString?)?.length ?? 0, length: 0)
        shellLog("panel opened, phew front \(phewIsFront), prefilled \(!text.isEmpty), line \(line != nil)")
    }

    /// The field's height, more when a line wraps under it.
    private var fittedHeight: CGFloat { max(Design.Size.ask, contentView?.fittingSize.height ?? 0) }

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
    @State var text: String
    let line: String?
    let onSubmit: (String) -> Void
    @State private var shown = false

    init(text: String = "", line: String? = nil, onSubmit: @escaping (String) -> Void) {
        _text = State(initialValue: text)
        self.line = line
        self.onSubmit = onSubmit
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Design.Space.s12) {
                PresenceDot()
                TextField("Ask Phew", text: $text)
                    .textFieldStyle(.plain)
                    .font(Design.Text.ask)
                    .foregroundStyle(Design.Ink.primary)
                    .onSubmit { onSubmit(text) }
                    .onChange(of: text) { shellLog("typing, phew front \(phewIsFront)") }
            }
            .frame(height: Design.Size.ask)
            if let line { LineRow(text: line) }
        }
        .padding(.horizontal, Design.Space.s16)
        .frame(width: Design.Size.width)
        .surface()
        // The scale half of `appear`; the window fades. Opacity only with Reduce Motion.
        .scaleEffect(shown || Design.Motion.reduce ? 1 : Design.Motion.appearScale)
        .onAppear { withAnimation(.easeOut(duration: Design.Motion.appear)) { shown = true } }
    }
}

/// One grey line under the field, inside the same surface, where the hint row sits (15.5 A).
private struct LineRow: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(Design.Text.small)
            .foregroundStyle(Design.Ink.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: Design.Size.hintRow - Design.Space.s8, alignment: .topLeading)
            .padding(.bottom, Design.Space.s8)
            .padding(.leading, Design.Size.dot + Design.Space.s12)  // under the words, not the dot
    }
}
