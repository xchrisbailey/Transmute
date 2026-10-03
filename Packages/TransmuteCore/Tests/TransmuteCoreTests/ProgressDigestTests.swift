import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

@MainActor
struct ProgressDigestTests {
    typealias Stats = ProgressStats
    let fixture: ProgressFixture
    var calendar: Calendar { fixture.calendar }

    init() throws {
        fixture = try ProgressFixture()
    }

    // MARK: Adherence

    /// Four weeks of Monday and Wednesday sessions, week 3 a deload. Weeks 1 and 3 are done in
    /// full, week 2 has one session finished and one still running, week 4 has nothing.
    func adherencePlan() throws -> Plan {
        let plan = fixture.plan(weeks: 4, weekdays: [1, 3])
        plan.phases = [
            PlanPhase(name: "Build", focus: "", firstWeek: 1, lastWeek: 2),
            PlanPhase(name: "Deload", focus: "", firstWeek: 3, lastWeek: 3, isDeload: true),
            PlanPhase(name: "Peak", focus: "", firstWeek: 4, lastWeek: 4),
        ]
        for (week, weekday, finished) in [
            (1, 1, true), (1, 3, true), (2, 1, true), (2, 3, false), (3, 1, true), (3, 3, true),
        ] {
            fixture.workout(
                day: (week - 1) * 7 + weekday - 1, finished: finished,
                planDay: fixture.planDay(plan, week: week, weekday: weekday), [])
        }
        // A session off the plan doesn't count towards it.
        fixture.workout(day: 8, [])
        try fixture.context.save()
        return plan
    }

    @Test func adherenceCountsFinishedPlannedSessionsUpToTheCurrentWeek() throws {
        let plan = try adherencePlan()
        let week = Stats.WeekAdherence.init

        let weeks = Stats.adherence(of: plan, now: fixture.evening(17), calendar: calendar)
        #expect(
            weeks == [
                week(1, fixture.day(0), 2, 2, false, false), week(2, fixture.day(7), 2, 1, false, false),
                week(3, fixture.day(14), 2, 2, true, true),
            ])
        #expect(weeks.map(\.isHit) == [true, false, true])
        #expect(Stats.streak(weeks) == 1)

        #expect(Stats.adherence(of: plan, now: fixture.day(-1), calendar: calendar).isEmpty)
        // Once the plan is over every week is listed and none is current.
        let after = Stats.adherence(of: plan, now: fixture.day(40), calendar: calendar)
        #expect(after.map(\.week) == [1, 2, 3, 4])
        #expect(after.map(\.done) == [2, 1, 2, 0])
        #expect(after.map(\.isCurrent) == [false, false, false, false])
        #expect(Stats.streak(after) == 0)
    }

    @Test func sessionsKPIIsThePlanWeekNowFallsIn() throws {
        let plan = try adherencePlan()
        #expect(Stats.sessionsKPI(of: plan, now: fixture.day(9), calendar: calendar) == .init(done: 1, planned: 2))
        #expect(Stats.sessionsKPI(of: plan, now: fixture.day(20), calendar: calendar) == .init(done: 2, planned: 2))
        #expect(Stats.sessionsKPI(of: plan, now: fixture.day(21), calendar: calendar) == .init(done: 0, planned: 2))
        // Clamped to the plan: the first week before it starts, the last once it's over.
        #expect(Stats.sessionsKPI(of: plan, now: fixture.day(-30), calendar: calendar) == .init(done: 2, planned: 2))
        #expect(Stats.sessionsKPI(of: plan, now: fixture.day(90), calendar: calendar) == .init(done: 0, planned: 2))
    }

    // MARK: Streak

    /// Weeks of three planned sessions with the given numbers done; the last may be current.
    func weeks(_ done: [Int], currentLast: Bool = true, deload: Set<Int> = []) -> [Stats.WeekAdherence] {
        done.enumerated().map { index, sessions in
            Stats.WeekAdherence(
                week: index + 1, weekStart: fixture.day(index * 7), planned: 3, done: sessions,
                isDeload: deload.contains(index + 1), isCurrent: currentLast && index == done.count - 1)
        }
    }

    @Test func streakCountsBackFromTheLastCompletedWeek() {
        #expect(Stats.streak([]) == 0)
        #expect(Stats.streak(weeks([3, 3], currentLast: false)) == 2)
        // The week in progress doesn't break the streak, and extends it once it's hit.
        #expect(Stats.streak(weeks([3, 3, 1])) == 2)
        #expect(Stats.streak(weeks([3, 3, 0])) == 2)
        #expect(Stats.streak(weeks([3, 3, 3])) == 3)
        #expect(Stats.streak(weeks([3, 4, 3])) == 3)
        #expect(Stats.streak(weeks([0])) == 0)
    }

    @Test func aMissedWeekResetsTheStreak() {
        #expect(Stats.streak(weeks([3, 2, 3, 1])) == 1)
        #expect(Stats.streak(weeks([3, 3, 2, 1])) == 0)
        #expect(Stats.streak(weeks([3, 3, 2, 3])) == 1)
        #expect(Stats.streak(weeks([3, 3, 2], currentLast: false)) == 0)
    }

    @Test func deloadWeeksCountAndOrderDoesNotMatter() {
        #expect(Stats.streak(weeks([3, 3, 3, 1], deload: [3])) == 3)
        #expect(Stats.streak(weeks([3, 3, 2, 1], deload: [3])) == 0)
        #expect(Stats.streak(weeks([3, 2, 3, 3, 1]).reversed() as [Stats.WeekAdherence]) == 2)

        // A week with nothing planned neither counts nor breaks.
        var rest = weeks([3, 3, 3, 1])
        rest[1].planned = 0
        rest[1].done = 0
        #expect(Stats.streak(rest) == 2)
    }

    // MARK: Digest

    /// One session a week for three of a plan's four weeks. The squat goes 100, 100, 95 and the
    /// bench 60, 62.5, 65.
    func digestLog() throws -> (plan: Plan, workouts: [Workout], records: [PersonalRecord]) {
        let plan = fixture.plan(weeks: 4, [("back-squat", 4), ("bench-press", 3)])
        let loads: [(squat: Double, bench: Double)] = [(100, 60), (100, 62.5), (95, 65)]
        let workouts = loads.enumerated().map { week, load in
            fixture.workout(
                day: week * 7, planDay: fixture.planDay(plan, week: week + 1),
                [
                    ("back-squat", [fixture.set(kg: load.squat, reps: 1)]),
                    ("bench-press", [fixture.set(kg: load.bench, reps: 1)]),
                ])
        }
        let old = workouts[0].orderedExercises[1].orderedSets[0]
        let best = workouts[2].orderedExercises[1].orderedSets[0]
        let records = [
            fixture.record("bench-press", .repMax, 60, reps: 1, set: old),
            fixture.record("bench-press", .estimatedOneRepMax, 65, set: best),
            fixture.record("bench-press", .repMax, 65, reps: 1, set: best),
        ]
        try fixture.context.save()
        return (plan, workouts, records)
    }

    @Test func digestSumsUpTheWeek() throws {
        let log = try digestLog()
        let digest = Stats.digest(
            plan: log.plan, workouts: log.workouts, records: log.records, now: fixture.evening(17), calendar: calendar)

        #expect(
            digest
                == Stats.WeekDigest(
                    weekStart: fixture.day(14), sessionsDone: 1, sessionsPlanned: 1, volumeKg: 160,
                    volumeChange: (160 - 162.5) / 162.5,
                    // The rep max leads its set, ahead of the estimate.
                    records: [
                        .init(
                            exerciseID: "bench-press", name: "Bench press",
                            mark: .init(kind: .repMax, value: 65, reps: 1))
                    ],
                    wentUp: [.init(exerciseID: "bench-press", name: "Bench press", fromKg: 62.5, toKg: 65)],
                    stalled: [.init(exerciseID: "back-squat", name: "Back squat", fromKg: 100, toKg: 95)],
                    streakWeeks: 3, isEmpty: false))
    }

    @Test func stalledNeedsThreeSessions() throws {
        let log = try digestLog()
        // In week 2 the squat has two flat sessions, which isn't enough to call.
        let digest = Stats.digest(
            plan: log.plan, workouts: log.workouts, records: log.records, now: fixture.evening(10), calendar: calendar)

        #expect(digest.stalled.isEmpty)
        #expect(digest.wentUp == [.init(exerciseID: "bench-press", name: "Bench press", fromKg: 60, toKg: 62.5)])
        #expect(digest.records.isEmpty)
        #expect(digest.volumeKg == 162.5 && digest.volumeChange == (162.5 - 160) / 160)
        #expect(digest.streakWeeks == 2)

        // Flat counts as stalled once there are three.
        let flat = (0..<3).map { fixture.workout(day: $0 * 7, [("deadlift", [fixture.set(kg: 150, reps: 1)])]) }
        let third = Stats.digest(plan: nil, workouts: flat, records: [], now: fixture.evening(17), calendar: calendar)
        #expect(third.stalled == [.init(exerciseID: "deadlift", name: "Deadlift", fromKg: 150, toKg: 150)])
        #expect(third.sessionsDone == 1 && third.sessionsPlanned == 0 && third.streakWeeks == 0)
    }

    @Test func digestForAWeekWithNothingLogged() throws {
        let log = try digestLog()
        let running = fixture.workout(day: 22, finished: false, [("back-squat", [fixture.set(kg: 200, reps: 1)])])
        let digest = Stats.digest(
            plan: log.plan, workouts: log.workouts + [running], records: log.records, now: fixture.evening(24),
            calendar: calendar)

        // The week in progress doesn't break the streak, and nothing moved without a session.
        #expect(
            digest
                == Stats.WeekDigest(
                    weekStart: fixture.day(21), sessionsDone: 0, sessionsPlanned: 1, volumeKg: 0, volumeChange: -1,
                    streakWeeks: 3, isEmpty: true))

        let nothing = Stats.digest(plan: nil, workouts: [], records: [], now: fixture.evening(24), calendar: calendar)
        #expect(nothing == Stats.WeekDigest(weekStart: fixture.day(21)))
        #expect(nothing.isEmpty && nothing.volumeChange == nil)
    }

    // MARK: Sample data

    @Test func sampleDataExercisesEveryStat() throws {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let (profile, plan) = SampleData.insert(into: fixture.context, now: now)
        try RecordBook(context: fixture.context).recomputeAll()
        try fixture.context.save()
        let workouts = try fixture.context.fetch(FetchDescriptor<Workout>())
        let records = try fixture.context.fetch(FetchDescriptor<PersonalRecord>())

        let lifts = Stats.liftKPIs(plan: plan, workouts: workouts, records: records)
        #expect(lifts.map(\.exerciseID) == ["back-squat", "bench-press", "romanian-deadlift", "bulgarian-split-squat"])
        #expect(lifts.allSatisfy { ($0.changeKg ?? 0) > 0 })
        let squat = Stats.maxTrend(of: "back-squat", workouts: workouts, records: records)
        #expect(squat.map(\.isRecord) == [false, true, true])

        let volume = Stats.weeklyVolume(workouts, by: .muscle, now: now)
        #expect(volume.count == 3 && volume.allSatisfy { $0.slices.count > 1 })
        #expect(Stats.bodyweightTrend(profile.bodyweights ?? []).count == 4)
        #expect(Stats.bodyweightKPI(profile.bodyweights ?? [])?.changeKg != nil)
        #expect(Set(Stats.conditioning(workouts, limit: 20).map(\.metric)) == [.rounds, .pace, .longestTime, .reps])

        let weeks = Stats.adherence(of: plan, now: now)
        #expect(weeks.map(\.done) == [3, 3, 3, 0])
        #expect(weeks.map(\.isDeload) == [false, false, false, true])
        #expect(weeks.last?.isCurrent == true)
        #expect(Stats.streak(weeks) == 3)
        #expect(Stats.sessionsKPI(of: plan, now: now) == .init(done: 0, planned: 3))

        let lastWeek = Stats.digest(
            plan: plan, workouts: workouts, records: records, now: now.addingTimeInterval(-7 * 86_400))
        #expect(!lastWeek.isEmpty && !lastWeek.records.isEmpty && lastWeek.wentUp.count == 4)
        #expect(Stats.digest(plan: plan, workouts: workouts, records: records, now: now).isEmpty)
    }
}
