import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteIntelligence
import TransmuteLogUI
import TransmutePlanUI
import TransmuteUI

@main
struct TransmuteMacApp: App {
    /// Shared with the App Intents, which run in this process.
    let container = TransmuteStore.shared
    @AppStorage(Appearance.defaultsKey) private var appearance = Appearance.system

    init() {
        container.mainContext.undoManager = UndoManager()
        // From launch: a tapped reminder is delivered as the app opens.
        ReminderTaps.shared.listen()
        DebugLaunch.apply(to: container)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 900, idealWidth: 1180, minHeight: 600, idealHeight: 760)
                .appearance(appearance)
                .reloadsWidgets()
                .indexesSpotlight()
                // A widget's link comes to the window that's open rather than a new one.
                .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
        }
        .defaultSize(width: 1180, height: 760)
        .modelContainer(container)
        .commands {
            TransmuteCommands()
        }

        Settings {
            SettingsRoot()
                .appearance(appearance)
        }
        .modelContainer(container)

        #if DEBUG
            Window(Text(verbatim: "AI debug"), id: "ai-debug") {
                NavigationStack {
                    IntelligenceDebugView(service: FoundationModelsService())
                }
                .frame(minWidth: 420, minHeight: 480)
                .appearance(appearance)
            }
        #endif
    }
}
