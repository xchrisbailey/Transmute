import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteLogUI
import TransmuteUI

@main
struct TransmuteApp: App {
    let container = TransmuteStore.makeAppContainer()

    init() {
        live = PhoneLiveWorkout()
        link = SessionLink(live: live, device: .phone)
        // Has to be listening from launch: the watch can start a workout at any time.
        live.listen()
        // Plan edits are undoable (#10).
        container.mainContext.undoManager = UndoManager()
        #if DEBUG
            // `-seedSample` fills an empty store with the sample tennis player, plan and log.
            let context = container.mainContext
            if ProcessInfo.processInfo.arguments.contains("-seedSample"),
                (try? context.fetchCount(FetchDescriptor<Profile>())) == 0
            {
                let (profile, plan) = SampleData.insert(into: context)
                // `-sampleSession` also starts this week's first session, to see the session screen.
                if ProcessInfo.processInfo.arguments.contains("-sampleSession"),
                    let day = plan.orderedDays.first(where: { $0.week == PlanEditor.week(of: plan) })
                {
                    let workout = WorkoutSession.start(day, profile: profile, in: context)
                    if let first = WorkoutSession.currentSet(of: workout) {
                        WorkoutSession.complete(first, in: workout)
                    }
                }
                try? context.save()
            }
        #endif
    }
    let health = HealthKitService()
    /// The iPhone's end of a workout the watch is recording, and the link that keeps the two
    /// in step (#15).
    let live: PhoneLiveWorkout
    let link: SessionLink

    var body: some Scene {
        WindowGroup {
            RootView()
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
