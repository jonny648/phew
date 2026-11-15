import AppKit
import SwiftUI

/// Imported memory, the Shell side (phase PB, docs/05-map.md 5.10): the paste box, a project folder's files, the
/// tick list. One small panel opened from the menu, non-activating like the others. Nothing is sent before Sort, and
/// nothing is kept before Keep. The pasted text, the files and the candidates live here, in memory only, and are
/// dropped when the panel closes. Logs carry counts and fixed words only.
@MainActor
final class ImportModel: ObservableObject {
    enum Stage: Equatable {
        case paste
        /// The files of the chosen folder, before anything is sent.
        case files
        case sorting
        case ticks
        /// One line and Done: what Keep wrote, or what "Undo last import" did.
        case line(String)
    }

    /// The picker's sources. Claude Code comes only from a project folder.
    static let sources: [ImportSource] = [.claude, .chatgpt, .gemini, .other]
    static let sendLine = "Nothing is sent until you press Sort. Then this text goes to Claude to be sorted into facts."
    static let filesLine = "These files go to Claude to be sorted into facts."

    @Published private(set) var stage: Stage { didSet { if stage != oldValue { onStage(stage) } } }
    @Published var text = ""
    @Published var source = ImportSource.claude
    @Published var candidates: [ImportCandidate] = []
    /// The chosen folder's files, read on this Mac; nothing of them is sent before Sort.
    @Published private(set) var memory: ProjectMemory?
    /// The fixed line saying the text was cut.
    @Published private(set) var note: String?
    @Published private(set) var problem: String?
    @Published private(set) var busy = false
    let brain: any Brain
    /// Each new stage: the panel fits it, and takes the keyboard only while the paste box shows.
    var onStage: (Stage) -> Void = { _ in }
    var onClose: () -> Void = {}
    /// A missing or refused key: the key row opens, as after an answer.
    var onKeyProblem: (BrainError) -> Void = { _ in }
    /// After a keep, so the menu's undo entry reads the last import again.
    var onImported: () -> Void = {}
    private var work: Task<Void, Never>?

    init(brain: any Brain, stage: Stage = .paste) {
        self.brain = brain
        self.stage = stage
    }

    var canSort: Bool {
        switch stage {
        case .paste: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .files: !(memory?.files.isEmpty ?? true)
        default: false
        }
    }
    var tickedCount: Int { candidates.filter(\.ticked).count }
    var keepTitle: String { tickedCount == 1 ? "Keep 1 fact" : "Keep \(tickedCount) facts" }
    var allTicked: Bool { !candidates.isEmpty && candidates.allSatisfy(\.ticked) }

    /// After the folder window: the folder's allowed files, read on this Mac. Sends nothing.
    func read(folder: URL) {
        memory = brain.projectMemory(folder: folder)
        stage = .files
        shellLog("import panel: folder read, \(memory?.files.count ?? 0) files, \(memory?.refused.count ?? 0) refused")
    }

    /// Sort: the one moment the text or the files leave the Mac.
    func sort() {
        guard canSort else { return }
        let back = stage, brain = brain
        let call: @Sendable () async throws -> ImportSort
        if back == .files, let memory {
            call = { try await brain.sortImport(memory) }
            shellLog("import panel: sort asked, \(memory.files.count) files")
        } else {
            let text = text, source = source
            call = { try await brain.sortImport(text, source: source) }
            shellLog("import panel: sort asked, \(text.count) characters, source \(source.rawValue)")
        }
        problem = nil
        stage = .sorting
        work = Task {
            do {
                let sort = try await call()
                guard !Task.isCancelled else { return }
                candidates = sort.candidates
                note = sort.note
                stage = .ticks
                shellLog("import panel: \(candidates.count) candidates, \(tickedCount) ticked, cut \(note != nil)")
            } catch {
                guard !Task.isCancelled else { return }
                stage = back
                fail(BrainError(error))
            }
        }
    }

    /// Cancel while sorting: the call is cancelled and its answer, if one still comes, is thrown away.
    func cancel() {
        guard stage == .sorting else { return }
        work?.cancel()
        work = nil
        stage = memory == nil ? .paste : .files
        shellLog("import panel: sort cancelled")
    }

    func tickAll(_ ticked: Bool) {
        for index in candidates.indices { candidates[index].ticked = ticked }
    }

    /// Writes the ticked candidates only, as one import.
    func keep() async {
        let chosen = candidates.filter(\.ticked)
        guard !busy, stage == .ticks, !chosen.isEmpty else { return }
        busy = true
        defer { busy = false }
        problem = nil
        do {
            let kept = try await brain.keepImport(chosen)
            guard !candidates.isEmpty else { return }  // the panel closed meanwhile
            // No import number: the Map could not take it, and its line says so.
            guard kept.number != nil else {
                problem = kept.card
                return shellLog("import panel: keep, no map")
            }
            shellLog("import panel: kept, \(chosen.count) ticked of \(candidates.count), \(kept.stored) stored, \(kept.seen) seen")
            drop()
            stage = .line(kept.card)
            onImported()
        } catch {
            fail(BrainError(error))
        }
    }

    /// Discard, Cancel, Done: nothing is kept, and the panel closes.
    func close() {
        drop()
        onClose()
    }

    /// The panel closed, by any way: the text, the files and the candidates go, and a sort under way is cancelled.
    func drop() {
        work?.cancel()
        work = nil
        text = ""
        candidates = []
        memory = nil
        note = nil
    }

    private func fail(_ error: BrainError) {
        problem = TextCard.sentence(for: error)
        if error == .noKey || error == .badKey { onKeyProblem(error) }
        shellLog("import panel: failed, \(error)")
    }
}

/// The menu's "Undo last import": off while there is nothing to undo; its title names the source and the count.
@MainActor
final class ImportUndo: ObservableObject {
    @Published private(set) var last: ImportInfo?
    let brain: any Brain
    private var observer: Any?

    init(brain: any Brain) { self.brain = brain }

    var title: String {
        guard let last else { return "Undo last import" }
        return "Undo last import (\(last.source), \(last.count == 1 ? "1 fact" : "\(last.count) facts"))"
    }

    func refresh() async { last = await brain.lastImport() }

    /// Reads the last import again each time a menu opens, so the entry is right when the user sees it.
    func watchMenus() {
        observer = NotificationCenter.default.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { Task { await self?.refresh() } }
        }
    }

    /// The Brain's line, or a fixed one when there was nothing to undo.
    func undo() async -> String {
        let line = await brain.undoLastImport()
        await refresh()
        shellLog("import undo: undone \(line != nil)")
        return line ?? "There was no import to undo."
    }
}

// MARK: - The panel

struct ImportView: View {
    @ObservedObject var model: ImportModel

    var body: some View {
        Group {
            switch model.stage {
            case .paste: paste
            case .files: files
            case .sorting: sorting
            case .ticks: ticks
            case .line(let line): done(line)
            }
        }
        .foregroundStyle(Design.Ink.primary)
        .padding(Design.Space.s20)
        .frame(width: Design.Size.panelWidth, height: short ? Design.Size.emptyPanelHeight : Design.Size.panelHeight,
               alignment: .topLeading)
    }

    private var short: Bool {
        switch model.stage {
        case .sorting, .line: true
        default: false
        }
    }

    private var paste: some View {
        VStack(alignment: .leading, spacing: Design.Space.s12) {
            Picker("From", selection: $model.source) {
                ForEach(ImportModel.sources, id: \.self) { Text(verbatim: $0 == .other ? "Other" : $0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            TextEditor(text: $model.text)
                .font(Design.Text.body)
                .scrollContentBackground(.hidden)
                .padding(Design.Space.s4)
                .background(Design.Ink.fill, in: RoundedRectangle(cornerRadius: Design.Radius.bubble))
                .overlay(alignment: .topLeading) {
                    if model.text.isEmpty {
                        Text("Paste the memory list your assistant wrote.")
                            .font(Design.Text.body)
                            .foregroundStyle(Design.Ink.tertiary)
                            .padding(.leading, Design.Space.s8 + 1)
                            .padding(.top, Design.Space.s4)
                            .allowsHitTesting(false)
                    }
                }
            HelpLine(text: ImportModel.sendLine, problem: model.problem)
            HStack(spacing: Design.Space.s8) {
                // Always works, even if keyboard shortcuts do not reach the box.
                Button("Paste") { model.text = NSPasteboard.general.string(forType: .string) ?? model.text }
                    .buttonStyle(QuietButton())
                Spacer()
                Button("Sort") { model.sort() }.buttonStyle(MainButton()).disabled(!model.canSort)
            }
        }
    }

    private var files: some View {
        let memory = model.memory ?? ProjectMemory(projectName: "")
        return VStack(alignment: .leading, spacing: Design.Space.s12) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: memory.projectName).font(Design.Text.strong).lineLimit(1)
                Spacer()
                Text(verbatim: "\(memory.files.count == 1 ? "1 file" : "\(memory.files.count) files"), \(Self.size(memory.totalBytes))")
                    .font(Design.Text.small)
                    .foregroundStyle(Design.Ink.secondary)
            }
            if memory.files.isEmpty && memory.refused.isEmpty {
                Text("No CLAUDE.md and no Claude Code memory files in this folder.")
                    .font(Design.Text.body)
                    .foregroundStyle(Design.Ink.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(memory.files, id: \.name) { file in
                            Row(title: file.name) { Text(verbatim: Self.size(file.bytes)).font(Design.Text.small).foregroundStyle(Design.Ink.secondary) }
                        }
                        ForEach(memory.refused, id: \.self) { name in
                            Row(title: name) { Text("Not read").font(Design.Text.small).foregroundStyle(Design.Ink.secondary) }
                        }
                    }
                }
            }
            HelpLine(text: ImportModel.filesLine, problem: model.problem)
            HStack(spacing: Design.Space.s8) {
                Spacer()
                Button("Cancel") { model.close() }.buttonStyle(QuietButton())
                Button("Sort") { model.sort() }.buttonStyle(MainButton()).disabled(!model.canSort)
            }
        }
    }

    private var sorting: some View {
        VStack(spacing: Design.Space.s12) {
            HStack(spacing: Design.Space.s8) {
                PresenceDot(breathing: true)
                Text("Sorting into facts…").font(Design.Text.body).foregroundStyle(Design.Ink.secondary)
            }
            Button("Cancel") { model.cancel() }.buttonStyle(QuietButton())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var ticks: some View {
        VStack(alignment: .leading, spacing: Design.Space.s12) {
            if model.candidates.isEmpty {
                Text("No facts were found to keep.")
                    .font(Design.Text.body)
                    .foregroundStyle(Design.Ink.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach($model.candidates) { $candidate in TickRow(candidate: $candidate) }
                    }
                }
            }
            HelpLine(text: model.note ?? "Only the ticked facts are kept. Instructions start unticked.", problem: model.problem)
            HStack(spacing: Design.Space.s8) {
                Button(model.allTicked ? "Untick all" : "Tick all") { model.tickAll(!model.allTicked) }
                    .buttonStyle(TextButton())
                    .disabled(model.candidates.isEmpty)
                Spacer()
                Button("Discard") { model.close() }.buttonStyle(QuietButton())
                Button(model.keepTitle) { Task { await model.keep() } }
                    .buttonStyle(MainButton())
                    .disabled(model.busy || model.tickedCount == 0)
            }
        }
    }

    private func done(_ line: String) -> some View {
        VStack(alignment: .leading, spacing: Design.Space.s12) {
            Text(verbatim: line)
                .font(Design.Text.body)
                .lineSpacing(Design.Text.bodySpacing)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            HStack {
                Spacer()
                Button("Done") { model.close() }.buttonStyle(MainButton())
            }
        }
    }

    static func size(_ bytes: Int) -> String { ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file) }
}

/// One candidate: its checkbox and sentence, then its tags. Laid out like `Row`.
private struct TickRow: View {
    @Binding var candidate: ImportCandidate

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Design.Space.s8) {
            Toggle(isOn: $candidate.ticked) {
                Text(verbatim: candidate.sentence)
                    .font(Design.Text.body)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .toggleStyle(.checkbox)
            Spacer(minLength: 0)
            // The tag style of 15.4, the key caps' look.
            if candidate.sensitive { Keycap(key: "sensitive") }
            if candidate.instruction { Keycap(key: "instruction") }
        }
        .padding(.vertical, Design.Space.s8)
        .frame(minHeight: Design.Size.row, alignment: .leading)
        .overlay(alignment: .bottom) { Design.Ink.hairline.frame(height: Design.Size.hairline) }
    }
}
