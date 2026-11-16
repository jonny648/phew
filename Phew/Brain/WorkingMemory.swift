import Foundation

/// The working memory (`docs/05-map.md` 5.8, `docs/03-experience.md` 3.10): the conversation in the card, at most its
/// last 8 questions and answers, as text only. Older turns are dropped, not summarised. Never a screen text or a picture:
/// every reply takes a fresh look. In memory only. Dropped when the card closes (`Brain.forgetTurns()`), 10 minutes
/// after the last answer with no reply, and on Quit.
final class WorkingMemory: @unchecked Sendable {
    static let maxTurns = 8
    static let lifetime: TimeInterval = 10 * 60

    private let lock = NSLock()
    private var kept: [Turn] = []
    private var lastAnswer = Date.distantPast
    private let now: @Sendable () -> Date

    init(now: @escaping @Sendable () -> Date = { Date() }) { self.now = now }

    /// The kept turns, oldest first. Empty once 10 minutes have passed since the last answer.
    var turns: [Turn] {
        lock.withLock {
            dropIfOld()
            return kept
        }
    }

    func add(_ turn: Turn) {
        lock.withLock {
            dropIfOld()
            // R48: past the cap, the oldest go in one block, so the first turn sent stays the same for the next
            // replies and the cache of earlier turns is read, not written again on every reply.
            kept = kept.count < Self.maxTurns ? kept + [turn] : Array((kept + [turn]).suffix(Self.maxTurns / 2))
            lastAnswer = now()
        }
        // Drops the turns on time even when no question follows.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.lifetime))
            guard let self else { return }
            lock.withLock { self.dropIfOld() }
        }
    }

    /// Drops every turn. The Shell calls it when the card closes and on Quit, through `Brain.forgetTurns()`.
    func clear() {
        lock.withLock { kept = [] }
    }

    private func dropIfOld() {
        if now().timeIntervalSince(lastAnswer) >= Self.lifetime { kept = [] }
    }
}
