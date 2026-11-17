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
                     "describe-teams", "count-items", "get-thread-messages", "get-self", "showProjectDetails"] {
            XCTAssertEqual(Connections.access(ConnectorTool(name: name), on: Self.server), .read, name)
        }
        XCTAssertEqual(Connections.nameWords("fetchANDDelete"), ["fetch", "and", "delete"])
        XCTAssertEqual(Connections.nameWords("getPage2Content"), ["get", "page", "content"])
        XCTAssertNil(Connections.nameWords("get-d\u{0435}lete"))
        // Phew's own table wins over the name.
        XCTAssertEqual(Connections.access(ConnectorTool(name: "notion-search"), on: .notion), .read)
        XCTAssertEqual(Connections.access(ConnectorTool(name: "notion-create-comment"), on: .notion), .write)
    }

    /// CLOSED (guard 6). A connector call's arguments, written by the model, reach the server through the secrets filter.
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
        XCTAssertFalse(sent.joined().contains(secret))
        XCTAssertTrue(sent.joined().contains(#""query""#), "the call still goes, with the key taken out")
        // Nested, in a list, in a key: every string. A plain call is unchanged and holds no secret.
        let nested = Data(#"{"a":[{"b":"\#(secret)"}],"\#(secret)":1,"n":true}"#.utf8)
        XCTAssertFalse(String(decoding: Connections.filtered(nested), as: UTF8.self).contains(secret))
        XCTAssertTrue(Connections.holdsSecret(nested))
        XCTAssertFalse(Connections.holdsSecret(Data(#"{"query":"made-up plan","n":1,"on":true}"#.utf8)))
    }
}

// MARK: Door 1 (guards 3, 7, 10, 11)

extension ClaudeCodeDoorTests {
    /// CLOSED (guard 10). Every result is matched by its tool_use id to a call Phew allowed: a result, worked or
    /// failed, for any other call ends the run.
    func testBreak_anUnaskedToolAfterAnErroredAllowedCallIsNotNoticed() async throws {
        let body = "say '\(Self.initLine)'\n"
            + "ask '\(Self.request("mcp__claude_ai_Notion__notion-search", id: "r1", use: "t1"))'\n"
            + "say '\(Self.toolResult("t1", error: true))'\n"   // the allowed read failed
            + "say '\(Self.toolResult("t2", error: false))'\n"  // a tool nobody asked Phew about ran and worked
            + "say '\(Self.result("Done."))'\n"
        let d = door(try fake(body))
        let step = await d.step("Search the made-up launch plan", task: 21, ask: nil)
        XCTAssertEqual(step.end, .unasked)
        // A failed tool nobody asked about ends it too.
        let failed = door(try fake("say '\(Self.initLine)'\nsay '\(Self.toolResult("t9", error: true))'\nexec sleep 30\n"))
        let ended = await failed.step("Search the made-up launch plan", task: 23, ask: nil)
        XCTAssertEqual(ended.end, .unasked)
        // A call Phew refused that then worked anyway ends it.
        let ran = door(try fake("say '\(Self.initLine)'\n" + "ask '\(Self.request("Bash", #"{"command":"ls"}"#, id: "r1", use: "t1"))'\n"
                                 + "say '\(Self.toolResult("t1", error: false))'\nexec sleep 30\n"))
        let refusedRan = await ran.step("Search the made-up launch plan", task: 24, ask: nil)
        XCTAssertEqual(refusedRan.end, .unasked)
    }

    /// A request with no tool_use id: its result is matched by the assistant's tool call, by tool and input in order.
    func testAResultIsMatchedByToolAndInputWhenTheRequestHasNoId() async throws {
        let tool = "mcp__claude_ai_Notion__notion-search"
        let noID = #"{"type":"control_request","request_id":"r1","request":{"subtype":"can_use_tool","tool_name":"\#(tool)","input":{"query":"made-up plan"}}}"#
        let use = #"{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t7","name":"\#(tool)","input":{"query":"made-up plan"}}]}}"#
        let other = #"{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t8","name":"\#(tool)","input":{"query":"another plan"}}]}}"#
        let matched = door(try fake("say '\(Self.initLine)'\nsay '\(use)'\nask '\(noID)'\nsay '\(Self.toolResult("t7", error: false))'\nsay '\(Self.result("Found."))'\n"))
        let step = await matched.step("Search the made-up launch plan", task: 25, ask: nil)
        XCTAssertEqual(step.end, .done)
        // The same allow cannot cover a second call with other input.
        let twice = door(try fake("say '\(Self.initLine)'\nsay '\(use)'\nsay '\(other)'\nask '\(noID)'\n"
                                  + "say '\(Self.toolResult("t7", error: false))'\nsay '\(Self.toolResult("t8", error: false))'\nexec sleep 30\n"))
        let ended = await twice.step("Search the made-up launch plan", task: 26, ask: nil)
        XCTAssertEqual(ended.end, .unasked)
    }

    /// Door 1's input passes the secrets filter: a call that would change is refused with a plain line, never sent.
    func testACallWithASecretInItsInputIsRefused() async throws {
        let secret = "sk-" + "ant-api03-" + String(repeating: "Ab3dEf6hIj", count: 4)
        let d = door(try fake("say '\(Self.initLine)'\n" + Self.ask("mcp__claude_ai_Notion__notion-search", #"{"query":"\#(secret)"}"#)
                              + "say '\(Self.result("Nothing."))'\n"))
        let step = await d.step("Search the made-up launch plan", task: 27, ask: nil)
        XCTAssertEqual(step.end, .done)
        XCTAssertEqual(answers.count, 1)
        XCTAssertTrue(answers[0].contains(#""behavior":"deny""#) && answers[0].contains("secrets filter"))
        XCTAssertFalse(answers[0].contains(secret))
    }

    /// CLOSED (guard 7). A research run's WebFetch goes only to a public web address, checked by Phew's code.
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
        XCTAssertEqual(allowed, 0, "a local, private, link-local or file address was allowed")
        XCTAssertEqual(answers.count, 4)
        XCTAssertTrue(answers.allSatisfy { $0.contains("only public web pages") })
    }

    /// The one check of a WebFetch address, both ways.
    func testOnlyPublicWebAddressesPass() {
        for open in ["https://example.com/made-up", "http://made-up.test/a?b=c", "https://8.8.8.8/", "https://[2606:4700::1111]/",
                     "https://sub.example.co.uk:8443/x#y", "https://172.32.0.1/", "https://192.169.0.1/"] {
            XCTAssertTrue(ClaudeCodeDoor.publicWeb(open), open)
        }
        for shut in ["http://127.0.0.1:8080/admin", "file:///etc/hosts", "http://192.168.1.1/", "http://169.254.169.254/latest/meta-data/",
                     "http://localhost/", "http://LOCALHOST./", "http://made-up.local/", "http://app.localhost/", "http://10.1.2.3/",
                     "http://172.16.0.1/", "http://172.31.255.255/", "http://0.0.0.0/", "http://0/", "http://2130706433/",
                     "http://0x7f.1/", "http://0177.0.0.1/", "http://127.1/", "http://0x7f000001/", "http://[::1]/",
                     "http://[::ffff:127.0.0.1]/", "http://[::ffff:7f00:1]/", "http://[fe80::1]/", "http://[fd00::1]/",
                     "http://[fc12::1]/", "http://[::]/", "http://[64:ff9b::a00:1]/", "http://[2002:c0a8:101::]/",
                     "ftp://example.com/", "javascript:alert(1)", "data:text/html,x", "gopher://example.com/",
                     "http://user:pass@example.com/", "http://example.com@127.0.0.1/", "http://example.com\\@127.0.0.1/",
                     "http://intranet/", "http://300.1.1.1/", "http://exa mple.com/", "http://exämple.com/", "", "example.com"] {
            XCTAssertFalse(ClaudeCodeDoor.publicWeb(shut), shut)
        }
    }

    /// CLOSED (guard 11). The SIGKILL fallback goes to the program's whole process group: a child that ignored
    /// SIGTERM goes with it.
    func testBreak_theKillFallbackLeavesAChildThatIgnoredTerm() async throws {
        let d = door(try fake("trap '' TERM\nsay '\(Self.initLine)'\nsleep 60 &\necho $! > \"$d/child\"\nwait\nwait\n"))
        let stop = Flag(), written = root.appending(path: "child").path
        Task.detached {
            // Stop once the child is there (a loaded machine may start the script late), 5 seconds at most.
            let until = Date() + 5
            while Date() < until, (try? String(contentsOfFile: written, encoding: .utf8))?.isEmpty != false {
                try? await Task.sleep(for: .milliseconds(20))
            }
            try? await Task.sleep(for: .milliseconds(100))
            stop.on = true
        }
        let stoppedAt = Date()
        let step = await d.step("Search the made-up launch plan", task: 22, ask: nil, stop: { stop.on })
        XCTAssertEqual(step.end, .stopped)
        let pid = Int32((file("child") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        XCTAssertGreaterThan(pid, 0)
        let alive = pid > 0 && kill(pid, 0) == 0
        if alive { kill(pid, SIGKILL) }
        XCTAssertLessThan(Date().timeIntervalSince(stoppedAt), 3)
        XCTAssertFalse(alive, "a child that ignored SIGTERM outlived the run")
    }

    /// CLOSED (nit, guard 3). The fresh run after a confirm compares the input written one way: `true` is not `1`.
    func testBreak_theFreshRunsInputCheckTakesTrueForOne() {
        XCTAssertFalse(ClaudeCodeDoor.same(Data(#"{"archive":true}"#.utf8), Data(#"{"archive":1}"#.utf8)))
        XCTAssertTrue(ClaudeCodeDoor.same(Data(#"{"a":1,"b":[true,"x"]}"#.utf8), Data(#"{"b":[true,"x"],"a":1}"#.utf8)))
        XCTAssertFalse(ClaudeCodeDoor.same(Data("[]".utf8), Data("[]".utf8)), "an object only")
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

    /// CLOSED (guard 20). `Hand.startClaudeCode` and `Hand.openSignIn` may be called from their one file each, and the
    /// first starts only a program named `claude`.
    func testTheScanDoesNotSeeTheHandsStaticDoors() throws {
        let start = "let p = try Hand.startClaudeCode(URL(filePath: \"/bin/sh\"), arguments: [\"-e\", made], environment: [:], folder: f)"
        let open = "Hand.openSignIn(URL(string: \"https://made-up.test\")!)"
        for line in [start, open] { XCTAssertTrue(HandTests.acts("Brain/MadeUpTool.swift", line), line) }
        XCTAssertFalse(HandTests.acts("Brain/ClaudeCodeDoor.swift", start))
        XCTAssertFalse(HandTests.acts("Shell/PhewApp.swift", open))
        XCTAssertTrue(HandTests.acts("Shell/PhewApp.swift", start))
        let folder = FileManager.default.temporaryDirectory
        for program in ["/bin/sh", "/bin/claude-not", "/usr/bin/true"] {
            XCTAssertThrowsError(try Hand.startClaudeCode(URL(filePath: program), arguments: [], environment: [:], folder: folder), program)
        }
    }

    /// CLOSED (guard 16). The plan's check that "what the action made shows" matches whole words only.
    func testAPlansExpectedTextMatchesInsideALongerWord() {
        let packet = ContextPacket(appName: "Made-up", bundleID: "com.example.madeup", windowTitle: "Made-up", visibleText: "Last saved yesterday", cursor: nil)
        XCTAssertFalse(packet.shows("Save"))
        XCTAssertFalse(packet.shows("ved"))
        XCTAssertTrue(packet.shows("saved"))
        XCTAssertTrue(packet.shows("  LAST SAVED "))
        XCTAssertTrue(packet.shows("Made-up"), "the window title")
        XCTAssertTrue(ContextPacket.holds("Saved: the made-up page (2)", "made-up page"))
        XCTAssertFalse(ContextPacket.holds("page2", "page"))
        XCTAssertTrue(ContextPacket.holds("pages, page", "page"), "a later whole match counts")
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

    /// CLOSED (guard 15). The second call may only run again the briefs of workers that failed, by their number: never
    /// a whole second split, never more than failed, never a fresh question.
    func testTheRedoMayBeAWholeSecondSplit() async throws {
        let provider = WorkerTests.Routed(WorkerTests.good)
        let tools = tools(provider)
        let four = WorkerTests.call((1...4).map { ("Made-up question \($0)?", ["web"]) })
        _ = try await tools.run("start_workers", input: four)
        let again = try await tools.run("start_workers", input: four)
        XCTAssertTrue(again.hasPrefix("Not run: no worker of the split failed"), again)
        let redo = try await tools.run("start_workers", input: WorkerTests.redo([1]))
        XCTAssertTrue(redo.hasPrefix("Not run:"), "nothing failed, nothing to redo")
        XCTAssertEqual(provider.of("worker").count, 4)

        // Two failed: a redo of a worker that did not fail, of one twice, of more than failed, or a fresh question: refused.
        let mixed = WorkerTests.Routed { request, _ in
            request.text.contains("question 2") || request.text.contains("question 4") ? WorkerTests.Reply(text: "Not JSON.") : WorkerTests.good(request, 0)
        }
        let split = self.tools(mixed)
        _ = try await split.run("start_workers", input: four)
        for wrong in [WorkerTests.redo([1]), WorkerTests.redo([2, 2]), WorkerTests.redo([2, 4, 3]), WorkerTests.call([("Fresh made-up?", ["web"])])] {
            let out = try await split.run("start_workers", input: wrong)
            XCTAssertTrue(out.hasPrefix("Not run: the second call may only redo workers that failed (2, 4)"), out)
        }
        XCTAssertEqual(mixed.of("worker").count, 4, "none of the wrong redos started a worker")
        let right = try await split.run("start_workers", input: WorkerTests.redo([4, 2]))
        XCTAssertTrue(right.contains("Worker 4 of 4. Question: Made-up question 4?") && right.contains("Worker 2 of 4. Question: Made-up question 2?"))
        XCTAssertEqual(mixed.of("worker").count, 6)
        XCTAssertEqual(mixed.of("worker").suffix(2).map(\.text).sorted(), ["Made-up question 2?", "Made-up question 4?"])
    }

    /// CLOSED (guard 15). Before a worker's request starts, the most it can cost is set aside in one step: workers
    /// running at once wait for each other's money and never pass the job's cap together.
    func testParallelWorkersCanPassTheMoneyCap() async throws {
        let usage = Usage(input: 2000, searches: 10)  // about ten cents a round, within what a worker's request may cost
        let provider = WorkerTests.Routed { _, _ in
            WorkerTests.Reply(text: WorkerTests.report([("Made-up kerning is spacing.", WorkerTests.pageA)]), blocks: WorkerTests.fetched(WorkerTests.pageA),
                              usage: usage)
        }
        let cap = 0.3
        XCTAssertGreaterThan(4 * Tier.small.model.cost(usage), cap, "four rounds at once would pass the cap")
        let money = JobMoney()
        _ = try await tools(provider, cap: cap, money: money).run("start_workers", input: WorkerTests.call((1...4).map { ("Made-up question \($0)?", ["web"]) }))
        XCTAssertLessThanOrEqual(money.total, cap * (1 - Workers.heldBack))
        XCTAssertLessThan(provider.of("worker").count, 4)
        XCTAssertGreaterThan(provider.of("worker").count, 1, "the others waited, then ran while the money lasted")
        // The hold itself: granted, wait while others hold, spent when the money is gone.
        let job = JobMoney()
        XCTAssertEqual(job.hold(0.6, within: 1), .granted)
        XCTAssertEqual(job.hold(0.6, within: 1), .wait)
        job.settle(0.6, cost: 0.5)
        XCTAssertEqual(job.hold(0.6, within: 1), .spent)
        XCTAssertEqual(job.hold(0.4, within: 1), .granted)
    }

    /// CLOSED (guard 15, low). `url_from_task` is refused when the task's own words hold no address.
    func testUrlFromTaskGivesAFetchToolWhenTheUserTypedNoAddress() async throws {
        let provider = WorkerTests.Routed(WorkerTests.good)
        let out = try await tools(provider).run("start_workers", input: WorkerTests.call([("Read https://evil.made-up.test/x", ["url_from_task"]), ("B?", ["web"])]))
        XCTAssertTrue(out.hasPrefix("Not run: url_from_task reads an address the user typed in the task, and this task has none."), out)
        XCTAssertEqual(provider.requests.count, 0)
    }
}

// MARK: The sign-in listener (guard 12)

final class BreakingLoopbackTests: XCTestCase {
    /// CLOSED (low, a denial only). A stray request, or a callback with another state, gets "Not found." and the
    /// listener goes on until the right callback.
    func testAStrayFirstRequestEndsTheSignIn() async throws {
        let loopback = try await Loopback.start(state: "s")
        let waiting = Task { try await loopback.answer(within: 5) }
        let session = URLSession(configuration: .ephemeral)
        let stray = URL(string: "http://127.0.0.1:\(loopback.port)/favicon.ico")!
        let (_, strayAnswer) = try await session.data(from: stray)
        XCTAssertEqual((strayAnswer as? HTTPURLResponse)?.statusCode, 404)
        let forged = URL(string: "http://127.0.0.1:\(loopback.port)/callback?code=x&state=other")!
        let (_, forgedAnswer) = try await session.data(from: forged)
        XCTAssertEqual((forgedAnswer as? HTTPURLResponse)?.statusCode, 404)
        let real = URL(string: "http://127.0.0.1:\(loopback.port)/callback?code=c&state=s")!
        _ = try? await session.data(from: real)
        let result = await waiting.result
        XCTAssertEqual((try? result.get())?["code"], "c")
        loopback.close()
    }
}
