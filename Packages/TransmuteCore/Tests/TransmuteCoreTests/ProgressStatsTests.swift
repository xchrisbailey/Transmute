import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

@MainActor
struct ProgressStatsTests {
    typealias Stats = ProgressStats
    let fixture: ProgressFixture

    init() throws {
        fixture = try ProgressFixture()
    }

    // MARK: Estimated one-rep max

    @Test func maxTrendTakesTheBestWorkingSetOfEachFinishedSession() throws {
        let first = fixture.workout(
            day: 0,
            [
                (
                    "back-squat",
                    [
                        fixture.set(kg: 140, reps: 1, warmUp: true), fixture.set(kg: 90, reps: 5),
                        fixture.set(kg: 100, reps: 1), fixture.set(kg: 200, reps: 1, completed: false),
                    ]
                ),
                ("bench-press", [fixture.set(kg: 300, reps: 1)]),
            ])
        let second = fixture.workout(day: 7, [("back-squat", [fixture.set(kg: 110, reps: 1)])])
        let running = fixture.workout(day: 8, finished: false, [("back-squat", [fixture.set(kg: 150, reps: 1)])])
        // Twelve reps say too little about a single to estimate from.
        let highReps = fixture.workout(day: 9, [("back-squat", [fixture.set(kg: 50, reps: 12)])])
        let records = [
            fixture.record("back-squat", .estimatedOneRepMax, 110, set: second.orderedExercises[0].orderedSets[0]),
            fixture.record("back-squat", .repMax, 90, reps: 5, set: first.orderedExercises[0].orderedSets[1]),
            fixture.record("bench-press", .estimatedOneRepMax, 300, set: first.orderedExercises[1].orderedSets[0]),
        ]
        try fixture.context.save()

        let trend = Stats.maxTrend(of: "back-squat", workouts: [highReps, running, second, first], records: records)
        #expect(
            trend == [
                Stats.MaxPoint(date: fixture.evening(0), kg: 90 * (1 + 5.0 / 30), isRecord: false),
                Stats.MaxPoint(date: fixture.evening(7), kg: 110, isRecord: true),
            ])
        #expect(Stats.maxTrend(of: "back-squat", workouts: [], records: []).isEmpty)
        #expect(Stats.maxTrend(of: "deadlift", workouts: [first, second], records: records).isEmpty)
    }

    // MARK: Key lifts

    @Test func keyLiftsRankThePlansWeightedExercisesByPlannedSets() {
        let plan = fixture.plan(
            weeks: 1, [("dumbbell-curl", 2), ("pull-up", 5), ("bench-press", 4), ("deadlift", 3), ("back-squat", 4)])
        // A planned warm-up isn't a working set, which leaves the deadlift level with the curl.
        fixture.planDay(plan, week: 1).orderedExercises[3].orderedSets[0].isWarmUp = true

        // Ties go in library order; the pull-up is reps only.
        #expect(
            Stats.keyLifts(of: plan, workouts: []) == ["back-squat", "bench-press", "deadlift", "dumbbell-curl"])
        #expect(Stats.keyLifts(of: plan, workouts: [], limit: 2) == ["back-squat", "bench-press"])
    }

    @Test func keyLiftsWithoutAPlanAreTheMostLoggedWeightedExercises() {
        let logged = fixture.workout(
            day: 0,
            [
                ("pull-up", [fixture.set(reps: 8), fixture.set(reps: 8), fixture.set(reps: 8), fixture.set(reps: 8)]),
                ("back-squat", [fixture.set(kg: 100, reps: 5), fixture.set(kg: 60, reps: 5, warmUp: true)]),
                ("dumbbell-curl", [fixture.set(kg: 10, reps: 10), fixture.set(kg: 10, reps: 10)]),
            ])
        let running = fixture.workout(day: 1, finished: false, [("deadlift", [fixture.set(kg: 100, reps: 5)])])

        #expect(Stats.keyLifts(of: nil, workouts: [logged, running]) == ["dumbbell-curl", "back-squat"])
        #expect(Stats.keyLifts(of: nil, workouts: []).isEmpty)
        // A plan with no weighted exercise falls back to the log too.
        let plan = fixture.plan(weeks: 1, [("pull-up", 3)])
        #expect(Stats.keyLifts(of: plan, workouts: [logged], limit: 1) == ["dumbbell-curl"])
    }

    @Test func liftKPIsCompareTheLatestSessionWithTheFirstInTheWindow() {
        let workouts = [
            fixture.workout(
                day: 0,
                [
                    ("back-squat", [fixture.set(kg: 100, reps: 1), fixture.set(kg: 95, reps: 1)]),
                    ("dumbbell-curl", [fixture.set(kg: 20, reps: 1)]),
                ]),
            fixture.workout(day: 7, [("back-squat", [fixture.set(kg: 105, reps: 1), fixture.set(kg: 95, reps: 1)])]),
            fixture.workout(day: 14, [("back-squat", [fixture.set(kg: 110, reps: 1), fixture.set(kg: 95, reps: 1)])]),
        ]

        #expect(
            Stats.liftKPIs(plan: nil, workouts: workouts, records: []) == [
                Stats.LiftKPI(exerciseID: "back-squat", name: "Back squat", currentKg: 110, changeKg: 10),
                Stats.LiftKPI(exerciseID: "dumbbell-curl", name: "Dumbbell curl", currentKg: 20, changeKg: nil),
            ])
        #expect(
            Stats.liftKPIs(plan: nil, workouts: workouts, records: [], since: fixture.day(5)) == [
                Stats.LiftKPI(exerciseID: "back-squat", name: "Back squat", currentKg: 110, changeKg: 5)
            ])
        #expect(Stats.liftKPIs(plan: nil, workouts: [], records: []).isEmpty)
    }

    // MARK: Volume

    func volumeLog() -> [Workout] {
        [
            fixture.workout(
                day: 0,
                [
                    (
                        "back-squat",
                        [
                            fixture.set(kg: 50, reps: 5, warmUp: true), fixture.set(kg: 100, reps: 5),
                            fixture.set(kg: 100, reps: 5), fixture.set(kg: 100, reps: 5, completed: false),
                        ]
                    ),
                    ("dumbbell-curl", [fixture.set(kg: 10, reps: 10)]),
                    ("pull-up", [fixture.set(reps: 10)]),
                ]),
            fixture.workout(day: 8, finished: false, [("back-squat", [fixture.set(kg: 999, reps: 1)])]),
            fixture.workout(
                day: 15,
                [
                    ("bench-press", [fixture.set(kg: 50, reps: 10)]),
                    ("custom-sled-drag", [fixture.set(kg: 10, reps: 10)]),
                ]),
        ]
    }

    @Test func weeklyVolumeSplitsByGroupAndKeepsEmptyWeeks() {
        let log = volumeLog()
        let now = fixture.evening(17)
        let slice = Stats.VolumeSlice.init

        let byCategory = Stats.weeklyVolume(log, by: .category, now: now, calendar: fixture.calendar)
        #expect(
            byCategory == [
                Stats.WeekVolume(weekStart: fixture.day(0), slices: [slice("strength", 1_100)]),
                Stats.WeekVolume(weekStart: fixture.day(7), slices: []),
                Stats.WeekVolume(weekStart: fixture.day(14), slices: [slice("strength", 500), slice("other", 100)]),
            ])
        #expect(byCategory.map(\.totalKg) == [1_100, 0, 600])

        // Volume goes to the first primary muscle, in the order `Muscle` lists them.
        let byMuscle = Stats.weeklyVolume(log, by: .muscle, now: now, calendar: fixture.calendar)
        #expect(
            byMuscle.map(\.slices) == [
                [slice("quads", 1_000), slice("biceps", 100)], [],
                [slice("chest", 500), slice("other", 100)],
            ])
    }

    @Test func weeklyVolumeIsLimitedToTheLastWeeks() {
        let log = volumeLog()
        let recent = Stats.weeklyVolume(
            log, by: .category, weeks: 2, now: fixture.evening(17), calendar: fixture.calendar)
        #expect(recent.map(\.weekStart) == [fixture.day(14)])

        // Later weeks aren't counted either, and nothing in the window means no weeks at all.
        let earlier = Stats.weeklyVolume(log, by: .category, now: fixture.evening(3), calendar: fixture.calendar)
        #expect(earlier.map(\.weekStart) == [fixture.day(0)])
        #expect(Stats.weeklyVolume(log, by: .category, weeks: 0, now: fixture.evening(17)).isEmpty)
        #expect(Stats.weeklyVolume([], by: .muscle, now: fixture.evening(17), calendar: fixture.calendar).isEmpty)
    }

    @Test func volumeKPIComparesThisWeekWithLast() {
        var log = volumeLog()
        let calendar = fixture.calendar
        #expect(
            Stats.volumeKPI(log, now: fixture.evening(17), calendar: calendar)
                == Stats.VolumeKPI(thisWeekKg: 600, lastWeekKg: 0))
        #expect(Stats.volumeKPI(log, now: fixture.evening(17), calendar: calendar).change == nil)
        #expect(Stats.volumeKPI(log, now: fixture.evening(10), calendar: calendar).change == -1)

        log.append(fixture.workout(day: 22, [("back-squat", [fixture.set(kg: 75, reps: 10)])]))
        let kpi = Stats.volumeKPI(log, now: fixture.day(27), calendar: calendar)
        #expect(kpi.thisWeekKg == 750 && kpi.lastWeekKg == 600 && kpi.change == 0.25)
        #expect(
            Stats.volumeKPI([], now: fixture.day(0), calendar: calendar)
                == Stats.VolumeKPI(thisWeekKg: 0, lastWeekKg: 0))
    }
}
