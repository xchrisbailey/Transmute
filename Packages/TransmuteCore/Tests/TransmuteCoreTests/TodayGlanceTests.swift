import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

@MainActor
struct TodayGlanceTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let now = Date(timeIntervalSince1970: 1_790_000_000)
    let calendar = Calendar(identifier: .iso8601)
    let metric = Units(system: .metric, locale: Locale(identifier: "en_GB"))
    let imperial = Units(system: .imperial, locale: Locale(identifier: "en_US"))

    init() throws {
        container = try TransmuteStore.makeContainer(.inMemory)
    }

    /// The sample plan with three weeks logged. Week 4, this week, has sessions on Monday,
    /// Wednesday and Friday.
    func plan() throws -> Plan {
        let (_, plan) = SampleData.insert(into: context, now: now)
        try context.save()
        return plan
    }

    /// Noon on a day of this week, by ISO weekday (1 is Monday).
    func date(weekday: Int) -> Date {
        let monday = calendar.dateInterval(of: .weekOfYear, for: now)!.start
        return calendar.date(byAdding: .day, value: weekday - 1, to: monday)!.addingTimeInterval(12 * 3_600)
    }

    func glance(_ plan: Plan?, workout: Workout? = nil, units: Units? = nil, weekday: Int = 1) -> TodayGlance {
        TodayGlance(
            plan: plan, workout: workout, units: units ?? metric, on: date(weekday: weekday), calendar: calendar)
    }

    /// A one-day plan with one exercise on this Monday.
    func plan(of exerciseID: String, sets: Int, configure: (PlannedSet) -> Void) throws -> Plan {
        let plan = Plan(name: "Test", startDate: calendar.startOfDay(for: date(weekday: 1)), weekCount: 1)
        let day = PlanDay(week: 1, weekday: 1, focus: "Lower A")
        let exercise = PlannedExercise(exerciseID: exerciseID, order: 0)
        for index in 0..<sets {
            let set = PlannedSet(order: index)
            configure(set)
            exercise.sets?.append(set)
        }
        day.exercises?.append(exercise)
        plan.days?.append(day)
        context.insert(plan)
        try context.save()
        return plan
    }

    // MARK: The day

    @Test func noPlanHasNothingToShow() throws {
        let empty = glance(nil)
        #expect(empty == TodayGlance())
        #expect(empty.day == .nothingPlanned)
        #expect(empty.sessionName == nil)
        #expect(empty.nextLift == nil)
        #expect(try TodayGlance.load(from: context, on: now) == TodayGlance())
    }

    @Test func aSessionDayNamesItAndItsFirstExercise() throws {
        let today = glance(try plan(), weekday: 3)
        #expect(today.day == .session("Upper and rotation"))
        #expect(today.sessionName == "Upper and rotation")
        #expect(!today.isDone)
        #expect(!today.isRunning)
        #expect(today.nextLift?.text == "Med ball rotational throw 2×6")
    }

    @Test func aRestDayLooksAheadToTheNextSession() throws {
        let today = glance(try plan(), weekday: 2)
        #expect(today.day == .rest)
        #expect(today.sessionName == nil)
        #expect(!today.isDone)
        #expect(today.nextLift?.name == "Med ball rotational throw")
    }

    @Test func aFinishedSessionIsDoneAndLooksAhead() throws {
        let plan = try plan()
        let monday = try #require(plan.orderedDays.first { $0.week == 4 && $0.weekday == 1 })
        let workout = WorkoutSession.start(monday, at: date(weekday: 1), in: context)
        for set in workout.orderedExercises.flatMap(\.orderedSets) {
            WorkoutSession.complete(set, in: workout, at: date(weekday: 1))
        }
        WorkoutSession.finish(workout, at: date(weekday: 1))

        let today = glance(plan)
        #expect(today.day == .session("Lower and power"))
        #expect(today.isDone)
        #expect(!today.isRunning)
        #expect(today.nextLift?.name == "Med ball rotational throw")
    }

    @Test func afterThePlanEndsNothingIsPlanned() throws {
        let later = calendar.date(byAdding: .weekOfYear, value: 3, to: now)!
        let today = TodayGlance(plan: try plan(), units: metric, on: later, calendar: calendar)
        #expect(today.day == .nothingPlanned)
        #expect(today.nextLift == nil)
    }

    // MARK: A running workout

    @Test func aRunningWorkoutShowsTheCurrentSet() throws {
        let plan = try plan()
        let monday = try #require(plan.orderedDays.first { $0.week == 4 && $0.weekday == 1 })
        let workout = WorkoutSession.start(monday, at: date(weekday: 1), in: context)
        var today = glance(plan, workout: workout)
        #expect(today.isRunning)
        #expect(!today.isDone)
        #expect(today.day == .session("Lower and power"))
        #expect(today.nextLift?.text == "Box jump 2×4")

        let jumps = try #require(workout.orderedExercises.first)
        for set in jumps.orderedSets {
            WorkoutSession.complete(set, in: workout, at: date(weekday: 1))
        }
        let squat = try #require(WorkoutSession.currentSet(of: workout))
        squat.weightKg = 80
        today = glance(plan, workout: workout)
        #expect(today.nextLift?.text == "Back squat 3×5 · 80 kg")

        // Everything logged but the workout not ended: there's no lift left to show.
        for set in workout.orderedExercises.flatMap(\.orderedSets) {
            WorkoutSession.complete(set, in: workout, at: date(weekday: 1))
        }
        today = glance(plan, workout: workout)
        #expect(today.isRunning)
        #expect(today.nextLift == nil)
    }

    @Test func anAdHocWorkoutUsesItsOwnTitle() throws {
        let workout = WorkoutSession.startAdHoc(title: "Garage", at: now, in: context)
        let bench = try #require(ExerciseLibrary.bundled.exercise(id: "bench-press"))
        WorkoutSession.add(bench, to: workout)
        let today = glance(nil, workout: workout)
        #expect(today.day == .session("Garage"))
        #expect(today.isRunning)
        #expect(today.nextLift?.text == "Bench press 3×10")
    }

    @Test func loadReadsTheStore() throws {
        let plan = try plan()
        var today = try TodayGlance.load(
            from: context, on: date(weekday: 3), calendar: calendar, locale: Locale(identifier: "en_US"))
        #expect(today.day == .session("Upper and rotation"))
        #expect(today.nextLift?.name == "Med ball rotational throw")

        let friday = try #require(plan.orderedDays.first { $0.week == 4 && $0.weekday == 5 })
        WorkoutSession.start(friday, at: date(weekday: 3), in: context)
        today = try TodayGlance.load(from: context, on: date(weekday: 3), calendar: calendar)
        #expect(today.isRunning)
        #expect(today.day == .session("Speed, agility and conditioning"))
        #expect(today.nextLift?.text == "Split-step reaction 3×0:10")
    }

    // MARK: The streak and the week

    @Test func theStreakAndTheWeekComeFromThePlan() throws {
        let plan = try plan()
        // Three weeks logged in full, and nothing yet in week 4.
        var today = glance(plan)
        #expect(today.streakWeeks == 3)
        #expect(today.week == .init(done: 0, planned: 3))
        #expect(!today.week.isHit)

        // A running workout doesn't count until it's finished.
        let monday = try #require(plan.orderedDays.first { $0.week == 4 && $0.weekday == 1 })
        let workout = WorkoutSession.start(monday, at: date(weekday: 1), in: context)
        today = glance(plan, workout: workout)
        #expect(today.isRunning)
        #expect(today.streakWeeks == 3)
        #expect(today.week == .init(done: 0, planned: 3))

        WorkoutSession.finish(workout, at: date(weekday: 1))
        today = glance(plan, weekday: 2)
        #expect(today.week == .init(done: 1, planned: 3))
        #expect(today.streakWeeks == 3)

        // The week's last session done: the week is hit and joins the streak.
        for weekday in [3, 5] {
            let day = try #require(plan.orderedDays.first { $0.week == 4 && $0.weekday == weekday })
            WorkoutSession.finish(WorkoutSession.start(day, at: date(weekday: weekday), in: context))
        }
        today = glance(plan, weekday: 5)
        #expect(today.week == .init(done: 3, planned: 3))
        #expect(today.week.isHit)
        #expect(today.streakWeeks == 4)
        #expect(try TodayGlance.load(from: context, on: date(weekday: 5), calendar: calendar) == today)
    }

    @Test func aMissedWeekEndsTheStreak() throws {
        let plan = try plan()
        let missed = try #require(plan.orderedDays.first { $0.week == 3 && $0.weekday == 5 })
        for workout in missed.workouts ?? [] {
            context.delete(workout)
        }
        try context.save()
        #expect(glance(plan).streakWeeks == 0)
    }

    @Test func outsideThePlanThereIsNoWeek() throws {
        #expect(glance(nil).streakWeeks == 0)
        #expect(glance(nil).week == .init())

        let plan = try plan()
        let later = calendar.date(byAdding: .weekOfYear, value: 3, to: now)!
        let after = TodayGlance(plan: plan, units: metric, on: later, calendar: calendar)
        #expect(after.week == .init())
        // Week 4 went unlogged, so the streak ended with it.
        #expect(after.streakWeeks == 0)

        let before = TodayGlance(plan: plan, units: metric, on: plan.startDate.addingTimeInterval(-86_400 * 8))
        #expect(before.week == .init())
        #expect(before.streakWeeks == 0)
    }

    // MARK: Formatting

    @Test func weightAndRepsReadSetsByRepsThenTheLoad() throws {
        let plan = try plan(of: "bench-press", sets: 5) {
            $0.targetReps = 5
            $0.targetLoadKg = 80
        }
        let lift = try #require(glance(plan).nextLift)
        #expect(lift.name == "Bench press")
        #expect(lift.detail == "5×5 · 80 kg")
        #expect(lift.text == "Bench press 5×5 · 80 kg")
        #expect(lift.sets == 5)
        #expect(lift.spokenAmount == "5")
        #expect(lift.spokenLoad == "80 kilograms")

        let pounds = try #require(glance(plan, units: imperial).nextLift)
        #expect(pounds.text == "Bench press 5×5 · 176.5 lb")
        #expect(pounds.spokenLoad == "176.5 pounds")
    }

    @Test func warmUpsAreNotCounted() throws {
        let plan = try plan(of: "bench-press", sets: 5) {
            $0.targetReps = $0.order < 2 ? 8 : 5
            $0.targetLoadKg = $0.order < 2 ? 40 : 80
            $0.isWarmUp = $0.order < 2
        }
        #expect(glance(plan).nextLift?.text == "Bench press 3×5 · 80 kg")
    }

    @Test func anOpenLoadComesFromTheLastTimeItWasLifted() throws {
        let plan = try plan(of: "bench-press", sets: 3) { $0.targetReps = 8 }
        #expect(glance(plan).nextLift?.text == "Bench press 3×8")

        let earlier = Workout(title: "Earlier", startedAt: date(weekday: 1).addingTimeInterval(-86_400))
        let logged = LoggedExercise(exerciseID: "bench-press", order: 0)
        let set = LoggedSet(order: 0, weightKg: 62.5, reps: 8)
        set.complete(at: earlier.startedAt)
        logged.sets?.append(set)
        earlier.exercises?.append(logged)
        earlier.endedAt = earlier.startedAt
        context.insert(earlier)
        try context.save()
        #expect(glance(plan).nextLift?.text == "Bench press 3×8 · 62.5 kg")
    }

    @Test func timeDistanceAndIntervalsGetShortForms() throws {
        let plank = try plan(of: "plank", sets: 3) { $0.targetSeconds = 45 }
        var lift = try #require(glance(plank).nextLift)
        #expect(lift.text == "Plank 3×0:45")
        #expect(lift.spokenAmount == "45 seconds")
        #expect(lift.load == nil)
        context.delete(plank)

        let sprint = try plan(of: "acceleration-sprint", sets: 6) { $0.targetMeters = 10 }
        lift = try #require(glance(sprint, units: imperial).nextLift)
        #expect(lift.text == "Acceleration sprint 6×10 m")
        #expect(lift.spokenAmount == "10 meters")
        context.delete(sprint)

        let bike = try plan(of: "assault-bike-intervals", sets: 1) {
            $0.targetSeconds = 20
            $0.rounds = 8
            $0.intervalRestSeconds = 10
        }
        lift = try #require(glance(bike).nextLift)
        #expect(lift.text == "Air bike intervals 8×0:20")
        #expect(lift.sets == 8)
        #expect(lift.spokenAmount == "20 seconds")
    }

    @Test func anUnknownExerciseFallsBackToItsIDWithNoNumbers() throws {
        let plan = try plan(of: "custom-missing", sets: 2) { _ in }
        let lift = try #require(glance(plan).nextLift)
        #expect(lift.text == "custom-missing")
        #expect(lift.detail == nil)
    }

    @Test func withAProfileTheNumbersAreTheOnesTheSessionStartsWith() throws {
        let plan = try plan()
        let profile = try #require(try context.fetch(FetchDescriptor<Profile>()).first)
        // With warm-ups on, the running session would be on its first warm-up set instead.
        profile.preferences.warmUpSets = false
        let monday = try #require(plan.orderedDays.first { $0.week == 4 && $0.weekday == 1 })
        // Put the squat first so the lift has a load for progression to move.
        for exercise in monday.orderedExercises {
            exercise.order = exercise.exerciseID == "back-squat" ? -1 : exercise.order
        }
        let before = TodayGlance(
            plan: plan, profile: profile, units: imperial, on: date(weekday: 1), calendar: calendar)
        let workout = WorkoutSession.start(monday, profile: profile, at: date(weekday: 1), in: context)
        let running = TodayGlance(
            plan: plan, workout: workout, profile: profile, units: imperial, on: date(weekday: 1), calendar: calendar)
        #expect(before.nextLift?.name == "Back squat")
        #expect(before.nextLift?.load != nil)
        #expect(before.nextLift == running.nextLift)
    }

    @Test func spokenFormsFollowTheUnitSystem() {
        #expect(TodayGlance.NextLift.spoken(meters: 400, units: metric) == "400 metres")
        #expect(TodayGlance.NextLift.spoken(meters: 1_500, units: metric) == "1.5 kilometres")
        #expect(TodayGlance.NextLift.spoken(meters: 1_609.344, units: imperial) == "1 mile")
        #expect(TodayGlance.NextLift.spoken(seconds: 90, locale: Locale(identifier: "en_US")) == "1 minute, 30 seconds")
    }
}
