import Foundation

struct PlanBackup: Codable, Equatable {
    var id: UUID
    var createdAt: Date
    var name: String
    var goalSummary: String
    var rationale: String
    var startDate: Date
    var weekCount: Int
    var isActive: Bool
    var brewedBy: String?
    var phases: [PlanPhase]
    var days: [PlanDayBackup]

    init(_ plan: Plan) {
        id = plan.id
        createdAt = plan.createdAt
        name = plan.name
        goalSummary = plan.goalSummary
        rationale = plan.rationale
        startDate = plan.startDate
        weekCount = plan.weekCount
        isActive = plan.isActive
        brewedBy = plan.brewedBy
        phases = plan.phases
        days = plan.backupDays.map(PlanDayBackup.init)
    }

    /// The plan and its days, the days in the backup's order so a `PlanDayRef` finds its day.
    func model() -> (plan: Plan, days: [PlanDay]) {
        let plan = Plan(name: name, goalSummary: goalSummary, startDate: startDate, weekCount: weekCount)
        plan.id = id
        plan.createdAt = createdAt
        plan.rationale = rationale
        plan.isActive = isActive
        plan.brewedBy = brewedBy
        plan.phases = phases
        let days = days.map { $0.model() }
        plan.days = days
        return (plan, days)
    }
}

extension Plan {
    /// Days in the order a backup lists them, which is the order `PlanDayRef.day` counts in.
    var backupDays: [PlanDay] {
        (days ?? []).sorted { ($0.week, $0.weekday, $0.focus) < ($1.week, $1.weekday, $1.focus) }
    }
}

struct PlanDayBackup: Codable, Equatable {
    var week: Int
    var weekday: Weekday
    var focus: String
    var notes: String
    var isEdited: Bool
    var exercises: [PlannedExerciseBackup]

    init(_ day: PlanDay) {
        week = day.week
        weekday = day.weekday
        focus = day.focus
        notes = day.notes
        isEdited = day.isEdited
        exercises = day.orderedExercises.map(PlannedExerciseBackup.init)
    }

    func model() -> PlanDay {
        let day = PlanDay(week: week, weekday: weekday, focus: focus, notes: notes)
        day.isEdited = isEdited
        day.exercises = exercises.map { $0.model() }
        return day
    }
}

struct PlannedExerciseBackup: Codable, Equatable {
    var exerciseID: String
    var order: Int
    var supersetGroup: Int?
    var notes: String
    var sets: [PlannedSetBackup]

    init(_ exercise: PlannedExercise) {
        exerciseID = exercise.exerciseID
        order = exercise.order
        supersetGroup = exercise.supersetGroup
        notes = exercise.notes
        sets = exercise.orderedSets.map(PlannedSetBackup.init)
    }

    func model() -> PlannedExercise {
        let exercise = PlannedExercise(
            exerciseID: exerciseID, order: order, supersetGroup: supersetGroup, notes: notes)
        exercise.sets = sets.map { $0.model() }
        return exercise
    }
}

struct PlannedSetBackup: Codable, Equatable {
    var order: Int
    var targetReps: Int?
    var targetRepsMax: Int?
    var targetSeconds: Double?
    var targetMeters: Double?
    var targetLoadKg: Double?
    var targetPercentOneRepMax: Double?
    var targetRPE: Double?
    var restSeconds: Double?
    var rounds: Int?
    var intervalRestSeconds: Double?
    var isWarmUp: Bool

    init(_ set: PlannedSet) {
        order = set.order
        targetReps = set.targetReps
        targetRepsMax = set.targetRepsMax
        targetSeconds = set.targetSeconds
        targetMeters = set.targetMeters
        targetLoadKg = set.targetLoadKg
        targetPercentOneRepMax = set.targetPercentOneRepMax
        targetRPE = set.targetRPE
        restSeconds = set.restSeconds
        rounds = set.rounds
        intervalRestSeconds = set.intervalRestSeconds
        isWarmUp = set.isWarmUp
    }

    func model() -> PlannedSet {
        let set = PlannedSet(order: order)
        set.targetReps = targetReps
        set.targetRepsMax = targetRepsMax
        set.targetSeconds = targetSeconds
        set.targetMeters = targetMeters
        set.targetLoadKg = targetLoadKg
        set.targetPercentOneRepMax = targetPercentOneRepMax
        set.targetRPE = targetRPE
        set.restSeconds = restSeconds
        set.rounds = rounds
        set.intervalRestSeconds = intervalRestSeconds
        set.isWarmUp = isWarmUp
        return set
    }
}
