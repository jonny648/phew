import AppKit
import ApplicationServices
import os

/// Reads the front app through the Accessibility API, only when called.
/// Coordinates are Accessibility ones: screen points, top-left origin of the main display.
enum WindowReader {
    /// One piece of visible text, with its frame for trimming by distance to the cursor.
    struct Text {
        var string: String
        var frame: CGRect?
    }

    // Hard limits, so a huge or hung app cannot stall Phew.
    // shortcut: the walk runs in reading order, so a limit cuts the end of the window, not the text farthest
    // from the cursor; walk the cursor's branch first if big apps (Notion, InDesign) hit the limits.
    static let maxElements = 3000
    static let maxDepth = 60
    static let timeBudget: TimeInterval = 0.8

    /// The element under the mouse, read synchronously: it must be the user's app, not Phew's panel.
    /// Also returns the mouse point.
    static func elementUnderCursor() -> (element: CursorElement?, point: CGPoint) {
        let systemWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(systemWide, 0.1)  // global for Phew: a hung app costs at most 0.1 s per call
        let mouse = NSEvent.mouseLocation  // bottom-left origin; flip against the main display
        let point = CGPoint(x: mouse.x, y: (NSScreen.screens.first?.frame.height ?? 0) - mouse.y)
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &hit) == .success,
              let element = hit else { return (nil, point) }
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        guard pid != getpid() else { return (nil, point) }

        let a = attributes(element)
        // Password field: its frame lets Phew point at it; nothing else is read.
        if a.isSecure { return (CursorElement(role: "AXSecureTextField", label: "", value: "", frame: a.frame), point) }
        // Whole documents and pages: their visible part is already in the window text.
        let value = ["AXTextArea", "AXWebArea"].contains(a.role) ? nil : valueString(element)
        return (CursorElement(role: a.role, label: a.title ?? a.description ?? "",
                              value: String((value ?? "").prefix(300)), frame: a.frame), point)
    }

    /// Focused window of the app (else main, else frontmost): title, frame, and its visible text in reading order.
    static func readWindow(pid: pid_t) -> (title: String, frame: CGRect?, texts: [Text]) {
        let app = AXUIElementCreateApplication(pid)
        guard let window = element(app, kAXFocusedWindowAttribute) ?? element(app, kAXMainWindowAttribute)
                ?? (attribute(app, kAXWindowsAttribute) as? [AXUIElement])?.first else {
            return ("", nil, [])
        }
        let root = attributes(window)
        let deadline = Date() + timeBudget
        var texts: [Text] = []
        var seen: Set<String> = [root.title ?? ""]  // repeats add nothing: links and their label, list rows
        var count = 0

        func visit(_ el: AXUIElement, _ a: Attributes, depth: Int) {
            count += 1
            if a.isSecure { return }  // never read secure text fields
            if let f = a.frame, let w = root.frame, !f.isEmpty, !f.intersects(w) { return }  // scrolled out of sight
            if let t = text(el, a)?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty, seen.insert(t).inserted {
                texts.append(Text(string: t, frame: a.frame))
            }
            for child in a.children {
                guard depth < maxDepth, count < maxElements, Date() < deadline else { return }
                visit(child, attributes(child), depth: depth + 1)
            }
        }
        visit(window, root, depth: 0)
        return (root.title ?? "", root.frame, texts)
    }

    private static let webContentAsked = OSAllocatedUnfairLock(initialState: Set<pid_t>())

    /// Chromium and Electron apps build their web content tree only after an assistive client asks.
    /// Returns true the first time per app process, when the tree may still be filling.
    static func askForWebContent(pid: pid_t) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        // Native apps answer "unsupported". AXEnhancedUserInterface is not settable on macOS 26 (not implemented).
        let asked = AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue) == .success
        return asked && webContentAsked.withLock { $0.insert(pid).inserted }
    }

    // MARK: - Accessibility helpers

    private struct Attributes {
        var role = "", subrole = ""
        var title: String?, description: String?
        var frame: CGRect?
        var children: [AXUIElement] = []
        var isSecure: Bool { SecretsFilter.isSecure(role: role, subrole: subrole) }
    }

    // One round trip per element. The value is left out: it is read only after the secure check.
    private static let names = [kAXRoleAttribute, kAXSubroleAttribute, kAXTitleAttribute, kAXDescriptionAttribute,
                                kAXPositionAttribute, kAXSizeAttribute, kAXChildrenAttribute] as CFArray

    private static func attributes(_ el: AXUIElement) -> Attributes {
        var raw: CFArray?
        guard AXUIElementCopyMultipleAttributeValues(el, names, [], &raw) == .success,
              let v = raw as? [AnyObject], v.count == 7 else { return Attributes() }
        var a = Attributes()
        a.role = v[0] as? String ?? ""
        a.subrole = v[1] as? String ?? ""
        a.title = (v[2] as? String).flatMap { $0.isEmpty ? nil : $0 }
        a.description = (v[3] as? String).flatMap { $0.isEmpty ? nil : $0 }
        var origin = CGPoint.zero, size = CGSize.zero
        if axValue(v[4], .cgPoint, &origin), axValue(v[5], .cgSize, &size) { a.frame = CGRect(origin: origin, size: size) }
        a.children = v[6] as? [AXUIElement] ?? []
        return a
    }

    private static func axValue(_ object: AnyObject, _ type: AXValueType, _ out: UnsafeMutableRawPointer) -> Bool {
        CFGetTypeID(object) == AXValueGetTypeID() && AXValueGetValue(object as! AXValue, type, out)
    }

    private static func attribute(_ el: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(el, name as CFString, &value) == .success ? value : nil
    }

    private static func element(_ el: AXUIElement, _ name: String) -> AXUIElement? {
        guard let value = attribute(el, name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func valueString(_ el: AXUIElement) -> String? {
        let value = attribute(el, kAXValueAttribute)
        return value as? String ?? (value as? NSNumber)?.stringValue
    }

    // Roles whose text is in their value. Others carry it in title or description.
    private static let valueRoles: Set<String> = ["AXStaticText", "AXTextField", "AXComboBox", "AXPopUpButton"]

    private static func text(_ el: AXUIElement, _ a: Attributes) -> String? {
        var value: String?
        if a.role == "AXTextArea" {
            value = visibleRange(el) ?? valueString(el)  // a terminal or document: only what is on screen
        } else if valueRoles.contains(a.role) {
            value = valueString(el)
        }
        return [value, a.title, a.description].compactMap { $0 }.first { !$0.isEmpty }
    }

    private static func visibleRange(_ el: AXUIElement) -> String? {
        var range: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXVisibleCharacterRangeAttribute as CFString, &range) == .success,
              let range else { return nil }
        var text: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(el, kAXStringForRangeParameterizedAttribute as CFString, range, &text) == .success
        else { return nil }
        return text as? String
    }
}
