import SwiftUI

/// D3 (docs/05-map.md 5.8.1): the saved conversations, from Memory, "Conversations…": newest first, each with Open and
/// Forget. Open puts it on the conversation card, where a reply continues it. Words pass as the Map gave them; no log
/// holds them.
@MainActor
final class ConversationsList: ObservableObject {
    @Published private(set) var items: [SavedThread] = []
    @Published private(set) var loaded = false
    @Published private(set) var busy = false
    /// The last Forget's line, or why it failed.
    @Published private(set) var line: String?
    @Published private(set) var failed = false
    let brain: any Brain
    /// Shows the thread on the card. Set by whoever opens the panel.
    var onOpen: ((Int64) -> Void)?

    init(brain: any Brain) { self.brain = brain }

    func refresh() async {
        items = await brain.savedThreads()
        loaded = true
    }

    func open(_ id: Int64) {
        shellLog("conversations: open")
        onOpen?(id)
    }

    /// One at a time, so a double click cannot forget twice. The list is read again after.
    func forget(_ id: Int64) async {
        guard !busy else { return }
        busy = true
        let said = await brain.forgetThread(id)
        failed = said == nil
        line = said ?? "Could not forget it. Please try again."
        await refresh()
        busy = false
        shellLog("conversations: forget ok \(!failed), items \(items.count)")
    }

    /// "17 Nov 2026 15:00 · Acme rebrand".
    static func detail(_ thread: SavedThread) -> String {
        ([MapStore.exportDate(thread.time, withTime: true) ?? ""] + (thread.project.isEmpty ? [] : [thread.project]))
            .filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

struct ConversationsView: View {
    @ObservedObject var list: ConversationsList

    var body: some View {
        PanelList(isEmpty: list.items.isEmpty, emptyLine: list.loaded ? "No saved conversations." : "Loading…",
                  help: list.line ?? "Conversations are kept as text in the Map, never what was on screen.",
                  problem: list.failed ? list.line : nil) {
            ForEach(list.items) { thread in
                Row(title: thread.first.isEmpty ? "(no question)" : thread.first, detail: ConversationsList.detail(thread)) {
                    Button("Forget") { Task { await list.forget(thread.id) } }.buttonStyle(TextButton())
                    Button("Open") { list.open(thread.id) }.buttonStyle(QuietButton())
                }
                .disabled(list.busy)
            }
        }
        .task { await list.refresh() }
    }
}
