import SwiftUI

/// What the Never read panel shows: the apps on the list, as names.
@MainActor
final class NeverReadModel: ObservableObject {
    @Published private(set) var apps: [NeverReadList.App]
    let list: NeverReadList

    init(list: NeverReadList = .shared) {
        self.list = list
        apps = list.apps
    }

    /// Phew may read the app again from the next call.
    func remove(_ bundleID: String) {
        list.remove(bundleID)
        apps = list.apps
        shellLog("never read: app removed, \(apps.count) on the list")
    }
}

/// Shown in a `MenuPanel`: non-activating, the front app keeps the focus.
struct NeverReadView: View {
    @ObservedObject var model: NeverReadModel

    var body: some View {
        PanelList(isEmpty: model.apps.isEmpty, emptyLine: "No apps on the list.",
                  help: "Phew never reads the screen of these apps. Use “Never read” in the menu to add the app in front.") {
            ForEach(model.apps) { app in
                Row(title: app.name) {
                    Button("Remove") { model.remove(app.bundleID) }.buttonStyle(QuietButton())
                }
            }
        }
    }
}
