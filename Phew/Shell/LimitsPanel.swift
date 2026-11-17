import SwiftUI

/// What the Limits panel shows: today's spend and requests against the ceilings, read through the Brain.
@MainActor
final class LimitsModel: ObservableObject {
    @Published private(set) var today: LimitsToday?
    let brain: any Brain

    /// The daily dollar ceilings offered; 0 is no limit.
    static let presets: [Double] = [1, 3, 10, 0]
    /// NA.13: the request ceilings offered, each within `Limits.minuteBounds` and `dayBounds`; there is no "no limit".
    static let minutePresets = [10, 30, 60], dayPresets = [100, 400, 2000]

    init(brain: any Brain) { self.brain = brain }

    func refresh() async { today = await brain.limitsToday() }

    func set(_ usd: Double) {
        brain.setDayLimit(usd: usd)
        shellLog("limits: daily dollar ceiling changed")
        Task { await refresh() }
    }

    func set(perMinute: Int) {
        brain.setMinuteLimit(requests: perMinute)
        shellLog("limits: requests a minute changed")
        Task { await refresh() }
    }

    func set(perDay: Int) {
        brain.setDayLimit(requests: perDay)
        shellLog("limits: requests a day changed")
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
            Row(title: "Requests a day") {
                ForEach(LimitsModel.dayPresets, id: \.self) { count in
                    Button("\(count)") { model.set(perDay: count) }
                        .buttonStyle(QuietButton())
                        .opacity(today.requestsPerDay == count ? 1 : 0.6)
                }
            }
            Row(title: "Requests a minute") {
                ForEach(LimitsModel.minutePresets, id: \.self) { count in
                    Button("\(count)") { model.set(perMinute: count) }
                        .buttonStyle(QuietButton())
                        .opacity(today.requestsPerMinute == count ? 1 : 0.6)
                }
            }
        }
    }
}
