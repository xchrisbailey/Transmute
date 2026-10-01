import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteIntelligence
import TransmutePlanUI
import TransmuteUI

@main
struct TransmuteMacApp: App {
    let container = TransmuteStore.makeAppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 480, minHeight: 320)
        }
        .modelContainer(container)

        #if DEBUG
            Window(Text(verbatim: "AI debug"), id: "ai-debug") {
                NavigationStack {
                    IntelligenceDebugView(service: FoundationModelsService())
                }
                .frame(minWidth: 420, minHeight: 480)
            }
        #endif
    }
}
