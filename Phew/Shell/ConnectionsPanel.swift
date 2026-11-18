import SwiftUI

/// The menu's "Connections" (NB.7): the tools he may reach, each with Connect, what he may do there (each tool marked
/// reads or writes), a change of its tools with Accept, and Disconnect. Reaches the Brain only through `Brain`.
@MainActor
final class ConnectionsModel: ObservableObject {
    /// Door 2: Phew's own sign-in, the fixed list.
    @Published private(set) var own: [ConnectorStatus] = []
    /// Door 1 (NB.9): the connectors of the user's Claude account, through Claude Code, and its switches.
    @Published private(set) var claudeAccount: [ConnectorStatus] = []
    @Published private(set) var account = ClaudeAccount()
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
        account = await brain.claudeAccount()
        changed()
    }

    /// Door 1's busy mark while Claude Code lists the connectors.
    static let listing = "claudeAccount"

    /// "Use my Claude account". On: the connectors are listed at once.
    func use(_ on: Bool) async {
        busy = Self.listing
        problem = await brain.useClaudeAccount(on)
        busy = nil
        await refresh()
    }

    func list() async {
        busy = Self.listing
        problem = await brain.listClaudeAccount()
        busy = nil
        await refresh()
    }

    /// NF.4: a connector that offers no tools cannot be ticked.
    func tick(_ id: String, _ on: Bool) async {
        guard !on || Self.canTick(claudeAccount.first { $0.id == id }) else { return }
        await brain.tickClaudeConnector(id, on)
        await refresh()
    }

    func research(_ on: Bool) async {
        await brain.researchThroughClaudeAccount(on)
        await refresh()
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
        if status.door == .claudeAccount, status.tools.isEmpty { return signInFirst }
        guard status.connected else { return status.door == .claudeAccount ? "Not ticked: he does not use it." : "Not connected." }
        let writes = status.tools.filter(\.writes).count, reads = status.tools.count - writes
        return "\(reads) tool\(reads == 1 ? "" : "s") that read. \(writes) that write: each listed on the card, or waiting for your confirm when a task asks."
    }

    /// NF.4: a connector of the Claude account that lists no tools is not signed in there.
    static let signInFirst = "Sign in on Claude first."

    /// NF.4: only a connector that offers tools can be ticked.
    static func canTick(_ status: ConnectorStatus?) -> Bool { status.map { !$0.tools.isEmpty } ?? false }

    /// One tool for the list: its name and what it does there.
    static func line(_ tool: ConnectorToolLine) -> String { "\(tool.name): \(tool.writes ? "writes" : "reads")" }
}

struct ConnectionsView: View {
    @ObservedObject var model: ConnectionsModel

    static let help = "He reads in the tools you connect when a task needs them. A change there is listed on the card, "
        + "and one a task asks for waits for your confirm in the menu. Disconnect removes the sign-in from the Keychain."
    static let door1 = "Claude Code, signed in by you, reaches your account's connectors. Your Claude plan pays. Only a task's words go to it."
    static let research = "A research task runs through Claude Code with web search and the connectors you tick. Explanations, guides and jobs stay on your API key."

    var body: some View {
        PanelList(isEmpty: false, emptyLine: "No tools to connect.", help: Self.help, problem: model.problem) {
            ForEach(model.own) { server in section(server) }
            // Door 1 (NB.9): the connectors of the user's Claude account, under their own heading.
            Text("Through your Claude account").font(Design.Text.small).foregroundStyle(Design.Ink.secondary)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, Design.Space.s12)
            if model.account.found {
                Row(title: "Use my Claude account", detail: Self.door1) {
                    Toggle("", isOn: Binding(get: { model.account.on }, set: { on in Task { await model.use(on) } }))
                        .labelsHidden().toggleStyle(.switch).disabled(model.busy != nil)
                }
                if model.account.on {
                    Row(title: "Research through my Claude account", detail: Self.research) {
                        Toggle("", isOn: Binding(get: { model.account.research }, set: { on in Task { await model.research(on) } }))
                            .labelsHidden().toggleStyle(.switch)
                    }
                    ForEach(model.claudeAccount) { server in section(server) }
                    Button(model.busy == ConnectionsModel.listing ? "Listing…" : "Refresh") { Task { await model.list() } }
                        .buttonStyle(QuietButton()).disabled(model.busy != nil)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.top, Design.Space.s4)
                }
            } else {
                Row(title: ClaudeCodeDoor.line(.missing)) { EmptyView() }
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
            } else {
                Toggle("", isOn: Binding(get: { server.connected }, set: { on in Task { await model.tick(server.id, on) } }))
                    .labelsHidden().toggleStyle(.checkbox).disabled(!server.connected && !ConnectionsModel.canTick(server))
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
