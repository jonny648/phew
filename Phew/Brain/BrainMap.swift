import Foundation

/// The Brain's door to the Map, shared by every copy of `ClaudeBrain`. The Map opens on first need; when it cannot
/// open, answers go on without memory. Librarian runs are chained, and every read waits for the last one, so a recall
/// or a forget always sees what the previous answer stored.
actor BrainMap {
    private let open: @Sendable () throws -> MapStore
    private var store: MapStore?
    private var unavailable = false
    private var learning: Task<Void, Never>?

    /// `maintenance`: the real delete of what was forgotten over 30 days ago, now and then once a day (5.5). Off
    /// under tests, so a test never opens the real Map.
    init(open: @escaping @Sendable () throws -> MapStore = { try MapStore.openOnMac() },
         maintenance: Bool = NSClassFromString("XCTestCase") == nil) {
        self.open = open
        guard maintenance else { return }
        // Lives as long as the app: the Brain is made once, at launch.
        Task {
            while true {
                await self.purge()
                try? await Task.sleep(for: .seconds(86_400))
            }
        }
    }

    /// The Map, once every Librarian run started before has finished. Nil when it cannot be opened.
    func ready() async -> MapStore? {
        while let task = learning {
            await task.value
            if learning == task { learning = nil }
        }
        if store == nil, !unavailable {
            do {
                store = try open()
            } catch {
                unavailable = true
                shellLog("map: not available, answering without memory")
            }
        }
        return store
    }

    /// After an answer: the Librarian in the background, after any run still going. The card does not wait for it.
    /// It gets the labels of the packet only, so the capture is not kept past the answer. A failure writes nothing
    /// and leaves one fixed line.
    func learn(question: String, answer: String, route: Route, packet: ContextPacket?, provider: any ModelProvider) {
        guard let store else { return }
        let previous = learning, labels = Self.labels(packet)
        learning = Task {
            await previous?.value
            do {
                _ = try await store.learn(question: question, answer: answer, route: route, packet: labels, provider: provider)
            } catch {
                shellLog("librarian: failed, nothing written")
            }
        }
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

/// `search_map` for the Guide, run on the Map by `MapStore.searchMap`. Logs nothing.
struct MapSearch: ToolRunner {
    let store: MapStore
    var tools: [ToolSpec] { [.searchMap] }

    func run(_ name: String, input: Data) async throws -> String {
        name == ToolSpec.searchMap.name ? await store.searchMap(input: input) : ""
    }
}
