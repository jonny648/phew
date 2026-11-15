import AppKit
import SwiftUI

/// The answer, in a small card beside the point where the shortcut was pressed. Non-activating, and it stays
/// when the student clicks elsewhere, so the steps can be read while working in the app. It never takes the
/// keyboard on its own: it becomes key only when clicked, for selecting and copying.
/// For a guide it lists the steps, the current one emphasized, while the pointer overlay points at its target.
/// There is no Next button: after the student acts in their app, Phew looks again and the guide moves on by itself
/// (`FollowRule` says when). Clicking a step line jumps to it, the quiet fallback.
/// Closed by Escape, its close control, the shortcut, or the last step done.
final class TextCard: EditPanel {
    static let width: CGFloat = 360
    static let maxHeight: CGFloat = 420

    let model = CardModel()
    private var task: Task<Void, Never>?
    private var top = NSPoint.zero
    // Internal, not private, except `escapeMonitor`: the guide (TextCardGuide.swift) and following
    // (TextCardFollowing.swift) extensions set these, and an extension in another file cannot reach private members.
    var brain: (any Brain)?
    var onKeyProblem: ((BrainError) -> Void)?
    /// One per step, AppKit screen coordinates: an element's frame, a zero-size rect for a screenshot point, or
    /// nil. All that is kept of the context for the guide, updated by each look; empty when no guide runs.
    var targets: [CGRect?] = []
    /// The guide as the Brain gave it, for the looks that follow the student; empty when no guide runs.
    var steps: [GuideStep] = []
    var overlay: PointerOverlay?
    private var escapeMonitor: Any?
    /// Observes the student's clicks, keys and scrolls in other apps while the guide follows them; nil otherwise.
    var actionMonitor: Any?
    var rule = FollowRule()
    /// The calm wait before a look, and the look itself (capture and Brain check).
    var waitTask: Task<Void, Never>?
    var lookTask: Task<Void, Never>?
    var lookPending: Bool { waitTask != nil || lookTask != nil }

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 44),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        level = .floating
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let host = FirstClickHostingView(rootView: CardView(
            model: model,
            onClose: { [weak self] in self?.dismiss() },
            onStep: { [weak self] in self?.jump(to: $0) },
            // Next turn of the run loop: resizing the window inside SwiftUI's layout pass would nest layouts.
            onHeight: { [weak self] height in DispatchQueue.main.async { self?.fit(height: height) } }))
        host.sizingOptions = []  // the card sets its own frame, top-left fixed
        contentView = host
    }

    // Borderless windows refuse key status by default; copying needs it once the student clicks in.
    override var canBecomeKey: Bool { true }

    /// Shows the card at once, thinking, then waits for the capture and plays the Brain's answer into it.
    /// `.noKey` and `.badKey` close the card and go to `onKeyProblem` instead.
    func show(at point: NSPoint, question: String, capture: Task<ContextPacket?, Never>?, brain: any Brain,
              onKeyProblem: @escaping (BrainError) -> Void) {
        dismiss()
        model.reset()
        self.brain = brain
        self.onKeyProblem = onKeyProblem
        top = NSPoint(x: point.x + 12, y: point.y - 12)  // beside the cursor, not under its tip
        fit(height: 44)  // the thinking row; the view reports its real height as it grows
        alphaValue = 0
        orderFrontRegardless()  // not key: keystrokes keep going to the student's app
        // Escape typed in the app closes the card. Observe only: the app gets its Escape too.
        escapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.dismiss() }
        }
        NSAnimationContext.runAnimationGroup { $0.duration = 0.15; animator().alphaValue = 1 }
        shellLog("card shown, phew front \(phewIsFront), key \(isKeyWindow), escape monitor \(escapeMonitor != nil)")

        task = Task { [weak self] in
            let start = Date()
            var failure: BrainError?
            do {
                // A fast typist can press Return before the first capture in an app is ready (about 1 s).
                let packet = await capture?.value
                guard !Task.isCancelled else { return }
                for try await event in brain.answer(question, packet: packet) {
                    self?.model.apply(event)
                    // Only the targets' rects stay for the guide; the packet goes when this task ends.
                    if case .steps(let steps) = event, !steps.isEmpty {
                        self?.startGuide(steps, targets: steps.map { Self.rect(for: $0.target, in: packet) })
                    }
                }
            } catch {
                failure = BrainError(error)
            }
            guard !Task.isCancelled, let self else { return }
            task = nil  // lets go of the capture and the answer
            shellLog("card: \(failure.map { "error \($0)" } ?? "done"), \(model.pieces) pieces, \(model.steps.count) steps, \(Int(Date().timeIntervalSince(start) * 1000)) ms")
            model.thinking = false
            guard let failure else { return }
            if failure == .noKey || failure == .badKey {
                dismiss()
                onKeyProblem(failure)
            } else {
                model.problem = Self.sentence(for: failure)
            }
        }
    }

    /// Stops reading the answer (the Brain then cancels its request) and takes the card off screen.
    func dismiss() {
        task?.cancel()
        task = nil
        endGuide()
        escapeMonitor.map(NSEvent.removeMonitor)
        escapeMonitor = nil
        guard isVisible else { return }
        orderOut(nil)
        model.reset()
        shellLog("card closed, phew front \(phewIsFront)")
    }

    // Escape, whatever has focus inside the card (selectable text would turn it into something else).
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown && event.keyCode == 53 { return dismiss() }
        super.sendEvent(event)
    }

    private func fit(height: CGFloat) {
        guard height > 0 else { return }
        setFrame(topLeft: top, size: NSSize(width: Self.width, height: min(height.rounded(.up), Self.maxHeight)))
    }

    static func sentence(for error: BrainError) -> String {
        switch error {
        case .rateLimited: "Too many questions in a short time. Wait a minute, then ask again."
        case .overloaded: "Claude is busy right now. Try again in a moment."
        case .network: "Phew couldn't reach Claude. Check your internet connection."
        case .refused: "Claude declined to answer this one."
        case .badOutput: "The answer came back garbled. Please ask again."
        case .failed(let status): "Something went wrong (error \(status)). Please ask again."
        case .noKey, .badKey: "Phew needs a working Claude API key."
        }
    }
}

final class CardModel: ObservableObject {
    @Published var thinking = true
    @Published var text = ""
    @Published var steps: [String] = []
    /// The step being guided, emphasized on the card.
    @Published var current = 0
    @Published var problem: String?
    private(set) var pieces = 0

    func apply(_ event: BrainEvent) {
        switch event {
        case .route(let route): shellLog("card: route \(route)")
        case .text(let piece): text += piece; pieces += 1; thinking = false
        case .steps(let steps): self.steps = steps.map(\.instruction)  // the card points at their targets
        case .done: break  // the card's task ends the thinking state, also when a stream stops short
        }
    }

    func reset() {
        thinking = true; text = ""; steps = []; current = 0; problem = nil; pieces = 0
    }
}

private struct CardView: View {
    @ObservedObject var model: CardModel
    let onClose: () -> Void
    let onStep: (Int) -> Void
    let onHeight: (CGFloat) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if model.thinking && model.problem == nil {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Thinking…").foregroundStyle(.secondary)
                    }
                }
                if !model.text.isEmpty { Text(verbatim: model.text) }
                // No Next button: the guide follows the student. A step line jumps to that step.
                ForEach(Array(model.steps.enumerated()), id: \.offset) { index, step in
                    Button { onStep(index) } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(verbatim: "\(index + 1).").monospacedDigit()
                            Text(verbatim: step).multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .fontWeight(index == model.current ? .semibold : .regular)
                    .foregroundStyle(index == model.current ? .primary : .secondary)
                    .accessibilityAddTraits(index == model.current ? .isSelected : [])
                }
                if let problem = model.problem { Text(verbatim: problem).foregroundStyle(.secondary) }
            }
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .padding(.trailing, 12)  // room for the close control
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onHeight($0) }
        }
        .frame(width: TextCard.width)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }
}

/// One click on the close control works even when the student has since clicked into the app.
// shortcut: only the hosting view answers, so text inside the scroll view may take one click to focus first;
// subclass the scroll view too if students notice.
private final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
