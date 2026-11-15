#if DEBUG
import Foundation

/// `--debug-brain-check voice` (P6.3): for each made-up spoken case, its two hearings (given as input, never
/// recorded) and a made-up screen go through the real Conductor; it counts whether the route is the expected one and,
/// for act cases, whether the Doer's first action hits the expected control. Logs counts and fixed words only: never
/// a hearing.
enum BrainVoiceCheck {
    struct Case {
        /// Best first, as the recogniser gives them.
        var hearings: [Hearing]
        var packet: ContextPacket
        var route: Route
        /// For act: the id of the pointable the first action must hit.
        var control: String?
    }

    // shortcut: four made-up cases so it compiles; at merge the lead wires the Senses builder's 40 sentences, each
    // with the recogniser's two hearings.
    static var cases: [Case] {
        let pages = ContextPacket(
            appName: "Pages", bundleID: "com.apple.iWork.Pages", windowTitle: "Made-up bakery menu.pages",
            visibleText: "Orbit Bakery\nSpring menu\nSourdough loaf 4.50\nRye roll 1.20", cursor: nil,
            windowFrame: CGRect(x: 0, y: 0, width: 1200, height: 800),
            pointables: [Pointable(id: "e1", role: "AXButton", label: "Bold", frame: CGRect(x: 300, y: 60, width: 28, height: 28)),
                         Pointable(id: "e2", role: "AXButton", label: "Italic", frame: CGRect(x: 330, y: 60, width: 28, height: 28)),
                         Pointable(id: "e3", role: "AXButton", label: "Table", frame: CGRect(x: 500, y: 20, width: 50, height: 40)),
                         Pointable(id: "e4", role: "AXButton", label: "Chart", frame: CGRect(x: 560, y: 20, width: 50, height: 40))])
        func two(_ it: String, _ en: String, italianFirst: Bool) -> [Hearing] {
            let a = Hearing(language: "it-IT", text: it, confidence: italianFirst ? 0.8 : 0.3)
            let b = Hearing(language: "en-US", text: en, confidence: italianFirst ? 0.3 : 0.8)
            return italianFirst ? [a, b] : [b, a]
        }
        return [
            Case(hearings: two("metti in grassetto il titolo", "met tin gras set oil tea tolo", italianFirst: true), packet: pages, route: .act, control: "e1"),
            Case(hearings: two("ma udii a da tei bol", "how do I add a table", italianFirst: false), packet: pages, route: .guide),
            Case(hearings: two("cosa vuol dire rye roll", "cosa vole dire rye roll", italianFirst: true), packet: pages, route: .explain),
            Case(hearings: two("la mela blu corre sotto il tetto", "lamella blue core so toil tetto", italianFirst: true), packet: pages, route: .unclear),
        ]
    }

    static func run() async {
        let provider = ClaudeProvider(), usd0 = CallLog.spentUSD
        let all = cases
        var routed = 0, acts = 0, hit = 0
        for (n, item) in all.enumerated() {
            let best = item.hearings.first?.text ?? ""
            var route = "error", action = "none"
            do {
                let got = try await Conductor.route(best, packet: item.packet, spoken: item.hearings, provider: provider)
                route = got.rawValue
                if got == item.route { routed += 1 }
            } catch {
                route = "error \(BrainError(error))"
            }
            if let control = item.control {
                acts += 1
                do {
                    let next = try await Doer.next(best, packet: item.packet, done: [], spoken: item.hearings, provider: provider)
                    if case .act(_, .element(let id)?, _, _) = next, id == control {
                        hit += 1
                        action = "hit"
                    } else {
                        action = "miss"
                    }
                } catch {
                    action = "error \(BrainError(error))"
                }
            }
            shellLog("voice check \(n + 1) \(item.hearings.map { Spoken.code($0.language) }) expected \(item.route.rawValue): route \(route), action \(action)")
        }
        shellLog("voice check done: route \(routed)/\(all.count), first action on the control \(hit)/\(acts), $\(CallLog.spentUSD - usd0)")
    }
}
#endif
