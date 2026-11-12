import Foundation

/// Explains and produces pointing steps. Main model, sees the screenshot.
///
/// The answer is one JSON object (structured outputs) whose first property, the explanation, is unescaped as it
/// streams; the steps are decoded and validated when it ends. Not "text, then a steps tool": on the main model,
/// text written before a tool call comes back as a progress-update thinking block, empty by default (docs).
enum Guide {
    static let system = """
        You are Phew, a companion on a university student's Mac. The student called you about what is on their \
        screen. You get a screenshot with the text: the window under the mouse pointer, or the whole screen when \
        the pointer is not on the front window. You also get the app, the front window, the element under the \
        pointer, the elements you can point at, and the visible text of the front window.

        Use the screenshot and the text together. When the question is about something you can see in the \
        screenshot, such as a photo, a diagram, a chart, the desktop wallpaper or a design, answer from the \
        screenshot and name specifically what is there. When you cannot tell, say so. "This" means what is at the \
        mouse pointer.

        Write the explanation for a student in plain words, straight to the point. Let the question set the \
        length: a sentence or two for a simple question, a fuller explanation in short paragraphs when the student \
        asks you to explain something. No greeting, no preamble, no restating the question. Use the language of \
        the student's question; when there is no question, use the language of the screen and explain what is at \
        the mouse pointer in its context.

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

    /// The packet as plain lines. With a screenshot, positions are in the pixels the model sees: from the
    /// screenshot's top-left corner, scaled like the image when the API downsizes it, so they match the points it
    /// returns. Without one, in window pixels.
    static func context(_ packet: ContextPacket, shot: ScreenshotSize?) -> String {
        let frame = shot == nil ? nil : packet.screenshotFrame
        let origin = frame?.origin ?? packet.windowFrame?.origin ?? .zero
        let sx = shot.map { CGFloat($0.seenWidth) / CGFloat($0.width) } ?? 1
        let sy = shot.map { CGFloat($0.seenHeight) / CGFloat($0.height) } ?? 1
        func at(_ p: CGPoint) -> String { "\(Int(((p.x - origin.x) * sx).rounded())),\(Int(((p.y - origin.y) * sy).rounded()))" }
        var lines = ["App: \(packet.appName)", "Window: \(packet.windowTitle)"]
        if let c = packet.cursor {
            let value = c.value.isEmpty ? "" : " value \"\(c.value.prefix(500))\""
            lines.append("Under the mouse pointer: \(c.role) \"\(c.label)\"\(value)\(c.id.map { " (\($0))" } ?? "")")
        }
        if let frame, let mouse = packet.mouse, frame.contains(mouse) {
            lines.append("Mouse pointer: \(at(mouse)) in screenshot pixels.")
        }
        if !packet.pointables.isEmpty {
            lines.append("Elements you can point at (id, role, label, x,y and width×height in \(shot == nil ? "window" : "screenshot") pixels):")
            lines += packet.pointables.map { p in
                "\(p.id) \(p.role) \"\(p.label)\" \(at(p.frame.origin)) \(Int((p.frame.width * sx).rounded()))×\(Int((p.frame.height * sy).rounded()))"
            }
        }
        lines.append(shot.map { "Screenshot: attached, \($0.seenWidth)×\($0.seenHeight) pixels." } ?? "Screenshot: none.")
        lines += ["Visible text:", packet.visibleText.isEmpty ? "(none)" : packet.visibleText]
        return lines.joined(separator: "\n")
    }

    /// Keeps a target only when it is real: an id from the packet, or a point inside the screenshot. Anything
    /// else becomes "no target", never a guess.
    static func steps(_ raw: [Output.Step], packet: ContextPacket?, shot: ScreenshotSize?) -> [GuideStep] {
        raw.compactMap { step in
            let instruction = step.instruction.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !instruction.isEmpty else { return nil }
            return GuideStep(instruction: instruction, target: target(element: step.element, point: step.point, packet: packet, shot: shot))
        }
    }

    /// One target as the model gave it, kept only when real. Shared with the Follower.
    static func target(element: String?, point: Output.Step.Point?, packet: ContextPacket?, shot: ScreenshotSize?) -> StepTarget? {
        let id = element?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let id, packet?.pointables.contains(where: { $0.id == id }) == true { return .element(id) }
        if let point, let pixel = shot?.pixel(x: point.x, y: point.y) { return .point(x: pixel.x, y: pixel.y) }
        return nil
    }
}
