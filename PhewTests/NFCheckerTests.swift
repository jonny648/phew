import XCTest
@testable import Phew

/// Phase NF, the checker's attempts to break it. Made-up names and data; the real Claude Code is never run.
@MainActor
final class NFCheckerTests: XCTestCase {
    typealias FakeSeam = ConnectionsTests.FakeSeam

    private var suite = ""
    private var defaults: UserDefaults!
    private var root: URL!
    private var saved: (calls: URL, actions: URL)!

    override func setUp() async throws {
        suite = "PhewTests.nfChecker.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.set(true, forKey: Hand.allowedKey)
        root = FileManager.default.temporaryDirectory.appending(path: "NFCheckerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        saved = (CallLog.url, ActionLog.url)
        CallLog.url = root.appending(path: "calls.log")
        ActionLog.url = root.appending(path: "actions.log")
    }

    override func tearDown() async throws {
        ActionLog.flush()
        (CallLog.url, ActionLog.url) = saved
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: root)
    }

    private func call(_ server: String, _ tool: String, door: ConnectorDoor = .claudeAccount) -> ConnectorCall {
        ConnectorCall(server: server, name: ClaudeCodeDoor.gate(server).name, tool: tool, arguments: Data("{}".utf8), door: door)
    }

    // MARK: NF.5 money

    static let brokerNames = ["eToro", "claude.ai eToro", "claude_ai_eToro", "Interactive Brokers (IBKR)", "claude.ai Interactive Brokers (IBKR)",
                              "claude_ai_Interactive_Brokers_IBKR", "plugin:x:stripe", "claude.ai PayPal", "ETORO", "my eToro account"]
    static let etoroTools = ["place-trade", "place-close", "prepare-trade", "prepare-close", "execute-write", "execute-read", "placeorder",
                             "createTradeV2", "sell_position", "wire", "send_money", "close_position", "cancel_order", "ÉxecuteWrite"]

    func testEveryToolOfABrokerIsMoney() {
        for server in Self.brokerNames {
            XCTAssertTrue(Connections.broker(server), server)
            for tool in Self.etoroTools {
                XCTAssertTrue(Connections.money(call(server, tool)), "\(server) \(tool)")
                XCTAssertTrue(Connections.money(call(server, tool, door: .own)), "own \(server) \(tool)")
            }
        }
    }

    func testMoneyWordsInAnyNameAreMoneyOnAnyServer() {
        for tool in ["placeorder", "PlaceOrder", "createTradeV2", "sell_position", "send_money", "wire", "wire_transfer", "cancel_order",
                     "buyShares", "make-payment", "Pay", "pay2", "orders_create", "refundCharge", "withdrawFunds", "executeTrade"] {
            XCTAssertTrue(Connections.money(call("claude.ai Made-up", tool)), tool)
        }
        XCTAssertFalse(Connections.money(call("claude.ai Notion", "notion-create-pages")))
        XCTAssertFalse(Connections.money(call("claude.ai Spotify", "play")))
    }

    func testAMoneyWriteIsNeverRunByAWatchedJobAndNothingMarksItConfirmedButTheMenu() {
        let seam = FakeSeam()
        let hand = Hand(defaults: defaults, surface: FakeSurface(), list: NeverReadList(defaults: defaults), connector: seam)
        for tool in ["place-trade", "place-close", "prepare-trade", "prepare-close", "execute-write", "placeorder", "send_money"] {
            for door in [ConnectorDoor.own, .claudeAccount] {
                let money = call("claude.ai eToro", tool, door: door)
                let step = HandStep(kind: .connector, pid: 0, name: money.name, connector: money)
                let end = hand.act(step, in: hand.begin(watchUser: false)).end
                XCTAssertTrue(end == .needsConfirm || end == .paying, "\(tool) \(end)")  // paying: refused outright, safer
                XCTAssertNotEqual(hand.act(step, in: hand.begin(watchUser: false, agent: true)).end, .done, "agent \(tool)")
                // an agent's job never counts as confirmed, even if asked
                XCTAssertNotEqual(hand.act(step, in: hand.begin(watchUser: false, agent: true, confirmed: true)).end, .done, "agent confirmed \(tool)")
            }
        }
        XCTAssertEqual(seam.sent, [])
        // Only a job begun as confirmed runs it (TaskList's Confirm), once.
        let trade = call("claude.ai eToro", "place-trade")
        let ran = hand.act(HandStep(kind: .connector, pid: 0, name: trade.name, connector: trade), in: hand.begin(watchUser: false, confirmed: true))
        XCTAssertEqual(ran.end, .done)
        XCTAssertEqual(seam.sent, [trade])
        let etoro = ClaudeCodeDoor.gate("claude.ai eToro")
        for tool in ["place-trade", "place-close", "prepare-trade", "prepare-close", "execute-write", "execute-read"] {
            XCTAssertEqual(Connections.access(ConnectorTool(name: tool), on: etoro), .write, tool)
        }
        let ibkr = ClaudeCodeDoor.gate("claude.ai Interactive Brokers (IBKR)")
        for tool in ["create_order_instruction", "delete_order_instruction", "update_alert", "create_alert", "edit_watchlist"] {
            XCTAssertEqual(Connections.access(ConnectorTool(name: tool), on: ibkr), .write, tool)
        }
    }

    // MARK: NF.1 naming

    func testWordsInsideOtherWordsNameNothing() {
        XCTAssertFalse(Connections.names("who is the driver otherwise", connector: "claude.ai Google Drive"))
        XCTAssertFalse(Connections.names("otherwise the squared numbers", connector: "claude.ai Wise"))
        XCTAssertFalse(Connections.names("a squarely built plan", connector: "claude.ai Square"))
        XCTAssertFalse(Connections.names("the rampant plan", connector: "claude.ai Ramp"))
        XCTAssertFalse(Connections.names("notional value", connector: "claude.ai Notion"))
    }

    private func door(_ servers: [ClaudeServer], ticked: [String]) -> ClaudeCodeDoor {
        let door = ClaudeCodeDoor(program: root.appending(path: "never-run/claude"), defaults: defaults)
        door.set(on: true)
        defaults.removeObject(forKey: ClaudeCodeDoor.tickedKey)
        defaults.set(try? JSONEncoder().encode(servers), forKey: ClaudeCodeDoor.listedKey)
        for name in ticked { door.tick(name, true) }
        return door
    }

    func testNamingAnUntickedOrEmptyOrChangedServerAllowsNothingOfItAndRefusesTheRest() {
        let mail = ClaudeServer(name: "claude.ai Gmail", tools: ["get_thread", "create_draft"])
        let music = ClaudeServer(name: "claude.ai Spotify", tools: ["play", "search"])
        let bare = ClaudeServer(name: "claude.ai Notion", tools: [])
        let plugin = ClaudeServer(name: "plugin:madeup:spotify", tools: ["play"])
        let door = door([mail, music, bare, plugin], ticked: [mail.name, music.name, bare.name, plugin.name])
        let plan = door.plan(for: "play jazz on Spotify")
        XCTAssertEqual(Set(plan.allowed.keys), ["mcp__claude_ai_Spotify__play", "mcp__claude_ai_Spotify__search"])
        XCTAssertTrue(plan.refused.contains("mcp__claude_ai_Gmail") && plan.refused.contains("mcp__claude_ai_Notion"))
        XCTAssertTrue(plan.refused.contains("mcp__plugin_madeup_spotify"), "a plugin server is refused even if its name matches")
        let notion = door.plan(for: "search my Notion")
        XCTAssertFalse(notion.allowed.keys.contains { $0.hasPrefix("mcp__claude_ai_Notion") })
        // Every tool of every listed server is allowed or refused, never left out.
        let all = plan
        for server in [mail, music, bare, plugin] {
            for tool in server.tools {
                let full = server.prefix + tool
                XCTAssertTrue(all.allowed[full] != nil || all.refused.contains(full) || all.refused.contains("mcp__" + ClaudeCodeDoor.norm(server.name)), full)
            }
        }
        // Unticked and named: not allowed.
        let some = self.door([mail, music], ticked: [mail.name])
        let unticked = some.plan(for: "play jazz on Spotify")
        XCTAssertTrue(Set(unticked.allowed.keys).isDisjoint(with: ["mcp__claude_ai_Spotify__play", "mcp__claude_ai_Spotify__search"]))
        XCTAssertTrue(unticked.refused.contains("mcp__claude_ai_Spotify"))
        // Changed after ticking, and named: nothing allowed anywhere.
        let both = self.door([mail, music], ticked: [mail.name, music.name])
        defaults.set(try? JSONEncoder().encode([mail, ClaudeServer(name: music.name, tools: ["play", "search", "delete_playlist"])]), forKey: ClaudeCodeDoor.listedKey)
        let changed = both.plan(for: "play jazz on Spotify")
        XCTAssertTrue(changed.allowed.isEmpty, "\(changed.allowed.keys)")
    }

    // MARK: NF.2 names

    func testNoNameOfAnUntickedConnectorReachesTheAgents() {
        let mail = ClaudeServer(name: "claude.ai Gmail", tools: ["get_thread"])
        let secret = ClaudeServer(name: "claude.ai Quartzbank", tools: ["get_thing"])
        let door = door([mail, secret], ticked: [mail.name])
        XCTAssertEqual(door.ticked(), ["Gmail"])
        let packet = ContextPacket(appName: "A", bundleID: "b", windowTitle: "w", visibleText: "", cursor: nil)
        let request = Doer.request("Do it", packet: packet, shot: nil, done: [], connectors: door.ticked())
        XCTAssertFalse(request.text.contains("Quartzbank") || (request.cached ?? "").contains("Quartzbank"))
        door.set(on: false)
        XCTAssertEqual(door.ticked(), [], "switch off: no names")
        XCTAssertEqual(Runner.connected(door.ticked()), "")
    }

    // MARK: NF.3 listing ends in time

    func testListingWithAProgramThatNeverAnswersEndsInItsTimeLimit() async throws {
        let folder = root.appending(path: "program")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: "claude")
        try "#!/bin/sh\nsleep 30\n".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        let door = ClaudeCodeDoor(program: url, defaults: defaults)
        door.set(on: true)
        door.listSeconds = 1
        let started = Date()
        let line = await door.list()
        XCTAssertLessThan(Date().timeIntervalSince(started), 6)
        XCTAssertEqual(line, ClaudeCodeDoor.line(.timeout))
    }

    // MARK: NF.4, NF.6

    func testNoPathTicksAServerWithNoToolsAndNoEndingNamesTheRequest() async throws {
        let bare = ClaudeServer(name: "claude.ai Gmail", tools: [])
        let door = door([bare], ticked: [])
        door.tick(bare.name, true)
        XCTAssertTrue(door.accept(bare.name))
        XCTAssertEqual(door.status().first?.connected, false)
        XCTAssertEqual(door.ticked(), [])
        XCTAssertTrue(door.plan(for: "Gmail").allowed.isEmpty)
        let marker = "ZEBRAQUARTZ"
        for words in ["find \(marker) in Gmail", "summarise \(marker)"] {
            let step = await door.step(words, task: 1, ask: nil)
            XCTAssertFalse(step.text.contains(marker), step.text)
        }
        ActionLog.flush()
        for name in ["calls.log", "actions.log"] {
            XCTAssertFalse(((try? String(contentsOf: root.appending(path: name), encoding: .utf8)) ?? "").contains(marker), name)
        }
    }
}
