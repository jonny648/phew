import Foundation

/// The Brain the Shell constructs: Conductor and Observer side by side on the small model, then the Guide.
struct ClaudeBrain: Brain {
    var provider: any ModelProvider = ClaudeProvider()
    /// The Guide's tools: `search_map` from stage S2. Nil: the Guide answers without tools. Never the Follower's.
    var tools: (any ToolRunner)? = nil
    /// The last turns as text, for follow-up questions. A reference, so every copy of this Brain shares it.
    var memory = WorkingMemory()

    // shortcut: a fixed English line until the Map exists (P5).
    static let cannotRemember = "I can't remember things yet. That's coming soon."

    func answer(_ question: String, packet: ContextPacket?) -> AsyncThrowingStream<BrainEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    // The packet was filtered by Senses; the typed question is filtered here, before any call.
                    try await run(SecretsFilter.clean(question), packet: packet) { continuation.yield($0) }
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

    func forgetTurns() { memory.clear() }

    private func run(_ question: String, packet: ContextPacket?, emit: (BrainEvent) -> Void) async throws {
        let start = Date()
        // Side by side, so together they cost one small-model round trip.
        async let routing = Conductor.route(question, packet: packet, provider: provider)
        async let cleaned = Observer.clean(packet?.visibleText ?? "", question: question, provider: provider)
        let route: Route
        do {
            route = try await routing
        } catch BrainError.refused, BrainError.badOutput {
            route = .explain  // the Guide, with its fallback model, can still answer
        }
        emit(.route(route))
        if route == .remember { return emit(.text(Self.cannotRemember)) }  // the Map comes in P5
        var packet = packet
        packet?.visibleText = await cleaned
        let earlier = memory.turns
        shellLog("brain: route \(route), text \(packet?.visibleText.count ?? 0) chars after the observer, \(earlier.count) earlier turns, ready in \(Int(Date().timeIntervalSince(start) * 1000)) ms")
        var explanation = "", steps: [GuideStep] = []
        try await Guide.answer(question, packet: packet, route: route, earlier: earlier, tools: tools, provider: provider) { event in
            if case .text(let piece) = event { explanation += piece }
            if case .steps(let given) = event { steps = given }
            emit(event)
        }
        // Only a finished answer is kept, and only as text.
        memory.add(Guide.turn(question, explanation: explanation, steps: steps))
    }
}
