import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// A small panel opened from the menu bar menu: Recently deleted, Export the Map, About and licences. Non-activating like the
/// other panels, and it becomes key only if a click needs it (selecting text), so the front app keeps the focus.
@MainActor
final class MenuPanel {
    private(set) var panel: NSPanel?

    func show(title: String, _ view: some View) {
        close()
        let panel = EditPanel(contentRect: .zero, styleMask: [.titled, .closable, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = title
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true  // buttons work without the panel taking key
        panel.level = .floating  // Phew is never active, so a normal panel would sink behind the front app
        panel.contentView = NSHostingView(rootView: view)
        panel.setContentSize(panel.contentView?.fittingSize ?? NSSize(width: 400, height: 320))
        panel.center()
        panel.orderFrontRegardless()
        self.panel = panel
        shellLog("menu panel shown: \(title), key \(panel.isKeyWindow), phew front \(phewIsFront)")
    }

    func close() {
        panel?.contentView = nil
        panel?.close()
        panel = nil
    }

    /// Closes with `leave`: opacity to 0, then gone.
    func fadeOut() {
        guard let panel else { return }
        self.panel = nil
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Design.Motion.leave
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.contentView = nil
            panel.close()
        })
    }
}

// MARK: - Recently deleted

/// What the Recently deleted panel shows. Labels pass through as the Map gave them.
@MainActor
final class DeletedList: ObservableObject {
    @Published private(set) var items: [DeletedItem] = []
    @Published private(set) var loaded = false
    @Published private(set) var busy = false
    @Published private(set) var problem: String?
    let brain: any Brain

    init(brain: any Brain) { self.brain = brain }

    func refresh() async {
        items = await brain.recentlyDeleted()
        loaded = true
    }

    func restore(_ id: Int64) async { await act("Could not restore it. Please try again.") { await self.brain.restore(id) } }
    func deleteNow(_ id: Int64) async { await act("Could not delete it. Please try again.") { await self.brain.deleteNow(id) } }

    /// One action at a time, so a double click cannot run it twice. The list is read again after each.
    private func act(_ failure: String, _ action: () async -> Bool) async {
        guard !busy else { return }
        busy = true
        let ok = await action()
        problem = ok ? nil : failure
        await refresh()
        busy = false
        shellLog("recently deleted action ok \(ok), items \(items.count)")
    }

    static func daysLeftText(_ days: Int) -> String {
        switch days {
        case ...0: "Less than a day left"
        case 1: "1 day left"
        default: "\(days) days left"
        }
    }
}

struct DeletedView: View {
    @ObservedObject var list: DeletedList

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if list.items.isEmpty {
                Text(list.loaded ? "Nothing in Recently deleted." : "Loading…")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(list.items) { row($0) }
                    }
                }
            }
            Text(list.problem ?? "Forgotten things wait here for 30 days, then they are wiped for good.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 420, height: 320, alignment: .topLeading)
        .task { await list.refresh() }
    }

    private func row(_ item: DeletedItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.label).lineLimit(2)
                Text(DeletedList.daysLeftText(item.daysLeft)).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Restore") { Task { await list.restore(item.id) } }
            Button("Delete now") { Task { await list.deleteNow(item.id) } }
        }
        .disabled(list.busy)
    }
}

// MARK: - About and licences

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Phew keeps the Map encrypted with SQLCipher Community Edition.")
                Text(Self.sqlcipherNotice)
                    .font(.system(.footnote, design: .monospaced))
                Text(Self.sqliteNotice).font(.footnote)
            }
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .frame(width: 560, height: 420)
    }

    /// Verbatim from https://www.zetetic.net/sqlcipher/license/SQLCIPHER_COMMUNITY_EDITION_LICENSE.txt
    static let sqlcipherNotice = """
    Copyright (c) 2008-2026, ZETETIC, LLC
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:
        * Redistributions of source code must retain the above copyright
          notice, this list of conditions and the following disclaimer.
        * Redistributions in binary form must reproduce the above copyright
          notice, this list of conditions and the following disclaimer in the
          documentation and/or other materials provided with the distribution.
        * Neither the name of the ZETETIC LLC nor the
          names of its contributors may be used to endorse or promote products
          derived from this software without specific prior written permission.

    THIS SOFTWARE IS PROVIDED BY ZETETIC LLC ''AS IS'' AND ANY
    EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
    WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
    DISCLAIMED. IN NO EVENT SHALL ZETETIC LLC BE LIABLE FOR ANY
    DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
    (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
    ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
    (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
    SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
    """

    /// Verbatim from the Open Source Legal Notices on https://www.zetetic.net/sqlcipher/license/
    static let sqliteNotice = "SQLite (http://sqlite.org/); Released to the Public Domain (http://sqlite.org/copyright.html); The author disclaims copyright to this source code.; This product includes software developed by the SQLite Project"
}

// MARK: - Export the Map (P5.10)

/// What the Export panel does: asks the Brain for the Map as Markdown, with sensitive facts only when ticked, then
/// hands it to `save`, which writes it only where the user chooses. Logs no path and no word of the Map.
@MainActor
final class MapExporter: ObservableObject {
    @Published var includeSensitive = false
    @Published private(set) var busy = false
    @Published private(set) var status: String?
    let brain: any Brain
    /// Asks where to save and writes the text there. The file's name when saved, nil when cancelled.
    let save: @MainActor (String) async throws -> String?

    init(brain: any Brain, save: @escaping @MainActor (String) async throws -> String? = MapExporter.saveInFolderWindow) {
        self.brain = brain
        self.save = save
    }

    /// One export at a time, so a double click cannot open two save windows.
    func export() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        guard let text = await brain.exportMap(includeSensitive: includeSensitive) else {
            status = "The Map isn't available right now, so nothing was saved."
            return shellLog("map export: no map")
        }
        do {
            let saved = try await save(text)
            status = saved.map { "Saved as \($0)." }
            shellLog("map export: saved \(saved != nil), sensitive \(includeSensitive), lines \(text.split(separator: "\n").count)")
        } catch {
            status = "Could not save the file. Please try again."
            shellLog("map export: write failed")
        }
    }

    /// The system folder window. Phew becomes active only while it is open: the one exception to never taking the
    /// focus (CLAUDE.md). When it closes, saved or cancelled, the app that was in front before is made active again.
    /// Cancel writes nothing.
    static func saveInFolderWindow(_ text: String) async throws -> String? {
        let front = NSWorkspace.shared.frontmostApplication
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Phew Map.md"
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.canCreateDirectories = true
        NSApp.activate()
        let response = await withCheckedContinuation { done in panel.begin { done.resume(returning: $0) } }
        defer {
            let back = front.map { $0 != .current && $0.activate(from: .current, options: []) } ?? false
            shellLog("map export: folder window closed, front app active again \(back), phew front \(phewIsFront)")
        }
        guard response == .OK, let url = panel.url else { return nil }
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url.lastPathComponent
    }
}

struct ExportView: View {
    @ObservedObject var exporter: MapExporter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Save the Map as one Markdown file you can read. The file is not encrypted, and forgetting something later does not change it.")
                .fixedSize(horizontal: false, vertical: true)
            Toggle("Include sensitive facts", isOn: $exporter.includeSensitive)
            HStack {
                Spacer()
                Button("Export…") { Task { await exporter.export() } }
                    .disabled(exporter.busy)
            }
            Text(exporter.status ?? "It is saved only where you choose.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 400, alignment: .leading)
    }
}
