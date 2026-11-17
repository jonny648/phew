import AppKit
import SwiftUI

/// The brand of docs/22-brand.md: the mark (the top of an eggshell in one heavy line), the name `phew!` as its outline,
/// and the states the shell alone tells. Pure where it can be, so the tests read the numbers of the sheet.
/// Also compiled by `Tools/make-icon.swift` with `Design.swift`, so it uses nothing else of the app.
enum Brand {
    // MARK: 22.1 The mark

    /// Both drawings sit in a box of 120 by 120; one line of 11, round joins and ends.
    static let box: CGFloat = 120
    static let line: CGFloat = 11
    /// The mark, from 32 points up.
    static let markData = "M 26 82 C 23 52 35 20 56 20 C 80 20 97 50 95 82 L 89.42 73.93 Q 86.00 69.00 82.58 73.93 L 80.42 77.07 Q 77.00 82.00 73.56 77.08 L 66.44 66.92 Q 63.00 62.00 59.56 66.92 L 52.44 77.08 Q 49.00 82.00 44.54 77.99 L 43.46 77.01 Q 39.00 73.00 34.07 76.42 L 26.00 82.00 Z"
    /// The small mark, at 24, 20 and 16 points: two notches.
    static let smallMarkData = "M 26 82 C 23 52 35 20 56 20 C 80 20 97 50 95 82 L 78.18 66.71 Q 73.00 62.00 68.05 66.95 L 57.95 77.05 Q 53.00 82.00 47.66 77.48 L 45.34 75.52 Q 40.00 71.00 34.50 75.32 L 26.00 82.00 Z"
    /// Under this many points the small mark is drawn instead.
    static let fullFrom: CGFloat = 32
    static let mark = cgPath(markData)
    static let smallMark = cgPath(smallMarkData)
    static func mark(small: Bool) -> CGPath { small ? smallMark : mark }

    /// Where the line's ink lies in the box: the stroked outline's bounds (80 by 73 for both drawings).
    static func ink(_ path: CGPath) -> CGRect {
        path.copy(strokingWithWidth: line, lineCap: .round, lineJoin: .round, miterLimit: 10).boundingBoxOfPath
    }

    // MARK: 22.2 The name

    /// `phew!` in Outfit Medium at 100 points, as its outline (the app ships no font): five signs, non-zero winding,
    /// y down, 255.21 wide and 92 high, baseline at y = 72.
    static let nameSize = CGSize(width: 255.21, height: 92)
    static let nameBaseline: CGFloat = 72
    /// Small-letter height, tall letters and stem of Outfit Medium at 100 points.
    static let nameX: CGFloat = 48, nameTall: CGFloat = 72, nameStem: CGFloat = 11
    static let nameData = [
        // p
        "M 25.7 73 C 22.03 73 18.77 72.23 15.9 70.7 C 13.03 69.1 10.77 66.93 9.1 64.2 C 7.5 61.47 6.7 58.37 6.7 54.9 L 6.7 41.1 C 6.7 37.63 7.53 34.53 9.2 31.8 C 10.87 29.07 13.13 26.93 16 25.4 C 18.87 23.8 22.1 23 25.7 23 C 30.03 23 33.93 24.13 37.4 26.4 C 40.93 28.6 43.7 31.6 45.7 35.4 C 47.77 39.13 48.8 43.37 48.8 48.1 C 48.8 52.77 47.77 57 45.7 60.8 C 43.7 64.53 40.93 67.5 37.4 69.7 C 33.93 71.9 30.03 73 25.7 73 Z M 0 92 L 0 24 L 11 24 L 11 36.9 L 9.1 48.6 L 11 60.2 L 11 92 L 0 92 Z M 23.9 62.6 C 26.57 62.6 28.9 62 30.9 60.8 C 32.97 59.53 34.57 57.8 35.7 55.6 C 36.9 53.4 37.5 50.87 37.5 48 C 37.5 45.13 36.9 42.6 35.7 40.4 C 34.57 38.2 32.97 36.5 30.9 35.3 C 28.9 34.03 26.57 33.4 23.9 33.4 C 21.23 33.4 18.87 34.03 16.8 35.3 C 14.73 36.5 13.13 38.2 12 40.4 C 10.87 42.6 10.3 45.13 10.3 48 C 10.3 50.87 10.87 53.4 12 55.6 C 13.13 57.8 14.73 59.53 16.8 60.8 C 18.87 62 21.23 62.6 23.9 62.6 Z",
        // h
        "M 90.91 72 L 90.91 44.3 C 90.91 41.1 89.87 38.47 87.81 36.4 C 85.81 34.33 83.21 33.3 80.01 33.3 C 77.87 33.3 75.97 33.77 74.31 34.7 C 72.64 35.63 71.34 36.93 70.41 38.6 C 69.47 40.27 69.01 42.17 69.01 44.3 L 64.71 41.9 C 64.71 38.23 65.51 35 67.11 32.2 C 68.71 29.33 70.91 27.1 73.71 25.5 C 76.57 23.83 79.77 23 83.31 23 C 86.91 23 90.11 23.8 92.91 25.4 C 95.71 27 97.91 29.23 99.51 32.1 C 101.11 34.9 101.91 38.17 101.91 41.9 L 101.91 72 L 90.91 72 Z M 58.01 72 L 58.01 0 L 69.01 0 L 69.01 72 L 58.01 72 Z",
        // e
        "M 135.39 73 C 130.59 73 126.25 71.93 122.39 69.8 C 118.59 67.6 115.55 64.6 113.29 60.8 C 111.09 57 109.99 52.73 109.99 48 C 109.99 43.27 111.09 39.03 113.29 35.3 C 115.49 31.5 118.45 28.5 122.19 26.3 C 125.99 24.1 130.19 23 134.79 23 C 139.25 23 143.19 24.03 146.59 26.1 C 150.05 28.17 152.75 31 154.69 34.6 C 156.69 38.2 157.69 42.3 157.69 46.9 C 157.69 47.7 157.62 48.53 157.49 49.4 C 157.42 50.2 157.29 51.1 157.09 52.1 L 117.69 52.1 L 117.69 43.1 L 151.39 43.1 L 147.29 46.7 C 147.15 43.77 146.59 41.3 145.59 39.3 C 144.59 37.3 143.15 35.77 141.29 34.7 C 139.49 33.63 137.25 33.1 134.59 33.1 C 131.79 33.1 129.35 33.7 127.29 34.9 C 125.22 36.1 123.62 37.8 122.49 40 C 121.35 42.13 120.79 44.7 120.79 47.7 C 120.79 50.7 121.39 53.33 122.59 55.6 C 123.79 57.87 125.49 59.63 127.69 60.9 C 129.89 62.1 132.42 62.7 135.29 62.7 C 137.75 62.7 140.02 62.27 142.09 61.4 C 144.22 60.53 146.02 59.27 147.49 57.6 L 154.49 64.7 C 152.15 67.43 149.32 69.5 145.99 70.9 C 142.65 72.3 139.12 73 135.39 73 Z",
        // w
        "M 179.92 72 L 160.62 24 L 172.02 24 L 185.02 58.9 L 181.62 59 L 194.32 24 L 200.72 24 L 213.42 59 L 210.02 58.9 L 223.02 24 L 234.42 24 L 215.12 72 L 208.72 72 L 195.72 38.8 L 199.32 38.8 L 186.32 72 L 179.92 72 Z",
        // !
        "M 243.71 48.8 L 242.21 0 L 253.71 0 L 252.21 48.8 L 243.71 48.8 Z M 247.91 73 C 245.78 73 244.01 72.3 242.61 70.9 C 241.28 69.43 240.61 67.67 240.61 65.6 C 240.61 63.47 241.28 61.7 242.61 60.3 C 244.01 58.9 245.78 58.2 247.91 58.2 C 250.04 58.2 251.78 58.9 253.11 60.3 C 254.51 61.7 255.21 63.47 255.21 65.6 C 255.21 67.67 254.51 69.43 253.11 70.9 C 251.78 72.3 250.04 73 247.91 73 Z",
    ]
    static let name: CGPath = {
        let all = CGMutablePath()
        for sign in nameData { all.addPath(cgPath(sign)) }
        return all
    }()

    // MARK: The path reader

    /// One piece of an SVG path, absolute coordinates.
    enum Segment: Equatable {
        case move(CGPoint), line(CGPoint), quad(CGPoint, CGPoint), curve(CGPoint, CGPoint, CGPoint), close
    }

    /// Reads the absolute M, L, Q, C and Z of the sheet's paths, nothing more: they are constants, so anything else
    /// is a mistake in this file and stops at once.
    static func segments(_ data: String) -> [Segment] {
        var tokens = data.split(separator: " ").map(String.init)[...]
        func point() -> CGPoint {
            let x = Double(tokens.removeFirst()), y = Double(tokens.removeFirst())
            precondition(x != nil && y != nil, "Brand: a number was expected in the path")
            return CGPoint(x: x!, y: y!)
        }
        var out: [Segment] = []
        while let command = tokens.popFirst() {
            switch command {
            case "M": out.append(.move(point()))
            case "L": out.append(.line(point()))
            case "Q": let c = point(); out.append(.quad(c, point()))
            case "C": let c1 = point(), c2 = point(); out.append(.curve(c1, c2, point()))
            case "Z": out.append(.close)
            default: preconditionFailure("Brand: path command \(command) is not read")
            }
        }
        return out
    }

    static func cgPath(_ data: String) -> CGPath {
        let path = CGMutablePath()
        for segment in segments(data) {
            switch segment {
            case .move(let p): path.move(to: p)
            case .line(let p): path.addLine(to: p)
            case .quad(let c, let p): path.addQuadCurve(to: p, control: c)
            case .curve(let c1, let c2, let p): path.addCurve(to: p, control1: c1, control2: c2)
            case .close: path.closeSubpath()
            }
        }
        return path
    }

    // MARK: 22.5 The states

    enum State: CaseIterable, Equatable {
        case resting, listening, thinking, acting, pointing, done, couldNot, waiting
    }

    /// Whole; a gap travelling round (thinking); the same gap held still (Reduce Motion, the menu bar); broken.
    enum Line: Equatable { case whole, travelling, stillGap, broken }
    /// The line alone, or the shell filled ("full").
    enum Look: Equatable { case line, full }
    /// Ink (the label colour, or shell white on black) or orange. Never both in one mark.
    enum Colour: Equatable { case ink, orange }

    /// In box units and degrees. `lift` up; `tip` about (60, 82), positive toward the side he points to (clockwise);
    /// `shift` that way.
    struct Pose: Equatable {
        var lift: CGFloat = 0
        var tip: Double = 0
        var shift: CGFloat = 0
        static let down = Pose()
    }

    struct Drawing: Equatable {
        var pose: Pose
        var line: Line
        var look: Look
        var colour: Colour
    }

    /// Lift is 1.5 line weights.
    static let lift: CGFloat = 1.5 * line
    /// The point a tip turns about, as a unit point of the box.
    static let pivot = UnitPoint(x: 60 / box, y: 82 / box)
    /// The travelling gap: 44 of a line of 240, once round in 1.6 s. Broken: dashes 15, gaps 19.
    static let gap: CGFloat = 44.0 / 240
    static let round: TimeInterval = 1.6
    static let dashes: [CGFloat] = [15, 19]
    /// Where the still gap sits, as a share of the line from the left foot: on the rise of the dome.
    static let stillGapAt: CGFloat = 0.2

    /// The table of 22.5. Set A in colour; set B is the menu bar's one colour, where full stands for orange and
    /// nothing moves (the menu bar icon never animates, 15.5 D): no pose, the gap held still. Reduce Motion: no
    /// lift, no tip, no travelling gap.
    static func drawing(_ state: State, setB: Bool = false, reduceMotion: Bool = false) -> Drawing {
        let up = Pose(lift: lift)
        var d: Drawing
        switch state {
        case .resting: d = Drawing(pose: .down, line: .whole, look: .line, colour: .ink)
        case .listening: d = Drawing(pose: Pose(lift: lift, tip: -9), line: .whole, look: .line, colour: .ink)
        case .thinking: d = Drawing(pose: up, line: .travelling, look: .line, colour: .ink)
        case .acting: d = Drawing(pose: up, line: .whole, look: .line, colour: .orange)
        case .pointing: d = Drawing(pose: Pose(lift: lift, tip: 10, shift: 5), line: .whole, look: .line, colour: .orange)
        case .done: d = Drawing(pose: .down, line: .whole, look: .full, colour: .orange)
        case .couldNot: d = Drawing(pose: Pose(tip: 16), line: .broken, look: .line, colour: .ink)
        case .waiting: d = Drawing(pose: .down, line: .whole, look: .line, colour: .orange)
        }
        if setB {
            d = Drawing(pose: .down, line: d.line == .travelling ? .stillGap : d.line,
                        look: d.colour == .orange ? .full : .line, colour: .ink)
        }
        if reduceMotion {
            d.pose = .down
            if d.line == .travelling { d.line = .stillGap }
        }
        return d
    }

    /// The state's word, for VoiceOver and beside the mark.
    static func word(_ state: State) -> String {
        switch state {
        case .resting: "Phew"
        case .listening: "Listening"
        case .thinking: "Thinking"
        case .acting: "Acting"
        case .pointing: "Pointing"
        case .done: "Done"
        case .couldNot: "Could not"
        case .waiting: "A result waits"
        }
    }

    // MARK: The one mapping from the app's moments

    /// What is happening in the app, as the surfaces know it. Each surface fills what it has.
    struct Moment: Equatable {
        /// The shortcut held to talk.
        var holding = false
        /// A model call runs for the card.
        var thinking = false
        /// A job acts on the Mac.
        var acting = false
        /// A guide's steps are on the card, the pointer at their targets.
        var pointing = false
        /// A problem line instead of an answer, or a hold that failed.
        var failed = false
        /// When the last answer finished; "done" shows for `doneHold`.
        var answeredAt: Date?
        /// Task results waiting in the menu bar.
        var waiting = 0
    }

    static let doneHold: TimeInterval = 2

    /// The brand state of a moment. The clock comes in, so the tests can move it.
    static func state(_ m: Moment, now: Date) -> State {
        if m.holding { return m.failed ? .couldNot : .listening }
        if m.acting { return .acting }
        if m.failed { return .couldNot }
        if m.thinking { return .thinking }
        if m.pointing { return .pointing }
        if let at = m.answeredAt, now >= at, now.timeIntervalSince(at) < doneHold { return .done }
        if m.waiting > 0 { return .waiting }
        return .resting
    }

    /// The notch: nothing drawn unless the shape is open, which is only while the shortcut is held.
    static func atNotch(open: Bool, problem: Bool) -> State? {
        open ? state(Moment(holding: true, failed: problem), now: .distantPast) : nil
    }

    /// The menu bar's three pictures: resting (line), acting (full), a result waits (full).
    static func inMenuBar(acting: Bool, waiting: Int) -> State {
        state(Moment(acting: acting, waiting: waiting), now: .distantPast)
    }

    // MARK: Colour

    /// 22.4: ink is the label colour, or shell white on black (the notch). Orange is the active line; with Increase
    /// Contrast on a light ground it is the darker orange.
    static func color(_ colour: Colour, onBlack: Bool, dark: Bool, highContrast: Bool) -> NSColor {
        switch colour {
        case .ink: onBlack ? Design.Brand.shellWhite : .labelColor
        case .orange: highContrast && !dark && !onBlack ? Design.Brand.orangeHigh : Design.Brand.orange
        }
    }

    // MARK: The menu bar picture

    /// The small mark at 16 points as a template image, line or full: the system colours it.
    static func menuImage(_ state: State) -> NSImage {
        let full = drawing(state, setB: true).look == .full
        let side: CGFloat = 16
        let image = NSImage(size: NSSize(width: side, height: side), flipped: true) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            let ink = Self.ink(smallMark)
            // Centred on its ink, so the line's round ends stay inside the 16 points.
            let scale = (side - 1) / max(ink.width, ink.height)
            context.translateBy(x: rect.midX - ink.midX * scale, y: rect.midY - ink.midY * scale)
            context.scaleBy(x: scale, y: scale)
            context.addPath(smallMark)
            context.setLineWidth(line)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.setFillColor(.black)
            context.setStrokeColor(.black)
            context.drawPath(using: full ? .fillStroke : .stroke)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = word(state)
        return image
    }
}

// MARK: Shapes

/// The mark or the small mark, its 120 box scaled to the rect's width.
/// With `gapAt`, the line leaves out `Brand.gap` of its length from there: one path, so one stroke paints it once.
struct MarkShape: Shape {
    var small = false
    var gapAt: CGFloat?

    func path(in rect: CGRect) -> Path {
        let k = rect.width / Brand.box
        let whole = Path(Brand.mark(small: small)).applying(CGAffineTransform(a: k, b: 0, c: 0, d: k, tx: rect.minX, ty: rect.minY))
        guard let start = gapAt else { return whole }
        let end = start + Brand.gap
        if end > 1 { return whole.trimmedPath(from: end - 1, to: start) }
        var path = whole.trimmedPath(from: end, to: 1)
        path.addPath(whole.trimmedPath(from: 0, to: start))
        return path
    }
}

/// The name `phew!`, its outline scaled to the rect's width. Filled, never stroked.
struct NameShape: Shape {
    func path(in rect: CGRect) -> Path {
        let k = rect.width / Brand.nameSize.width
        return Path(Brand.name).applying(CGAffineTransform(a: k, b: 0, c: 0, d: k, tx: rect.minX, ty: rect.minY))
    }
}

/// Phew, by the shell alone: pose, line and colour of the state (22.5). `size` is the box in points; under 32 the small
/// mark. No dot, badge, shading or shadow is ever added (22.7).
struct BrandMark: View {
    var state: Brand.State
    var size: CGFloat
    /// The notch: ink becomes shell white.
    var onBlack = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let reduce = Design.Motion.reduce
        let drawing = Brand.drawing(state, reduceMotion: reduce)
        let k = size / Brand.box
        ZStack {
            shell(drawing).id(reduce ? state : nil).transition(.opacity)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(drawing.pose.tip), anchor: Brand.pivot)
        .offset(x: drawing.pose.shift * k, y: -drawing.pose.lift * k)
        // Reduce Motion: states swap by opacity; otherwise the "grow" spring moves the pose.
        .animation(reduce ? .easeInOut(duration: Design.Motion.appear) : Brand.grow, value: state)
        .accessibilityElement()
        .accessibilityLabel(Brand.word(state))
    }

    @ViewBuilder private func shell(_ d: Brand.Drawing) -> some View {
        let color = Color(nsColor: Brand.color(d.colour, onBlack: onBlack, dark: scheme == .dark,
                                               highContrast: contrast == .increased))
        Group {
            if d.line == .travelling {
                TimelineView(.animation) { context in
                    line(d, color: color, gapAt: Brand.gapPhase(at: context.date))
                }
            } else {
                line(d, color: color, gapAt: Brand.stillGapAt)
            }
        }
        .animation(.easeOut(duration: Design.Motion.appear), value: d.colour)  // colour changes in 0.16 s
    }

    @ViewBuilder private func line(_ d: Brand.Drawing, color: Color, gapAt: CGFloat) -> some View {
        let k = size / Brand.box, small = size < Brand.fullFrom
        let style = StrokeStyle(lineWidth: Brand.line * k, lineCap: .round, lineJoin: .round,
                                dash: d.line == .broken ? Brand.dashes.map { $0 * k } : [])
        let gapped = d.line == .travelling || d.line == .stillGap
        ZStack {
            if d.look == .full { MarkShape(small: small).fill(color) }
            MarkShape(small: small, gapAt: gapped ? gapAt : nil).stroke(color, style: style)
        }
    }
}

extension Brand {
    /// Lift, tip and settle: the "grow" spring of 15.4 (response 0.35), with no bounce.
    static let grow = Animation.spring(response: Design.Motion.growDuration, dampingFraction: 1)

    /// Where the travelling gap starts at a moment: once round in 1.6 s.
    static func gapPhase(at date: Date) -> CGFloat {
        CGFloat(date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: round) / round)
    }
}

// MARK: 22.3 Mark and name together

/// The measures of a lockup for a name whose tall letters are `tall` points high, in points, y down, origin at the
/// top-left of the clear space.
struct Lockup: Equatable {
    enum Form { case beside, stacked }
    let form: Form
    let tall: CGFloat
    /// The mark's 120 box, and the name's outline box.
    let markBox: CGRect
    let nameBox: CGRect
    /// Between the mark's ink and the name's: across when beside, down when stacked.
    let gap: CGFloat
    /// The whole, clear space included.
    let size: CGSize

    /// x, the small-letter height: the unit of every measure.
    var x: CGFloat { tall * Brand.nameX / Brand.nameTall }
    var small: Bool { markBox.width < Brand.fullFrom }
    /// The mark's ink, in lockup points.
    var markInk: CGRect { Self.ink(in: markBox) }

    /// Both drawings have the same ink, so the mark's ink is known from its box alone.
    static func ink(in box: CGRect) -> CGRect {
        let ink = Brand.ink(Brand.mark), k = box.width / Brand.box
        return CGRect(x: box.minX + ink.minX * k, y: box.minY + ink.minY * k, width: ink.width * k, height: ink.height * k)
    }
    /// The name's tall letters: from the top of its box to its baseline.
    var nameTallLine: CGFloat { nameBox.minY }
    var nameBaseline: CGFloat { nameBox.minY + Brand.nameBaseline * nameBox.width / Brand.nameSize.width }

    init(_ form: Form, tall: CGFloat) {
        self.form = form
        self.tall = tall
        let k = tall / Brand.nameTall  // the name's scale from 100 points
        let x = tall * Brand.nameX / Brand.nameTall
        let ink = Brand.ink(Brand.mark)
        // Measured from the name's top-left (its tall letters start at y = 0), then moved into the clear space.
        let name = CGRect(x: 0, y: 0, width: Brand.nameSize.width * k, height: Brand.nameSize.height * k)
        var mark: CGRect, nameAt = name
        switch form {
        case .beside:
            // 1.04 times the tall letters: 2% over their line, 2% under the baseline.
            let m = 1.04 * tall / ink.height
            mark = CGRect(x: -ink.minX * m, y: -0.02 * tall - ink.minY * m, width: Brand.box * m, height: Brand.box * m)
            gap = 0.8 * x
            nameAt.origin.x = ink.width * m + gap
        case .stacked:
            // 2 x tall, centred, 0.6 x over the tall letters.
            let m = 2 * x / ink.height
            gap = 0.6 * x
            mark = CGRect(x: name.midX - ink.midX * m, y: -gap - ink.maxY * m, width: Brand.box * m, height: Brand.box * m)
        }
        let all = Self.ink(in: mark).union(nameAt)
        let move = CGAffineTransform(translationX: x - all.minX, y: x - all.minY)
        markBox = mark.applying(move)
        nameBox = nameAt.applying(move)
        size = CGSize(width: all.width + 2 * x, height: all.height + 2 * x)
    }
}

/// The mark and the name together, in ink: the label colour, following light and dark.
struct LockupView: View {
    let lockup: Lockup

    init(_ form: Lockup.Form = .beside, tall: CGFloat) { lockup = Lockup(form, tall: tall) }

    var body: some View {
        let k = lockup.markBox.width / Brand.box
        ZStack(alignment: .topLeading) {
            MarkShape(small: lockup.small)
                .stroke(Design.Ink.primary, style: StrokeStyle(lineWidth: Brand.line * k, lineCap: .round, lineJoin: .round))
                .frame(width: lockup.markBox.width, height: lockup.markBox.height)
                .offset(x: lockup.markBox.minX, y: lockup.markBox.minY)
            NameShape()
                .fill(Design.Ink.primary)
                .frame(width: lockup.nameBox.width, height: lockup.nameBox.height)
                .offset(x: lockup.nameBox.minX, y: lockup.nameBox.minY)
        }
        .frame(width: lockup.size.width, height: lockup.size.height, alignment: .topLeading)
        .accessibilityElement()
        .accessibilityLabel("phew!")
    }
}
