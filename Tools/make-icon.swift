// Draws Phew's app icon (docs/22-brand.md 22.6): the mark in shell white on ink, the mark 56% of the tile, in the
// macOS icon shape with the usual margins. Drawn from the path in Brand.swift itself, so the icon is the mark.
// Run from the repository root:
//   swiftc -parse-as-library -o /tmp/make-icon Tools/make-icon.swift Phew/Shell/Brand.swift Phew/Shell/Design.swift && /tmp/make-icon
import AppKit
import SwiftUI

@main
enum MakeIcon {
    static let out = URL(fileURLWithPath: "Phew/Assets.xcassets/AppIcon.appiconset")

    static func icon(_ px: Int) -> Data {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let context = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
        let s = CGFloat(px)
        // Apple's grid: a 1024 canvas holds an 824 tile, its corners continuous.
        let tile = CGRect(x: 0, y: 0, width: s, height: s).insetBy(dx: s * 100 / 1024, dy: s * 100 / 1024)
        context.addPath(RoundedRectangle(cornerRadius: tile.width * 0.225, style: .continuous).path(in: tile).cgPath)
        context.setFillColor(Design.Brand.ink.cgColor)
        context.fillPath()
        // The mark 56% of the tile, centred on its ink. Small sizes take the small mark (under 32 points of box).
        let ink = Brand.ink(Brand.mark)
        let k = tile.width * 0.56 / ink.width
        let mark = Brand.mark(small: Brand.box * k < Brand.fullFrom)
        context.translateBy(x: tile.midX, y: tile.midY)
        context.scaleBy(x: k, y: -k)  // the path is y down
        context.translateBy(x: -ink.midX, y: -ink.midY)
        context.addPath(mark)
        context.setLineWidth(Brand.line)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setStrokeColor(Design.Brand.shellWhite.cgColor)
        context.strokePath()
        return rep.representation(using: .png, properties: [:])!
    }

    static func main() throws {
        var images: [[String: String]] = []
        for (pt, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
            let name = "icon_\(pt)x\(pt)\(scale == 2 ? "@2x" : "").png"
            try icon(pt * scale).write(to: out.appendingPathComponent(name))
            images.append(["idiom": "mac", "size": "\(pt)x\(pt)", "scale": "\(scale)x", "filename": name])
        }
        let json = try JSONSerialization.data(withJSONObject: ["images": images, "info": ["version": 1, "author": "xcode"]],
                                              options: [.prettyPrinted, .sortedKeys])
        try json.write(to: out.appendingPathComponent("Contents.json"))
    }
}
