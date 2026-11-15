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
        VStack(alignment: .leading, spacing: 12) {
            if model.apps.isEmpty {
                Text("No apps on the list.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(model.apps) { app in
                            HStack {
                                Text(app.name).lineLimit(1)
                                Spacer()
                                Button("Remove") { model.remove(app.bundleID) }
                            }
                        }
                    }
                }
            }
            Text("Phew never reads the screen of these apps. Use “Never read this app” in the menu to add the app in front.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 360, height: 260, alignment: .topLeading)
    }
}
