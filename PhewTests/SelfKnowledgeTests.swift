import XCTest
@testable import Phew

/// Phew knows himself (PS.14): the fixed text in the Guide's system prompt, the live facts in a `<self>` block.
/// A fake provider and a Map in memory with made-up data. No network, never the real Map.
final class SelfKnowledgeTests: XCTestCase {
    typealias FakeProvider = BrainAgentsTests.FakeProvider
    typealias Reply = FakeProvider.Reply

    private let made = "QUOKKA-MADE-UP"

    private func packet(_ text: String) -> ContextPacket {
        ContextPacket(appName: "\(made) App", bundleID: "com.example.made-up", windowTitle: "\(made) Window", visibleText: text,
                      cursor: nil, windowFrame: CGRect(x: 0, y: 0, width: 800, height: 600))
    }

    /// Asks through the whole Brain on a made-up Map and returns the Guide's request.
    private func guideRequest(_ question: String, state: ShellState, store: MapStore?) async throws -> ModelRequest {
        let fake = FakeProvider(rounds: ["conductor": [Reply(pieces: [#"{"route":"explain"}"#])],
                                         "guide": [Reply(pieces: [#"{"explanation":"Made-up answer.","steps":[]}"#])]])
        let brain = ClaudeBrain(provider: fake, map: BrainMap(open: {
            guard let store else { throw MapError.underTests }
            return store
        }))
        for try await _ in brain.answer(question, packet: packet("\(made) screen"), state: state) {}
        _ = await brain.map.ready()
        return try XCTUnwrap(fake.requests.first { $0.agent == "guide" })
    }

    private func store() async throws -> MapStore {
        let store = try MapStore()
        let project = try await store.add(MapNode(mapClass: .project, kind: "client job", name: "\(made) Bakery", origin: .told))
        let note = try await store.add(MapNode(mapClass: .note, kind: "fact", text: "\(made) secret recipe.", origin: .told))
        try await store.add(MapEdge(from: note, to: project, link: .about, origin: .told))
        try await store.add(MapNode(mapClass: .task, kind: "delivery", name: "\(made) old task", origin: .told, sensitive: true))
        return store
    }

    func testRequestCarriesTheFixedTextAndASelfBlock() async throws {
        let state = ShellState(accessibility: true, screenRecording: false, guideRunning: true)
        let request = try await guideRequest("Who are you?", state: state, store: try await store())

        XCTAssertTrue(request.system.contains(SelfKnowledge.text))
        XCTAssertEqual(request.system, Guide.system)
        // The Map rules come last, after the self text, so the rule "a period needs one search" keeps its force.
        let selfText = try XCTUnwrap(request.system.range(of: SelfKnowledge.text))
        XCTAssertNotNil(request.system.range(of: "What Phew remembers", range: selfText.upperBound..<request.system.endIndex))
        XCTAssertTrue(request.system.hasSuffix("nothing more is there: do not search again."))
        XCTAssertTrue(request.text.contains("</map>\n\n<self>\n"))  // next to the Map's block, before the screen
        let block = try XCTUnwrap(request.text.components(separatedBy: "<self>").last?.components(separatedBy: "</self>").first)
        XCTAssertTrue(block.contains("Accessibility permission: on"))
        XCTAssertTrue(block.contains("Screen Recording permission: off"))
        XCTAssertTrue(block.contains("Guide running when asked: yes"))
        XCTAssertTrue(block.contains("Question in this conversation: 1"))
        // A project, a Note and a sensitive Task: three facts; Me is not one.
        XCTAssertTrue(block.contains("Map: 1 projects, 3 facts"))
        XCTAssertFalse(block.contains(made))
    }

    func testWithoutAMapOrAShellTheBlockSaysSo() async throws {
        let request = try await guideRequest("What can you do?", state: ShellState(), store: nil)
        XCTAssertTrue(request.text.contains("Accessibility permission: unknown"))
        XCTAssertTrue(request.text.contains("Map: not available"))
    }

    /// Every line of the block, past its label, is a number or a fixed state word: never a word from the user.
    func testLiveFactsHoldOnlyNumbersAndStateWords() async throws {
        let store = try await store()
        let counts = await store.counts()
        XCTAssertEqual(counts.projects, 1)
        XCTAssertEqual(counts.facts, 3)
        let info: [String: Any] = ["CFBundleShortVersionString": "0.1 \(made)", "CFBundleVersion": "7"]
        let labels = ["Accessibility permission:", "Screen Recording permission:", "Guide running when asked:",
                      "Let Phew act:", "Question in this conversation:", "Map:", "App version:"]
        let words: Set = ["on", "off", "unknown", "yes", "no", "projects", "facts", "not", "available", "build"]
        for state in [ShellState(), ShellState(accessibility: true, screenRecording: true, guideRunning: true, acting: true)] {
            for (projects, facts) in [(counts.projects, counts.facts), (nil, nil)] as [(Int?, Int?)] {
                let text = SelfKnowledge.live(state, turn: 3, projects: projects, facts: facts, info: info)
                let lines = text.split(separator: "\n").map(String.init)
                XCTAssertEqual(lines.first, "<self>")
                XCTAssertEqual(lines.last, "</self>")
                for line in lines.dropFirst().dropLast() {
                    let label = try XCTUnwrap(labels.first { line.hasPrefix($0) }, line)
                    for token in line.dropFirst(label.count).split(whereSeparator: { $0 == " " || $0 == "," }) {
                        XCTAssertTrue(words.contains(String(token)) || token.allSatisfy { $0.isNumber || $0 == "." }, String(token))
                    }
                }
                XCTAssertTrue(text.contains("App version: 0.1, build 7"))
            }
        }
    }

    /// PH.8: he knows he acts, how, where, what he never touches and how a job is stopped; nothing says he cannot.
    func testTheTextSaysHeActs() {
        let text = SelfKnowledge.text
        for part in ["Do a job when the user asks you to do it", "with no confirm", "Asked how, you show instead",
                     "In Notes, Reminders, Calendar and Excel you work through the app's own scripting, behind the app",
                     "press buttons, type into fields, pick menu items, and click on a spot",
                     "One job may use several apps", "bring the user back to where they were",
                     "it is on from the start", "\"Let Phew act\" switch in the menu",
                     "Stop on the card", "click or key in the app you are working in hands the job back",
                     "secure fields", "pay or enter card details", "sign in", "System Settings, Terminal, code editors, password managers",
                     "never act in it", "your own windows"] {
            XCTAssertTrue(text.contains(part), part)
        }
        for stale in ["act in apps for the user", "cannot do yet: act", "not files, mail or other apps"] {
            XCTAssertFalse(text.contains(stale), stale)
        }
        XCTAssertTrue(SelfKnowledge.live(ShellState(acting: true), turn: 1, projects: nil, facts: nil).contains("Let Phew act: on"))
        XCTAssertTrue(SelfKnowledge.live(ShellState(acting: false), turn: 1, projects: nil, facts: nil).contains("Let Phew act: off"))
    }

    /// PL.5: he knows he researches tasks alone, up to three, reports as a PDF, and adds items in the background.
    func testTheTextSaysHeResearchesTasks() {
        let text = SelfKnowledge.text
        for part in ["Research a task on your own and report back", "up to three tasks at once", "saved as a PDF",
                     "or Downloads, never over an existing file", "a note, a reminder, an event or a sheet in the background",
                     "a task only adds, never changes or deletes"] {
            XCTAssertTrue(text.contains(part), part)
        }
        XCTAssertFalse(text.contains("cannot do yet: research"))
    }

    /// PB: he knows he imports what other assistants know, by paste and from a Claude Code folder, ticked, undoable.
    func testTheTextSaysHeImportsMemory() {
        let text = SelfKnowledge.text
        for part in ["Import what other AI assistants know", "paste the memory list", "Claude Code project folder",
                     "the user ticks the ones you keep", "\"Undo last import\""] {
            XCTAssertTrue(text.contains(part), part)
        }
        XCTAssertFalse(text.contains("import memory from other AI tools"))
    }

    func testFixedPartIsTheSameForTwoQuestions() async throws {
        let one = try await guideRequest("Who are you?", state: ShellState(accessibility: true), store: try await store())
        let two = try await guideRequest("How do I export a PDF?", state: ShellState(screenRecording: false), store: nil)
        XCTAssertEqual(one.system, two.system)
        XCTAssertEqual(Data(one.system.utf8), Data(SelfKnowledgeTests.systemOnce.utf8))
        XCTAssertNotEqual(one.text, two.text)
    }

    private static let systemOnce = Guide.system

    /// PS.16: a guide gets the same instructions without the self text and without the live facts; an explanation
    /// keeps both.
    func testOnlyAnExplanationGetsTheSelfTextAndTheLiveFacts() {
        let about = SelfKnowledge.live(ShellState(), turn: 1, projects: nil, facts: nil)
        let guide = Guide.request("How do I add a table?", packet: packet("x"), route: .guide, shot: nil, about: about)
        XCTAssertEqual(guide.system, Guide.guideSystem)
        XCTAssertFalse(guide.system.contains(SelfKnowledge.text))
        XCTAssertFalse(guide.text.contains("<self>"))
        XCTAssertTrue(guide.system.contains("When the route is guide, also give the steps"))
        XCTAssertTrue(guide.system.contains("steps empty.\n\nWhat Phew remembers"))
        XCTAssertEqual(guide.system.count, Guide.system.count - SelfKnowledge.text.count - 2)
        let explain = Guide.request("Who are you?", packet: packet("x"), route: .explain, shot: nil, about: about)
        XCTAssertEqual(explain.system, Guide.system)
        XCTAssertTrue(explain.text.contains("<self>"))
    }

    /// The five live cases of `--debug-brain-check` run offline on a fake provider, and the email check refuses a
    /// claim that it was sent.
    func testSelfCheckCasesRunWithoutTheNetwork() async throws {
        func provider(_ answer: String) -> FakeProvider {
            FakeProvider(rounds: ["conductor": [Reply(pieces: [#"{"route":"explain"}"#])],
                                  "guide": [Reply(pieces: [#"{"explanation":"\#(answer)","steps":[]}"#])]])
        }
        let email = try XCTUnwrap(BrainSelfCheck.selfCases.last)
        XCTAssertEqual(BrainSelfCheck.selfCases.count, 5)
        let refused = try await email.run(provider("I can't send email for you yet. Click Send yourself."))
        XCTAssertTrue(refused.0, refused.1)
        let claimed = try await email.run(provider("Done, I sent it."))
        XCTAssertFalse(claimed.0, claimed.1)
        for item in BrainSelfCheck.selfCases.dropLast() {
            let result = try await item.run(provider("I'm Phew, a shy chick in the menu bar."))
            XCTAssertFalse(result.1.isEmpty)
        }
    }
}
