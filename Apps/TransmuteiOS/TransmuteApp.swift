import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteUI

@main
struct TransmuteApp: App {
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
                let (_, plan) = SampleData.insert(into: context)
                // `-sampleSession` also starts this week's first session, to see the session screen.
                if ProcessInfo.processInfo.arguments.contains("-sampleSession"),
                    let day = plan.orderedDays.first(where: { $0.week == PlanEditor.week(of: plan) })
                {
                    let workout = WorkoutSession.start(day, in: context)
                    if let first = WorkoutSession.currentSet(of: workout) {
                        WorkoutSession.complete(first, in: workout)
                    }
                }
                try? context.save()
            }
        #endif
    }
    let health = HealthKitService()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
        .environment(\.health, health)
    }
}
