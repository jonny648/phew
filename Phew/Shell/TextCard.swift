import AppKit
import SwiftUI

/// The answer, in a small card beside the point where the shortcut was pressed. Non-activating, and it stays
/// when the student clicks elsewhere, so the steps can be read while working in the app. Closed, it never takes the
/// keyboard: keystrokes keep going to the student's app.
/// For a guide it lists the steps, the current one emphasized, while the pointer overlay points at its target.
/// There is no Next button: after the student acts in their app, Phew looks again and the guide moves on by itself
/// (`FollowRule` says when). Clicking a step line jumps to it, the quiet fallback.
///
/// The conversation (`docs/03-experience.md` 3.10): a click on the card grows the same panel into a thread with a
/// reply field. Only then does the card take typing, as the input panel does: key, never `NSApp.activate`, so the
/// student's app stays the active app. Every reply takes a fresh screen look; the thread lives in memory only.
/// Closed by Escape, its close control, the shortcut (when the reply field is empty), 10 minutes without a reply,
/// or, while the thread is closed, the last step done. Closing forgets the conversation in the Brain too.
final class TextCard: EditPanel {
    static let width: CGFloat = 360
    static let maxHeight: CGFloat = 420
    static let openWidth: CGFloat = 400
    static let openMaxHeight: CGFloat = 520
    /// The conversation ends after 10 minutes without a reply (3.10, your choice of 15 November).
    static let idleLimit: TimeInterval = 10 * 60
    /// The open thread's top strip: the close control, and where the card is dragged.
    static let header: CGFloat = 28

    let model = CardModel()
    private var task: Task<Void, Never>?
    private var idleTask: Task<Void, Never>?
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
    /// True while an answer streams in.
    var answering: Bool { task != nil }

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

    // Borderless windows refuse key status by default; copying and the reply field need it.
    override var canBecomeKey: Bool { true }

    /// Shows the card at once, thinking, then waits for the capture and plays the Brain's answer into it.
    /// `.noKey` and `.badKey` close the card and go to `onKeyProblem` instead.
    func show(at point: NSPoint, question: String, capture: Task<ContextPacket?, Never>?, brain: any Brain,
              onKeyProblem: @escaping (BrainError) -> Void) {
        dismiss()
        model.reset()
        self.brain = brain
        self.onKeyProblem = onKeyProblem
        // Beside the cursor, not under its tip; the thinking row; the view reports its real height as it grows.
        setFrame(topLeft: NSPoint(x: point.x + 12, y: point.y - 12), size: NSSize(width: Self.width, height: 44))
        alphaValue = 0
        orderFrontRegardless()  // not key: keystrokes keep going to the student's app
        // Escape typed in the app closes the card. Observe only: the app gets its Escape too.
        escapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.dismiss() }
        }
        NSAnimationContext.runAnimationGroup { $0.duration = 0.15; animator().alphaValue = 1 }
        shellLog("card shown, phew front \(phewIsFront), key \(isKeyWindow), escape monitor \(escapeMonitor != nil)")
        answer(question, capture: capture)
    }

    /// One turn: the question on the card, the capture awaited, the Brain's answer played in. The packet goes when
    /// this task ends; only the targets' rects stay for the guide.
    private func answer(_ question: String, capture: Task<ContextPacket?, Never>?, guiding: Bool = false) {
        guard let brain else { return }
        // PS.14: Phew's own state for questions about himself. States only, never words.
        let state = ShellState(accessibility: AXIsProcessTrusted(), screenRecording: CGPreflightScreenCaptureAccess(), guideRunning: guiding)
        idleTask?.cancel()
        idleTask = nil
        model.begin(question)
        task = Task { [weak self] in
            let start = Date()
            var failure: BrainError?
            do {
                // A fast typist can press Return before the first capture in an app is ready (about 1 s).
                let packet = await capture?.value
                guard !Task.isCancelled else { return }
                if let packet, packet.neverRead { self?.model.note = CardModel.neverReadNote(packet.appName) }
                for try await event in brain.answer(question, packet: packet, state: state) {
                    self?.model.apply(event)
                    if case .steps(let steps) = event, !steps.isEmpty {
                        self?.startGuide(steps, targets: steps.map { Self.rect(for: $0.target, in: packet) })
                    }
                }
            } catch {
                failure = BrainError(error)
            }
            guard !Task.isCancelled, let self else { return }
            task = nil  // lets go of the capture and the answer
            shellLog("card: \(failure.map { "error \($0)" } ?? "done"), turn \(model.history.count + 1), \(model.pieces) pieces, \(model.steps.count) steps, \(Int(Date().timeIntervalSince(start) * 1000)) ms")
            model.thinking = false
            if let failure {
                if failure == .noKey || failure == .badKey {
                    let onKeyProblem = onKeyProblem
                    dismiss()
                    onKeyProblem?(failure)
                    return
                }
                model.problem = Self.sentence(for: failure)
            }
            restartIdle()
            if model.queued { sendReply() }  // typed and sent while he answered
        }
    }

    /// Return in the reply field. While he answers the reply waits, and goes when the answer is done.
    /// Each reply takes a fresh look at the screen (3.10): the earlier capture is never reused.
    func sendReply() {
        guard model.open, isVisible else { return }
        let reply = model.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if answering { model.queued = !reply.isEmpty; return }
        model.queued = false
        guard !reply.isEmpty else { return }
        model.draft = ""
        let guiding = !steps.isEmpty
        endGuide()  // a guide of the turn before stops; this reply may start its own
        shellLog("card: reply sent, \(reply.count) characters, turn \(model.history.count + 2), phew front \(phewIsFront)")
        answer(reply, capture: Senses.capture(), guiding: guiding)
    }

    /// A click on the closed card: the same panel grows into the thread, with the cursor in the reply field.
    func openThread() {
        guard isVisible, !model.open else { return }
        model.open = true
        focusReply()
        shellLog("card: thread opened, key \(isKeyWindow), reply focused \(firstResponder is NSTextView), phew front \(phewIsFront), app active \(NSRunningApplication.current.isActive)")
    }

    /// The panel becomes key so the field takes typing; Phew is never made the active app.
    func focusReply() {
        guard model.open, isVisible else { return }
        makeKey()
        contentView?.layoutSubtreeIfNeeded()  // SwiftUI creates the field lazily
        makeFirstResponder(contentView?.editableText)
    }

    /// The shortcut while the thread is open: the cursor goes back to the reply field and no second card opens.
    /// Pressed again with the field focused and empty, it closes the conversation.
    func shortcutPressed() {
        let inField = isKeyWindow && firstResponder is NSTextView
        if inField && model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            dismiss()
        } else {
            focusReply()
        }
        shellLog("card: shortcut while the thread is open, \(isVisible ? "reply focused" : "closed"), phew front \(phewIsFront)")
    }

    /// The last step done. While the thread is open the conversation stays (3.10); closed, the card goes as before.
    func guideDone() {
        model.open ? endGuide() : dismiss()
    }

    /// Stops reading the answer (the Brain then cancels its request), forgets the conversation and takes the card
    /// off screen. Ordering out a key panel hands the keyboard back to the student's app, which never stopped being
    /// the active app.
    func dismiss() {
        task?.cancel()
        task = nil
        idleTask?.cancel()
        idleTask = nil
        endGuide()
        brain?.forgetTurns()  // 3.10: closing ends the conversation; the next call starts fresh
        escapeMonitor.map(NSEvent.removeMonitor)
        escapeMonitor = nil
        guard isVisible else { return }
        orderOut(nil)
        model.reset()  // the thread's words go with the card
        shellLog("card closed, phew front \(phewIsFront), key \(isKeyWindow)")
    }

    private func restartIdle() {
        idleTask?.cancel()
        idleTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.idleLimit))
            guard !Task.isCancelled else { return }
            shellLog("card: 10 minutes without a reply, conversation ended")
            self?.dismiss()
        }
    }

    override func sendEvent(_ event: NSEvent) {
        let point = event.locationInWindow
        let onClose = point.x > frame.width - 32 && point.y > frame.height - 32
        switch event.type {
        // Escape, whatever has focus inside the card (selectable text would turn it into something else).
        case .keyDown where event.keyCode == 53:
            return dismiss()
        // Return sends, Shift and Return makes a new line. Not while an input method is composing.
        case .keyDown where (event.keyCode == 36 || event.keyCode == 76) && model.open:
            if let editor = firstResponder as? NSTextView, editor.isEditable, !editor.hasMarkedText() {
                return event.modifierFlags.contains(.shift) ? editor.insertNewlineIgnoringFieldEditor(nil) : sendReply()
            }
        // The open thread is dragged by its top strip.
        case .leftMouseDown where model.open && point.y > frame.height - Self.header && !onClose:
            return performDrag(with: event)
        default:
            break
        }
        super.sendEvent(event)
        // A click anywhere on the closed card opens the thread; after the click, so a step line still jumps.
        if event.type == .leftMouseUp && !onClose { openThread() }
    }

    /// Puts the top-left corner where it is now, so the card grows and shrinks downward, kept on screen.
    private func fit(height: CGFloat) {
        guard height > 0 else { return }
        let size = model.open ? NSSize(width: Self.openWidth, height: min(height.rounded(.up), Self.openMaxHeight))
                              : NSSize(width: Self.width, height: min(height.rounded(.up), Self.maxHeight))
        setFrame(topLeft: NSPoint(x: frame.minX, y: frame.maxY), size: size)
    }

    /// Moves the card out of the way when it covers the spot the pointer marks (3.10).
    func moveAside(from target: CGRect?) {
        guard let target, isVisible, let visible = screen?.visibleFrame,
              let origin = Self.aside(of: frame, from: target, in: visible) else { return }
        setFrameOrigin(origin)
        shellLog("card: moved aside from the pointer's spot")
    }

    /// Where the card goes so it no longer covers `target` (a zero-size rect is a point ring): left of it, right,
    /// below, then above, the first that stays inside `visible`. Nil when it does not cover the spot, or nothing fits.
    static func aside(of card: CGRect, from target: CGRect, in visible: CGRect) -> CGPoint? {
        let spot = target.insetBy(dx: -24, dy: -24)  // the ring around the target, and a little room
        guard card.intersects(spot) else { return nil }
        let size = card.size
        return [CGPoint(x: spot.minX - size.width, y: card.minY), CGPoint(x: spot.maxX, y: card.minY),
                CGPoint(x: card.minX, y: spot.minY - size.height), CGPoint(x: card.minX, y: spot.maxY)]
            .first { visible.contains(CGRect(origin: $0, size: size)) }
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
    /// The thread shows as many turns as the Brain keeps (3.10): older ones are dropped, not summarised.
    static let keptTurns = 8

    /// One finished turn of the thread, as text: the question, the answer, the step words.
    struct Exchange: Equatable {
        var question: String
        var answer: String
        var steps: [String]
    }

    /// The turn being answered now.
    @Published var question = ""
    @Published var thinking = true
    @Published var text = ""
    @Published var steps: [String] = []
    /// The step being guided, emphasized on the card.
    @Published var current = 0
    @Published var problem: String?
    /// One grey line above the answer: the app is on the never-read list, so its screen was not read.
    @Published var note: String?
    /// The earlier turns, oldest first. Shown only when the thread is open.
    @Published var history: [Exchange] = []
    /// The thread is open: wider, with the reply field.
    @Published var open = false
    /// The reply being typed. In memory only.
    @Published var draft = ""
    /// Return was pressed while he answered: the draft goes when the answer is done.
    @Published var queued = false
    private(set) var pieces = 0
    private var started = false

    func apply(_ event: BrainEvent) {
        switch event {
        case .route(let route): shellLog("card: route \(route)")
        case .text(let piece): text += piece; pieces += 1; thinking = false
        case .steps(let steps): self.steps = steps.map(\.instruction)  // the card points at their targets
        case .done: break  // the card's task ends the thinking state, also when a stream stops short
        }
    }

    /// A new turn: the one on the card moves up into the thread, and the card thinks again.
    func begin(_ question: String) {
        if started {
            history.append(Exchange(question: self.question, answer: problem ?? text, steps: steps))
            history = Array(history.suffix(Self.keptTurns - 1))
        }
        started = true
        self.question = question
        thinking = true; text = ""; steps = []; current = 0; problem = nil; note = nil; pieces = 0
    }

    static func neverReadNote(_ app: String) -> String {
        "\(app.isEmpty ? "This app" : app) is on your Never read list, so Phew did not look at the screen."
    }

    func reset() {
        question = ""; thinking = true; text = ""; steps = []; current = 0; problem = nil; note = nil; pieces = 0
        history = []; open = false; draft = ""; queued = false; started = false
    }
}

private struct CardView: View {
    @ObservedObject var model: CardModel
    let onClose: () -> Void
    let onStep: (Int) -> Void
    let onHeight: (CGFloat) -> Void
    @State private var threadHeight: CGFloat = 0
    @State private var barHeight: CGFloat = 0

    var body: some View {
        Group {
            if model.open { thread } else { closed }
        }
        .frame(width: model.open ? TextCard.openWidth : TextCard.width)
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

    /// The answer card as before, with one grey line saying it can be continued.
    private var closed: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                turn
                Text("Reply…").foregroundStyle(.tertiary)
            }
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .padding(.trailing, 12)  // room for the close control
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onHeight($0) }
        }
    }

    /// Oldest at the top, newest at the bottom, scrolling inside; the reply field below.
    private var thread: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: TextCard.header)  // the close control and the drag strip
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(model.history.enumerated()), id: \.offset) { _, earlier in
                        asked(earlier.question)
                        if !earlier.answer.isEmpty { Text(verbatim: earlier.answer) }
                        // A guide in the thread: each step as one short line.
                        ForEach(Array(earlier.steps.enumerated()), id: \.offset) { index, step in
                            Text(verbatim: "\(index + 1). \(step)").foregroundStyle(.secondary)
                        }
                    }
                    asked(model.question)
                    turn
                }
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { threadHeight = $0; report() }
            }
            .defaultScrollAnchor(.bottom)
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                TextField("Reply…", text: $model.draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...6)
                if model.queued {
                    Text("Sent when this answer is done.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { barHeight = $0; report() }
        }
    }

    private func report() {
        guard threadHeight > 0, barHeight > 0 else { return }
        onHeight(TextCard.header + threadHeight + 1 + barHeight)  // 1: the divider
    }

    /// The student's question, set apart on the right.
    @ViewBuilder private func asked(_ question: String) -> some View {
        if !question.isEmpty {
            Text(verbatim: question)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    /// The turn being answered: thinking, the words as they arrive, the step lines, or what went wrong.
    @ViewBuilder private var turn: some View {
        if let note = model.note { Text(verbatim: note).font(.footnote).foregroundStyle(.secondary) }
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
}

/// One click on the close control works even when the student has since clicked into the app.
// shortcut: only the hosting view answers, so text inside the scroll view may take one click to focus first;
// subclass the scroll view too if students notice.
private final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

private extension NSView {
    /// The reply field: the one editable text in the card, whichever AppKit view SwiftUI made it from.
    var editableText: NSView? {
        if let field = self as? NSTextField, field.isEditable { return field }
        if let view = self as? NSTextView, view.isEditable { return view }
        return subviews.lazy.compactMap(\.editableText).first
    }
}
