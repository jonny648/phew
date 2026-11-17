import XCTest
@testable import Phew

/// A breaking pass over NB and N4 (17 November). Each test below tries to get past one guard, with made-up data only.
/// A test that wraps its assertion in `XCTExpectFailure` shows a hole that is OPEN today: the suite stays green, and
/// the day the hole is closed the test fails with "failure expected" and must be turned into a plain assertion.
/// No live model, no real `claude`, no real service.

// MARK: The gate's name rule (guards 1 and 2)

final class BreakingGateTests: XCTestCase {
    static let server = ConnectorServer(id: "madeup", name: "Made-up", url: URL(string: "https://mcp.made-up.test/mcp")!)

    /// Guards that held.
    func testNamesWithAWriteWordAreWritesWhateverTheCaseOrSeparator() {
        for name in ["get-or-create-page", "fetch_and_delete", "search-replace", "list-and-archive", "getOrCreatePage", "GET_OR_CREATE",
                     "madeup-get-and-update", "SEARCH-AND-REPLACE", "unknown-tool", ""] {
            XCTAssertEqual(Connections.access(ConnectorTool(name: name), on: Self.server), .write, name)
        }
        // A server's mark can only make a tool stricter.
        XCTAssertEqual(Connections.access(ConnectorTool(name: "delete-all", readOnly: true), on: Self.server), .write)
        XCTAssertEqual(Connections.access(ConnectorTool(name: "get-page", readOnly: false), on: Self.server), .write)
        XCTAssertEqual(Connections.access(ConnectorTool(name: "get-page", destructive: true), on: Self.server), .write)
        XCTAssertEqual(Connections.access(ConnectorTool(name: "get-page", readOnly: true), on: Self.server), .read)
    }

    /// CLOSED (guard 2). The name rule is an allow-list: every word must be a read verb or a harmless word, so a write
    /// word Phew does not know, one hidden by an all-capitals run, or a look-alike letter makes the tool a write.
    func testAReadWordInFrontLetsAWriteWordThroughThatTheListLacks() {
        let names = ["fetchANDDelete", "get-and-trigger-build", "list-and-purge", "fetch-then-clear-cache", "search-and-merge",
                     "read-and-save", "find-and-append", "view-and-approve", "get_and_execute", "get-and-sync", "query-and-drop",
                     "fetch-and-deletes", "list-and-trash", "get-d\u{0435}lete" /* Cyrillic e */, "get_access_to_vercel_url",
                     "getPageAndPublish", "list-pages2-purge", "GETPAGESANDDELETE", "pages", "comments", "get-comment", "get\u{2013}page"]
        let misclassed = names.filter { Connections.access(ConnectorTool(name: $0), on: Self.server) == .read }
        XCTAssertEqual(misclassed, [])
    }

    /// Plain reads still read, by the name alone and after the server's prefix.
    func testPlainReadNamesStillRead() {
        for name in ["get-page", "search-pages", "list-recent-files", "getPageContent", "get_file_metadata", "list_calendars",
                     "fetch", "SEARCH", "madeup-query-database", "find-users-by-id", "list-events-in-calendar", "lookup",
                     "describe-teams", "count-items", "get-thread-messages", "get-self", "check-status", "showProjectDetails"] {
            XCTAssertEqual(Connections.access(ConnectorTool(name: name), on: Self.server), .read, name)
        }
        XCTAssertEqual(Connections.nameWords("fetchANDDelete"), ["fetch", "and", "delete"])
        XCTAssertEqual(Connections.nameWords("getPage2Content"), ["get", "page", "content"])
        XCTAssertNil(Connections.nameWords("get-d\u{0435}lete"))
        // Phew's own table wins over the name.
        XCTAssertEqual(Connections.access(ConnectorTool(name: "notion-search"), on: .notion), .read)
        XCTAssertEqual(Connections.access(ConnectorTool(name: "notion-create-comment"), on: .notion), .write)
    }

    /// OPEN (guard 6). A connector call's arguments, written by the model, reach the server with no secrets filter.
    func testConnectorArgumentsAreNotFilteredBeforeTheyLeave() async throws {
        final class Recording: ConnectorTransport, @unchecked Sendable {
            private let lock = NSLock()
            private var seen: [Data] = []
            var arguments: [Data] { lock.withLock { seen } }
            func tools() async throws -> [ConnectorTool] { [ConnectorTool(name: "made-search")] }
            func call(_ permit: ConnectorPermit, arguments: Data) async throws -> ConnectorAnswer {
                lock.withLock { seen.append(arguments) }
                return ConnectorAnswer(text: "ok")
            }
        }
        var server = Self.server
        server.reads = ["made-search"]
        let door = Recording()
        let defaults = UserDefaults(suiteName: "PhewTests.breaking.\(UUID().uuidString)")!
        let connections = Connections(servers: [server], defaults: defaults, make: { _ in door })
        let tools = ConnectorTools(connections: connections, offered: [(server, ConnectorTool(name: "made-search"))], ask: nil)
        let secret = "sk-" + "ant-api03-" + String(repeating: "Ab3dEf6hIj", count: 4)
        _ = try await tools.run("madeup__made-search", input: Data(#"{"query":"\#(secret)"}"#.utf8))
        let sent = door.arguments.map { String(decoding: $0, as: UTF8.self) }
        XCTAssertEqual(sent.count, 1)
        XCTExpectFailure("the answer is filtered, the arguments are not (Connections.read, ConnectorTools.run)") {
            XCTAssertFalse(sent.joined().contains(secret))
        }
    }
}

// MARK: Door 1 (guards 3, 7, 10, 11)

extension ClaudeCodeDoorTests {
    /// OPEN (guard 10). The "ran without asking Phew" net counts only SUCCESSFUL results against Phew's allows: an
    /// allowed call that fails pays for one tool that Claude Code ran by the user's own settings, with no ask.
    func testBreak_anUnaskedToolAfterAnErroredAllowedCallIsNotNoticed() async throws {
        let body = "say '\(Self.initLine)'\n"
            + "ask '\(Self.request("mcp__claude_ai_Notion__notion-search", id: "r1", use: "t1"))'\n"
            + "say '\(Self.toolResult("t1", error: true))'\n"   // the allowed read failed
            + "say '\(Self.toolResult("t2", error: false))'\n"  // a tool nobody asked Phew about ran and worked
            + "say '\(Self.result("Done."))'\n"
        let d = door(try fake(body))
        let step = await d.step("Search the made-up launch plan", task: 21, ask: nil)
        XCTExpectFailure("results (1) is not more than allows (1): ClaudeCodeDoor.swift:729-730") {
            XCTAssertEqual(step.end, .unasked)
        }
    }

    /// OPEN (guard 7). A research run lets WebFetch go to ANY address the model names: a local one, a private network
    /// one, a file one. Phew's gate counts the page and says yes; Door 2's server-side fetch cannot reach the Mac.
    func testBreak_researchWebFetchReachesLocalAndPrivateAddresses() async throws {
        let report = #"# Made-up\n\nShort.\n\n## Not checked\n\nNothing."#
        let body = "say '\(Self.initLine)'\n"
            + Self.ask("WebFetch", #"{"url":"http://127.0.0.1:8080/admin"}"#, id: "r1", use: "t1")
            + Self.ask("WebFetch", #"{"url":"file:///etc/hosts"}"#, id: "r2", use: "t2")
            + Self.ask("WebFetch", #"{"url":"http://192.168.1.1/"}"#, id: "r3", use: "t3")
            + Self.ask("WebFetch", #"{"url":"http://169.254.169.254/latest/meta-data/"}"#, id: "r4", use: "t4")
            + "say '\(Self.result(report))'\n"
        let d = door(try fake(body))
        d.set(research: true)
        let reports = FileManager.default.temporaryDirectory.appending(path: "BreakingReports-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: reports, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: reports) }
        for try await _ in d.research("Research the made-up plan", number: 31, folder: reports, connector: nil) {}
        let allowed = answers.filter { $0.contains(#""behavior":"allow""#) }.count
        XCTExpectFailure("ClaudeCodeDoor.swift:441-447 allows every WebFetch that is within the page count") {
            XCTAssertEqual(allowed, 0, "a local, private, link-local or file address was allowed")
        }
    }

    /// LOW (guard 11). SIGTERM reaches the program's whole process group (`Process.terminate`), so a child dies with
    /// it: that held (a first version of this test showed it). The SIGKILL half a second later is aimed at one pid: a
    /// program that ignores SIGTERM (and so does its child) leaves the child behind. A real Claude Code stops its tool
    /// servers when its input closes, which `Run.end` does; this only shows the fallback is not group-wide.
    func testBreak_theKillFallbackLeavesAChildThatIgnoredTerm() async throws {
        let d = door(try fake("trap '' TERM\nsay '\(Self.initLine)'\nsleep 60 &\necho $! > \"$d/child\"\nwait\nwait\n"))
        let stop = Flag()
        Task.detached { try? await Task.sleep(for: .milliseconds(700)); stop.on = true }
        let stoppedAt = Date()
        let step = await d.step("Search the made-up launch plan", task: 22, ask: nil, stop: { stop.on })
        XCTAssertEqual(step.end, .stopped)
        let pid = Int32((file("child") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        XCTAssertGreaterThan(pid, 0)
        let alive = pid > 0 && kill(pid, 0) == 0
        if alive { kill(pid, SIGKILL) }
        XCTAssertLessThan(Date().timeIntervalSince(stoppedAt), 3)
        XCTExpectFailure("Run.end sends SIGKILL to one pid, not its group (ClaudeCodeDoor.swift:632-633)") {
            XCTAssertFalse(alive, "a child that ignored SIGTERM outlived the run")
        }
    }

    /// OPEN (nit, guard 3). The fresh run after a confirm compares the input as Foundation objects: `true` equals `1`.
    func testBreak_theFreshRunsInputCheckTakesTrueForOne() {
        XCTExpectFailure("ClaudeCodeDoor.same uses NSDictionary.isEqual (ClaudeCodeDoor.swift:400-404)") {
            XCTAssertFalse(ClaudeCodeDoor.same(Data(#"{"archive":true}"#.utf8), Data(#"{"archive":1}"#.utf8)))
        }
    }
}

// MARK: The confirm rows and the Hand's other doors (guards 3 and 20)

@MainActor
final class BreakingConfirmTests: XCTestCase {
    /// CLOSED (guard 3). The row the user confirms shows what will be written or sent: the arguments, keys and values,
    /// or the shortcut's input, cut on the row, whole in the row's own menu.
    func testTheConfirmRowDoesNotShowWhatWillBeWrittenOrSent() {
        let write = ConnectorCall(server: "madeup", name: "Made-up", tool: "made-create-pages",
                                  arguments: Data(#"{"title":"EXFIL-MARK-7","parent":{"id":"p1"},"done":true}"#.utf8))
        XCTAssertEqual(TaskList.asks(write), #"Waiting for you: write in Made-up with made-create-pages: done: true; parent: {"id":"p1"}; title: EXFIL-MARK-7?"#)
        XCTAssertNil(TaskList.whole(write), "short: the row shows it all")
        let shortcut = ShortcutCall(name: "Made-up shortcut", input: "EXFIL-INPUT-9")
        XCTAssertEqual(TaskList.asks(shortcut), "Waiting for you: run the shortcut “Made-up shortcut” with “EXFIL-INPUT-9”?")
        XCTAssertEqual(TaskList.asks(ShortcutCall(name: "Made-up shortcut")), "Waiting for you: run the shortcut “Made-up shortcut”?")
        // A long one: cut on the row, whole under it, line by line.
        let body = String(repeating: "made-up words ", count: 20) + "END-MARK"
        let long = ConnectorCall(server: "madeup", name: "Made-up", tool: "made-create-pages",
                                 arguments: try! JSONSerialization.data(withJSONObject: ["body": body]))
        XCTAssertTrue(TaskList.asks(long).hasSuffix("…?"))
        XCTAssertFalse(TaskList.asks(long).contains("END-MARK"))
        let whole = try! XCTUnwrap(TaskList.whole(long))
        XCTAssertEqual(whole.joined(), "body: " + body)
        XCTAssertTrue(whole.allSatisfy { $0.count <= TaskList.rowCap })
        XCTAssertEqual(TaskList.whole(ShortcutCall(name: "s", input: "first\nsecond")), ["first", "second"])
    }

    /// OPEN (guard 20). `Hand.startClaudeCode` starts ANY program with ANY arguments and `Hand.openSignIn` opens the
    /// browser: both are static, take no permit and check nothing, and the scan of `testOnlyHandActs` passes a call to
    /// them from anywhere because they are not on its word lists.
    func testTheScanDoesNotSeeTheHandsStaticDoors() {
        for line in ["let p = try Hand.startClaudeCode(URL(filePath: \"/bin/sh\"), arguments: [\"-e\", made], environment: [:], folder: f)",
                     "Hand.openSignIn(URL(string: \"https://made-up.test\")!)"] {
            XCTAssertFalse(HandTests.acts("Brain/MadeUpTool.swift", line), "the hole: the scan lets this line through")
            XCTExpectFailure("add `Hand.startClaudeCode` and `Hand.openSignIn` to HandTests.surfaces, and make the first take only the claude program") {
                XCTAssertTrue(HandTests.acts("Brain/MadeUpTool.swift", line), line)
            }
        }
    }

    /// OPEN (guard 16). The plan's check that "what the action made shows" is a substring match in the window text:
    /// "Save" is shown by "Last saved yesterday".
    func testAPlansExpectedTextMatchesInsideALongerWord() {
        let packet = ContextPacket(appName: "Made-up", bundleID: "com.example.madeup", windowTitle: "Made-up", visibleText: "Last saved yesterday", cursor: nil)
        XCTExpectFailure("ContextPacket.shows lowercases and calls contains (ContextPacket.swift:97)") {
            XCTAssertFalse(packet.shows("Save"))
        }
    }
}

// MARK: Workers (guard 15)

final class BreakingWorkerTests: XCTestCase {
    private var saved: (copies: URL, calls: URL)!
    private var root: URL!

    override func setUp() {
        root = FileManager.default.temporaryDirectory.appending(path: "BreakingWorkerTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        saved = (Report.copies, CallLog.url)
        Report.copies = root.appending(path: "copies")
        CallLog.url = root.appending(path: "calls.log")
    }

    override func tearDown() {
        (Report.copies, CallLog.url) = saved
        try? FileManager.default.removeItem(at: root)
    }

    private func tools(_ provider: any ModelProvider, cap: Double = 2, money: JobMoney = JobMoney(), words: String = "Compare made-up kerning and leading") -> WorkerTools {
        WorkerTools(provider: provider, number: 41, cap: cap, money: money, map: nil, words: words)
    }

    /// OPEN (guard 15). "One split, plus one redo of failed parts" is kept as "two calls": the second may be four
    /// brand-new briefs when nothing failed, so one job runs eight workers.
    func testTheRedoMayBeAWholeSecondSplit() async throws {
        let provider = WorkerTests.Routed(WorkerTests.good)
        let tools = tools(provider)
        let four = WorkerTests.call((1...4).map { ("Made-up question \($0)?", ["web"]) })
        _ = try await tools.run("start_workers", input: four)
        _ = try await tools.run("start_workers", input: four)
        XCTAssertEqual(provider.of("worker").count, 8)
        XCTExpectFailure("WorkerTools.run counts calls, not failed parts (Workers.swift:364-368)") {
            XCTAssertLessThanOrEqual(provider.of("worker").count, 4)
        }
    }

    /// OPEN (guard 15). The money check runs before a worker's request, and workers run at once: four requests start
    /// together under the budget and every one is paid, so the job passes its cap by up to four rounds.
    func testParallelWorkersCanPassTheMoneyCap() async throws {
        let dollar = Tier.small.model.cost(Usage(input: 1_000_000))
        let tokens = Int(1_000_000 / max(dollar, 0.000_001))  // about one dollar a round
        let provider = WorkerTests.Routed { _, _ in
            WorkerTests.Reply(text: WorkerTests.report([("Made-up kerning is spacing.", WorkerTests.pageA)]), blocks: WorkerTests.fetched(WorkerTests.pageA),
                              usage: Usage(input: tokens))
        }
        let money = JobMoney()
        _ = try await tools(provider, cap: 2, money: money).run("start_workers", input: WorkerTests.call((1...4).map { ("Made-up question \($0)?", ["web"]) }))
        XCTAssertGreaterThan(money.total, 2, "four parallel rounds were paid")
        XCTExpectFailure("Workers.work checks `money.total < budget` once per round, before it knows the round's cost (Workers.swift:84)") {
            XCTAssertLessThanOrEqual(money.total, 2)
        }
    }

    /// OPEN (guard 15, low). `url_from_task` hands the worker the page-reading tool even when the user typed no
    /// address, and the question is the lead's own words: the set is not "an address the user typed".
    func testUrlFromTaskGivesAFetchToolWhenTheUserTypedNoAddress() async throws {
        let provider = WorkerTests.Routed(WorkerTests.good)
        _ = try await tools(provider).run("start_workers", input: WorkerTests.call([("Read https://evil.made-up.test/x", ["url_from_task"]), ("B?", ["web"])]))
        let reader = try XCTUnwrap(provider.of("worker").first { $0.text.hasPrefix("Read https://evil") })
        XCTExpectFailure("Workers.swift:76 gives web_fetch to url_from_task with no typed address") {
            XCTAssertEqual(reader.serverTools, [])
        }
    }
}

// MARK: The sign-in listener (guard 12)

final class BreakingLoopbackTests: XCTestCase {
    /// OPEN (low, a denial only). The listener takes the FIRST request of any path: a stray probe before the browser
    /// ends the sign-in, and the real callback then finds the door closed. No code leaks and no state check is skipped.
    func testAStrayFirstRequestEndsTheSignIn() async throws {
        let loopback = try await Loopback.start()
        let waiting = Task { try await loopback.answer(within: 5) }
        let stray = URL(string: "http://127.0.0.1:\(loopback.port)/favicon.ico")!
        _ = try? await URLSession.shared.data(from: stray)
        let real = URL(string: "http://127.0.0.1:\(loopback.port)/callback?code=c&state=s")!
        _ = try? await URLSession.shared.data(from: real)
        let result = await waiting.result
        XCTExpectFailure("Loopback.take finishes on the first request, even a 404 (OwnClient.swift:282-298)") {
            XCTAssertEqual((try? result.get())?["code"], "c")
        }
        loopback.close()
    }
}
