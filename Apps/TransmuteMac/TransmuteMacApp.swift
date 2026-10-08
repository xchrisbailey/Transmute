import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteIntelligence
import TransmuteLogUI
import TransmutePlanUI
import TransmuteUI

@main
struct TransmuteMacApp: App {
    /// Shared with the App Intents, which run in this process (#19).
    let container = TransmuteStore.shared
    /// System, Mocha or Latte, chosen on this Mac (#18).
    @AppStorage(Appearance.defaultsKey) private var appearance = Appearance.system

    init() {
        // Plan edits are undoable (#10).
        container.mainContext.undoManager = UndoManager()
        // From launch: a tapped reminder (#19) is delivered as the app opens.
        ReminderTaps.shared.listen()
        #if DEBUG
            // `-initCloudKitSchema` creates every record type and field in CloudKit's Development
            // environment (#20), then the app carries on launching.
            if ProcessInfo.processInfo.arguments.contains("-initCloudKitSchema") {
                TransmuteStore.initializeCloudKitSchemaForLaunch()
            }
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
