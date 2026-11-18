import XCTest
@testable import Phew

/// Checker pass on N7: no state sticks, and the mark carries nothing the sheet (22.7) forbids.
final class BrandCheckerTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 5000)

    func testDoneNeverStartsFromTheFuture() {
        // A clock moved back must not leave "done" showing for good.
        let moment = Brand.Moment(answeredAt: t0 + 3600)
        XCTAssertEqual(Brand.state(moment, now: t0), .resting)
    }

    func testANewQuestionLeavesDoneAndCouldNotAtOnce() {
        // answeredAt and problem are cleared by CardModel.begin; here thinking must win over a stale answer.
        XCTAssertEqual(Brand.state(Brand.Moment(thinking: true, answeredAt: t0), now: t0), .thinking)
        XCTAssertEqual(Brand.state(Brand.Moment(thinking: true), now: t0), .thinking)
    }

    @MainActor
    func testAStoppedOrFailedTurnLeavesNoDone() {
        let model = CardModel()
        model.begin("a made-up question")
        model.answeredAt = t0
        model.problem = "A made-up problem."
        model.begin("a second made-up question")
        XCTAssertNil(model.answeredAt)
        XCTAssertNil(model.problem)
        model.answeredAt = t0
        model.reset()
        XCTAssertNil(model.answeredAt, "closing the card clears done")
        let m = Brand.Moment(thinking: model.thinking, acting: model.acting, pointing: !model.steps.isEmpty,
                             failed: model.problem != nil, answeredAt: model.answeredAt)
        XCTAssertNotEqual(Brand.state(m, now: t0 + 100), .done)
    }

    func testTheGapOnlyTravelsWhileThinking() {
        for state in Brand.State.allCases where state != .thinking {
            XCTAssertNotEqual(Brand.drawing(state).line, .travelling, "\(state)")
            XCTAssertNotEqual(Brand.drawing(state, setB: true).line, .travelling, "\(state)")
        }
        XCTAssertEqual(Brand.drawing(.thinking, setB: true).line, .stillGap, "the menu bar never animates")
    }

    func testThePhasePerRoundStaysInZeroToOne() {
        for s in stride(from: -3.0, through: 9.0, by: 0.37) {
            let phase = Brand.gapPhase(at: Date(timeIntervalSinceReferenceDate: s))
            XCTAssertGreaterThanOrEqual(phase, -0.0001 - 1)
            XCTAssertLessThan(phase, 1)
        }
    }

    func testTheMarkCarriesNoShadingNoDotNoBadge() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let brand = try String(contentsOf: root.appendingPathComponent("Phew/Shell/Brand.swift"), encoding: .utf8)
            .split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }.joined(separator: "\n")
        for word in ["Gradient", "shadow", "Circle(", "Ellipse(", "blur(", "badge", "checkmark", "Image(systemName"] {
            XCTAssertFalse(brand.contains(word), "22.7: \(word) in Brand.swift")
        }
        for file in ["Phew/Shell/Design.swift", "Phew/Shell/PhewApp.swift", "Phew/Shell/TextCard.swift", "Phew/Shell/NotchListening.swift",
                     "Phew/Shell/InputPanel.swift"] {
            let text = try String(contentsOf: root.appendingPathComponent(file), encoding: .utf8)
            XCTAssertFalse(text.contains("PresenceDot"), "the old presence dot is left in \(file)")
        }
    }

    func testThePathsAreParsedOnceNotPerFrame() {
        XCTAssertTrue(Brand.mark === Brand.mark, "a static, the same object each time")
        XCTAssertTrue(Brand.smallMark === Brand.smallMark)
    }
}
