import Foundation

/// One set's targets as the engine sees them: a plain copy of a `PlannedSet` or of the targets a
/// `LoggedSet` was logged against. Which fields are set depends on the exercise's tracking.
public struct SetTarget: Codable, Hashable, Sendable {
    public var order: Int
    public var reps: Int?
    /// Upper end of a rep range, e.g. 8 in "6–8".
    public var repsMax: Int?
    public var loadKg: Double?
    /// 0–1, e.g. 0.75 for 75% of 1RM. The engine resolves it to `loadKg`.
    public var percentOneRepMax: Double?
    public var rpe: Double?
    public var seconds: Double?
    public var meters: Double?
    public var rounds: Int?
    public var intervalRestSeconds: Double?
    public var restSeconds: Double?
    public var isWarmUp: Bool

    public init(
        order: Int = 0, reps: Int? = nil, repsMax: Int? = nil, loadKg: Double? = nil,
        percentOneRepMax: Double? = nil, rpe: Double? = nil, seconds: Double? = nil, meters: Double? = nil,
        rounds: Int? = nil, intervalRestSeconds: Double? = nil, restSeconds: Double? = nil, isWarmUp: Bool = false
    ) {
        self.order = order
        self.reps = reps
        self.repsMax = repsMax
        self.loadKg = loadKg
        self.percentOneRepMax = percentOneRepMax
        self.rpe = rpe
        self.seconds = seconds
        self.meters = meters
        self.rounds = rounds
        self.intervalRestSeconds = intervalRestSeconds
        self.restSeconds = restSeconds
        self.isWarmUp = isWarmUp
    }

    /// The top of the range, or the fixed rep count.
    var topReps: Int? { repsMax ?? reps }

    /// Whether this is a rep range rather than a fixed count.
    var isRange: Bool {
        guard let reps, let repsMax else { return false }
        return repsMax > reps
    }
}

/// One logged set as the engine sees it: what was done, and what it was aiming for.
public struct SetPerformance: Hashable, Sendable {
    public var order: Int
    public var weightKg: Double?
    public var reps: Int?
    public var seconds: Double?
    public var meters: Double?
    public var rpe: Double?
    public var rounds: Int?
    public var isWarmUp: Bool
    public var isCompleted: Bool
    /// What the set was logged against. `nil` is judged against today's plan instead.
    public var target: SetTarget?

    public init(
        order: Int = 0, weightKg: Double? = nil, reps: Int? = nil, seconds: Double? = nil, meters: Double? = nil,
        rpe: Double? = nil, rounds: Int? = nil, isWarmUp: Bool = false, isCompleted: Bool = true,
        target: SetTarget? = nil
    ) {
        self.order = order
        self.weightKg = weightKg
        self.reps = reps
        self.seconds = seconds
        self.meters = meters
        self.rpe = rpe
        self.rounds = rounds
        self.isWarmUp = isWarmUp
        self.isCompleted = isCompleted
        self.target = target
    }
}

/// One exercise in one past workout.
public struct ExercisePerformance: Hashable, Sendable {
    public var date: Date
    public var sets: [SetPerformance]

    public init(date: Date, sets: [SetPerformance]) {
        self.date = date
        self.sets = sets
    }

    /// Working sets in order. Warm-ups never count towards a judgement.
    var workingSets: [SetPerformance] {
        sets.filter { !$0.isWarmUp }.sorted { $0.order < $1.order }
    }

    /// Whether any working set was done at all. Sessions where the exercise was skipped are
    /// left out of the history.
    var wasDone: Bool {
        workingSets.contains(where: \.isCompleted)
    }
}

/// Everything about the exercise and the person the rules need besides the sets.
public struct ProgressionContext: Sendable {
    public var exerciseID: String
    /// The library entry, for tracking, body region and equipment. `nil` for an unknown id,
    /// which is treated as an upper-body weight × reps lift.
    public var exercise: LibraryExercise?
    /// The plan phase this day falls in is a deload.
    public var isDeload: Bool
    /// The profile's equipment, for rounding to what's loadable.
    public var equipment: Set<Equipment>
    public var system: UnitSystem
    public var settings: ProgressionSettings
    /// Lifts the person entered, used for percentage targets before there's any history.
    public var knownLifts: [KnownLift]

    public init(
        exerciseID: String, exercise: LibraryExercise?, isDeload: Bool = false, equipment: Set<Equipment> = [],
        system: UnitSystem = .metric, settings: ProgressionSettings = ProgressionSettings(),
        knownLifts: [KnownLift] = []
    ) {
        self.exerciseID = exerciseID
        self.exercise = exercise
        self.isDeload = isDeload
        self.equipment = equipment
        self.system = system
        self.settings = settings
        self.knownLifts = knownLifts
    }

    var tracking: TrackingType { exercise?.tracking ?? .weightReps }

    /// The kit to round with: what the exercise uses that the person has, or everything it can
    /// use when the profile doesn't say.
    var roundingEquipment: Set<Equipment> {
        let all = exercise?.allEquipment ?? [.barbell]
        let have = all.intersection(equipment)
        return have.isEmpty ? all : have
    }
}

/// The next targets for one exercise, and why.
public struct ProgressionResult: Hashable, Sendable {
    /// One per set to do, in order. A deload returns fewer working sets than the plan has.
    public var targets: [SetTarget]
    public var reason: ProgressionReason

    public init(targets: [SetTarget], reason: ProgressionReason) {
        self.targets = targets
        self.reason = reason
    }
}
