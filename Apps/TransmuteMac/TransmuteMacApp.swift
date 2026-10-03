import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteIntelligence
import TransmutePlanUI
import TransmuteUI

@main
struct TransmuteMacApp: App {
    let container = TransmuteStore.makeAppContainer()

    init() {
        // Plan edits are undoable (#10).
        container.mainContext.undoManager = UndoManager()
        #if DEBUG
            // `-seedSample` fills an empty store with the sample tennis player, plan and log.
            let context = container.mainContext
            if ProcessInfo.processInfo.arguments.contains("-seedSample"),
                (try? context.fetchCount(FetchDescriptor<Profile>())) == 0
            {
                SampleData.insert(into: context)
                try? context.save()
            }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 900, idealWidth: 1180, minHeight: 600, idealHeight: 760)
        }
        .defaultSize(width: 1180, height: 760)
        .modelContainer(container)
        .commands {
            TransmuteCommands()
        }

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
