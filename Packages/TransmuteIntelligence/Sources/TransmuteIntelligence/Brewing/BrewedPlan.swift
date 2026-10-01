import Foundation
import SwiftData
import TransmuteCore

/// A finished brew as plain values: checked, fixed and expanded week by week. Nothing is saved
/// until `insert(into:)`, so a brew can be previewed or thrown away.
public struct BrewedPlan: Sendable, Equatable {
    public var name: String
    public var goalSummary: String
    public var rationale: String
    public var phases: [PlanPhase]
    public var weekCount: Int
    public var days: [BrewedDay]

    public func days(inWeek week: Int) -> [BrewedDay] {
        days.filter { $0.week == week }
    }
}

public struct BrewedDay: Sendable, Equatable {
    public var week: Int
    public var weekday: Weekday
    public var focus: String
    /// One line for "From your plan" (#11).
    public var why: String
    public var kind: DayKind
    public var exercises: [BrewedExercise]
}

public struct BrewedExercise: Sendable, Equatable {
    public var exerciseID: String
    public var supersetGroup: Int?
    public var note: String
    public var sets: [BrewedSet]

    public init(exerciseID: String, supersetGroup: Int? = nil, note: String = "", sets: [BrewedSet]) {
        self.exerciseID = exerciseID
        self.supersetGroup = supersetGroup
        self.note = note
        self.sets = sets
    }
}

public struct BrewedSet: Sendable, Equatable {
    public var reps: Int?
    public var seconds: Double?
    public var meters: Double?
    public var loadKg: Double?
    public var percentOneRepMax: Double?
    public var rpe: Double?
    public var restSeconds: Double
    public var rounds: Int?
    public var intervalRestSeconds: Double?

    public init(
        reps: Int? = nil, seconds: Double? = nil, meters: Double? = nil, loadKg: Double? = nil,
        percentOneRepMax: Double? = nil, rpe: Double? = nil, restSeconds: Double = 90, rounds: Int? = nil,
        intervalRestSeconds: Double? = nil
    ) {
        self.reps = reps
        self.seconds = seconds
        self.meters = meters
        self.loadKg = loadKg
        self.percentOneRepMax = percentOneRepMax
        self.rpe = rpe
        self.restSeconds = restSeconds
        self.rounds = rounds
        self.intervalRestSeconds = intervalRestSeconds
    }
}

extension BrewedPlan {
    /// Saves the plan and makes it the active one. Older plans stay, archived with their history.
    @MainActor @discardableResult
    public func insert(into context: ModelContext, startDate: Date, brewedBy: String) throws -> Plan {
        for active in try context.fetch(FetchDescriptor<Plan>(predicate: #Predicate { $0.isActive })) {
            active.isActive = false
        }
        let plan = Plan(name: name, goalSummary: goalSummary, startDate: startDate, weekCount: weekCount)
        plan.rationale = rationale
        plan.phases = phases
        plan.brewedBy = brewedBy
        context.insert(plan)
        for day in days {
            plan.days?.append(day.makePlanDay())
        }
        try context.save()
        return plan
    }

    /// Replaces the plan from `week` on with this brew's days, keeping any day that already has
    /// a logged workout so history stays attached.
    @MainActor
    public func replaceWeeks(of plan: Plan, from week: Int, in context: ModelContext) throws {
        let kept = (plan.days ?? []).filter { $0.week >= week && !($0.workouts ?? []).isEmpty }
        let keptSlots = Set(kept.map { "\($0.week)-\($0.weekday)" })
        for day in plan.days ?? [] where day.week >= week && (day.workouts ?? []).isEmpty {
            context.delete(day)
        }
        for day in days where day.week >= week && !keptSlots.contains("\(day.week)-\(day.weekday)") {
            plan.days?.append(day.makePlanDay())
        }
        plan.phases = phases
        plan.rationale = rationale
        try context.save()
    }
}

extension BrewedDay {
    func makePlanDay() -> PlanDay {
        let day = PlanDay(week: week, weekday: weekday, focus: focus, notes: why)
        for (order, exercise) in exercises.enumerated() {
            let planned = PlannedExercise(
                exerciseID: exercise.exerciseID, order: order, supersetGroup: exercise.supersetGroup,
                notes: exercise.note)
            for (index, target) in exercise.sets.enumerated() {
                let set = PlannedSet(order: index)
                set.targetReps = target.reps
                set.targetSeconds = target.seconds
                set.targetMeters = target.meters
                set.targetLoadKg = target.loadKg
                set.targetPercentOneRepMax = target.percentOneRepMax
                set.targetRPE = target.rpe
                set.restSeconds = target.restSeconds
                set.rounds = target.rounds
                set.intervalRestSeconds = target.intervalRestSeconds
                planned.sets?.append(set)
            }
            day.exercises?.append(planned)
        }
        return day
    }
}
