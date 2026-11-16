import Foundation

/// The arguments of `search_map` (docs/05-map.md 5.11, `ToolSpec.searchMap`), decoded from the tool call's JSON.
/// Odd input never fails: a field of the wrong type is read as missing.
struct MapSearchArguments: Decodable, Equatable, Sendable {
    var query = ""
    var mapClass: String?
    var since: String?
    var list: String?
    var past = false

    enum CodingKeys: String, CodingKey { case query, mapClass = "class", since, list, past }

    init(query: String = "", mapClass: String? = nil, since: String? = nil, list: String? = nil, past: Bool = false) {
        (self.query, self.mapClass, self.since, self.list, self.past) = (query, mapClass, since, list, past)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        query = (try? c.decodeIfPresent(String.self, forKey: .query)) ?? ""
        mapClass = try? c.decodeIfPresent(String.self, forKey: .mapClass)
        since = try? c.decodeIfPresent(String.self, forKey: .since)
        list = try? c.decodeIfPresent(String.self, forKey: .list)
        past = (try? c.decodeIfPresent(Bool.self, forKey: .past)) ?? false
    }
}

/// The reading side of the Map: the defined terms (5.6), the rules (5.7), recall (5.11 layer 2), the profile (5.8),
/// `search_map` (5.11 layer 3) and project detection. All plain code: no model call. Every line handed out has
/// passed the secrets filter, and carries its origin and date.
///
/// Class values in `properties` are stored as `{"due": {"value": "2026-11-20", "origin": "told"}, "done":
/// {"value": true, "origin": "observed"}}`: `due`, `done` (Task), `start`, `end` (Event), `path`, `address`
/// (Document). A date is ISO 8601, with a time or as a day alone.
extension MapStore {
    /// The defined terms of 5.6, written once into `terms`. Each query reads `p.now` (ISO 8601) and `p.project` (an
    /// id or null) from the line `term(_:)` puts in front, and returns ids in its order. "Next step" is run by code
    /// from these, in the order 5.6 gives (5.12).
    static let termQueries: [(String, String)] = {
        let current = "n.valid_to IS NULL AND n.deleted = ''"
        let open = "n.class = 'Task' AND \(current) AND NOT coalesce(json_extract(n.properties, '$.done.value'), 0)"
        let due = "json_extract(n.properties, '$.due.value')"
        let start = "json_extract(n.properties, '$.start.value')"
        let live = { (e: String) in "\(e).valid_to IS NULL AND \(e).deleted = ''" }
        return [
            ("current", "SELECT n.id FROM all_nodes n WHERE \(current)"),
            ("open", "SELECT n.id FROM all_nodes n WHERE \(open)"),
            ("active", """
                SELECT n.id, (SELECT max(julianday(e.time)) FROM all_events e WHERE e.project = n.id AND e.deleted = '') AS last
                FROM all_nodes n, p WHERE n.class = 'Project' AND \(current) AND last >= julianday(p.now) - 14
                ORDER BY last DESC, n.id
                """),
            // A day alone counts as its whole day: + (length = 10) adds one day to it.
            ("due_soon", "SELECT n.id FROM all_nodes n, p WHERE \(open) AND julianday(\(due)) <= julianday(p.now) + 7 ORDER BY julianday(\(due)), n.id"),
            ("coming_up", """
                SELECT n.id FROM all_nodes n, p WHERE n.class = 'Event' AND \(current)
                  AND julianday(\(start)) + (length(\(start)) = 10) >= julianday(p.now) AND julianday(\(start)) <= julianday(p.now) + 7
                ORDER BY julianday(\(start)), n.id
                """),
            ("stale", "SELECT n.id FROM all_nodes n, p WHERE \(current) AND n.origin != 'told' AND julianday(n.updated) < julianday(p.now) - 90 ORDER BY n.updated, n.id"),
            ("open_point", """
                SELECT n.id FROM all_nodes n, p WHERE n.class = 'Topic' AND \(current)
                  AND (SELECT count(*) FROM all_events e, json_each(e.mentions) m
                       WHERE m.value = n.id AND e.kind IN ('ask', 'guide') AND e.deleted = '') >= 2
                  AND coalesce((SELECT min(u.strength) FROM all_edges u
                                WHERE u.link = 'understands' AND u.to_node = n.id AND \(live("u"))), 0) < 0.5
                  AND (p.project IS NULL
                    OR EXISTS (SELECT 1 FROM all_events e, json_each(e.mentions) m
                               WHERE e.project = p.project AND m.value = n.id AND e.deleted = '')
                    OR EXISTS (SELECT 1 FROM all_edges r JOIN all_edges o ON o.from_node = r.from_node
                               WHERE r.link = 'requires' AND r.to_node = n.id AND \(live("r"))
                                 AND o.link = 'part_of' AND o.to_node = p.project AND \(live("o"))))
                ORDER BY n.id
                """),
        ]
    }()

    /// The ids one defined term gives, in its order. A failed or unknown term gives nothing.
    func term(_ name: String, now: Date, project: Int64? = nil) -> [Int64] {
        guard case .text(let query)? = try? db.scalar("SELECT query FROM main.terms WHERE name = ?", [.text(name)]) else { return [] }
        let rows = try? db.query("WITH p(now, project) AS (SELECT ?1, ?2) " + query, [.text(Self.iso(now)), SQLValue(project)])
        return (rows ?? []).compactMap { $0.int("id") }
    }

    // MARK: - "Understands" (5.4)

    /// The next strength of "understands". `current` nil: no link yet. What the user said wins, with no 0.1 step.
    static func nextStrength(_ current: Double?, said: Bool?) -> Double {
        if let said { return said ? 0.9 : 0 }
        guard let current else { return 0.3 }
        return max(0, ((current - 0.1) * 10).rounded() / 10)
    }

    /// Moves the strength of Me "understands" `topic` after one question (5.4). `said`: what the user said about the
    /// Topic (understood, not understood, nil for nothing). `asked`: the question was of kind ask or guide and
    /// mentioned the Topic. Updated in place: a counter, no history row. Returns the strength now stored.
    @discardableResult
    func moveUnderstanding(topic: Int64, said: Bool?, asked: Bool, now: Date = .now) throws -> Double? {
        guard let me = try db.scalar("SELECT id FROM all_nodes WHERE class = 'Me' AND deleted = ''").intValue else { return nil }
        let link = try db.query("""
            SELECT id, strength FROM all_edges WHERE link = 'understands' AND from_node = ? AND to_node = ? AND valid_to IS NULL AND deleted = ''
            """, [.int(me), .int(topic)]).first
        guard said != nil || asked else { return link?.real("strength") }
        let stamp = Self.iso(now)
        let strength = Self.nextStrength(link == nil ? nil : link?.real("strength") ?? 0, said: said)
        if let id = link?.int("id") {
            for file in ["main", "s"] {
                try db.query("UPDATE \(file).edges SET strength = ?, updated = ? WHERE id = ?", [.real(strength), .text(stamp), .int(id)])
            }
        } else {
            try add(MapEdge(from: me, to: topic, link: .understands, strength: strength,
                            origin: said == nil ? .observed : .told, validFrom: stamp, created: stamp, updated: stamp))
        }
        return strength
    }

    // MARK: - Project detection (5.11)

    /// The Project the call is about, by code: first the open document's path or address against stored Documents,
    /// then the app name, window title and question against the names and other names of Projects and Documents.
    /// Nil when nothing matches: no guess.
    func detectProject(appName: String, windowTitle: String, documentPath: String?, question: String = "") -> MapNode? {
        if let label = documentPath.map(Self.label), !label.isEmpty, let document = documentWithLabel(label),
           let project = projectOf(document.id) {
            return project
        }
        for hit in search([Self.detectionWords([appName, windowTitle, question])], classes: [.project, .document], namesOnly: true) {
            if hit.mapClass == .project { return hit }
            if let project = projectOf(hit.id) { return project }
        }
        return nil
    }

    /// The words project detection may match on: at least 3 letters and not a common English or Italian word, so
    /// "the", "di" or "la" in a title never names a Project by themselves.
    static func detectionWords(_ parts: [String]) -> String {
        parts.flatMap { $0.split { !$0.isLetter && !$0.isNumber } }
            .filter { $0.count >= 3 && !stopwords.contains($0.lowercased()) }.joined(separator: " ")
    }

    static let stopwords: Set<String> = [
        "the", "and", "for", "with", "from", "this", "that", "what", "how", "why", "who", "are", "was", "you", "your",
        "not", "but", "can", "all", "has", "have", "does", "into", "about", "una", "uno", "gli", "che", "per", "con",
        "del", "della", "dei", "delle", "nel", "nella", "sul", "sulla", "come", "cosa", "non", "sono", "questo",
        "questa", "quello", "quella", "anche", "più", "mio", "mia", "tuo", "tua", "suo", "sua",
    ]

    /// "This is the X project": a told fact. Links the open document to Project X with "part of", so the next call
    /// from the same file names X at step 1. With no path, the window title becomes the Document's name instead.
    /// X is reused when a current Project has that name or other name (ignoring capitals and accents), else created.
    /// An older "part of" to another Project ends, kept as history. Only labels are stored, never screen text.
    @discardableResult
    func setProject(named name: String, windowTitle: String, documentPath: String?, now: Date = .now) throws -> MapNode? {
        let stamp = Self.iso(now)
        func made(_ node: MapNode) throws -> MapNode? {
            var node = node
            (node.origin, node.validFrom, node.created, node.updated) = (.told, stamp, stamp, stamp)
            return try self.node(add(node))
        }
        return try db.transaction {
            guard let project = try currentNodes(.project).first(where: { Self.sameName($0, name) })
                    ?? made(MapNode(mapClass: .project, name: name, origin: .told)) else { return nil }
            let label = documentPath.map(Self.label) ?? ""
            var document: MapNode?
            if !label.isEmpty {
                let isFile = label.hasPrefix("/")
                let named = isFile ? URL(fileURLWithPath: label).lastPathComponent : (windowTitle.isEmpty ? label : windowTitle)
                document = try documentWithLabel(label) ?? made(MapNode(
                    mapClass: .document, kind: isFile ? "document" : "web page", name: named,
                    properties: Self.json([isFile ? "path" : "address": ["value": label, "origin": "told"]]), origin: .told))
            } else if !windowTitle.isEmpty {
                document = try currentNodes(.document).first(where: { Self.sameName($0, windowTitle) })
                    ?? made(MapNode(mapClass: .document, kind: "document", name: windowTitle, origin: .told))
            }
            guard let document else { return project }
            let old = try db.query("""
                SELECT e.id, e.to_node FROM all_edges e JOIN all_nodes p ON p.id = e.to_node AND p.class = 'Project'
                WHERE e.from_node = ? AND e.link = 'part_of' AND e.valid_to IS NULL AND e.deleted = ''
                """, [.int(document.id)])
            guard !old.contains(where: { $0.int("to_node") == project.id }) else { return project }
            guard let new = try add(MapEdge(from: document.id, to: project.id, link: .partOf, origin: .told,
                                            validFrom: stamp, created: stamp, updated: stamp)) else { return project }
            for id in old.compactMap({ $0.int("id") }) {
                for file in ["main", "s"] {
                    try db.query("UPDATE \(file).edges SET valid_to = ?, superseded_by = ? WHERE id = ?", [.text(stamp), .int(new), .int(id)])
                }
            }
            return project
        }
    }

    // MARK: - Recall (5.11 layer 2)

    /// What code adds before every answer, with no model call: the Project, its last 3 past questions, up to 6
    /// facts found by a text search, and at most 3 lines each of due soon, coming up, next step and the Project's
    /// open points. Rules 1 to 3 of 5.7: "Start from" an open point a Task requires, the next step, and "may be
    /// outdated" on stale facts. Empty when the Map has nothing to add.
    func recall(question: String, appName: String, windowTitle: String, documentPath: String?, now: Date = .now) -> String {
        let context = LineContext(now: now, stale: Set(term("stale", now: now)))
        let project = detectProject(appName: appName, windowTitle: windowTitle, documentPath: documentPath, question: question)
        let words = [question, appName, windowTitle]
        let questions = project.map { lastQuestions(on: $0.id, limit: 3) } ?? searchEvents(words, limit: 3)
        let dueSoon = term("due_soon", now: now)
        let comingUp = term("coming_up", now: now)
        let next = nextStep(project: project?.id, now: now)
        var tasks = dueSoon
        if case .task(let task)? = next { tasks.insert(task.id, at: 0) }
        let allOpenPoints = term("open_point", now: now, project: project?.id)
        let start = startFrom(allOpenPoints, tasks: tasks)
        let openPoints = allOpenPoints.filter { $0 != start?.id }
        // A fact already on a list is not repeated among the search results.
        var listed = Set(dueSoon.prefix(3) + comingUp.prefix(3) + openPoints.prefix(3) + [project?.id, start?.id].compactMap { $0 })
        if case .task(let task)? = next { listed.insert(task.id) }
        let found = search(words, limit: 6 + listed.count).filter { !listed.contains($0.id) }.prefix(6)

        let sections: [(String, [String])] = [
            ("Project", project.map { [line($0, context)] } ?? []),
            ("Last past questions", questions.map { line($0, context) }),
            ("Found in the Map", found.map { line($0, context) }),
            ("Due soon", nodes(dueSoon.prefix(3)).map { line($0, context) }),
            ("Coming up", nodes(comingUp.prefix(3)).map { line($0, context) }),
            ("Next step", next.map { [line($0, context)] } ?? []),
            ("Start from (open point)", start.map { [line($0, context)] } ?? []),
            ("Open points", nodes(openPoints.prefix(3)).map { line($0, context) }),
        ]
        // About 1,500 tokens at most (5.11). A header with no line that fits is left out.
        var out: [String] = [], size = 0
        for (title, lines) in sections {
            var block = [title + ":"], blockSize = title.count + 2
            for text in lines.map({ "- " + $0 }) where size + blockSize + text.count + 1 <= Self.recallLimit {
                block.append(text)
                blockSize += text.count + 1
            }
            if block.count > 1 { (out, size) = (out + block, size + blockSize) }
        }
        return out.joined(separator: "\n")
    }

    static let recallLimit = 6_000

    // MARK: - Profile (5.8)

    /// A short summary of the user, built by code: their name, current Notes about Me (told, then observed, then
    /// imported; more confident first), then active Projects with their Tasks due soon. The same facts and `now`
    /// always give the same text. At most 200 lines.
    func profile(now: Date = .now) -> String {
        let context = LineContext(now: now, stale: Set(term("stale", now: now)))
        var lines = aboutMe(context)
        let dueSoon = term("due_soon", now: now)
        let active = nodes(term("active", now: now)[...])
        if !active.isEmpty { lines.append("Active projects:") }
        for project in active {
            lines.append("- " + line(project, context, links: false))
            let parts = Set(((try? db.query("""
                SELECT from_node FROM all_edges WHERE link = 'part_of' AND to_node = ? AND valid_to IS NULL AND deleted = ''
                """, [.int(project.id)])) ?? []).compactMap { $0.int("from_node") })
            for task in nodes(dueSoon.filter(parts.contains)[...]) {
                lines.append("  - Due soon: " + line(task, context, links: false))
            }
        }
        return lines.prefix(200).joined(separator: "\n")
    }

    // MARK: - search_map (5.11 layer 3)

    /// `search_map` from the tool call's JSON. Input that cannot be read returns nothing.
    func searchMap(input: Data, now: Date = .now, forRunner: Bool = false) -> String {
        searchMap((try? JSONDecoder().decode(MapSearchArguments.self, from: input)) ?? MapSearchArguments(), now: now, forRunner: forRunner)
    }

    /// At most 10 result lines. A named list in place of a query; else a text search of things and past questions,
    /// limited to one class of things or to past questions only (`History`). An unknown list or class name returns nothing. Sensitive facts are found from
    /// their own index, as any other (5.12). For the Runner, web addresses are left out of every line.
    func searchMap(_ arguments: MapSearchArguments, now: Date = .now, forRunner: Bool = false) -> String {
        let context = LineContext(now: now, stale: Set(term("stale", now: now)), runner: forRunner)
        let list = (arguments.list ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        let className = (arguments.mapClass ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        let query = arguments.query
        let since = arguments.since.flatMap { MapDate.parse($0) == nil ? nil : $0 }
        var lines: [String] = []
        if !list.isEmpty {
            switch list {
            case "due_soon": lines = nodes(term("due_soon", now: now)[...]).map { line($0, context) }
            case "coming_up": lines = nodes(term("coming_up", now: now)[...]).map { line($0, context) }
            case "open_points": lines = nodes(term("open_point", now: now)[...]).map { line($0, context) }
            case "stale": lines = nodes(term("stale", now: now)[...]).map { line($0, context) }
            case "next_step": lines = nextStep(project: nil, now: now).map { [line($0, context)] } ?? []
            case "about_me": lines = aboutMe(context).filter { $0.hasPrefix("- ") }.map { String($0.dropFirst(2)) }
            default: return ""
            }
        } else {
            let history = className == "history"
            var classes: [MapClass] = []
            if !className.isEmpty, !history {
                guard let mapClass = MapClass.allCases.first(where: { $0.rawValue.lowercased() == className }) else { return "" }
                classes = [mapClass]
            }
            // No class: things and past questions together (5.11: `History` searches only past questions). With no
            // query, past questions only when `since` or `History` asks for them. A period asked with words that
            // match no past question ("my work this month") gets the latest past questions of that period.
            let matched = classes.isEmpty && !query.isEmpty ? searchEvents([query], since: since, limit: 10) : []
            let latest = classes.isEmpty && matched.isEmpty && (since != nil || (history && query.isEmpty))
            let events = !latest ? matched : ((try? db.query("""
                SELECT * FROM all_events WHERE deleted = '' AND summary != '' AND (julianday(?1) IS NULL OR julianday(time) >= julianday(?1))
                ORDER BY time DESC, id DESC LIMIT 10
                """, [SQLValue(since)])) ?? []).compactMap(Self.event)
            let found: [MapNode]
            if history {
                found = []
            } else if !query.isEmpty {
                found = search([query], classes: classes, since: since, past: arguments.past, limit: 10)
            } else if let mapClass = classes.first {
                found = ((try? db.query("""
                    SELECT * FROM all_nodes WHERE class = ?1 AND deleted = '' AND (?2 OR valid_to IS NULL)
                      AND (julianday(?3) IS NULL OR julianday(valid_from) >= julianday(?3))
                    ORDER BY updated DESC, id DESC LIMIT 10
                    """, [.text(mapClass.rawValue), .int(arguments.past ? 1 : 0), SQLValue(since)])) ?? []).compactMap(Self.node)
            } else {
                found = []
            }
            // Up to 5 of the 10 places are kept for past questions, so many things cannot crowd them out.
            lines = found.prefix(10 - min(events.count, 5)).map { line($0, context) } + events.map { line($0, context) }
        }
        return lines.prefix(10).map { "- " + $0 }.joined(separator: "\n")
    }

    // MARK: - Next step and start from (5.6, 5.7)

    enum NextStep { case task(MapNode), question(MapEvent) }

    /// The first open Task due soon, earliest first; else the open Task of the Project with the oldest "last seen"
    /// (with no Project, the one of the latest past question); else the last past question on that Project.
    func nextStep(project: Int64?, now: Date) -> NextStep? {
        if let first = term("due_soon", now: now).first, let task = try? node(first) { return .task(task) }
        let latest = try? db.scalar("SELECT project FROM all_events WHERE deleted = '' AND project IS NOT NULL ORDER BY time DESC, id DESC LIMIT 1")
        guard let project = project ?? latest?.intValue else { return nil }
        let open = Set(term("open", now: now))
        let tasks = ((try? db.query("""
            SELECT n.* FROM all_nodes n JOIN all_edges e ON e.from_node = n.id
            WHERE e.link = 'part_of' AND e.to_node = ? AND e.valid_to IS NULL AND e.deleted = '' ORDER BY n.updated, n.id
            """, [.int(project)])) ?? []).compactMap(Self.node)
        if let task = tasks.first(where: { open.contains($0.id) }) { return .task(task) }
        return lastQuestions(on: project, limit: 1).first.map { .question($0) }
    }

    /// Rule 1: the first open point that one of `tasks` requires, in the order of `tasks`.
    private func startFrom(_ openPoints: [Int64], tasks: [Int64]) -> MapNode? {
        let points = Set(openPoints)
        for task in tasks {
            let required = ((try? db.query("""
                SELECT to_node FROM all_edges WHERE link = 'requires' AND from_node = ? AND valid_to IS NULL AND deleted = '' ORDER BY id
                """, [.int(task)])) ?? []).compactMap { $0.int("to_node") }
            if let topic = required.first(where: points.contains), let node = try? node(topic) { return node }
        }
        return nil
    }

    // MARK: - Lines (5.11 "What a result looks like")

    /// What the lines of one read share: the time, the stale ids, and whether web addresses are left out (Runner).
    struct LineContext {
        let now: Date
        let stale: Set<Int64>
        var runner = false
    }

    private func line(_ step: NextStep, _ context: LineContext) -> String {
        switch step {
        case .task(let task): return line(task, context)
        case .question(let event): return "Pick up from your last past question. " + line(event, context)
        }
    }

    /// One result line for a thing or a Note: name, class and kind (a Note's sentence), its dates, where it came
    /// from, "late" and "may be outdated", then up to 8 current links and up to 3 current Notes about it. No ids.
    func line(_ node: MapNode, _ context: LineContext, links: Bool = true) -> String {
        let kind = node.kind.isEmpty ? node.mapClass.rawValue : "\(node.mapClass.rawValue), \(node.kind)"
        var parts = [node.mapClass == .note ? "\"\(node.text)\" (\(kind))." : "\(node.name.isEmpty ? "You" : node.name) (\(kind))."]
        let values = Self.values(node.properties)
        if node.mapClass == .task {
            if let due = values["due"] as? String, let said = MapDate.say(due, now: context.now, withTime: true) {
                parts.append("Due \(said)\(MapDate.isPast(due, now: context.now) && values["done"] as? Bool != true ? ", late" : "").")
            }
            if values["done"] as? Bool == true { parts.append("Done.") }
        }
        if node.mapClass == .event, let start = values["start"] as? String, let said = MapDate.say(start, now: context.now, withTime: true) {
            parts.append("Starts \(said).")
        }
        parts.append(origin(node.origin, node.created, node.sourceEvent, context) + ".")
        if let from = MapDate.say(node.validFrom, now: context.now), from != MapDate.say(node.created, now: context.now) {
            parts.append("True from \(from).")
        }
        if let until = node.validTo.flatMap({ MapDate.say($0, now: context.now) }) { parts.append("Old version, true until \(until).") }
        if context.stale.contains(node.id) { parts.append("May be outdated.") }
        if links {
            if let text = linkText(node.id) { parts.append(text) }
            if let text = notesText(node.id, context) { parts.append(text) }
        }
        return finish(parts.joined(separator: " "), context)
    }

    /// One line for a past question: its date, app, Project and summary.
    func line(_ event: MapEvent, _ context: LineContext) -> String {
        let verb = [EventKind.ask: "Asked", .guide: "Asked", .tell: "Told", .correction: "Corrected", .task: "Task given",
                    .import: "Imported"][event.kind] ?? "Asked"
        var text = "Past question. \(verb) on \(MapDate.say(event.time, now: context.now) ?? "an unknown day")"
        if !event.app.isEmpty { text += " in \(event.app)" }
        if let id = event.project, let project = try? node(id) { text += ", on \(project.name)" }
        return finish(text + ": \(event.summary)", context)
    }

    // MARK: - Private

    private func finish(_ text: String, _ context: LineContext) -> String {
        let clean = SecretsFilter.clean(text)
        guard context.runner else { return clean }
        return clean.replacingOccurrences(of: #"(?i)\b(?:https?://|www\.)\S+"#, with: "(web address left out)", options: .regularExpression)
    }

    /// "Told on 12 Nov", "Observed on 12 Nov in Figma", "Imported on 13 Nov".
    private func origin(_ origin: Origin, _ created: String, _ source: Int64?, _ context: LineContext, capital: Bool = true) -> String {
        var text = "\(capital ? origin.rawValue.capitalized : origin.rawValue) on \(MapDate.say(created, now: context.now) ?? "an unknown day")"
        if origin == .observed, let source, case .text(let app)? = try? db.scalar("SELECT app FROM all_events WHERE id = ?", [.int(source)]),
           !app.isEmpty {
            text += " in \(app)"
        }
        return text
    }

    private static let linkWords: [String: (String, String)] = [
        "part_of": ("part of", "has part"), "about": ("about", "subject of"), "requires": ("requires", "required by"),
        "involves": ("involves", "involved in"), "uses": ("uses", "used by"), "at": ("at", "place of"),
    ]

    /// "Part of Acme rebrand, at Milan office, involves Marta." Newest first, at most 8. Notes about the thing are
    /// listed apart, Me and "understands" are left out.
    private func linkText(_ id: Int64) -> String? {
        let rows = (try? db.query("""
            SELECT e.link, e.from_node = ?1 AS outgoing, o.class, o.name, o.text FROM all_edges e
            JOIN all_nodes o ON o.id = CASE WHEN e.from_node = ?1 THEN e.to_node ELSE e.from_node END
            WHERE (e.from_node = ?1 OR e.to_node = ?1) AND e.valid_to IS NULL AND e.deleted = ''
              AND o.valid_to IS NULL AND o.deleted = '' AND o.class != 'Me' AND e.link != 'understands'
              AND NOT (e.link = 'about' AND e.to_node = ?1 AND o.class = 'Note')
            ORDER BY e.created DESC, e.id DESC LIMIT 8
            """, [.int(id)])) ?? []
        let links = rows.compactMap { row -> String? in
            guard let words = row.text("link").flatMap({ Self.linkWords[$0] }) else { return nil }
            let other = row.text("class") == "Note" ? "\"\(row.text("text") ?? "")\"" : row.text("name") ?? ""
            return "\(row.int("outgoing") == 1 ? words.0 : words.1) \(other)"
        }
        guard !links.isEmpty else { return nil }
        let text = links.joined(separator: ", ")
        return text.prefix(1).uppercased() + text.dropFirst() + "."
    }

    /// Up to 3 current Notes about a thing, newest first, each with its origin and date.
    private func notesText(_ id: Int64, _ context: LineContext) -> String? {
        let notes = ((try? db.query("""
            SELECT n.* FROM all_edges e JOIN all_nodes n ON n.id = e.from_node
            WHERE e.to_node = ? AND e.link = 'about' AND n.class = 'Note' AND e.valid_to IS NULL AND e.deleted = ''
              AND n.valid_to IS NULL AND n.deleted = '' ORDER BY n.created DESC, n.id DESC LIMIT 3
            """, [.int(id)])) ?? []).compactMap(Self.node)
        guard !notes.isEmpty else { return nil }
        return "Notes: " + notes.map { note in
            "\"\(note.text)\" (\(origin(note.origin, note.created, note.sourceEvent, context, capital: false))"
                + (context.stale.contains(note.id) ? ", may be outdated)" : ")")
        }.joined(separator: "; ") + "."
    }

    /// "About you:" then Me's name and the current Notes about Me: told, observed, imported; more confident first.
    private func aboutMe(_ context: LineContext) -> [String] {
        guard let me = ((try? db.query("SELECT * FROM all_nodes WHERE class = 'Me' AND deleted = '' LIMIT 1")) ?? []).first.flatMap(Self.node)
        else { return [] }
        let notes = ((try? db.query("""
            SELECT n.* FROM all_edges e JOIN all_nodes n ON n.id = e.from_node
            WHERE e.to_node = ? AND e.link = 'about' AND n.class = 'Note' AND e.valid_to IS NULL AND e.deleted = ''
              AND n.valid_to IS NULL AND n.deleted = ''
            ORDER BY CASE n.origin WHEN 'told' THEN 0 WHEN 'observed' THEN 1 ELSE 2 END, n.confidence DESC, n.created, n.id
            """, [.int(me.id)])) ?? []).compactMap(Self.node)
        let lines = (me.name.isEmpty ? [] : [line(me, context, links: false)]) + notes.map { line($0, context, links: false) }
        return lines.isEmpty ? [] : ["About you:"] + lines.map { "- " + $0 }
    }

    private func lastQuestions(on project: Int64, limit: Int) -> [MapEvent] {
        ((try? db.query("""
            SELECT * FROM all_events WHERE project = ? AND deleted = '' AND summary != '' ORDER BY time DESC, id DESC LIMIT ?
            """, [.int(project), .int(Int64(limit))])) ?? []).compactMap(Self.event)
    }

    private func nodes(_ ids: ArraySlice<Int64>) -> [MapNode] { ids.compactMap { try? node($0) } }

    func currentNodes(_ mapClass: MapClass) throws -> [MapNode] {
        try db.query("SELECT * FROM all_nodes WHERE class = ? AND valid_to IS NULL AND deleted = '' ORDER BY updated DESC, id DESC",
                     [.text(mapClass.rawValue)]).compactMap(Self.node)
    }

    /// The classes whose names the recogniser is given (P6.3) and the sound match learns (N3.2).
    static let spokenClasses: [MapClass] = [.project, .person, .tool, .organization]

    /// N3.2: the other names of the current things the recogniser is given, other name to name; nothing sensitive.
    /// A word heard for a name and corrected by the user is kept there ("also heard as", `addHeardAs`).
    func heardAs() throws -> [String: String] {
        var out: [String: String] = [:]
        for mapClass in Self.spokenClasses {
            for node in try currentNodes(mapClass) where !node.sensitive && !node.name.isEmpty {
                for alias in node.aliases where out[alias] == nil { out[alias] = node.name }
            }
        }
        return out
    }

    /// N3.2: `heard` kept once as an other name ("also heard as") of the current, not sensitive thing named `name`
    /// in a spoken class, the most recently seen first. Filtered like every write. False when there is no such
    /// thing, it already holds `heard`, or `heard` looks secret. Encrypted with the rest; Forget takes it with the thing.
    @discardableResult
    func addHeardAs(_ heard: String, name: String) throws -> Bool {
        let heard = Self.cleaned(heard, 200)
        guard !heard.isEmpty, !Librarian.looksSecret(heard) else { return false }
        // Never when `heard` is itself a name in the Map: "Marta" must not become another way to say "Marco".
        for mapClass in Self.spokenClasses where try currentNodes(mapClass).contains(where: { Self.sameName($0, heard) }) { return false }
        for mapClass in Self.spokenClasses {
            guard var node = try currentNodes(mapClass).first(where: { !$0.sensitive && Self.folded($0.name) == Self.folded(name) })
            else { continue }
            guard !Self.sameName(node, heard) else { return false }
            node.aliases.append(heard)
            try db.query("UPDATE main.nodes SET aliases = ?1, updated = ?2 WHERE id = ?3",
                         [.text(Self.json(node.aliases)), .text(Self.now()), .int(node.id)])
            return true
        }
        return false
    }

    /// The current Document whose path or address is `label`, the most recently seen first.
    func documentWithLabel(_ label: String) -> MapNode? {
        ((try? db.query("""
            SELECT * FROM all_nodes WHERE class = 'Document' AND valid_to IS NULL AND deleted = ''
              AND (json_extract(properties, '$.path.value') = ?1 OR json_extract(properties, '$.address.value') = ?1)
            ORDER BY updated DESC, id DESC LIMIT 1
            """, [.text(label)])) ?? []).first.flatMap(Self.node)
    }

    /// The current Project a thing is part of, the newest link first.
    func projectOf(_ id: Int64) -> MapNode? {
        ((try? db.query("""
            SELECT p.* FROM all_edges e JOIN all_nodes p ON p.id = e.to_node
            WHERE e.from_node = ? AND e.link = 'part_of' AND e.valid_to IS NULL AND e.deleted = ''
              AND p.class = 'Project' AND p.valid_to IS NULL AND p.deleted = ''
            ORDER BY e.created DESC, e.id DESC LIMIT 1
            """, [.int(id)])) ?? []).first.flatMap(Self.node)
    }

    /// A path as it is; a web address without anything after `?` or `#` (5.9).
    static func label(_ pathOrAddress: String) -> String {
        pathOrAddress.hasPrefix("/") ? pathOrAddress : String(pathOrAddress.prefix { $0 != "?" && $0 != "#" })
    }

    /// Same name or other name, ignoring capitals and accents (5.9).
    static func sameName(_ node: MapNode, _ name: String) -> Bool {
        let fold = { (s: String) in s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).trimmingCharacters(in: .whitespaces) }
        return ([node.name] + node.aliases).contains { fold($0) == fold(name) }
    }

    /// The class values of `properties`, each without the origin that set it.
    static func values(_ properties: String) -> [String: Any] {
        let object = (try? JSONSerialization.jsonObject(with: Data(properties.utf8))) as? [String: Any] ?? [:]
        return object.compactMapValues { ($0 as? [String: Any])?["value"] }
    }

    static func iso(_ date: Date) -> String { date.formatted(.iso8601) }
}

/// Stored dates in words, for result lines.
enum MapDate {
    /// ISO 8601 with a time, or a day alone (YYYY-MM-DD, read in UTC so it never shifts a day).
    static func parse(_ text: String) -> (date: Date, dayOnly: Bool)? {
        if text.count == 10, let day = try? Date(text, strategy: .iso8601.year().month().day()) { return (day, true) }
        return (try? Date(text, strategy: .iso8601)).map { ($0, false) }
    }

    /// "12 Nov", or "12 Nov 2025" in another year; with `withTime`, "20 Nov 15:00" when the date has a time.
    static func say(_ text: String, now: Date, withTime: Bool = false) -> String? {
        guard let (date, dayOnly) = parse(text) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = dayOnly ? TimeZone(identifier: "UTC") : .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = formatter.timeZone
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        formatter.dateFormat = (sameYear ? "d MMM" : "d MMM yyyy") + (withTime && !dayOnly ? " HH:mm" : "")
        return formatter.string(from: date)
    }

    /// Past its date: a day alone lasts until its end.
    static func isPast(_ text: String, now: Date) -> Bool {
        guard let (date, dayOnly) = parse(text) else { return false }
        return date.addingTimeInterval(dayOnly ? 86_400 : 0) < now
    }
}
