import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteUI

@main
struct TransmuteApp: App {
    let container = TransmuteStore.makeAppContainer()

    var body: some Scene {
        WindowGroup {
            PlaceholderRoot(platform: "iPhone")
        }
        .modelContainer(container)
    }
}
