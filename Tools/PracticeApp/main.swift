// A made-up practice app for PH.5's live check: a window in another process for Phew's Hand to act on, since the
// Hand never acts on Phew's own windows. Not part of the Xcode project. Build and run:
//   swiftc -o <dir>/PracticeApp.app/Contents/MacOS/PracticeApp Tools/PracticeApp/main.swift
//   cp Tools/PracticeApp/Info.plist <dir>/PracticeApp.app/Contents/ && open -n <dir>/PracticeApp.app --args <state.json> "Phew test 4821"
// Then: Phew --debug-act "Type Weekly plan in the Title field, press Bold, tick Done, choose Format > Make Italic
// from the menu bar, then press Save." --test-window "Phew test 4821". The second argument is the window's title, the
// made-up marker the live check looks for (PH.10). Every change writes the window's state, made-up only, to <state.json>.
// PH.7 (several apps in one job): a second copy, the same binary with InfoTwo.plist (bundle id
// com.example.phew-practice-two, "Practice Two"), titled "Phew test 4821 B"; Phew's debug build may open it by name.
// PH.11 (a click at a point): the canvas below the controls has no accessibility children, only four drawn shapes,
// and records where it was clicked.
import AppKit

/// Four drawn targets and nothing Accessibility can name. Flipped: y runs down, as in the screenshot.
final class Canvas: NSView {
    /// Name, centre, and the drawn letter. Every shape is 44 points across.
    static let targets: [(name: String, centre: CGPoint, letter: String, color: NSColor)] = [
        ("red circle", CGPoint(x: 60, y: 55), "A", .systemRed),
        ("blue square", CGPoint(x: 310, y: 60), "B", .systemBlue),
        ("green triangle", CGPoint(x: 90, y: 160), "C", .systemGreen),
        ("purple diamond", CGPoint(x: 280, y: 165), "D", .systemPurple),
    ]
    var clicks: [CGPoint] = []
    var onClick: () -> Void = {}

    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    static func path(_ i: Int) -> NSBezierPath {
        let c = targets[i].centre, r: CGFloat = 22
        switch i {
        case 0: return NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        case 1: return NSBezierPath(rect: NSRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        default:
            let p = NSBezierPath()
            let points = i == 2 ? [CGPoint(x: c.x, y: c.y - r), CGPoint(x: c.x + r, y: c.y + r), CGPoint(x: c.x - r, y: c.y + r)]
                                : [CGPoint(x: c.x, y: c.y - r), CGPoint(x: c.x + r, y: c.y), CGPoint(x: c.x, y: c.y + r), CGPoint(x: c.x - r, y: c.y)]
            p.move(to: points[0])
            points.dropFirst().forEach(p.line)
            p.close()
            return p
        }
    }

    /// The target a point lies in, or nil.
    static func hit(_ p: CGPoint) -> String? { targets.indices.first { path($0).contains(p) }.map { targets[$0].name } }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        bounds.fill()
        NSColor.gray.setStroke()
        NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5)).stroke()
        let font = NSFont.boldSystemFont(ofSize: 15)
        for (i, t) in Self.targets.enumerated() {
            t.color.setFill()
            Self.path(i).fill()
            let letter = NSAttributedString(string: t.letter, attributes: [.font: font, .foregroundColor: NSColor.white])
            let size = letter.size()
            letter.draw(at: CGPoint(x: t.centre.x - size.width / 2, y: t.centre.y - size.height / 2 + (i == 2 ? 6 : 0)))
        }
        // The last click, as a small black dot, so a look after it can see it landed.
        if let last = clicks.last {
            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: last.x - 3, y: last.y - 3, width: 6, height: 6)).fill()
        }
    }

    override func mouseDown(with event: NSEvent) {
        clicks.append(convert(event.locationInWindow, from: nil))
        needsDisplay = true
        onClick()
    }
}

final class Practice: NSObject, NSApplicationDelegate {
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 440), styleMask: [.titled, .closable],
                          backing: .buffered, defer: false)
    let field = NSTextField(frame: NSRect(x: 20, y: 380, width: 260, height: 24))
    let done = NSButton(checkboxWithTitle: "Done", target: nil, action: nil)
    let canvas = Canvas(frame: NSRect(x: 20, y: 20, width: 380, height: 220))
    let state = CommandLine.arguments.dropFirst().first.map { URL(filePath: $0) }
    var counts: [String: Int] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        window.title = CommandLine.arguments.dropFirst(2).first ?? "Practice"
        field.placeholderString = "Title"
        field.target = self
        field.action = #selector(changed)
        window.contentView?.addSubview(field)
        for (i, name) in ["Bold", "Save"].enumerated() {
            let button = NSButton(title: name, target: self, action: #selector(pressed))
            button.frame = NSRect(x: 20 + i * 140, y: 320, width: 120, height: 30)
            window.contentView?.addSubview(button)
        }
        done.target = self
        done.action = #selector(pressed)
        done.frame = NSRect(x: 20, y: 280, width: 120, height: 24)
        window.contentView?.addSubview(done)
        canvas.onClick = { [weak self] in self?.save() }
        window.contentView?.addSubview(canvas)
        let bar = NSMenu(), app = NSMenuItem(), format = NSMenuItem(title: "Format", action: nil, keyEquivalent: "")
        app.submenu = NSMenu()
        app.submenu?.addItem(NSMenuItem(title: "Quit Practice", action: #selector(NSApplication.terminate), keyEquivalent: "q"))
        format.submenu = NSMenu(title: "Format")
        let italic = NSMenuItem(title: "Make Italic", action: #selector(picked), keyEquivalent: "")
        italic.target = self
        format.submenu?.addItem(italic)
        bar.addItem(app)
        bar.addItem(format)
        NSApp.mainMenu = bar
        window.center()
        // The second copy sits lower right, so both windows show whole.
        if Bundle.main.bundleIdentifier?.hasSuffix("-two") == true { window.setFrameOrigin(NSPoint(x: window.frame.minX + 240, y: window.frame.minY - 120)) }
        // On screen even while the user works in a full-screen app on another Space: the live check looks at it there.
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        NotificationCenter.default.addObserver(self, selector: #selector(changed), name: NSControl.textDidChangeNotification, object: field)
        // Every left mouse down the app receives, and whether AppKit gave it a window: shows whether a posted click
        // reached the app at all.
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.counts[event.window == nil ? "mouse down, no window" : "mouse down", default: 0] += 1
            let hit = event.window?.contentView?.hitTest(event.locationInWindow).map { "\(type(of: $0))" } ?? "nothing"
            self?.counts["at \(Int(event.locationInWindow.x)),\(Int(event.locationInWindow.y)) on \(hit) key \(event.window?.isKeyWindow ?? false)", default: 0] += 1
            self?.save()
            return event
        }
        save()
    }

    @objc func pressed(_ sender: NSButton) {
        counts[sender.title, default: 0] += 1
        if sender.title == "Bold" { field.font = .boldSystemFont(ofSize: 13) }
        save()
    }

    @objc func picked(_ sender: NSMenuItem) {
        counts[sender.title, default: 0] += 1
        field.font = NSFontManager.shared.convert(field.font ?? .systemFont(ofSize: 13), toHaveTrait: .italicFontMask)
        save()
    }

    @objc func changed() { save() }

    func save() {
        // Canvas clicks in canvas points (y down), with the target each landed in, if any.
        let clicks = canvas.clicks.map { ["x": $0.x, "y": $0.y, "hit": Canvas.hit($0) ?? "none"] as [String: Any] }
        let object: [String: Any] = ["title": field.stringValue, "done": done.state == .on, "counts": counts, "canvas": clicks]
        if let state, let data = try? JSONSerialization.data(withJSONObject: object, options: .sortedKeys) { try? data.write(to: state) }
    }
}

let delegate = Practice()
NSApplication.shared.delegate = delegate
NSApp.setActivationPolicy(.regular)
NSApp.run()
