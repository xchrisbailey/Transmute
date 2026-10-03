import Foundation

/// Which training reminders this device sends (#19). Both are off until the person turns them
/// on. Kept in user defaults, so each device decides for itself; the watch mirrors the iPhone's.
public struct ReminderSettings: Equatable, Sendable {
    /// Bool. A reminder on each planned training day.
    public static let trainingDayKey = "reminders.trainingDay"
    /// Int. When that reminder comes, in minutes after midnight.
    public static let trainingDayMinutesKey = "reminders.trainingDay.minutes"
    /// Bool. A nudge the morning after a planned day with no workout.
    public static let missedDayKey = "reminders.missedDay"

    /// 08:00, until the person picks a time.
    public static let defaultMinutes = 8 * 60

    public var remindsOnTrainingDays: Bool
    /// The time of day of the training-day reminder, in minutes after midnight.
    public var trainingDayMinutes: Int
    public var nudgesAfterMissedDay: Bool

    public init(
        remindsOnTrainingDays: Bool = false, trainingDayMinutes: Int = defaultMinutes,
        nudgesAfterMissedDay: Bool = false
    ) {
        self.remindsOnTrainingDays = remindsOnTrainingDays
        self.trainingDayMinutes = min(max(trainingDayMinutes, 0), 24 * 60 - 1)
        self.nudgesAfterMissedDay = nudgesAfterMissedDay
    }

    /// True when either reminder is on, so notifications need permission.
    public var isOn: Bool {
        remindsOnTrainingDays || nudgesAfterMissedDay
    }

    public static func load(from defaults: UserDefaults = .standard) -> ReminderSettings {
        ReminderSettings(
            remindsOnTrainingDays: defaults.bool(forKey: trainingDayKey),
            trainingDayMinutes: defaults.object(forKey: trainingDayMinutesKey) as? Int ?? defaultMinutes,
            nudgesAfterMissedDay: defaults.bool(forKey: missedDayKey))
    }

    public func save(to defaults: UserDefaults = .standard) {
        defaults.set(remindsOnTrainingDays, forKey: Self.trainingDayKey)
        defaults.set(trainingDayMinutes, forKey: Self.trainingDayMinutesKey)
        defaults.set(nudgesAfterMissedDay, forKey: Self.missedDayKey)
    }

    // MARK: Time of day

    /// The reminder time as a date on `day`, for a time picker.
    public func trainingDayTime(on day: Date = .now, calendar: Calendar = .current) -> Date {
        ReminderPlanner.date(atMinutes: trainingDayMinutes, on: day, calendar: calendar)
    }

    /// Takes the hour and minute of `time` as the reminder time.
    public mutating func setTrainingDayTime(_ time: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.hour, .minute], from: time)
        trainingDayMinutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}
