import Foundation

/// The Brain the Shell constructs: Conductor and Observer side by side on the small model, the Map read by code,
/// then the Guide, then the Librarian in the background.
struct ClaudeBrain: Brain {
    var provider: any ModelProvider = ClaudeProvider()
    /// The Guide's tools. Nil: `search_map` on the Map when it is open, else none. Never the Follower's.
    var tools: (any ToolRunner)? = nil
    /// The last turns as text, for follow-up questions. A reference, so every copy of this Brain shares it.
    var memory = WorkingMemory()
    /// The Map, opened on first need, and the Librarian's runs. A reference, shared like `memory`.
    var map = BrainMap()

    /// Only when the Map cannot be opened.
    static let cannotRemember = "My memory isn't available right now, so nothing was stored."

    func answer(_ question: String, packet: ContextPacket?) -> AsyncThrowingStream<BrainEvent, Error> {
        answer(question, packet: packet, state: ShellState())
    }

    func answer(_ question: String, packet: ContextPacket?, state: ShellState) -> AsyncThrowingStream<BrainEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    // The packet was filtered by Senses; the typed question is filtered here, before any call.
                    try await run(SecretsFilter.clean(question), packet: packet, state: state) { continuation.yield($0) }
                    continuation.yield(.done)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: BrainError(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func progress(steps: [GuideStep], current: Int, packet: ContextPacket?) async throws -> GuideProgress {
        do {
            return try await Follower.progress(steps: steps, current: current, packet: packet, provider: provider)
        } catch {
            throw BrainError(error)
        }
    }

    func nextAction(_ request: String, packet: ContextPacket?, done: [String]) async throws -> NextAction {
        do {
            // The packet was filtered by Senses; the words and the lines of done actions are filtered here.
            return try await Doer.next(SecretsFilter.clean(request), packet: packet, done: done.map(SecretsFilter.clean), provider: provider)
        } catch {
            throw BrainError(error)
        }
    }

    func forgetTurns() { memory.clear() }

    // MARK: Recently deleted (5.5, roadmap P5.15)

    func recentlyDeleted() async -> [DeletedItem] {
        await map.ready()?.recentlyDeleted().map { DeletedItem(id: $0.id, label: $0.label, daysLeft: $0.daysLeft) } ?? []
    }

    func restore(_ id: Int64) async -> Bool {
        guard let store = await map.ready() else { return false }
        return (try? await store.restore(id)) ?? false
    }

    func deleteNow(_ id: Int64) async -> Bool {
        guard let store = await map.ready() else { return false }
        return (try? await store.deleteNow(id)) ?? false
    }

    /// After every Librarian run started before, like every other read.
    func exportMap(includeSensitive: Bool) async -> String? {
        await map.ready()?.export(includeSensitive: includeSensitive)
    }

    // MARK: One request

    private func run(_ question: String, packet: ContextPacket?, state: ShellState, emit: (BrainEvent) -> Void) async throws {
        let start = Date()
        // Side by side, so together they cost one small-model round trip. The Map is read by code, no model call.
        async let routing = Conductor.route(question, packet: packet, provider: provider)
        async let cleaned = Observer.clean(packet?.visibleText ?? "", question: question, provider: provider)
        async let recalled = recall(question, packet: packet)
        var route: Route
        do {
            route = try await routing
        } catch BrainError.refused, BrainError.badOutput {
            route = .explain  // the Guide, with its fallback model, can still answer
        }
        emit(.route(route))
        if route == .remember { return try await remember(question, packet: packet, emit: emit) }
        if route == .task { return }  // PA.2: the Shell starts the task through `runTask`
        // PH.4: the Shell runs an act job through `nextAction`. With acting off it is shown as a guide.
        if route == .act && state.acting { return }
        if route == .act { route = .guide }
        var packet = packet
        packet?.visibleText = await cleaned
        let earlier = memory.turns
        let (store, lines) = await recalled
        shellLog("brain: route \(route), text \(packet?.visibleText.count ?? 0) chars after the observer, \(earlier.count) earlier turns, map \(store == nil ? "off" : "on") with \(lines.isEmpty ? 0 : lines.split(separator: "\n").count) lines, ready in \(Int(Date().timeIntervalSince(start) * 1000)) ms")
        let held = await store?.counts()
        let about = SelfKnowledge.live(state, turn: earlier.count + 1, projects: held?.projects, facts: held?.facts)
        var explanation = "", steps: [GuideStep] = []
        try await Guide.answer(question, packet: packet, route: route, earlier: earlier, recall: lines, about: about,
                               tools: tools ?? store.map(MapSearch.init), provider: provider) { event in
            if case .text(let piece) = event { explanation += piece }
            if case .steps(let given) = event { steps = given }
            emit(event)
        }
        // Only a finished answer is kept, and only as text. The Librarian learns from the same text.
        let turn = Guide.turn(question, explanation: explanation, steps: steps)
        memory.add(turn)
        await map.learn(question: question, answer: turn.answer, route: route, packet: packet, provider: provider)
    }

    /// Layers 1 and 2 of 5.11: the profile on top, then what code recalls for this question. Empty without a Map.
    /// Does not wait for the last answer's Librarian (PS.12); the remember route does.
    private func recall(_ question: String, packet: ContextPacket?) async -> (MapStore?, String) {
        guard let store = await map.now() else { return (nil, "") }
        let profile = await store.profile()
        let recall = await store.recall(question: question, appName: packet?.appName ?? "", windowTitle: packet?.windowTitle ?? "",
                                        documentPath: packet?.documentPath)
        return (store, [profile, recall].filter { !$0.isEmpty }.joined(separator: "\n"))
    }

    /// The remember route (5.9): the Librarian alone, then its one line on the card. A forget clears the turns.
    private func remember(_ question: String, packet: ContextPacket?, emit: (BrainEvent) -> Void) async throws {
        guard let store = await map.ready() else { return emit(.text(Self.cannotRemember)) }
        let outcome = try await store.learn(question: question, answer: "", route: .remember, packet: BrainMap.labels(packet),
                                            lastTurn: memory.turns.last, provider: provider)
        if outcome.forgot != nil { memory.clear() }
        emit(.text(outcome.askBack ?? outcome.card))
    }
}

// MARK: Tasks (phase PA)

extension ClaudeBrain {
    /// The Runner with the Map search when the Map is open (addresses left out of its lines), and the web.
    func runTask(_ words: String, packet: ContextPacket?, number: Int, folder: URL?, add: AddItem?) -> AsyncThrowingStream<TaskEvent, Error> {
        let injected = tools, map = map
        return Runner.stream(words, packet: packet, number: number, folder: folder, tools: {
            let search: (any ToolRunner)? = if let injected { injected } else { await map.now().map { MapSearch(store: $0, forRunner: true) } }
            return search.map(RunnerTools.init)
        }, add: add, provider: provider)
    }

    func keepTurn(_ question: String, answer: String) {
        memory.add(Guide.turn(question, explanation: answer, steps: []))
    }
}
