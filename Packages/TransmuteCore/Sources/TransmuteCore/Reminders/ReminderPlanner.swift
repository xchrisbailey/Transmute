import Foundation

/// One notification to schedule (#19).
public struct PlannedReminder: Hashable, Identifiable, Sendable {
    public enum Kind: String, Sendable {
        /// Today has a session, at the time the person chose.
        case trainingDay
        /// The morning after a planned day that got no workout.
        case missedDay
    }

    /// Stable for a kind and a planned day, so scheduling twice replaces rather than doubles.
    public var id: String
    public var kind: Kind
    public var fireDate: Date
    /// The plan day's focus, e.g. "Lower A". Empty when the day has none.
    public var sessionName: String

    public init(id: String, kind: Kind, fireDate: Date, sessionName: String) {
        self.id = id
        self.kind = kind
        self.fireDate = fireDate
        self.sessionName = sessionName
    }
}

/// Works out which reminders are due over the next two weeks. It only reads the plan; the
/// scheduler in TransmuteLogUI hands the result to the system.
public enum ReminderPlanner {
    /// Every reminder's identifier starts with this. The rest alert's doesn't.
    public static let identifierPrefix = "transmute.reminder."
    /// How far ahead reminders are scheduled. Opening the app plans the days after.
    public static let horizonDays = 14
    /// The missed-day nudge comes at 09:00.
    public static let nudgeMinutes = 9 * 60
    /// iOS keeps at most this many pending notifications for an app.
    public static let pendingLimit = 64

    /// The reminders to have pending, soonest first.
    ///
    /// A training-day reminder goes on each planned day from today on that has no workout,
    /// leaving today out once its time has passed. A nudge goes on the morning after the
    /// soonest planned day without a workout: only ever one, so nudges don't pile up while the
    /// app stays closed, none when the person has trained since that day began, and none on a
    /// morning that already has a training-day reminder.
    /// - Parameters:
    ///   - plan: The active plan, if there is one.
    ///   - lastWorkoutAt: When the latest workout started, on or off the plan.
    ///   - limit: The most reminders to return.
    public static func reminders(
        plan: Plan?, lastWorkoutAt: Date? = nil, settings: ReminderSettings, now: Date = .now,
        calendar: Calendar = .init(identifier: .iso8601), limit: Int = pendingLimit
    ) -> [PlannedReminder] {
        guard let plan, settings.isOn else { return [] }
        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
            let end = calendar.date(byAdding: .day, value: horizonDays, to: today)
        else { return [] }

        // Planned days nobody has trained on yet, by the same dates the plan screen shows.
        let open = plan.orderedDays.filter { ($0.workouts ?? []).isEmpty }.map {
            (date: calendar.startOfDay(for: PlanEditor.date(of: $0, in: plan, calendar: calendar)), name: $0.focus)
        }
        .filter { $0.date >= yesterday && $0.date < end }
        .sorted { $0.date < $1.date }

        var reminders: [PlannedReminder] = []
        if settings.remindsOnTrainingDays {
            reminders = open.filter { $0.date >= today }.map {
                PlannedReminder(
                    id: identifier(.trainingDay, for: $0.date, calendar: calendar), kind: .trainingDay,
                    fireDate: date(atMinutes: settings.trainingDayMinutes, on: $0.date, calendar: calendar),
                    sessionName: $0.name)
            }
        }
        if settings.nudgesAfterMissedDay {
            let reminded = Set(settings.remindsOnTrainingDays ? open.map(\.date) : [])
            let nudges = open.compactMap { session -> PlannedReminder? in
                if let lastWorkoutAt, lastWorkoutAt >= session.date { return nil }
                guard let morning = calendar.date(byAdding: .day, value: 1, to: session.date),
                    !reminded.contains(morning)
                else { return nil }
                return PlannedReminder(
                    id: identifier(.missedDay, for: session.date, calendar: calendar), kind: .missedDay,
                    fireDate: date(atMinutes: nudgeMinutes, on: morning, calendar: calendar),
                    sessionName: session.name)
            }
            if let nudge = nudges.first(where: { $0.fireDate > now }) {
                reminders.append(nudge)
            }
        }
        return Array(reminders.filter { $0.fireDate > now }.sorted { $0.fireDate < $1.fireDate }.prefix(max(limit, 0)))
    }

    /// e.g. "transmute.reminder.trainingDay.2026-10-05", by the planned day's date.
    static func identifier(_ kind: PlannedReminder.Kind, for day: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        let date = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        return "\(identifierPrefix)\(kind.rawValue).\(date)"
    }

    /// A time of day on a date, in minutes after midnight.
    static func date(atMinutes minutes: Int, on day: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: day)
        return calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: start)
            ?? start.addingTimeInterval(TimeInterval(minutes * 60))
    }
}
