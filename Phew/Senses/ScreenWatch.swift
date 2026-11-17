import AppKit
import ScreenCaptureKit

/// The screen watch during a guide, and only then (docs/04-architecture.md 4.6): it tells when the screen has settled
/// and whether it changed since the last look. It starts when a guide's steps are shown and stops as soon as following
/// stops, or after `idleLimit` without an action from the user; an action starts it again. It never calls the model:
/// a look is still made only after the user acts.
/// Each display is streamed small and slow, with Phew's own windows and the mouse pointer left out. Of a frame only a
/// copy of its pixels is kept, in memory: the latest per display, and the one at the last look. `stop` drops them.
/// Nothing of it is written to disk or to a log.
final class ScreenWatch: NSObject, SCStreamOutput, SCStreamDelegate {
    static let shared = ScreenWatch()
    /// Two minutes without an action stop the watch (decided 14 November). The debug check shortens it.
    static var idleLimit: TimeInterval = 120
    /// Frames per second at most, and points per pixel: enough to see a ticked box or a typed letter, little work.
    static let fps: Int32 = 10
    static let scale = 2

    private(set) var running = false
    private var lastAction = Date.distantPast
    /// Counts starts and stops, so a stream that was still starting when the watch stopped is not kept.
    private var generation = 0
    private var streams: [SCStream] = []
    private var idleTask: Task<Void, Never>?
    private let lock = NSLock()
    /// Under `lock`: the stream queue writes it.
    private var frames = WatchFrames()
    private let queue = DispatchQueue(label: "Phew.ScreenWatch")
    private let screen: Bool
    private let list: NeverReadList
    /// The front app's bundle id, read at each start.
    private let front: () -> String?
    #if DEBUG
    /// The guide check's follow cases: every look goes ahead, as before the watch.
    var seesEveryChange = false
    #endif

    /// `screen` false streams nothing (tests): no change can be seen, so every look goes ahead.
    init(screen: Bool = true, list: NeverReadList = .shared,
         front: @escaping () -> String? = { NSWorkspace.shared.frontmostApplication?.bundleIdentifier }) {
        self.screen = screen
        self.list = list
        self.front = front
    }

    /// `markFirst`: the first frames are what the first look is compared with (a guide's start). After an idle stop
    /// the action came before any frame, so there is nothing to compare with and the next look goes ahead.
    func start(markFirst: Bool) {
        guard !running else { return }
        // Never while an app on the never-read list is in front; an action in another app starts it again.
        guard !list.refuses(front()) else { return shellLog("watch: not started, front app on the never-read list") }
        running = true
        generation += 1
        lastAction = Date()
        lock.withLock { frames.open(markFirst: markFirst) }
        shellLog("watch started")
        idleTask = Task { @MainActor [weak self] in
            while let left = self?.checkIdle(at: Date()) { try? await Task.sleep(for: .seconds(left)) }
        }
        guard screen, CGPreflightScreenCaptureAccess() else {
            lock.withLock { frames.blind = true }
            return shellLog("watch: no screen recording, every look goes ahead")
        }
        let started = generation
        Task { @MainActor [weak self] in
            let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let self, generation == started else { return }
            guard let content, !content.displays.isEmpty else { return blind("no display to watch") }
            // Phew's windows, and every never-read app's: the watch does not see them even when they come in front.
            // shortcut: an app on the list launched after the watch started is seen until the next start; update the filter if that matters.
            // The same apps the whole-display picture leaves out (R1): the password managers and terminals too.
            // The app the guide is in stays seen, as in the picture.
            let frontPid = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
            let hidden = content.applications.filter {
                ScreenCapture.hides(pid: $0.processID, bundleID: $0.bundleIdentifier, front: frontPid, list: self.list)
            }
            for display in content.displays {
                let config = SCStreamConfiguration()
                config.width = max(display.width / Self.scale, 1)
                config.height = max(display.height / Self.scale, 1)
                config.minimumFrameInterval = CMTime(value: 1, timescale: Self.fps)
                config.showsCursor = false
                config.queueDepth = 3
                config.pixelFormat = kCVPixelFormatType_32BGRA
                let filter = SCContentFilter(display: display, excludingApplications: hidden, exceptingWindows: [])
                let stream = SCStream(filter: filter, configuration: config, delegate: self)
                do {
                    try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
                    try await stream.startCapture()
                } catch {
                    blind("a display stream did not start")
                    continue
                }
                guard generation == started else {
                    try? await stream.stopCapture()
                    return
                }
                streams.append(stream)
            }
        }
    }

    /// Following stopped, or two minutes passed without an action. The frames are dropped.
    func stop(_ why: String) {
        guard running else { return }
        running = false
        generation += 1
        idleTask?.cancel()
        idleTask = nil
        streams.forEach { $0.stopCapture { _ in } }
        streams = []
        lock.withLock { frames = WatchFrames() }
        shellLog("watch stopped: \(why)")
    }

    /// The user acted: the two minutes start again, and a stopped watch starts again.
    func acted(at now: Date = Date()) {
        if running { lock.withLock { frames.actionSeen() } } else { start(markFirst: false) }
        lastAction = now
    }

    /// Stops the watch once the user has not acted for `idleLimit`; else returns the time left. Nil once stopped.
    @discardableResult
    func checkIdle(at now: Date) -> TimeInterval? {
        guard running else { return nil }
        let left = lastAction.addingTimeInterval(Self.idleLimit).timeIntervalSince(now)
        guard left > 0 else {
            stop("idle, no action for \(Int(Self.idleLimit)) s")
            return nil
        }
        return left
    }

    func settled(at now: Date) -> Bool { lock.withLock { frames.settled(at: now) } }

    /// Whether the screen differs from the last look (or the guide's start). True when it cannot be known.
    func changed() -> Bool {
        #if DEBUG
        if seesEveryChange { return true }
        #endif
        return lock.withLock { frames.changed }
    }

    /// A look starts: what it sees is what the next one is compared with.
    func mark() { lock.withLock { frames.mark() } }

    /// Whether any frame is held. False whenever the watch is stopped.
    var holdsFrames: Bool { lock.withLock { !frames.isEmpty } }

    /// One frame's pixels from one display's stream.
    func receive(_ pixels: [UInt8], from display: ObjectIdentifier, at now: Date) {
        lock.withLock { frames.add(pixels, from: display, at: now) }
    }

    private func blind(_ why: String) {
        lock.withLock { frames.blind = true }
        shellLog("watch: \(why), every look goes ahead")
    }

    // MARK: - Streams

    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
        // Only new frames: an idle one means nothing changed.
        let info = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]]
        guard type == .screen, (info?.first?[.status] as? Int).flatMap(SCFrameStatus.init) == .complete,
              let image = buffer.imageBuffer, let pixels = Self.pixels(of: image) else { return }
        receive(pixels, from: ObjectIdentifier(stream), at: Date())
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { self.blind("a display stream stopped") }
    }

    /// A copy of the frame's pixels, row padding left out. The frame itself is let go when the callback returns.
    private static func pixels(of image: CVPixelBuffer) -> [UInt8]? {
        CVPixelBufferLockBaseAddress(image, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(image, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(image) else { return nil }
        let width = CVPixelBufferGetWidth(image) * 4, height = CVPixelBufferGetHeight(image)
        let row = CVPixelBufferGetBytesPerRow(image)
        var out = [UInt8](repeating: 0, count: width * height)
        out.withUnsafeMutableBytes { copy in
            for y in 0..<height { (copy.baseAddress! + y * width).copyMemory(from: base + y * row, byteCount: width) }
        }
        return out
    }
}

/// The watch's frames and what they tell. Pure, so its rules are unit-tested with made-up pixels.
struct WatchFrames {
    /// How long the screen must stay the same to count as settled.
    static let calm: TimeInterval = 0.3

    /// A stream failed or none could start: a change cannot be seen, so every look goes ahead.
    var blind = false
    private var isOpen = false
    /// The first frame of each display is kept for the first look, until the user acts.
    private var marking = false
    private var latest: [ObjectIdentifier: [UInt8]] = [:]
    private var reference: [ObjectIdentifier: [UInt8]] = [:]
    private var lastChange = Date.distantPast

    var isEmpty: Bool { latest.isEmpty && reference.isEmpty }

    mutating func open(markFirst: Bool) {
        self = WatchFrames()
        isOpen = true
        marking = markFirst
    }

    /// A frame that comes after the user acted shows their action: it must not become the reference.
    mutating func actionSeen() { marking = false }

    mutating func add(_ pixels: [UInt8], from display: ObjectIdentifier, at now: Date) {
        guard isOpen else { return }
        if let last = latest[display], last != pixels { lastChange = now }
        latest[display] = pixels
        if marking && reference[display] == nil { reference[display] = pixels }
    }

    func settled(at now: Date) -> Bool { now.timeIntervalSince(lastChange) >= Self.calm }

    /// Exact comparison: the same screen gives the same pixels. True when there is nothing to compare.
    var changed: Bool { blind || latest.isEmpty || latest.contains { reference[$0.key] != $0.value } }

    mutating func mark() {
        reference = latest
        marking = false
    }
}
