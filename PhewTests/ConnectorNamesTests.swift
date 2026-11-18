import XCTest
@testable import Phew

/// Phase NF offline: a request that names a connector reaches it (NF.1), the agents are told the ticked names (NF.2),
/// a connector with no tools cannot be ticked (NF.4), money writes wait for the confirm in a watched job too (NF.5),
/// and a failed connector step says why on the card (NF.6). Made-up tool lists, throwaway settings, fake doors and
/// seams. The real Claude Code is never run: the door's program is a path that is never started here.
@MainActor
final class ConnectorNamesTests: XCTestCase {
    typealias Script = RunnerTests.Script
    typealias FakeDoor = ConnectionsTests.FakeDoor
    typealias FakeSeam = ConnectionsTests.FakeSeam

    private var suite = ""
    private var defaults: UserDefaults!
    private var saved: (calls: URL, actions: URL)!
    private var root: URL!

    override func setUp() async throws {
        suite = "PhewTests.connectorNames.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.set(true, forKey: Hand.allowedKey)
        root = FileManager.default.temporaryDirectory.appending(path: "ConnectorNamesTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        saved = (CallLog.url, ActionLog.url)
        CallLog.url = root.appending(path: "calls.log")  // never the user's real logs
        ActionLog.url = root.appending(path: "actions.log")
    }

    override func tearDown() async throws {
        ActionLog.flush()
        (CallLog.url, ActionLog.url) = saved
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: Made-up connectors of a Claude account

    static let gmail = ClaudeServer(name: "claude.ai Gmail", tools: ["create_draft", "download_gmail_attachment", "get_thread", "search_threads"])
    static let calendar = ClaudeServer(name: "claude.ai Google Calendar", tools: ["create_event", "list_calendars", "list_events"])
    static let spotify = ClaudeServer(name: "claude.ai Spotify", tools: ["get_currently_playing", "play", "search"])
    static let notion = ClaudeServer(name: "claude.ai Notion", tools: ["notion-create-pages", "notion-search"])

    /// A door switched on, with the given servers listed and those in `ticked` ticked. Its program is never started.
    private func door(_ servers: [ClaudeServer], ticked: [String]? = nil) -> ClaudeCodeDoor {
        let door = ClaudeCodeDoor(program: root.appending(path: "never-run/claude"), defaults: defaults)
        door.set(on: true)
        defaults.removeObject(forKey: ClaudeCodeDoor.tickedKey)
        defaults.set(try? JSONEncoder().encode(servers), forKey: ClaudeCodeDoor.listedKey)
        for name in ticked ?? servers.map(\.name) { door.tick(name, true) }
        return door
    }

    private func allowed(_ door: ClaudeCodeDoor, _ words: String) -> Set<String> { Set(door.plan(for: words).allowed.keys) }
    private func all(_ server: ClaudeServer) -> Set<String> { Set(server.tools.map { server.prefix + $0 }) }

    // MARK: NF.1 Naming a connector selects it

    func testNamingAConnectorOffersAllItsToolsAndNoOtherInEnglishOrItalian() {
        let door = door([Self.gmail, Self.calendar, Self.spotify, Self.notion])
        for words in ["Find the last email from Anna in Gmail", "Trova l'ultima email di Anna su Gmail", "trova in GMAIL la mail di Anna"] {
            XCTAssertEqual(allowed(door, words), all(Self.gmail), words)
        }
        for words in ["What is on my Google Calendar tomorrow?", "Cosa ho nel calendario domani?", "Che impegni ho domani su Google Calendar?"] {
            XCTAssertEqual(allowed(door, words), all(Self.calendar), words)
        }
        for words in ["Play some jazz on Spotify", "Metti un po' di jazz su Spotify"] {
            XCTAssertEqual(allowed(door, words), all(Self.spotify), words)
        }
        // Every other server is refused by name; each call is still judged by the gate.
        let plan = door.plan(for: "Play some jazz on Spotify")
        XCTAssertTrue(plan.refused.contains("mcp__claude_ai_Gmail") && plan.refused.contains("mcp__claude_ai_Notion"))
        XCTAssertEqual(plan.allowed["mcp__claude_ai_Spotify__play"]?.gate.name, "Spotify")
        // Two named: both, whole.
        XCTAssertEqual(allowed(door, "Put the Gmail thread into Notion"), all(Self.gmail).union(all(Self.notion)))
        // None named: the word match as before.
        XCTAssertEqual(allowed(door, "search the made-up threads"),
                       ["mcp__claude_ai_Gmail__search_threads", "mcp__claude_ai_Gmail__get_thread", "mcp__claude_ai_Spotify__search",
                        "mcp__claude_ai_Notion__notion-search"])
        XCTAssertTrue(allowed(door, "Summarise the made-up budget").isEmpty)
        // An unticked server is never offered, named or not.
        let some = self.door([Self.gmail, Self.spotify], ticked: [Self.gmail.name])
        XCTAssertTrue(allowed(some, "Play some jazz on Spotify").isEmpty)
    }

    func testTheNameMatchIgnoresGenericWords() {
        XCTAssertEqual(Connections.nameTerms("claude.ai Google Calendar"), ["calendar"])
        XCTAssertEqual(Connections.nameTerms("claude.ai Google Cloud BigQuery"), ["bigquery"])
        XCTAssertTrue(Connections.nameTerms("claude.ai Google Cloud").isEmpty, "only generic words: never named")
        XCTAssertFalse(Connections.names("Search my Google account", connector: "claude.ai Google Calendar"))
        XCTAssertTrue(Connections.names("drives?", connector: "Google Drive"), "a plural counts")
        XCTAssertFalse(Connections.names("Send it by mail", connector: "claude.ai Gmail"))
    }

    func testOwnClientNamedServerIsFilledUpToTheLimitAndNoOther() async throws {
        let mail = ConnectorServer(id: "madegmail", name: "Gmail", url: URL(string: "https://mcp.made-up.test/gmail")!,
                                   reads: ["made-get-thread"])
        let music = ConnectorServer(id: "madespotify", name: "Spotify", url: URL(string: "https://mcp.made-up.test/spotify")!)
        let mailTools = ["made-search-threads", "made-get-thread", "made-create-draft"].map { ConnectionsTests.tool($0) }
            + (1...20).map { ConnectionsTests.tool("made-label-\($0)") }
        let mailDoor = FakeDoor(mailTools), musicDoor = FakeDoor([ConnectionsTests.tool("made-play"), ConnectionsTests.tool("made-search")])
        let connections = Connections(servers: [mail, music], defaults: defaults, make: { $0.id == mail.id ? mailDoor : musicDoor })
        _ = try await connections.connect(mail.id, open: { _ in })
        _ = try await connections.connect(music.id, open: { _ in })

        let named = await connections.offer(for: "Trova l'ultima email di Anna su Gmail")
        XCTAssertEqual(Set(named.map(\.server.id)), [mail.id], "no other connector's tools")
        XCTAssertEqual(named.count, Connections.mostTools, "filled up to the limit")
        XCTAssertEqual(named.first?.tool.name, "made-get-thread", "Phew's table's reads first when no word fits")
        let fitting = await connections.offer(for: "search the threads in Gmail")
        XCTAssertEqual(fitting.first?.tool.name, "made-search-threads", "the best word match first")
        let music2 = await connections.offer(for: "Play some jazz on Spotify")
        XCTAssertEqual(Set(music2.map(\.tool.name)), ["made-play", "made-search"])
        // None named: the word match as before, across servers.
        let none = await connections.offer(for: "search")
        XCTAssertEqual(Set(none.map(\.tool.name)), ["made-search-threads", "made-search"])
        XCTAssertEqual(connections.connectedNames, ["Gmail", "Spotify"])
    }

    // MARK: NF.2 The agents are told the ticked names

    static let packet = ContextPacket(appName: "Made-up app", bundleID: "com.example.madeup", windowTitle: "Made-up", visibleText: "", cursor: nil)

    func testTheDoerIsToldTheTickedConnectorsOnly() async throws {
        let door = door([Self.gmail, Self.spotify, Self.notion], ticked: [Self.gmail.name, Self.notion.name])
        let script = Script([.init(text: #"{"action":"done","element":null,"point":null,"menu":[],"text":"Done."}"#)])
        let brain = ClaudeBrain(provider: script, claudeCode: door)
        _ = try await brain.nextAction("Find the last email from Anna in Gmail", packet: Self.packet, done: [])
        let request = try XCTUnwrap(script.requests.first)
        let cached = try XCTUnwrap(request.cached)
        XCTAssertTrue(cached.contains("Connected: Gmail, Notion."), cached)
        XCTAssertFalse(cached.contains("Spotify") || request.text.contains("Spotify"), "an unticked name is never sent")
        XCTAssertTrue(Doer.system.contains("When the request names one of them, use a connector step for that part before the screen"))
        // Off: none at all.
        door.set(on: false)
        _ = try await brain.nextAction("Find the last email from Anna in Gmail", packet: Self.packet, done: [])
        XCTAssertFalse(script.requests[1].cached?.contains("Connected:") ?? false)
    }

    func testTheRunnerIsToldTheConnectedServersOnly() async throws {
        let mail = ConnectorServer(id: "madegmail", name: "Gmail", url: URL(string: "https://mcp.made-up.test/gmail")!)
        let music = ConnectorServer(id: "madespotify", name: "Spotify", url: URL(string: "https://mcp.made-up.test/spotify")!)
        let door = FakeDoor([ConnectionsTests.tool("made-search")])
        let connections = Connections(servers: [mail, music], defaults: defaults, make: { _ in door })
        _ = try await connections.connect(mail.id, open: { _ in })
        let script = Script([.init(text: "# Made-up\n\nShort.\n\n## Not checked\n\nNothing.")])
        let brain = ClaudeBrain(provider: script, tools: RunnerTests.FakeMap(out: ""), connections: connections)
        for try await _ in brain.runTask("Research the made-up plan", packet: nil, number: 7, folder: root, add: nil) {}
        let text = try XCTUnwrap(script.requests.first?.text)
        XCTAssertTrue(text.contains("Connected: Gmail."), text)
        XCTAssertFalse(text.contains("Spotify"), "a server not connected is never named")
        XCTAssertTrue(Runner.system.contains("When the task names one of them, use its tools for that part before the web"))
        XCTAssertEqual(Runner.connected([]), "")
    }

    /// The Conductor sends a request that names a service to a job, or to a task when it asks for a report.
    func testTheConductorRoutesANamedServiceToAJobOrATask() {
        XCTAssertTrue(Conductor.system.contains(#""find the last email from Anna in Gmail", "what is on my Google Calendar tomorrow?""#))
        XCTAssertTrue(Conductor.system.contains("is act, even as a question"))
        XCTAssertTrue(Conductor.system.contains("Asking for research or a report that uses it is task."))
    }

    // MARK: NF.4 A connector with no tools

    func testAConnectorWithNoToolsCannotBeTickedAndSaysSignInFirst() async throws {
        let bare = ClaudeServer(name: "claude.ai Gmail", tools: [])
        let door = door([bare, Self.notion], ticked: [])
        door.tick(bare.name, true)
        XCTAssertEqual(door.status().first?.connected, false, "the door refuses the tick")
        // A tick kept from before, with no tools: ignored.
        defaults.set(try? JSONEncoder().encode([bare.name: [String]()]), forKey: ClaudeCodeDoor.tickedKey)
        XCTAssertEqual(door.status().first?.connected, false)
        XCTAssertEqual(door.ticked(), [])
        XCTAssertTrue(door.plan(for: "Search my Gmail").allowed.isEmpty)

        let model = ConnectionsModel(brain: ClaudeBrain(provider: Script([]), claudeCode: door), open: { _ in })
        await model.refresh()
        let row = try XCTUnwrap(model.claudeAccount.first { $0.name == "Gmail" })
        XCTAssertEqual(ConnectionsModel.summary(row), "Sign in on Claude first.")
        XCTAssertFalse(ConnectionsModel.canTick(row))
        await model.tick(bare.name, true)
        XCTAssertEqual(model.claudeAccount.first { $0.name == "Gmail" }?.connected, false, "the model refuses the tick")
        await model.tick(Self.notion.name, true)
        XCTAssertEqual(model.claudeAccount.first { $0.name == "Notion" }?.connected, true, "one with tools ticks")
        XCTAssertNotEqual(ConnectionsModel.summary(try XCTUnwrap(model.claudeAccount.first { $0.name == "Notion" })), "Sign in on Claude first.")
    }

    // MARK: NF.5 Money tools wait for the confirm, a watched job too

    func testMoneyToolsAreJudgedByPhewsCode() {
        let etoro = ClaudeCodeDoor.gate("claude.ai eToro"), ibkr = ClaudeCodeDoor.gate("claude.ai Interactive Brokers (IBKR)")
        let shop = ClaudeCodeDoor.gate("claude.ai Shopify")
        XCTAssertTrue(Connections.broker(etoro.name) && Connections.broker(ibkr.name) && Connections.broker("PayPal"))
        XCTAssertFalse(Connections.broker(shop.name) || Connections.broker("Notion") || Connections.broker("Squarespace"))
        XCTAssertEqual(Connections.access(ConnectorTool(name: "get-trades"), on: etoro), .read, "a read on a broker still runs")
        XCTAssertEqual(Connections.access(ConnectorTool(name: "list_orders"), on: ibkr), .read)
        XCTAssertEqual(Connections.access(ConnectorTool(name: "place-trade"), on: etoro), .write)
        XCTAssertEqual(Connections.access(ConnectorTool(name: "get-order"), on: shop), .write, "a money word never reads elsewhere")
        func call(_ name: String, _ tool: String) -> ConnectorCall {
            ConnectorCall(server: "claude.ai \(name)", name: name, tool: tool, arguments: Data("{}".utf8), door: .claudeAccount)
        }
        XCTAssertTrue(Connections.money(call("eToro", "create-watchlist")), "any write on a broker")
        XCTAssertTrue(Connections.money(call("Made-up", "made_sell_shares")))
        XCTAssertTrue(Connections.money(call("Made-up", "createWithdrawal")))
        XCTAssertTrue(Connections.money(call("Made-up", "rimborso-è")), "a name Phew cannot read counts")
        XCTAssertFalse(Connections.money(call("Notion", "notion-create-pages")))
    }

    func testAMoneyWriteInAWatchedJobWaitsAndRunsOnlyAfterTheConfirm() async throws {
        let seam = FakeSeam()
        let hand = Hand(defaults: defaults, surface: FakeSurface(), list: NeverReadList(defaults: defaults), connector: seam)
        let trade = ConnectorCall(server: "claude.ai eToro", name: "eToro", tool: "place-trade",
                                  arguments: Data(#"{"symbol":"MADEUP","units":3}"#.utf8), door: .claudeAccount)
        let withdraw = ConnectorCall(server: "madeup", name: "Made-up", tool: "made-withdraw", arguments: Data("{}".utf8))
        for money in [trade, withdraw] {
            let result = hand.act(HandStep(kind: .connector, pid: 0, name: money.name, connector: money), in: hand.begin(watchUser: false))
            XCTAssertEqual(result.end, .needsConfirm, money.tool)
        }
        XCTAssertEqual(seam.sent, [], "a money write never runs in a watched job")
        // Any other write in a watched job still runs, as before.
        let page = ConnectorCall(server: "madeup", name: "Made-up", tool: "made-create-pages", arguments: Data("{}".utf8))
        XCTAssertEqual(hand.act(HandStep(kind: .connector, pid: 0, connector: page), in: hand.begin(watchUser: false)).end, .done)

        // The job's step: the Hand's answer, the row in the menu, the card's line.
        struct Trading: Brain {
            let call: ConnectorCall
            func answer(_ question: String, packet: ContextPacket?) -> AsyncThrowingStream<BrainEvent, Error> { AsyncThrowingStream { $0.finish() } }
            func progress(steps: [GuideStep], current: Int, packet: ContextPacket?) async throws -> GuideProgress { GuideProgress(current: current) }
            func nextAction(_ request: String, packet: ContextPacket?, done: [String]) async throws -> NextAction {
                done.isEmpty ? .connector("Buy 3 made-up shares on eToro") : .done("Asked.")
            }
            func connectorStep(_ words: String, job: Int, ask: @escaping ConnectorAsk, stop: @escaping @Sendable () -> Bool) async -> (ok: Bool, line: String) {
                let word = await ask(call)
                return (true, Connections.answer(ConnectorAnswer(text: ClaudeCodeDoor.refusal(word))))
            }
        }
        let list = TaskList(brain: ClaudeBrain(provider: Script([])), hand: hand, folder: { nil })
        let packet = Self.packet
        var run = ActJob(brain: Trading(call: trade), hand: hand, capture: { _ in packet })
        var rows: [String] = []
        run.skilled = { line, _ in rows.append(line) }
        run.held = { list.hold($0, words: "Buy 3 made-up shares on eToro") }
        let job = hand.begin(watchUser: false)
        let outcome = await run.run("Buy 3 made-up shares on eToro", job: job) { _ in }
        hand.close(job)
        XCTAssertEqual(outcome, .done("Asked."))
        XCTAssertEqual(seam.sent, [page], "the trade did not run")
        XCTAssertEqual(rows, [ActJob.sentence(for: .needsConfirm)])
        let item = try XCTUnwrap(list.confirms.first)
        XCTAssertEqual(TaskList.asks(try XCTUnwrap(item.waits.first?.connector)), "Waiting for you: write in eToro with place-trade: symbol: MADEUP; units: 3?")
        XCTAssertTrue(list.running.isEmpty && list.waiting.isEmpty, "not a task: never in Working or Ready")
        let confirmed = await list.confirm(item.id)
        XCTAssertEqual(confirmed, .done)
        XCTAssertEqual(seam.sent, [page, trade], "it runs once, on the user's confirm")
        XCTAssertTrue(list.confirms.isEmpty)
    }

    // MARK: NF.6 A failed connector step says why

    func testEachFailedStepHasItsPlainLine() async throws {
        let door = door([Self.gmail, Self.notion, ClaudeServer(name: "claude.ai Spotify", tools: [])], ticked: [Self.gmail.name, Self.notion.name])
        let nothing = await door.step("Summarise the made-up budget", task: 1, ask: nil)
        XCTAssertEqual(nothing.end, .nothing)
        XCTAssertEqual(nothing.text, "None of the connectors you ticked fits this. Ticked: Gmail, Notion.")
        let bare = await door.step("Play some jazz on Spotify", task: 1, ask: nil)
        XCTAssertEqual(bare.end, .noTools)
        XCTAssertEqual(bare.text, "That connector offers no tools: sign in to it on Claude first.")
        // Gmail's tools changed since it was ticked: the named one says so.
        defaults.set(try? JSONEncoder().encode([ClaudeServer(name: Self.gmail.name, tools: ["search_threads"]), Self.notion]),
                     forKey: ClaudeCodeDoor.listedKey)
        let changed = await door.step("Find the last email in Gmail", task: 1, ask: nil)
        XCTAssertEqual(changed.end, .changed)
        XCTAssertEqual(changed.text, "The tools of a connector changed. Accept the change in Connections first.")
        let none = self.door([Self.gmail], ticked: [])
        let unticked = await none.step("Summarise the made-up budget", task: 1, ask: nil)
        XCTAssertEqual(unticked.text, "You have not ticked any connector in Connections.")
        let missing = await ClaudeCodeDoor(program: nil, defaults: defaults).step("Find the mail in Gmail", task: 1, ask: nil)
        XCTAssertEqual(missing.text, "Claude Code is not on this Mac.")
        door.set(on: false)
        let off = await door.step("Find the mail in Gmail", task: 1, ask: nil)
        XCTAssertEqual(off.text, "“Use my Claude account” is off in Connections.")
        XCTAssertEqual(ClaudeCodeDoor.line(.changed), "The tools of a connector changed. Accept the change in Connections first.")
        XCTAssertEqual(ClaudeCodeDoor.line(.timeout), "Claude Code did not finish in time.")
        XCTAssertEqual(ClaudeCodeDoor.line(.failed), "Claude Code could not do it. Check that it is signed in.")
    }

    func testTheCardShowsWhyAConnectorStepFailed() async {
        struct Failing: Brain {
            let line: String
            func answer(_ question: String, packet: ContextPacket?) -> AsyncThrowingStream<BrainEvent, Error> { AsyncThrowingStream { $0.finish() } }
            func progress(steps: [GuideStep], current: Int, packet: ContextPacket?) async throws -> GuideProgress { GuideProgress(current: current) }
            func nextAction(_ request: String, packet: ContextPacket?, done: [String]) async throws -> NextAction {
                done.isEmpty ? .connector("Look up the made-up page in Notion") : .stuck("Could not.")
            }
            func connectorStep(_ words: String, job: Int, ask: @escaping ConnectorAsk, stop: @escaping @Sendable () -> Bool) async -> (ok: Bool, line: String) {
                (false, line)
            }
        }
        let hand = Hand(defaults: defaults, surface: FakeSurface(), list: NeverReadList(defaults: defaults))
        let packet = Self.packet
        for end in [DoorEnd.nothing, .noTools, .changed, .timeout, .off, .missing] {
            var run = ActJob(brain: Failing(line: ClaudeCodeDoor.line(end)), hand: hand, capture: { _ in packet })
            var rows: [(String, Bool)] = []
            run.skilled = { rows.append(($0, $1)) }
            let job = hand.begin(watchUser: false)
            _ = await run.run("Look up the made-up page in Notion", job: job) { _ in }
            hand.close(job)
            XCTAssertEqual(rows.first?.0, ClaudeCodeDoor.line(end), "\(end)")
            XCTAssertEqual(rows.first?.1, false)
        }
    }
}
