import SwiftData
import SwiftUI

/// App entry point. Opens the SwiftData container and hands off to
/// `RootView`.
@main
struct SolitusApp: App {
    private let container: ModelContainer

    init() {
        if DebugLaunch.inMemoryStore, let scratch = try? ModelContainerFactory.makeInMemoryContainer() {
            container = scratch
        } else {
            container = ModelContainerFactory.makeAppContainer().container
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
