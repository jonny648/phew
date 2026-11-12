/// The only door from Shell and Senses into the Brain, so it can move to a backend later.
protocol Brain: Sendable {
    /// `question` may be empty: then Phew explains what is under the cursor. Events arrive in this order:
    /// `.route`, `.text` pieces as they stream, `.steps` (guide route only), `.done`.
    /// Errors are `BrainError`; `.noKey` means the Shell should ask for the API key.
    func answer(_ question: String, packet: ContextPacket?) -> AsyncThrowingStream<BrainEvent, Error>
}

enum Route: String, Sendable, CaseIterable {
    case explain, guide, remember
}

enum BrainEvent: Sendable, Equatable {
    case route(Route)
    /// The next piece of the explanation, to append to the card.
    case text(String)
    /// Validated: every element id exists in the packet, every point lies inside the screenshot.
    case steps([GuideStep])
    case done
}

struct GuideStep: Sendable, Equatable {
    var instruction: String
    /// Nil when there is nothing safe to point at.
    var target: StepTarget?
}

enum StepTarget: Sendable, Equatable {
    /// The `id` of one of the packet's pointables, e.g. "e12".
    case element(String)
    /// Screenshot pixels: 1 pixel per screen point, origin at the window's top-left.
    case point(x: Int, y: Int)
}

/// The small, readable set of things that go wrong. Never carries text from the request, the answer or the key.
enum BrainError: Error, Sendable, Equatable {
    case noKey
    case badKey
    case rateLimited
    case overloaded
    case network
    case refused
    /// The model's answer was cut off or did not match its schema.
    case badOutput
    /// Any other HTTP status from the API (400, 402, 403, 404, 413…).
    case failed(status: Int)
}

extension BrainError {
    init(status: Int) {
        switch status {
        case 401: self = .badKey
        case 429: self = .rateLimited
        case 500...: self = .overloaded  // 500 api_error, 529 overloaded_error
        default: self = .failed(status: status)
        }
    }

    init(_ error: Error) {
        switch error {
        case let error as BrainError: self = error
        case is DecodingError: self = .badOutput
        default: self = .network  // URLError and cancellation
        }
    }
}
