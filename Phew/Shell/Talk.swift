import Foundation

/// The two permissions talking needs (P6.1), as the system says now. Senses gives the real ones.
struct VoicePermissions: Equatable {
    enum State: Equatable { case granted, notAsked, refused }
    var microphone: State
    var speech: State

    static let granted = VoicePermissions(microphone: .granted, speech: .granted)
    var allGranted: Bool { microphone == .granted && speech == .granted }
}

/// Hold the shortcut to talk (P6.1 to P6.3, the owner's choices of 15 November). The hold takes the same single
/// capture as the shortcut and shows the ask panel listening; the release sends the words at once, with every
/// hearing; nothing said explains what is under the cursor (P6.2); Escape drops the capture and sends nothing.
/// What it does on screen goes through closures: the app delegate's real ones, fakes in tests.
/// Logs counts, languages, confidences and fixed words only: never a heard word.
@MainActor
final class Talk {
    /// What the ask panel shows during a hold.
    enum Look: Equatable {
        case listening
        /// The words so far, greyed in the field.
        case partial(String)
        /// One plain line in place of listening: the hold failed.
        case line(String)
        case closed
    }

    /// The recogniser. Nil until Senses' is merged: a hold is then a short press (the app delegate's choice).
    var listener: (any Listening)?
    /// Microphone and Speech Recognition now. Senses gives the real ones; until then both granted.
    var permissions: () -> VoicePermissions = { .granted }
    /// Names from the Map for the recogniser (`Brain.spokenNames`).
    var names: () async -> [String] = { [] }
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
    private final class Hold {
        var capture: Task<ContextPacket?, Never>?
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
        let names = names
        hold.started = Task {
            let context = Self.spokenContext(await capture?.value) + (await names())
            do {
                try await listener.start(context: context) { [weak self, weak hold] words in
                    guard let self, let hold, self.hold === hold else { return }
                    show(.partial(words))
                }
                return true
            } catch {
                guard self.hold === hold else { return false }  // Escape came first
                fail(error)
                return false
            }
        }
    }

    /// The release: the words go at once, no confirm.
    func holdEnd() {
        guard let hold, let started = hold.started else { return }
        self.hold = nil
        let capture = hold.capture
        hold.capture = nil
        Task {
            guard await started.value, let listener else { return closeLine() }
            let heard = await listener.stop()
            let hearings = heard.hearings
            if hearings.isEmpty {
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
        show(.closed)
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

    /// Words on screen for the recogniser: the app's name, the control under the pointer and the controls.
    // shortcut: Senses may give `packet.spokenContext`; at merge this body becomes that, if it exists.
    static func spokenContext(_ packet: ContextPacket?) -> [String] {
        guard let packet, !packet.neverRead else { return [] }
        var seen = Set<String>()
        return ([packet.appName, packet.cursor?.label ?? ""] + packet.pointables.map(\.label))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count <= 40 && seen.insert($0.lowercased()).inserted }
            .prefix(60).map { $0 }
    }
}
