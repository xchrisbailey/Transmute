import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteIntelligence
import TransmutePlanUI
import TransmuteUI

@main
struct TransmuteApp: App {
    let container = TransmuteStore.makeAppContainer()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                PlaceholderRoot(platform: "iPhone")
                    #if DEBUG
                        .toolbar {
                            NavigationLink {
                                IntelligenceDebugView(service: FoundationModelsService())
                            } label: {
                                Label {
                                    Text(verbatim: "AI debug")
                                } icon: {
                                    Image(systemName: "ladybug")
                                }
                            }
                        }
                    #endif
            }
        }
        .modelContainer(container)
    }
}
