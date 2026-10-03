import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

/// Hand-built logs for the progress tests: a UTC calendar, a Monday to count days from, and
/// short ways to log sets and workouts.
@MainActor
struct ProgressFixture {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let calendar: Calendar
    /// A Monday at midnight.
    let monday: Date

    init() throws {
        container = try TransmuteStore.makeContainer(.inMemory)
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        self.calendar = calendar
        monday = calendar.dateInterval(of: .weekOfYear, for: Date(timeIntervalSince1970: 1_790_000_000))!.start
    }

    /// Midnight, `days` after the Monday.
    func day(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: monday)!
    }

    /// 6 pm, `days` after the Monday.
    func evening(_ days: Int) -> Date {
        day(days).addingTimeInterval(18 * 3_600)
    }

    func set(
        kg: Double? = nil, reps: Int? = nil, seconds: Double? = nil, meters: Double? = nil, rounds: Int? = nil,
        warmUp: Bool = false, completed: Bool = true
    ) -> LoggedSet {
        let set = LoggedSet(order: 0, weightKg: kg, reps: reps, seconds: seconds, meters: meters)
        set.rounds = rounds
        set.isWarmUp = warmUp
        set.isCompleted = completed
        return set
    }

    /// A workout started at 6 pm on a day, with its exercises in order.
    @discardableResult
    func workout(
        day days: Int, finished: Bool = true, planDay: PlanDay? = nil, _ exercises: [(String, [LoggedSet])]
    ) -> Workout {
        let workout = Workout(title: "Day \(days)", startedAt: evening(days), planDay: planDay)
        for (order, item) in exercises.enumerated() {
            let exercise = LoggedExercise(exerciseID: item.0, order: order)
            for (index, set) in item.1.enumerated() {
                set.order = index
                set.completedAt = set.isCompleted ? evening(days) : nil
                exercise.sets?.append(set)
            }
            workout.exercises?.append(exercise)
        }
        workout.endedAt = finished ? evening(days).addingTimeInterval(3_600) : nil
        context.insert(workout)
        return workout
    }

    /// A plan starting on the Monday, with the same sessions every week.
    func plan(weeks: Int, weekdays: [Weekday] = [1], _ exercises: [(String, Int)] = []) -> Plan {
        let plan = Plan(name: "Test", startDate: monday, weekCount: weeks)
        for week in 1...weeks {
            for weekday in weekdays {
                let day = PlanDay(week: week, weekday: weekday, focus: "Session")
                for (order, item) in exercises.enumerated() {
                    let exercise = PlannedExercise(exerciseID: item.0, order: order)
                    exercise.sets = (0..<item.1).map { PlannedSet(order: $0) }
                    day.exercises?.append(exercise)
                }
                plan.days?.append(day)
            }
        }
        context.insert(plan)
        return plan
    }

    func planDay(_ plan: Plan, week: Int, weekday: Weekday = 1) -> PlanDay {
        plan.orderedDays.first { $0.week == week && $0.weekday == weekday }!
    }

    func record(_ exerciseID: String, _ kind: RecordKind, _ value: Double, reps: Int? = nil, set: LoggedSet)
        -> PersonalRecord
    {
        let mark = RecordMark(kind: kind, value: value, reps: reps)
        let record = PersonalRecord(exerciseID: exerciseID, mark: mark, date: set.completedAt ?? monday, set: set)
        context.insert(record)
        return record
    }
}
