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

    /// Set while the shortcut is held to talk (P6.1): the panel shows what is heard and never takes the keyboard,
    /// since the user is holding modifier keys over their app.
    private(set) var listening: ListenModel?

    // Borderless windows refuse key status by default; typing needs it. Never while listening.
    override var canBecomeKey: Bool { listening == nil }

    /// `text`: what the field holds at first, the cursor after it. `line`: one grey line under the field, such as
    /// "I did not catch that." `point`: the top-left corner; nil, the cursor.
    func open(text: String = "", line: String? = nil, at point: NSPoint? = nil, onClose: @escaping (String?) -> Void) {
        endListening(fade: false)
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

    /// The listening state at the cursor: the dot breathing, the words as they come, greyed. Shown, never key.
    func listen() {
        guard !isOpen else { return }
        let model = ListenModel()
        listening = model
        contentView = NSHostingView(rootView: ListeningField(model: model))
        setFrame(topLeft: NSEvent.mouseLocation, size: NSSize(width: Design.Size.width, height: Design.Size.ask))
        alphaValue = 0
        orderFrontRegardless()  // not key: the keys stay with the user's app
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Design.Motion.appear
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
        }
        shellLog("panel listening, key \(isKeyWindow), phew front \(phewIsFront)")
    }

    /// The words heard so far, or one plain line when listening failed.
    func heard(_ words: String) { listening?.partial = words }
    func listenProblem(_ line: String) {
        listening?.line = line
        listening?.active = false
        // Next turn of the run loop, once SwiftUI has laid out the line.
        DispatchQueue.main.async { [weak self] in
            guard let self, listening != nil else { return }
            setFrame(topLeft: NSPoint(x: frame.minX, y: frame.maxY), size: NSSize(width: Design.Size.width, height: fittedHeight))
        }
    }

    /// The field's height, more when a line wraps under it.
    private var fittedHeight: CGFloat { max(Design.Size.ask, contentView?.fittingSize.height ?? 0) }

    /// Ends the listening state: at once when the card takes the panel's place, else with `leave`. Nothing when the
    /// panel is not listening, so a typing panel is never closed by it.
    func endListening(fade: Bool = true) {
        guard listening != nil else { return }
        listening = nil
        guard fade else { return orderOut(nil) }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Design.Motion.leave
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, !isOpen, listening == nil else { return }  // opened again during the fade
            orderOut(nil)
        })
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

/// What the listening panel shows; the app delegate fills it as words come.
final class ListenModel: ObservableObject {
    @Published var partial = ""
    @Published var line: String?
    /// False once listening failed: the dot stops breathing.
    @Published var active = true
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

/// The ask panel while the shortcut is held (P6.1): the dot breathing in the accent (dimmed and still with Reduce
/// Motion), the words heard so far in `ask`, greyed, in place of the placeholder.
private struct ListeningField: View {
    @ObservedObject var model: ListenModel
    @State private var shown = false

    var body: some View {
        let reduce = Design.Motion.reduce
        VStack(spacing: 0) {
            HStack(spacing: Design.Space.s12) {
                PresenceDot(breathing: model.active && !reduce)
                    .opacity(model.active && reduce ? 0.4 : 1)
                    .accessibilityLabel(model.active ? "Listening" : "Phew")
                Text(verbatim: model.partial.isEmpty ? "Ask Phew" : model.partial)
                    .font(Design.Text.ask)
                    .foregroundStyle(model.partial.isEmpty ? Design.Ink.tertiary : Design.Ink.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)  // the newest words stay in view
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: Design.Size.ask)
            if let line = model.line { LineRow(text: line) }
        }
        .padding(.horizontal, Design.Space.s16)
        .frame(width: Design.Size.width)
        .surface()
        .scaleEffect(shown || reduce ? 1 : Design.Motion.appearScale)
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
