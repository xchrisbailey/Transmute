import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteUI

@main
struct TransmuteWatchApp: App {
    let container = TransmuteStore.makeAppContainer()

    var body: some Scene {
        WindowGroup {
            PlaceholderRoot(platform: "Apple Watch")
        }
        .modelContainer(container)
    }
}
