import Foundation

/// Explains and produces pointing steps. Main model, sees the screenshot.
///
/// The answer is one JSON object (structured outputs) whose first property, the explanation, is unescaped as it
/// streams; the steps are decoded and validated when it ends. Not "text, then a steps tool": on the main model,
/// text written before a tool call comes back as a progress-update thinking block, empty by default (docs).
enum Guide {
    static let system = """
        You are Phew, a companion on a university student's Mac. The student called you about what is on their \
        screen. You get the app, the window, the element under the mouse pointer, the elements you can point at, \
        the visible text, and sometimes a screenshot of the window.

        Write the explanation for a student: plain words, two to five short sentences, straight to the point. No \
        greeting, no preamble, no restating the question. Use the language of the student's question; when there \
        is no question, use the language of the screen and explain the element under the pointer in its context.

        When the route is guide, also give the steps to do it on this screen: in order, one action per step, at \
        most six, each a short instruction. Give each step a target when you can: the id of a listed element (for \
        example e12), never an id that is not in the list. Only when no listed element fits and a screenshot is \
        attached, give a point in screenshot pixels instead (x to the right, y down, from the top-left corner). \
        Otherwise leave both empty. When the route is explain, leave the steps empty.
        """

    static let schema = #"""
        {"type":"object","properties":{"explanation":{"type":"string"},"steps":{"type":"array","items":{"type":"object","properties":{"instruction":{"type":"string"},"element":{"type":["string","null"]},"point":{"anyOf":[{"type":"object","properties":{"x":{"type":"integer"},"y":{"type":"integer"}},"required":["x","y"],"additionalProperties":false},{"type":"null"}]}},"required":["instruction","element","point"],"additionalProperties":false}}},"required":["explanation","steps"],"additionalProperties":false}
        """#

    struct Output: Decodable {
        struct Step: Decodable {
            struct Point: Decodable { let x, y: Int }
            let instruction: String
            let element: String?
            let point: Point?
        }
        let explanation: String
        let steps: [Step]
    }

    static func answer(_ question: String, packet: ContextPacket?, route: Route, provider: any ModelProvider,
                       emit: (BrainEvent) -> Void) async throws {
        let shot = packet?.screenshot.flatMap(ScreenshotSize.init(png:))
        var json = "", stop = "", shown = false
        var explanation = ExplanationStream()
        for try await event in provider.stream(request(question, packet: packet, route: route, shot: shot)) {
            switch event {
            case .text(let piece):
                json += piece
                let words = explanation.feed(piece)
                if !words.isEmpty { shown = true; emit(.text(words)) }
            case .stop(let reason): stop = reason
            case .usage: break
            }
        }
        guard stop != "max_tokens", let output = try? JSONDecoder().decode(Output.self, from: Data(json.utf8)) else {
            throw BrainError.badOutput
        }
        if !shown { emit(.text(output.explanation)) }
        guard route == .guide else { return }
        let valid = steps(output.steps, packet: packet, shot: shot)
        let given = output.steps.filter { $0.element != nil || $0.point != nil }.count
        let kept = valid.filter { $0.target != nil }.count
        shellLog("guide: \(valid.count) steps, \(kept) with a target, \(given - kept) targets dropped")
        emit(.steps(valid))
    }

    static func request(_ question: String, packet: ContextPacket?, route: Route, shot: ScreenshotSize?) -> ModelRequest {
        let task = route == .guide ? "Route: guide. Explain briefly, then give the steps." : "Route: explain. Leave the steps empty."
        let asked = question.isEmpty ? "Question: none. Explain what is under the mouse pointer." : "Question: \(question)"
        let screen = packet.map { context($0, shot: shot) } ?? "No screen context."
        return ModelRequest(agent: "guide", tier: .main, system: system, text: [screen, task, asked].joined(separator: "\n\n"),
                            image: shot == nil ? nil : packet?.screenshot, schema: schema, maxTokens: 8192)
    }

    /// The packet as plain lines. Frames are given in window pixels, the screenshot's coordinates.
    static func context(_ packet: ContextPacket, shot: ScreenshotSize?) -> String {
        let origin = packet.windowFrame?.origin ?? .zero
        var lines = ["App: \(packet.appName)", "Window: \(packet.windowTitle)"]
        if let c = packet.cursor {
            let value = c.value.isEmpty ? "" : " value \"\(c.value.prefix(500))\""
            lines.append("Under the mouse pointer: \(c.role) \"\(c.label)\"\(value)\(c.id.map { " (\($0))" } ?? "")")
        }
        if !packet.pointables.isEmpty {
            lines.append("Elements you can point at (id, role, label, x,y and width×height in window pixels):")
            lines += packet.pointables.map { p in
                "\(p.id) \(p.role) \"\(p.label)\" \(Int(p.frame.minX - origin.x)),\(Int(p.frame.minY - origin.y)) \(Int(p.frame.width))×\(Int(p.frame.height))"
            }
        }
        lines.append(shot.map { "Screenshot: attached, \($0.seenWidth)×\($0.seenHeight) pixels." } ?? "Screenshot: none.")
        lines += ["Visible text:", packet.visibleText.isEmpty ? "(none)" : packet.visibleText]
        return lines.joined(separator: "\n")
    }

    /// Keeps a target only when it is real: an id from the packet, or a point inside the screenshot. Anything
    /// else becomes "no target", never a guess.
    static func steps(_ raw: [Output.Step], packet: ContextPacket?, shot: ScreenshotSize?) -> [GuideStep] {
        let ids = Set(packet?.pointables.map(\.id) ?? [])
        return raw.compactMap { step in
            let instruction = step.instruction.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !instruction.isEmpty else { return nil }
            let id = step.element?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if let id, ids.contains(id) { return GuideStep(instruction: instruction, target: .element(id)) }
            if let point = step.point, let pixel = shot?.pixel(x: point.x, y: point.y) {
                return GuideStep(instruction: instruction, target: .point(x: pixel.x, y: pixel.y))
            }
            return GuideStep(instruction: instruction, target: nil)
        }
    }
}
