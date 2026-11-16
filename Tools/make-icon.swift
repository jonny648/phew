// Draws Phew's app icon: his orange presence dot on a near-black rounded square. Run: swift Tools/make-icon.swift
import AppKit

let out = URL(fileURLWithPath: "Phew/Assets.xcassets/AppIcon.appiconset")
func icon(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px), inset = s * 0.1  // Apple's icon grid: the shape sits inside a margin
    let box = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let shape = NSBezierPath(roundedRect: box, xRadius: box.width * 0.225, yRadius: box.width * 0.225)
    NSGradient(starting: NSColor(white: 0.16, alpha: 1), ending: NSColor(white: 0.05, alpha: 1))!.draw(in: shape, angle: -90)
    let d = box.width * 0.34
    let dot = NSRect(x: box.midX - d / 2, y: box.midY - d / 2, width: d, height: d)
    NSColor(red: 1, green: 0.42, blue: 0.21, alpha: 0.28).setFill()
    NSBezierPath(ovalIn: dot.insetBy(dx: -d * 0.22, dy: -d * 0.22)).fill()  // a soft halo, as when he breathes
    NSColor(red: 0xF2 / 255, green: 0x54 / 255, blue: 0x1B / 255, alpha: 1).setFill()
    NSBezierPath(ovalIn: dot).fill()
    NSGraphicsContext.current = nil
    return rep.representation(using: .png, properties: [:])!
}
var images: [[String: String]] = []
for (pt, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    let name = "icon_\(pt)x\(pt)\(scale == 2 ? "@2x" : "").png"
    try icon(pt * scale).write(to: out.appendingPathComponent(name))
    images.append(["idiom": "mac", "size": "\(pt)x\(pt)", "scale": "\(scale)x", "filename": name])
}
let json = try JSONSerialization.data(withJSONObject: ["images": images, "info": ["version": 1, "author": "xcode"]], options: [.prettyPrinted, .sortedKeys])
try json.write(to: out.appendingPathComponent("Contents.json"))
