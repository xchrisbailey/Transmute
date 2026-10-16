import Foundation
import Testing

@testable import TransmuteCore

struct PlanCalendarTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()

    func date(_ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    /// Six weeks starting on Saturday 3 October 2026, so week 1 begins on Monday 28 September.
    func saturdayPlan(weekCount: Int = 6) -> PlanCalendar {
        PlanCalendar(startDate: date(10, 3, hour: 9), weekCount: weekCount, calendar: calendar)
    }

    @Test func aSaturdayStartMakesTheFollowingMondayWeekTwo() {
        let plan = saturdayPlan()
        #expect(plan.week(containing: date(10, 3, hour: 9)) == 1)
        #expect(plan.week(containing: date(10, 4, hour: 23, minute: 59)) == 1)
        #expect(plan.week(containing: date(10, 5)) == 2)
        #expect(plan.clampedWeek(containing: date(10, 5)) == 2)
    }

    @Test func weeksStartOnMondayMidnight() {
        let plan = saturdayPlan()
        #expect(plan.start(ofWeek: 1) == date(9, 28))
        #expect(plan.start(ofWeek: 2) == date(10, 5))
        #expect(plan.start(ofWeek: 3) == date(10, 12))
    }

    @Test func aWeekRunsFromItsMondayThroughItsSunday() {
        let plan = saturdayPlan()
        #expect(plan.week(containing: date(10, 11, hour: 23, minute: 59)) == 2)
        #expect(plan.week(containing: date(10, 12)) == 3)
        #expect(plan.week(containing: date(10, 12, hour: 0, minute: 1)) == 3)
    }

    @Test func aMondayStartMakesThatMondayWeekOne() {
        let plan = PlanCalendar(startDate: date(9, 28), weekCount: 4, calendar: calendar)
        #expect(plan.start(ofWeek: 1) == date(9, 28))
        #expect(plan.week(containing: date(10, 4, hour: 23)) == 1)
        #expect(plan.week(containing: date(10, 5)) == 2)
    }

    @Test func aSundayStartBelongsToTheWeekBefore() {
        let plan = PlanCalendar(startDate: date(10, 4), weekCount: 4, calendar: calendar)
        #expect(plan.start(ofWeek: 1) == date(9, 28))
        #expect(plan.week(containing: date(10, 5)) == 2)
    }

    @Test func beforeThePlanStartsIsWeekZeroAndClampsToOne() {
        let plan = saturdayPlan()
        #expect(plan.week(containing: date(9, 27, hour: 23, minute: 59)) == 0)
        #expect(plan.clampedWeek(containing: date(9, 27, hour: 23, minute: 59)) == 1)
        // The days before the start date, in the start's own week, are already week 1.
        #expect(plan.week(containing: date(9, 28)) == 1)
    }

    @Test func afterThePlanEndsCountsOnAndClampsToTheLastWeek() {
        let plan = saturdayPlan(weekCount: 4)
        #expect(plan.week(containing: date(10, 26)) == 5)
        #expect(plan.week(containing: date(12, 31)) == 14)
        #expect(plan.clampedWeek(containing: date(10, 26)) == 4)
        #expect(plan.clampedWeek(containing: date(12, 31)) == 4)
    }

    @Test func aPlanWithNoWeeksClampsToWeekOne() {
        let plan = saturdayPlan(weekCount: 0)
        #expect(plan.clampedWeek(containing: date(12, 31)) == 1)
    }

    @Test func aPlanDayIsDatedFromItsWeekAndWeekday() {
        let plan = saturdayPlan()
        #expect(plan.date(week: 1, weekday: 1) == date(9, 28))
        #expect(plan.date(week: 1, weekday: 6) == date(10, 3))
        #expect(plan.date(week: 2, weekday: 1) == date(10, 5))
        #expect(plan.date(week: 3, weekday: 7) == date(10, 18))
    }

    @Test func theClockChangeDoesNotShiftWeeksOrDays() {
        // The clocks go back at 02:00 on Sunday 25 October, so that week is 25 hours long.
        let plan = saturdayPlan()
        #expect(plan.week(containing: date(10, 25, hour: 23, minute: 30)) == 4)
        #expect(plan.week(containing: date(10, 26)) == 5)
        #expect(plan.week(containing: date(10, 26, hour: 0, minute: 30)) == 5)
        #expect(plan.start(ofWeek: 5) == date(10, 26))
        #expect(plan.start(ofWeek: 6) == date(11, 2))
        #expect(plan.date(week: 4, weekday: 7) == date(10, 25))
        #expect(plan.date(week: 5, weekday: 1) == date(10, 26))
        #expect(plan.week(containing: date(11, 1, hour: 23, minute: 59)) == 5)
        #expect(plan.week(containing: date(11, 2)) == 6)
    }
}
