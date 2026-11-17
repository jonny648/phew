import SwiftUI

/// The menu's "Shortcuts he may run" (NB.5): the user's Shortcuts by name, each with a tick (off by default) and a
/// second mark, "safe to run without asking" (off by default). Only a ticked one can ever run; the Hand reads the same
/// ticks when it runs one. Names only; nothing is run from here.
@MainActor
final class ShortcutsModel: ObservableObject {
    struct Line: Identifiable, Equatable {
        var name: String
        var allowed = false
        var safe = false
        var id: String { name }
    }

    @Published private(set) var lines: [Line] = []
    @Published private(set) var loaded = false
    let ticks: ShortcutTicks
    /// The user's shortcuts by name: the Hand's runner (`shortcuts list`); tests give made-up names.
    let list: @Sendable () -> [String]
    /// After the list changed, so the panel fits it.
    var changed: () -> Void = {}

    init(ticks: ShortcutTicks, list: @escaping @Sendable () -> [String]) {
        (self.ticks, self.list) = (ticks, list)
    }

    /// Off the main thread: the system's program may take a moment.
    func refresh() async {
        let list = list
        let names = await Task.detached { list() }.value
        lines = names.map { Line(name: $0, allowed: ticks.isAllowed($0), safe: ticks.isSafe($0)) }
        loaded = true
        changed()
    }

    /// Unticking takes the safe mark away too (`ShortcutTicks.set`); the view ticks one marked safe.
    func set(_ name: String, allowed: Bool, safe: Bool) {
        ticks.set(name, allowed: allowed, safe: safe)
        lines = lines.map { Line(name: $0.name, allowed: ticks.isAllowed($0.name), safe: ticks.isSafe($0.name)) }
        shellLog("shortcuts: \(ticks.allowed.count) ticked, \(ticks.safe.count) safe")
    }
}

struct ShortcutsView: View {
    @ObservedObject var model: ShortcutsModel

    static let help = "Tick a shortcut to let a research task run it. A shortcut can do anything, so one not marked "
        + "safe waits for your confirm in the menu bar. Mark safe only one that changes nothing you would miss."

    var body: some View {
        PanelList(isEmpty: model.lines.isEmpty, emptyLine: model.loaded ? "No shortcuts found." : "Reading your shortcuts…",
                  help: Self.help) {
            ForEach(model.lines) { line in
                Row(title: line.name) {
                    Toggle("May run", isOn: Binding(get: { line.allowed }, set: { model.set(line.name, allowed: $0, safe: $0 && line.safe) }))
                        .toggleStyle(.checkbox)
                    Toggle("Safe", isOn: Binding(get: { line.safe }, set: { model.set(line.name, allowed: line.allowed || $0, safe: $0) }))
                        .toggleStyle(.checkbox)
                }
            }
        }
        .task { await model.refresh() }
    }
}
