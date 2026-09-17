import SwiftUI

@main
struct PoseTraceApp: App {
    @State private var library = LibraryStore()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                LibraryView()
            }
            .environment(library)
        }
    }
}
