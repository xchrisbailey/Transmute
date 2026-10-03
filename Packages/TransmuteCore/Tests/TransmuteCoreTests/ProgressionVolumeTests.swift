import Foundation
import Testing

@testable import TransmuteCore

/// Reps, time, distance and intervals.
struct ProgressionVolumeTests {
    @Test func repsOnlyAddsARepOnceEverySetHits() {
        let history = [Lift.session(2, 3, reps: 10)]
        let result = ProgressionEngine.next(
            planned: Lift.plan(3, SetTarget(reps: 10)), history: history, context: Lift.context("push-up"))
        #expect(result.reason.kind == .addReps)
        #expect(result.reason.change == 1)
        #expect(Lift.working(result).map(\.reps) == [11, 11, 11])
    }

    @Test func aRepRangeMovesUpAsAWhole() {
        let range = SetTarget(reps: 8, repsMax: 12)
        let topped = ProgressionEngine.next(
            planned: Lift.plan(3, range), history: [Lift.session(2, 3, reps: 12)], context: Lift.context("push-up"))
        #expect(Lift.working(topped).map(\.reps) == [9, 9, 9])
        #expect(Lift.working(topped).map(\.repsMax) == [13, 13, 13])
        let building = ProgressionEngine.next(
            planned: Lift.plan(3, range), history: [Lift.session(2, 3, reps: 10)], context: Lift.context("push-up"))
        #expect(building.reason.kind == .buildReps)
        #expect(Lift.working(building).map(\.reps) == [8, 8, 8])
    }

    @Test func repsOnlyDropsAfterThreeMisses() {
        let history = (0..<3).map { Lift.session(2 + $0 * 2, 3, reps: 7) }
        let result = ProgressionEngine.next(
            planned: Lift.plan(3, SetTarget(reps: 10)), history: history, context: Lift.context("push-up"))
        #expect(result.reason.kind == .drop)
        #expect(Lift.working(result).map(\.reps) == [9, 9, 9])
        #expect(result.reason.change == -1)
    }

    @Test func weightRepsLoggedWithoutWeightProgressesReps() {
        let history = [Lift.session(2, 3, reps: 5)]
        let result = ProgressionEngine.next(
            planned: Lift.plan(3, SetTarget(reps: 5)), history: history, context: Lift.context("back-squat"))
        #expect(result.reason.kind == .addReps)
    }

    @Test func holdsGetLonger() {
        let plank = SetTarget(seconds: 30)
        let result = ProgressionEngine.next(
            planned: Lift.plan(3, plank), history: [Lift.session(2, 3, seconds: 30)], context: Lift.context("plank"))
        #expect(result.reason.kind == .addTime)
        #expect(result.reason.change == 5)
        #expect(Lift.working(result).map(\.seconds) == [35, 35, 35])

        let long = SetTarget(seconds: 120)
        let longer = ProgressionEngine.next(
            planned: Lift.plan(2, long), history: [Lift.session(2, 2, seconds: 120)], context: Lift.context("plank"))
        #expect(Lift.working(longer).map(\.seconds) == [130, 130])
    }

    @Test func aPlanAlreadyAskingForMoreWins() {
        let history = [Lift.session(2, 3, seconds: 30, target: SetTarget(seconds: 30))]
        let result = ProgressionEngine.next(
            planned: Lift.plan(3, SetTarget(seconds: 45)), history: history, context: Lift.context("plank"))
        #expect(Lift.working(result).map(\.seconds) == [45, 45, 45])
    }

    @Test func shortHoldsAreMisses() {
        let history = [Lift.session(2, 3, seconds: 25)]
        let result = ProgressionEngine.next(
            planned: Lift.plan(3, SetTarget(seconds: 30)), history: history, context: Lift.context("plank"))
        #expect(result.reason.kind == .retry)
        #expect(Lift.working(result).map(\.seconds) == [30, 30, 30])
        let thrice = ProgressionEngine.next(
            planned: Lift.plan(3, SetTarget(seconds: 30)),
            history: (0..<3).map { Lift.session(2 + $0, 3, seconds: 25) },
            context: Lift.context("plank"))
        #expect(Lift.working(thrice).map(\.seconds) == [27, 27, 27])
    }

    @Test func distanceGoesFurtherInSmallSteps() {
        let short = ProgressionEngine.next(
            planned: Lift.plan(3, SetTarget(meters: 20)), history: [Lift.session(2, 3, meters: 20)],
            context: Lift.context("sled-push"))
        #expect(short.reason.kind == .addDistance)
        #expect(Lift.working(short).map(\.meters) == [30, 30, 30])
        let long = ProgressionEngine.next(
            planned: Lift.plan(1, SetTarget(meters: 400)), history: [Lift.session(2, 1, meters: 400)],
            context: Lift.context("sled-push"))
        #expect(long.reason.change == 20)
    }

    @Test func timedDistanceGetsFaster() {
        let trial = SetTarget(seconds: 100, meters: 400)
        let result = ProgressionEngine.next(
            planned: Lift.plan(1, trial), history: [Lift.session(2, 1, seconds: 99, meters: 400)],
            context: Lift.context("sled-push"))
        #expect(result.reason.kind == .faster)
        #expect(result.targets.map(\.seconds) == [98])
        #expect(result.reason.change == -2)
        let slow = ProgressionEngine.next(
            planned: Lift.plan(1, trial), history: [Lift.session(2, 1, seconds: 104, meters: 400)],
            context: Lift.context("sled-push"))
        #expect(slow.reason.kind == .retry)
    }

    @Test func intervalsAddRoundsThenShortenRestThenLengthenWork() {
        func next(_ target: SetTarget) -> ProgressionResult {
            ProgressionEngine.next(
                planned: Lift.plan(1, target),
                history: [Lift.session(2, 1, seconds: target.seconds, rounds: target.rounds, target: target)],
                context: Lift.context("rower-intervals"))
        }
        let rounds = next(SetTarget(seconds: 30, rounds: 8, intervalRestSeconds: 30))
        #expect(rounds.reason.kind == .addRound)
        #expect(rounds.targets.map(\.rounds) == [9])
        let rest = next(SetTarget(seconds: 30, rounds: 10, intervalRestSeconds: 30))
        #expect(rest.reason.kind == .shorterRest)
        #expect(rest.targets.map(\.intervalRestSeconds) == [25])
        #expect(rest.reason.change == -5)
        let work = next(SetTarget(seconds: 30, rounds: 10, intervalRestSeconds: 10))
        #expect(work.reason.kind == .addTime)
        #expect(work.targets.map(\.seconds) == [35])
    }

    @Test func missedRoundsRetryThenDropARound() {
        let target = SetTarget(seconds: 30, rounds: 8, intervalRestSeconds: 30)
        let once = ProgressionEngine.next(
            planned: Lift.plan(1, target), history: [Lift.session(2, 1, seconds: 30, rounds: 6)],
            context: Lift.context("rower-intervals"))
        #expect(once.reason.kind == .retry)
        let thrice = ProgressionEngine.next(
            planned: Lift.plan(1, target), history: (0..<3).map { Lift.session(2 + $0, 1, seconds: 30, rounds: 6) },
            context: Lift.context("rower-intervals"))
        #expect(thrice.reason.kind == .drop)
        #expect(thrice.targets.map(\.rounds) == [7])
    }

    @Test func speedWorkStaysSteady() {
        let sprint = SetTarget(meters: 20)
        let result = ProgressionEngine.next(
            planned: Lift.plan(4, sprint), history: [Lift.session(2, 4, seconds: 3.1, meters: 20)],
            context: Lift.context("acceleration-sprint"))
        #expect(result.reason.kind == .steady)
        #expect(Lift.working(result).map(\.meters) == [20, 20, 20, 20])
    }
}

struct ProgressionSettingsTests {
    @Test(arguments: [
        ("back-squat", BodyRegion.lower), ("romanian-deadlift", .lower), ("farmers-carry", .lower),
        ("bench-press", .upper), ("pull-up", .upper), ("dumbbell-curl", .upper), ("cable-crunch", .upper),
        ("burpee", .lower),
    ])
    func bodyRegionComesFromPatternThenMuscles(id: String, region: BodyRegion) {
        #expect(BodyRegion(ExerciseLibrary.bundled.exercise(id: id)) == region)
    }

    @Test func unknownExercisesGetTheSmallerStep() {
        #expect(BodyRegion(nil) == .upper)
    }

    @Test func defaultsMatchTheIssue() {
        let settings = ProgressionSettings()
        #expect(settings.incrementKg(for: .lower, system: .metric) == 2.5)
        #expect(settings.incrementKg(for: .upper, system: .metric) == 1.25)
        #expect(abs(settings.incrementKg(for: .lower, system: .imperial) * Units.poundsPerKilogram - 5) < 0.0001)
        #expect(settings.increment(for: .upper, system: .imperial) == 2.5)
    }

    @Test func settingsAndReasonsRoundTrip() throws {
        var settings = ProgressionSettings()
        settings.setHeld(true, "back-squat")
        settings.setHeld(true, "back-squat")
        #expect(settings.heldExerciseIDs == ["back-squat"])
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(ProgressionSettings.self, from: data) == settings)

        let reason = ProgressionReason(exerciseID: "back-squat", kind: .addLoad, loadKg: 102.5, changeKg: 2.5)
        let decoded = try JSONDecoder().decode(ProgressionReason.self, from: JSONEncoder().encode(reason))
        #expect(decoded == reason)
    }
}
