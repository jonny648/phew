import XCTest
@testable import Phew

/// Phase PB, the Shell side: the import panel's model and the menu's undo entry, on a stub Brain with made-up data.
/// Nothing is sent before Sort, nothing is kept before Keep, and only the ticked facts are kept.
@MainActor
final class ImportPanelTests: XCTestCase {
    override func tearDown() {
        shellLogTap = nil
    }

    private func until(_ done: () -> Bool) async {
        for _ in 0..<200 where !done() { try? await Task.sleep(for: .milliseconds(10)) }
    }

    private func sorted(_ brain: ImportStubBrain) async -> ImportModel {
        let model = ImportModel(brain: brain)
        model.text = "A made-up memory list."
        model.sort()
        await until { model.stage == .ticks }
        return model
    }

    func testNothingIsCalledBeforeSort() async {
        let brain = ImportStubBrain()
        let model = ImportModel(brain: brain)
        XCTAssertFalse(model.canSort, "an empty box sorts nothing")
        model.sort()
        model.text = "A made-up memory list."
        model.source = .chatgpt
        model.tickAll(true)
        await model.keep()
        XCTAssertEqual(brain.calls, [])
        model.sort()
        await until { model.stage == .ticks }
        XCTAssertEqual(brain.calls, ["sortImport text"])
        XCTAssertEqual(model.candidates.count, 12)
        XCTAssertEqual(model.candidates.first?.source, .chatgpt)
    }

    func testCancelWhileSortingCallsNothingMoreAndKeepsNothing() async {
        let brain = ImportStubBrain(delay: .seconds(5))
        let model = ImportModel(brain: brain)
        model.text = "A made-up memory list."
        model.sort()
        XCTAssertEqual(model.stage, .sorting)
        model.cancel()
        XCTAssertEqual(model.stage, .paste)
        try? await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(model.stage, .paste)
        XCTAssertTrue(model.candidates.isEmpty)
        XCTAssertNil(model.problem)
        XCTAssertEqual(brain.calls, ["sortImport text"])
    }

    func testInstructionsStartUnticked() async {
        let model = await sorted(ImportStubBrain())
        let instructions = model.candidates.filter(\.instruction)
        XCTAssertEqual(instructions.count, 1)
        XCTAssertFalse(instructions[0].ticked)
        XCTAssertEqual(model.candidates.filter(\.sensitive).count, 1)
        XCTAssertEqual(model.keepTitle, "Keep 11 facts")
        XCTAssertEqual(model.note, Importer.cutLine)
    }

    func testOnlyTickedCandidatesReachKeep() async {
        let brain = ImportStubBrain()
        let model = await sorted(brain)
        var imported = 0
        model.onImported = { imported += 1 }
        model.candidates[0].ticked = false
        XCTAssertEqual(model.keepTitle, "Keep 10 facts")
        await model.keep()
        XCTAssertEqual(brain.kept.count, 10)
        XCTAssertTrue(brain.kept.allSatisfy(\.ticked))
        XCTAssertFalse(brain.kept.contains { $0.id == 0 || $0.instruction })
        XCTAssertEqual(brain.calls, ["sortImport text", "keepImport 10"])
        guard case .line(let line) = model.stage else { return XCTFail("not on the kept line") }
        XCTAssertTrue(line.hasPrefix("Kept 10 facts"))
        XCTAssertTrue(model.candidates.isEmpty, "dropped once kept")
        XCTAssertEqual(imported, 1)
    }

    func testTickAllAndUntickAll() async {
        let model = await sorted(ImportStubBrain())
        model.tickAll(true)
        XCTAssertTrue(model.allTicked)
        XCTAssertEqual(model.keepTitle, "Keep 12 facts")
        model.tickAll(false)
        XCTAssertEqual(model.tickedCount, 0)
        await model.keep()
        XCTAssertEqual(model.stage, .ticks, "nothing ticked, nothing kept")
    }

    func testDiscardAndCloseKeepNothingAndDropTheCandidates() async {
        for discard in [true, false] {
            let brain = ImportStubBrain()
            let model = await sorted(brain)
            var closed = 0
            model.onClose = { closed += 1 }
            if discard { model.close() } else { model.drop() }  // Discard, or the panel's close button
            XCTAssertTrue(model.candidates.isEmpty)
            XCTAssertEqual(model.text, "")
            XCTAssertEqual(closed, discard ? 1 : 0)
            XCTAssertFalse(brain.calls.contains { $0.hasPrefix("keepImport") })
        }
    }

    func testClosingWhileSortingDropsTheAnswer() async {
        let brain = ImportStubBrain(delay: .milliseconds(100))
        let model = ImportModel(brain: brain)
        model.text = "A made-up memory list."
        model.sort()
        model.drop()
        try? await Task.sleep(for: .milliseconds(400))
        XCTAssertTrue(model.candidates.isEmpty)
        XCTAssertNotEqual(model.stage, .ticks)
    }

    func testFolderReadsOnlyAfterChoiceAndSendsOnlyOnSort() async {
        let brain = ImportStubBrain()
        let model = ImportModel(brain: brain)
        XCTAssertEqual(brain.calls, [])
        model.read(folder: URL(fileURLWithPath: "/made-up/Orbit Lamp"))
        XCTAssertEqual(model.stage, .files)
        XCTAssertEqual(model.memory?.files.count, 3)
        XCTAssertEqual(model.memory?.refused, ["memory/huge_notes.md"])
        XCTAssertEqual(brain.calls, ["projectMemory"])
        model.sort()
        await until { model.stage == .ticks }
        XCTAssertEqual(brain.calls, ["projectMemory", "sortImport memory"])
        XCTAssertTrue(model.candidates.allSatisfy { $0.source == .claudeCode })
    }

    func testCancelOnAFolderGoesBackToItsFiles() async {
        let model = ImportModel(brain: ImportStubBrain(delay: .seconds(5)))
        model.read(folder: URL(fileURLWithPath: "/made-up/Orbit Lamp"))
        model.sort()
        model.cancel()
        XCTAssertEqual(model.stage, .files)
    }

    func testErrorsAreOneLineAndAMissingKeyOpensTheKeyRow() async {
        for error in [BrainError.noKey, .network] {
            let model = ImportModel(brain: ImportStubBrain(failure: error))
            var keyRow: [BrainError] = []
            model.onKeyProblem = { keyRow.append($0) }
            model.text = "A made-up memory list."
            model.sort()
            await until { model.problem != nil }
            XCTAssertEqual(model.stage, .paste)
            XCTAssertEqual(model.problem, TextCard.sentence(for: error))
            XCTAssertEqual(keyRow, error == .noKey ? [.noKey] : [])
            XCTAssertEqual(model.text, "A made-up memory list.", "the text stays for another try")
        }
    }

    func testKeepWithoutAMapIsAProblem() async {
        let model = await sorted(ImportStubBrain(number: nil))
        await model.keep()
        XCTAssertEqual(model.stage, .ticks)
        XCTAssertNotNil(model.problem)
        XCTAssertEqual(model.candidates.count, 12)
    }

    func testUndoEntryIsOffWhenThereIsNoLastImport() async {
        let none = ImportUndo(brain: ImportStubBrain(last: nil))
        await none.refresh()
        XCTAssertNil(none.last)
        XCTAssertEqual(none.title, "Undo last import")
        let line = await none.undo()
        XCTAssertEqual(line, "There was no import to undo.")

        let brain = ImportStubBrain()
        let undo = ImportUndo(brain: brain)
        await undo.refresh()
        XCTAssertNotNil(undo.last)
        XCTAssertEqual(undo.title, "Undo last import (ChatGPT, 12 facts)")
        let undone = await undo.undo()
        XCTAssertTrue(undone.hasPrefix("Took out"))
        XCTAssertNil(undo.last, "read again after the undo")
        XCTAssertEqual(brain.calls, ["lastImport", "undoLastImport", "lastImport"])
    }

    func testNoPlantedWordInAnyLogLine() async {
        let lines = ImportTests.Logged()
        shellLogTap = { lines.add($0) }
        let brain = ImportStubBrain()
        let model = ImportModel(brain: brain)
        model.text = "Zorbleflax keeps a made-up diary."
        model.sort()
        await until { model.stage == .ticks }
        await model.keep()
        let folder = ImportModel(brain: brain)
        folder.read(folder: URL(fileURLWithPath: "/made-up/Zorbleflax"))
        folder.sort()
        await until { folder.stage == .ticks }
        folder.close()
        _ = await ImportUndo(brain: brain).undo()
        let failing = ImportModel(brain: ImportStubBrain(failure: .network))
        failing.text = "Zorbleflax again."
        failing.sort()
        await until { failing.problem != nil }
        shellLogTap = nil

        XCTAssertFalse(lines.lines.isEmpty)
        for line in lines.lines {
            for word in ["Zorbleflax", "diary", "Orbit", "Lamp", "CLAUDE.md", "made-up", "Kerning", "kerning"] {
                XCTAssertFalse(line.contains(word), "\(word) in a log line")
            }
        }
    }
}
