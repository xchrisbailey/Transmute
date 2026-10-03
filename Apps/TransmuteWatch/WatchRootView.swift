import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteUI
import WidgetKit

/// Today until a workout is running, then the workout. A workout left running, even by a
/// relaunched app, opens straight back up.
struct WatchRootView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    @Query(filter: #Predicate<Plan> { $0.isActive }, sort: \Plan.createdAt, order: .reverse) private var plans: [Plan]
    @Query(filter: #Predicate<Workout> { $0.endedAt == nil }, sort: \Workout.startedAt, order: .reverse)
    private var running: [Workout]
    @Query(sort: \CustomExercise.name) private var customExercises: [CustomExercise]
    @Environment(\.health) private var health
    @State private var session: WatchSession?
    private let link = WatchLive.link
    private let live = WatchLive.workout

    private var units: Units {
        Units(profiles.first)
    }

    /// Rest haptics and auto-start rest (#18), from the profile once it has synced.
    private var preferences: WorkoutPreferences {
        profiles.first?.preferences ?? WorkoutPreferences()
    }

    private var library: ExerciseLibrary {
        ExerciseLibrary.bundled.adding(customExercises.map(LibraryExercise.init))
    }

    var body: some View {
        Group {
            if let session {
                WatchSessionView(session: session, units: units, restHaptics: preferences.restHaptics) {
                    session.close()
                    self.session = nil
                }
            } else {
                NavigationStack {
                    WatchTodayView(plan: plans.first, units: units, library: library, onStart: start)
                }
            }
        }
        .onChange(of: mine?.id, initial: true) {
            if session == nil, let workout = mine {
                run(workout)
            }
        }
        .onChange(of: link.mirrored) {
            if let session {
                session.mirrorChanged()
            } else if let snapshot = link.mirrored, !snapshot.isFinished {
                // The iPhone started a workout: join it.
                let session = WatchSession(mirroring: snapshot, context: context, library: library, health: health)
                self.session = session
                Task { await session.startLive() }
            }
        }
        .onChange(of: live.heartRate) { _, bpm in
            if let bpm { link.sendHeartRate(bpm) }
        }
        .onChange(of: session?.snapshot) {
            // The complication shows the next lift: keep it current as sets are logged.
            WidgetCenter.shared.reloadTimelines(ofKind: TodayGlance.watchWidgetKind)
        }
        .task { await link.run() }
    }

    /// The running workout this watch owns. One the iPhone started is its to run: the watch
    /// joins it over the link instead of writing to a second copy.
    private var mine: Workout? {
        running.first { $0.startedOn != .phone }
    }

    private func start(_ day: PlanDay) {
        run(WorkoutSession.start(day, profile: profiles.first, library: library, in: context))
    }

    private func run(_ workout: Workout) {
        let session = WatchSession(workout: workout, context: context, library: library, health: health)
        self.session = session
        Task { await session.startLive() }
    }
}
