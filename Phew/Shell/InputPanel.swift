import AppKit
import SwiftUI

/// Small typing panel at the cursor. Non-activating: the front app stays frontmost.
final class InputPanel: NSPanel {
    private var isOpen = false

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

    func open() {
        // A fresh view each time: empty text, focus on the field.
        contentView = NSHostingView(rootView: InputField(onSubmit: { [weak self] text in
            shellLog("submitted: \(text)")  // nothing is sent anywhere until the Brain exists (P3)
            self?.dismiss()
        }))
        setContentSize(contentView?.fittingSize ?? NSSize(width: 320, height: 44))

        let mouse = NSEvent.mouseLocation
        var origin = NSPoint(x: mouse.x, y: mouse.y - frame.height)
        if let visible = (NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main)?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX), visible.maxX - frame.width)
            origin.y = min(max(origin.y, visible.minY), visible.maxY - frame.height)
        }
        setFrameOrigin(origin)

        isOpen = true
        orderFrontRegardless()
        makeKey()
        // SwiftUI's own focus request only works on the first open, so focus the AppKit field directly.
        // Layout first: SwiftUI creates the NSTextField lazily.
        contentView?.layoutSubtreeIfNeeded()
        makeFirstResponder(contentView?.firstTextField)
        shellLog("panel opened, front app \(frontAppID)")
    }

    func dismiss() {
        guard isOpen else { return }
        isOpen = false
        orderOut(nil)
        shellLog("panel closed, front app \(frontAppID)")
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
            .onChange(of: text) { shellLog("typing, front app \(frontAppID)") }
            .padding(12)
            .frame(width: 320)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

private extension NSView {
    var firstTextField: NSTextField? {
        (self as? NSTextField) ?? subviews.lazy.compactMap(\.firstTextField).first
    }
}
