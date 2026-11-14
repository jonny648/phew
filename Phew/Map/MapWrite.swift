import Foundation

/// What one Librarian run did, for the card (5.9) and the tests. Ids only, and the card's one line.
struct LibrarianOutcome: Sendable, Equatable {
    /// The past question written, nil on a forget, a question back, or a remember with nothing stored.
    var event: Int64?
    /// Things, Notes and links created.
    var stored: [Int64] = []
    var storedLinks: [Int64] = []
    /// Facts that took a new value or were ended by a correction (5.5).
    var replaced: [Int64] = []
    /// Notes of kind "unconfirmed": a weaker source kept beside a stronger one.
    var unconfirmed: [Int64] = []
    /// Stored facts confirmed again.
    var seen: [Int64] = []
    /// Proposals code dropped: a class or link outside the lists, bad ends, unknown labels, secrets.
    var dropped = 0
    var forgot: Forgotten?
    /// Remember route: the Librarian was not sure which fact was meant. Nothing was written.
    var askBack: String?
    /// Remember route: the card's one line. Empty after an answer.
    var card = ""
}

/// One forget: its id in Recently deleted and the line the card showed.
struct Forgotten: Sendable, Equatable {
    var id: Int64
    var label: String
    /// Other current sentences that still hold the name (5.5 "The name used elsewhere").
    var othersWithName: Int
}

/// A line of Recently deleted (5.5, roadmap P5.15).
struct RecentlyDeleted: Sendable, Equatable {
    var id: Int64
    var label: String
    var time: String
    var daysLeft: Int
}

/// The writing side of the Map: the Librarian's checked writes (5.9), priority and corrections (5.5), forget,
/// restore and the real delete (5.5, 5.12). The model proposes; this code checks every line and writes.
extension MapStore {
    static let daysInRecentlyDeleted = 30

    // MARK: - The Librarian (5.9)

    /// After an answer (route explain or guide) or alone on the remember route: one small-model call, then code
    /// checks and writes in one transaction. A failed call or a reply not in the form writes nothing and throws.
    /// `lastTurn`: the last question and answer still in working memory, for "forget that".
    func learn(question: String, answer: String, route: Route, packet: ContextPacket?, lastTurn: Turn? = nil,
               provider: any ModelProvider, now: Date = .now) async throws -> LibrarianOutcome {
        let brief = librarianBrief(question: question, answer: answer, route: route, packet: packet, lastTurn: lastTurn, now: now)
        let json = try await provider.complete(Librarian.request(brief))
        guard let reply = Librarian.decode(json) else {
            shellLog("librarian: reply not in the form, nothing written")
            throw BrainError.badOutput
        }
        return try apply(reply, brief)
    }

    /// The Librarian's call: only the labels of `packet` are read (app name, window title, document path), never
    /// its text, picture or elements. Stored facts: the detected Project, a text search with the question and the
    /// labels, and on the remember route what the last answer was about.
    func librarianBrief(question: String, answer: String, route: Route, packet: ContextPacket?, lastTurn: Turn? = nil,
                        now: Date = .now) -> LibrarianBrief {
        let appName = packet?.appName ?? "", windowTitle = packet?.windowTitle ?? "", path = packet?.documentPath
        let project = detectProject(appName: appName, windowTitle: windowTitle, documentPath: path, question: question)
        var ids = project.map { [$0.id] } ?? []
        var words = [question, appName, windowTitle]
        if route == .remember, let lastTurn {
            words += [lastTurn.question]
            let latest = try? db.scalar("SELECT mentions FROM all_events WHERE deleted = '' ORDER BY time DESC, id DESC LIMIT 1")
            if case .text(let mentions)? = latest { ids += Self.list(mentions) as [Int64] }
        }
        ids += search(words, limit: 10).map(\.id)
        var facts: [String: Int64] = [:], lines: [String] = []
        let context = LineContext(now: now, stale: Set(term("stale", now: now)))
        for id in ids where !facts.values.contains(id) && facts.count < 16 {
            guard let node = try? node(id), node.validTo == nil, node.mapClass != .me else { continue }
            let number = "f\(facts.count + 1)"
            facts[number] = id
            lines.append("\(number): \(line(node, context))")
        }
        let kinds = ((try? db.query("""
            SELECT class, group_concat(kind, ', ') AS kinds FROM (SELECT class, kind FROM all_nodes
              WHERE kind != '' AND kind != 'unconfirmed' AND deleted = '' AND valid_to IS NULL
              GROUP BY class, kind ORDER BY class, count(*) DESC) GROUP BY class ORDER BY class
            """)) ?? []).compactMap { row in row.text("class").map { "\($0): \(row.text("kinds") ?? "")" } }
        let projectLine = project.map { p in "\(facts.first { $0.value == p.id }?.key ?? "") \(p.name)" }
        let text = Librarian.text(question: question, answer: answer, route: route, appName: appName, windowTitle: windowTitle,
                                  documentPath: path, project: projectLine, lastTurn: lastTurn, facts: lines, kindsInUse: kinds, now: now)
        return LibrarianBrief(text: text, facts: facts, project: project?.id, route: route, appName: SecretsFilter.clean(appName), now: now)
    }

    /// Every check of 5.9 on one reply, then the writes in one transaction: things (with name matching and the
    /// priority of 5.5, value by value), the past question's Project, Notes, links, the "understands" strengths,
    /// and one past question that names what it mentions. On the remember route a forget or a question back
    /// writes nothing else.
    func apply(_ reply: LibrarianReply, _ brief: LibrarianBrief) throws -> LibrarianOutcome {
        var out = LibrarianOutcome()
        if brief.route == .remember {
            let ask = Self.cleaned(reply.askBack, 300)
            if !ask.isEmpty, !Librarian.looksSecret(ask) {
                out.askBack = ask
                out.card = ask
                return out
            }
            let ids = reply.forget.compactMap { brief.facts[Self.ref($0)] }
            if !ids.isEmpty, let forgotten = try forget(ids, now: brief.now) {
                out.forgot = forgotten
                out.card = forgotten.label
                return out
            }
        }
        let s = WriteState(brief: brief)
        return try db.transaction {
            try write(reply, s, &out)
            return out
        }
    }

    private func current(_ ref: String, _ s: WriteState) throws -> MapNode? {
        guard let id = s.refs[Self.ref(ref)], let node = try node(id), node.validTo == nil else { return nil }
        return node
    }

    private static func origin(_ text: String) -> Origin { text.lowercased() == "told" ? .told : .observed }

    private func write(_ reply: LibrarianReply, _ s: WriteState, _ out: inout LibrarianOutcome) throws {
        if let me = try db.scalar("SELECT id FROM all_nodes WHERE class = 'Me' AND deleted = ''").intValue { s.refs["me"] = me }

        // Things: Projects first, so a part_of to a new Project is known when its parts are matched.
        let things = reply.things.filter { MapStore.thingClass($0.mapClass) == .project }
            + reply.things.filter { MapStore.thingClass($0.mapClass) != .project }
        var topics: [(Int64, Bool?)] = []
        for thing in things {
            guard let id = try write(thing, reply, s, &out) else { out.dropped += 1; continue }
            if !thing.label.isEmpty { s.refs[MapStore.ref(thing.label)] = id }
            s.mention(id)
            if MapStore.thingClass(thing.mapClass) == .topic, !topics.contains(where: { $0.0 == id }) {
                topics.append((id, ["yes": true, "no": false][thing.understood.lowercased()]))
            }
        }

        let project = try s.brief.project ?? resolveProject(reply.project, s)
        for proposal in reply.notes { try write(proposal, project: project, s, &out) }
        for proposal in reply.links { try write(proposal, s, &out) }

        // "Understands": the strength is set here, from what the user said about the Topic (5.4).
        for (topic, said) in topics {
            try moveUnderstanding(topic: topic, said: said, asked: s.brief.route != .remember, now: s.brief.now)
        }

        let wrote = !(out.stored.isEmpty && out.replaced.isEmpty && out.unconfirmed.isEmpty && out.seen.isEmpty)
        if s.brief.route == .remember {
            guard wrote else { out.card = "Nothing was stored."; return }
            let card = MapStore.cleaned(reply.card, 200)
            out.card = card.isEmpty || Librarian.looksSecret(card) ? "Stored as you told me." : card
        }
        var summary = MapStore.cleaned(reply.summary, 400)
        if Librarian.looksSecret(summary) { summary = "" }
        let kind: EventKind = s.brief.route == .remember ? (s.corrected ? .correction : .tell) : s.brief.route == .guide ? .guide : .ask
        let event = try add(MapEvent(time: s.stamp, app: s.brief.appName, kind: kind, summary: summary, project: project,
                                           mentions: s.mentions))
        out.event = event
        // The past question is the source of what it produced (5.5).
        for file in ["main", "s"] {
            try db.query("UPDATE \(file).nodes SET source_event = ?1 WHERE id IN (SELECT value FROM json_each(?2))",
                         [.int(event), .text(MapStore.json(out.stored + out.unconfirmed))])
            try db.query("UPDATE \(file).edges SET source_event = ?1 WHERE id IN (SELECT value FROM json_each(?2))",
                         [.int(event), .text(MapStore.json(out.storedLinks))])
        }
    }

    // MARK: Things

    /// A thing: checked, matched by name to a stored one or created, its values written with priority.
    /// Nil when dropped: a class outside the list, Me, a Note, no name, or something that looks secret.
    private func write(_ thing: LibrarianReply.Thing, _ reply: LibrarianReply, _ s: WriteState, _ out: inout LibrarianOutcome) throws -> Int64? {
        guard let mapClass = MapStore.thingClass(thing.mapClass), mapClass != .me, mapClass != .note else { return nil }
        let name = MapStore.cleaned(thing.name, 200)
        let aliases = thing.otherNames.map { MapStore.cleaned($0, 200) }.filter { !$0.isEmpty && !Librarian.looksSecret($0) }
        guard !name.isEmpty, !Librarian.looksSecret(name) else { return nil }
        let origin = Self.origin(thing.origin)
        let validFrom = s.trueFrom(thing.date)
        var values: [String: Any] = [:]
        if mapClass == .task {
            if let due = MapStore.date(thing.due) { values["due"] = due }
            if let done = ["yes": true, "no": false][thing.done.lowercased()] { values["done"] = done }
        }
        if mapClass == .event {
            if let start = MapStore.date(thing.start) { values["start"] = start }
            if let end = MapStore.date(thing.end) { values["end"] = end }
        }
        var pathValue: String?
        let raw = MapStore.cleaned(thing.path, 1000)
        if mapClass == .document, !raw.isEmpty, !Librarian.looksSecret(raw) {
            pathValue = MapStore.label(raw)   // a web address loses what follows ? or # (5.9)
            values[raw.hasPrefix("/") || raw.hasPrefix("~") ? "path" : "address"] = pathValue
        }

        // Which stored thing this is: the fact the Librarian named when it is of the same class, else the name.
        let status = thing.status.lowercased()
        var existing: MapNode?
        if status == "same" || status == "replaces", let node = try current(thing.fact, s), node.mapClass == mapClass {
            existing = node
        }
        if existing == nil {
            let project = [MapClass.task, .document, .event].contains(mapClass) ? try projectInReply(of: thing.label, reply, s) : nil
            existing = try match(mapClass, name: name, path: pathValue, project: project)
        }
        if let existing {
            try merge(existing, name: name, kind: MapStore.kind(thing.kind), aliases: aliases, values: values,
                      replaces: status == "replaces", origin: origin, validFrom: validFrom, sensitive: thing.sensitive, s, &out)
            return existing.id
        }
        let id = try add(MapNode(mapClass: mapClass, kind: MapStore.kind(thing.kind), name: name,
                                       aliases: aliases.filter { !MapStore.folded($0).isEmpty && MapStore.folded($0) != MapStore.folded(name) },
                                       properties: MapStore.properties(values.mapValues { ($0, origin) }), origin: origin,
                                       sensitive: thing.sensitive, validFrom: validFrom, created: s.stamp, updated: s.stamp))
        out.stored.append(id)
        return id
    }

    /// The Project the reply puts a thing in, through a part_of link from its label. Nil: any Project matches.
    private func projectInReply(of label: String, _ reply: LibrarianReply, _ s: WriteState) throws -> Int64? {
        guard !label.isEmpty else { return nil }
        for link in reply.links where MapStore.ref(link.from) == MapStore.ref(label) && link.link.lowercased() == MapLink.partOf.rawValue {
            if let node = try current(link.to, s), node.mapClass == .project { return node.id }
        }
        return nil
    }

    /// The values of a stored thing, value by value (5.5): one nobody stated is filled by any source; a stated
    /// one is changed only by a source as strong or stronger, else kept beside it as an "unconfirmed" Note. A
    /// change first copies the old values into a history row. Name and kind change only on "replaces".
    private func merge(_ node: MapNode, name: String, kind: String, aliases: [String], values: [String: Any],
                                replaces: Bool, origin: Origin, validFrom: String, sensitive: Bool, _ s: WriteState,
                       _ out: inout LibrarianOutcome) throws {
        var row = node
        var stored = (try? JSONSerialization.jsonObject(with: Data(node.properties.utf8))) as? [String: Any] ?? [:]
        var changed = false, filled = false
        var doubts: [String] = []
        let strong = MapStore.rank(origin) >= MapStore.rank(node.origin)

        for (key, value) in values.sorted(by: { $0.key < $1.key }) {
            let old = stored[key] as? [String: Any]
            if let oldValue = old?["value"] {
                guard !MapStore.same(oldValue, value) else { continue }
                let oldOrigin = (old?["origin"] as? String).flatMap(Origin.init) ?? .imported
                if MapStore.rank(origin) >= MapStore.rank(oldOrigin) {
                    stored[key] = ["value": value, "origin": origin.rawValue]
                    changed = true
                } else {
                    doubts.append("\(node.name): \(MapStore.valueWords[key] ?? key) \(MapStore.say(value))")
                }
            } else {
                stored[key] = ["value": value, "origin": origin.rawValue]
                filled = true
            }
        }
        if replaces, !MapStore.sameName(node, name) {
            if strong { row.name = name; changed = true } else { doubts.append("\(node.name) may be called \(name)") }
        }
        if !kind.isEmpty, kind != node.kind {
            if node.kind.isEmpty { row.kind = kind; filled = true }
            else if replaces { if strong { row.kind = kind; changed = true } else { doubts.append("\(node.name) is a \(kind)") } }
        }
        for alias in aliases where !MapStore.sameName(row, alias) {
            row.aliases.append(alias)
            filled = true
        }
        row.properties = MapStore.properties(stored)

        let file = node.sensitive ? "s" : "main"
        if changed {
            // The old version: same values, true until the new fact, replaced by the living row (5.5).
            try db.query("""
                INSERT INTO \(file).nodes (id, class, kind, name, aliases, text, properties, origin, source_event, confidence,
                  sensitive, valid_from, valid_to, superseded_by, created, updated)
                SELECT ?1, class, kind, name, aliases, text, properties, origin, source_event, confidence, sensitive,
                  valid_from, ?2, id, created, updated FROM \(file).nodes WHERE id = ?3
                """, [.int(try db.nextID()), .text(validFrom), .int(node.id)])
            row.validFrom = validFrom
            out.replaced.append(node.id)
            s.corrected = true
        } else {
            out.seen.append(node.id)
        }
        let stronger = MapStore.rank(origin) > MapStore.rank(node.origin) ? origin : node.origin
        let confidence = changed || filled ? max(node.confidence, origin.startingConfidence) : MapStore.seenAgain(node.confidence, origin)
        try db.query("""
            UPDATE \(file).nodes SET name = ?1, kind = ?2, aliases = ?3, properties = ?4, origin = ?5, confidence = ?6,
              valid_from = ?7, updated = ?8 WHERE id = ?9
            """, [.text(row.name), .text(row.kind), .text(MapStore.json(row.aliases)), .text(row.properties), .text(stronger.rawValue),
                  .real(confidence), .text(row.validFrom), .text(s.stamp), .int(node.id)])
        for doubt in doubts { try unconfirmed(doubt, about: [node.id], origin: origin, validFrom: validFrom, sensitive: node.sensitive, s, &out) }
        if sensitive, !node.sensitive { try moveSensitive(node.id, true) }
    }

    /// The weaker side of a disagreement: a Note of kind "unconfirmed", written only by code (5.3, 5.5).
    private func unconfirmed(_ text: String, about: [Int64], origin: Origin, validFrom: String, sensitive: Bool, _ s: WriteState,
                             _ out: inout LibrarianOutcome) throws {
        let id = try add(MapNode(mapClass: .note, kind: "unconfirmed", text: SecretsFilter.clean(text), origin: origin,
                                       sensitive: sensitive, validFrom: validFrom, created: s.stamp, updated: s.stamp))
        for target in about {
            if let edge = try add(MapEdge(from: id, to: target, link: .about, origin: origin, validFrom: validFrom,
                                                created: s.stamp, updated: s.stamp)) { out.storedLinks.append(edge) }
        }
        out.unconfirmed.append(id)
        s.mention(id)
    }

    /// The past question's Project when code detected none: a label, a fact number or a stored Project's name.
    private func resolveProject(_ text: String, _ s: WriteState) throws -> Int64? {
        if let node = try current(text, s), node.mapClass == .project { return node.id }
        let name = MapStore.cleaned(text, 200)
        guard !name.isEmpty else { return nil }
        return try currentNodes(.project).first { MapStore.sameName($0, name) }?.id
    }

    // MARK: Notes

    private func write(_ proposal: LibrarianReply.Note, project: Int64?, _ s: WriteState, _ out: inout LibrarianOutcome) throws {
        let text = MapStore.cleaned(proposal.text, 500)
        guard !text.isEmpty, !Librarian.looksSecret(text) else { out.dropped += 1; return }
        let origin = Self.origin(proposal.origin)
        let validFrom = s.trueFrom(proposal.date)
        var about: [Int64] = []
        for ref in proposal.about {
            guard let node = try current(ref, s) else { out.dropped += 1; continue }
            if !about.contains(node.id) { about.append(node.id) }
        }
        let status = proposal.status.lowercased()
        let named = status == "same" || status == "replaces" ? try current(proposal.fact, s).flatMap { $0.mapClass == .note ? $0 : nil } : nil
        let namedAbout = try named.map { old in
            try db.query("SELECT to_node FROM all_edges WHERE from_node = ? AND link = 'about' AND valid_to IS NULL AND deleted = ''",
                         [.int(old.id)]).compactMap { $0.int("to_node") }
        } ?? []
        // A Note about nothing: about what the Note it replaces was about, else the Project of the question.
        if about.isEmpty, status == "replaces" { about = namedAbout }
        if about.isEmpty, let project { about = [project] }
        // The same sentence as a current Note, ignoring capitals and accents: seen again, not stored twice.
        let twin = try db.query("SELECT * FROM all_nodes WHERE class = 'Note' AND valid_to IS NULL AND deleted = ''")
            .compactMap(MapStore.node).first { MapStore.folded($0.text) == MapStore.folded(text) }
        if let seen = twin ?? (status == "same" ? named : nil) {
            try seenAgain(seen, origin, s, &out)
            return
        }
        var kind = MapStore.kind(proposal.kind)
        var replacing = status == "replaces" ? named : nil
        if let old = replacing, MapStore.rank(origin) < MapStore.rank(old.origin) {
            // A weaker source never replaces a stronger one: kept beside it, about the same things.
            kind = "unconfirmed"
            about += namedAbout.filter { !about.contains($0) }
            replacing = nil
        }
        let id = try add(MapNode(mapClass: .note, kind: kind, text: text, origin: origin, sensitive: proposal.sensitive,
                                       validFrom: validFrom, created: s.stamp, updated: s.stamp))
        for target in about {
            if let edge = try add(MapEdge(from: id, to: target, link: .about, origin: origin, validFrom: validFrom,
                                                created: s.stamp, updated: s.stamp)) { out.storedLinks.append(edge) }
        }
        if let old = replacing {
            // The old Note ends, replaced by the new one; its links end with it (5.5).
            for file in ["main", "s"] {
                try db.query("UPDATE \(file).nodes SET valid_to = ?1, superseded_by = ?2 WHERE id = ?3",
                                   [.text(validFrom), .int(id), .int(old.id)])
                try db.query("UPDATE \(file).edges SET valid_to = ?1 WHERE from_node = ?2 AND valid_to IS NULL",
                                   [.text(validFrom), .int(old.id)])
            }
            out.replaced.append(old.id)
            s.corrected = true
        }
        if kind == "unconfirmed" { out.unconfirmed.append(id) } else { out.stored.append(id) }
        s.mention(id)
    }

    /// Seen again (5.5): 0.1 more confidence, up to 0.9; the user confirming it sets it to 1.
    private func seenAgain(_ node: MapNode, _ origin: Origin, _ s: WriteState, _ out: inout LibrarianOutcome) throws {
        for file in ["main", "s"] {
            try db.query("UPDATE \(file).nodes SET confidence = ?1, updated = ?2 WHERE id = ?3",
                               [.real(MapStore.seenAgain(node.confidence, origin)), .text(s.stamp), .int(node.id)])
        }
        out.seen.append(node.id)
        s.mention(node.id)
    }

    // MARK: Links

    private func write(_ proposal: LibrarianReply.Link, _ s: WriteState, _ out: inout LibrarianOutcome) throws {
        guard let link = MapLink(rawValue: proposal.link.lowercased().trimmingCharacters(in: .whitespaces)), link != .understands,
              let from = try current(proposal.from, s), let to = try current(proposal.to, s), link.allows(from.mapClass, to.mapClass)
        else { out.dropped += 1; return }
        let origin = Self.origin(proposal.origin)
        let validFrom = s.trueFrom(proposal.date)
        let live = "valid_to IS NULL AND deleted = ''"
        if let same = try db.query("SELECT * FROM all_edges WHERE from_node = ? AND to_node = ? AND link = ? AND \(live)",
                                         [.int(from.id), .int(to.id), .text(link.rawValue)]).first.flatMap(MapStore.edge) {
            for file in ["main", "s"] {
                try db.query("UPDATE \(file).edges SET confidence = ?1, updated = ?2 WHERE id = ?3",
                                   [.real(MapStore.seenAgain(same.confidence, origin)), .text(s.stamp), .int(same.id)])
            }
            return
        }
        // "replaces f3": the current link of the same name from the same thing to f3 ends.
        var old: MapEdge?
        if proposal.status.lowercased() == "replaces", let target = try current(proposal.fact, s) {
            old = try db.query("SELECT * FROM all_edges WHERE from_node = ? AND to_node = ? AND link = ? AND \(live)",
                                     [.int(from.id), .int(target.id), .text(link.rawValue)]).first.flatMap(MapStore.edge)
            if let weaker = old, MapStore.rank(origin) < MapStore.rank(weaker.origin) {
                let words = MapStore.valueWords[link.rawValue] ?? link.rawValue
                try unconfirmed("\(from.name) \(words) \(to.mapClass == .note ? to.text : to.name)", about: [from.id], origin: origin,
                                validFrom: validFrom, sensitive: from.sensitive || to.sensitive, s, &out)
                return
            }
        }
        guard let id = try add(MapEdge(from: from.id, to: to.id, link: link, origin: origin, validFrom: validFrom,
                                             created: s.stamp, updated: s.stamp)) else { out.dropped += 1; return }
        out.storedLinks.append(id)
        if let old {
            for file in ["main", "s"] {
                try db.query("UPDATE \(file).edges SET valid_to = ?1, superseded_by = ?2 WHERE id = ?3",
                                   [.text(validFrom), .int(id), .int(old.id)])
            }
            out.replaced.append(old.id)
            s.corrected = true
        }
    }

    /// Name matching (5.9): a current thing of the same class with the same name or other name, ignoring capitals
    /// and accents; for a Task, a Document or an Event also in the same Project (none given: any Project). For a
    /// Document with a known path or address, that decides. Several: the one seen most recently.
    func match(_ mapClass: MapClass, name: String, path: String?, project: Int64?) throws -> MapNode? {
        if mapClass == .document, let path {
            if let document = documentWithLabel(path) { return document }
        }
        return try currentNodes(mapClass).first { node in
            guard Self.sameName(node, name) else { return false }
            // A Document stored with a different path is a different file.
            if mapClass == .document, path != nil, !Self.values(node.properties).filter({ ["path", "address"].contains($0.key) }).isEmpty {
                return false
            }
            guard let project, [.task, .document, .event].contains(mapClass), let stored = projectOf(node.id) else { return true }
            return stored.id == project
        }
    }

    // MARK: - Forget, restore, the real delete (5.5, 5.12)

    /// "Forget that": acts at once. The things (never Me), every past version, their links, the Notes about them with
    /// their past versions, and the past questions that mention them are hidden from every read and both text
    /// indexes. One `forgets` row holds the card's line; it goes to the sensitive file when any of it is sensitive.
    /// Writes no past question. Nil when there is nothing to forget.
    @discardableResult
    func forget(_ ids: [Int64], now: Date = .now) throws -> Forgotten? {
        try db.transaction {
            let me = try db.scalar("SELECT id FROM all_nodes WHERE class = 'Me'").intValue
            let roots = try ids.filter { $0 != me }.compactMap { try node($0) }.filter { $0.mapClass != .me }
            guard let first = roots.first else { return nil }
            var nodes = try withPastVersions(Set(roots.map(\.id)))
            let notes = try db.query("""
                SELECT DISTINCT e.from_node FROM all_edges e JOIN all_nodes n ON n.id = e.from_node
                WHERE e.link = 'about' AND n.class = 'Note' AND e.to_node IN (SELECT value FROM json_each(?))
                """, [.text(Self.json(Array(nodes)))]).compactMap { $0.int("from_node") }.filter { $0 != me }
            nodes = try withPastVersions(nodes.union(notes))
            let set: SQLValue = .text(Self.json(nodes.sorted()))
            let inSet = "IN (SELECT value FROM json_each(?1))"
            let edges = try db.query("SELECT id FROM all_edges WHERE from_node \(inSet) OR to_node \(inSet)", [set]).compactMap { $0.int("id") }
            let events = try db.query("""
                SELECT id FROM all_events WHERE project \(inSet) OR EXISTS (SELECT 1 FROM json_each(mentions) WHERE value \(inSet))
                """, [set]).compactMap { $0.int("id") }

            let label = try forgetLabel(first, nodes: nodes, edges: edges, events: events)
            let sensitive = try db.scalar("""
                SELECT count(*) FROM (SELECT id FROM s.nodes WHERE id \(inSet) UNION ALL SELECT id FROM s.events WHERE id IN (SELECT value FROM json_each(?2)))
                """, [set, .text(Self.json(events))]) != .int(0)
            let id = try db.nextID()
            try db.query("INSERT INTO \(sensitive ? "s" : "main").forgets (id, time, label) VALUES (?, ?, ?)",
                         [.int(id), .text(Self.iso(now)), .text(label)])
            let add = "deleted = CASE WHEN deleted = '' THEN json_array(?2) ELSE json_insert(deleted, '$[#]', ?2) END"
            for file in ["main", "s"] {
                for (table, rows) in [("nodes", Array(nodes)), ("edges", edges), ("events", events)] {
                    try db.query("UPDATE \(file).\(table) SET \(add) WHERE id IN (SELECT value FROM json_each(?1))",
                                 [.text(Self.json(rows)), .int(id)])
                }
            }
            let name = first.mapClass == .note ? "" : first.name
            let others = name.isEmpty ? 0 : search([name], limit: 50).filter {
                $0.mapClass == .note ? Self.folded($0.text).contains(Self.folded(name)) : false
            }.count
            return Forgotten(id: id, label: label, othersWithName: others)
        }
    }

    /// Restore: removes only this forget's id, so a row still hidden by another forget stays hidden. The triggers
    /// put what is visible again back into both text indexes. False when the forget is not there.
    @discardableResult
    func restore(_ forget: Int64) throws -> Bool {
        try db.transaction {
            guard try forgetExists(forget) else { return false }
            for file in ["main", "s"] {
                for table in ["nodes", "edges", "events"] {
                    try db.query("""
                        UPDATE \(file).\(table) SET deleted = coalesce((SELECT CASE WHEN count(*) = 0 THEN '' ELSE json_group_array(value) END
                          FROM json_each(deleted) WHERE value != ?1), '')
                        WHERE deleted != '' AND EXISTS (SELECT 1 FROM json_each(deleted) WHERE value = ?1)
                        """, [.int(forget)])
                }
                try db.query("DELETE FROM \(file).forgets WHERE id = ?", [.int(forget)])
            }
            return true
        }
    }

    /// The real delete of one forget (Delete now, or after 30 days). Its things, versions, Notes and links leave both
    /// files (secure delete is on). Every past question it hid loses those mentions and its summary; the emptied row
    /// is deleted unless it still mentions something else or another fact has it as its source. Things only linked to
    /// it stay. Every id that pointed at a wiped row is removed in the same transaction. The `forgets` row goes too.
    @discardableResult
    func deleteNow(_ forget: Int64) throws -> Bool {
        try db.transaction {
            guard try forgetExists(forget) else { return false }
            let hidden = "deleted != '' AND EXISTS (SELECT 1 FROM json_each(deleted) WHERE value = ?1)"
            let nodes = try db.query("SELECT id FROM all_nodes WHERE \(hidden)", [.int(forget)]).compactMap { $0.int("id") }
            let edges = try db.query("SELECT id FROM all_edges WHERE \(hidden)", [.int(forget)]).compactMap { $0.int("id") }
            let wiped: SQLValue = .text(Self.json(nodes)), wipedEdges: SQLValue = .text(Self.json(edges))
            let without = "coalesce((SELECT CASE WHEN count(*) = 0 THEN '' ELSE json_group_array(value) END FROM json_each(deleted) WHERE value != ?1), '')"
            for file in ["main", "s"] {   // first the rows, in both files, so no wiped row still counts as a source below
                try db.query("DELETE FROM \(file).edges WHERE id IN (SELECT value FROM json_each(?1)) OR from_node IN (SELECT value FROM json_each(?2)) OR to_node IN (SELECT value FROM json_each(?2))",
                             [wipedEdges, wiped])
                try db.query("DELETE FROM \(file).nodes WHERE id IN (SELECT value FROM json_each(?1))", [wiped])
                try db.query("UPDATE \(file).nodes SET superseded_by = NULL WHERE superseded_by IN (SELECT value FROM json_each(?1))", [wiped])
                try db.query("UPDATE \(file).edges SET superseded_by = NULL WHERE superseded_by IN (SELECT value FROM json_each(?1))", [wipedEdges])
            }
            for file in ["main", "s"] {
                // Any past question: the wiped ids leave its mentions and its Project.
                try db.query("""
                    UPDATE \(file).events SET mentions = (SELECT json_group_array(value) FROM json_each(mentions)
                      WHERE value NOT IN (SELECT value FROM json_each(?1)))
                    WHERE EXISTS (SELECT 1 FROM json_each(mentions) WHERE value IN (SELECT value FROM json_each(?1)))
                    """, [wiped])
                try db.query("UPDATE \(file).events SET project = NULL WHERE project IN (SELECT value FROM json_each(?1))", [wiped])
                // The past questions this forget hid: emptied, then deleted when nothing still needs them.
                try db.query("""
                    DELETE FROM \(file).events WHERE \(hidden) AND mentions = '[]'
                      AND NOT EXISTS (SELECT 1 FROM all_nodes WHERE source_event = \(file).events.id)
                      AND NOT EXISTS (SELECT 1 FROM all_edges WHERE source_event = \(file).events.id)
                    """, [.int(forget)])
                try db.query("UPDATE \(file).events SET summary = '', deleted = \(without) WHERE \(hidden)", [.int(forget)])
                try db.query("DELETE FROM \(file).forgets WHERE id = ?", [.int(forget)])
            }
            return true
        }
    }

    /// The real delete of every forget older than 30 days. Run when Phew starts and once a day. Returns how many.
    @discardableResult
    func purge(now: Date = .now) throws -> Int {
        let due = try db.query("""
            SELECT id FROM (SELECT id, time FROM main.forgets UNION ALL SELECT id, time FROM s.forgets)
            WHERE julianday(time) <= julianday(?) - ? ORDER BY time
            """, [.text(Self.iso(now)), .int(Int64(Self.daysInRecentlyDeleted))]).compactMap { $0.int("id") }
        for id in due { try deleteNow(id) }
        return due.count
    }

    /// Recently deleted: each forget with its line and the days left, newest first.
    func recentlyDeleted(now: Date = .now) -> [RecentlyDeleted] {
        let rows = (try? db.query("""
            SELECT id, time, label FROM (SELECT * FROM main.forgets UNION ALL SELECT * FROM s.forgets) ORDER BY time DESC, id DESC
            """)) ?? []
        return rows.compactMap { row in
            guard let id = row.int("id"), let time = row.text("time"), let date = MapDate.parse(time)?.date else { return nil }
            let elapsed = Int((now.timeIntervalSince(date) / 86_400).rounded(.down))
            return RecentlyDeleted(id: id, label: row.text("label") ?? "", time: time, daysLeft: max(0, Self.daysInRecentlyDeleted - elapsed))
        }
    }

    /// The old versions of a fact, newest first: a thing's history rows, or the Notes it replaced, with the date each
    /// stopped being true and what replaced it (`supersededBy`).
    func history(_ id: Int64) -> [MapNode] {
        var out: [MapNode] = [], next = [id]
        while let current = next.popLast() {
            let rows = ((try? db.query("SELECT * FROM all_nodes WHERE superseded_by = ? AND deleted = '' ORDER BY valid_to DESC, id DESC",
                                       [.int(current)])) ?? []).compactMap(Self.node)
            for row in rows where !out.contains(where: { $0.id == row.id }) {
                out.append(row)
                next.append(row.id)
            }
        }
        return out
    }

    /// For tests and the self-check: every visible row.
    func visibleNodes(currentOnly: Bool = true) -> [MapNode] {
        ((try? db.query("SELECT * FROM all_nodes WHERE deleted = '' AND (? = 0 OR valid_to IS NULL) ORDER BY id",
                        [.int(currentOnly ? 1 : 0)])) ?? []).compactMap(Self.node)
    }

    func visibleEdges(currentOnly: Bool = true) -> [MapEdge] {
        ((try? db.query("SELECT * FROM all_edges WHERE deleted = '' AND (? = 0 OR valid_to IS NULL) ORDER BY id",
                        [.int(currentOnly ? 1 : 0)])) ?? []).compactMap(Self.edge)
    }

    func visibleEvents() -> [MapEvent] {
        ((try? db.query("SELECT * FROM all_events WHERE deleted = '' ORDER BY id")) ?? []).compactMap(Self.event)
    }

    /// For tests: one number from a query on this Map.
    func count(_ sql: String, _ params: [SQLValue] = []) throws -> Int64 { try db.scalar(sql, params).intValue ?? -1 }

    // MARK: - Private

    private func forgetExists(_ id: Int64) throws -> Bool {
        try db.scalar("SELECT count(*) FROM (SELECT id FROM main.forgets UNION ALL SELECT id FROM s.forgets) WHERE id = ?", [.int(id)]) != .int(0)
    }

    /// The ids and every row whose "replaced by" chain leads to them.
    private func withPastVersions(_ ids: Set<Int64>) throws -> Set<Int64> {
        var all = ids
        while true {
            let more = try db.query("SELECT id FROM all_nodes WHERE superseded_by IN (SELECT value FROM json_each(?))",
                                    [.text(Self.json(Array(all)))]).compactMap { $0.int("id") }.filter { !all.contains($0) }
            if more.isEmpty { return all }
            all.formUnion(more)
        }
    }

    /// "Forgot Marta: 1 person, 4 notes, 3 links, 6 past questions. In Recently deleted for 30 days."
    private func forgetLabel(_ first: MapNode, nodes: Set<Int64>, edges: [Int64], events: [Int64]) throws -> String {
        let rows = try db.query("""
            SELECT class, count(*) AS n FROM all_nodes WHERE id IN (SELECT value FROM json_each(?)) AND valid_to IS NULL GROUP BY class ORDER BY class = 'Note', class
            """, [.text(Self.json(nodes.sorted()))])
        let links = try count("SELECT count(*) FROM all_edges WHERE id IN (SELECT value FROM json_each(?)) AND valid_to IS NULL", [.text(Self.json(edges))])
        func counted(_ n: Int64, _ one: String, _ many: String) -> String { "\(n) \(n == 1 ? one : many)" }
        var parts = rows.compactMap { row -> String? in
            guard let name = row.text("class"), let n = row.int("n"), n > 0 else { return nil }
            let one = name == "Note" ? "note" : name.lowercased()
            return counted(n, one, one == "person" ? "people" : one + "s")
        }
        if links > 0 { parts.append(counted(links, "link", "links")) }
        if !events.isEmpty { parts.append(counted(Int64(events.count), "past question", "past questions")) }
        let what = first.mapClass == .note ? "\"\(first.text.prefix(60))\"" : first.name
        return SecretsFilter.clean("Forgot \(what): \(parts.joined(separator: ", ")). In Recently deleted for \(Self.daysInRecentlyDeleted) days.")
    }

    // MARK: - Small helpers

    /// "T1", " f3 " → "t1", "f3": labels and fact numbers are compared ignoring capitals and spaces.
    static func ref(_ text: String) -> String { text.trimmingCharacters(in: .whitespaces).lowercased() }

    /// A writable thing class, ignoring capitals. Nil for anything else.
    static func thingClass(_ text: String) -> MapClass? {
        MapClass.allCases.first { $0.rawValue.lowercased() == text.trimmingCharacters(in: .whitespaces).lowercased() }
    }

    /// Every string from the reply: through the secrets filter again, trimmed, cut to a sane length.
    static func cleaned(_ text: String, _ limit: Int) -> String {
        String(SecretsFilter.clean(text).trimmingCharacters(in: .whitespacesAndNewlines).prefix(limit))
    }

    /// A kind: lower case, short. "unconfirmed" is written only by code.
    static func kind(_ text: String) -> String {
        let kind = String(cleaned(text, 40).lowercased())
        return kind == "unconfirmed" || Librarian.looksSecret(kind) ? "" : kind
    }

    /// A date that can be read: a day alone or ISO 8601 as given; a local time without a zone ("2026-11-20T15:00",
    /// the form the Librarian is asked for) as ISO 8601. Else nil: left empty (5.9).
    static func date(_ text: String) -> String? {
        let text = text.trimmingCharacters(in: .whitespaces)
        if MapDate.parse(text) != nil { return text }
        let local = DateFormatter()
        local.locale = Locale(identifier: "en_US_POSIX")
        for format in ["yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm"] {
            local.dateFormat = format
            if let date = local.date(from: text) { return iso(date) }
        }
        return nil
    }

    static func folded(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func rank(_ origin: Origin) -> Int { [Origin.imported: 0, .observed: 1, .told: 2][origin] ?? 0 }

    static func seenAgain(_ confidence: Double, _ origin: Origin) -> Double {
        origin == .told ? 1 : max(confidence, min(0.9, ((confidence + 0.1) * 10).rounded() / 10))
    }

    /// `{"due": {"value": …, "origin": "told"}}` (see MapRecall.swift), keys sorted so the same values give the same text.
    static func properties(_ values: [String: (Any, Origin)]) -> String {
        properties(values.mapValues { ["value": $0.0, "origin": $0.1.rawValue] })
    }

    static func properties(_ object: [String: Any]) -> String {
        (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }

    static func same(_ a: Any, _ b: Any) -> Bool {
        if let a = a as? Bool, let b = b as? Bool { return a == b }
        return "\(a)" == "\(b)"
    }

    static func say(_ value: Any) -> String {
        if let done = value as? Bool { return done ? "yes" : "no" }
        return "\(value)"
    }

    static let valueWords = ["due": "due", "done": "done", "start": "starts", "end": "ends", "path": "path", "address": "address",
                             "part_of": "part of", "about": "about", "requires": "requires", "involves": "involves", "uses": "uses", "at": "at"]
}

/// The state of one reply's writes, inside `MapStore.apply`'s transaction.
private final class WriteState {
    let brief: LibrarianBrief
    let stamp: String
    /// "f1" and "t1" (and "me") → node id.
    var refs: [String: Int64]
    var mentions: [Int64] = []
    var corrected = false

    init(brief: LibrarianBrief) {
        self.brief = brief
        stamp = MapStore.iso(brief.now)
        refs = brief.facts
    }

    func mention(_ id: Int64) { if !mentions.contains(id) { mentions.append(id) } }

    /// "True from": the date the Librarian gave when it can be read, else the time of the question (5.9).
    func trueFrom(_ date: String) -> String { MapStore.date(date) ?? stamp }
}
