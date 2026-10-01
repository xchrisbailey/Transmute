import Foundation

/// What the plan has on a given day (#11): a session, or rest with the next session ahead.
public struct TodayPlan {
    /// The plan week the date falls in.
    public var week: Int
    /// The session planned for the date, if there is one.
    public var day: PlanDay?
    /// The next planned session after the date that hasn't been logged.
    public var next: PlanDay?

    /// Looks up a date in a plan, by the same calendar dates the plan screen shows.
    public init(plan: Plan, on date: Date = .now, calendar: Calendar = .init(identifier: .iso8601)) {
        week = PlanEditor.week(of: plan, on: date, calendar: calendar)
        let today = calendar.startOfDay(for: date)
        let dated = plan.orderedDays.map {
            (day: $0, date: calendar.startOfDay(for: PlanEditor.date(of: $0, in: plan)))
        }
        day = dated.first { $0.date == today }?.day
        next = dated.first { $0.date > today && ($0.day.workouts ?? []).isEmpty }?.day
    }

    /// True when the date's session already has a finished workout.
    public var isDone: Bool {
        (day?.workouts ?? []).contains { $0.endedAt != nil }
    }
}
