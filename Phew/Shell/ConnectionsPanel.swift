import SwiftUI

/// The menu's "Connections" (NB.7): the tools he may reach, each with Connect, what he may do there (each tool marked
/// reads or writes), a change of its tools with Accept, and Disconnect. Reaches the Brain only through `Brain`.
@MainActor
final class ConnectionsModel: ObservableObject {
    /// Door 2: Phew's own sign-in, the fixed list.
    @Published private(set) var own: [ConnectorStatus] = []
    /// Door 1 (NB.9): the connectors of the user's Claude account, through Claude Code. Its section and its switch
    /// "Use my Claude account" are added by the door 1 builder; empty until then.
    @Published private(set) var claudeAccount: [ConnectorStatus] = []
    @Published private(set) var problem: String?
    /// The server being connected, while its sign-in runs.
    @Published private(set) var busy: String?
    let brain: any Brain
    /// Opens the sign-in page in the browser: only from `connect`, on the user's press.
    let open: @Sendable (URL) -> Void
    /// After the list changed, so the panel fits it.
    var changed: () -> Void = {}

    init(brain: any Brain, open: @escaping @Sendable (URL) -> Void) {
        self.brain = brain
        self.open = open
    }

    func refresh() async {
        let all = await brain.connectors()
        own = all.filter { $0.door == .own }
        claudeAccount = all.filter { $0.door == .claudeAccount }
        changed()
    }

    func connect(_ id: String) async {
        busy = id
        problem = await brain.connect(id, open: open)
        busy = nil
        await refresh()
        shellLog("connections: connect \(problem == nil ? "done" : "not done")")
    }

    func accept(_ id: String) async {
        problem = await brain.acceptTools(id)
        await refresh()
    }

    func disconnect(_ id: String) async {
        await brain.disconnect(id)
        problem = nil
        await refresh()
    }

    /// The row's second line: how many tools read and how many write, or that it is not connected.
    static func summary(_ status: ConnectorStatus) -> String {
        guard status.connected else { return "Not connected." }
        let writes = status.tools.filter(\.writes).count, reads = status.tools.count - writes
        return "\(reads) tool\(reads == 1 ? "" : "s") that read. \(writes) that write: each listed on the card, or waiting for your confirm when a task asks."
    }

    /// One tool for the list: its name and what it does there.
    static func line(_ tool: ConnectorToolLine) -> String { "\(tool.name): \(tool.writes ? "writes" : "reads")" }
}

struct ConnectionsView: View {
    @ObservedObject var model: ConnectionsModel

    static let help = "He reads in the tools you connect when a task needs them. A change there is listed on the card, "
        + "and one a task asks for waits for your confirm in the menu. Disconnect removes the sign-in from the Keychain."

    var body: some View {
        PanelList(isEmpty: model.own.isEmpty && model.claudeAccount.isEmpty, emptyLine: "No tools to connect.",
                  help: Self.help, problem: model.problem) {
            ForEach(model.own) { server in section(server) }
            // Door 1 (NB.9): the connectors of the user's Claude account go here, under their own heading.
            if !model.claudeAccount.isEmpty {
                Text("Through your Claude account").font(Design.Text.small).foregroundStyle(Design.Ink.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.top, Design.Space.s12)
                ForEach(model.claudeAccount) { server in section(server) }
            }
        }
        .task { await model.refresh() }
    }

    @ViewBuilder private func section(_ server: ConnectorStatus) -> some View {
        Row(title: server.name, detail: ConnectionsModel.summary(server)) {
            if server.door == .own {
                if server.connected {
                    Button("Disconnect") { Task { await model.disconnect(server.id) } }.buttonStyle(QuietButton())
                } else {
                    Button(model.busy == server.id ? "Signing in…" : "Connect") { Task { await model.connect(server.id) } }
                        .buttonStyle(MainButton()).disabled(model.busy != nil)
                }
            }
        }
        if let change = server.change {
            Row(title: change.line(server.name)) {
                Button("Accept") { Task { await model.accept(server.id) } }.buttonStyle(QuietButton())
            }
        }
        if server.connected, !server.tools.isEmpty {
            DisclosureGroup("What he may do there") {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(server.tools, id: \.self) { tool in
                        Text(verbatim: ConnectionsModel.line(tool)).font(Design.Text.small).foregroundStyle(Design.Ink.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(Design.Text.small)
            .padding(.vertical, Design.Space.s4)
        }
    }
}
