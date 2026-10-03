import Foundation

/// A running session as the device that doesn't own it sees it (#15).
///
/// The owner builds one from its `Workout` after every change and sends it across. The other
/// device shows it and never writes the workout to its own store, which CloudKit would later
/// turn into a duplicate.
public struct SessionSnapshot: Codable, Equatable, Sendable {
    public struct Exercise: Codable, Equatable, Sendable {
        public var exerciseID: String
        /// The library's name for it, or the id when the library doesn't know the exercise.
        public var name: String
        public var order: Int
        public var isSkipped: Bool
        /// `nil` when the library doesn't know the exercise.
        public var tracking: TrackingType?
        public var sets: [Set]

        public init(
            exerciseID: String, name: String, order: Int, isSkipped: Bool = false, tracking: TrackingType? = nil,
            sets: [Set] = []
        ) {
            self.exerciseID = exerciseID
            self.name = name
            self.order = order
            self.isSkipped = isSkipped
            self.tracking = tracking
            self.sets = sets
        }
    }

    public struct Set: Codable, Equatable, Sendable {
        public var order: Int
        public var weightKg: Double?
        public var reps: Int?
        public var seconds: Double?
        public var meters: Double?
        public var rounds: Int?
        public var rpe: Double?
        public var intervalRestSeconds: Double?
        public var restSeconds: Double?
        public var isWarmUp: Bool
        public var isCompleted: Bool
        public var completedAt: Date?

        public init(
            order: Int, weightKg: Double? = nil, reps: Int? = nil, seconds: Double? = nil, meters: Double? = nil,
            rounds: Int? = nil, rpe: Double? = nil, intervalRestSeconds: Double? = nil, restSeconds: Double? = nil,
            isWarmUp: Bool = false, isCompleted: Bool = false, completedAt: Date? = nil
        ) {
            self.order = order
            self.weightKg = weightKg
            self.reps = reps
            self.seconds = seconds
            self.meters = meters
            self.rounds = rounds
            self.rpe = rpe
            self.intervalRestSeconds = intervalRestSeconds
            self.restSeconds = restSeconds
            self.isWarmUp = isWarmUp
            self.isCompleted = isCompleted
            self.completedAt = completedAt
        }
    }

    public var workoutID: UUID
    public var title: String
    public var startedAt: Date
    public var endedAt: Date?
    /// When the running rest ends.
    public var restEndsAt: Date?
    /// How long that rest was set for, for the countdown ring.
    public var restSeconds: Double?
    /// Whether logging a set starts its rest (#18), so the mirroring device predicts what the
    /// owner will do. `nil`, from an owner that doesn't say, means it does.
    public var autoStartsRest: Bool?
    /// In order.
    public var exercises: [Exercise]

    public init(
        workoutID: UUID, title: String, startedAt: Date, endedAt: Date? = nil, restEndsAt: Date? = nil,
        restSeconds: Double? = nil, autoStartsRest: Bool? = nil, exercises: [Exercise] = []
    ) {
        self.workoutID = workoutID
        self.title = title
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.restEndsAt = restEndsAt
        self.restSeconds = restSeconds
        self.autoStartsRest = autoStartsRest
        self.exercises = exercises
    }

    /// The workout as it stands now.
    public init(_ workout: Workout, library: ExerciseLibrary = .bundled) {
        self.init(
            workoutID: workout.id, title: workout.title, startedAt: workout.startedAt, endedAt: workout.endedAt,
            restEndsAt: workout.restEndsAt, restSeconds: workout.restSeconds,
            autoStartsRest: WorkoutPreferences.stored(in: workout.modelContext).autoStartRest,
            exercises: workout.orderedExercises.map { Exercise($0, library: library) })
    }

    // MARK: Where you are

    /// The set to do next: the first unlogged set of the first exercise not skipped. The same
    /// rule as `WorkoutSession.currentSet`.
    public var current: SetRef? {
        for exercise in exercises where !exercise.isSkipped {
            if let set = exercise.sets.first(where: { !$0.isCompleted }) {
                return SetRef(exerciseOrder: exercise.order, setOrder: set.order)
            }
        }
        return nil
    }

    /// The exercise the next set belongs to.
    public var currentExercise: Exercise? {
        current.flatMap { exercise(order: $0.exerciseOrder) }
    }

    /// The set to do next.
    public var currentSet: Set? {
        current.flatMap { set(at: $0) }
    }

    public func exercise(order: Int) -> Exercise? {
        exercises.first { $0.order == order }
    }

    public func set(at ref: SetRef) -> Set? {
        exercise(order: ref.exerciseOrder)?.sets.first { $0.order == ref.setOrder }
    }

    /// Seconds of rest left at a moment, or `nil` when no rest is running.
    public func restRemaining(at date: Date = .now) -> TimeInterval? {
        guard let end = restEndsAt else { return nil }
        let remaining = end.timeIntervalSince(date)
        return remaining > 0 ? remaining : nil
    }

    public var isFinished: Bool {
        endedAt != nil
    }
}

extension SessionSnapshot.Exercise {
    public init(_ exercise: LoggedExercise, library: ExerciseLibrary = .bundled) {
        let known = library.exercise(id: exercise.exerciseID)
        self.init(
            exerciseID: exercise.exerciseID, name: known?.name ?? exercise.exerciseID, order: exercise.order,
            isSkipped: exercise.isSkipped, tracking: known?.tracking,
            sets: exercise.orderedSets.map(SessionSnapshot.Set.init))
    }
}

extension SessionSnapshot.Set {
    public init(_ set: LoggedSet) {
        self.init(
            order: set.order, weightKg: set.weightKg, reps: set.reps, seconds: set.seconds, meters: set.meters,
            rounds: set.rounds, rpe: set.rpe, intervalRestSeconds: set.intervalRestSeconds,
            restSeconds: set.restSeconds, isWarmUp: set.isWarmUp, isCompleted: set.isCompleted,
            completedAt: set.completedAt)
    }
}
