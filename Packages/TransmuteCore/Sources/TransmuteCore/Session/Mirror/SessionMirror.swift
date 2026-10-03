import Foundation
import SwiftData

/// The owner's side of a mirrored session (#15): applies what the other device asked for to
/// the workout, through `WorkoutSession`, so a set logged on the watch is saved exactly like
/// one logged on the phone.
public enum SessionMirror {
    /// What became of a command.
    public enum Outcome: Hashable, Sendable {
        /// The workout changed. Send a fresh snapshot.
        case applied
        /// Nothing changed: the command pointed at an exercise or set that's no longer there,
        /// asked for something already so (a set logged twice), or came after the session ended.
        case ignored
        /// The session ended and was kept.
        case finished(WorkoutSummary)
        /// The session was thrown away. The workout is deleted and must not be used again.
        case discarded
    }

    /// Applies a command to the running workout and saves.
    @discardableResult
    public static func apply(_ command: SessionCommand, to workout: Workout, in context: ModelContext) -> Outcome {
        guard workout.endedAt == nil else { return .ignored }
        switch command {
        case .logSet(let ref, let values, let date):
            return log(ref, values, at: date, in: workout)
        case .reopenSet(let ref):
            return reopen(ref, in: workout)
        case .updateSet(let ref, let values):
            return update(ref, values, in: workout, context)
        case .startRest(let seconds, let date):
            WorkoutSession.startRest(seconds, in: workout, at: date)
            return .applied
        case .adjustRest(let seconds, let date):
            return adjustRest(by: seconds, at: date, in: workout)
        case .setSkipped(let order, let isSkipped):
            return setSkipped(order, isSkipped, in: workout)
        case .finish(let date):
            return .finished(WorkoutSession.finish(workout, at: date))
        case .discard:
            WorkoutSession.discard(workout, in: context)
            return .discarded
        }
    }

    // MARK: Commands

    private static func log(_ ref: SetRef, _ values: SetValues, at date: Date, in workout: Workout) -> Outcome {
        // Already logged: leave it, and above all don't restart the rest.
        guard let set = set(at: ref, in: workout), !set.isCompleted else { return .ignored }
        write(values, to: set)
        WorkoutSession.complete(set, in: workout, at: date)
        return .applied
    }

    private static func reopen(_ ref: SetRef, in workout: Workout) -> Outcome {
        guard let set = set(at: ref, in: workout), set.isCompleted else { return .ignored }
        WorkoutSession.reopen(set, in: workout)
        return .applied
    }

    private static func update(
        _ ref: SetRef, _ values: SetValues, in workout: Workout, _ context: ModelContext
    ) -> Outcome {
        guard let set = set(at: ref, in: workout) else { return .ignored }
        write(values, to: set)
        WorkoutSession.save(context)
        return .applied
    }

    private static func adjustRest(by seconds: Double, at date: Date, in workout: Workout) -> Outcome {
        guard WorkoutSession.restRemaining(in: workout, at: date) != nil else { return .ignored }
        WorkoutSession.adjustRest(by: seconds, in: workout, at: date)
        return .applied
    }

    private static func setSkipped(_ order: Int, _ isSkipped: Bool, in workout: Workout) -> Outcome {
        guard let exercise = exercise(order: order, in: workout) else { return .ignored }
        WorkoutSession.setSkipped(exercise, isSkipped)
        return .applied
    }

    // MARK: Helpers

    private static func exercise(order: Int, in workout: Workout) -> LoggedExercise? {
        workout.orderedExercises.first { $0.order == order }
    }

    private static func set(at ref: SetRef, in workout: Workout) -> LoggedSet? {
        exercise(order: ref.exerciseOrder, in: workout)?.orderedSets.first { $0.order == ref.setOrder }
    }

    private static func write(_ values: SetValues, to set: LoggedSet) {
        set.weightKg = values.weightKg
        set.reps = values.reps
        set.seconds = values.seconds
        set.meters = values.meters
        set.rpe = values.rpe
    }
}
