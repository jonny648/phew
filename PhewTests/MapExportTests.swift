import XCTest
@testable import Phew

/// P5.10: the Map exported to one readable Markdown file (docs/05-map-storage.md 5.13), on a made-up Map in memory. The
/// save window itself is a hand test.
final class MapExportTests: XCTestCase {
    private let now = Made.now

    /// The lines of one `## title` section, without the leading "- ".
    private func section(_ text: String, _ title: String) -> [String] {
        let lines = text.components(separatedBy: "\n")
        guard let start = lines.firstIndex(of: "## \(title)") else { return [] }
        return lines[(start + 1)...].prefix { !$0.hasPrefix("## ") }.filter { $0.hasPrefix("- ") }.map { String($0.dropFirst(2)) }
    }

    private func occurrences(_ text: String, _ part: String) -> Int { text.components(separatedBy: part).count - 1 }

    /// The line each node starts with: a thing's bold name, or a Note's quoted sentence.
    private func head(_ node: MapNode) -> String {
        node.mapClass == .note ? "- \"\(node.text)\" (Note" : "- **\(node.mapClass == .me && node.name.isEmpty ? "You" : node.name)** ("
    }

    func testTheExportMatchesTheDatabase() async throws {
        let store = try await MadeUpMap.build()
        let text = await store.export(includeSensitive: false, now: now)
        let nodes = await store.visibleNodes().filter { !$0.sensitive }
        let edges = await store.visibleEdges()
        let kept = Set(nodes.map(\.id))
        let events = await store.visibleEvents().filter { !$0.sensitive }
        XCTAssertEqual(nodes.count, 8, "Me, project, task, person, tool, topic and two notes")
        // Each current fact once, before the old versions (which repeat the poster's name as history).
        let currentPart = try XCTUnwrap(text.components(separatedBy: "## Old versions").first)
        for node in nodes {
            XCTAssertEqual(occurrences(currentPart, head(node)), 1, "\(head(node)) once\n\(text)")
        }
        XCTAssertEqual(section(text, "Links").count, edges.filter { kept.contains($0.from) && kept.contains($0.to) }.count)
        XCTAssertEqual(section(text, "Past questions").count, events.count)
        XCTAssertEqual(section(text, "Old versions").count, 1)
        XCTAssertTrue(text.hasPrefix("# Phew Map\n"))
        XCTAssertTrue(text.contains("Things and notes: 8. Links: 7. Old versions: 1. Past questions: 1."), text)

        // Grouped by Project, with origin, date and confidence on each fact.
        let project = section(text, "Project: Example rebrand")
        XCTAssertEqual(project.count, 3, "the project, its task and the note about it")
        XCTAssertTrue(project.contains("**Example poster** (Task, assignment). Due 20 Nov 2026. Told on 10 Nov 2026, confidence 0.9."), "\(project)")
        XCTAssertTrue(project.contains("\"Client approved logo v3\" (Note, decision). Observed on 10 Nov 2026, confidence 0.6."), "\(project)")
        XCTAssertEqual(section(text, "You").count, 2, "Me and the note about Me")
        XCTAssertEqual(section(text, "People").count, 1)
        XCTAssertTrue(section(text, "Links").contains("You, understands, Kerning, strength 0.3. Observed on 10 Nov 2026, confidence 0.6."))
        XCTAssertTrue(section(text, "Links").contains("Example poster, part of, Example rebrand. Told on 10 Nov 2026, confidence 0.9."))
        XCTAssertEqual(section(text, "Old versions").first,
                       "**Example poster** (Task, assignment). Due 18 Nov 2026. Told on 9 Nov 2026, confidence 0.9. True until 10 Nov 2026, replaced by Example poster.")
        XCTAssertTrue(section(text, "Past questions").first?.hasSuffix(" Asked in Sketchpad, on Example rebrand: Asked how to set kerning on the poster.") ?? false)
    }

    func testForgottenItemsNeverAppear() async throws {
        let store = try await MadeUpMap.build()
        for sensitive in [false, true] {
            let text = await store.export(includeSensitive: sensitive, now: now)
            XCTAssertFalse(text.contains("Carla"), "the forgotten person and the note about her")
            XCTAssertFalse(text.contains("tea"))
        }
    }

    func testSensitiveFactsOnlyWhenTicked() async throws {
        let store = try await MadeUpMap.build()
        let without = await store.export(includeSensitive: false, now: now)
        XCTAssertFalse(without.contains("Bruno"), "the sensitive person, the note about him, the link and the past question")
        XCTAssertTrue(without.contains("Sensitive facts are left out."))
        XCTAssertFalse(without.contains("Sensitive."))

        let with = await store.export(includeSensitive: true, now: now)
        XCTAssertEqual(occurrences(with, "- **\(MadeUpMap.sensitiveName)** (Person, friend). Told on 10 Nov 2026, confidence 0.9. Sensitive."), 1, with)
        XCTAssertEqual(occurrences(with, "- \"Bruno has a made-up private matter\" (Note, reference)."), 1)
        XCTAssertTrue(section(with, "Links").contains("\"Bruno has a made-up private matter\", about, \(MadeUpMap.sensitiveName). Told on 10 Nov 2026, confidence 0.9."))
        XCTAssertEqual(section(with, "Past questions").count, 2)
        XCTAssertTrue(with.contains("Told about Bruno's made-up matter. Sensitive."))
    }

    func testTheSameMapGivesTheSameText() async throws {
        let store = try await MadeUpMap.build()
        let first = await store.export(includeSensitive: true, now: now)
        let second = await store.export(includeSensitive: true, now: now)
        XCTAssertEqual(first, second)
    }

    func testTheSecretsFilterRunsOnTheText() async throws {
        let store = try MapStore()
        try await store.add(MapNode(mapClass: .note, kind: "reference", text: "Made-up key sk-ant-ABCDEFGHIJKLMNOPQRSTUVWX\nsecond line",
                                    origin: .told))
        let text = await store.export(includeSensitive: false, now: now)
        XCTAssertFalse(text.contains("ABCDEFGHIJKLMNOP"))
        XCTAssertTrue(text.contains("\"Made-up key [key removed] second line\" (Note, reference)."), "one fact, one line\n\(text)")
    }

    func testClaudeBrainExportsTheMapAndNothingWithoutOne() async throws {
        let store = try await MadeUpMap.build()
        let brain = ClaudeBrain(provider: BrainAgentsTests.FakeProvider([:]), map: BrainMap(open: { store }))
        let text = await brain.exportMap(includeSensitive: false)
        XCTAssertTrue(text?.contains("## Project: Example rebrand") ?? false)
        let closed = ClaudeBrain(provider: BrainAgentsTests.FakeProvider([:]), map: BrainMap(open: { throw MapError.underTests }))
        let none = await closed.exportMap(includeSensitive: false)
        XCTAssertNil(none)
        let fallback = await FakeBrain().exportMap(includeSensitive: true)
        XCTAssertNil(fallback, "a Brain without a Map exports nothing")
    }
}

/// The Export panel's model, on a stub Brain and a stand-in for the save window.
@MainActor
final class MapExporterTests: XCTestCase {
    func testItAsksWithTheCheckboxValueAndSavesTheText() async throws {
        let brain = ExportStubBrain(store: try await MadeUpMap.build())
        var saved: [String] = []
        let exporter = MapExporter(brain: brain) { text in saved.append(text); return "Phew Map.md" }
        XCTAssertFalse(exporter.includeSensitive, "off by default")
        await exporter.export()
        exporter.includeSensitive = true
        await exporter.export()
        XCTAssertEqual(brain.asked, [false, true])
        XCTAssertEqual(saved.count, 2)
        XCTAssertFalse(saved[0].contains(MadeUpMap.sensitiveName))
        XCTAssertTrue(saved[1].contains(MadeUpMap.sensitiveName))
        XCTAssertEqual(saved[1], brain.lastText)
        XCTAssertEqual(exporter.status, "Saved as Phew Map.md.")
        XCTAssertFalse(exporter.busy)
    }

    func testCancelSavesNothingAndSaysNothing() async throws {
        let exporter = MapExporter(brain: ExportStubBrain(store: try await MadeUpMap.build())) { _ in nil }
        await exporter.export()
        XCTAssertNil(exporter.status)
    }

    func testNoMapMeansNoSaveWindow() async {
        var opened = false
        let exporter = MapExporter(brain: ExportStubBrain(store: nil)) { _ in opened = true; return "x" }
        await exporter.export()
        XCTAssertFalse(opened)
        XCTAssertNotNil(exporter.status)
    }

    func testAFailedWriteSaysSo() async throws {
        let exporter = MapExporter(brain: ExportStubBrain(store: try await MadeUpMap.build())) { _ in throw CocoaError(.fileWriteNoPermission) }
        await exporter.export()
        XCTAssertEqual(exporter.status, "Could not save the file. Please try again.")
    }
}
