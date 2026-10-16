import Foundation

extension ProgressStats {
    public struct WeekAdherence: Identifiable, Equatable, Sendable {
        /// 1-based week of the plan.
        public var week: Int
        /// The Monday the week starts on, as the plan screen dates it.
        public var weekStart: Date
        public var planned: Int
        /// Planned sessions with a finished workout.
        public var done: Int
        public var isDeload: Bool
        /// The week `now` falls in, so it may still be in progress.
        public var isCurrent: Bool
        public var id: Int { week }

        public init(
            week: Int, weekStart: Date, planned: Int, done: Int, isDeload: Bool = false, isCurrent: Bool = false
        ) {
            self.week = week
            self.weekStart = weekStart
            self.planned = planned
            self.done = done
            self.isDeload = isDeload
            self.isCurrent = isCurrent
        }

        public var isHit: Bool {
            planned > 0 && done >= planned
        }
    }

    /// The plan's weeks from the first to the one `now` falls in, never future ones. Empty
    /// before the plan starts; once it's over, every week and none of them current.
    public static func adherence(
        of plan: Plan, now: Date = .now, calendar: Calendar = .init(identifier: .iso8601)
    ) -> [WeekAdherence] {
        let current = PlanCalendar(plan: plan, calendar: calendar).week(containing: now)
        guard current >= 1 else { return [] }
        return (1...min(current, max(plan.weekCount, 1))).map { week in
            adherence(of: plan, week: week, isCurrent: week == current, calendar: calendar)
        }
    }

    public struct SessionsKPI: Equatable, Sendable {
        public var done: Int
        public var planned: Int

        public init(done: Int, planned: Int) {
            self.done = done
            self.planned = planned
        }
    }

    /// The plan week `now` falls in: the first week before the plan starts, the last once it's
    /// over.
    public static func sessionsKPI(
        of plan: Plan, now: Date = .now, calendar: Calendar = .init(identifier: .iso8601)
    ) -> SessionsKPI {
        let week = PlanCalendar(plan: plan, calendar: calendar).clampedWeek(containing: now)
        let entry = adherence(of: plan, week: week, isCurrent: true, calendar: calendar)
        return SessionsKPI(done: entry.done, planned: entry.planned)
    }

    /// Consecutive weeks that hit their planned sessions, counting back from the latest finished
    /// week. The current week adds to the streak once it's hit and never breaks it while it's in
    /// progress. Deload weeks count like any other, a missed week ends the streak, and a week
    /// with nothing planned is passed over.
    public static func streak(_ weeks: [WeekAdherence]) -> Int {
        var count = 0
        for week in weeks.sorted(by: { $0.week > $1.week }) where week.planned > 0 {
            if week.isHit {
                count += 1
            } else if !week.isCurrent {
                break
            }
        }
        return count
    }

    static func adherence(of plan: Plan, week: Int, isCurrent: Bool, calendar: Calendar) -> WeekAdherence {
        let days = (plan.days ?? []).filter { $0.week == week }
        let done = days.count { day in (day.workouts ?? []).contains { $0.endedAt != nil } }
        let weekStart = PlanCalendar(plan: plan, calendar: calendar).start(ofWeek: week)
        return WeekAdherence(
            week: week, weekStart: weekStart, planned: days.count, done: done,
            isDeload: plan.phase(forWeek: week)?.isDeload ?? false, isCurrent: isCurrent)
    }
}
