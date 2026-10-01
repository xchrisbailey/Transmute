import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteUI

@main
struct TransmuteApp: App {
    let container = TransmuteStore.makeAppContainer()

    init() {
        // Plan edits are undoable (#10).
        container.mainContext.undoManager = UndoManager()
    }
    let health = HealthKitService()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
        .environment(\.health, health)
    }
}
