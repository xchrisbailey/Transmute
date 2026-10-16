import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteLogUI
import TransmuteUI

@main
struct TransmuteApp: App {
    /// Shared with the App Intents, which run in this process.
    let container = TransmuteStore.shared

    init() {
        live = PhoneLiveWorkout()
        link = SessionLink(live: live, device: .phone)
        // Has to be listening from launch: the watch can start a workout at any time.
        live.listen()
        // Also from launch: a tapped reminder is delivered as the app opens.
        ReminderTaps.shared.listen()
        // Also from launch: an App Intent can save in a process that never opens a window.
        WidgetReload.listen()
        container.mainContext.undoManager = UndoManager()
        DebugLaunch.apply(to: container)
    }
    let health = HealthKitService()
    /// The iPhone's end of a workout the watch is recording, and the link that keeps the two
    /// in step.
    let live: PhoneLiveWorkout
    let link: SessionLink
    @AppStorage(Appearance.defaultsKey) private var appearance = Appearance.system

    var body: some Scene {
        WindowGroup {
            RootView()
                .appearance(appearance)
                .reloadsWidgetsOnLeavingForeground()
                .indexesSpotlight()
                .task { await link.run() }
                .onChange(of: link.remoteHeartRate) { _, bpm in
                    live.update(heartRate: bpm, averageHeartRate: nil, activeEnergyKcal: nil)
                }
        }
        .modelContainer(container)
        .environment(\.health, health)
        .environment(\.sessionLink, link)
    }
}
