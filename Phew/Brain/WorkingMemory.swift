import Foundation

/// The working memory (`docs/05-map.md` 5.8, `docs/03-experience.md` 3.10): the conversation in the card, at most its
/// last 8 questions and answers, as text only. Older turns are dropped, not summarised. In memory only. Dropped when the
/// card closes (`Brain.forgetTurns()`), 10 minutes after the last answer with no reply, and on Quit.
/// D3: beside the turns, the capture of the previous turn (the earlier screen) for at most 10 minutes from when it was
/// taken, and the whole conversation as text with its saved thread's id, for the thread in the Map (5.8.1).
final class WorkingMemory: @unchecked Sendable {
    static let maxTurns = 8
    static let lifetime: TimeInterval = 10 * 60

    private let lock = NSLock()
    private var kept: [Turn] = []
    private var lastAnswer = Date.distantPast
    let now: @Sendable () -> Date
    /// How long the earlier capture is kept; tests shorten it to see the timer drop it.
    let captureLifetime: TimeInterval
    /// D3: the previous turn's capture, its picture and text; never a history, never written anywhere.
    private var capture: (packet: ContextPacket, taken: Date)?
    /// Every turn of this conversation, text only, for its saved thread (5.8.1); at most `Thread.maxTurns`.
    private var whole: [Turn] = []
    /// The saved thread this conversation writes to, and the Project code detected for it.
    private var threadID: Int64?
    private var project: Int64?
    /// Changes whenever the conversation ends, so a save that finishes after the end cannot hand its id to the next one.
    private var generation = 0

    init(now: @escaping @Sendable () -> Date = { Date() }, captureLifetime: TimeInterval = lifetime) {
        self.now = now
        self.captureLifetime = captureLifetime
    }

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
            whole = Array((whole + [turn]).suffix(MapThreads.maxTurns))
            lastAnswer = now()
        }
        // Drops the turns on time even when no question follows.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.lifetime))
            guard let self else { return }
            lock.withLock { self.dropIfOld() }
        }
    }

    /// Drops every turn, the earlier capture and the thread's id. The Shell calls it when the card closes and on Quit,
    /// through `Brain.forgetTurns()`; a forget on the remember route too. The thread already saved stays in the Map.
    func clear() {
        lock.withLock { reset() }
    }

    // MARK: The earlier screen (D3)

    /// Keeps `packet` as the earlier screen for the next reply, in place of the one before. Its labels, text and
    /// picture only: no element list, no menus, no full-size pixels. Nil, or an app never read: none is kept.
    func keepCapture(_ packet: ContextPacket?, taken: Date) {
        let kept = packet.flatMap { p -> ContextPacket? in
            guard !p.neverRead else { return nil }
            var p = p
            p.pointables = []; p.cursor = nil; p.menus = ""; p.image = nil
            return p
        }
        lock.withLock { capture = kept.map { ($0, taken) } }
        guard kept != nil else { return }
        // A timer, not only a check on the next reply: gone 10 minutes after it was taken, with or without a reply.
        let wait = max(0, captureLifetime - now().timeIntervalSince(taken)) + 0.01
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(wait))
            self?.lock.withLock { self?.dropOldCapture() }
        }
    }

    /// The earlier screen for a reply, when it is younger than 10 minutes and its app is not refused now; a refused
    /// one is dropped. Nil otherwise.
    func earlierCapture(refusing refuses: (String) -> Bool) -> ContextPacket? {
        lock.withLock {
            dropIfOld()
            dropOldCapture()
            if let bundleID = capture?.packet.bundleID, refuses(bundleID) { capture = nil }
            return capture?.packet
        }
    }

    /// For tests: whether a capture is held now, without dropping anything.
    var holdsCapture: Bool { lock.withLock { capture != nil } }

    // MARK: The saved thread (5.8.1)

    /// The whole conversation for its saved thread: its id when it has one, every turn, its Project, and which
    /// conversation it is (for `saved`).
    var conversation: (id: Int64?, turns: [Turn], project: Int64?, generation: Int) {
        lock.withLock { (threadID, whole, project, generation) }
    }

    /// The first Project found for this conversation stays its Project.
    func setProject(_ id: Int64) { lock.withLock { if project == nil { project = id } } }

    var hasProject: Bool { lock.withLock { project != nil } }

    /// The thread was written as `id`; kept only while the same conversation goes on.
    func saved(as id: Int64, generation: Int) { lock.withLock { if generation == self.generation { threadID = id } } }

    /// A saved thread opened again: its turns become the conversation, so a reply continues it. Sent as the working
    /// memory's own limits allow: all of 8 or fewer, else the last 4.
    func resume(id: Int64, turns: [Turn], project: Int64?) {
        lock.withLock {
            reset()
            whole = turns
            kept = turns.count <= Self.maxTurns ? turns : Array(turns.suffix(Self.maxTurns / 2))
            threadID = id
            self.project = project
            lastAnswer = now()
        }
    }

    // MARK: Private, under the lock

    private func reset() {
        if !kept.isEmpty || !whole.isEmpty || threadID != nil { generation += 1 }
        kept = []; whole = []; capture = nil; threadID = nil; project = nil
    }

    private func dropIfOld() {
        if now().timeIntervalSince(lastAnswer) >= Self.lifetime { reset() }
    }

    private func dropOldCapture() {
        if let taken = capture?.taken, now().timeIntervalSince(taken) >= captureLifetime { capture = nil }
    }
}
