import CryptoKit
import Foundation
import os

// Connections (phase NB, docs/18-capabilities.md 18.1 and 18.4): the tools the user connected, through one gate.
// Door 2 is Phew's own client (`OwnClient`); door 1, Claude Code (NB.9), plugs in as another `ConnectorTransport`.
// The gate is the same for both: Phew's own table says which tools read and which write, a tool it does not know
// writes, reads run freely, a write runs only inside `Hand.act` (it needs a `ConnectorPermit` made there), a tool's
// answer is data and passes the secrets filter, and only the tools that fit the job go to the model.

/// A server on the fixed list. No free "add any server" field.
struct ConnectorServer: Sendable, Equatable, Identifiable {
    /// A fixed word, also the start of the tool names the model sees ("notion__notion-search").
    let id: String
    /// The plain name, for the menu, the card and the report.
    let name: String
    let url: URL
    /// Phew's own table: the tools it knows. Any other tool is judged by its name (`Connections.byName`).
    var reads: Set<String> = []
    var writes: Set<String> = []

    /// Only Notion is tested (NB.1, docs/18-capabilities.md 18.4 T2).
    static let notion = ConnectorServer(
        id: "notion", name: "Notion", url: URL(string: "https://mcp.notion.com/mcp")!,
        reads: ["notion-search", "notion-fetch", "notion-get-comments", "notion-query-data-sources"],
        writes: ["notion-create-pages", "notion-update-page", "notion-create-comment"])

    static let all = [notion]
}

enum ConnectorAccess: String, Sendable { case read, write }

/// One tool as the server listed it. The definition is the server's: data, never instructions.
struct ConnectorTool: Sendable, Equatable {
    var name: String
    var description = ""
    /// The input schema as JSON.
    var schema = #"{"type":"object"}"#
    /// The server's own marks: they can only make a tool stricter (`Connections.access`).
    var readOnly: Bool? = nil
    var destructive: Bool? = nil
    /// SHA-256 of the whole definition as listed, so any change to it shows.
    var hash = ""

    /// From one entry of `tools/list`. Nil without a name.
    init?(listed: [String: Any]) {
        guard let name = listed["name"] as? String, !name.isEmpty else { return nil }
        self.name = name
        description = listed["description"] as? String ?? ""
        if let schema = listed["inputSchema"], let data = try? JSONSerialization.data(withJSONObject: schema, options: .sortedKeys) {
            self.schema = String(decoding: data, as: UTF8.self)
        }
        let marks = listed["annotations"] as? [String: Any]
        readOnly = marks?["readOnlyHint"] as? Bool
        destructive = marks?["destructiveHint"] as? Bool
        let whole = (try? JSONSerialization.data(withJSONObject: listed, options: .sortedKeys)) ?? Data(name.utf8)
        hash = SHA256.hash(data: whole).map { String(format: "%02x", $0) }.joined()
    }

    init(name: String, description: String = "", schema: String = #"{"type":"object"}"#, readOnly: Bool? = nil,
         destructive: Bool? = nil, hash: String = "") {
        (self.name, self.description, self.schema, self.readOnly, self.destructive, self.hash) = (name, description, schema, readOnly, destructive, hash)
    }
}

/// What a server answered to a call: its text, as data.
struct ConnectorAnswer: Sendable, Equatable {
    var text: String
    var isError = false
}

/// The only thing a transport takes to call a tool. A read permit is made here, only for a tool that reads; a write
/// permit only inside `Hand.act` (Senses/Hand.swift), so no other code can send a write (HandTests.testOnlyHandActs).
struct ConnectorPermit: Sendable, Equatable {
    let tool: String

    init?(reading tool: ConnectorTool, on server: ConnectorServer) {
        guard Connections.access(tool, on: server) == .read else { return nil }
        self.tool = tool.name
    }
}

/// A write the model asked for, held until the Hand runs it. Memory only; the arguments are never logged.
struct ConnectorCall: Sendable, Equatable {
    /// `ConnectorServer.id`.
    var server: String
    /// The server's plain name, for the card and the menu.
    var name: String
    var tool: String
    /// The arguments, a JSON object.
    var arguments: Data
    /// NB.9: the door it goes through. For door 1, `server` is Claude Code's own name of the server.
    var door = ConnectorDoor.own
    /// NB.9: door 1's key of the tool call waiting in a live run; nil, or a run that ended: a fresh short run.
    var request: String? = nil
}

/// How a door reaches a server: list its tools, call one. Door 2 is `OwnClient`; door 1 and the tests' fakes plug in.
protocol ConnectorTransport: Sendable {
    func tools() async throws -> [ConnectorTool]
    func call(_ permit: ConnectorPermit, arguments: Data) async throws -> ConnectorAnswer
}

/// A door with its own sign-in (door 2). Door 1 has none: the user's Claude account holds it.
protocol ConnectorSignIn: Sendable {
    /// `open` shows the sign-in page in the browser, only when the user pressed Connect.
    func signIn(open: @escaping @Sendable (URL) -> Void) async throws
    /// Removes the token from the Keychain.
    func signOut()
}

enum ConnectorError: Error, Equatable {
    case notConnected, signIn, changed, failed, tooLarge, timeout
}

/// The tools of a server, as remembered on the day the user connected, against what it lists now.
struct ConnectorChange: Sendable, Equatable {
    var added: [String] = [], removed: [String] = [], altered: [String] = []

    /// One line for the panel, names of the server's own tools only.
    func line(_ name: String) -> String {
        var parts: [String] = []
        if !added.isEmpty { parts.append("new: " + added.joined(separator: ", ")) }
        if !removed.isEmpty { parts.append("gone: " + removed.joined(separator: ", ")) }
        if !altered.isEmpty { parts.append("changed: " + altered.joined(separator: ", ")) }
        return "The tools of \(name) changed (\(parts.joined(separator: "; "))). Phew does not use them until you accept."
    }
}

/// NB.9: which door reaches a server. The panel lists each door in its own section.
enum ConnectorDoor: String, Sendable { case own, claudeAccount }

/// One tool for the panel: its name and whether it writes.
struct ConnectorToolLine: Sendable, Equatable, Hashable {
    var name: String
    var writes: Bool
}

/// A server for the menu's Connections panel. Names only, no word of the user.
struct ConnectorStatus: Sendable, Equatable, Identifiable {
    var id: String
    var name: String
    var door = ConnectorDoor.own
    var connected = false
    var tools: [ConnectorToolLine] = []
    var change: ConnectorChange? = nil
}

/// The connections of this Mac: the remembered tool lists (with Phew's settings: names and hashes only), the doors,
/// the gate. Reads run here; a write only through `Hand.act`, which calls `write` with a permit it made.
final class Connections: @unchecked Sendable {  // state under `lock`
    static let shared = Connections()

    let servers: [ConnectorServer]
    private let defaults: UserDefaults
    private let make: @Sendable (ConnectorServer) -> any ConnectorTransport
    private let lock = NSLock()
    private var doors: [String: any ConnectorTransport] = [:]
    private var changes: [String: ConnectorChange] = [:]

    /// Tests pass made-up servers, a throwaway defaults suite and a fake door.
    init(servers: [ConnectorServer] = ConnectorServer.all, defaults: UserDefaults = .standard,
         make: @escaping @Sendable (ConnectorServer) -> any ConnectorTransport = { OwnClient(server: $0) }) {
        self.servers = servers
        self.defaults = defaults
        self.make = make
    }

    // MARK: The gate

    /// The verbs that only read. A name needs at least one.
    static let readVerbs: Set = ["get", "list", "search", "read", "fetch", "query", "find", "view", "show", "describe", "count",
                                 "lookup", "status", "download"]
    /// Nouns and joiners that change nothing. A read verb is still needed beside them. "check" is not a read verb, so "check_in_user" writes;
    /// "comment" alone is left out, so "get-comment" asks.
    static let harmlessWords: Set = ["page", "pages", "file", "files", "user", "users", "comments", "event", "events", "item",
                                     "items", "by", "id", "ids", "info", "details", "metadata", "recent", "all", "of", "for",
                                     "in", "the", "my", "self", "content", "document", "doc", "docs", "sheet", "values", "thread",
                                     "threads", "messages", "calendar", "calendars", "team", "teams", "project", "projects",
                                     "database", "data", "source", "sources", "results", "logs", "message", "draft",
                                     "drafts", "label", "labels", "spreadsheet", "permissions", "revisions", "shared",
                                     "drive", "drives", "presentation", "profile"]

    /// Read or write, decided by Phew's code: the server's table first, else the name; the server's own marks can only
    /// make it stricter. A tool it cannot judge writes.
    static func access(_ tool: ConnectorTool, on server: ConnectorServer) -> ConnectorAccess {
        let phew: ConnectorAccess = server.writes.contains(tool.name) ? .write
            : server.reads.contains(tool.name) ? .read : byName(tool.name, server: server)
        if phew == .read, tool.readOnly == false || tool.destructive == true { return .write }
        return phew
    }

    /// A read only when every word of the name, after the server's own prefix, is a read verb or a harmless word, and
    /// one at least is a read verb. Anything else writes: a word Phew does not know, any sign that is not ASCII.
    static func byName(_ name: String, server: ConnectorServer) -> ConnectorAccess {
        guard var words = nameWords(name) else { return .write }
        if words.first == server.id { words.removeFirst() }
        guard words.contains(where: readVerbs.contains),
              words.allSatisfy({ readVerbs.contains($0) || harmlessWords.contains($0) }) else { return .write }
        return .read
    }

    /// A tool name's words, lower case: split at every sign and digit, at a capital inside a word ("getPage") and at
    /// the end of a capital run ("fetchANDDelete": fetch, and, delete). Nil when the name holds anything not ASCII.
    static func nameWords(_ name: String) -> [String]? {
        guard name.unicodeScalars.allSatisfy(\.isASCII) else { return nil }
        return name.replacing(#/([a-z])([A-Z])/#) { "\($0.1) \($0.2)" }
            .replacing(#/([A-Z]+)([A-Z][a-z])/#) { "\($0.1) \($0.2)" }
            .lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init)
    }

    /// Lower-case words of a name or a text: split at every sign and at a capital inside a word ("getPage").
    static func words(_ text: String) -> [String] {
        text.replacing(#/([a-z0-9])([A-Z])/#) { "\($0.1) \($0.2)" }.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    // MARK: The tools that fit the job

    /// At most this many tools of one server go to the model in one run.
    static let mostTools = 12
    /// A tool's description is cut to this many characters before it goes to the model.
    static let descriptionCap = 600
    /// At most this much of one answer goes to the model.
    static let answerCap = 20_000

    private static let common: Set = ["the", "and", "for", "with", "from", "that", "this", "into", "about", "what", "which",
                                      "are", "was", "you", "your", "can", "all", "any", "its", "his", "her", "per", "con",
                                      "del", "della", "che", "una", "uno", "dei", "nel", "nella", "sul", "alla", "mio", "mia"]

    /// The words that count for a match: three letters or more, not a common word, a plural's "s" dropped.
    static func terms(_ text: String) -> Set<String> {
        Set(words(text).filter { $0.count >= 3 && !common.contains($0) }.map { $0.count > 3 && $0.hasSuffix("s") ? String($0.dropLast()) : $0 })
    }

    /// The tools that fit the task's words: those sharing a word with its name (counted twice) or description, best
    /// first; ties go to the tools in Phew's table, then to reads. At most `mostTools`; none when nothing matches.
    static func chosen(_ tools: [ConnectorTool], on server: ConnectorServer, for task: String) -> [ConnectorTool] {
        let asked = terms(task)
        let scored = tools.map { tool in
            (tool, 2 * terms(tool.name).intersection(asked).count + terms(tool.description).intersection(asked).count)
        }
        func rank(_ tool: ConnectorTool) -> Int {
            (server.reads.contains(tool.name) || server.writes.contains(tool.name) ? 0 : 2) + (access(tool, on: server) == .read ? 0 : 1)
        }
        return scored.filter { $0.1 > 0 }
            .sorted { ($0.1, -rank($0.0), $1.0.name) > ($1.1, -rank($1.0), $0.0.name) }
            .prefix(mostTools).map(\.0)
    }

    /// The tool as the model sees it: the server's id before its name, the description cut, a write said to wait.
    /// Nil for a name the API would refuse.
    static func spec(_ tool: ConnectorTool, on server: ConnectorServer) -> ToolSpec? {
        let name = "\(server.id)__\(tool.name)"
        guard name.wholeMatch(of: #/[a-zA-Z0-9_-]{1,64}/#) != nil else { return nil }
        let cut = tool.description.count > descriptionCap ? tool.description.prefix(descriptionCap) + "…" : Substring(tool.description)
        let writes = access(tool, on: server) == .write
            ? " It changes the user's \(server.name): it does not run now, it waits for the user's confirm in the menu bar." : ""
        return ToolSpec(name: name, description: "\(server.name): \(cut)\(writes)", schema: tool.schema)
    }

    /// A call's arguments as they may leave the Mac: every string in them (keys too) through the secrets filter, keys
    /// sorted. Not JSON: the text, filtered.
    static func filtered(_ arguments: Data) -> Data {
        func clean(_ value: Any) -> Any {
            switch value {
            case let text as String: SecretsFilter.clean(text)
            case let list as [Any]: list.map(clean)
            case let object as [String: Any]:
                Dictionary(object.map { (SecretsFilter.clean($0.key), clean($0.value)) }, uniquingKeysWith: { a, _ in a })
            default: value
            }
        }
        guard let value = try? JSONSerialization.jsonObject(with: arguments, options: .fragmentsAllowed),
              let data = try? JSONSerialization.data(withJSONObject: clean(value), options: [.sortedKeys, .fragmentsAllowed])
        else { return Data(SecretsFilter.clean(String(decoding: arguments, as: UTF8.self)).utf8) }
        return data
    }

    /// A JSON object written one way only: keys sorted, `true` never equal to `1`. Nil for anything else.
    static func canonical(_ arguments: Data) -> Data? {
        guard let object = (try? JSONSerialization.jsonObject(with: arguments)) as? [String: Any] else { return nil }
        return try? JSONSerialization.data(withJSONObject: object, options: .sortedKeys)
    }

    /// The secrets filter would change something in these arguments.
    static func holdsSecret(_ arguments: Data) -> Bool { canonical(arguments).map { $0 != filtered(arguments) } ?? true }

    /// A tool's answer for the model: cut to `answerCap`, filtered, in its `<connector>` block, as data.
    static func answer(_ answer: ConnectorAnswer) -> String {
        let cut = answer.text.count > answerCap ? String(answer.text.prefix(answerCap)) + "\n[cut: the answer was longer]" : answer.text
        let head = answer.isError ? "The tool answered with an error.\n" : ""
        return head + Guide.block("connector", SecretsFilter.clean(cut))
    }

    // MARK: Remembered tool lists

    private struct Pin: Codable, Equatable { var hash: String; var writes: Bool }
    private static func key(_ id: String) -> String { "connectorTools.\(id)" }

    private func pins(_ id: String) -> [String: Pin]? {
        defaults.data(forKey: Self.key(id)).flatMap { try? JSONDecoder().decode([String: Pin].self, from: $0) }
    }

    private func pin(_ server: ConnectorServer, _ tools: [ConnectorTool]) {
        let pins = Dictionary(tools.map { ($0.name, Pin(hash: $0.hash, writes: Self.access($0, on: server) == .write)) }, uniquingKeysWith: { a, _ in a })
        defaults.set(try? JSONEncoder().encode(pins), forKey: Self.key(server.id))
        lock.withLock { changes[server.id] = nil }
    }

    /// Nil when the list is the one remembered.
    static func change(from pinned: [String: String], to tools: [ConnectorTool]) -> ConnectorChange? {
        let now = Dictionary(tools.map { ($0.name, $0.hash) }, uniquingKeysWith: { a, _ in a })
        let change = ConnectorChange(added: now.keys.filter { pinned[$0] == nil }.sorted(),
                                     removed: pinned.keys.filter { now[$0] == nil }.sorted(),
                                     altered: now.filter { pinned[$0.key] != nil && pinned[$0.key] != $0.value }.keys.sorted())
        return change == ConnectorChange() ? nil : change
    }

    func server(_ id: String) -> ConnectorServer? { servers.first { $0.id == id } }

    private func door(_ server: ConnectorServer) -> any ConnectorTransport {
        lock.withLock {
            if let door = doors[server.id] { return door }
            let door = make(server)
            doors[server.id] = door
            return door
        }
    }

    // MARK: Connect, check, accept, disconnect

    /// Connect: the sign-in (the browser opens through `open`), then the tool list, remembered from now on.
    func connect(_ id: String, open: @escaping @Sendable (URL) -> Void) async throws -> [ConnectorTool] {
        guard let server = server(id) else { throw ConnectorError.notConnected }
        let door = door(server)
        try await (door as? ConnectorSignIn)?.signIn(open: open)
        let tools = try await door.tools()
        pin(server, tools)
        shellLog("connections: \(id) connected, \(tools.count) tools")
        return tools
    }

    /// The server's tools now, only when they are the ones remembered. A change is kept for the panel and nothing of
    /// that server is used until the user accepts it.
    func check(_ server: ConnectorServer) async throws -> [ConnectorTool] {
        guard let pinned = pins(server.id) else { throw ConnectorError.notConnected }
        let tools = try await door(server).tools()
        if let change = Self.change(from: pinned.mapValues(\.hash), to: tools) {
            lock.withLock { changes[server.id] = change }
            shellLog("connections: \(server.id) tools changed, stopped")
            throw ConnectorError.changed
        }
        lock.withLock { changes[server.id] = nil }
        return tools
    }

    /// The user accepted the changed list in the panel: it is remembered as it is now.
    func accept(_ id: String) async throws {
        guard let server = server(id), pins(id) != nil else { throw ConnectorError.notConnected }
        pin(server, try await door(server).tools())
        shellLog("connections: \(id) changed tools accepted")
    }

    /// The token leaves the Keychain and the remembered list goes.
    func disconnect(_ id: String) {
        guard let server = server(id) else { return }
        (door(server) as? ConnectorSignIn)?.signOut()
        defaults.removeObject(forKey: Self.key(id))
        lock.withLock { doors[id] = nil; changes[id] = nil }
        shellLog("connections: \(id) disconnected")
    }

    /// For the panel.
    func status() -> [ConnectorStatus] {
        servers.map { server in
            let pinned = pins(server.id)
            return ConnectorStatus(id: server.id, name: server.name, connected: pinned != nil,
                                   tools: (pinned ?? [:]).map { ConnectorToolLine(name: $0.key, writes: $0.value.writes) }.sorted { $0.name < $1.name },
                                   change: lock.withLock { changes[server.id] })
        }
    }

    // MARK: Reads, freely

    /// One read, in its block as data. A tool that writes is refused here: it needs the Hand.
    func read(_ tool: ConnectorTool, on server: ConnectorServer, arguments: Data) async -> String {
        guard let permit = ConnectorPermit(reading: tool, on: server) else { return AddItemTool.refused }
        do {
            return Self.answer(try await door(server).call(permit, arguments: Self.filtered(arguments)))
        } catch {
            return "The tool failed. Write the report with what you have."  // no error text: it could carry the request
        }
    }

    /// The tools of each connected server that fit the task, checked against the remembered lists once. A server whose
    /// list changed, or that fails, offers nothing.
    func offer(for task: String) async -> [(server: ConnectorServer, tool: ConnectorTool)] {
        var offered: [(ConnectorServer, ConnectorTool)] = []
        for server in servers where pins(server.id) != nil {
            guard let tools = try? await check(server) else { continue }
            offered += Self.chosen(tools, on: server, for: task).map { (server, $0) }
        }
        return offered
    }
}

/// The Hand's seam for a write (Senses/Hand.swift): it runs only with a permit `Hand.act` made, after the list is
/// checked again. Blocks until it ends, Stop, or `writeTimeout`: off the main thread, as the Hand is.
extension Connections: HandConnector {
    static let writeTimeout: TimeInterval = 60

    func write(_ call: ConnectorCall, permit: ConnectorPermit, stop: @escaping () -> Bool) -> HandEnd {
        guard let server = server(call.server), permit.tool == call.tool else { return .failed }
        let ended = OSAllocatedUnfairLock<HandEnd?>(initialState: nil)
        let task = Task {
            let end: HandEnd
            do {
                // The tool must still be the one remembered: a list that changed stops it.
                guard try await check(server).contains(where: { $0.name == call.tool }) else { ended.withLock { $0 = .gone }; return }
                end = try await door(server).call(permit, arguments: Self.filtered(call.arguments)).isError ? .failed : .done
            } catch ConnectorError.changed {
                end = .surprise
            } catch {
                end = .failed
            }
            ended.withLock { $0 = end }
        }
        let start = Date()
        while true {
            if let end = ended.withLock({ $0 }) { return end }
            if stop() { task.cancel(); return .stopped }
            if Date().timeIntervalSince(start) > Self.writeTimeout { task.cancel(); return .timeout }
            Thread.sleep(forTimeInterval: 0.02)
        }
    }
}

// MARK: For a research task

/// The Runner's `add_item`-like door for a connector write: the Shell runs it through the Hand in an agent's job, so it
/// waits for the confirm. Returns the Hand's fixed word.
typealias ConnectorAsk = @Sendable (ConnectorCall) async -> String

/// The connector tools of one task: reads at once, a write handed to the Shell to wait. Names the servers it used.
struct ConnectorTools: ToolRunner {
    let connections: Connections
    let offered: [(server: ConnectorServer, tool: ConnectorTool, spec: ToolSpec)]
    let ask: ConnectorAsk?
    let used = UsedConnectors()
    /// A write asked for, as the report lists it with `add_item`'s: label, tool, word.
    var asked: @Sendable (String, String, String) -> Void = { _, _, _ in }

    init(connections: Connections, offered: [(server: ConnectorServer, tool: ConnectorTool)], ask: ConnectorAsk?) {
        self.connections = connections
        self.ask = ask
        // Without the Shell's door no write is offered.
        self.offered = offered.compactMap { pair in
            guard ask != nil || Connections.access(pair.tool, on: pair.server) == .read,
                  let spec = Connections.spec(pair.tool, on: pair.server) else { return nil }
            return (pair.server, pair.tool, spec)
        }
    }

    var tools: [ToolSpec] { offered.map(\.spec) }

    func run(_ name: String, input: Data) async throws -> String {
        guard let hit = offered.first(where: { $0.spec.name == name }),
              (try? JSONSerialization.jsonObject(with: input)) is [String: Any] else { return AddItemTool.refused }
        // The model wrote the arguments: they leave filtered, and the confirm row shows them as they will leave.
        let input = Connections.filtered(input)
        let (server, tool) = (hit.server, hit.tool)
        used.add(server.name)
        if Connections.access(tool, on: server) == .read { return await connections.read(tool, on: server, arguments: input) }
        guard let ask else { return AddItemTool.refused }
        let word = await ask(ConnectorCall(server: server.id, name: server.name, tool: tool.name, arguments: input))
        asked("In \(server.name):", tool.name, word)
        return word
    }
}

/// The connections a task used, by name, for the end of its report. Memory only.
final class UsedConnectors: @unchecked Sendable {
    private let lock = NSLock()
    private var names: [String] = []

    func add(_ name: String) { lock.withLock { if !names.contains(name) { names.append(name) } } }

    var section: String {
        let names = lock.withLock { self.names }
        return names.isEmpty ? "" : "\n\n## Connections he used\n\n" + names.map { "- \($0)" }.joined(separator: "\n")
    }
}

// MARK: The Brain's door for the panel

extension ClaudeBrain {
    func connectors() async -> [ConnectorStatus] { (connections?.status() ?? []) + (claudeCode?.status() ?? []) }

    func connect(_ server: String, open: @escaping @Sendable (URL) -> Void) async -> String? {
        guard let connections else { return Connections.line(.notConnected) }
        do {
            _ = try await connections.connect(server, open: open)
            return nil
        } catch {
            return Connections.line(error as? ConnectorError ?? .failed)
        }
    }

    func acceptTools(_ server: String) async -> String? {
        if let claudeCode, claudeCode.accept(server) { return nil }  // door 1
        do {
            try await connections?.accept(server)
            return nil
        } catch {
            return Connections.line(error as? ConnectorError ?? .failed)
        }
    }

    func disconnect(_ server: String) async { connections?.disconnect(server) }

    var connector: (any HandConnector)? {
        connections == nil && claudeCode == nil ? nil : ConnectorDoors(own: connections, claudeCode: claudeCode)
    }
}

extension Connections {
    /// The panel's one line for what went wrong. Fixed words.
    static func line(_ error: ConnectorError) -> String {
        switch error {
        case .signIn: "The sign-in did not finish. Try Connect again."
        case .notConnected: "Not connected."
        case .changed: "Its tools changed: accept the change first."
        case .tooLarge: "Its answer was too large."
        case .timeout: "It did not answer in time."
        case .failed: "It could not be reached. Try again later."
        }
    }
}
