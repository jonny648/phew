import AppKit
@testable import Phew

/// A made-up practice window inside the test process (docs/13-hand.md 13.6): the only real thing the Hand's tests
/// act on. Buttons, a text field, a secure field, a menu, "Pay now"/"Paga ora", "Sign in"/"Accedi", a button that
/// moves, one that raises a sheet, a slow one. Nothing in it is real content.
@MainActor
final class PracticeWindow: NSObject {
    static let names = ["Bold", "Pay now", "Paga ora", "Sign in", "Accedi", "Move me", "Open sheet", "Slow"]
    /// How long the slow button takes, on the main thread: under `Hand.timeout`, so a press is in flight, not refused.
    static let slow: TimeInterval = 0.3

    let window = NSWindow(contentRect: NSRect(x: 140, y: 160, width: 440, height: 300), styleMask: [.titled],
                          backing: .buffered, defer: false)
    let sheet = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 80), styleMask: [.titled],
                         backing: .buffered, defer: false)
    let field = NSTextField(frame: NSRect(x: 20, y: 200, width: 200, height: 24))
    let secret = NSSecureTextField(frame: NSRect(x: 20, y: 240, width: 200, height: 24))
    private(set) var buttons: [String: NSButton] = [:]
    private(set) var presses: [String: Int] = [:]
    private var savedMenu: NSMenu?

    override init() {
        super.init()
        window.title = "Practice"
        window.isReleasedWhenClosed = false
        for (i, name) in Self.names.enumerated() {
            let button = NSButton(title: name, target: self, action: #selector(pressed))
            button.frame = NSRect(x: 20 + (i % 2) * 210, y: 20 + (i / 2) * 40, width: 160, height: 30)
            window.contentView?.addSubview(button)
            buttons[name] = button
        }
        field.placeholderString = "Title"
        secret.placeholderString = "Secret"
        window.contentView?.addSubview(field)
        window.contentView?.addSubview(secret)
        // The menu: "Practice" > "Make Bold" and "Account" > "Sign In…", in the test process's own menu bar.
        savedMenu = NSApp.mainMenu
        let bar = NSMenu()
        bar.addItem(NSMenuItem())  // the first menu is always the app's own, shown under the app's name
        for (title, item) in [("Practice", "Make Bold"), ("Account", "Sign In…")] {
            let top = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            top.submenu = NSMenu(title: title)
            let entry = NSMenuItem(title: item, action: #selector(picked), keyEquivalent: "")
            entry.target = self
            top.submenu?.addItem(entry)
            bar.addItem(top)
        }
        NSApp.mainMenu = bar
        window.orderFrontRegardless()  // in front without making the test process the active app
    }

    func close() {
        if window.attachedSheet != nil { window.endSheet(sheet) }
        window.orderOut(nil)
        NSApp.mainMenu = savedMenu
    }

    @objc private func pressed(_ sender: NSButton) {
        presses[sender.title, default: 0] += 1
        if sender.title == "Slow" { Thread.sleep(forTimeInterval: Self.slow) }
        if sender.title == "Open sheet" { window.beginSheet(sheet) }
    }

    @objc private func picked(_ sender: NSMenuItem) { presses[sender.title, default: 0] += 1 }

    /// A view's frame in Accessibility coordinates (top-left origin of the main display), as the look reads it.
    func frame(_ view: NSView) -> CGRect {
        let r = window.convertToScreen(view.convert(view.bounds, to: nil))
        return CGRect(x: r.minX, y: (NSScreen.screens.first?.frame.height ?? 0) - r.maxY, width: r.width, height: r.height)
    }

    func press(_ name: String) -> HandStep {
        HandStep(kind: .press, pid: getpid(), role: "AXButton", name: name, frame: frame(buttons[name]!))
    }

    func set(_ text: String, secure: Bool = false) -> HandStep {
        let target = secure ? secret : field
        return HandStep(kind: .set, pid: getpid(), role: "AXTextField", name: target.placeholderString ?? "",
                        frame: frame(target), text: text)
    }
}
