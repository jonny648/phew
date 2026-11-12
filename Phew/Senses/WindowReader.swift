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
    // The look inside the element under the cursor runs on the main thread before the panel opens: keep it tiny.
    static let cursorElements = 30
    static let cursorDepth = 4
    static let cursorBudget: TimeInterval = 0.015
    static let cursorCap = 300

    /// The element under the mouse, read synchronously: it must be the user's app, not Phew's panel.
    /// Also returns the mouse point. `pid` is the app being read, used only by the debug point.
    static func elementUnderCursor(pid: pid_t) -> (element: CursorElement?, point: CGPoint) {
        let systemWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(systemWide, 0.1)  // global for Phew: a hung app costs at most 0.1 s per call
        let mouse = NSEvent.mouseLocation  // bottom-left origin; flip against the main display
        var point = CGPoint(x: mouse.x, y: (NSScreen.screens.first?.frame.height ?? 0) - mouse.y)
        var hit: AXUIElement?
        #if DEBUG
        if let p = debugPoint { point = p; hit = debugHit(pid: pid, at: p) }
        #endif
        if hit == nil { AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &hit) }
        guard let element = hit else { return (nil, point) }
        var owner: pid_t = 0
        AXUIElementGetPid(element, &owner)
        guard owner != getpid() else { return (nil, point) }

        let a = attributes(element)
        // Password field: its frame lets Phew point at it; nothing else is read.
        if a.isSecure { return (CursorElement(role: "AXSecureTextField", label: "", value: "", frame: a.frame), point) }
        // Whole documents and pages: their value can be a whole file; the look-inside below reads the visible part.
        let value = ["AXTextArea", "AXWebArea"].contains(a.role) ? nil : valueString(element).map(removeJunk)
        var cursor = CursorElement(role: a.role, label: a.title ?? a.description ?? "",
                                   value: String((value ?? "").prefix(cursorCap)), frame: a.frame)
        if cursor.label.isEmpty && cursor.value.isEmpty {
            // No text of its own (a list cell, a block): the text inside it, nearest the mouse first.
            #if DEBUG
            let start = Date()
            defer { shellLog("cursor look-inside: \(Int(Date().timeIntervalSince(start) * 1_000_000)) µs, \(cursor.value.count) chars") }
            #endif
            let inner = walk(element, a, clip: a.frame, near: point, pointables: false,
                             maxElements: cursorElements, maxDepth: cursorDepth, budget: cursorBudget)
            cursor.value = ContextPacket.trim(inner.texts, near: point, cap: cursorCap)
        }
        return (cursor, point)
    }

    /// Focused window of the app (else main, else frontmost): title, frame, its visible text and the elements
    /// Phew can point at, both in reading order.
    static func readWindow(pid: pid_t) -> (title: String, frame: CGRect?, texts: [Text], pointables: [Pointable]) {
        guard let window = window(pid) else { return ("", nil, [], []) }
        let root = attributes(window)
        let found = walk(window, root, clip: root.frame, maxElements: maxElements, maxDepth: maxDepth, budget: timeBudget)
        return (root.title ?? "", root.frame, found.texts.filter { $0.string != root.title }, found.pointables)
    }

    // What a student clicks, types into or picks from, as the test apps expose it. Tabs are AXRadioButton, switches
    // AXCheckBox, sidebar entries AXRow. Cells and images are left out: rows cover the first, the second are mostly
    // decoration (hundreds on a web page).
    static let pointableRoles: Set<String> = [
        "AXButton", "AXLink", "AXTextField", "AXTextArea", "AXComboBox", "AXCheckBox", "AXRadioButton", "AXPopUpButton",
        "AXMenuButton", "AXMenuItem", "AXSlider", "AXIncrementor", "AXDisclosureTriangle", "AXColorWell", "AXRow",
    ]
    // A field's value is what the student typed: it never names the field.
    private static let fieldRoles: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox"]

    /// The frame Phew points at: clipped, in whole points. Nil below 4 points either way, a sliver at the edge of a
    /// scroll area: Chromium gives an element scrolled out of sight a 1-point frame there.
    static func pointableFrame(_ frame: CGRect?, clip: CGRect?) -> CGRect? {
        guard let frame else { return nil }
        let f = clip.map { frame.intersection($0) } ?? frame
        return f.width >= 4 && f.height >= 4 ? f.integral : nil
    }

    /// Visible text under `root`, skipping secure fields and anything outside `clip` (scrolled out of sight).
    /// Reading order, or nearest `point` first when given, so a big container gives the text by the mouse.
    /// With `pointables`, also the named controls on screen (`pointableRoles`), and secure fields without a name.
    /// shortcut: only the first children within the element limit are ranked; a long list under the mouse
    /// may miss its far rows. Use AXVisibleChildren if that bites.
    private static func walk(_ root: AXUIElement, _ rootAttributes: Attributes, clip: CGRect?, near point: CGPoint? = nil,
                             pointables wantsPointables: Bool = true,
                             maxElements: Int, maxDepth: Int, budget: TimeInterval) -> (texts: [Text], pointables: [Pointable]) {
        let deadline = Date() + budget
        var texts: [Text] = []
        var pointables: [Pointable] = []
        var unnamed: [Int] = []  // listed controls around the current element still waiting for a name
        var seen: Set<String> = []  // repeats add nothing: links and their label, list rows
        var count = 0

        // `pointClip` narrows `clip` for controls: one shows only within the controls around it.
        func visit(_ el: AXUIElement, _ a: Attributes, depth: Int, pointClip: CGRect?) {
            count += 1
            if let f = a.frame, let clip, !f.isEmpty, !f.intersects(clip) { return }
            let frame = wantsPointables ? pointableFrame(a.frame, clip: pointClip) : nil
            if a.isSecure {  // never read secure text fields: role and frame only, so Phew can still point at one
                if let frame { pointables.append(Pointable(role: "AXSecureTextField", label: "", frame: frame)) }
                return
            }
            let t = text(el, a).map(removeJunk)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !t.isEmpty {
                if seen.insert(t).inserted { texts.append(Text(string: t, frame: a.frame)) }
                for i in unnamed { pointables[i].label = t }  // the first text inside a row or button names it
                unnamed.removeAll()
            }
            let unnamedBefore = unnamed.count
            defer { unnamed.removeSubrange(min(unnamedBefore, unnamed.count)...) }
            if let frame, pointableRoles.contains(a.role) {
                pointables.append(Pointable(role: a.role, label: name(el, a, text: t), frame: frame))
                if pointables[pointables.count - 1].label.isEmpty && !fieldRoles.contains(a.role) {
                    unnamed.append(pointables.count - 1)
                }
            }
            guard depth < maxDepth else { return }
            var children: [(AXUIElement, Attributes)] = []
            for child in a.children.prefix(max(maxElements - count, 0)) {
                guard Date() < deadline else { break }
                children.append((child, attributes(child)))
            }
            if let point { children.sort { distance($0.1.frame, point) < distance($1.1.frame, point) } }
            // A Notion card scrolled half out of sight keeps its buttons' frames: clip them to the card. Not the menu
            // of a pop-up, which opens outside it.
            // shortcut: only controls clip what is inside them. A Chromium scroll area is a plain group, so a control
            // hidden under its edge yet inside the window can still be listed; clip to scrolling groups if seen.
            let innerClip = pointableRoles.contains(a.role) && a.frame != nil
                && !["AXPopUpButton", "AXMenuButton", "AXComboBox"].contains(a.role) ? frame ?? .null : pointClip
            for (child, childAttributes) in children {
                guard count < maxElements, Date() < deadline else { return }
                visit(child, childAttributes, depth: depth + 1, pointClip: innerClip)
            }
        }
        visit(root, rootAttributes, depth: 0, pointClip: clip)
        return (texts, pointables.filter { !$0.label.isEmpty || $0.role == "AXSecureTextField" })
    }

    /// What the Guide calls a control: its title or description, a pop-up's chosen item, a field's placeholder.
    /// Empty when it has none: the walk then names it after the first text inside it, except fields.
    /// shortcut: a control named only by a label beside it (a System Settings switch) is left out; read
    /// AXTitleUIElement if the Guide needs those.
    private static func name(_ el: AXUIElement, _ a: Attributes, text: String) -> String {
        let name = a.title ?? a.description ?? (a.role == "AXPopUpButton" ? text
            : fieldRoles.contains(a.role) ? attribute(el, kAXPlaceholderValueAttribute) as? String : nil)
        return name.map { removeJunk($0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
    }

    /// Distance from `point` to a frame, 0 inside it. No frame counts as farthest.
    static func distance(_ frame: CGRect?, _ point: CGPoint) -> CGFloat {
        guard let f = frame else { return .infinity }
        return hypot(max(f.minX - point.x, 0, point.x - f.maxX), max(f.minY - point.y, 0, point.y - f.maxY))
    }

    // A data URI, or a whitespace-free run of base64 characters (image data leaked into a label).
    private static let junkCandidate = try! NSRegularExpression(
        pattern: #"(?<!\S)(?:data:\w+/[\w.+-]+;base64,\S*|[A-Za-z0-9+/]{30,}={0,2})(?!\S)"#)

    /// Drops image data and data URIs from a text. URLs, paths, emails and long words stay: base64 has a part of
    /// 30 or more characters between slashes mixing upper case, lower case and digits; they have dots, @, or short parts.
    static func removeJunk(_ text: String) -> String {
        let out = NSMutableString(string: text)
        for match in junkCandidate.matches(in: text, range: NSRange(location: 0, length: out.length)).reversed() {
            let run = out.substring(with: match.range)
            let base64 = run.split(separator: "/").contains { $0.count >= 30 }
                && run.contains(where: \.isNumber) && run.contains(where: \.isUppercase) && run.contains(where: \.isLowercase)
            if run.hasPrefix("data:") || base64 { out.replaceCharacters(in: match.range, with: "") }
        }
        return out as String
    }

    private static let fullTreeAsked = OSAllocatedUnfairLock(initialState: Set<pid_t>())

    /// Some apps build their full tree only after an assistive client asks: Chromium and Electron their web content
    /// (AXManualAccessibility), native apps such as Keynote their canvas (AXEnhancedUserInterface, which VoiceOver sets).
    /// Returns true the first time per app process, when the tree may still be filling.
    static func askForFullTree(pid: pid_t) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        let enhanced = "AXEnhancedUserInterface"
        // Native apps answer "unsupported" to the first. The second is set only where the app reports it off.
        var asked = AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue) == .success
        if !asked, attribute(app, enhanced) as? Bool == false {
            // Keynote answers "not implemented" on macOS 26 yet takes the value: read it back.
            AXUIElementSetAttributeValue(app, enhanced as CFString, kCFBooleanTrue)
            asked = attribute(app, enhanced) as? Bool == true
        }
        return asked && fullTreeAsked.withLock { $0.insert(pid).inserted }
    }

    #if DEBUG
    /// `--debug-point x,y` (Accessibility coordinates): the self-check reads that point instead of the mouse's,
    /// because the checker cannot move the mouse. The real mouse is never moved.
    private static let debugPoint: CGPoint? = {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--debug-point"), i + 1 < args.count else { return nil }
        let xy = args[i + 1].split(separator: ",").compactMap { Double($0) }
        return xy.count == 2 ? CGPoint(x: xy[0], y: xy[1]) : nil
    }()

    /// The deepest element of the app's window containing `point`, found by frames: it works on windows behind
    /// others or on another Space, where the system hit test sees a different app.
    private static func debugHit(pid: pid_t, at point: CGPoint) -> AXUIElement? {
        func deepest(_ el: AXUIElement) -> (element: AXUIElement, depth: Int) {
            attributes(el).children.filter { attributes($0).frame?.contains(point) == true }
                .map { let d = deepest($0); return (d.element, d.depth + 1) }.max { $0.depth < $1.depth } ?? (el, 0)
        }
        return window(pid).map { deepest($0).element }
    }
    #endif

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

    private static func window(_ pid: pid_t) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        return element(app, kAXFocusedWindowAttribute) ?? element(app, kAXMainWindowAttribute)
            ?? (attribute(app, kAXWindowsAttribute) as? [AXUIElement])?.first
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
