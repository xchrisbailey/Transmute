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
    let container = TransmuteStore.makeAppContainer()
    let health = HealthKitService()

    init() {
        #if DEBUG
            // `-seedSample` fills an empty store with the sample tennis player, plan and log, so
            // the watch has something to run in the simulator without iCloud.
            let context = container.mainContext
            if ProcessInfo.processInfo.arguments.contains("-seedSample"),
                (try? context.fetchCount(FetchDescriptor<Profile>())) == 0
            {
                let (profile, plan) = SampleData.insert(into: context)
                // `-sampleSession` also starts this week's first session, to see the set screen;
                // `-sampleRest` logs its first set too, to see the rest ring.
                if ProcessInfo.processInfo.arguments.contains("-sampleSession"),
                    let day = plan.orderedDays.first(where: { $0.week == PlanEditor.week(of: plan) })
                {
                    let workout = WorkoutSession.start(day, profile: profile, in: context)
                    if ProcessInfo.processInfo.arguments.contains("-sampleRest"),
                        let first = WorkoutSession.currentSet(of: workout)
                    {
                        WorkoutSession.complete(first, in: workout)
                    }
                }
                try? context.save()
            }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
        .modelContainer(container)
        .environment(\.health, health)
    }
}
