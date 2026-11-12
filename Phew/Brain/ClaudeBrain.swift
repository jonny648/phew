import Foundation

/// The Brain the Shell constructs: Conductor and Observer side by side on the small model, then the Guide.
struct ClaudeBrain: Brain {
    var provider: any ModelProvider = ClaudeProvider()

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
        shellLog("brain: route \(route), text \(packet?.visibleText.count ?? 0) chars after the observer, ready in \(Int(Date().timeIntervalSince(start) * 1000)) ms")
        try await Guide.answer(question, packet: packet, route: route, provider: provider, emit: emit)
    }
}
