import Foundation

/// The Map as one readable Markdown file (docs/05-map-storage.md 5.13, roadmap P5.10): you, your projects with their tasks,
/// documents, events and notes, the other things by class, every link, the old versions, then past questions by
/// date. Each fact shows its origin, when it was stored and its confidence. Forgotten items never appear; sensitive
/// facts only when `includeSensitive`. Plain code, no model call. The same Map and `now` give the same text.
extension MapStore {
    func export(includeSensitive: Bool, now: Date = .now) -> String {
        let all = visibleNodes(currentOnly: false).filter { includeSensitive || !$0.sensitive }
        let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        let current = all.filter { $0.validTo == nil }
        // A link is shown only when both its ends are: a link to a left-out sensitive thing is left out with it.
        let edges = visibleEdges(currentOnly: false).filter { byID[$0.from] != nil && byID[$0.to] != nil }
        let liveEdges = edges.filter { $0.validTo == nil }
        let events = visibleEvents().filter { (includeSensitive || !$0.sensitive) && !$0.summary.isEmpty }
            .sorted { ($0.time, $0.id) < ($1.time, $1.id) }

        // Each current thing or Note is listed once, in one section: its Project, You, or its class.
        func project(of node: MapNode) -> Int64? {
            liveEdges.first { $0.link == .partOf && $0.from == node.id && byID[$0.to]?.mapClass == .project && byID[$0.to]?.validTo == nil }?.to
        }
        func home(_ node: MapNode) -> String {
            switch node.mapClass {
            case .me: return "you"
            case .project: return "p\(node.id)"
            case .task, .document, .event: return project(of: node).map { "p\($0)" } ?? node.mapClass.rawValue
            case .note:
                guard let about = liveEdges.first(where: { $0.link == .about && $0.from == node.id }), let target = byID[about.to],
                      target.validTo == nil else { return node.mapClass.rawValue }
                if target.mapClass == .me { return "you" }
                if target.mapClass == .project { return "p\(target.id)" }
                return [.task, .document, .event].contains(target.mapClass) ? project(of: target).map { "p\($0)" } ?? "Note" : "Note"
            default: return node.mapClass.rawValue
            }
        }
        let homes = Dictionary(grouping: current, by: home)

        func name(_ id: Int64) -> String {
            guard let node = byID[id] else { return "?" }
            switch node.mapClass {
            case .me: return node.name.isEmpty ? "You" : node.name
            case .note: return "\"\(node.text)\""
            default: return node.name
            }
        }
        // An imported fact names its source and its import's number, so the export shows what an undo would take (5.10).
        let imports = Dictionary(uniqueKeysWithValues: visibleEvents().filter { $0.kind == .import }.map { ($0.id, $0.app) })
        func origin(_ origin: Origin, _ created: String, _ confidence: Double, _ source: Int64?) -> String {
            let from = origin == .imported ? source.flatMap { id in imports[id].map { " from \($0) (import \(id))" } } ?? "" : ""
            return "\(origin.rawValue.capitalized)\(from) on \(Self.exportDate(created) ?? "an unknown day"), confidence \(String(format: "%.1f", confidence))."
        }
        func line(_ node: MapNode) -> String {
            let kind = node.kind.isEmpty ? node.mapClass.rawValue : "\(node.mapClass.rawValue), \(node.kind)"
            var parts = [node.mapClass == .note ? "\"\(node.text)\" (\(kind))." : "**\(name(node.id))** (\(kind))."]
            if !node.aliases.isEmpty { parts.append("Also called \(node.aliases.joined(separator: ", ")).") }
            let values = Self.values(node.properties)
            for (key, word) in [("due", "Due"), ("start", "Starts"), ("end", "Ends")] {
                if let date = values[key] as? String { parts.append("\(word) \(Self.exportDate(date, withTime: true) ?? date).") }
            }
            if values["done"] as? Bool == true { parts.append("Done.") }
            if let path = values["path"] as? String { parts.append("Path: \(path).") }
            if let address = values["address"] as? String { parts.append("Address: \(address).") }
            parts.append(origin(node.origin, node.created, node.confidence, node.sourceEvent))
            if let from = Self.exportDate(node.validFrom), from != Self.exportDate(node.created) { parts.append("True from \(from).") }
            if let until = node.validTo {
                parts.append("True until \(Self.exportDate(until) ?? until)" + (node.supersededBy.map { ", replaced by \(name($0))" } ?? "") + ".")
            }
            if node.sensitive { parts.append("Sensitive.") }
            return parts.joined(separator: " ")
        }
        func line(_ edge: MapEdge) -> String {
            var text = "\(name(edge.from)), \(Self.exportLinkWords[edge.link] ?? edge.link.rawValue), \(name(edge.to))"
            if edge.link == .understands, let strength = edge.strength { text += ", strength \(String(format: "%.1f", strength))" }
            text += ". " + origin(edge.origin, edge.created, edge.confidence, edge.sourceEvent)
            if let until = edge.validTo { text += " True until \(Self.exportDate(until) ?? until)." }
            return text
        }
        func line(_ event: MapEvent) -> String {
            let verb = [EventKind.ask: "Asked", .guide: "Asked", .tell: "Told", .correction: "Corrected", .task: "Task given",
                        .import: "Imported"][event.kind] ?? "Asked"
            var text = "\(Self.exportDate(event.time, withTime: true) ?? "Unknown day"). \(verb)"
            if !event.app.isEmpty { text += (event.kind == .import ? " from " : " in ") + event.app }
            if let id = event.project, byID[id] != nil { text += ", on \(name(id))" }
            return text + ": \(event.summary)" + (event.sensitive ? " Sensitive." : "")
        }

        var out = ["# Phew Map", "",
                   "Exported on \(Self.exportDate(Self.iso(now), withTime: true) ?? ""). "
                   + (includeSensitive ? "Sensitive facts are included and marked \"Sensitive\"." : "Sensitive facts are left out."),
                   "",
                   "Each fact says where it came from: told (you said it), observed (Phew learned it while answering) or "
                   + "imported (from another AI tool), when it was stored, and how sure Phew is (confidence, 0 to 1). "
                   + "This file is a copy: forgetting something in Phew later does not change it.",
                   "",
                   "Things and notes: \(current.count). Links: \(liveEdges.count). Old versions: \(all.count - current.count + edges.count - liveEdges.count). Past questions: \(events.count)."]
        func section(_ title: String, _ lines: [String]) {
            guard !lines.isEmpty else { return }
            out += ["", "## \(title)", ""] + lines.map { "- " + $0 }
        }
        section("You", (homes["you"] ?? []).map(line))
        for project in current where project.mapClass == .project {
            section("Project: \(project.name)", (homes["p\(project.id)"] ?? []).map(line))
        }
        for (mapClass, title) in Self.exportSections {
            section(title, (homes[mapClass.rawValue] ?? []).map(line))
        }
        section("Links", liveEdges.map(line))
        section("Old versions", all.filter { $0.validTo != nil }.map(line) + edges.filter { $0.validTo != nil }.map(line))
        section("Past questions", events.map(line))
        // One fact per line: a line break inside a name or a sentence would split it. Then the secrets filter, line by line.
        return out.map { SecretsFilter.clean($0.replacingOccurrences(of: "\n", with: " ")) }.joined(separator: "\n") + "\n"
    }

    /// The things outside a Project, by class, in this order.
    static let exportSections: [(MapClass, String)] = [
        (.person, "People"), (.organization, "Organizations"), (.topic, "Topics"), (.tool, "Tools"), (.place, "Places"),
        (.task, "Other tasks"), (.document, "Other documents"), (.event, "Other events"), (.note, "Other notes"),
    ]

    static let exportLinkWords: [MapLink: String] = [
        .partOf: "part of", .about: "about", .requires: "requires", .involves: "involves", .uses: "uses", .at: "at",
        .understands: "understands",
    ]

    /// "12 Nov 2026", or "12 Nov 2026 15:00" with `withTime` when the date has a time. Nil when it cannot be read.
    static func exportDate(_ text: String, withTime: Bool = false) -> String? {
        guard let (date, dayOnly) = MapDate.parse(text) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = dayOnly ? TimeZone(identifier: "UTC") : .current
        formatter.dateFormat = "d MMM yyyy" + (withTime && !dayOnly ? " HH:mm" : "")
        return formatter.string(from: date)
    }
}
