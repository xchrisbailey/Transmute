import HealthKit
import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteUI
import WatchKit

/// The iPhone starting a workout wakes the watch app here, to run the Health workout and
/// mirror it back.
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        Task { @MainActor in
            try? await WatchLive.workout.start(with: workoutConfiguration)
            WatchLive.link.requestSnapshot()
        }
    }
}

@main
struct TransmuteWatchApp: App {
    @WKApplicationDelegateAdaptor private var delegate: WatchAppDelegate
    /// Shared with the App Intents, which run in this process.
    let container = TransmuteStore.shared
    let health = HealthKitService()

    init() {
        WidgetReload.listen()
        DebugLaunch.apply(to: container)
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
        .modelContainer(container)
        .environment(\.health, health)
    }
}
