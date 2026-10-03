import Foundation
import Testing
import TransmuteCore

@testable import TransmuteUI

/// What Siri says for the shortcuts, built from a glance.
struct ShortcutCopyTests {
    static let bench = TodayGlance.NextLift(
        name: "Bench press", sets: 5, amount: "5", load: "80 kg", spokenAmount: "5", spokenLoad: "80 kilograms")
    static let plank = TodayGlance.NextLift(name: "Plank", sets: 3, amount: "0:45", spokenAmount: "45 seconds")
    static let week = TodayGlance.Week(done: 1, planned: 3)

    // MARK: What's my workout today?

    @Test func aSessionSaysItsNameFirstLiftAndTheWeek() {
        let glance = TodayGlance(day: .session("Lower A"), nextLift: Self.bench, streakWeeks: 3, week: Self.week)
        #expect(
            ShortcutCopy.today(glance)
                == "Today is Lower A. First up: Bench press, 5 sets of 5 at 80 kilograms. Sessions this week: 1 of 3.")
    }

    @Test func loadsAreSaidInFullNeverAsSymbols() {
        let glance = TodayGlance(day: .session("Lower A"), nextLift: Self.bench)
        #expect(!ShortcutCopy.today(glance).contains("kg"))
        #expect(ShortcutCopy.spoken(Self.plank) == "Plank, 3 sets of 45 seconds")
        #expect(ShortcutCopy.spoken(TodayGlance.NextLift(name: "Mobility flow", sets: 0)) == "Mobility flow")
    }

    @Test func aRunningWorkoutSaysTheCurrentLift() {
        let glance = TodayGlance(day: .session("Lower A"), isRunning: true, nextLift: Self.plank, week: Self.week)
        #expect(
            ShortcutCopy.today(glance)
                == "Lower A is in progress. Next: Plank, 3 sets of 45 seconds. Sessions this week: 1 of 3.")
        let adHoc = TodayGlance(isRunning: true, nextLift: Self.plank)
        #expect(ShortcutCopy.today(adHoc) == "A workout is in progress. Next: Plank, 3 sets of 45 seconds.")
    }

    @Test func aDoneSessionLeavesOutTheNextDaysLift() {
        let glance = TodayGlance(
            day: .session("Lower A"), isDone: true, nextLift: Self.bench, week: .init(done: 3, planned: 3))
        #expect(ShortcutCopy.today(glance) == "Lower A is done for today. Sessions this week: 3 of 3.")
    }

    @Test func aRestDayPointsAtTheNextSession() {
        let glance = TodayGlance(day: .rest, nextLift: Self.bench, week: Self.week)
        #expect(
            ShortcutCopy.today(glance)
                == "Today is a rest day. Your next session starts with Bench press, 5 sets of 5 at 80 kilograms. "
                + "Sessions this week: 1 of 3.")
        #expect(ShortcutCopy.today(TodayGlance(day: .rest)) == "Today is a rest day.")
    }

    @Test func aWeekWithNothingDoneSaysWhatIsPlanned() {
        let glance = TodayGlance(day: .rest, week: .init(done: 0, planned: 3))
        #expect(ShortcutCopy.today(glance) == "Today is a rest day. 3 sessions planned this week.")
        #expect(ShortcutCopy.week(.init()) == nil)
    }

    @Test func noPlanPointsAtTheApp() {
        #expect(
            ShortcutCopy.today(TodayGlance()) == "Nothing is planned for today. You can make a plan in Transmute.")
    }

    @Test func theSnippetHasAHeadingAStatusAndTheWeek() {
        #expect(ShortcutCopy.title(TodayGlance(day: .session("Lower A"))) == "Lower A")
        #expect(ShortcutCopy.title(TodayGlance(day: .rest)) == "Rest day")
        #expect(ShortcutCopy.title(TodayGlance()) == "Nothing planned")
        #expect(ShortcutCopy.status(TodayGlance(day: .session("Lower A"))) == nil)
        #expect(ShortcutCopy.status(TodayGlance(isRunning: true)).map { String(localized: $0) } == "In progress")
        #expect(ShortcutCopy.status(TodayGlance(isDone: true)).map { String(localized: $0) } == "Done")
        #expect(ShortcutCopy.weekFigure(Self.week) == "1 of 3 this week")
        #expect(ShortcutCopy.weekFigure(.init()) == nil)
    }

    // MARK: Begin today's workout

    @Test func beginStartsASessionStillToDoOrGoesBackIntoOne() {
        let toDo = TodayGlance(day: .session("Lower A"))
        #expect(ShortcutCopy.begin(toDo) == .begin)
        #expect(String(localized: ShortcutCopy.beginning(toDo)) == "Starting Lower A.")
        let running = TodayGlance(day: .session("Lower A"), isRunning: true)
        #expect(ShortcutCopy.begin(running) == .begin)
        #expect(String(localized: ShortcutCopy.beginning(running)) == "Back to Lower A.")
        let adHoc = TodayGlance(isRunning: true)
        #expect(ShortcutCopy.begin(adHoc) == .begin)
        #expect(String(localized: ShortcutCopy.beginning(adHoc)) == "Back to your workout.")
    }

    @Test func beginOnlyShowsTodayWhenThereIsNothingToStart() {
        let rest = TodayGlance(day: .rest, nextLift: Self.bench)
        #expect(ShortcutCopy.begin(rest) == .showToday)
        #expect(String(localized: ShortcutCopy.beginning(rest)) == "Today is a rest day. Transmute is open on Today.")
        let done = TodayGlance(day: .session("Lower A"), isDone: true)
        #expect(ShortcutCopy.begin(done) == .showToday)
        #expect(
            String(localized: ShortcutCopy.beginning(done)) == "Lower A is done for today. Transmute is open on Today.")
        #expect(ShortcutCopy.begin(TodayGlance()) == .showToday)
        #expect(
            String(localized: ShortcutCopy.beginning(TodayGlance()))
                == "Nothing is planned for today. Transmute is open on Today.")
    }

    // MARK: Log bodyweight

    @Test func loggingConfirmsTheWeightAndHealth() {
        #expect(String(localized: ShortcutCopy.logged("79.4 kilograms", inHealth: false)) == "Logged 79.4 kilograms.")
        #expect(
            String(localized: ShortcutCopy.logged("175 pounds", inHealth: true))
                == "Logged 175 pounds, and saved it to Health.")
    }

    // MARK: Spotlight

    @Test func workoutSummariesSayExercisesAndVolume() {
        let units = Units(system: .metric, locale: Locale(identifier: "en_GB"))
        let lifted = WorkoutSummary(sets: 18, exercises: 6, volumeKg: 8_420, duration: 3_130)
        #expect(ShortcutCopy.workoutSummary(lifted, units: units) == "6 exercises · 8,420 kg")
        let run = WorkoutSummary(sets: 4, exercises: 2, volumeKg: 0, duration: 1_200)
        #expect(ShortcutCopy.workoutSummary(run, units: units) == "2 exercises")
    }

    @Test func planSummariesPreferTheGoal() {
        #expect(ShortcutCopy.planSummary(goal: "Stronger legs for tennis", weeks: 8) == "Stronger legs for tennis")
        #expect(ShortcutCopy.planSummary(goal: "", weeks: 8) == "8 weeks")
    }
}
