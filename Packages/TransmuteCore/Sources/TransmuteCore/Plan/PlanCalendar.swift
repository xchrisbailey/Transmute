import Foundation

/// The dates of a plan. Plan week n starts on the ISO Monday of the week containing the
/// plan's start date, so a plan that starts on a Saturday has its second week on the next
/// Monday. Every screen counts weeks through this type.
public struct PlanCalendar: Sendable {
    public let startDate: Date
    public let weekCount: Int
    /// An ISO 8601 calendar, so weeks begin on Monday. Its time zone sets where days begin.
    let calendar: Calendar

    public init(startDate: Date, weekCount: Int, calendar: Calendar = .init(identifier: .iso8601)) {
        assert(calendar.identifier == .iso8601, "A plan counts ISO weeks")
        self.startDate = startDate
        self.weekCount = weekCount
        self.calendar = calendar
    }

    public init(plan: Plan, calendar: Calendar = .init(identifier: .iso8601)) {
        self.init(startDate: plan.startDate, weekCount: plan.weekCount, calendar: calendar)
    }

    /// The Monday a plan week starts on.
    public func start(ofWeek week: Int) -> Date {
        let first = calendar.dateInterval(of: .weekOfYear, for: startDate)?.start ?? calendar.startOfDay(for: startDate)
        return calendar.date(byAdding: .day, value: (week - 1) * 7, to: first) ?? first
    }

    /// The plan week a date falls in, not clamped: 0 before the plan starts, more than
    /// `weekCount` once it's over.
    public func week(containing date: Date) -> Int {
        let first = start(ofWeek: 1)
        guard date >= first else { return 0 }
        return (calendar.dateComponents([.day], from: first, to: date).day ?? 0) / 7 + 1
    }

    /// The plan week a date falls in, clamped to the plan: the first week before it starts,
    /// the last once it's over.
    public func clampedWeek(containing date: Date) -> Int {
        min(max(week(containing: date), 1), max(weekCount, 1))
    }

    /// The date a weekday of a plan week falls on, at the start of the day.
    public func date(week: Int, weekday: Weekday) -> Date {
        let start = start(ofWeek: week)
        return calendar.date(byAdding: .day, value: weekday - 1, to: start) ?? start
    }

    /// The date of a plan day.
    public func date(of day: PlanDay) -> Date {
        date(week: day.week, weekday: day.weekday)
    }
}
