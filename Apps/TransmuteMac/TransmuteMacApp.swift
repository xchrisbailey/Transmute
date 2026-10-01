import SwiftUI
import TransmuteUI

@main
struct TransmuteMacApp: App {
    var body: some Scene {
        WindowGroup {
            PlaceholderRoot(platform: "Mac")
                .frame(minWidth: 480, minHeight: 320)
        }
    }
}
