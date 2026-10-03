import Foundation
import SwiftData

/// Preview and test data: the tennis player from the epic, a four-week plan built around
/// their practice and match days, and three weeks of logged workouts.
public enum SampleData {
    /// Every exercise id the sample uses. The exercise library must contain all of them.
    public static let exerciseIDs: Set<String> = Set(days.flatMap { $0.exercises.map(\.id) })

    /// 5′9″, 175 lb, intermediate, playing tennis three times a week.
    public static func profile() -> Profile {
        let profile = Profile()
        profile.heightCm = Units.centimetres(feet: 5, inches: 9)
        profile.birthYear = 1991
        profile.experience = .intermediate
        profile.sports = ["tennis"]
        profile.goalText =
            "Improve overall performance on the court: first-step speed, power and staying fresh in the third set."
        profile.goalTags = [.sportPerformance, .power, .speed, .agility, .conditioning]
        profile.schedule = Schedule(
            daysPerWeek: 3, preferredWeekdays: [1, 3, 5], sessionMinutes: 60, weeks: 4,
            commitments: [
                Commitment(weekday: 2, label: "Practice", intensity: .moderate),
                Commitment(weekday: 4, label: "Practice", intensity: .moderate),
                Commitment(weekday: 6, label: "Match", intensity: .hard),
            ])
        profile.equipment = [
            .barbell, .dumbbell, .kettlebell, .bench, .rack, .pullUpBar, .medicineBall, .box, .cones, .band, .bike,
        ]
        profile.limitations = "Right shoulder gets cranky with heavy overhead pressing."
        profile.unitSystem = .imperial
        return profile
    }

    struct DayTemplate {
        let weekday: Weekday
        let focus: String
        let exercises: [ExerciseTemplate]
    }

    struct ExerciseTemplate {
        let id: String
        let sets: Int
        var reps: Int?
        var seconds: Double?
        var meters: Double?
        var loadKg: Double?
        var rest: Double = 90
        var rounds: Int?
        var superset: Int?
    }

    static let days: [DayTemplate] = [
        DayTemplate(
            weekday: 1, focus: "Lower and power",
            exercises: [
                ExerciseTemplate(id: "box-jump", sets: 3, reps: 4, rest: 60),
                ExerciseTemplate(id: "back-squat", sets: 4, reps: 5, loadKg: 90, rest: 150),
                ExerciseTemplate(id: "romanian-deadlift", sets: 3, reps: 8, loadKg: 70, rest: 120),
                ExerciseTemplate(id: "bulgarian-split-squat", sets: 3, reps: 8, loadKg: 16, rest: 90),
                ExerciseTemplate(id: "pallof-press", sets: 3, reps: 10, rest: 45),
            ]),
        DayTemplate(
            weekday: 3, focus: "Upper and rotation",
            exercises: [
                ExerciseTemplate(id: "med-ball-rotational-throw", sets: 3, reps: 6, rest: 60),
                ExerciseTemplate(id: "bench-press", sets: 4, reps: 6, loadKg: 70, rest: 150),
                ExerciseTemplate(id: "pull-up", sets: 4, reps: 6, rest: 120),
                ExerciseTemplate(
                    id: "half-kneeling-landmine-press", sets: 3, reps: 8, loadKg: 20, rest: 90, superset: 1),
                ExerciseTemplate(id: "band-external-rotation", sets: 3, reps: 15, rest: 45, superset: 1),
            ]),
        DayTemplate(
            weekday: 5, focus: "Speed, agility and conditioning",
            exercises: [
                ExerciseTemplate(id: "split-step-reaction", sets: 4, seconds: 10, rest: 45),
                ExerciseTemplate(id: "acceleration-sprint", sets: 6, meters: 10, rest: 60),
                ExerciseTemplate(id: "pro-agility-shuttle", sets: 5, meters: 18.3, rest: 75),
                ExerciseTemplate(id: "lateral-shuffle", sets: 4, seconds: 15, meters: 10, rest: 45),
                ExerciseTemplate(id: "assault-bike-intervals", sets: 1, seconds: 20, rest: 10, rounds: 8),
                ExerciseTemplate(id: "hip-90-90", sets: 2, seconds: 60, rest: 30),
            ]),
    ]

    /// A four-week plan. Loads climb 2.5% a week and week 4 is a lighter deload.
    public static func plan(startingOn start: Date) -> Plan {
        let plan = Plan(
            name: "Court-ready strength", goalSummary: "Power, first-step speed and conditioning for tennis",
            startDate: start, weekCount: 4)
        plan.rationale =
            "Heavy lifting sits on Monday, two days from your match, and speed work on Friday stays short so you're fresh for Saturday."
        plan.brewedBy = "Apple Intelligence on iPhone"
        plan.phases = [
            PlanPhase(name: "Build", focus: "Strength and power", firstWeek: 1, lastWeek: 3),
            PlanPhase(name: "Deload", focus: "Recover", firstWeek: 4, lastWeek: 4, isDeload: true),
        ]
        for week in 1...4 {
            let factor = week == 4 ? 0.85 : 1 + 0.025 * Double(week - 1)
            for template in days {
                let day = PlanDay(week: week, weekday: template.weekday, focus: template.focus)
                for (order, item) in template.exercises.enumerated() {
                    let exercise = PlannedExercise(exerciseID: item.id, order: order, supersetGroup: item.superset)
                    for index in 0..<(week == 4 ? max(1, item.sets - 1) : item.sets) {
                        let set = PlannedSet(order: index)
                        set.targetReps = item.reps
                        set.targetSeconds = item.seconds
                        set.targetMeters = item.meters
                        set.targetLoadKg = item.loadKg.map { ($0 * factor * 2).rounded() / 2 }
                        set.restSeconds = item.rest
                        set.rounds = item.rounds
                        set.intervalRestSeconds = item.rounds == nil ? nil : item.rest
                        set.targetRPE = item.loadKg == nil ? nil : 7.5
                        exercise.sets?.append(set)
                    }
                    day.exercises?.append(exercise)
                }
                plan.days?.append(day)
            }
        }
        return plan
    }

    /// Logs the plan's first `weeks` weeks as if every set was done as written.
    public static func workouts(following plan: Plan, weeks: Int, calendar: Calendar = .init(identifier: .iso8601))
        -> [Workout]
    {
        plan.orderedDays.filter { $0.week <= weeks }.map { day in
            let offset = (day.week - 1) * 7 + (day.weekday - 1)
            let start = calendar.date(byAdding: .day, value: offset, to: plan.startDate)!
                .addingTimeInterval(18 * 3_600)
            let workout = Workout(title: day.focus, startedAt: start, planDay: day)
            var clock = start
            for planned in day.orderedExercises {
                let logged = LoggedExercise(exerciseID: planned.exerciseID, order: planned.order)
                for target in planned.orderedSets {
                    let set = LoggedSet(
                        order: target.order, weightKg: target.targetLoadKg, reps: target.targetReps,
                        seconds: target.targetSeconds, meters: target.targetMeters,
                        rpe: target.targetRPE.map { $0 + 0.5 })
                    set.rounds = target.rounds
                    clock += 60 + (target.restSeconds ?? 60)
                    set.complete(at: clock)
                    logged.sets?.append(set)
                }
                workout.exercises?.append(logged)
            }
            workout.endedAt = clock
            return workout
        }
    }

    /// Inserts the profile, the plan and three weeks of workouts. The plan starts on the
    /// Monday three weeks before `now`, so week 4 is this week.
    @discardableResult
    public static func insert(into context: ModelContext, now: Date = .now) -> (profile: Profile, plan: Plan) {
        let calendar = Calendar(identifier: .iso8601)
        let thisMonday = calendar.dateInterval(of: .weekOfYear, for: now)!.start
        let start = calendar.date(byAdding: .weekOfYear, value: -3, to: thisMonday)!

        let profile = profile()
        context.insert(profile)
        for week in 0..<4 {
            let date = calendar.date(byAdding: .weekOfYear, value: week, to: start)!
            profile.bodyweights?.append(BodyweightEntry(date: date, kg: 79.4 - Double(week) * 0.2))
        }

        let plan = plan(startingOn: start)
        context.insert(plan)
        for workout in workouts(following: plan, weeks: 3, calendar: calendar) {
            context.insert(workout)
        }
        return (profile, plan)
    }

    /// An in-memory container holding the sample, for SwiftUI previews.
    @MainActor
    public static func previewContainer() throws -> ModelContainer {
        let container = try TransmuteStore.makeContainer(.inMemory)
        insert(into: container.mainContext)
        try container.mainContext.save()
        return container
    }
}
