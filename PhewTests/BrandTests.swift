import SwiftUI
import XCTest
@testable import Phew

/// The brand of docs/22-brand.md: the numbers of the mark and the name, the states of 22.5, the one mapping from the
/// app's moments, the notch and menu bar models, the lockup of 22.3. Nothing is put on screen.
final class BrandTests: XCTestCase {
    private func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    // MARK: 22.1, 22.2

    func testTheMarkIsTheSheetsPath() {
        let dome: [Brand.Segment] = [.move(p(26, 82)), .curve(p(23, 52), p(35, 20), p(56, 20)), .curve(p(80, 20), p(97, 50), p(95, 82))]
        XCTAssertEqual(Brand.segments(Brand.markData), dome + [
            .line(p(89.42, 73.93)), .quad(p(86, 69), p(82.58, 73.93)),
            .line(p(80.42, 77.07)), .quad(p(77, 82), p(73.56, 77.08)),
            .line(p(66.44, 66.92)), .quad(p(63, 62), p(59.56, 66.92)),
            .line(p(52.44, 77.08)), .quad(p(49, 82), p(44.54, 77.99)),
            .line(p(43.46, 77.01)), .quad(p(39, 73), p(34.07, 76.42)),
            .line(p(26, 82)), .close,
        ])
        XCTAssertEqual(Brand.segments(Brand.smallMarkData), dome + [
            .line(p(78.18, 66.71)), .quad(p(73, 62), p(68.05, 66.95)),
            .line(p(57.95, 77.05)), .quad(p(53, 82), p(47.66, 77.48)),
            .line(p(45.34, 75.52)), .quad(p(40, 71), p(34.5, 75.32)),
            .line(p(26, 82)), .close,
        ])
        XCTAssertEqual(Brand.box, 120)
        XCTAssertEqual(Brand.line, 11)
    }

    func testTheMarksInkIsEightyBySeventyThreeWithTheDomeLeftOfCentre() {
        for path in [Brand.mark, Brand.smallMark] {
            let ink = Brand.ink(path)
            XCTAssertEqual(ink.width, 80, accuracy: 1, "80.6: the sheet gives whole points")
            XCTAssertEqual(ink.height, 73, accuracy: 0.5)
            XCTAssertEqual(ink.maxY, 82 + Brand.line / 2, accuracy: 0.01, "both feet stand on y = 82")
            XCTAssertEqual(ink.midX - 56, 4.5, accuracy: 0.5, "the top of the dome is 4.5 left of the ink's centre")
        }
    }

    func testTheShapeDrawsThePathScaled() {
        let rect = CGRect(x: 10, y: 20, width: 16, height: 16)
        let drawn = MarkShape(small: true).path(in: rect).boundingRect
        let k: CGFloat = 16 / 120, raw = Brand.smallMark.boundingBoxOfPath
        XCTAssertEqual(drawn.minX, 10 + raw.minX * k, accuracy: 0.001)
        XCTAssertEqual(drawn.maxY, 20 + 82 * k, accuracy: 0.001)
        XCTAssertEqual(drawn.width, raw.width * k, accuracy: 0.001)
        // The gap: the dome's top left out, also when the gap runs past the start of the line.
        let box = CGRect(x: 0, y: 0, width: 120, height: 120)
        XCTAssertGreaterThan(MarkShape(gapAt: 0.25).path(in: box).boundingRect.minY, 20.5, "no ink at the dome's top")
        XCTAssertFalse(MarkShape(gapAt: 0.9).path(in: box).isEmpty)
        XCTAssertEqual(MarkShape(gapAt: 0.9).path(in: box).boundingRect.minY, 20, accuracy: 0.01, "the dome stays whole")
    }

    func testTheNameOutlineIs255By92() {
        XCTAssertEqual(Brand.nameData.count, 5, "p, h, e, w, !")
        let box = Brand.name.boundingBoxOfPath
        XCTAssertEqual(box.minX, 0, accuracy: 0.01)
        XCTAssertEqual(box.minY, 0, accuracy: 0.01, "the tall letters reach the top")
        XCTAssertEqual(box.width, 255.21, accuracy: 0.01)
        XCTAssertEqual(box.height, 92, accuracy: 0.01)
        XCTAssertEqual(Brand.nameSize, CGSize(width: 255.21, height: 92))
        let drawn = NameShape().path(in: CGRect(x: 0, y: 0, width: 25.521, height: 9.2)).boundingRect
        XCTAssertEqual(drawn.height, 9.2, accuracy: 0.01, "scaled by its width, never stretched")
    }

    // MARK: 22.5

    func testEachStateGivesThePoseLineLookAndColourOfTheTable() {
        let lift = Brand.lift
        XCTAssertEqual(lift, 16.5, "1.5 line weights")
        typealias D = Brand.Drawing
        let a: [Brand.State: D] = [
            .resting: D(pose: .down, line: .whole, look: .line, colour: .ink),
            .listening: D(pose: .init(lift: lift, tip: -9), line: .whole, look: .line, colour: .ink),
            .thinking: D(pose: .init(lift: lift), line: .travelling, look: .line, colour: .ink),
            .acting: D(pose: .init(lift: lift), line: .whole, look: .line, colour: .orange),
            .pointing: D(pose: .init(lift: lift, tip: 10, shift: 5), line: .whole, look: .line, colour: .orange),
            .done: D(pose: .down, line: .whole, look: .full, colour: .orange),
            .couldNot: D(pose: .init(tip: 16), line: .broken, look: .line, colour: .ink),
            .waiting: D(pose: .down, line: .whole, look: .line, colour: .orange),
        ]
        // Set B, the menu bar: one colour, nothing moves; orange becomes full.
        let b: [Brand.State: (Brand.Line, Brand.Look)] = [
            .resting: (.whole, .line), .listening: (.whole, .line), .thinking: (.stillGap, .line), .acting: (.whole, .full),
            .pointing: (.whole, .full), .done: (.whole, .full), .couldNot: (.broken, .line), .waiting: (.whole, .full),
        ]
        for state in Brand.State.allCases {
            XCTAssertEqual(Brand.drawing(state), a[state], "set A, \(state)")
            let one = Brand.drawing(state, setB: true)
            XCTAssertEqual(one.pose, .down, "\(state)")
            XCTAssertEqual(one.colour, .ink, "\(state)")
            XCTAssertEqual(one.line, b[state]?.0, "set B, \(state)")
            XCTAssertEqual(one.look, b[state]?.1, "set B, \(state)")
        }
        XCTAssertEqual(Brand.pivot.x * Brand.box, 60, accuracy: 0.001)
        XCTAssertEqual(Brand.pivot.y * Brand.box, 82, accuracy: 0.001)
        XCTAssertEqual(Brand.gap * 240, 44, accuracy: 0.001)
        XCTAssertEqual(Brand.round, 1.6)
        XCTAssertEqual(Brand.dashes, [15, 19])
        XCTAssertEqual(Brand.gapPhase(at: Date(timeIntervalSinceReferenceDate: 0.8)), 0.5, accuracy: 0.001, "half round in 0.8 s")
        XCTAssertEqual(Set(Brand.State.allCases.map(Brand.word)).count, Brand.State.allCases.count, "a word for each")
    }

    func testReduceMotionKeepsEveryShellDownAndTheGapStill() {
        for state in Brand.State.allCases {
            let d = Brand.drawing(state, reduceMotion: true)
            XCTAssertEqual(d.pose, .down, "no lift, no tip: \(state)")
            XCTAssertNotEqual(d.line, .travelling, "\(state)")
            XCTAssertEqual(d.colour, Brand.drawing(state).colour, "colour and look stay")
            XCTAssertEqual(d.look, Brand.drawing(state).look)
        }
        XCTAssertEqual(Brand.drawing(.thinking, reduceMotion: true).line, .stillGap)
    }

    func testIncreaseContrastDarkensTheOrangeOnLightGroundsOnly() {
        typealias C = Design.Brand
        XCTAssertEqual(Brand.color(.orange, onBlack: false, dark: false, highContrast: false), C.orange)
        XCTAssertEqual(Brand.color(.orange, onBlack: false, dark: false, highContrast: true), C.orangeHigh)
        XCTAssertEqual(Brand.color(.orange, onBlack: false, dark: true, highContrast: true), C.orange)
        XCTAssertEqual(Brand.color(.orange, onBlack: true, dark: true, highContrast: true), C.orange, "the notch is black")
        XCTAssertEqual(Brand.color(.ink, onBlack: true, dark: true, highContrast: false), C.shellWhite)
        XCTAssertEqual(Brand.color(.ink, onBlack: false, dark: false, highContrast: true), .labelColor)
        let hex = { (c: NSColor) -> String in
            let s = c.usingColorSpace(.sRGB)!
            return String(format: "%02X%02X%02X", Int(round(s.redComponent * 255)), Int(round(s.greenComponent * 255)), Int(round(s.blueComponent * 255)))
        }
        XCTAssertEqual([C.ink, C.shellWhite, C.white, C.warmGrey, C.orange, C.orangeHigh].map(hex),
                       ["141414", "F4EFE6", "FFFFFF", "D9D2C4", "F2541B", "D9440F"])
    }

    // MARK: The mapping

    func testTheAppsMomentsMapToOneState() {
        typealias M = Brand.Moment
        let now = Date(timeIntervalSinceReferenceDate: 1000)
        let cases: [(M, Brand.State)] = [
            (M(), .resting),
            (M(holding: true), .listening),
            (M(holding: true, failed: true), .couldNot),
            (M(thinking: true), .thinking),
            (M(thinking: true, acting: true), .acting),
            (M(acting: true, waiting: 3), .acting),
            (M(pointing: true), .pointing),
            (M(thinking: true, pointing: true), .thinking),
            (M(thinking: true, failed: true), .couldNot),
            (M(answeredAt: now), .done),
            (M(answeredAt: now, waiting: 1), .done),
            (M(waiting: 1), .waiting),
            (M(holding: true, acting: true), .listening),
        ]
        for (moment, state) in cases { XCTAssertEqual(Brand.state(moment, now: now), state, "\(moment)") }
    }

    func testDoneReturnsToRestingAfterTwoSeconds() {
        let at = Date(timeIntervalSinceReferenceDate: 500)
        let moment = Brand.Moment(answeredAt: at)
        XCTAssertEqual(Brand.state(moment, now: at), .done)
        XCTAssertEqual(Brand.state(moment, now: at + 1.99), .done)
        XCTAssertEqual(Brand.state(moment, now: at + 2), .resting)
        XCTAssertEqual(Brand.state(moment, now: at + 60), .resting)
        XCTAssertEqual(Brand.state(Brand.Moment(answeredAt: at, waiting: 2), now: at + 2), .waiting)
    }

    @MainActor
    func testTheCardKnowsWhenAnAnswerIsDone() {
        let model = CardModel()
        model.begin("a made-up question")
        XCTAssertNil(model.answeredAt, "a new turn is not done")
        model.answeredAt = Date()
        model.begin("another")
        XCTAssertNil(model.answeredAt, "cleared by the next turn")
    }

    // MARK: The notch and the menu bar

    @MainActor
    func testTheNotchShowsNothingAtRest() {
        let model = NotchModel()
        XCTAssertNil(Brand.atNotch(open: model.open, problem: model.line != nil), "at rest nothing is drawn")
        model.grow()
        XCTAssertEqual(Brand.atNotch(open: model.open, problem: model.line != nil), .listening)
        model.say("A made-up problem line.")
        XCTAssertEqual(Brand.atNotch(open: model.open, problem: model.line != nil), .couldNot)
        model.end(.sent)
        XCTAssertNil(Brand.atNotch(open: model.open, problem: model.line != nil))
        model.reset()
        XCTAssertNil(Brand.atNotch(open: model.open, problem: model.line != nil))
    }

    func testTheMenuBarHasThreePictures() throws {
        XCTAssertEqual(Brand.inMenuBar(acting: false, waiting: 0), .resting)
        XCTAssertEqual(Brand.inMenuBar(acting: true, waiting: 0), .acting)
        XCTAssertEqual(Brand.inMenuBar(acting: false, waiting: 2), .waiting)
        XCTAssertEqual(Brand.inMenuBar(acting: true, waiting: 2), .acting)
        let looks = [Brand.State.resting, .acting, .waiting].map { Brand.drawing($0, setB: true).look }
        XCTAssertEqual(looks, [.line, .full, .full])

        func inked(_ state: Brand.State) throws -> Int {
            let image = Brand.menuImage(state)
            XCTAssertTrue(image.isTemplate, "the system colours it")
            XCTAssertEqual(image.size, NSSize(width: 16, height: 16))
            let rep = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 32, pixelsHigh: 32, bitsPerSample: 8,
                                                     samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                                     bytesPerRow: 0, bitsPerPixel: 0))
            rep.size = image.size
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            image.draw(in: NSRect(origin: .zero, size: image.size))
            NSGraphicsContext.restoreGraphicsState()
            var count = 0
            for x in 0..<32 { for y in 0..<32 where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5 { count += 1 } }
            // The round ends stay inside: the outer ring of pixels is empty.
            for i in 0..<32 {
                for (x, y) in [(i, 0), (i, 31), (0, i), (31, i)] {
                    XCTAssertLessThan(rep.colorAt(x: x, y: y)?.alphaComponent ?? 0, 0.5, "\(state) touches the edge at \(x), \(y)")
                }
            }
            return count
        }
        let line = try inked(.resting), full = try inked(.acting)
        XCTAssertGreaterThan(line, 60, "the line is drawn")
        XCTAssertGreaterThan(full, line + 60, "full is the shell filled")
        XCTAssertEqual(try inked(.waiting), full, "a result waiting is the same drawing (22.8)")
    }

    // MARK: 22.3

    func testTheLockupsMeasures() {
        let tall: CGFloat = 36, k = tall / 72, x = tall * 48 / 72
        let beside = Lockup(.beside, tall: tall)
        XCTAssertEqual(beside.x, 24)
        let ink = beside.markInk
        XCTAssertEqual(ink.height, 1.04 * tall, accuracy: 0.01, "the mark 1.04 times the tall letters")
        XCTAssertEqual(beside.nameTallLine - ink.minY, 0.02 * tall, accuracy: 0.01, "its top 2% over their line")
        XCTAssertEqual(ink.maxY - beside.nameBaseline, 0.02 * tall, accuracy: 0.01, "its feet 2% under the baseline")
        XCTAssertEqual(beside.nameBox.minX - ink.maxX, 0.8 * x, accuracy: 0.01, "gap 0.8 x")
        XCTAssertEqual(beside.gap, 0.8 * x, accuracy: 0.01)
        XCTAssertEqual(beside.nameBox.width, 255.21 * k, accuracy: 0.01)
        XCTAssertEqual(Brand.line * beside.markBox.width / Brand.box, Brand.nameStem * k, accuracy: 0.03 * Brand.nameStem * k,
                       "the mark's line equals the letters' stem")
        // One x of clear space on every side.
        XCTAssertEqual(ink.minX, x, accuracy: 0.01)
        XCTAssertEqual(ink.minY, x, accuracy: 0.01)
        XCTAssertEqual(beside.size.width - beside.nameBox.maxX, x, accuracy: 0.01)
        XCTAssertEqual(beside.size.height - beside.nameBox.maxY, x, accuracy: 0.01, "the p's tail is the lowest ink")
        XCTAssertFalse(beside.small, "a 36-point name has the mark")
        XCTAssertTrue(Lockup(.beside, tall: 12).small, "the smallest takes the small mark")

        let stacked = Lockup(.stacked, tall: tall)
        let up = stacked.markInk
        XCTAssertEqual(up.height, 2 * x, accuracy: 0.01, "mark 2 x tall")
        XCTAssertEqual(stacked.nameTallLine - up.maxY, 0.6 * x, accuracy: 0.01, "gap 0.6 x to the tall letters")
        XCTAssertEqual(up.midX, stacked.nameBox.midX, accuracy: 0.01, "centred")
        XCTAssertEqual(up.minY, x, accuracy: 0.01)
        XCTAssertEqual(stacked.nameBox.minX, x, accuracy: 0.01)
        XCTAssertEqual(stacked.size.width, stacked.nameBox.width + 2 * x, accuracy: 0.01)
    }

    // MARK: A look, on request

    /// With `PHEW_BRAND_PNG` set to a folder, draws every state, the notch, the menu bar pictures and the lockup there
    /// as PNG files, to look at. Without it, nothing is drawn.
    @MainActor
    func testDrawsTheBrandToLookAt() throws {
        guard let folder = ProcessInfo.processInfo.environment["PHEW_BRAND_PNG"] else { return }
        let out = URL(fileURLWithPath: folder)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        func save(_ view: some View, _ name: String) throws {
            let renderer = ImageRenderer(content: view)
            renderer.scale = 4
            let image = try XCTUnwrap(renderer.nsImage)
            let rep = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(image.tiffRepresentation)))
            try XCTUnwrap(rep.representation(using: .png, properties: [:])).write(to: out.appendingPathComponent(name + ".png"))
        }
        let states = Brand.State.allCases
        for (scheme, ground) in [(ColorScheme.light, Color.white), (.dark, Color(white: 0.16))] {
            for contrast in [ColorSchemeContrast.standard, .increased] {
                let row = HStack(spacing: 24) {
                    ForEach(states, id: \.self) { state in
                        VStack(spacing: 8) {
                            BrandMark(state: state, size: 48)
                            BrandMark(state: state, size: 16)
                            Text(Brand.word(state)).font(.caption)
                        }
                    }
                }
                .padding(24).background(ground).environment(\.colorScheme, scheme)
                try save(row.environment(\._colorSchemeContrast, contrast), "states-\(scheme)-\(contrast == .increased ? "contrast" : "standard")")
            }
            try save(LockupView(.beside, tall: 36).background(ground).environment(\.colorScheme, scheme), "lockup-beside-\(scheme)")
            try save(LockupView(.stacked, tall: 36).background(ground).environment(\.colorScheme, scheme), "lockup-stacked-\(scheme)")
        }
        try save(HStack(spacing: 16) {
            ForEach([Brand.State.listening, .couldNot, .resting], id: \.self) { BrandMark(state: $0, size: 22, onBlack: true) }
        }.padding(16).background(.black), "notch")
        // The menu bar: the template image as the system tints it, on a light bar and a dark one.
        for (name, bar, tint) in [("menubar-light", Color(white: 0.92), Color.black), ("menubar-dark", Color(white: 0.2), .white)] {
            try save(HStack(spacing: 12) {
                ForEach([Brand.State.resting, .acting, .waiting], id: \.self) {
                    Image(nsImage: Brand.menuImage($0)).renderingMode(.template).foregroundStyle(tint)
                }
            }.padding(6).background(bar), name)
        }
    }
}
