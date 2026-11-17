import AppKit
import ApplicationServices

/// The names of an app's menu bar commands, for the Doer (N2.6): so a job picks a command by its real path. Read by
/// Accessibility once per job and per app, only when Phew is called, never for an app on the Never read list.
/// Titles only, enabled ones, two levels under the menu bar. Menus that hold the user's own things (recent files,
/// history, bookmarks, the window list, profiles) are left out whole. Every name passes the secrets filter. The text
/// lives in memory with the job's looks and goes with them; it is never logged.
enum MenuReader {
    /// One menu item as read: its title, whether it is enabled, and the items of its menu.
    struct Node: Equatable {
        var title: String
        var enabled = true
        var children: [Node] = []
    }

    /// The most characters the names may take in a request.
    static let cap = 3000

    /// Menus left out whole, by a word in their title (folded: any case, no accents). English and Italian.
    static let privateWords = ["recent", "history", "cronologia", "bookmark", "segnalibr", "favorit", "preferit",
                               "profil", "people", "persone"]
    /// Menus left out whole, by their whole title: the window list, and Services (other apps' names).
    static let privateTitles: Set<String> = ["window", "windows", "finestra", "finestre", "services", "servizi"]

    /// A menu (an item with items) that holds the user's own things.
    static func isPrivate(_ title: String) -> Bool {
        let folded = NeverList.fold(title)
        return privateTitles.contains(folded) || privateWords.contains { folded.contains($0) }
    }

    /// The menus as text, one menu bar menu per line: `Format: Font > [Bold | Italic] | Show Fonts…`. `bar` is the
    /// menu bar's items in order; the first, the Apple menu, is left out. Filtered before the cap, cut at a line end.
    static func names(_ bar: [Node], cap: Int = cap) -> String {
        func title(_ node: Node) -> String {
            String(SecretsFilter.clean(node.title).split(whereSeparator: \.isNewline).joined(separator: " ")
                .trimmingCharacters(in: .whitespaces).prefix(ContextPacket.labelCap))
        }
        func kept(_ nodes: [Node]) -> [Node] {
            nodes.filter { $0.enabled && !title($0).isEmpty && ($0.children.isEmpty || !isPrivate($0.title)) }
        }
        let lines = kept(Array(bar.dropFirst())).filter { !$0.children.isEmpty }.compactMap { menu -> String? in
            let items = kept(menu.children).map { item in
                let sub = kept(item.children).map(title)
                return sub.isEmpty ? title(item) : "\(title(item)) > [\(sub.joined(separator: " | "))]"
            }
            return items.isEmpty ? nil : "\(title(menu)): \(items.joined(separator: " | "))"
        }
        var text = lines.joined(separator: "\n")
        guard text.count > cap else { return text }
        text = String(text.prefix(cap))
        if let end = text.lastIndex(of: "\n") { text = String(text[..<end]) }
        return text
    }

    /// The real read: the menu bar of app `pid`, two levels under it, then `names`. Empty for an app never read
    /// (`NeverReadList.refuses`), or when the app gives no menu bar. Reads titles and the enabled flag only, never opens a menu.
    static func names(pid: pid_t, list: NeverReadList = .shared) -> String {
        guard !list.refuses(pid: pid) else { return "" }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, Hand.timeout)
        var bar: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute as CFString, &bar) == .success, let bar,
              CFGetTypeID(bar) == AXUIElementGetTypeID() else { return "" }
        let deadline = Date() + 1  // a hung or huge app cannot stall the job
        // Under the menu bar the items sit directly; under an item, inside its one menu.
        func items(_ el: AXUIElement, under bar: Bool) -> [AXUIElement] {
            let direct = children(el)
            return bar ? direct : direct.flatMap(children)
        }
        func node(_ el: AXUIElement, depth: Int) -> Node {
            var raw: CFArray?
            let names = [kAXTitleAttribute, kAXEnabledAttribute] as CFArray
            guard Date() < deadline, AXUIElementCopyMultipleAttributeValues(el, names, [], &raw) == .success,
                  let v = raw as? [AnyObject], v.count == 2 else { return Node(title: "", enabled: false) }
            var n = Node(title: v[0] as? String ?? "", enabled: v[1] as? Bool ?? true)
            // Two levels under the menu bar; a private menu's items are never read.
            if depth < 2, n.enabled, !isPrivate(n.title) { n.children = items(el, under: false).map { node($0, depth: depth + 1) } }
            return n
        }
        return names(items(bar as! AXUIElement, under: true).map { node($0, depth: 0) })
    }

    private static func children(_ el: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &value) == .success else { return [] }
        return value as? [AXUIElement] ?? []
    }
}
