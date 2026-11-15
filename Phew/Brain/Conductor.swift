import Foundation

/// Understands the request and chooses who works: explain, guide, remember, act or task. Small model, a few lines of
/// context (not the whole packet), an answer bound to a schema.
enum Conductor {
    /// act against guide (PH.4, docs/13-hand.md 13.4): asked to do, he does; asked how, he shows; unsure, he shows.
    static let system = """
        You route the requests the user sends to Phew, a companion on their Mac that explains what is \
        on screen and can also do things in the app in front of them. Choose one route.
        explain: they want to understand something they see, or they ask what Phew remembers or knows.
        guide: they want to know how to do something, where to click, or which steps to take.
        remember: they only ask Phew to remember, note or save something for later, to correct something it remembers, or to forget something.
        act: they clearly ask Phew to do something in the app for them now, as an order or a request: "make the title bold", \
        "add a row below", "can you tick this box?", "rendi il titolo in grassetto", "puoi aggiungere una riga?".
        A question about how, where or which steps ("how do I make it bold?", "come faccio a…", "dove trovo…") is guide, \
        never act. A wish or a goal that does not ask Phew to do it ("I need to export this", "devo esportarlo") is guide. \
        When you are unsure between act and guide, choose guide. "Remember…" or "note that…" is remember, not act.
        Adding a reminder, a calendar event, a note in Notes or a spreadsheet in Excel ("add a reminder…", "make a \
        note in Notes…", "aggiungi un promemoria…", "metti in calendario…") is act: it goes into that app, not into \
        Phew's memory.
        task: they hand Phew work to do on his own and report back later, usually research: "research X and report", \
        "find out…", "look into … and write me a report", "ricerca … e fammi un report", "scopri…". A question about \
        what is on screen stays explain or guide; asking Phew to do something in the app now stays act. When you are \
        unsure between task and explain, choose explain.
        unclear: only when the request is followed by a <spoken> block and neither hearing reads as a request about \
        this screen, about Phew's memory or for a task. Never for a request without a <spoken> block.
        heard: only when the request is followed by a <spoken> block: the request as you understood it, one line, in \
        the language it was said, with misheard words put right from the screen and the memory and names spelled as \
        they are there. Leave it out for a request without a <spoken> block.


        """ + Spoken.rule

    static let schema = #"{"type":"object","properties":{"route":{"type":"string","enum":["explain","guide","remember","act","task","unclear"]},"heard":{"type":"string"}},"required":["route"],"additionalProperties":false}"#

    /// The route, and for a spoken question the request as the model understood it (P6.3): the card shows that line
    /// as the question, so the user sees what he understood. Never logged.
    struct Understood: Equatable {
        var route: Route
        var heard: String?
    }

    /// An empty question means "explain what is under the cursor": no call is needed. `spoken`: the hearings of a
    /// question said aloud (P6.3). Only a spoken question can be unclear: a typed one is explained instead. `names`:
    /// for a spoken question, the words the recogniser was given (`Spoken.block`).
    static func understand(_ question: String, packet: ContextPacket?, spoken: [Hearing] = [], names: [String] = [],
                           provider: any ModelProvider) async throws -> Understood {
        guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return Understood(route: .explain) }
        let json = try await provider.complete(request(question, packet: packet, spoken: spoken, names: names))
        guard let route = decode(json) else { throw BrainError.badOutput }
        return Understood(route: route == .unclear && spoken.isEmpty ? .explain : route, heard: spoken.isEmpty ? nil : heard(json))
    }

    static func route(_ question: String, packet: ContextPacket?, spoken: [Hearing] = [], provider: any ModelProvider) async throws -> Route {
        try await understand(question, packet: packet, spoken: spoken, provider: provider).route
    }

    static func request(_ question: String, packet: ContextPacket?, spoken: [Hearing] = [], names: [String] = []) -> ModelRequest {
        var lines: [String] = []
        if let packet {
            lines += ["App: \(packet.appName)", "Window: \(packet.windowTitle)"]
            if let cursor = packet.cursor { lines.append("Under the mouse pointer: \(cursor.role) \"\(cursor.label.prefix(100))\"") }
        }
        lines.append(Spoken.after("Request: \(question)", spoken, names: names))
        return ModelRequest(agent: "conductor", tier: .small, system: system, text: lines.joined(separator: "\n"),
                            schema: schema, maxTokens: 1024)
    }

    /// Structured outputs do not guarantee the casing of enum values (docs), so compare lowercased.
    static func decode(_ json: String) -> Route? {
        (try? JSONDecoder().decode(Reply.self, from: Data(json.utf8))).flatMap { Route(rawValue: $0.route.lowercased()) }
    }

    /// The understood request: its first line, trimmed, at most 200 characters; nil when empty or left out.
    static func heard(_ json: String) -> String? {
        let line = (try? JSONDecoder().decode(Reply.self, from: Data(json.utf8)))?.heard?
            .split(whereSeparator: \.isNewline).first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        return line.isEmpty ? nil : String(line.prefix(200))
    }

    private struct Reply: Decodable {
        let route: String
        var heard: String? = nil
    }
}
