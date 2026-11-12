import Foundation

/// The screenshot's size, and the size the model actually sees. The API downsizes images over the model's limits,
/// and the points the model returns are in the downsized image, so they are scaled back to screenshot pixels.
struct ScreenshotSize: Equatable {
    let width, height: Int
    let seenWidth, seenHeight: Int

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        (seenWidth, seenHeight) = Self.seen(width: width, height: height)
    }

    /// Reads the size from the PNG header; nil when the data is not a PNG.
    init?(png: Data) {
        let bytes = [UInt8](png.prefix(24))
        guard bytes.count == 24, bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]), Array(bytes[12..<16]) == Array("IHDR".utf8)
        else { return nil }
        func int(at i: Int) -> Int { bytes[i..<i + 4].reduce(0) { $0 << 8 | Int($1) } }
        self.init(width: int(at: 16), height: int(at: 20))
    }

    /// A point the model gave, in screenshot pixels; nil when it falls outside the screenshot.
    func pixel(x: Int, y: Int) -> (x: Int, y: Int)? {
        let px = Int((Double(x) * Double(width) / Double(seenWidth)).rounded())
        let py = Int((Double(y) * Double(height) / Double(seenHeight)).rounded())
        return (0..<width).contains(px) && (0..<height).contains(py) ? (px, py) : nil
    }

    /// The size the API downsizes an image to: the largest aspect-preserving size within the edge and visual-token
    /// limits (docs: vision-coordinates, reference implementation). Defaults are the high-resolution tier of
    /// Claude 4.7 and later, which holds the main model and its fallback.
    static func seen(width: Int, height: Int, maxEdge: Int = 2576, maxTokens: Int = 4784) -> (Int, Int) {
        func fits(_ w: Int, _ h: Int) -> Bool {
            let (cols, rows) = ((w + 27) / 28, (h + 27) / 28)
            return cols * 28 <= maxEdge && rows * 28 <= maxEdge && cols * rows <= maxTokens
        }
        if fits(width, height) { return (width, height) }
        if height > width {
            let (h, w) = seen(width: height, height: width, maxEdge: maxEdge, maxTokens: maxTokens)
            return (w, h)
        }
        let ratio = Double(width) / Double(height)
        func other(_ long: Int) -> Int { max(Int((Double(long) / ratio).rounded(.toNearestOrEven)), 1) }  // Python's round()
        var (lo, hi) = (1, width)  // lo always fits, hi never does
        while lo + 1 < hi {
            let mid = (lo + hi) / 2
            if fits(mid, other(mid)) { lo = mid } else { hi = mid }
        }
        return (lo, other(lo))
    }
}
