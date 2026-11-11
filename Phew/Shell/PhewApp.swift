import SwiftUI

@main
struct PhewApp: App {
    var body: some Scene {
        // No main window (hard rule). The menu bar item arrives in P1.
        Settings { EmptyView() }
    }
}
