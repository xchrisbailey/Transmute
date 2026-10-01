import Foundation
import SwiftData

/// The workout log (#14): finished workouts grouped by week, filtered, and kept consistent
/// when a past set or workout is edited or deleted. Progression (#12) reads history live, so
/// it follows edits by itself; records (#13) are derived and get recomputed here.
public enum WorkoutLog {
    /// What the log is narrowed to. Empty fields don't filter.
    public struct Filter: Equatable, Sendable {
        /// Matches the workout's title, or any exercise's name.
        public var text: String
        public var exerciseID: String?
        /// Only workouts from this plan.
        public var planID: UUID?
        public var dates: DateInterval?

        public init(text: String = "", exerciseID: String? = nil, planID: UUID? = nil, dates: DateInterval? = nil) {
            self.text = text
            self.exerciseID = exerciseID
            self.planID = planID
            self.dates = dates
        }

        public var isEmpty: Bool {
            self == Filter()
        }
    }

    /// One week of the log, newest workout first.
    public struct Week: Identifiable {
        /// The Monday the week starts on.
        public var start: Date
        public var workouts: [Workout]
        public var id: Date { start }
    }

    /// Finished workouts matching the filter, newest first.
    public static func workouts(
        _ workouts: [Workout], matching filter: Filter, library: ExerciseLibrary = .bundled
    ) -> [Workout] {
        let text = filter.text.trimmingCharacters(in: .whitespaces)
        return workouts.filter { workout in
            guard workout.endedAt != nil else { return false }
            if let dates = filter.dates, !dates.contains(workout.startedAt) { return false }
            if let planID = filter.planID, workout.planDay?.plan?.id != planID { return false }
            let ids = workout.orderedExercises.map(\.exerciseID)
            if let exerciseID = filter.exerciseID, !ids.contains(exerciseID) { return false }
            if !text.isEmpty {
                let names = [workout.title] + ids.map { library.exercise(id: $0)?.name ?? $0 }
                guard names.contains(where: { $0.localizedStandardContains(text) }) else { return false }
            }
            return true
        }
        .sorted { $0.startedAt > $1.startedAt }
    }

    /// Workouts grouped into ISO weeks, newest week first.
    public static func weeks(_ workouts: [Workout], calendar: Calendar = .init(identifier: .iso8601)) -> [Week] {
        let grouped = Dictionary(grouping: workouts) { workout in
            calendar.dateInterval(of: .weekOfYear, for: workout.startedAt)?.start ?? workout.startedAt
        }
        return grouped.map { Week(start: $0.key, workouts: $0.value.sorted { $0.startedAt > $1.startedAt }) }
            .sorted { $0.start > $1.start }
    }

    // MARK: Editing

    /// Call after changing a logged set's numbers: the exercise's records are rebuilt.
    public static func edited(_ set: LoggedSet, in context: ModelContext, library: ExerciseLibrary = .bundled) throws {
        guard let exerciseID = set.exercise?.exerciseID else { return }
        _ = try RecordBook(context: context, library: library).recompute(exerciseID: exerciseID)
        try context.save()
    }

    /// Deletes one logged set and rebuilds that exercise's records. An exercise left with no
    /// sets goes too.
    public static func delete(_ set: LoggedSet, in context: ModelContext, library: ExerciseLibrary = .bundled) throws {
        guard let exercise = set.exercise else { return }
        exercise.sets?.removeAll { $0 === set }
        context.delete(set)
        for (index, set) in exercise.orderedSets.enumerated() {
            set.order = index
        }
        if exercise.orderedSets.isEmpty {
            exercise.workout?.exercises?.removeAll { $0 === exercise }
            context.delete(exercise)
        }
        _ = try RecordBook(context: context, library: library).recompute(exerciseID: exercise.exerciseID)
        try context.save()
    }

    /// Deletes a workout and everything in it, rebuilds the records of every exercise it had,
    /// and returns the Health workout to remove, if Transmute wrote one.
    @discardableResult
    public static func delete(_ workout: Workout, in context: ModelContext, library: ExerciseLibrary = .bundled)
        throws -> UUID?
    {
        let exerciseIDs = Set(workout.orderedExercises.map(\.exerciseID))
        let healthID = workout.healthKitWorkoutID
        context.delete(workout)
        let book = RecordBook(context: context, library: library)
        for exerciseID in exerciseIDs {
            _ = try book.recompute(exerciseID: exerciseID)
        }
        try context.save()
        return healthID
    }

    // MARK: Exercise history

    /// One session's worth of an exercise, for its history screen.
    public struct ExerciseEntry: Identifiable {
        public var workout: Workout
        public var sets: [LoggedSet]
        /// The best estimated one-rep max that day, for the trend.
        public var estimatedOneRepMaxKg: Double?
        public var id: PersistentIdentifier { workout.persistentModelID }
    }

    /// Every finished session of an exercise, newest first, with its logged working sets.
    public static func history(of exerciseID: String, in context: ModelContext) throws -> [ExerciseEntry] {
        let descriptor = FetchDescriptor<LoggedExercise>(predicate: #Predicate { $0.exerciseID == exerciseID })
        return try context.fetch(descriptor)
            .compactMap { logged -> ExerciseEntry? in
                guard let workout = logged.workout, workout.endedAt != nil else { return nil }
                let sets = logged.orderedSets.filter(\.isCompleted)
                guard !sets.isEmpty else { return nil }
                let best = sets.filter { !$0.isWarmUp }
                    .compactMap { set in set.weightKg.flatMap { OneRepMax.estimate(weightKg: $0, reps: set.reps ?? 0) }
                    }
                    .max()
                return ExerciseEntry(workout: workout, sets: sets, estimatedOneRepMaxKg: best)
            }
            .sorted { $0.workout.startedAt > $1.workout.startedAt }
    }
}
