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
    /// The project folders the user pointed Phew at (PB.2), and where Claude Code keeps its memory files.
    var projectFolders = ProjectFolders()
    /// The ceilings on what the key spends, checked before each new request from the user. Nil: none (unit tests,
    /// so they never read the real calls.log or settings); the app passes `Limits()`.
    var limits: Limits? = nil

    /// Only when the Map cannot be opened.
    static let cannotRemember = "My memory isn't available right now, so nothing was stored."

    func answer(_ question: String, packet: ContextPacket?) -> AsyncThrowingStream<BrainEvent, Error> {
        answer(question, packet: packet, state: ShellState())
    }

    func answer(_ question: String, packet: ContextPacket?, state: ShellState) -> AsyncThrowingStream<BrainEvent, Error> {
        answer(question, packet: packet, state: state, spoken: [])
    }

    func answer(_ question: String, packet: ContextPacket?, state: ShellState, spoken: [Hearing]) -> AsyncThrowingStream<BrainEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try limits?.start()  // a question or a reply: a new request
                    // The packet was filtered by Senses; the typed question is filtered here, before any call (the
                    // hearings in `Spoken.block`).
                    try await run(SecretsFilter.clean(question), packet: packet, state: state, spoken: spoken) { continuation.yield($0) }
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
        try await nextAction(request, packet: packet, done: done, spoken: [])
    }

    func nextAction(_ request: String, packet: ContextPacket?, done: [String], spoken: [Hearing]) async throws -> NextAction {
        do {
            // The packet was filtered by Senses; the words and the lines of done actions are filtered here.
            return try await Doer.next(SecretsFilter.clean(request), packet: packet, done: done.map(SecretsFilter.clean),
                                       spoken: spoken, provider: provider)
        } catch {
            throw BrainError(error)
        }
    }

    func forgetTurns() { memory.clear() }

    func spokenNames() async -> [String] { await map.spokenNames() }

    func heardAs() async -> [String: String] { await map.heardAs() }

    func learnHeard(_ heard: String, meant: String) async -> Bool {
        guard let change = NameMatch.correction(heard: heard, meant: meant) else { return false }
        return await map.addHeardAs(change.heard, name: change.meant)
    }

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

    private func run(_ question: String, packet: ContextPacket?, state: ShellState, spoken: [Hearing], emit: (BrainEvent) -> Void) async throws {
        let start = Date()
        // Side by side, so together they cost one small-model round trip. The Map is read by code, no model call.
        // P6.3: for a spoken question, the words the recogniser had (screen and memory), so a misheard name can be put right.
        let mapNames = spoken.isEmpty ? [] : await map.spokenNames()
        let names = spoken.isEmpty ? [] : packet?.spokenContext(extra: mapNames) ?? mapNames
        async let routing = Conductor.understand(question, packet: packet, spoken: spoken, names: names, provider: provider)
        async let cleaned = Observer.clean(packet?.visibleText ?? "", question: question, provider: provider)
        async let recalled = recall(question, packet: packet)
        var route: Route
        var aboutPhew = true  // A1: unsure, the text about himself goes along
        do {
            let understood = try await routing
            route = understood.route
            aboutPhew = understood.aboutPhew
            if let heard = understood.heard { emit(.heard(heard)) }  // P6.3: the card shows what he understood
        } catch BrainError.refused, BrainError.badOutput {
            route = .explain  // the Guide, with its fallback model, can still answer
        }
        emit(.route(route))
        if route == .unclear { return }  // P6.3: nothing answered, nothing acts; the Shell shows what was heard
        // N3.7: unsure hearing on a route that changes something: nothing stored here; the Shell shows the heard text.
        if SendOrShow.held(route, acting: state.acting, spoken: spoken) != nil { return }
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
        let project = route == .explain ? await projectMemoryBlock(question, packet: packet, store: store) : nil
        var explanation = "", steps: [GuideStep] = []
        try await Guide.answer(question, packet: packet, route: route, earlier: earlier, recall: lines, about: about,
                               aboutPhew: aboutPhew, projectMemory: project, spoken: spoken, tools: tools ?? store.map(MapSearch.init), provider: provider) { event in
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

    /// "Read again when needed" (5.10, 5.11): when the question or the task is about a project whose folder the user
    /// chose (the open file is inside it, or the Project code detects carries the folder's name), that project's
    /// CLAUDE.md and memory files as one filtered data block, for this request only. Nil otherwise: never for another
    /// project, never with no folder chosen.
    func projectMemoryBlock(_ question: String, packet: ContextPacket?, store: MapStore?) async -> String? {
        let folders = projectFolders.folders
        guard !folders.isEmpty else { return nil }
        let path = packet?.documentPath.map { ProjectMemoryReader.real(URL(fileURLWithPath: $0)).path }
        var chosen = folders.first { folder in path?.hasPrefix(folder.path + "/") == true }
        if chosen == nil, let store,
           let project = await store.detectProject(appName: packet?.appName ?? "", windowTitle: packet?.windowTitle ?? "",
                                                   documentPath: packet?.documentPath, question: question) {
            chosen = folders.first { MapStore.sameName(project, $0.lastPathComponent) }
        }
        guard let chosen, let block = ProjectMemoryReader.excerpt(folder: chosen, claudeHome: projectFolders.claudeHome) else { return nil }
        shellLog("brain: project memory added, \(block.count) chars")
        return block
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
        runTask(words, packet: packet, number: number, folder: folder, spoken: [], add: add)
    }

    func runTask(_ words: String, packet: ContextPacket?, number: Int, folder: URL?, spoken: [Hearing], add: AddItem?) -> AsyncThrowingStream<TaskEvent, Error> {
        let injected = tools, map = map, brain = self
        // The task was counted when its words were routed. N2.12: it sets aside its budget out of today's ceiling, so
        // tasks side by side cannot pass it together; a smaller reserve caps its cost, and past it the task ends
        // through its own cost limit, with its report so far. Nothing left: it does not start.
        var taskLimits = TaskLimits()
        if let limits {
            taskLimits.dayLeft = limits.reserve(task: number, usd: taskLimits.usd)
            taskLimits.dayCeiling = limits.usdPerDay
            guard taskLimits.dayLeft > 0 else {
                return AsyncThrowingStream { $0.finish(throwing: BrainError.limited(.dayUSD(limits.usdPerDay))) }
            }
        }
        let stream = Runner.stream(words, packet: packet, spoken: spoken, number: number, folder: folder, tools: {
            let search: (any ToolRunner)? = if let injected { injected } else { await map.now().map { MapSearch(store: $0, forRunner: true) } }
            return search.map(RunnerTools.init)
        }, projectMemory: {
            await brain.projectMemoryBlock(SecretsFilter.clean(words), packet: packet, store: await map.now()).map(Runner.withoutAddresses)
        }, add: add, provider: provider, limits: taskLimits)
        guard let limits else { return stream }
        // What the task did not spend goes back when it ends, fails or is stopped.
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await event in stream { continuation.yield(event) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
                limits.release(task: number)
            }
            continuation.onTermination = { _ in
                task.cancel()
                limits.release(task: number)
            }
        }
    }

    func limitsToday() async -> LimitsToday? {
        guard let limits else { return nil }
        return await Task.detached { limits.today() }.value
    }

    func setDayLimit(usd: Double) {
        limits?.defaults.set(max(0, usd), forKey: Limits.usdKey)
    }

    func keepTurn(_ question: String, answer: String) {
        memory.add(Guide.turn(question, explanation: answer, steps: []))
    }
}

// MARK: Imported memory (phase PB)

extension ClaudeBrain {
    // Each sort is one new request for the limits, however many calls it makes.
    func sortImport(_ text: String, source: ImportSource) async throws -> ImportSort {
        do {
            try limits?.start()
            return try await Importer.sort(text, source: source, provider: provider)
        } catch { throw BrainError(error) }
    }

    func projectMemory(folder: URL) -> ProjectMemory {
        projectFolders.remember(folder)
        return ProjectMemoryReader.read(folder: folder, claudeHome: projectFolders.claudeHome)
    }

    func sortImport(_ memory: ProjectMemory) async throws -> ImportSort {
        do {
            try limits?.start()
            return try await Importer.sort(memory, provider: provider)
        } catch { throw BrainError(error) }
    }

    func claudeExport(at url: URL) async -> ClaudeExport {
        await Task.detached { ClaudeExportReader.read(url) }.value
    }

    func sortImport(_ export: ClaudeExport, progress: @escaping @Sendable (Int, Int) -> Void) async throws -> ImportSort {
        do {
            try limits?.start()
            return try await Importer.sort(export, provider: provider, progress: progress)
        } catch { throw BrainError(error) }
    }

    func sortReport(_ markdown: String) async throws -> ImportSort {
        do {
            try limits?.start()
            return try await Importer.sort(report: markdown, provider: provider)
        } catch { throw BrainError(error) }
    }

    /// After every Librarian run started before, like every other write.
    func keepImport(_ candidates: [ImportCandidate]) async throws -> ImportKept {
        guard let store = await map.ready() else { return ImportKept(card: Self.cannotRemember) }
        do { return try await store.keep(candidates) } catch { throw BrainError(error) }
    }

    func lastImport() async -> ImportInfo? { await map.ready()?.lastImport() }

    func undoLastImport() async -> String? {
        guard let store = await map.ready() else { return nil }
        return (try? await store.undoLastImport())?.label
    }
}
