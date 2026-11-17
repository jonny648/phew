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
        /// Licence text.
        static let mono = Font.system(size: 12, design: .monospaced)
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

    /// The brand's colours, docs/22-brand.md 22.4. In the app "ink" is the label colour; these are for the mark on
    /// black (the notch), the app icon and the active line.
    enum Brand {
        static let ink = NSColor(srgbRed: 0x14 / 255, green: 0x14 / 255, blue: 0x14 / 255, alpha: 1)  // #141414
        static let shellWhite = NSColor(srgbRed: 0xF4 / 255, green: 0xEF / 255, blue: 0xE6 / 255, alpha: 1)  // #F4EFE6
        static let white = NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)  // #FFFFFF
        /// A third ground, for ink only: never orange on it.
        static let warmGrey = NSColor(srgbRed: 0xD9 / 255, green: 0xD2 / 255, blue: 0xC4 / 255, alpha: 1)  // #D9D2C4
        /// The active line; with Increase Contrast on light grounds, `orangeHigh`. Never text, never a field.
        static let orange = NSColor(srgbRed: 0xF2 / 255, green: 0x54 / 255, blue: 0x1B / 255, alpha: 1)  // #F2541B
        static let orangeHigh = NSColor(srgbRed: 0xD9 / 255, green: 0x44 / 255, blue: 0x0F / 255, alpha: 1)  // #D9440F
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
        /// The row under the ask field: the hint, or one grey line.
        static let hintRow: CGFloat = 24
        static let cardMax: CGFloat = 420
        static let threadMax: CGFloat = 520
        /// Header and footer of the card.
        static let bar: CGFloat = 36
        /// The small mark on the ask panel and the card, and the mark at the notch (22.6).
        static let mark: CGFloat = 16
        static let notchMark: CGFloat = 22
        static let hairline: CGFloat = 0.5
        /// The footer while he acts.
        static let actingBar: CGFloat = 44
        /// Consent screens and first run.
        static let consentWidth: CGFloat = 440
        /// Small panels opened from the menu; the licences are wider.
        static let panelWidth: CGFloat = 420
        static let licenceWidth: CGFloat = 560
        /// A small panel with a list, and the same panel with nothing in it.
        static let panelHeight: CGFloat = 320
        static let emptyPanelHeight: CGFloat = 160
        /// The import panel for Claude's export and its grouped tick list: about 12 rows, then it scrolls.
        static let tallPanelHeight: CGFloat = 560
        /// A row of a small panel or of first run, at least.
        static let row: CGFloat = 36
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
        /// The shortcut held this long is a hold to talk (P6.1); released before, it is a press.
        static let hold: TimeInterval = 0.3
        /// The notch growing while he listens (P6), as the system grows its own: a spring, response 0.38, damping
        /// 0.8; back into it the same way, or quicker on Escape (response 0.25, damping 0.9). The content follows the
        /// shape by `notchDelay`. Sent: the dot swells and settles, `pulse` each way, before the shape goes back.
        static let notch = Animation.spring(response: 0.38, dampingFraction: 0.8)
        static let notchQuick = Animation.spring(response: 0.25, dampingFraction: 0.9)
        static let notchDelay: TimeInterval = 0.08
        static let pulse: TimeInterval = 0.1
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
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Design.Text.strong)
            .foregroundStyle(Color(nsColor: .windowBackgroundColor))
            .padding(.horizontal, Design.Space.s16)
            .frame(minHeight: Design.Size.control)
            .background(Design.Ink.primary, in: RoundedRectangle(cornerRadius: Design.Radius.chip))
            .opacity(!enabled ? 0.35 : configuration.isPressed ? 0.8 : 1)
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

/// A key cap, as the shortcut is written: `tag` on `fill`, radius 6.
struct Keycap: View {
    let key: String

    var body: some View {
        Text(key)
            .font(Design.Text.tag)
            .foregroundStyle(Design.Ink.secondary)
            .padding(.horizontal, Design.Space.s4)
            .padding(.vertical, 2)
            .background(Design.Ink.fill, in: RoundedRectangle(cornerRadius: Design.Radius.chip))
    }
}

/// A row of a small panel (15.5 E): its text in `body`, an optional second line in `small`, `ink2`, its controls on
/// the right, a hairline under it. At least 36 high.
struct Row<Trailing: View>: View {
    let title: String
    var detail: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: Design.Space.s12) {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: title).font(Design.Text.body).foregroundStyle(Design.Ink.primary).lineLimit(2)
                if let detail { Text(verbatim: detail).font(Design.Text.small).foregroundStyle(Design.Ink.secondary) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(.vertical, Design.Space.s4)
        .frame(minHeight: Design.Size.row)
        .overlay(alignment: .bottom) { Design.Ink.hairline.frame(height: Design.Size.hairline) }
    }
}

/// A plain text button in `ink2`: the second, rarer action of a row ("Delete now"), so it does not look equal to the first.
struct TextButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Design.Text.body)
            .foregroundStyle(Design.Ink.secondary)
            .frame(minHeight: Design.Size.control)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(Rectangle())
    }
}

/// The help line of a small panel in `small`, `ink2`; a problem takes its place, with the `problem` symbol.
struct HelpLine: View {
    let text: String
    var problem: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Design.Space.s4) {
            if problem != nil { Image(systemName: "exclamationmark.circle").foregroundStyle(Design.Ink.problem) }
            Text(verbatim: problem ?? text).fixedSize(horizontal: false, vertical: true)
        }
        .font(Design.Text.small)
        .foregroundStyle(problem == nil ? Design.Ink.secondary : Design.Ink.primary)
    }
}

/// The body of a small panel with a list (15.5 E): the rows, then the help line at the bottom, 420 by 320. Empty:
/// one line in `body`, `ink2`, with the help line under it in the middle, and the panel shrinks to 160 high.
struct PanelList<Rows: View>: View {
    let isEmpty: Bool
    let emptyLine: String
    let help: String
    var problem: String?
    @ViewBuilder var rows: Rows

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Space.s12) {
            if isEmpty {
                VStack(spacing: Design.Space.s4) {
                    Text(verbatim: emptyLine).font(Design.Text.body).foregroundStyle(Design.Ink.secondary)
                    HelpLine(text: help, problem: problem).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView { VStack(spacing: 0) { rows } }
                HelpLine(text: help, problem: problem)
            }
        }
        .padding(Design.Space.s20)
        .frame(width: Design.Size.panelWidth, height: isEmpty ? Design.Size.emptyPanelHeight : Design.Size.panelHeight,
               alignment: .topLeading)
    }
}
