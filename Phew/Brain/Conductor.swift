import Foundation

/// Understands the request and chooses who works: explain, guide or remember. Small model, a few lines of
/// context (not the whole packet), an answer bound to a schema.
enum Conductor {
    static let system = """
        You route the requests the user sends to Phew, a companion on their Mac that explains what is \
        on screen. Choose one route.
        explain: they want to understand something they see, or they ask what Phew remembers or knows.
        guide: they want to know how to do something, where to click, or which steps to take.
        remember: they only ask Phew to remember, note or save something for later, to correct something it remembers, or to forget something.
        """

    static let schema = #"{"type":"object","properties":{"route":{"type":"string","enum":["explain","guide","remember"]}},"required":["route"],"additionalProperties":false}"#

    /// An empty question means "explain what is under the cursor": no call is needed.
    static func route(_ question: String, packet: ContextPacket?, provider: any ModelProvider) async throws -> Route {
        guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .explain }
        guard let route = decode(try await provider.complete(request(question, packet: packet))) else { throw BrainError.badOutput }
        return route
    }

    static func request(_ question: String, packet: ContextPacket?) -> ModelRequest {
        var lines: [String] = []
        if let packet {
            lines += ["App: \(packet.appName)", "Window: \(packet.windowTitle)"]
            if let cursor = packet.cursor { lines.append("Under the mouse pointer: \(cursor.role) \"\(cursor.label.prefix(100))\"") }
        }
        lines.append("Request: \(question)")
        return ModelRequest(agent: "conductor", tier: .small, system: system, text: lines.joined(separator: "\n"),
                            schema: schema, maxTokens: 1024)
    }

    /// Structured outputs do not guarantee the casing of enum values (docs), so compare lowercased.
    static func decode(_ json: String) -> Route? {
        struct Reply: Decodable { let route: String }
        return (try? JSONDecoder().decode(Reply.self, from: Data(json.utf8))).flatMap { Route(rawValue: $0.route.lowercased()) }
    }
}
