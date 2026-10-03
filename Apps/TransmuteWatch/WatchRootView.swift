import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteUI

/// Today until a workout is running, then the workout. A workout left running, even by a
/// relaunched app, opens straight back up.
struct WatchRootView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    @Query(filter: #Predicate<Plan> { $0.isActive }, sort: \Plan.createdAt, order: .reverse) private var plans: [Plan]
    @Query(filter: #Predicate<Workout> { $0.endedAt == nil }, sort: \Workout.startedAt, order: .reverse)
    private var running: [Workout]
    @Query(sort: \CustomExercise.name) private var customExercises: [CustomExercise]
    @State private var session: WatchSession?

    private var units: Units {
        Units(system: profiles.first?.unitSystem)
    }

    private var library: ExerciseLibrary {
        ExerciseLibrary.bundled.adding(customExercises.map(LibraryExercise.init))
    }

    var body: some View {
        Group {
            if let session {
                WatchSessionView(session: session, units: units) {
                    self.session = nil
                }
            } else {
                NavigationStack {
                    WatchTodayView(plan: plans.first, units: units, library: library, onStart: start)
                }
            }
        }
        .onChange(of: running.first?.id, initial: true) {
            if session == nil, let workout = running.first {
                session = WatchSession(workout: workout, context: context, library: library)
            }
        }
    }

    private func start(_ day: PlanDay) {
        let workout = WorkoutSession.start(day, profile: profiles.first, library: library, in: context)
        session = WatchSession(workout: workout, context: context, library: library)
    }
}
