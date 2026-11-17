import Foundation

/// The Brain the Shell constructs: the Conductor on the small model beside the Map read by code (and, for a typed
/// question, the Guide's plain explanation, R57), then the Guide, then the Librarian in the background.
struct ClaudeBrain: Brain {
    var provider: any ModelProvider = ClaudeProvider()
    /// The Guide's tools. Nil: `search_map` on the Map when it is open, else none. Never the Follower's.
    var tools: (any ToolRunner)? = nil
    /// NC: the self-made skills a task may write and run, in the closed box. Nil: no such tools (tests, checks).
    var skills: SkillTools? = nil
    /// The last turns as text, for follow-up questions. A reference, so every copy of this Brain shares it.
    var memory = WorkingMemory()
    /// The Map, opened on first need, and the Librarian's runs. A reference, shared like `memory`.
    var map = BrainMap()
    /// The project folders the user pointed Phew at (PB.2), and where Claude Code keeps its memory files.
    var projectFolders = ProjectFolders()
    /// The ceilings on what the key spends, checked before each new request from the user. Nil: none (unit tests,
    /// so they never read the real calls.log or settings); the app passes `Limits()`.
    var limits: Limits? = nil
    /// R57: a typed question starts its explanation beside the Conductor, held back until the route says explain, not
    /// about Phew; on any other route it is cancelled unseen (its cost logged as cancelled). Off by default, so unit
    /// tests stay deterministic; the app turns it on.
    var answerEarly = false
    /// D3: asked at each reply, so an earlier screen from an app put on the list since is never sent.
    var neverRead = NeverReadList.shared
    /// NA.11: the folders the user let a research task read. Empty: a task has no file tool.
    var fileFolders = ReadFolders()
    /// NA.12: where a replaced file goes before its new text is written. Nil: the system's Trash. Tests pass a stand-in.
    var trash: (@Sendable (URL) throws -> Void)? = nil
    /// NB: the tools the user connected. Nil: none (unit tests, checks); the app passes `Connections.shared`.
    var connections: Connections? = nil
    /// NB.9, NB.10: door 1, through Claude Code under the user's own Claude plan. Nil: none (unit tests, checks); the
    /// app passes `ClaudeCodeDoor.shared`, which starts nothing until the user switches it on.
    var claudeCode: ClaudeCodeDoor? = nil
    /// N4.5, N4.7: the hidden switches. Tests pass their own defaults.
    var switches = CostSwitches()
    /// NB.5: the user's ticks in "Shortcuts he may run". Nil: no shortcut tool (unit tests, checks); the app passes one.
    var shortcutTicks: ShortcutTicks? = nil

    /// Only when the Map cannot be opened.
    static let cannotRemember = "My memory isn't available right now, so nothing was stored."

    func answer(_ question: String, packet: ContextPacket?) -> AsyncThrowingStream<BrainEvent, Error> {
        answer(question, packet: packet, state: ShellState())
    }

    func answer(_ question: String, packet: ContextPacket?, state: ShellState) -> AsyncThrowingStream<BrainEvent, Error> {
        answer(question, packet: packet, state: state, spoken: [])
    }

    func answer(_ question: String, packet: ContextPacket?, state: ShellState, spoken: [Hearing]) -> AsyncThrowingStream<BrainEvent, Error> {
        answer(question, packet: packet, state: state, spoken: spoken, asItIs: false)
    }

    func answerAsItIs(_ question: String, packet: ContextPacket?, state: ShellState) -> AsyncThrowingStream<BrainEvent, Error> {
        answer(question, packet: packet, state: state, spoken: [], asItIs: true)
    }

    private func answer(_ question: String, packet: ContextPacket?, state: ShellState, spoken: [Hearing],
                        asItIs: Bool) -> AsyncThrowingStream<BrainEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try limits?.start()  // a question or a reply: a new request
                    // The packet was filtered by Senses; the typed question is filtered here, before any call (the
                    // hearings in `Spoken.block`). D7: as it is, the Guide alone gets the words unfiltered.
                    try await run(SecretsFilter.clean(question), asTyped: asItIs ? question : nil, packet: packet, state: state,
                                  spoken: spoken) { continuation.yield($0) }
                    continuation.yield(.done)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: BrainError(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func progress(steps: [GuideStep], current: Int, packet: ContextPacket?, before: Set<String>?) async throws -> GuideProgress {
        if let before, let done = Follower.confirmed(steps: steps, current: current, packet: packet, before: before) { return done }
        return try await progress(steps: steps, current: current, packet: packet)
    }

    func progress(steps: [GuideStep], current: Int, packet: ContextPacket?) async throws -> GuideProgress {
        do {
            return try await Follower.progress(steps: steps, current: current, packet: packet, provider: provider,
                                               smallFirst: switches.smallFollower)
        } catch {
            throw BrainError(error)
        }
    }

    func nextAction(_ request: String, packet: ContextPacket?, done: [String]) async throws -> NextAction {
        try await nextAction(request, packet: packet, done: done, spoken: [])
    }

    func nextAction(_ request: String, packet: ContextPacket?, done: [String], spoken: [Hearing]) async throws -> NextAction {
        try await nextAction(request, packet: packet, done: done, spoken: spoken, skill: nil)
    }

    func nextAction(_ request: String, packet: ContextPacket?, done: [String], spoken: [Hearing], skill: String?) async throws -> NextAction {
        try await plan(request, packet: packet, done: done, spoken: spoken, skill: skill, batch: false)[0].action
    }

    /// N4.5: several actions per call, unless the hidden switch is off.
    func nextActions(_ request: String, packet: ContextPacket?, done: [String], spoken: [Hearing], skill: String?) async throws -> [PlannedAction] {
        try await plan(request, packet: packet, done: done, spoken: spoken, skill: skill, batch: switches.batch)
    }

    private func plan(_ request: String, packet: ContextPacket?, done: [String], spoken: [Hearing], skill: String?,
                      batch: Bool) async throws -> [PlannedAction] {
        do {
            // The packet was filtered by Senses; the words, the lines of done actions and the last skill's result are
            // filtered here. NC.9: the kept skills are listed as data, read again each round (a few small files).
            return try await Doer.plan(SecretsFilter.clean(request), packet: packet, done: done.map(SecretsFilter.clean),
                                       spoken: spoken, skills: skills.map { $0.block() ?? Doer.noSkillsYet },
                                       skill: skill.map(SecretsFilter.clean), batch: batch, provider: provider)
        } catch {
            throw BrainError(error)
        }
    }

    func forgetTurns() {
        memory.clear()
        Task { [map] in await map.endConversation() }  // N4.6: the card closed or Phew quits: the Librarian learns now
    }

    func finishLearning() async {
        memory.clear()
        await map.learned()
    }

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

    // MARK: Saved conversations (D3, 05-map.md 5.8.1)

    func savedThreads() async -> [SavedThread] { await map.ready()?.threads() ?? [] }

    func openThread(_ id: Int64) async -> SavedThread? {
        guard let thread = await map.ready()?.thread(id) else { return nil }
        memory.resume(id: thread.id, turns: thread.turns, project: thread.projectID)
        return thread
    }

    func forgetThread(_ id: Int64) async -> String? {
        guard let store = await map.ready() else { return nil }
        return (try? await store.forgetThread(id))?.label
    }

    /// After every Librarian run started before, like every other read.
    func exportMap(includeSensitive: Bool) async -> String? {
        await map.ready()?.export(includeSensitive: includeSensitive)
    }

    // MARK: One request

    /// `question` is filtered. `asTyped` (D7): the user's own words, sent to the Guide in its place; everything else
    /// (the Conductor, the Map, the turn kept, the Librarian) has the filtered `question`.
    private func run(_ question: String, asTyped: String? = nil, packet: ContextPacket?, state: ShellState, spoken: [Hearing],
                     emit: (BrainEvent) -> Void) async throws {
        let start = Date()
        let taken = memory.now()  // when this turn's capture was taken, for its 10 minutes as the earlier screen
        let sent = asTyped ?? question
        // The Conductor and the Map side by side. The Map is read by code, no model call.
        // P6.3: for a spoken question, the words the recogniser had (screen and memory), so a misheard name can be put right.
        let mapNames = spoken.isEmpty ? [] : await map.spokenNames()
        let names = spoken.isEmpty ? [] : packet?.spokenContext(extra: mapNames) ?? mapNames
        async let routing = Conductor.understand(question, packet: packet, spoken: spoken, names: names, provider: provider)
        // R47: there is no Observer: the Guide reads the packet's text as it is.
        let recalled = Task { await recall(question, packet: packet) }
        let earlier = memory.turns
        // D3: the previous turn's capture, for a reply, as data; dropped here when its app is never read now.
        let earlierScreen = memory.earlierCapture(refusing: neverRead.refuses)
        // R57: a typed question's plain explanation starts now; its words wait in `early` until the route is known.
        let (early, out) = AsyncThrowingStream<BrainEvent, Error>.makeStream()
        let starting = answerEarly && spoken.isEmpty && !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let explaining = !starting ? nil : Task {
            do {
                let (store, lines) = await recalled.value
                let project = await projectMemoryBlock(question, packet: packet, store: store)
                try await Guide.answer(sent, packet: packet, route: .explain, earlier: earlier, recall: lines, aboutPhew: false,
                                       projectMemory: project, earlierScreen: earlierScreen, tools: tools ?? store.map(MapSearch.init),
                                       provider: provider, half: switches.halfPicture, small: switches.smallExplain) { out.yield($0) }
                out.finish()
            } catch { out.finish(throwing: error) }
        }
        defer { explaining?.cancel() }  // any route but a plain explanation: cancelled, never shown
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
        if route == .watch { return }  // NA.15: the Shell starts the watcher, on the Mac; nothing more is sent
        // PH.4: the Shell runs an act job through `nextAction`. With acting off it is shown as a guide.
        if route == .act && state.acting { return }
        if route == .act { route = .guide }
        let (store, lines) = await recalled.value
        let fromEarly = explaining != nil && route == .explain && !aboutPhew
        shellLog("brain: route \(route), text \(packet?.visibleText.count ?? 0) chars,\(earlier.count) earlier turns, earlier screen \(earlierScreen != nil), map \(store == nil ? "off" : "on") with \(lines.isEmpty ? 0 : lines.split(separator: "\n").count) lines, ready in \(Int(Date().timeIntervalSince(start) * 1000)) ms\(explaining == nil ? "" : fromEarly ? ", early answer kept" : ", early answer cancelled")")
        var explanation = "", steps: [GuideStep] = []
        func take(_ event: BrainEvent) {
            if case .text(let piece) = event { explanation += piece }
            if case .steps(let given) = event { steps = given }
            emit(event)
        }
        if fromEarly {
            for try await event in early { take(event) }
            try Task.checkCancellation()  // a stopped stream ends quietly: a cut answer is never kept or learned from
        } else {
            explaining?.cancel()
            let held = await store?.counts()
            let about = SelfKnowledge.live(state, turn: earlier.count + 1, projects: held?.projects, facts: held?.facts)
            let project = route == .explain ? await projectMemoryBlock(question, packet: packet, store: store) : nil
            try await Guide.answer(sent, packet: packet, route: route, earlier: earlier, recall: lines, about: about,
                                   aboutPhew: aboutPhew, projectMemory: project, spoken: spoken, earlierScreen: earlierScreen,
                                   tools: tools ?? store.map(MapSearch.init), provider: provider,
                                   half: switches.halfPicture, small: switches.smallExplain, emit: take)
        }
        // Only a finished answer is kept, and only as text. The Librarian learns from the same text.
        let turn = Guide.turn(question, explanation: explanation, steps: steps)
        memory.add(turn)
        memory.keepCapture(packet, taken: taken)  // D3: in memory only, the earlier screen of the next reply
        await saveThread(question, packet: packet)
        await map.learn(question: question, answer: turn.answer, route: route, packet: packet, provider: provider)
    }

    /// D3 (5.8.1): the conversation as text in the Map, one row rewritten after each turn, under the first Project code
    /// detects for it. Code only, no model call; never the capture. Does not wait for the Librarian.
    private func saveThread(_ question: String, packet: ContextPacket?) async {
        guard let store = await map.now() else { return }
        if !memory.hasProject,
           let project = await store.detectProject(appName: packet?.appName ?? "", windowTitle: packet?.windowTitle ?? "",
                                                   documentPath: packet?.documentPath, question: question) {
            memory.setProject(project.id)
        }
        let conversation = memory.conversation
        do {
            if let id = try await store.saveThread(id: conversation.id, turns: conversation.turns, project: conversation.project) {
                memory.saved(as: id, generation: conversation.generation)
            }
        } catch {
            shellLog("map: conversation not saved")
        }
    }

    /// Layers 1 and 2 of 5.11: the profile on top, then what code recalls for this question. Empty without a Map.
    /// Does not wait for the last answer's Librarian (PS.12); the remember route does.
    private func recall(_ question: String, packet: ContextPacket?) async -> (MapStore?, String) {
        guard let store = await map.now() else { return (nil, "") }
        let text = await store.profileAndRecall(question: question, appName: packet?.appName ?? "", windowTitle: packet?.windowTitle ?? "",
                                                documentPath: packet?.documentPath)
        return (store, text)
    }

    /// "Read again when needed" (5.10, 5.11): when the question or the task is about a project whose folder the user
    /// chose (the open file is inside it, or the Project code detects carries the folder's name), that project's
    /// CLAUDE.md and memory files as one filtered data block, for this request only. Nil otherwise: never for another
    /// project, never with no folder chosen.
    func projectMemoryBlock(_ question: String, packet: ContextPacket?, store: MapStore?) async -> String? {
        guard let store, !projectFolders.folders.isEmpty else { return nil }
        // R34: only while the Map holds that folder's Project, so a cancelled import, Undo last import or Forget stops it.
        await pruneFolders(store)
        let folders = projectFolders.folders
        let path = packet?.documentPath.map { ProjectMemoryReader.real(URL(fileURLWithPath: $0)).path }
        var chosen = folders.first { folder in path?.hasPrefix(folder.path + "/") == true }
        if chosen == nil,
           let project = await store.detectProject(appName: packet?.appName ?? "", windowTitle: packet?.windowTitle ?? "",
                                                   documentPath: packet?.documentPath, question: question) {
            chosen = folders.first { MapStore.sameName(project, $0.lastPathComponent) }
        }
        guard let chosen, let block = ProjectMemoryReader.excerpt(folder: chosen, claudeHome: projectFolders.claudeHome) else { return nil }
        shellLog("brain: project memory added, \(block.count) chars")
        return block
    }

    /// R34: a stored project folder goes when its Project is no longer current in the Map. A failed read drops nothing.
    func pruneFolders(_ store: MapStore) async {
        guard let projects = try? await store.currentNodes(.project) else { return }
        projectFolders.keepOnly(projects)
    }

    /// The remember route (5.9): the Librarian alone, then its one line on the card. A forget clears the turns.
    private func remember(_ question: String, packet: ContextPacket?, emit: (BrainEvent) -> Void) async throws {
        guard let store = await map.ready() else { return emit(.text(Self.cannotRemember)) }
        let outcome = try await store.learn(question: question, answer: "", route: .remember, packet: BrainMap.labels(packet),
                                            lastTurn: memory.turns.last, provider: provider)
        if outcome.forgot != nil {
            memory.clear()
            await pruneFolders(store)
        }
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
        runTask(words, packet: packet, number: number, folder: folder, spoken: spoken, add: add, change: nil)
    }

    func runTask(_ words: String, packet: ContextPacket?, number: Int, folder: URL?, spoken: [Hearing], add: AddItem?,
                 change: ChangeFile?) -> AsyncThrowingStream<TaskEvent, Error> {
        runTask(words, packet: packet, number: number, folder: folder, spoken: spoken, add: add, change: change, connector: nil)
    }

    func runTask(_ words: String, packet: ContextPacket?, number: Int, folder: URL?, spoken: [Hearing], add: AddItem?,
                 change: ChangeFile?, connector: ConnectorAsk?) -> AsyncThrowingStream<TaskEvent, Error> {
        runTask(words, packet: packet, number: number, folder: folder, spoken: spoken, add: add, change: change, connector: connector, shortcut: nil)
    }

    func runTask(_ words: String, packet: ContextPacket?, number: Int, folder: URL?, spoken: [Hearing], add: AddItem?,
                 change: ChangeFile?, connector: ConnectorAsk?, shortcut: ShortcutAsk?) -> AsyncThrowingStream<TaskEvent, Error> {
        // NB.10: both switches on: the task runs through Claude Code and the user's plan pays. Only its words go: no
        // screen read, no Map, no dollars set aside from today's ceiling (the task was counted as a request already).
        if let claudeCode, claudeCode.researches {
            return claudeCode.research(words, number: number, folder: folder, connector: connector,
                                       limits: TaskLimits.asksDeep(words) ? .deep : TaskLimits())
        }
        let injected = tools, map = map, brain = self, connections = connections
        // The task was counted when its words were routed. N2.12: it sets aside its budget out of today's ceiling, so
        // tasks side by side cannot pass it together; a smaller reserve caps its cost, and past it the task ends
        // through its own cost limit, with its report so far. Nothing left: it does not start.
        var taskLimits = TaskLimits.asksDeep(words) ? TaskLimits.deep : TaskLimits()
        if let limits {
            taskLimits.dayLeft = limits.reserve(task: number, usd: taskLimits.usd)
            // R8: deep only when today's ceiling has room for all of it; else the normal size, and the report says so.
            if taskLimits.size == .deep, taskLimits.dayLeft < taskLimits.usd {
                limits.release(task: number)
                taskLimits = TaskLimits()
                taskLimits.deepRefused = true
                taskLimits.dayLeft = limits.reserve(task: number, usd: taskLimits.usd)
            }
            taskLimits.dayCeiling = limits.usdPerDay
            // R31: too little left for one search, one page and a report: the money would go for no report.
            guard taskLimits.dayLeft >= Runner.minimumUSD else {
                limits.release(task: number)
                return AsyncThrowingStream { $0.finish(throwing: BrainError.limited(.dayUSD(limits.usdPerDay))) }
            }
        }
        let stream = Runner.stream(words, packet: packet, spoken: spoken, number: number, folder: folder, tools: {
            let search: (any ToolRunner)? = if let injected { injected } else { await map.now().map { MapSearch(store: $0, forRunner: true) } }
            return search.map(RunnerTools.init)
        }, projectMemory: {
            await brain.projectMemoryBlock(SecretsFilter.clean(words), packet: packet, store: await map.now()).map(Runner.withoutAddresses)
        }, add: add, skills: skills,
           files: fileFolders.folders.isEmpty ? nil : FileTools(folders: fileFolders, reads: taskLimits.fileReads, change: change),
           connectors: {
            // NB.4: only the tools that fit the task, from servers whose tools are as remembered; the task's own words.
            guard let connections else { return nil }
            let offered = await connections.offer(for: SecretsFilter.clean(words))
            return offered.isEmpty ? nil : ConnectorTools(connections: connections, offered: offered, ask: connector)
        }, shortcuts: shortcutTicks.flatMap { ShortcutTools(ticks: $0, ask: shortcut) }, provider: provider, limits: taskLimits)
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

    func readFolders() -> [URL] { fileFolders.folders }
    func addReadFolder(_ folder: URL) -> Bool { fileFolders.add(folder) }
    func removeReadFolder(_ folder: URL) { fileFolders.remove(folder) }

    /// NA.12: the user confirmed a waiting file change in the menu. The one call to `Files.replace`. Logs nothing.
    func changeFile(_ change: FileChange) async -> FileChangeEnd {
        let folders = fileFolders.folders, trash = trash
        return await Task.detached { Files.replace(change, folders: folders, trash: trash) }.value
    }

    func limitsToday() async -> LimitsToday? {
        guard let limits else { return nil }
        return await Task.detached { limits.today() }.value
    }

    func setDayLimit(usd: Double) {
        limits?.defaults.set(max(0, usd), forKey: Limits.usdKey)
    }

    func setDayLimit(requests: Int) {
        limits?.defaults.set(Limits.bounded(requests, Limits.dayBounds), forKey: Limits.requestsKey)
    }

    func setMinuteLimit(requests: Int) {
        limits?.defaults.set(Limits.bounded(requests, Limits.minuteBounds), forKey: Limits.minuteKey)
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
        projectFolders.pick(folder)  // R34: stored only if its import is kept
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
        do {
            let kept = try await store.keep(candidates)
            projectFolders.kept(fromFolder: candidates.contains { $0.source == .claudeCode })
            await pruneFolders(store)
            return kept
        } catch { throw BrainError(error) }
    }

    func lastImport() async -> ImportInfo? { await map.ready()?.lastImport() }

    func undoLastImport() async -> String? {
        guard let store = await map.ready() else { return nil }
        let label = (try? await store.undoLastImport())?.label
        await pruneFolders(store)
        return label
    }
}

// MARK: Door 1 for the panel (NB.9)

extension ClaudeBrain {
    func claudeAccount() async -> ClaudeAccount { claudeCode?.account ?? ClaudeAccount() }

    func useClaudeAccount(_ on: Bool) async -> String? {
        guard let claudeCode else { return ClaudeCodeDoor.line(.missing) }
        claudeCode.set(on: on)
        return on ? await claudeCode.list() : nil
    }

    func listClaudeAccount() async -> String? { await claudeCode?.list() ?? ClaudeCodeDoor.line(.missing) }

    func tickClaudeConnector(_ server: String, _ on: Bool) async { claudeCode?.tick(server, on) }

    func researchThroughClaudeAccount(_ on: Bool) async { claudeCode?.set(research: on) }

    /// NB.9: a job's connector step. Counted apart from the tasks (`task` below zero), one run at a time per job.
    func connectorStep(_ words: String, job: Int, ask: @escaping ConnectorAsk, stop: @escaping @Sendable () -> Bool) async -> (ok: Bool, line: String) {
        guard let claudeCode else { return (false, ClaudeCodeDoor.line(.off)) }
        let step = await claudeCode.step(words, task: -job, ask: ask, stop: stop)
        return (step.end == .done, step.text)
    }
}
