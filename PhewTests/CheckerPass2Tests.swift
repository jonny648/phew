import XCTest
@testable import Phew

/// Checker, second pass (17 November): names of my own against the read/write rule and the WebFetch gate. Made up.
final class CheckerPass2Tests: XCTestCase {
    private let server = ConnectorServer(id: "madeup", name: "Made-up", url: URL(string: "https://made-up.test/mcp")!)
    private func access(_ n: String) -> ConnectorAccess { Connections.access(ConnectorTool(name: n), on: server) }

    func testWritesThatLookLikeReadsAreWrites() {
        let writes = ["get_or_create_page","fetch_and_delete_items", "list_all_and_purge", "search_replace_content",
                      "read_mark_all", "view_and_approve_item", "find_or_create_user", "get_page_then_archive", "show_hide_item",
                      "query_data_and_export", "lookup_and_merge", "count_items_reset", "status_set", "get_file_share",
                      "get_item_send", "list_events_cancel", "fetch_page_publish", "describe_page_move", "read_item_notify"]
        XCTAssertEqual(writes.filter { access($0) == .read }, [])
    }

    func testPlainReadsRead() {
        let reads = ["get_file_metadata", "list_recent_files", "search_threads", "read_file_content", "get_event", "list_events",
                     "madeup-get-users", "get_page", "search_events", "fetch_page_content"]
        XCTAssertEqual(reads.filter { access($0) == .write }, [])
    }

    /// Everyday reads of the connected services, listed: those classed as writes are the cost of the allow-list.
    func testWhichEverydayReadsNowWrite() {
        let everyday = ["get_message", "list_drafts", "get_draft", "list_labels", "get_spreadsheet", "get_values", "download_file_content",
                        "get_file_permissions", "list_file_revisions", "list_shared_drives", "read_doc", "read_presentation", "get_thread",
                        "search_files", "list_calendars", "suggest_time", "search_contracts", "get_profile", "list_projects", "get_project",
                        "notion-get-users", "notion-get-teams", "notion-list-recent-pages", "notion-get-self", "notion-search", "notion-fetch"]
        let writes = everyday.filter { access($0) == .write }
        // Fail-safe cost of the allow-list: on a server outside Phew's table these ask for a confirm. Not a hole.
        XCTAssertEqual(Set(writes).subtracting(["notion-get-users", "notion-get-teams", "notion-list-recent-pages", "notion-get-self", "notion-search", "notion-fetch"]),
                       ["suggest_time", "search_contracts"])
    }

    func testPublicWebMore() {
        // Known gap, no DNS lookup: a public name that points home passes (nip.io). Said here and in the report only.
        XCTAssertTrue(ClaudeCodeDoor.publicWeb("http://127.0.0.1.nip.io/"))
        for shut in ["http://2130706433/", "http://0x7f.1/", "http://[::ffff:127.0.0.1]/", "https://user@example.com/", "HTTP://LOCALHOST",
                     "http://localhost./", "http://example.com\u{2024}evil/", "http://b\u{fc}cher.example/", "http://[::ffff:10.0.0.1]/",
                     "http://0300.0250.0.1/", "http://169.254.169.254.:80/", "http://[::127.0.0.1]/", "http://%31%32%37.0.0.1/",
                     "http://127.0.0.1%2f@example.com/", "http://metadata.google.internal/", "http://[::ffff:a9fe:a9fe]/"] {
            XCTAssertFalse(ClaudeCodeDoor.publicWeb(shut), shut)
        }
        for open in ["http://xn--bcher-kva.example/", "https://example.com./x"] { XCTAssertTrue(ClaudeCodeDoor.publicWeb(open), open) }
    }
}

/// After the second pass: one loose word closed, everyday reads of mail and files opened.
final class ReadWordTests: XCTestCase {
    func testCheckInWritesAndMailReadsRead() {
        let server = ConnectorServer.notion
        for name in ["check_in_user", "check_out_item", "get_in_touch"] { XCTAssertEqual(Connections.byName(name, server: server), .write, name) }
        for name in ["get_message", "list_drafts", "get_draft", "list_labels", "get_spreadsheet", "download_file_content",
                     "get_file_permissions", "list_file_revisions", "list_shared_drives", "read_presentation", "get_profile"] {
            XCTAssertEqual(Connections.byName(name, server: server), .read, name)
        }
        for name in ["message_user", "comment_page", "draft_message", "label_thread", "get_and_message", "check-status", "get-comment"] { XCTAssertEqual(Connections.byName(name, server: server), .write, name) }
    }
}
