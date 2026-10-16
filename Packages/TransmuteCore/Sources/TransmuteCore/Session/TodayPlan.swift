import Foundation

public struct TodayPlan {
    public var week: Int
    public var day: PlanDay?
    /// The next planned session after the date that hasn't been logged.
    public var next: PlanDay?

    /// Looks up a date in a plan, by the same calendar dates the plan screen shows.
    public init(plan: Plan, on date: Date = .now, calendar: Calendar = .init(identifier: .iso8601)) {
        let planCalendar = PlanCalendar(plan: plan, calendar: calendar)
        week = planCalendar.clampedWeek(containing: date)
        let today = calendar.startOfDay(for: date)
        let dated = plan.orderedDays.map {
            (day: $0, date: planCalendar.date(of: $0))
        }
        day = dated.first { $0.date == today }?.day
        next = dated.first { $0.date > today && ($0.day.workouts ?? []).isEmpty }?.day
    }

    public var isDone: Bool {
        (day?.workouts ?? []).contains { $0.endedAt != nil }
    }
}
