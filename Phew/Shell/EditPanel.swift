import AppKit

/// Base for Phew's panels. Phew has no main menu (menu bar app), so nothing turns Command+X, C, V and A
/// into cut, copy, paste and select all: the panel sends those actions to the focused field itself.
class EditPanel: NSPanel {
    private static let editActions: [String: Selector] = [
        "x": #selector(NSText.cut(_:)), "c": #selector(NSText.copy(_:)),
        "v": #selector(NSText.paste(_:)), "a": #selector(NSText.selectAll(_:)),
    ]

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Command alone (Caps Lock ignored), on the key under the letter in the current layout.
        if event.modifierFlags.intersection([.command, .shift, .option, .control]) == .command,
           let action = event.charactersIgnoringModifiers.flatMap({ Self.editActions[$0.lowercased()] }),
           NSApp.sendAction(action, to: nil, from: self) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    /// Puts the top-left corner at `point`, kept inside the visible frame of that point's screen.
    /// `animated`: through the animator, inside the caller's animation group.
    func setFrame(topLeft point: NSPoint, size: NSSize, animated: Bool = false) {
        var origin = NSPoint(x: point.x, y: point.y - size.height)
        if let visible = (NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main)?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
            origin.y = min(max(origin.y, visible.minY), visible.maxY - size.height)
        }
        (animated ? animator() : self).setFrame(NSRect(origin: origin, size: size), display: true)
    }
}

extension NSView {
    /// SwiftUI's own focus request is unreliable in these panels, so Phew focuses the AppKit field directly.
    var firstTextField: NSTextField? {
        (self as? NSTextField) ?? subviews.lazy.compactMap(\.firstTextField).first
    }

    /// The same for a multi-line box (SwiftUI's `TextEditor`).
    var firstTextView: NSTextView? {
        (self as? NSTextView) ?? subviews.lazy.compactMap(\.firstTextView).first
    }
}
