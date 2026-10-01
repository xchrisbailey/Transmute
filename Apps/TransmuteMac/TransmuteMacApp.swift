import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteUI

@main
struct TransmuteMacApp: App {
    let container = TransmuteStore.makeAppContainer()

    var body: some Scene {
        WindowGroup {
            PlaceholderRoot(platform: "Mac")
                .frame(minWidth: 480, minHeight: 320)
        }
        .modelContainer(container)
    }
}
