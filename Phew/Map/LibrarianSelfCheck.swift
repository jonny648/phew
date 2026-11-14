#if DEBUG
import Foundation

/// The live Librarian check of P5.2, for `--debug-brain-check`: 10 made-up interactions through the real
/// Librarian with the writes each must give (pass mark 8 of 10), then the sensitive case (a made-up bank balance
/// and private message stored marked sensitive, a password not stored). Each case runs on its own Map in memory,
/// never the real one. Costs about half a cent. Logs case names, PASS or FAIL and counts only: no made-up text,
/// no model text.
enum LibrarianSelfCheck {
    struct Result: Equatable { var passed = 0, total = 0, sensitive = false }

    static func run(provider: any ModelProvider, now: Date = .now) async -> Result {
        var result = Result()
        for item in cases {
            let ok = await check(item, provider: provider, now: now)
            result.total += 1
            if ok { result.passed += 1 }
            shellLog("librarian check \(ok ? "PASS" : "FAIL") \(item.name)")
        }
        result.sensitive = await check(sensitiveCase, provider: provider, now: now)
        shellLog("librarian check \(result.sensitive ? "PASS" : "FAIL") \(sensitiveCase.name)")
        shellLog("librarian check: \(result.passed)/\(result.total) interactions (pass mark 8), sensitive \(result.sensitive ? "PASS" : "FAIL")")
        return result
    }

    struct Case: Sendable {
        var name: String
        var question: String
        var answer = ""
        var route = Route.explain
        var app = "Safari"
        var window = ""
        var path: String? = nil
        /// Facts the Map already holds before the call.
        var seed: @Sendable (MapStore) async throws -> Void = { _ in }
        /// True when the Map holds the expected writes.
        var expect: @Sendable (MapStore) async -> Bool
    }

    private static func check(_ item: Case, provider: any ModelProvider, now: Date) async -> Bool {
        guard let store = try? MapStore() else { return false }
        do {
            try await item.seed(store)
            let packet = ContextPacket(appName: item.app, bundleID: "", windowTitle: item.window, visibleText: "", cursor: nil,
                                       documentPath: item.path)
            _ = try await store.learn(question: item.question, answer: item.answer, route: item.route, packet: packet,
                                      provider: provider, now: now)
            return await item.expect(store)
        } catch {
            return false
        }
    }

    // MARK: - Reading the Map back

    private static func nodes(_ store: MapStore, _ mapClass: MapClass, named words: String...) async -> [MapNode] {
        await store.visibleNodes().filter { node in
            node.mapClass == mapClass && words.allSatisfy { (node.name + " " + node.aliases.joined(separator: " ") + " " + node.text).localizedCaseInsensitiveContains($0) }
        }
    }

    private static func has(_ store: MapStore, _ link: MapLink, from: MapNode?, to: MapNode?) async -> Bool {
        guard let from, let to else { return false }
        return await store.visibleEdges().contains { $0.link == link && $0.from == from.id && $0.to == to.id }
    }

    private static func meNotes(_ store: MapStore) async -> [MapNode] {
        let all = await store.visibleNodes()
        guard let me = all.first(where: { $0.mapClass == .me }) else { return [] }
        let about = Set(await store.visibleEdges().filter { $0.link == .about && $0.to == me.id }.map(\.from))
        return all.filter { about.contains($0.id) }
    }

    private static func seedProject(_ store: MapStore, _ name: String) async throws -> Int64 {
        try await store.add(MapNode(mapClass: .project, kind: "client job", name: name, origin: .told))
    }

    // MARK: - The cases (all made up)

    static let cases: [Case] = [
        Case(name: "topic asked", question: "What does kerning mean here?",
             answer: "Kerning is the space between two specific letters. In this poster the A and V are too far apart; tighten that pair.",
             app: "Figma", window: "Spring poster – Typography 2", expect: { store in
                 guard let topic = await nodes(store, .topic, named: "kerning").first else { return false }
                 let strength = await store.visibleEdges().first { $0.link == .understands && $0.to == topic.id }?.strength
                 let asked = await store.visibleEvents().contains { $0.kind == .ask && $0.mentions.contains(topic.id) }
                 return strength == 0.3 && asked
             }),
        Case(name: "told preference", question: "Remember that I prefer short answers in Italian", route: .remember, expect: { store in
            await meNotes(store).contains { $0.origin == .told && ($0.text.localizedCaseInsensitiveContains("italian") || $0.text.localizedCaseInsensitiveContains("italiano")) }
        }),
        Case(name: "task with due date", question: "Remember that the poster brief for Typography 2 is due on 2026-11-20", route: .remember,
             expect: { store in
                 guard let task = await nodes(store, .task, named: "poster").first, let project = await nodes(store, .project, named: "typography").first
                 else { return false }
                 let linked = await has(store, .partOf, from: task, to: project)
                 return linked && task.origin == .told && MapStore.values(task.properties)["due"] as? String == "2026-11-20"
             }),
        Case(name: "correction", question: "No, the poster brief is due on 2026-11-22, not the 20th", route: .remember,
             seed: { store in
                 let project = try await seedProject(store, "Typography 2")
                 let task = try await store.add(MapNode(mapClass: .task, kind: "assignment", name: "Poster brief",
                                                        properties: MapStore.properties(["due": ("2026-11-20", Origin.told)]), origin: .told))
                 _ = try await store.add(MapEdge(from: task, to: project, link: .partOf, origin: .told))
             }, expect: { store in
                 let tasks = await nodes(store, .task, named: "poster")
                 guard tasks.count == 1, let task = tasks.first, MapStore.values(task.properties)["due"] as? String == "2026-11-22" else { return false }
                 return await store.history(task.id).contains { MapStore.values($0.properties)["due"] as? String == "2026-11-20" }
             }),
        Case(name: "person and organization", question: "Who sent me this?",
             answer: "This email is from Marta Vellani, the marketing lead at Acme Biscotti. She asks for the logo in blue by Friday.",
             app: "Mail", window: "Logo colours – Acme Biscotti", expect: { store in
                 let person = await nodes(store, .person, named: "marta").first
                 let org = await nodes(store, .organization, named: "acme").first
                 return await has(store, .partOf, from: person, to: org)
             }),
        Case(name: "event at a place", question: "When is this meeting?",
             answer: "It is the design review with Marta on 2026-11-20 at 15:00 in Room B12 of the Milan office.",
             app: "Calendar", window: "Design review", expect: { store in
                 guard let event = await nodes(store, .event, named: "review").first,
                       (MapStore.values(event.properties)["start"] as? String)?.hasPrefix("2026-11-20") == true else { return false }
                 let place = await store.visibleNodes().first { $0.mapClass == .place && $0.name.localizedCaseInsensitiveContains("B12") }
                 return await has(store, .at, from: event, to: place)
             }),
        Case(name: "document with its path", question: "Which version of the logo is this?",
             answer: "This is logo-v3.fig, the third version of the Acme Biscotti logo, with the blue wordmark.",
             app: "Figma", window: "logo-v3", path: "/Users/someone/Acme/logo-v3.fig", expect: { store in
                 await store.visibleNodes().contains {
                     $0.mapClass == .document && MapStore.values($0.properties)["path"] as? String == "/Users/someone/Acme/logo-v3.fig"
                 }
             }),
        Case(name: "tool used by a project", question: "How do I export the banner from Figma for the Acme rebrand?",
             answer: "Select the banner frame, open the Export section in the right panel, choose PNG at 2x and click Export.",
             route: .guide, app: "Figma", window: "Banner – Acme rebrand",
             seed: { store in _ = try await seedProject(store, "Acme rebrand") }, expect: { store in
                 let tool = await nodes(store, .tool, named: "figma").first
                 let project = await nodes(store, .project, named: "acme")
                 return tool != nil && project.count == 1
             }),
        Case(name: "understood topic", question: "I understand kerning now, you can stop explaining it", route: .remember,
             seed: { store in
                 let topic = try await store.add(MapNode(mapClass: .topic, kind: "skill", name: "Kerning", origin: .observed))
                 try await store.moveUnderstanding(topic: topic, said: nil, asked: true)
             }, expect: { store in
                 let topics = await nodes(store, .topic, named: "kerning")
                 guard topics.count == 1, let topic = topics.first else { return false }
                 return await store.visibleEdges().first { $0.link == .understands && $0.to == topic.id }?.strength == 0.9
             }),
        Case(name: "known person reused", question: "What does Marta want changed?",
             answer: "Marta asks to move the Acme rebrand launch to December and to use the darker blue on the landing page.",
             app: "Mail", window: "Re: launch – Acme rebrand",
             seed: { store in
                 let project = try await seedProject(store, "Acme rebrand")
                 let marta = try await store.add(MapNode(mapClass: .person, kind: "client", name: "Marta", origin: .told))
                 _ = try await store.add(MapEdge(from: project, to: marta, link: .involves, origin: .told))
             }, expect: { store in
                 let people = await store.visibleNodes().filter { $0.mapClass == .person && $0.name.localizedCaseInsensitiveContains("marta") }
                 let projects = await nodes(store, .project, named: "acme")
                 let marta = people.first?.id ?? -1
                 let onProject = await store.visibleEvents().contains { $0.project == projects.first?.id && $0.mentions.contains(marta) }
                 return people.count == 1 && projects.count == 1 && onProject
             }),
    ]

    static let sensitiveCase = Case(
        name: "sensitive and password", question: "What is on this page?",
        answer: """
            This is your Banca Fittizia account page. The current balance is 3,214.50 euros. In the side panel there is a \
            private message from Luca Ferrandi saying he has been unwell and cannot come on Monday. The login box below \
            shows the password Brisk-Otter-77 typed in a normal text field.
            """,
        app: "Safari", window: "Banca Fittizia – Accounts", expect: { store in
            let nodes = await store.visibleNodes(currentOnly: false)
            let events = await store.visibleEvents()
            let money = nodes.contains { $0.sensitive && ($0.text + $0.name).range(of: #"3[.,]?214|balance|saldo"#, options: [.regularExpression, .caseInsensitive]) != nil }
            let message = nodes.contains { $0.sensitive && ($0.text + $0.name).range(of: #"luca|unwell|message"#, options: [.regularExpression, .caseInsensitive]) != nil }
            let everything = nodes.map { [$0.name, $0.text, $0.properties, $0.aliases.joined()].joined(separator: " ") } + events.map(\.summary)
            let password = everything.contains { $0.localizedCaseInsensitiveContains("Brisk-Otter") || $0.localizedCaseInsensitiveContains("Otter-77") }
            return money && message && !password
        })
}
#endif
