import Foundation

/// Follows the user through a guide, so there is no Next button: after they act, looks at the fresh screen and
/// says which step they are on now and where that step points. Main model, sees the screenshot, one answer bound
/// to a schema. Never ends the guide by itself: a refusal or a bad answer keeps the user on the same step.
/// Main, not small: in the live self-check (12 Nov) the small model missed two steps done at once (3 of 4 right),
/// the main model got 4 of 4, at about $0.0025 instead of $0.00015 a look and the same 2 s.
enum Follower {
    static let system = """
        You follow the user through a short guide on their Mac, so they never have to press a Next \
        button. You get the steps of the guide in order, the step the user was on, and their screen as it is \
        now: a screenshot with the app, the front window, the element under the mouse pointer, the elements you can \
        point at, and the visible text of the front window.

        Decide which step the user is on now. Judge only from what the screen shows, never from what the user \
        might have done. A step counts as done only when its result is visible. Start from the step they were on: \
        when its result is visible, move to the next step and check that one the same way. The user may have \
        done several steps at once, so skip ahead as far as the screen shows. When you are unsure, stay on the same \
        step. Never move back to an earlier step unless the screen clearly shows its result undone. When the results \
        of all the steps are visible, the guide is done.

        Then give the target of the step the user is on now, on this screen: the id of a listed element (for \
        example e12), never an id that is not in the list. Only when no listed element fits and a screenshot is \
        attached, give a point in screenshot pixels instead (x to the right, y down, from the top-left corner). \
        Otherwise, and when the guide is done, leave both empty.
        """

    static let schema = #"""
        {"type":"object","properties":{"step":{"type":"integer"},"element":{"type":["string","null"]},"point":{"anyOf":[{"type":"object","properties":{"x":{"type":"integer"},"y":{"type":"integer"}},"required":["x","y"],"additionalProperties":false},{"type":"null"}]}},"required":["step","element","point"],"additionalProperties":false}
        """#

    struct Output: Decodable {
        /// 1-based, as the prompt counts; `steps.count + 1` means done.
        let step: Int
        let element: String?
        let point: Guide.Output.Step.Point?
    }

    static func progress(steps: [GuideStep], current: Int, packet: ContextPacket?,
                         provider: any ModelProvider) async throws -> GuideProgress {
        let current = min(max(current, 0), steps.count)
        let stay = GuideProgress(current: current, target: nil)
        // Nothing left to follow, or no screen to judge from: no call.
        guard current < steps.count, let packet else { return stay }
        let shot = packet.screenshot.flatMap(ScreenshotSize.init(png:))
        let output: Output
        do {
            let json = try await provider.complete(request(steps: steps, current: current, packet: packet, shot: shot))
            guard let decoded = try? JSONDecoder().decode(Output.self, from: Data(json.utf8)) else { throw BrainError.badOutput }
            output = decoded
        } catch BrainError.refused, BrainError.badOutput {
            shellLog("follower: no usable answer, staying on step \(current + 1) of \(steps.count)")
            return stay
        }
        let now = min(max(output.step - 1, 0), steps.count)
        let target = now < steps.count ? Guide.target(element: output.element, point: output.point, packet: packet, shot: shot) : nil
        let kind = switch target { case .element: "element"; case .point: "point"; case nil: "none" }
        shellLog("follower: step \(current + 1) to \(now + 1) of \(steps.count), target \(kind)")
        return GuideProgress(current: now, target: target)
    }

    static func request(steps: [GuideStep], current: Int, packet: ContextPacket, shot: ScreenshotSize?) -> ModelRequest {
        let list = steps.enumerated().map { "\($0.offset + 1). \($0.element.instruction)" }.joined(separator: "\n")
        let task = """
            Steps of the guide:
            \(list)
            The user was on step \(current + 1). Reply with the step they are on now: a number from 1 to \
            \(steps.count), or \(steps.count + 1) when every step is done.
            """
        return ModelRequest(agent: "follower", tier: .main, system: system, text: [Guide.context(packet, shot: shot), task].joined(separator: "\n\n"),
                            image: shot == nil ? nil : packet.screenshot, schema: schema, maxTokens: 2048)
    }
}
