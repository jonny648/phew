import XCTest
@testable import Phew

/// Claude's memory export, the main way in (owner's instruction of 15 November): a made-up export in a temporary folder
/// (`ImportSelfCheck.madeUpExport`), read through the allow-list, zipped and unpacked, sorted by a fake provider that
/// answers by the file's title, kept on a temporary encrypted Map with made-up keys, then undone. Never a real export,
/// the real Map or the user's folders.
final class ClaudeExportTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appending(path: "PhewExportTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        shellLogTap = nil
        try? FileManager.default.removeItem(at: folder)
    }

    private func fixture() throws -> (parent: URL, export: URL) {
        try ImportSelfCheck.madeUpExport(in: folder.appending(path: "download"))
    }

    // MARK: A fake sorter that answers by the file's title

    /// Replies in the sorter's form, chosen by the "Title:" line inside the data block. Records every request; `pause`
    /// makes each call slow, to test Cancel.
    final class TitleProvider: ModelProvider, @unchecked Sendable {
        private let lock = NSLock()
        private var made: [ModelRequest] = []
        let pause: Duration
        init(pause: Duration = .zero) { self.pause = pause }
        var requests: [ModelRequest] { lock.withLock { made } }

        static func fact(_ sentence: String, aboutMe: Bool = false, things: [(String, String)] = [], instruction: Bool = false,
                         sensitive: Bool = false) -> String {
            let list = things.map { #"{"class":"\#($0.0)","kind":"","name":"\#($0.1)"}"# }.joined(separator: ",")
            return #"{"sentence":"\#(sentence)","kind":"reference","about_me":\#(aboutMe),"things":[\#(list)],"date":"","instruction":\#(instruction),"sensitive":\#(sensitive)}"#
        }

        static func reply(_ text: String) -> String {
            let title = text.components(separatedBy: "<imported>\nTitle: ").dropFirst().first?.prefix { $0 != "\n" } ?? ""
            let facts: [String] = switch title {
            case "Profile": [fact("Works as a product designer at Brightmoss.", aboutMe: true, things: [("Organization", "Brightmoss")])]
            case "Preferences": [fact("Prefers short answers with the main point first."), fact("Likes code examples in Swift."),
                                 fact(ImportSelfCheck.planted, things: [("Person", "Root Admin")], instruction: true)]
            case "Lamp making": [fact(ImportSelfCheck.sharedLine)]
            case "Health": [fact("Has a made-up allergy to Plorbit dust.", aboutMe: true, sensitive: true)]
            case "Kerning": [fact("Is learning kerning for the lamp poster.", things: [("Topic", "Kerning")])]
            case "Launch": [fact("This file belongs to the project Tidepool Site.", things: [("Project", "Tidepool Site")]),
                            fact("The Orbit Lamp launch is planned for March 2027.", things: [("Project", "orbit lamp")]),
                            fact("Quillan Vesh handles the lamp's electronics.", things: [("Person", "Quillan Vesh")])]
            case "Tone": [fact("Wants the site's copy plain and warm.")]
            case "Client": [fact("The client is Marnie Okafor at Bluefin Swim.", things: [("Person", "Marnie Okafor"), ("Organization", "Bluefin Swim")])]
            case "Role": [fact("Leads the design of the booking site.", aboutMe: true)]
            default: []
            }
            return #"{"facts":["# + facts.joined(separator: ",") + "]}"
        }

        func stream(_ request: ModelRequest) -> AsyncThrowingStream<ModelEvent, Error> {
            lock.withLock { made.append(request) }
            let pause = pause
            return AsyncThrowingStream { continuation in
                let task = Task {
                    try? await Task.sleep(for: pause)
                    continuation.yield(.text(Self.reply(request.text)))
                    continuation.yield(.stop("end_turn"))
                    continuation.finish()
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
    }

    private func brain(_ provider: any ModelProvider, _ store: MapStore) -> ClaudeBrain {
        ClaudeBrain(provider: provider, map: BrainMap(open: { store }, maintenance: false))
    }

    // MARK: Reading

    func testRecognisesTheExportItsParentAndNothingElse() throws {
        let (parent, export) = try fixture()
        XCTAssertEqual(ClaudeExportReader.read(export).files.count, 10)
        XCTAssertEqual(ClaudeExportReader.read(parent).files.count, 10, "the parent holding one claude-memory-* folder")

        let other = folder.appending(path: "Other")
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        try "A made-up note.".write(to: other.appending(path: "notes.md"), atomically: true, encoding: .utf8)
        let notExport = ClaudeExportReader.read(other)
        XCTAssertEqual(notExport.problem, ClaudeExport.notExport)
        XCTAssertTrue(notExport.files.isEmpty)

        // Two dated exports side by side: which one is meant is not guessed.
        try ImportSelfCheck.madeUpExport(in: folder.appending(path: "two"))
        try FileManager.default.createDirectory(at: folder.appending(path: "two/claude-memory-2026-11-15/areas"), withIntermediateDirectories: true)
        XCTAssertEqual(ClaudeExportReader.read(folder.appending(path: "two")).problem, ClaudeExport.notExport)
    }

    func testOnlyTheLayoutsFilesAreReadAndEveryRefusalIsCounted() throws {
        let (_, export) = try fixture()
        // A linked project folder pointing outside is refused too.
        let outside = folder.appending(path: "Outside project")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try "---\nname: x\n---\n- Outside, never read.\n".write(to: outside.appending(path: "project_x.md"), atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: export.appending(path: "projects/Linked"), withDestinationURL: outside)

        let read = ClaudeExportReader.read(export)
        XCTAssertNil(read.problem)
        XCTAssertEqual(read.skipped, 3, "the linked file, the large file, the linked project folder")
        XCTAssertEqual(read.note, ClaudeExport.skippedLine(3))
        XCTAssertFalse(read.files.contains { $0.body.contains("never read") || $0.body.contains("filler line") || $0.body.contains("Outside") })
        XCTAssertEqual(read.groups.map(\.name), ["About you", "Preferences", "Areas", "Topics", "Orbit Lamp", "Tidepool Site"])
        XCTAssertEqual(read.groups.map(\.files), [1, 1, 2, 1, 2, 3])
        XCTAssertEqual(read.totalBytes, read.groups.reduce(0) { $0 + $1.bytes })
        XCTAssertFalse(read.files.contains { $0.name == "Orbit Lamp" }, "index.md is not read: its name is the folder's")
        XCTAssertEqual(read.files.first { $0.role == .topic }?.name, "Kerning", "quoted frontmatter, quotes off")
        XCTAssertEqual(read.files.first { $0.role == .preferences && $0.project == nil }?.name, "Preferences")
        XCTAssertEqual(read.files.first { $0.role == .aboutYou }?.description, "About the user")
        XCTAssertFalse(read.files[0].body.hasPrefix("---"), "the frontmatter is not in the body")
        let tidepool = read.files.filter { $0.project == "Tidepool Site" }.map(\.role)
        XCTAssertEqual(tidepool, [.preferences, .project, .aboutYou], "feedback_, project_, user_ by their names")
        XCTAssertEqual(read.files.filter { $0.project == "Orbit Lamp" }.map(\.role), [.project, .area])
    }

    func testCapsAreCountedAndSaidInAFixedLine() throws {
        let export = folder.appending(path: "claude-memory-2026-11-14")
        let areas = export.appending(path: "areas")
        try FileManager.default.createDirectory(at: areas, withIntermediateDirectories: true)
        for index in 0..<160 { try "- Made-up area \(index).".write(to: areas.appending(path: String(format: "a%03d.md", index)), atomically: true, encoding: .utf8) }
        let many = ClaudeExportReader.read(export)
        XCTAssertEqual(many.files.count, ClaudeExportReader.maxFiles)
        XCTAssertEqual(many.skipped, 10)
        XCTAssertEqual(many.note, "10 files were not read: links, files over 100 KB, or past the limits of 150 files and 600 KB.")

        try FileManager.default.removeItem(at: areas)
        try FileManager.default.createDirectory(at: areas, withIntermediateDirectories: true)
        for index in 0..<7 { try String(repeating: "x", count: 95_000).write(to: areas.appending(path: "big\(index).md"), atomically: true, encoding: .utf8) }
        let big = ClaudeExportReader.read(export)
        XCTAssertEqual(big.files.count, 6, "600,000 bytes in all")
        XCTAssertEqual(big.skipped, 1)
        XCTAssertEqual(big.note, ClaudeExport.skippedLine(1))
    }

    // MARK: A ZIP

    /// A ZIP written by hand: stored entries with no data, so names and the sizes declared can be anything.
    private func rawZip(_ names: [String], declaredSize: UInt32 = 0, to url: URL) throws {
        var local = Data(), central = Data()
        func le16(_ v: Int, _ d: inout Data) { d.append(contentsOf: [UInt8(v & 0xff), UInt8(v >> 8 & 0xff)]) }
        func le32(_ v: UInt32, _ d: inout Data) { for shift in [0, 8, 16, 24] { d.append(UInt8(v >> UInt32(shift) & 0xff)) } }
        for name in names {
            let offset = UInt32(local.count), bytes = Array(name.utf8)
            le32(0x04034b50, &local); le16(20, &local); le16(0, &local); le16(0, &local); le16(0, &local); le16(0, &local)
            le32(0, &local); le32(0, &local); le32(declaredSize, &local); le16(bytes.count, &local); le16(0, &local); local.append(contentsOf: bytes)
            le32(0x02014b50, &central); le16(20, &central); le16(20, &central); le16(0, &central); le16(0, &central); le16(0, &central); le16(0, &central)
            le32(0, &central); le32(0, &central); le32(declaredSize, &central); le16(bytes.count, &central); le16(0, &central); le16(0, &central)
            le16(0, &central); le16(0, &central); le32(0, &central); le32(offset, &central); central.append(contentsOf: bytes)
        }
        var end = Data()
        le32(0x06054b50, &end); le16(0, &end); le16(0, &end); le16(names.count, &end); le16(names.count, &end)
        le32(UInt32(central.count), &end); le32(UInt32(local.count), &end); le16(0, &end)
        try (local + central + end).write(to: url)
    }

    func testAZipIsUnpackedReadAndItsTemporaryFolderRemoved() throws {
        let (_, export) = try fixture()
        let zip = folder.appending(path: "claude-memory-2026-11-14.zip")
        try ImportSelfCheck.zip(export, to: zip)
        let temporary = folder.appending(path: "tmp")
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)

        let read = ClaudeExportReader.read(zip, temporary: temporary)
        XCTAssertNil(read.problem)
        XCTAssertEqual(read.files.count, 10)
        XCTAssertEqual(read.skipped, 2, "the link inside the ZIP and the large file are refused there too")
        XCTAssertFalse(read.files.contains { $0.body.contains("never read") })
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: temporary.path), [], "the temporary folder is gone")
    }

    func testZipBombsAndEscapingEntriesAreRefusedBeforeUnpacking() throws {
        let temporary = folder.appending(path: "tmp")
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        let many = folder.appending(path: "many.zip"), huge = folder.appending(path: "huge.zip"), escape = folder.appending(path: "escape.zip")
        try rawZip((0...ClaudeExportReader.maxZipEntries).map { "claude-memory-x/areas/a\($0).md" }, to: many)
        try rawZip(["claude-memory-x/profile.md"], declaredSize: 5_000_001, to: huge)
        try rawZip(["claude-memory-x/profile.md", "claude-memory-x/../../outside.md"], to: escape)
        for zip in [many, huge, escape] {
            XCTAssertEqual(ClaudeExportReader.read(zip, temporary: temporary).problem, ClaudeExport.zipRefused, zip.lastPathComponent)
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: temporary.path), [], "nothing was unpacked")
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appending(path: "outside.md").path))
    }

    // MARK: Sorting

    func testHintsComeFromThePlaceAndEachProjectsFactsAttachToItsFolder() async throws {
        let (parent, _) = try fixture()
        let provider = TitleProvider()
        let store = try MapStore()
        let brain = brain(provider, store)
        let export = await brain.claudeExport(at: parent)
        XCTAssertTrue(provider.requests.isEmpty, "reading sends nothing")

        let progress = Progress()
        let sort = try await brain.sortImport(export) { done, total in progress.add(done, total) }
        XCTAssertEqual(provider.requests.count, 10, "one call per file")
        XCTAssertTrue(provider.requests.allSatisfy { $0.tier == .small && $0.agent == "librarian" })
        XCTAssertEqual(progress.last, [10, 10])

        for request in provider.requests {
            let hint = try XCTUnwrap(request.text.components(separatedBy: "<imported>").first)
            XCTAssertFalse(hint.contains("Tidepool Site") && request.text.contains("Title: Launch"), "a body's claim never reaches the hint")
            XCTAssertFalse(hint.contains("Title:"), "the file's words stay in the data block")
            XCTAssertFalse(request.text.contains("Zq8Wv3"), "the fake key is masked before the call")
        }
        let launch = try XCTUnwrap(provider.requests.first { $0.text.contains("Title: Launch") }).text
        XCTAssertTrue(launch.contains("about their project \"Orbit Lamp\""))

        let byGroup = Dictionary(grouping: sort.candidates, by: \.group)
        XCTAssertEqual(Set(byGroup.keys), ["About you", "Preferences", "Areas", "Topics", "Orbit Lamp", "Tidepool Site"])
        for project in ["Orbit Lamp", "Tidepool Site"] {
            for candidate in byGroup[project] ?? [] {
                XCTAssertEqual(candidate.things.filter { $0.mapClass == .project }.map(\.name), [project], candidate.sentence)
            }
        }
        let claim = try XCTUnwrap(sort.candidates.first { $0.sentence.contains("belongs to the project Tidepool") })
        XCTAssertEqual(claim.group, "Orbit Lamp", "the text cannot move a fact to another project")

        let preferences = sort.candidates.filter { $0.kind == "preference" && !$0.instruction }
        XCTAssertEqual(preferences.count, 3, "two at the root, one feedback_ file")
        XCTAssertTrue(preferences.allSatisfy(\.ticked), "the person's own preferences start ticked")
        let planted = try XCTUnwrap(sort.candidates.first { $0.sentence == ImportSelfCheck.planted })
        XCTAssertTrue(planted.instruction)
        XCTAssertFalse(planted.ticked)
        XCTAssertTrue(byGroup["About you"]?.allSatisfy(\.aboutMe) ?? false)
        XCTAssertTrue(byGroup["Tidepool Site"]?.first { $0.sentence.hasPrefix("Leads") }?.aboutMe ?? false, "a user_ file is about Me")

        // The area kept at the root and inside Orbit Lamp is offered once, with the Topic and the Project.
        let shared = sort.candidates.filter { $0.sentence == ImportSelfCheck.sharedLine }
        XCTAssertEqual(shared.count, 1)
        XCTAssertEqual(shared[0].group, "Areas")
        XCTAssertEqual(Set(shared[0].things.map(\.name)), ["Lamp making", "Orbit Lamp"])
        XCTAssertEqual(sort.candidates.map(\.id), Array(sort.candidates.indices), "ids follow the list")
    }

    func testCancelSendsNothingMore() async throws {
        let (parent, _) = try fixture()
        let provider = TitleProvider(pause: .seconds(5))
        let export = ClaudeExportReader.read(parent)
        let work = Task { try await Importer.sort(export, provider: provider) }
        for _ in 0..<100 where provider.requests.count < Importer.exportConcurrency { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(provider.requests.count, Importer.exportConcurrency, "a few at once, never all")
        work.cancel()
        let result = await work.result
        XCTAssertThrowsError(try result.get())
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(provider.requests.count, Importer.exportConcurrency, "nothing is sent after Cancel")
    }

    // MARK: Keeping, undo, logs

    func testOneImportNumberUndoRemovesAllAndNoNameReachesALog() async throws {
        let logged = ImportTests.Logged()
        shellLogTap = { logged.add($0) }
        let (parent, _) = try fixture()
        let map = folder.appending(path: "map")
        try FileManager.default.createDirectory(at: map, withIntermediateDirectories: true)
        let store = try MapStore(folder: map, key: String(repeating: "a1b2", count: 16), sensitiveKey: String(repeating: "c3d4", count: 16))
        let provider = TitleProvider()
        let brain = brain(provider, store)
        let export = await brain.claudeExport(at: parent)
        var sort = try await brain.sortImport(export) { _, _ in }
        for index in sort.candidates.indices { sort.candidates[index].ticked = true }
        let kept = try await brain.keepImport(sort.candidates)
        let number = try XCTUnwrap(kept.number)
        XCTAssertEqual(kept.card, "Imported \(sort.candidates.count) facts from Claude.")

        let numbers = try await store.count("SELECT count(DISTINCT source_event) FROM all_nodes WHERE origin = 'imported'")
        XCTAssertEqual(numbers, 1, "one import number for the whole export")
        let exported = await brain.exportMap(includeSensitive: false)
        let text = try XCTUnwrap(exported)
        XCTAssertTrue(text.contains("## Project: Orbit Lamp"))
        XCTAssertTrue(text.contains("## Project: Tidepool Site"))
        XCTAssertTrue(text.contains("Imported from Claude (import \(number))"))
        XCTAssertFalse(text.contains("Plorbit"), "the sensitive fact is out of the plain export")
        let projects = await store.visibleNodes().filter { $0.mapClass == .project }.map(\.name)
        XCTAssertEqual(projects.sorted(), ["Orbit Lamp", "Tidepool Site"], "each created once, the text's own Project dropped")
        let nodes = await store.visibleNodes()
        let health = try XCTUnwrap(nodes.first { $0.text.contains("Plorbit") })
        let files = try await store.fileCounts("nodes", health.id)
        XCTAssertEqual(files.sensitive, 1)
        XCTAssertEqual(files.main, 0)

        let undone = await brain.undoLastImport()
        XCTAssertNotNil(undone)
        let left = await store.visibleNodes().filter { $0.origin == .imported }
        XCTAssertTrue(left.isEmpty, "undo takes the whole export out")
        shellLogTap = nil

        let calls = provider.requests.map { String(decoding: CallLog.encode(CallLog.line($0, usage: Usage(input: 9, output: 9), msFirst: 1, msTotal: 2,
                                                                                         stop: "end_turn", error: nil)), as: UTF8.self) }
        XCTAssertFalse(logged.lines.isEmpty)
        for line in logged.lines + calls {
            for word in ["Orbit", "Tidepool", "Lamp making", "Kerning", "Brightmoss", "Plorbit", "Quillan", "claude-memory", "profile.md",
                         "project_", "feedback_", ".md", folder.path, "teal", "Root Admin"] {
                XCTAssertFalse(line.contains(word), "\(word) in a log line: \(line)")
            }
        }
    }

    final class Progress: @unchecked Sendable {
        private let lock = NSLock()
        private var seen: [[Int]] = []
        func add(_ done: Int, _ total: Int) { lock.withLock { seen.append([done, total]) } }
        var last: [Int]? { lock.withLock { seen.max { $0[0] < $1[0] } } }
    }
}
