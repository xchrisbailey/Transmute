import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

@MainActor
struct ProgressBodyTests {
    typealias Stats = ProgressStats
    let fixture: ProgressFixture

    init() throws {
        fixture = try ProgressFixture()
    }

    // MARK: Bodyweight

    @Test func bodyweightTrendIsASevenDayRollingMean() {
        let entries = [(10, 77.0), (0, 80.0), (7, 78.0), (3, 79.0)].map {
            BodyweightEntry(date: fixture.day($0.0), kg: $0.1)
        }
        let point = Stats.BodyweightPoint.init

        #expect(
            Stats.bodyweightTrend(entries) == [
                point(fixture.day(0), 80, 80), point(fixture.day(3), 79, 79.5),
                // A weigh-in exactly seven days back has dropped out of the window.
                point(fixture.day(7), 78, 78.5), point(fixture.day(10), 77, 77.5),
            ])
        // The trend at the window's edge still uses the weigh-in before it.
        #expect(Stats.bodyweightTrend(entries, since: fixture.day(3)).first == point(fixture.day(3), 79, 79.5))
        #expect(Stats.bodyweightTrend([]).isEmpty)
    }

    @Test func bodyweightKPIComparesTheTrendAcrossTheWindow() {
        let entries = [(0, 80.0), (3, 79.0), (7, 78.0), (10, 77.0)].map {
            BodyweightEntry(date: fixture.day($0.0), kg: $0.1)
        }

        #expect(Stats.bodyweightKPI(entries) == Stats.BodyweightKPI(currentKg: 77, changeKg: -2.5))
        #expect(Stats.bodyweightKPI(entries, since: fixture.day(3)) == Stats.BodyweightKPI(currentKg: 77, changeKg: -2))
        #expect(
            Stats.bodyweightKPI(entries, since: fixture.day(10)) == Stats.BodyweightKPI(currentKg: 77, changeKg: nil))
        #expect(Stats.bodyweightKPI(entries, since: fixture.day(11)) == nil)
        #expect(Stats.bodyweightKPI([]) == nil)
    }

    // MARK: Conditioning

    func conditioningLog() -> [Workout] {
        [
            fixture.workout(
                day: 0,
                [
                    ("assault-bike-intervals", [fixture.set(seconds: 20, rounds: 8)]),
                    (
                        "acceleration-sprint",
                        [fixture.set(seconds: 4, meters: 20), fixture.set(seconds: 3.5, meters: 20)]
                    ),
                    ("plank", [fixture.set(seconds: 30), fixture.set(seconds: 45)]),
                    ("pull-up", [fixture.set(reps: 8), fixture.set(reps: 6)]),
                    ("push-up", [fixture.set(reps: 20)]),
                    ("back-squat", [fixture.set(kg: 100, reps: 5)]),
                ]),
            fixture.workout(
                day: 7,
                [
                    (
                        "assault-bike-intervals",
                        [fixture.set(seconds: 20, rounds: 8), fixture.set(seconds: 20, rounds: 2)]
                    ),
                    ("acceleration-sprint", [fixture.set(seconds: 3, meters: 20), fixture.set(meters: 20)]),
                    ("plank", [fixture.set(seconds: 60), fixture.set(seconds: 90, completed: false)]),
                    ("pull-up", [fixture.set(reps: 20, warmUp: true), fixture.set(reps: 10)]),
                    ("back-squat", [fixture.set(kg: 100, reps: 5)]),
                ]),
            fixture.workout(day: 14, [("acceleration-sprint", [fixture.set(seconds: 3.5, meters: 20)])]),
            fixture.workout(day: 15, finished: false, [("push-up", [fixture.set(reps: 30)])]),
        ]
    }

    @Test func conditioningPicksTheNumberThatMattersPerSession() {
        let series = Stats.conditioning(conditioningLog())
        let days = [fixture.evening(0), fixture.evening(7), fixture.evening(14)]
        func points(_ values: [Double]) -> [Stats.ConditioningPoint] {
            zip(days, values).map { Stats.ConditioningPoint(date: $0, value: $1) }
        }

        // Most sessions first, then library order. One push-up session isn't a trend.
        #expect(series.map(\.exerciseID) == ["acceleration-sprint", "pull-up", "plank", "assault-bike-intervals"])
        #expect(series.map(\.metric) == [.pace, .reps, .longestTime, .rounds])
        #expect(series.map(\.name) == ["Acceleration sprint", "Pull-up", "Plank", "Air bike intervals"])
        #expect(series[0].points == points([17.5, 15, 17.5]))
        #expect(series[1].points == points([8, 10]))
        #expect(series[2].points == points([45, 60]))
        #expect(series[3].points == points([8, 10]))

        #expect(
            Stats.conditioning(conditioningLog(), limit: 2).map(\.exerciseID) == ["acceleration-sprint", "pull-up"])
        #expect(Stats.conditioning([]).isEmpty)
    }
}
