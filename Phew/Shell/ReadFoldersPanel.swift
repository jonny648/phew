import SwiftUI

/// The menu's "Folders he may read" (NA.11): the folders a research task may read, each with Remove. Empty by default.
@MainActor
final class ReadFoldersModel: ObservableObject {
    @Published private(set) var folders: [URL]
    @Published private(set) var problem: String?
    let brain: any Brain
    /// After the list changed, so the panel fits it.
    var changed: () -> Void = {}

    init(brain: any Brain) {
        self.brain = brain
        folders = brain.readFolders()
    }

    static let refused = "Phew cannot read that folder: it is hidden or holds keys."

    func add(_ folder: URL) {
        problem = brain.addReadFolder(folder) ? nil : Self.refused
        folders = brain.readFolders()
        changed()
        shellLog("read folders: \(problem == nil ? "one added" : "one refused"), \(folders.count) on the list")
    }

    /// Closed from the next file call, also for a task already running.
    func remove(_ folder: URL) {
        brain.removeReadFolder(folder)
        folders = brain.readFolders()
        changed()
        shellLog("read folders: one removed, \(folders.count) on the list")
    }
}

struct ReadFoldersView: View {
    @ObservedObject var model: ReadFoldersModel
    /// Opens the system folder window.
    let add: () -> Void

    static let help = "A research task may read the files in these folders when it needs them, and ask to change one: "
        + "nothing changes before you confirm it in the menu, and the old version goes to the Trash. "
        + "Hidden files, keys and password files are never read."

    var body: some View {
        VStack(spacing: 0) {
            PanelList(isEmpty: model.folders.isEmpty, emptyLine: "No folders yet.", help: Self.help, problem: model.problem) {
                ForEach(model.folders, id: \.self) { folder in
                    Row(title: folder.lastPathComponent, detail: (folder.path as NSString).abbreviatingWithTildeInPath) {
                        Button("Remove") { model.remove(folder) }.buttonStyle(QuietButton())
                    }
                }
            }
            HStack {
                Spacer()
                Button("Add a folder…", action: add).buttonStyle(MainButton())
            }
            .padding([.horizontal, .bottom], Design.Space.s20)
        }
    }
}
