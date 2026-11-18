import XCTest
@testable import Phew

/// NF.L: Phew's own door code against the real Claude Code program and the user's real connectors. Off unless asked
/// for, at the user's word: `TEST_RUNNER_PHEW_DOOR=1 xcodebuild … test -only-testing:PhewTests/DoorLiveTests`.
/// It uses the user's Claude plan, writes one page named "Phew live check" in Notion, and prints only how each step
/// ended, counts and a short answer about that page: never what a connector returned about anything else.
final class DoorLiveTests: XCTestCase {
    func testListReadAndWriteThroughTheRealProgram() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["PHEW_DOOR"] == "1", "live: the real Claude Code, at the user's word")
        let suite = "phew-door-live-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let log = CallLog.url
        CallLog.url = FileManager.default.temporaryDirectory.appending(path: "\(suite).log")
        defer { CallLog.url = log; defaults.removePersistentDomain(forName: suite) }

        let door = ClaudeCodeDoor(defaults: defaults)
        XCTAssertNotNil(door.program, "Claude Code not found")
        door.set(on: true)

        var started = Date()
        let line = await door.list()
        let listed = door.listed()
        func tools(_ name: String) -> Int { listed.first { $0.name == name }?.tools.count ?? -1 }
        print("NFL list: line=\(line ?? "nil") servers=\(listed.count) notion=\(tools("claude.ai Notion")) gmail=\(tools("claude.ai Gmail")) seconds=\(Int(Date().timeIntervalSince(started)))")
        XCTAssertNil(line)
        door.tick("claude.ai Notion", true)
        door.tick("claude.ai Gmail", true)

        // The write, as in a job the user watches: through `Hand.act`, with its own permit.
        let hand = Hand(defaults: defaults, surface: FakeSurface(), list: NeverReadList(defaults: defaults),
                        connector: ConnectorDoors(own: nil, claudeCode: door))
        let acted = LockedBox<[String]>([])
        started = Date()
        let write = await door.step("In Notion, create one new private page titled \"Phew live check\" whose only text is: made-up test line.",
                                    task: 1, ask: { call in
            let job = await hand.begin(watchUser: false)
            let word = await Task.detached { hand.act(HandStep(kind: .connector, pid: 0, name: call.name, connector: call), in: job).end.rawValue }.value
            acted.update { $0.append("\(call.tool)=\(word)") }
            return word
        })
        print("NFL write: end=\(write.end.rawValue) hand=\(acted.value) seconds=\(Int(Date().timeIntervalSince(started)))")

        started = Date()
        let read = await door.step("Search Notion for a page titled \"Phew live check\". Answer with one word only: found or missing.", task: 2, ask: nil)
        print("NFL read: end=\(read.end.rawValue) answer=\(read.text.prefix(80)) seconds=\(Int(Date().timeIntervalSince(started)))")

        started = Date()
        let mail = await door.step("In Gmail, count my labels. Answer with the number only, nothing else.", task: 3, ask: nil)
        print("NFL gmail: end=\(mail.end.rawValue) characters=\(mail.text.count) seconds=\(Int(Date().timeIntervalSince(started)))")

        XCTAssertEqual(write.end, .done)
        XCTAssertEqual(read.end, .done)
        XCTAssertEqual(mail.end, .done)
    }
}
