import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

/// The adapters from stored plans and logs, and the one call the session makes.
@MainActor
struct ProgressionModelTests {
    let container: ModelContainer
    let profile = Profile()
    let plan = Plan(name: "Strength", startDate: Lift.daysAgo(14), weekCount: 4)
    let day = PlanDay(week: 1, weekday: 1, focus: "Lower A")
    let squat = PlannedExercise(exerciseID: "back-squat", order: 0)
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try TransmuteStore.makeContainer(.inMemory)
        plan.phases = [
            PlanPhase(name: "Build", focus: "", firstWeek: 1, lastWeek: 3),
            PlanPhase(name: "Deload", focus: "", firstWeek: 4, lastWeek: 4, isDeload: true),
        ]
        for order in 0..<3 {
            let set = PlannedSet(order: order)
            set.targetReps = 5
            set.targetLoadKg = 100
            squat.sets?.append(set)
        }
        day.exercises = [squat]
        plan.days = [day]
        profile.equipmentRaw = ["barbell", "rack"]
        profile.unitSystem = .metric
        context.insert(profile)
        context.insert(plan)
    }

    /// A workout of squats on the plan day. `recordTargets` stores the targets on each set,
    /// as the session will; otherwise they fall back to the plan day.
    @discardableResult
    func log(daysAgo: Int, kg: Double, reps: Int, recordTargets: Bool = false, finished: Bool = true) -> Workout {
        let workout = Workout(title: "Lower A", startedAt: Lift.daysAgo(daysAgo), planDay: day)
        if finished { workout.endedAt = workout.startedAt.addingTimeInterval(3_600) }
        let logged = LoggedExercise(exerciseID: "back-squat", order: 0)
        for order in 0..<3 {
            let set = LoggedSet(order: order, weightKg: kg, reps: reps)
            if recordTargets {
                set.targetReps = 3
                set.targetLoadKg = kg
            }
            set.complete(at: workout.startedAt)
            logged.sets?.append(set)
        }
        workout.exercises = [logged]
        context.insert(workout)
        return workout
    }

    @Test func profileStartsWithDefaultSettings() throws {
        try context.save()
        let stored = try #require(try context.fetch(FetchDescriptor<Profile>()).first)
        #expect(stored.progression == ProgressionSettings())
        stored.toggleProgressionHold(for: "back-squat")
        try context.save()
        #expect(stored.progression.isHeld("back-squat"))
    }

    @Test func historyIsNewestFirstAndLeavesOutTheWorkoutInProgress() throws {
        log(daysAgo: 7, kg: 95, reps: 5)
        log(daysAgo: 3, kg: 100, reps: 5)
        let current = log(daysAgo: 0, kg: 102.5, reps: 5, finished: false)
        try context.save()
        let history = try ProgressionEngine.history(of: "back-squat", in: context, excluding: current)
        #expect(history.map { $0.orderedSets.first?.weightKg } == [100, 95])
        #expect(try ProgressionEngine.history(of: "bench-press", in: context).isEmpty)
    }

    @Test func setsWithoutRecordedTargetsAreJudgedAgainstThePlanDay() throws {
        log(daysAgo: 3, kg: 100, reps: 5)
        try context.save()
        let history = try ProgressionEngine.history(of: "back-squat", in: context)
        let performance = try #require(ExercisePerformance(history[0]))
        #expect(performance.sets.map(\.target?.reps) == [5, 5, 5])
        let result = ProgressionEngine.next(for: squat, history: history, profile: profile)
        #expect(result.reason.kind == .addLoad)
        #expect(result.reason.loadKg == 102.5)
        #expect(result.reason.sourceDate == Lift.daysAgo(3))
        // The plan itself isn't touched.
        #expect(squat.orderedSets.map(\.targetLoadKg) == [100, 100, 100])
    }

    @Test func recordedTargetsAreUsedFirst() throws {
        log(daysAgo: 3, kg: 100, reps: 5, recordTargets: true)
        try context.save()
        let history = try ProgressionEngine.history(of: "back-squat", in: context)
        #expect(ExercisePerformance(history[0])?.sets.map(\.target?.reps) == [3, 3, 3])
    }

    @Test func deloadComesFromThePlanPhase() throws {
        #expect(!ProgressionEngine.isDeload(day))
        day.week = 4
        #expect(ProgressionEngine.isDeload(day))
        let result = ProgressionEngine.next(for: squat, history: [], profile: profile)
        #expect(result.reason.kind == .deload)
        #expect(result.targets.map(\.loadKg) == [90, 90])
    }

    @Test func heldExercisesFromTheProfile() throws {
        log(daysAgo: 3, kg: 100, reps: 5)
        profile.toggleProgressionHold(for: "back-squat")
        try context.save()
        let history = try ProgressionEngine.history(of: "back-squat", in: context)
        let result = ProgressionEngine.next(for: squat, history: history, profile: profile)
        #expect(result.reason.kind == .held)
        #expect(result.reason.loadKg == 100)
    }

    @Test func imperialProfilesRoundToPounds() throws {
        profile.unitSystem = .imperial
        log(daysAgo: 3, kg: Lift.pounds(225), reps: 5)
        try context.save()
        let history = try ProgressionEngine.history(of: "back-squat", in: context)
        let result = ProgressionEngine.next(for: squat, history: history, profile: profile)
        #expect(Lift.display(result.reason.loadKg, .imperial) == 230)
    }

    @Test func aLoggedSetStartsFromItsTarget() throws {
        let target = SetTarget(
            order: 2, reps: 6, repsMax: 8, loadKg: 102.5, rpe: 8, seconds: 30, meters: 20, rounds: 6,
            intervalRestSeconds: 15)
        let set = LoggedSet(target: target)
        #expect(set.order == 2)
        #expect(set.targetReps == 6 && set.targetRepsMax == 8 && set.targetLoadKg == 102.5 && set.targetRPE == 8)
        #expect(set.targetSeconds == 30 && set.targetMeters == 20 && set.targetRounds == 6)
        #expect(set.targetIntervalRestSeconds == 15)
        #expect(set.weightKg == 102.5 && set.reps == 6 && set.seconds == 30 && set.meters == 20 && set.rounds == 6)
        #expect(set.rpe == nil)
        #expect(!set.isCompleted)
        #expect(SetTarget(logged: set)?.repsMax == 8)
        #expect(SetTarget(logged: LoggedSet(order: 0, weightKg: 100, reps: 5)) == nil)
    }
}
