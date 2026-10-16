import Foundation

struct WorkoutBackup: Codable, Equatable {
    var id: UUID
    var title: String
    var startedAt: Date
    var endedAt: Date?
    var notes: String
    var healthKitWorkoutID: UUID?
    var planDay: Backup.PlanDayRef?
    var restEndsAt: Date?
    var restSeconds: Double?
    var startedOn: String?
    var exercises: [LoggedExerciseBackup]

    init(_ workout: Workout) {
        id = workout.id
        title = workout.title
        startedAt = workout.startedAt
        endedAt = workout.endedAt
        notes = workout.notes
        healthKitWorkoutID = workout.healthKitWorkoutID
        planDay = workout.planDay.flatMap(Backup.PlanDayRef.init(day:))
        restEndsAt = workout.restEndsAt
        restSeconds = workout.restSeconds
        startedOn = workout.startedOnRaw
        exercises = workout.orderedExercises.map(LoggedExerciseBackup.init)
    }

    func model(planDay: PlanDay?) -> (workout: Workout, sets: [[LoggedSet]]) {
        let workout = Workout(title: title, startedAt: startedAt, planDay: planDay)
        workout.id = id
        workout.endedAt = endedAt
        workout.notes = notes
        workout.healthKitWorkoutID = healthKitWorkoutID
        workout.restEndsAt = restEndsAt
        workout.restSeconds = restSeconds
        workout.startedOnRaw = startedOn
        let logged = exercises.map { $0.model() }
        workout.exercises = logged.map(\.exercise)
        return (workout, logged.map(\.sets))
    }
}

struct LoggedExerciseBackup: Codable, Equatable {
    var exerciseID: String
    var order: Int
    var notes: String
    var isSkipped: Bool
    var substitutedFromID: String?
    var sets: [LoggedSetBackup]

    init(_ exercise: LoggedExercise) {
        exerciseID = exercise.exerciseID
        order = exercise.order
        notes = exercise.notes
        isSkipped = exercise.isSkipped
        substitutedFromID = exercise.substitutedFromID
        sets = exercise.orderedSets.map(LoggedSetBackup.init)
    }

    func model() -> (exercise: LoggedExercise, sets: [LoggedSet]) {
        let exercise = LoggedExercise(exerciseID: exerciseID, order: order)
        exercise.notes = notes
        exercise.isSkipped = isSkipped
        exercise.substitutedFromID = substitutedFromID
        let sets = sets.map { $0.model() }
        exercise.sets = sets
        return (exercise, sets)
    }
}

struct LoggedSetBackup: Codable, Equatable {
    var order: Int
    var weightKg: Double?
    var reps: Int?
    var seconds: Double?
    var meters: Double?
    var rpe: Double?
    var rounds: Int?
    var targetReps: Int?
    var targetRepsMax: Int?
    var targetLoadKg: Double?
    var targetRPE: Double?
    var targetSeconds: Double?
    var targetMeters: Double?
    var targetRounds: Int?
    var targetIntervalRestSeconds: Double?
    var isWarmUp: Bool
    var isCompleted: Bool
    var completedAt: Date?
    var notes: String
    var restSeconds: Double?
    var intervalRestSeconds: Double?
    var isRecordConfirmed: Bool

    init(_ set: LoggedSet) {
        order = set.order
        weightKg = set.weightKg
        reps = set.reps
        seconds = set.seconds
        meters = set.meters
        rpe = set.rpe
        rounds = set.rounds
        targetReps = set.targetReps
        targetRepsMax = set.targetRepsMax
        targetLoadKg = set.targetLoadKg
        targetRPE = set.targetRPE
        targetSeconds = set.targetSeconds
        targetMeters = set.targetMeters
        targetRounds = set.targetRounds
        targetIntervalRestSeconds = set.targetIntervalRestSeconds
        isWarmUp = set.isWarmUp
        isCompleted = set.isCompleted
        completedAt = set.completedAt
        notes = set.notes
        restSeconds = set.restSeconds
        intervalRestSeconds = set.intervalRestSeconds
        isRecordConfirmed = set.isRecordConfirmed
    }

    func model() -> LoggedSet {
        let set = LoggedSet(order: order, weightKg: weightKg, reps: reps, seconds: seconds, meters: meters, rpe: rpe)
        set.rounds = rounds
        set.targetReps = targetReps
        set.targetRepsMax = targetRepsMax
        set.targetLoadKg = targetLoadKg
        set.targetRPE = targetRPE
        set.targetSeconds = targetSeconds
        set.targetMeters = targetMeters
        set.targetRounds = targetRounds
        set.targetIntervalRestSeconds = targetIntervalRestSeconds
        set.isWarmUp = isWarmUp
        set.isCompleted = isCompleted
        set.completedAt = completedAt
        set.notes = notes
        set.restSeconds = restSeconds
        set.intervalRestSeconds = intervalRestSeconds
        set.isRecordConfirmed = isRecordConfirmed
        return set
    }
}

struct RecordBackup: Codable, Equatable {
    var exerciseID: String
    var kind: String
    var value: Double
    var reps: Int?
    var meters: Double?
    var date: Date
    var set: Backup.SetRef?

    init(_ record: PersonalRecord) {
        exerciseID = record.exerciseID
        kind = record.kindRaw
        value = record.value
        reps = record.reps
        meters = record.meters
        date = record.date
        set = record.set.flatMap(Backup.SetRef.init(set:))
    }

    func model(set: LoggedSet?) -> PersonalRecord {
        let record = PersonalRecord(
            exerciseID: exerciseID, kind: .estimatedOneRepMax, value: value, date: date, set: set)
        record.kindRaw = kind
        record.reps = reps
        record.meters = meters
        return record
    }

    /// A fixed order for records, which have no order of their own.
    static func precedes(_ lhs: RecordBackup, _ rhs: RecordBackup) -> Bool {
        (lhs.date, lhs.exerciseID, lhs.kind, lhs.value, lhs.reps ?? 0, lhs.meters ?? 0)
            < (rhs.date, rhs.exerciseID, rhs.kind, rhs.value, rhs.reps ?? 0, rhs.meters ?? 0)
    }
}
