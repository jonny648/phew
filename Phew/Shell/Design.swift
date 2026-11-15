import AppKit
import SwiftUI

/// Phew's look, the tokens of docs/15-design.md 15.4. Change a value here and it changes everywhere.
/// Only what is in use so far; the pointer, the menu and the small panels add theirs when they are restyled.
enum Design {
    enum Text {
        /// The ask field only.
        static let ask = Font.system(size: 16)
        /// Answers, replies, steps. Use with `.lineSpacing(Design.Text.bodySpacing)` for its 18-point line.
        static let body = Font.body
        static let bodySpacing: CGFloat = 2
        /// The current step, button labels.
        static let strong = Font.body.weight(.semibold)
        /// Footers, notes, the question line on the card.
        static let small = Font.subheadline
    }

    enum Ink {
        static let primary = Color(nsColor: .labelColor)
        static let secondary = Color(nsColor: .secondaryLabelColor)
        static let tertiary = Color(nsColor: .tertiaryLabelColor)
        static let hairline = Color(nsColor: .separatorColor)
        /// Bubbles, key caps, quiet buttons.
        static let fill = HierarchicalShapeStyle.quaternary
        /// Phew's one colour. Shapes only, never text.
        static let accent = Color(nsColor: NSColor(name: "PhewAccent") { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(srgbRed: 1, green: 0x6B / 255, blue: 0x35 / 255, alpha: 1)  // #FF6B35
                : NSColor(srgbRed: 0xF2 / 255, green: 0x54 / 255, blue: 0x1B / 255, alpha: 1)  // #F2541B
        })
        /// On a small symbol only.
        static let problem = Color(nsColor: .systemRed)
    }

    enum Space {
        static let s4: CGFloat = 4, s8: CGFloat = 8, s12: CGFloat = 12, s16: CGFloat = 16, s20: CGFloat = 20, s24: CGFloat = 24
    }

    enum Radius {
        /// Your message in a thread, text fields in panels.
        static let bubble: CGFloat = 10
        /// The ask panel and the card.
        static let panel: CGFloat = 14
    }

    enum Size {
        /// Ask panel, card and thread, always.
        static let width: CGFloat = 400
        static let ask: CGFloat = 48
        static let cardMax: CGFloat = 420
        static let threadMax: CGFloat = 520
        /// Header and footer of the card.
        static let bar: CGFloat = 36
        static let dot: CGFloat = 8
        static let hairline: CGFloat = 0.5
        /// Hit area of any control, at least.
        static let control: CGFloat = 28
    }

    enum Motion {
        /// The system's Reduce Motion setting.
        static var reduce: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
        /// Opacity 0 to 1, ease-out, with scale 0.98 to 1 (opacity only with Reduce Motion).
        static let appear: TimeInterval = 0.16
        static let appearScale: CGFloat = 0.98
        /// Opacity to 0, ease-in.
        static let leave: TimeInterval = 0.12
        /// The card's height as words arrive, opening the thread. With Reduce Motion the frame is set at once.
        /// 15.4 gives a spring (response 0.35, damping 0.86); a window frame takes no spring, so its twin is this
        /// ease-out of the same length, with no overshoot.
        static let growDuration: TimeInterval = 0.35
        static let growCurve = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1)
        /// One 1.6 s cycle, opacity 1 to 0.4 and back: thinking.
        static let breathe = Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)
    }
}

/// The blurred material of the ask panel and the card, always in its active look: Phew is never the active app,
/// and a material that follows the window's state would draw in its dull inactive look (15.1).
struct Surface: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

extension View {
    /// `Surface` in the panel's rounded shape with its hairline. Increase Contrast: the window background with a
    /// 1-point border instead (15.4).
    func surface() -> some View { modifier(SurfaceStyle()) }
}

private struct SurfaceStyle: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Design.Radius.panel)
        let high = contrast == .increased
        content
            .background { if high { Color(nsColor: .windowBackgroundColor) } else { Surface() } }
            .clipShape(shape)
            .overlay(shape.strokeBorder(high ? Design.Ink.secondary : Design.Ink.hairline,
                                        lineWidth: high ? 1 : Design.Size.hairline))
    }
}

/// Phew, as an 8-point dot in his colour: still when he is done, breathing while he thinks.
struct PresenceDot: View {
    var breathing = false
    @State private var dim = false

    var body: some View {
        Circle()
            .fill(Design.Ink.accent)
            .frame(width: Design.Size.dot, height: Design.Size.dot)
            .opacity(breathing && dim ? 0.4 : 1)
            // Opacity only, so the same with Reduce Motion.
            .animation(breathing ? Design.Motion.breathe : .default, value: dim)
            .onAppear { dim = breathing }
            .onChange(of: breathing) { dim = breathing }
            .accessibilityElement()
            .accessibilityLabel(breathing ? "Thinking" : "Phew")
    }
}
