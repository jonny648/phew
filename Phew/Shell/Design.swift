import AppKit
import QuartzCore
import SwiftUI

/// Phew's look, the tokens of docs/15-design.md 15.4. Change a value here and it changes everywhere.
/// Only what is in use so far; the menu and the small panels add theirs when they are restyled.
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
        /// Heading of a consent screen.
        static let title = Font.title3.weight(.semibold)
        /// Key caps, the "can't be undone" tag.
        static let tag = Font.caption2.weight(.medium)
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
        /// The pointer and the ring: one value in both modes, since they sit on the user's app, not on Phew's.
        static let accentOnScreen = Color(nsColor: onScreen)
        static let onScreen = NSColor(srgbRed: 0xF2 / 255, green: 0x54 / 255, blue: 0x1B / 255, alpha: 1)  // #F2541B
        /// On a small symbol only.
        static let ok = Color(nsColor: .systemGreen)
        static let problem = Color(nsColor: .systemRed)
    }

    enum Space {
        static let s4: CGFloat = 4, s8: CGFloat = 8, s12: CGFloat = 12, s16: CGFloat = 16, s20: CGFloat = 20, s24: CGFloat = 24
    }

    enum Radius {
        /// Key caps, tags, buttons.
        static let chip: CGFloat = 6
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
        /// The footer while he acts.
        static let actingBar: CGFloat = 44
        /// Consent screens.
        static let consentWidth: CGFloat = 440
        /// Hit area of any control, at least; the height of a button.
        static let control: CGFloat = 28
    }

    enum Motion {
        /// The system's Reduce Motion setting, or the debug checks' `--debug-reduce-motion`.
        static var reduce: Bool { forceReduce || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
        static var forceReduce = false
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
        /// One 1.6 s cycle, opacity 1 to 0.4 and back (on the pointer also scale 1 to 1.12): thinking, looking, acting.
        static let breatheHalf: TimeInterval = 0.8
        static let breathe = Animation.easeInOut(duration: breatheHalf).repeatForever(autoreverses: true)
        /// The pointer between spots: a spring, response 0.5, damping 0.9, as Core Animation takes it.
        static func travel() -> CASpringAnimation {
            let spring = CASpringAnimation(keyPath: "position")
            spring.mass = 1
            spring.stiffness = 158
            spring.damping = 22.6
            spring.duration = spring.settlingDuration
            return spring
        }
        /// Each action he takes: the pointer 1 to 0.88 to 1; the ring fills with accent at 25% over `pressFill`.
        static let press: TimeInterval = 0.18
        static let pressFill: TimeInterval = 0.3
        /// A step or action marked done: opacity 0 to 1, scale 0.6 to 1 (opacity only with Reduce Motion).
        static let tick: TimeInterval = 0.12
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

/// The tick of a done step or action, in `ok`, played in with `tick` when it first shows.
struct TickMark: View {
    @State private var shown = false

    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Design.Ink.ok)
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown || Design.Motion.reduce ? 1 : 0.6)
            .onAppear { withAnimation(.easeOut(duration: Design.Motion.tick)) { shown = true } }
            .accessibilityLabel("Done")
    }
}

/// The main button: ink fill, panel text (black on light, white on dark). The accent is never a button.
struct MainButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Design.Text.strong)
            .foregroundStyle(Color(nsColor: .windowBackgroundColor))
            .padding(.horizontal, Design.Space.s16)
            .frame(minHeight: Design.Size.control)
            .background(Design.Ink.primary, in: RoundedRectangle(cornerRadius: Design.Radius.chip))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(Rectangle())
    }
}

/// A quiet button on `fill`: Stop, Not now.
struct QuietButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Design.Text.strong)
            .foregroundStyle(Design.Ink.primary)
            .padding(.horizontal, Design.Space.s12)
            .frame(minHeight: Design.Size.control)
            .background(Design.Ink.fill, in: RoundedRectangle(cornerRadius: Design.Radius.chip))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Rectangle())
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
