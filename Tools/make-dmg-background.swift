// Draws the background of the installer window: 640 x 400 points, at 1x and 2x. Run by Tools/make-dmg.sh.
import AppKit

let dir = URL(fileURLWithPath: CommandLine.arguments[1])
func draw(_ scale: CGFloat) -> Data {
    let w = 640 * scale, h = 400 * scale
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(w), pixelsHigh: Int(h), bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let all = NSRect(x: 0, y: 0, width: w, height: h)
    NSGradient(starting: NSColor(white: 0.13, alpha: 1), ending: NSColor(white: 0.05, alpha: 1))!.draw(in: all, angle: -90)
    // A soft glow of his colour behind where the app's icon sits (left), in Finder's coordinates the icon is at (170, 200).
    let orange = NSColor(red: 0xF2 / 255, green: 0x54 / 255, blue: 0x1B / 255, alpha: 1)
    NSGradient(colors: [orange.withAlphaComponent(0.22), orange.withAlphaComponent(0)])!
        .draw(fromCenter: NSPoint(x: 170 * scale, y: 200 * scale), radius: 0, toCenter: NSPoint(x: 170 * scale, y: 200 * scale), radius: 190 * scale)
    func text(_ s: String, _ size: CGFloat, _ weight: NSFont.Weight, _ white: CGFloat, y: CGFloat) {
        let style = NSMutableParagraphStyle(); style.alignment = .center
        NSAttributedString(string: s, attributes: [.font: NSFont.systemFont(ofSize: size * scale, weight: weight),
                                                   .foregroundColor: NSColor(white: 1, alpha: white), .paragraphStyle: style])
            .draw(in: NSRect(x: 0, y: y * scale, width: w, height: (size + 10) * scale))
    }
    text("Phew!", 30, .semibold, 0.95, y: 322)
    text("Drag him to Applications", 14, .regular, 0.55, y: 296)
    text("Then call him with Right Option + Right Command", 12, .regular, 0.35, y: 36)
    // The arrow between the two icons.
    let arrow = NSBezierPath(); let y = 200 * scale
    arrow.move(to: NSPoint(x: 268 * scale, y: y)); arrow.line(to: NSPoint(x: 366 * scale, y: y))
    arrow.move(to: NSPoint(x: 352 * scale, y: y + 12 * scale)); arrow.line(to: NSPoint(x: 368 * scale, y: y)); arrow.line(to: NSPoint(x: 352 * scale, y: y - 12 * scale))
    arrow.lineWidth = 3 * scale; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round
    orange.withAlphaComponent(0.9).setStroke(); arrow.stroke()
    NSGraphicsContext.current = nil
    return rep.representation(using: .png, properties: [:])!
}
try draw(1).write(to: dir.appendingPathComponent("background.png"))
try draw(2).write(to: dir.appendingPathComponent("background@2x.png"))
