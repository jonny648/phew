// A made-up practice app for PH.5's live check: a window in another process for Phew's Hand to act on, since the
// Hand never acts on Phew's own windows. Not part of the Xcode project. Build and run:
//   swiftc -o <dir>/PracticeApp.app/Contents/MacOS/PracticeApp Tools/PracticeApp/main.swift
//   cp Tools/PracticeApp/Info.plist <dir>/PracticeApp.app/Contents/ && open -n <dir>/PracticeApp.app --args <state.json>
// Then: Phew --debug-act "Type Weekly plan in the Title field, press Bold, tick Done, choose Format > Make Italic
// from the menu bar, then press Save." Every change writes the window's state, made-up only, to <state.json>.
import AppKit

final class Practice: NSObject, NSApplicationDelegate {
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 220), styleMask: [.titled, .closable],
                          backing: .buffered, defer: false)
    let field = NSTextField(frame: NSRect(x: 20, y: 160, width: 260, height: 24))
    let done = NSButton(checkboxWithTitle: "Done", target: nil, action: nil)
    let state = CommandLine.arguments.dropFirst().first.map { URL(filePath: $0) }
    var counts: [String: Int] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        window.title = "Practice"
        field.placeholderString = "Title"
        field.target = self
        field.action = #selector(changed)
        window.contentView?.addSubview(field)
        for (i, name) in ["Bold", "Save"].enumerated() {
            let button = NSButton(title: name, target: self, action: #selector(pressed))
            button.frame = NSRect(x: 20 + i * 140, y: 100, width: 120, height: 30)
            window.contentView?.addSubview(button)
        }
        done.target = self
        done.action = #selector(pressed)
        done.frame = NSRect(x: 20, y: 60, width: 120, height: 24)
        window.contentView?.addSubview(done)
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
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        NotificationCenter.default.addObserver(self, selector: #selector(changed), name: NSControl.textDidChangeNotification, object: field)
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
        let object: [String: Any] = ["title": field.stringValue, "done": done.state == .on, "counts": counts]
        if let state, let data = try? JSONSerialization.data(withJSONObject: object, options: .sortedKeys) { try? data.write(to: state) }
    }
}

let delegate = Practice()
NSApplication.shared.delegate = delegate
NSApp.setActivationPolicy(.regular)
NSApp.run()
