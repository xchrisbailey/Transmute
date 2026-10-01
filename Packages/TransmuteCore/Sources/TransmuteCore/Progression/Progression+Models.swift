import Foundation
import SwiftData

// Adapters between the stored models and the engine's plain values, so the session screen
// makes one call and the engine itself never touches SwiftData.

extension SetTarget {
    /// A planned set's targets.
    public init(_ planned: PlannedSet) {
        self.init(
            order: planned.order, reps: planned.targetReps, repsMax: planned.targetRepsMax,
            loadKg: planned.targetLoadKg, percentOneRepMax: planned.targetPercentOneRepMax, rpe: planned.targetRPE,
            seconds: planned.targetSeconds, meters: planned.targetMeters, rounds: planned.rounds,
            intervalRestSeconds: planned.intervalRestSeconds, restSeconds: planned.restSeconds,
            isWarmUp: planned.isWarmUp)
    }

    /// The targets a set was logged against, or `nil` when the session didn't record any.
    public init?(logged set: LoggedSet) {
        let recorded: [Any?] = [
            set.targetReps, set.targetRepsMax, set.targetLoadKg, set.targetRPE, set.targetSeconds,
            set.targetMeters, set.targetRounds, set.targetIntervalRestSeconds,
        ]
        guard recorded.contains(where: { $0 != nil }) else { return nil }
        self.init(
            order: set.order, reps: set.targetReps, repsMax: set.targetRepsMax, loadKg: set.targetLoadKg,
            rpe: set.targetRPE, seconds: set.targetSeconds, meters: set.targetMeters, rounds: set.targetRounds,
            intervalRestSeconds: set.targetIntervalRestSeconds, isWarmUp: set.isWarmUp)
    }
}

extension SetPerformance {
    /// A logged set, judged against the targets it recorded or else `fallback`.
    public init(_ set: LoggedSet, fallback: SetTarget? = nil) {
        self.init(
            order: set.order, weightKg: set.weightKg, reps: set.reps, seconds: set.seconds, meters: set.meters,
            rpe: set.rpe, rounds: set.rounds, isWarmUp: set.isWarmUp, isCompleted: set.isCompleted,
            target: SetTarget(logged: set) ?? fallback)
    }
}

extension ExercisePerformance {
    /// A logged exercise. Sets that didn't record their targets fall back to the plan day's set
    /// at the same order. `nil` when it isn't part of a workout.
    public init?(_ logged: LoggedExercise) {
        guard let workout = logged.workout else { return nil }
        let planned = workout.planDay?.orderedExercises.first { $0.exerciseID == logged.exerciseID }
        let plannedSets = planned?.orderedSets ?? []
        self.init(
            date: workout.startedAt,
            sets: logged.orderedSets.map { set in
                SetPerformance(set, fallback: plannedSets.first { $0.order == set.order }.map(SetTarget.init))
            })
    }
}

extension LoggedSet {
    /// A new set that starts from a target: the target fields record it, and the logged values
    /// are prefilled with it so the person only changes what differed.
    public convenience init(target: SetTarget) {
        self.init(order: target.order)
        apply(target)
    }

    /// Records the target and prefills the logged values with it. Reps prefill with the bottom
    /// of a range; RPE is left for the person to log.
    public func apply(_ target: SetTarget) {
        targetReps = target.reps
        targetRepsMax = target.repsMax
        targetLoadKg = target.loadKg
        targetRPE = target.rpe
        targetSeconds = target.seconds
        targetMeters = target.meters
        targetRounds = target.rounds
        targetIntervalRestSeconds = target.intervalRestSeconds
        weightKg = target.loadKg
        reps = target.reps
        seconds = target.seconds
        meters = target.meters
        rounds = target.rounds
        isWarmUp = target.isWarmUp
    }
}

extension ProgressionEngine {
    /// The next targets for a planned exercise, for the session screen.
    /// - Parameters:
    ///   - planned: The exercise on today's plan day. It isn't changed.
    ///   - history: Its logged history, from `history(of:in:excluding:)`.
    ///   - profile: For equipment, units, known lifts and progression settings.
    ///   - isDeload: Overrides the plan day's phase, mainly for tests.
    public static func next(
        for planned: PlannedExercise, history: [LoggedExercise], profile: Profile?,
        library: ExerciseLibrary = .bundled, isDeload: Bool? = nil
    ) -> ProgressionResult {
        let context = ProgressionContext(
            exerciseID: planned.exerciseID, exercise: library.exercise(id: planned.exerciseID),
            isDeload: isDeload ?? Self.isDeload(planned.day), equipment: Set(profile?.equipment ?? []),
            system: profile?.unitSystem ?? .preferred(), settings: profile?.progression ?? ProgressionSettings(),
            knownLifts: profile?.knownLifts ?? [])
        return next(
            planned: planned.orderedSets.map(SetTarget.init), history: history.compactMap(ExercisePerformance.init),
            context: context)
    }

    /// Whether a plan day falls in a deload phase.
    public static func isDeload(_ day: PlanDay?) -> Bool {
        guard let day else { return false }
        return day.plan?.phase(forWeek: day.week)?.isDeload ?? false
    }

    /// An exercise's logged history, newest first, leaving out the workout in progress.
    public static func history(
        of exerciseID: String, in context: ModelContext, excluding workout: Workout? = nil, limit: Int = 12
    ) throws -> [LoggedExercise] {
        let descriptor = FetchDescriptor<LoggedExercise>(predicate: #Predicate { $0.exerciseID == exerciseID })
        let logged = try context.fetch(descriptor).filter { $0.workout != nil && $0.workout !== workout }
        let sorted = logged.sorted {
            ($0.workout?.startedAt ?? .distantPast) > ($1.workout?.startedAt ?? .distantPast)
        }
        return Array(sorted.prefix(limit))
    }
}
