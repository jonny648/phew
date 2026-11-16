import SwiftUI

/// What the Limits panel shows: today's spend and requests against the ceilings, read through the Brain.
@MainActor
final class LimitsModel: ObservableObject {
    @Published private(set) var today: LimitsToday?
    let brain: any Brain

    /// The daily dollar ceilings offered; 0 is no limit.
    static let presets: [Double] = [1, 3, 10, 0]

    init(brain: any Brain) { self.brain = brain }

    func refresh() async { today = await brain.limitsToday() }

    func set(_ usd: Double) {
        brain.setDayLimit(usd: usd)
        shellLog("limits: daily dollar ceiling changed")
        Task { await refresh() }
    }

    static func dollars(_ usd: Double) -> String { usd == 0 ? "No limit" : String(format: "$%.2f", usd) }
}

/// Shown in a `MenuPanel`: non-activating, the front app keeps the focus.
struct LimitsView: View {
    @ObservedObject var model: LimitsModel

    var body: some View {
        let today = model.today ?? LimitsToday()
        PanelList(isEmpty: false, emptyLine: "",
                  help: "Phew sends nothing more today once a limit is reached. It starts again at midnight.") {
            Row(title: "Spent today", detail: String(format: "$%.2f", today.spentUSD) + " of " + LimitsModel.dollars(today.usdPerDay).lowercased()) {
                EmptyView()
            }
            Row(title: "Requests today", detail: "\(today.requests) of " + (today.requestsPerDay == 0 ? "no limit" : "\(today.requestsPerDay)")) {
                EmptyView()
            }
            Row(title: "Daily limit") {
                ForEach(LimitsModel.presets, id: \.self) { usd in
                    Button(usd == 0 ? "No limit" : String(format: "$%.0f", usd)) { model.set(usd) }
                        .buttonStyle(QuietButton())
                        .opacity(today.usdPerDay == usd ? 1 : 0.6)
                }
            }
        }
    }
}
