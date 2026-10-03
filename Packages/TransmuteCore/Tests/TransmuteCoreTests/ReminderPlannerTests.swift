import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

@MainActor
struct ReminderPlannerTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()
    /// Reminders at 18:00 and nudges, both on.
    let both = ReminderSettings(remindsOnTrainingDays: true, trainingDayMinutes: 18 * 60, nudgesAfterMissedDay: true)
    let nudgeOnly = ReminderSettings(nudgesAfterMissedDay: true)

    init() throws {
        container = try TransmuteStore.makeContainer(.inMemory)
    }

    /// Monday 5 October 2026, the first day of the plan.
    var monday: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 5))!
    }

    /// A time on a day of the plan, counting days from its first Monday.
    func time(day: Int, hour: Int, minute: Int = 0) -> Date {
        let date = calendar.date(byAdding: .day, value: day, to: monday)!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date)!
    }

    /// Four weeks of Monday "Lower", Wednesday "Upper" and Friday "Speed".
    func plan() throws -> Plan {
        let plan = Plan(name: "Test", startDate: monday, weekCount: 4)
        for week in 1...4 {
            for (weekday, focus) in [(1, "Lower"), (3, "Upper"), (5, "Speed")] {
                plan.days?.append(PlanDay(week: week, weekday: weekday, focus: focus))
            }
        }
        context.insert(plan)
        try context.save()
        return plan
    }

    /// Logs a workout against a plan day, finished an hour after `start` unless it's still going.
    func log(_ plan: Plan, week: Int, weekday: Int, at start: Date, finished: Bool = true) throws {
        let day = try #require(PlanEditor.day(of: plan, week: week, weekday: weekday))
        let workout = Workout(title: day.focus, startedAt: start, planDay: day)
        workout.endedAt = finished ? start.addingTimeInterval(3_600) : nil
        context.insert(workout)
        try context.save()
    }

    func reminders(
        _ plan: Plan?, _ settings: ReminderSettings, now: Date, lastWorkoutAt: Date? = nil, limit: Int = 64
    ) -> [PlannedReminder] {
        ReminderPlanner.reminders(
            plan: plan, lastWorkoutAt: lastWorkoutAt, settings: settings, now: now, calendar: calendar, limit: limit)
    }

    // MARK: Off

    @Test func nothingIsPlannedByDefault() throws {
        #expect(ReminderSettings() == ReminderSettings(remindsOnTrainingDays: false, nudgesAfterMissedDay: false))
        #expect(reminders(try plan(), ReminderSettings(), now: time(day: 0, hour: 7)).isEmpty)
    }

    @Test func nothingIsPlannedWithoutAPlan() {
        #expect(reminders(nil, both, now: time(day: 0, hour: 7)).isEmpty)
    }

    // MARK: Training days

    @Test func remindsOnEachPlannedDayOfTheNextTwoWeeks() throws {
        let settings = ReminderSettings(remindsOnTrainingDays: true, trainingDayMinutes: 18 * 60)
        let planned = reminders(try plan(), settings, now: time(day: 0, hour: 7))
        #expect(planned.map(\.fireDate) == [0, 2, 4, 7, 9, 11].map { time(day: $0, hour: 18) })
        #expect(planned.map(\.sessionName) == ["Lower", "Upper", "Speed", "Lower", "Upper", "Speed"])
        #expect(planned.allSatisfy { $0.kind == .trainingDay })
        #expect(planned.first?.id == "transmute.reminder.trainingDay.2026-10-05")
        #expect(Set(planned.map(\.id)).count == planned.count)
        #expect(planned.allSatisfy { $0.id.hasPrefix(ReminderPlanner.identifierPrefix) })
    }

    @Test func skipsTodayOnceTheTimeHasPassed() throws {
        let settings = ReminderSettings(remindsOnTrainingDays: true, trainingDayMinutes: 18 * 60)
        let planned = reminders(try plan(), settings, now: time(day: 0, hour: 18))
        #expect(planned.first?.fireDate == time(day: 2, hour: 18))
    }

    @Test func skipsADayThatAlreadyHasAWorkout() throws {
        let plan = try plan()
        try log(plan, week: 1, weekday: 1, at: time(day: 0, hour: 6))
        try log(plan, week: 1, weekday: 3, at: time(day: 0, hour: 6, minute: 30), finished: false)
        let settings = ReminderSettings(remindsOnTrainingDays: true, trainingDayMinutes: 18 * 60)
        let planned = reminders(plan, settings, now: time(day: 0, hour: 7))
        #expect(planned.first?.fireDate == time(day: 4, hour: 18))
    }

    @Test func stopsWhenThePlanRunsOut() throws {
        let settings = ReminderSettings(remindsOnTrainingDays: true)
        let planned = reminders(try plan(), settings, now: time(day: 23, hour: 9))
        #expect(planned.map(\.fireDate) == [time(day: 25, hour: 8)])
        #expect(reminders(try plan(), both, now: time(day: 40, hour: 7)).isEmpty)
    }

    @Test func keepsToTheLimitSoonestFirst() throws {
        let planned = reminders(try plan(), both, now: time(day: 0, hour: 7), limit: 2)
        #expect(planned.map(\.fireDate) == [time(day: 0, hour: 18), time(day: 1, hour: 9)])
        #expect(reminders(try plan(), both, now: time(day: 0, hour: 7), limit: 0).isEmpty)
    }

    @Test func followsTheClockChange() throws {
        // British clocks go back on Sunday 25 October 2026; 18:00 stays 18:00 on the wall.
        let settings = ReminderSettings(remindsOnTrainingDays: true, trainingDayMinutes: 18 * 60)
        let planned = reminders(try plan(), settings, now: time(day: 18, hour: 19))
        #expect(planned.map(\.fireDate) == [21, 23, 25].map { time(day: $0, hour: 18) })
        #expect(planned.first.map { calendar.component(.hour, from: $0.fireDate) } == 18)
    }

    // MARK: Missed days

    @Test func nudgesTheMorningAfterAPlannedDay() throws {
        let planned = reminders(try plan(), nudgeOnly, now: time(day: 0, hour: 7))
        #expect(planned.count == 1)
        #expect(planned.first?.kind == .missedDay)
        #expect(planned.first?.fireDate == time(day: 1, hour: 9))
        #expect(planned.first?.sessionName == "Lower")
        #expect(planned.first?.id == "transmute.reminder.missedDay.2026-10-05")
    }

    @Test func nudgesForYesterdayUntilTheMorningHasPassed() throws {
        let plan = try plan()
        #expect(reminders(plan, nudgeOnly, now: time(day: 1, hour: 8)).map(\.fireDate) == [time(day: 1, hour: 9)])
        // After 09:00 Monday's nudge has gone; the next one is for Wednesday.
        #expect(reminders(plan, nudgeOnly, now: time(day: 1, hour: 9)).map(\.fireDate) == [time(day: 3, hour: 9)])
    }

    @Test func neverPlansMoreThanOneNudge() throws {
        // Nothing logged for a week and a half: still one nudge, for the latest day.
        let planned = reminders(try plan(), nudgeOnly, now: time(day: 10, hour: 7))
        #expect(planned.map(\.id) == ["transmute.reminder.missedDay.2026-10-14"])
        #expect(reminders(try plan(), both, now: time(day: 0, hour: 7)).filter { $0.kind == .missedDay }.count == 1)
    }

    @Test func aWorkoutOnTheDayMovesTheNudgeOn() throws {
        let plan = try plan()
        try log(plan, week: 1, weekday: 1, at: time(day: 0, hour: 17))
        let planned = reminders(plan, nudgeOnly, now: time(day: 0, hour: 19), lastWorkoutAt: time(day: 0, hour: 17))
        #expect(planned.map(\.fireDate) == [time(day: 3, hour: 9)])
    }

    @Test func noNudgeOnceThePersonHasTrainedSince() throws {
        let plan = try plan()
        // Monday's session wasn't logged, but there was a workout off the plan on Tuesday at 06:00.
        let planned = reminders(plan, nudgeOnly, now: time(day: 1, hour: 8), lastWorkoutAt: time(day: 1, hour: 6))
        #expect(planned.map(\.fireDate) == [time(day: 3, hour: 9)])
        // An older workout doesn't count.
        let before = reminders(plan, nudgeOnly, now: time(day: 1, hour: 8), lastWorkoutAt: time(day: -2, hour: 6))
        #expect(before.map(\.fireDate) == [time(day: 1, hour: 9)])
    }

    @Test func aTrainingDayReminderStandsInForTheNudge() throws {
        let plan = try plan()
        let wednesday = try #require(PlanEditor.day(of: plan, week: 1, weekday: 3))
        PlanEditor.move(wednesday, to: 2)
        // Monday and Tuesday are both planned: Tuesday's reminder is enough for that morning.
        let planned = reminders(plan, both, now: time(day: 0, hour: 19))
        #expect(planned.prefix(2).map(\.kind) == [.trainingDay, .missedDay])
        #expect(planned.prefix(2).map(\.fireDate) == [time(day: 1, hour: 18), time(day: 2, hour: 9)])
        // With only nudges on, Monday's nudge still comes on Tuesday.
        #expect(reminders(plan, nudgeOnly, now: time(day: 0, hour: 19)).first?.fireDate == time(day: 1, hour: 9))
    }

    // MARK: Settings

    @Test func settingsRoundTripThroughDefaults() throws {
        let name = "ReminderPlannerTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        #expect(ReminderSettings.load(from: defaults) == ReminderSettings())
        #expect(ReminderSettings.load(from: defaults).isOn == false)
        both.save(to: defaults)
        #expect(ReminderSettings.load(from: defaults) == both)
        #expect(defaults.integer(forKey: ReminderSettings.trainingDayMinutesKey) == 18 * 60)
    }

    @Test func timeOfDayConvertsToAndFromADate() {
        var settings = ReminderSettings()
        #expect(settings.trainingDayMinutes == 8 * 60)
        settings.setTrainingDayTime(time(day: 3, hour: 6, minute: 45), calendar: calendar)
        #expect(settings.trainingDayMinutes == 6 * 60 + 45)
        #expect(settings.trainingDayTime(on: monday, calendar: calendar) == time(day: 0, hour: 6, minute: 45))
        #expect(ReminderSettings(trainingDayMinutes: 5_000).trainingDayMinutes == 24 * 60 - 1)
    }
}
