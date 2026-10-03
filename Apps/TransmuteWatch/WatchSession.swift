import Foundation
import Observation
import SwiftData
import TransmuteCore

/// A record just set, for the toast.
struct RecordNotice: Equatable, Identifiable {
    let id = UUID()
    let mark: RecordMark
}

/// The workout running on the watch (#15). Screens draw its snapshot and send it commands, so
/// they don't care whether the workout lives in this watch's store or is mirrored from the
/// iPhone.
@MainActor @Observable
final class WatchSession: Identifiable {
    let id: UUID
    private(set) var snapshot: SessionSnapshot
    /// Set once the workout is finished, for the summary.
    private(set) var summary: WorkoutSummary?
    private(set) var isDiscarded = false
    var record: RecordNotice?
    /// A logged set far beyond the previous best, waiting for a yes or a fix.
    var suspicious: SetRef?

    /// The Health workout running alongside: heart rate and energy while it lasts.
    let live: WatchLiveWorkout
    /// True once the finished workout is in Health.
    private(set) var isSavedToHealth = false

    let library: ExerciseLibrary
    private let workout: Workout
    private let context: ModelContext
    private let health: any HealthService

    init(
        workout: Workout, context: ModelContext, library: ExerciseLibrary, live: WatchLiveWorkout,
        health: any HealthService
    ) {
        id = workout.id
        self.workout = workout
        self.context = context
        self.library = library
        self.live = live
        self.health = health
        snapshot = SessionSnapshot(workout, library: library)
    }

    /// Starts the Health workout, or picks it back up after a relaunch. Logging works without
    /// it: with no Health access there's just no heart rate, and nothing is saved to Health.
    func startLive() async {
        guard health.isAvailable, workout.endedAt == nil else { return }
        if await live.recover() { return }
        try? await health.requestAccess(.workouts)
        let exercises = workout.orderedExercises.compactMap { library.exercise(id: $0.exerciseID) }
        try? await live.start(activity: .infer(from: exercises), at: .now)
    }

    /// Ends the Health workout and keeps its id on the logged workout, so the iPhone doesn't
    /// save a second one and deleting the workout later removes it from Health too.
    private func saveToHealth() async {
        guard let id = try? await live.finish(workoutID: workout.id, title: workout.title, at: workout.endedAt ?? .now)
        else { return }
        workout.healthKitWorkoutID = id
        try? context.save()
        isSavedToHealth = true
    }

    func perform(_ command: SessionCommand) {
        switch SessionMirror.apply(command, to: workout, in: context) {
        case .ignored:
            break
        case .discarded:
            isDiscarded = true
            Task { await live.discard() }
            return
        case .finished(let summary):
            self.summary = summary
            Task { await saveToHealth() }
        case .applied:
            switch command {
            case .logSet(let ref, _, _): checkRecords(ref)
            case .reopenSet(let ref): recomputeRecords(ref)
            default: break
            }
        }
        snapshot = SessionSnapshot(workout, library: library)
    }

    /// The person said the big jump is real: record it.
    func confirmSuspicious() {
        guard let ref = suspicious, let set = set(at: ref) else { return }
        suspicious = nil
        guard let check = try? RecordBook(context: context, library: library).confirm(set) else { return }
        try? context.save()
        record = check.gold.first.map { RecordNotice(mark: $0.mark) }
    }

    /// The person said it was a slip: open the set back up to correct it.
    func fixSuspicious() {
        guard let ref = suspicious else { return }
        suspicious = nil
        perform(.startRest(seconds: nil, at: .now))
        perform(.reopenSet(ref))
    }

    private func checkRecords(_ ref: SetRef) {
        guard let set = set(at: ref),
            let check = try? RecordBook(context: context, library: library).check(set)
        else { return }
        try? context.save()
        if let gold = check.gold.first {
            record = RecordNotice(mark: gold.mark)
        } else if !check.needsConfirmation.isEmpty {
            suspicious = ref
        }
    }

    private func recomputeRecords(_ ref: SetRef) {
        guard let exerciseID = set(at: ref)?.exercise?.exerciseID else { return }
        _ = try? RecordBook(context: context, library: library).recompute(exerciseID: exerciseID)
        try? context.save()
    }

    private func set(at ref: SetRef) -> LoggedSet? {
        workout.orderedExercises.first { $0.order == ref.exerciseOrder }?
            .orderedSets.first { $0.order == ref.setOrder }
    }
}

extension SessionSnapshot {
    func exercise(at ref: SetRef) -> Exercise? {
        exercise(order: ref.exerciseOrder)
    }
}
