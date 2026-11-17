import Foundation

/// The Brain's door to the Map, shared by every copy of `ClaudeBrain`. The Map opens on first need; when it cannot
/// open, answers go on without memory. Librarian runs are chained, and every read waits for the last one, so a recall
/// or a forget always sees what the previous answer stored.
actor BrainMap {
    private let open: @Sendable () throws -> MapStore
    private var store: MapStore?
    /// When the last open failed. The open is tried again `retryAfter` seconds later, never latched off (R28).
    private var failedAt: Date?
    private let retryAfter: TimeInterval
    private var learning: Task<Void, Never>?

    /// `maintenance`: the real delete of what was forgotten over 30 days ago, now and then once a day (5.5). Off
    /// under tests, so a test never opens the real Map.
    init(open: @escaping @Sendable () throws -> MapStore = { try MapStore.openOnMac() },
         maintenance: Bool = NSClassFromString("XCTestCase") == nil, retryAfter: TimeInterval = 30,
         conversationEnd: TimeInterval = WorkingMemory.lifetime) {
        self.open = open
        self.retryAfter = retryAfter
        self.conversationEnd = conversationEnd
        guard maintenance else { return }
        // Lives as long as the app: the Brain is made once, at launch.
        Task {
            while true {
                await self.purge()
                try? await Task.sleep(for: .seconds(86_400))
            }
        }
    }

    /// The Map, once every Librarian run started before has finished. Nil when it cannot be opened. For what must
    /// see the last answer's facts: remember and forget, Recently deleted, the export.
    func ready() async -> MapStore? {
        endConversation()  // N4.6: what is still to learn is learned first
        while let task = learning {
            await task.value
            if learning == task { learning = nil }
        }
        return opened()
    }

    /// The Map as it is now, without waiting for a Librarian still running (PS.12): for the recall and the search
    /// of the next answer, which has the last answer in its turns anyway. The wait was about 3.2 s on 14 Nov.
    func now() -> MapStore? { opened() }

    private func opened() -> MapStore? {
        if store == nil, failedAt.map({ Date.now.timeIntervalSince($0) >= retryAfter }) ?? true {
            do {
                store = try open()
                failedAt = nil
            } catch {
                failedAt = .now
                shellLog("map: not available, answering without memory")
            }
        }
        return store
    }

    /// True while the Map cannot be opened; asking tries again once the wait is over.
    func off() -> Bool { opened() == nil }

    /// N4.6: the answers of this conversation not yet learned from, as text, with the labels of their packet only, so
    /// the capture is not kept past the answer. In memory only.
    private var pending: [(question: String, answer: String, route: Route, labels: ContextPacket?)] = []
    private var pendingProvider: (any ModelProvider)?
    private var noted = 0
    /// N4.6: a conversation is over this long after its last answer, as the working memory's turns are (10 minutes).
    private let conversationEnd: TimeInterval
    /// N4.6: a long conversation is learned from every this many answers, so one call never carries too much.
    static let mostPending = WorkingMemory.maxTurns

    /// After an answer (N4.6): kept until the conversation ends (the card closes, 10 minutes pass with no reply, or Phew
    /// quits), then the Librarian learns from all its answers in one call, in the background. Anything that must see
    /// the facts (`ready`) learns them first, so nothing waits to be learned when it is read. A failure writes nothing
    /// and leaves one fixed line.
    func learn(question: String, answer: String, route: Route, packet: ContextPacket?, provider: any ModelProvider) {
        guard store != nil else { return }
        pending.append((question, answer, route, Self.labels(packet)))
        pendingProvider = provider
        noted += 1
        guard pending.count < Self.mostPending else { return endConversation() }
        let mark = noted, wait = conversationEnd
        Task {
            try? await Task.sleep(for: .seconds(wait))
            await self.endConversation(after: mark)
        }
    }

    /// N4.6: the conversation is over: its answers go to the Librarian in one call, after any run still going.
    /// `after`: only when no answer came since that one (the 10-minute timer).
    func endConversation(after mark: Int? = nil) {
        guard mark.map({ $0 == noted }) ?? true, let store, let provider = pendingProvider, let last = pending.last else { return }
        let turns = pending
        pending = []
        let previous = learning
        let question = turns.map(\.question).joined(separator: "\n"), answer = turns.map(\.answer).joined(separator: "\n\n")
        shellLog("librarian: conversation of \(turns.count) answers")
        learning = Task {
            await previous?.value
            do {
                _ = try await store.learn(question: question, answer: answer, route: last.route, packet: last.labels, provider: provider)
            } catch {
                shellLog("librarian: failed, nothing written")
            }
        }
    }

    /// Names for the recogniser (P6.3): current Projects, People, Tools and Organizations, the most recently changed
    /// first, at most `limit`. Names only; nothing sensitive. Does not wait for a Librarian still running.
    func spokenNames(limit: Int = 30) async -> [String] {
        guard let store = opened() else { return [] }
        var nodes: [MapNode] = []
        for mapClass in [MapClass.project, .person, .tool, .organization] { nodes += (try? await store.currentNodes(mapClass)) ?? [] }
        var seen = Set<String>()
        return Array(nodes.filter { !$0.sensitive }.sorted { $0.updated > $1.updated }.map(\.name)
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }.prefix(limit))
    }

    /// N3.2: words heard before for those names, heard words to name. Does not wait for a Librarian still running.
    func heardAs() async -> [String: String] {
        guard let store = opened() else { return [:] }
        return (try? await store.heardAs()) ?? [:]
    }

    /// N3.2: a correction the user made to a heard name, kept as "also heard as" of that name. False: nothing kept.
    func addHeardAs(_ heard: String, name: String) async -> Bool {
        guard let store = await ready() else { return false }
        return (try? await store.addHeardAs(heard, name: name)) ?? false
    }

    /// The real delete of every forget past 30 days.
    func purge(now: Date = .now) async {
        guard let store = await ready() else { return }
        do {
            let wiped = try await store.purge(now: now)
            shellLog("map: purge, \(wiped) forgets deleted for real")
        } catch {
            shellLog("map: purge failed")
        }
    }

    /// What the Map may keep of a packet: the app name, the window title and the document's path or address.
    static func labels(_ packet: ContextPacket?) -> ContextPacket? {
        packet.map { ContextPacket(appName: $0.appName, bundleID: "", windowTitle: $0.windowTitle, visibleText: "", cursor: nil,
                                   documentPath: $0.documentPath) }
    }
}

extension ClaudeBrain {
    func memoryOff() async -> Bool { await map.off() }
}

/// `search_map` for the Guide, run on the Map by `MapStore.searchMap`. Logs nothing.
/// Fewer than the 10 lines a search may return means nothing was cut: a fixed line says so, so the model does
/// not search again for the same period.
struct MapSearch: ToolRunner {
    static let complete = "These are all the matches."
    let store: MapStore
    /// For the Runner: web addresses are left out of every line (5.11), so no address from the Map reaches it.
    let forRunner: Bool
    var tools: [ToolSpec] { [.searchMap] }

    init(store: MapStore) { self.init(store: store, forRunner: false) }
    init(store: MapStore, forRunner: Bool) {
        self.store = store
        self.forRunner = forRunner
    }

    func run(_ name: String, input: Data) async throws -> String {
        var out = name == ToolSpec.searchMap.name ? await store.searchMap(input: input, forRunner: forRunner) : ""
        if !out.isEmpty, out.split(separator: "\n").count < 10 { out += "\n" + Self.complete }
        return out
    }

    func isComplete(_ result: String) -> Bool { result.hasSuffix(Self.complete) }
}
