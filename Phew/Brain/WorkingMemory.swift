import Foundation

/// The working memory (`docs/05-map.md` 5.8): the last 3 questions and answers, as text only, so a follow-up
/// question is understood. Never a screen text or a picture: a follow-up takes a fresh look. In memory only.
/// Dropped 5 minutes after the last answer, and on Quit.
final class WorkingMemory: @unchecked Sendable {
    static let maxTurns = 3
    static let lifetime: TimeInterval = 5 * 60

    private let lock = NSLock()
    private var kept: [Turn] = []
    private var lastAnswer = Date.distantPast
    private let now: @Sendable () -> Date

    init(now: @escaping @Sendable () -> Date = { Date() }) { self.now = now }

    /// The kept turns, oldest first. Empty once 5 minutes have passed since the last answer.
    var turns: [Turn] {
        lock.withLock {
            dropIfOld()
            return kept
        }
    }

    func add(_ turn: Turn) {
        lock.withLock {
            dropIfOld()
            kept = Array((kept + [turn]).suffix(Self.maxTurns))
            lastAnswer = now()
        }
        // Drops the turns on time even when no question follows.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.lifetime))
            guard let self else { return }
            lock.withLock { self.dropIfOld() }
        }
    }

    /// Drops every turn. The Shell calls it on Quit, through `Brain.forgetTurns()`.
    func clear() {
        lock.withLock { kept = [] }
    }

    private func dropIfOld() {
        if now().timeIntervalSince(lastAnswer) >= Self.lifetime { kept = [] }
    }
}
