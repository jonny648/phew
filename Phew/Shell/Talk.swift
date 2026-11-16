import Foundation

/// The permission talking needs (P6.1), as the system says now: the Microphone only. Apple's on-device analyzer
/// needs no Speech Recognition permission, so it is never asked (`ListenPermissions`).
struct VoicePermissions: Equatable {
    enum State: Equatable { case granted, notAsked, refused }
    var microphone: State

    static let granted = VoicePermissions(microphone: .granted)
    var allGranted: Bool { microphone == .granted }

    /// As the system says now.
    static var now: VoicePermissions {
        switch ListenPermissions.microphone {
        case .allowed: .granted
        case .notAsked: VoicePermissions(microphone: .notAsked)
        case .denied: VoicePermissions(microphone: .refused)
        }
    }
}

/// Hold the shortcut to talk (P6.1 to P6.3, the owner's choices of 15 November). The hold takes the same single
/// capture as the shortcut and shows him listening at the notch (`NotchListening`); the release sends the words at once, with every
/// hearing; nothing said explains what is under the cursor (P6.2); Escape drops the capture and sends nothing.
/// What it does on screen goes through closures: the app delegate's real ones, fakes in tests.
/// Logs counts, languages, confidences and fixed words only: never a heard word.
@MainActor
final class Talk {
    /// What the notch shows during a hold.
    enum Look: Equatable {
        case listening
        /// The words so far, greyed.
        case partial(String)
        /// How loud the voice is now, 0...1.
        case level(Double)
        /// One plain line in place of listening: the hold failed.
        case line(String)
        /// Released: the words are on their way.
        case sending
        /// Escape: nothing is sent.
        case cancelled
        case closed
    }

    /// The recogniser. Nil: a hold is a short press (the app delegate's choice).
    var listener: (any Listening)?
    /// The Microphone permission now.
    var permissions: () -> VoicePermissions = { .granted }
    /// Names from the Map for the recogniser (`Brain.spokenNames`).
    var names: () async -> [String] = { [] }
    /// Words heard before for those names, heard words to name (`Brain.heardAs`, N3.2).
    var heardAs: () async -> [String: String] = { [:] }
    /// The shortcut's single capture, taken with the card off screen.
    var capture: () -> Task<ContextPacket?, Never>? = { nil }
    var show: (Look) -> Void = { _ in }
    /// The ask path: the best hearing as the question (empty: explain what is under the cursor), every hearing, and
    /// the capture.
    var send: (String, [Hearing], Task<ContextPacket?, Never>?) -> Void = { _, _, _ in }
    /// A permission is missing: first run's two voice rows.
    var missing: () -> Void = {}
    /// How long the line of a failed hold stays after the release.
    var lineStays: Duration = .seconds(3)

    /// One hold. The capture lives here until it is sent or dropped.
    private final class Hold: @unchecked Sendable {
        var capture: Task<ContextPacket?, Never>?
        /// The words the recogniser was given and the words heard before for names, for the sound match (N3.1).
        /// Set once by the context, read after the listener started.
        var words: [String] = []
        var heardAs: [String: String] = [:]
        /// True when the listener started; false when it failed and the hold showed its line or the rows.
        var started: Task<Bool, Never>?
    }
    private var hold: Hold?

    /// A hold under way holds a capture (the tests check it goes).
    var holdsCapture: Bool { hold?.capture != nil }

    func holdStart() {
        guard let listener else { return }
        guard permissions().allGranted else {
            shellLog("talk: a voice permission is missing")
            return missing()
        }
        let hold = Hold()
        self.hold = hold
        let capture = capture()
        hold.capture = capture
        show(.listening)
        shellLog("talk: listening")
        let names = names, heardAs = heardAs
        // The microphone opens at once; the words on screen and the Map's names follow when the capture is read.
        let context: @Sendable () async -> [String] = { [hold] in
            async let named = names()
            async let before = heardAs()
            let packet = await capture?.value
            let known = await before
            // The words heard before go to the recogniser too (N3.2), after the names.
            let extra = await named + known.keys.sorted()
            let words = packet?.spokenContext(extra: extra) ?? ContextPacket.spokenWords(extra)
            hold.words = words
            hold.heardAs = known
            return words
        }
        hold.started = Task {
            do {
                try await listener.start(context: context, partial: { [weak self, weak hold] words in
                    guard let self, let hold, self.hold === hold else { return }
                    show(.partial(words))
                }, level: { [weak self, weak hold] level in
                    guard let self, let hold, self.hold === hold else { return }
                    show(.level(level))
                })
                return true
            } catch {
                guard self.hold === hold else { return false }  // Escape came first
                fail(error)
                return false
            }
        }
    }

    /// The release: names matched by sound (N3.1), then the words go at once, always (N3.7). An unsure hearing is held
    /// only after routing, on the card (`SendOrShow.held`).
    /// `atLimit`: the hold reached `HotKey.longestHold` with no release seen (R35). Listening stops the same way, and
    /// words heard still go; silence sends nothing, since nobody asked for the screen to be explained.
    func holdEnd(atLimit: Bool = false) {
        guard let hold, let started = hold.started else { return }
        self.hold = nil
        let capture = hold.capture
        hold.capture = nil
        Task {
            guard await started.value, let listener else { return closeLine() }
            show(atLimit ? .closed : .sending)  // the notch closes now; the words follow when the recognisers finish
            let hearings = NameMatch.apply(await listener.stop(), names: hold.words, heardAs: hold.heardAs).hearings
            if hearings.isEmpty {
                if atLimit { return shellLog("talk: hold reached its limit, nothing heard, nothing sent, capture dropped") }
                shellLog("talk: nothing heard, explaining what is under the cursor")
            } else {
                shellLog("talk: heard \(hearings.count) hearings, languages \(hearings.map { Spoken.code($0.language) }), confidences \(hearings.map { ($0.confidence * 100).rounded() / 100 }), best \(hearings[0].text.count) characters")
            }
            send(hearings.first?.text ?? "", hearings, capture)
        }
    }

    /// Escape during a hold: nothing is sent, the capture is dropped.
    func holdCancel() {
        guard let hold else { return }
        self.hold = nil
        hold.capture = nil
        show(.cancelled)
        shellLog("talk: cancelled, capture dropped")
        let started = hold.started, listener = listener
        Task {
            if await started?.value == true { await listener?.cancel() }
        }
    }

    private func fail(_ error: Error) {
        hold?.capture = nil
        let problem = error as? ListenProblem ?? .failed
        shellLog("talk: listening failed, \(Self.kind(problem))")
        switch problem {
        case .noMicrophone, .noSpeechPermission:
            show(.closed)
            missing()
        case .modelMissing(let language):
            show(.line(Self.modelMissing(language)))
        case .failed:
            show(.closed)
        }
    }

    /// After a failed hold: a line shown stays a moment past the release, then goes.
    private func closeLine() {
        Task {
            try? await Task.sleep(for: lineStays)
            if hold == nil { show(.closed) }
        }
    }

    /// A fixed word for the log.
    static func kind(_ problem: ListenProblem) -> String {
        switch problem {
        case .noMicrophone: "no microphone"
        case .noSpeechPermission: "no speech permission"
        case .modelMissing(let language): "model missing \(Spoken.code(language))"
        case .failed: "failed"
        }
    }

    static func modelMissing(_ language: String) -> String {
        let name = Locale(identifier: "en").localizedString(forLanguageCode: Spoken.code(language)) ?? language
        return "macOS is still getting the speech model for \(name). Try again in a minute."
    }
}
