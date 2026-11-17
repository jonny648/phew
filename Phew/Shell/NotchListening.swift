import AppKit
import SwiftUI

/// Hold to talk, at the notch (P6, the owner's request of 16 November): while the shortcut is held a black shape grows
/// out of the notch, the way the system grows its own, with Phew's mark, a small level of the voice and the words as
/// he hears them. Without a notch, a black pill drops from under the menu bar's centre. A clear panel that every
/// click goes through, sized to the shape only, never key. What it shows comes from `Talk.Look`.
@MainActor
final class NotchListening {
    let model = NotchModel()
    private var panel: NSPanel?
    /// Counts holds, so a late close of an earlier hold leaves a newer one alone.
    private var shows = 0
    /// The debug check draws it as on a screen without a notch.
    var noNotch = false

    func show(_ look: Talk.Look) {
        switch look {
        case .listening: open()
        case .partial(let words): model.hear(words)
        case .level(let level): model.take(level)
        case .line(let line): withAnimation(Design.Motion.notch) { model.say(line) }
        case .sending: close(.sent)
        case .cancelled: close(.cancelled)
        case .closed: close(.normal)
        }
    }

    private func open() {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main else { return }
        let notch = noNotch ? nil : NotchGeometry.notch(frame: screen.frame, safeTop: screen.safeAreaInsets.top,
                                                          left: screen.auxiliaryTopLeftArea, right: screen.auxiliaryTopRightArea)
        let geometry = NotchGeometry(frame: screen.frame, visible: screen.visibleFrame, notch: notch)
        let reduce = Design.Motion.reduce
        shows += 1
        model.reset()
        let panel = panel ?? Self.makePanel()
        self.panel = panel
        panel.setFrame(geometry.window, display: false)
        panel.contentView = NSHostingView(rootView: NotchView(model: model, geometry: geometry, reduce: reduce))
        panel.orderFrontRegardless()  // never key: the keys stay with the user's app
        panel.displayIfNeeded()  // drawn closed first, so the growing shows
        DispatchQueue.main.async { [model] in
            withAnimation(reduce ? .easeOut(duration: Design.Motion.appear) : Design.Motion.notch) { model.grow() }
        }
        shellLog("notch: listening, notch \(notch != nil), reduce motion \(reduce), placed \(panel.frame == geometry.window), window \(panel.windowNumber)")
    }

    /// Sent: the mark swells once, then the shape goes back into the notch. Escape: the same, quicker, no pulse.
    private func close(_ end: NotchModel.End) {
        guard model.open, model.ended == nil else { return }
        let mine = shows
        let reduce = Design.Motion.reduce
        let shrink = { [weak self] in
            guard let self, shows == mine else { return }
            let motion = reduce ? .easeIn(duration: Design.Motion.leave) : end == .cancelled ? Design.Motion.notchQuick : Design.Motion.notch
            withAnimation(motion, completionCriteria: .logicallyComplete) { self.model.end(end) } completion: { [weak self] in
                guard let self, shows == mine else { return }  // a new hold took the panel
                panel?.orderOut(nil)
                panel?.contentView = nil
            }
        }
        shellLog("notch: closing, \(end)")
        guard end == .sent, !reduce else { return shrink() }
        model.ended = .sent  // a second close during the pulse does nothing
        withAnimation(.easeOut(duration: Design.Motion.pulse)) { model.pulse = true } completion: { [model] in
            withAnimation(.easeIn(duration: Design.Motion.pulse)) { model.pulse = false }
            shrink()
        }
    }

    private static func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = true  // the menu bar items beside it keep their clicks
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.appearance = NSAppearance(named: .darkAqua)  // white on black, whatever the menu bar
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)  // above the menu bar and its icons
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        return panel
    }
}

/// What the shape shows. Numbers and the words on screen only; nothing here is logged or kept after the hold.
@MainActor
final class NotchModel: ObservableObject {
    enum End: Equatable { case sent, cancelled, normal }
    @Published private(set) var open = false
    @Published fileprivate(set) var ended: End?
    @Published private(set) var words = ""
    @Published private(set) var line: String?
    /// The voice's loudness, smoothed, 0...1.
    @Published private(set) var level = 0.0
    /// Level readings so far: gives the bars a little variety.
    @Published private(set) var beat = 0
    @Published fileprivate(set) var pulse = false

    /// Bars and words move only while listening, not under the problem line.
    var listening: Bool { open && ended == nil && line == nil }
    /// Nothing heard yet, or a pause: the bars rest.
    var silent: Bool { level < 0.08 }

    func reset() { open = false; ended = nil; words = ""; line = nil; level = 0; beat = 0; pulse = false }
    func grow() { open = true }
    func hear(_ words: String) { if listening { self.words = words } }
    func take(_ reading: Double) {
        guard listening else { return }
        level = Self.smooth(level, reading)
        beat += 1
    }
    func say(_ line: String) {
        guard open, ended == nil else { return }
        self.line = line
        level = 0
    }
    func end(_ how: End) {
        open = false
        ended = how
    }

    /// Rises fast, falls slower, so the bars follow the voice without flicker.
    nonisolated static func smooth(_ old: Double, _ new: Double) -> Double { old + (new - old) * (new > old ? 0.6 : 0.25) }

    /// With Reduce Motion the shape does not grow and cross-fades instead; the pill without a notch also fades, since
    /// there is no notch for it to come out of.
    nonisolated static func style(reduce: Bool, notched: Bool) -> (grows: Bool, fades: Bool) { (!reduce, reduce || !notched) }
}

/// Where the shape sits, AppKit screen coordinates. Pure, so the tests can make up screens.
struct NotchGeometry: Equatable {
    /// Before it grows: the notch itself, or a small pill under the menu bar.
    var start: CGRect
    /// Grown while listening, and taller for the problem line.
    var grown: CGRect
    var tall: CGRect
    /// The notch's height: the band beside the camera that holds the mark and the bars. 0 without a notch.
    var band: CGFloat
    /// The panel: the grown shape and its shoulders, nothing more; whole points, as AppKit places windows, so the
    /// shape stays centred on the notch.
    var window: CGRect

    /// How far the shape grows past each side of the notch, its row of words, and its taller row for two lines.
    static let ear: CGFloat = 56, row: CGFloat = 32, tallRow: CGFloat = 44
    /// The small curves where the grown shape meets the top of the screen.
    static let shoulder: CGFloat = 6
    static let pillWidth: CGFloat = 320, pillHeight: CGFloat = 36, tallPill: CGFloat = 52

    /// The notch from the screen's frame, the safe area's top inset and the two areas beside it. Nil without one.
    static func notch(frame: CGRect, safeTop: CGFloat, left: CGRect?, right: CGRect?) -> CGRect? {
        guard safeTop > 0, let left, let right, left.width > 0, right.width > 0 else { return nil }
        let minX = frame.minX + left.width, maxX = frame.maxX - right.width
        guard maxX > minX else { return nil }
        return CGRect(x: minX, y: frame.maxY - safeTop, width: maxX - minX, height: safeTop)
    }

    init(frame: CGRect, visible: CGRect, notch: CGRect?) {
        if let notch {
            let width = min(notch.width + 2 * Self.ear, frame.width - 2 * Self.shoulder)
            func below(_ row: CGFloat) -> CGRect {
                CGRect(x: notch.midX - width / 2, y: notch.minY - row, width: width, height: notch.height + row)
            }
            start = notch
            grown = below(Self.row)
            tall = below(Self.tallRow)
            band = notch.height
            window = tall.union(notch).insetBy(dx: -Self.shoulder, dy: 0).integral
        } else {
            let width = min(Self.pillWidth, frame.width - 2 * Design.Space.s16)
            let top = visible.maxY - Design.Space.s8  // under the menu bar, or the top in full screen
            func pill(_ height: CGFloat) -> CGRect { CGRect(x: frame.midX - width / 2, y: top - height, width: width, height: height) }
            start = CGRect(x: frame.midX - width / 4, y: top - Self.pillHeight / 2, width: width / 2, height: Self.pillHeight / 2)
            grown = pill(Self.pillHeight)
            tall = pill(Self.tallPill)
            band = 0
            window = tall.union(start).integral
        }
    }
}

/// The black shape: the notch's own outline (square top, rounded bottom corners, small shoulders into the top edge
/// once grown), or a pill without a notch.
struct NotchShape: Shape {
    var shoulder: CGFloat
    var pill: Bool

    var animatableData: CGFloat {
        get { shoulder }
        set { shoulder = newValue }
    }

    func path(in rect: CGRect) -> Path {
        if pill { return RoundedRectangle(cornerRadius: min(rect.height / 2, 18), style: .continuous).path(in: rect) }
        let body = rect.insetBy(dx: shoulder, dy: 0)
        let r = min(18, body.height * 0.3, body.width / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: body.minX, y: rect.minY + shoulder), control: CGPoint(x: body.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: body.minX, y: body.maxY - r))
        path.addQuadCurve(to: CGPoint(x: body.minX + r, y: body.maxY), control: CGPoint(x: body.minX, y: body.maxY))
        path.addLine(to: CGPoint(x: body.maxX - r, y: body.maxY))
        path.addQuadCurve(to: CGPoint(x: body.maxX, y: body.maxY - r), control: CGPoint(x: body.maxX, y: body.maxY))
        path.addLine(to: CGPoint(x: body.maxX, y: rect.minY + shoulder))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: body.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

/// The shape at its size now, the content laid out at the grown size and clipped by it, in a panel the size of the
/// grown shape.
struct NotchView: View {
    @ObservedObject var model: NotchModel
    let geometry: NotchGeometry
    let reduce: Bool

    var body: some View {
        let notched = geometry.band > 0
        let style = NotchModel.style(reduce: reduce, notched: notched)
        let full = model.line == nil ? geometry.grown : geometry.tall
        let rect = model.open || !style.grows ? full : geometry.start
        let shoulder = notched && (model.open || !style.grows) ? NotchGeometry.shoulder : 0
        let shape = NotchShape(shoulder: shoulder, pill: !notched)
        Color.clear
            .frame(width: rect.width + 2 * shoulder, height: rect.height)
            .overlay(alignment: .top) {
                NotchContent(model: model, band: geometry.band)
                    .frame(width: full.width, height: full.height)
                    .opacity(model.open ? 1 : 0)
                    .animation(model.open ? .easeOut(duration: Design.Motion.appear).delay(Design.Motion.notchDelay)
                                          : .easeIn(duration: model.ended == .cancelled ? Design.Motion.leave / 2 : Design.Motion.leave),
                               value: model.open)
                    .frame(width: rect.width, height: rect.height, alignment: .top)
                    .clipped()  // the words never show past the shape while it shrinks
            }
            .background(shape.fill(.black))
            .clipShape(shape)
            .opacity(style.fades ? (model.open ? 1 : 0) : 1)
            .padding(.top, geometry.window.maxY - rect.maxY)
            .frame(width: geometry.window.width, height: geometry.window.height, alignment: .top)
            .environment(\.colorScheme, .dark)  // white on black, whatever the menu bar
    }
}

/// Mark, level and words. Beside the camera on a notch (mark left, level right, words under it); in one row on the pill.
struct NotchContent: View {
    @ObservedObject var model: NotchModel
    let band: CGFloat

    var body: some View {
        if band > 0 {
            VStack(spacing: 0) {
                HStack {
                    mark
                    Spacer()
                    LevelBars(level: model.level, beat: model.beat)
                }
                .padding(.horizontal, Design.Space.s20)
                .frame(height: band)
                words.padding(.horizontal, Design.Space.s20).frame(maxHeight: .infinity)
                    .padding(.bottom, Design.Space.s4)
            }
        } else {
            HStack(spacing: Design.Space.s12) {
                mark
                words
                if model.line == nil { LevelBars(level: model.level, beat: model.beat) }
            }
            .padding(.horizontal, Design.Space.s16)
        }
    }

    private var mark: some View {
        // Closing, he settles back down as the shape goes; the whole panel is gone at rest.
        BrandMark(state: Brand.atNotch(open: model.open, problem: model.line != nil) ?? .resting,
                  size: Design.Size.notchMark, onBlack: true)
            .scaleEffect(model.pulse ? 1.2 : 1)
    }

    @ViewBuilder private var words: some View {
        if let line = model.line {
            Text(verbatim: line)
                .font(Design.Text.small)
                .foregroundStyle(Design.Ink.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(verbatim: model.words.isEmpty ? "Listening" : model.words)
                .font(Design.Text.ask)
                .foregroundStyle(model.words.isEmpty ? Design.Ink.tertiary : Design.Ink.secondary)
                .lineLimit(1)
                .truncationMode(.head)  // the newest words stay in view
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Five rounded bars that follow the voice; resting short when it is quiet.
struct LevelBars: View {
    let level: Double
    let beat: Int
    static let weights = [0.55, 0.85, 1, 0.75, 0.5]
    static let rest: CGFloat = 3, tall: CGFloat = 16

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Self.weights.indices, id: \.self) { i in
                Capsule().fill(Design.Ink.primary).frame(width: 3, height: Self.height(i, level: level, beat: beat))
            }
        }
        .frame(height: Self.tall)
        .animation(.easeOut(duration: 0.1), value: beat)  // the readings come about 20 a second; this fills between
        .accessibilityHidden(true)
    }

    static func height(_ bar: Int, level: Double, beat: Int) -> CGFloat {
        let wobble = 0.7 + 0.3 * abs(sin(Double(beat) * (0.9 + Double(bar) * 0.37)))
        return rest + (tall - rest) * CGFloat(min(max(level, 0), 1) * weights[bar] * wobble)
    }
}
