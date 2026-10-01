import Foundation
import Testing

@testable import TransmuteCore

/// Builders shared by the progression tests.
enum Lift {
    static let today = Date(timeIntervalSince1970: 1_790_553_600)  // Monday 2026-09-28, UTC.

    static func daysAgo(_ days: Int) -> Date {
        today.addingTimeInterval(Double(-days) * 86_400)
    }

    static func pounds(_ lb: Double) -> Double {
        lb / Units.poundsPerKilogram
    }

    static func context(
        _ id: String, deload: Bool = false, system: UnitSystem = .metric,
        equipment: Set<Equipment> = [.barbell, .rack, .bench, .dumbbell],
        settings: ProgressionSettings = ProgressionSettings(), knownLifts: [KnownLift] = []
    ) -> ProgressionContext {
        ProgressionContext(
            exerciseID: id, exercise: ExerciseLibrary.bundled.exercise(id: id), isDeload: deload,
            equipment: equipment, system: system, settings: settings, knownLifts: knownLifts)
    }

    /// `count` working sets with the same target.
    static func plan(_ count: Int, _ target: SetTarget, warmUp: SetTarget? = nil) -> [SetTarget] {
        let warmUps = warmUp.map { [$0] } ?? []
        return (warmUps + Array(repeating: target, count: count)).enumerated().map { index, target in
            var target = target
            target.order = index
            return target
        }
    }

    /// One past session of identical sets.
    static func session(
        _ daysAgo: Int, _ count: Int, kg: Double? = nil, reps: Int? = nil, rpe: Double? = nil,
        seconds: Double? = nil, meters: Double? = nil, rounds: Int? = nil, target: SetTarget? = nil,
        completed: Bool = true
    ) -> ExercisePerformance {
        ExercisePerformance(
            date: Lift.daysAgo(daysAgo),
            sets: (0..<count).map {
                SetPerformance(
                    order: $0, weightKg: kg, reps: reps, seconds: seconds, meters: meters, rpe: rpe, rounds: rounds,
                    isCompleted: completed, target: target)
            })
    }

    static func display(_ kg: Double?, _ system: UnitSystem) -> Double {
        let value = Units(system: system).displayWeight(kg: kg ?? 0)
        return (value * 100).rounded() / 100
    }

    static func working(_ result: ProgressionResult) -> [SetTarget] {
        result.targets.filter { !$0.isWarmUp }
    }
}

struct ProgressionEngineTests {
    let range = SetTarget(reps: 6, repsMax: 8, loadKg: 100, restSeconds: 150)
    let fives = SetTarget(reps: 5, loadKg: 100, rpe: 8)

    // MARK: Calibration and the estimate

    @Test func oneRepMaxUsesEpleyUpToTenReps() {
        #expect(OneRepMax.estimate(weightKg: 100, reps: 1) == 100)
        #expect(abs((OneRepMax.estimate(weightKg: 100, reps: 5) ?? 0) - 116.667) < 0.001)
        #expect(OneRepMax.estimate(weightKg: 100, reps: 11) == nil)
        #expect(OneRepMax.estimate(weightKg: 0, reps: 5) == nil)
    }

    @Test func noHistoryCalibratesWithThePlanUnchanged() {
        let plan = Lift.plan(3, range)
        let result = ProgressionEngine.next(planned: plan, history: [], context: Lift.context("back-squat"))
        #expect(result.targets == plan)
        #expect(result.reason.kind == .calibrate)
        #expect(result.reason.loadKg == 100)
        #expect(result.reason.sourceDate == nil)
    }

    @Test func skippedSessionsDontCount() {
        let skipped = Lift.session(3, 3, kg: 100, reps: 8, completed: false)
        let result = ProgressionEngine.next(
            planned: Lift.plan(3, range), history: [skipped], context: Lift.context("back-squat"))
        #expect(result.reason.kind == .calibrate)
    }

    @Test func bestRecentSetGivesTheEstimate() {
        let history = [
            Lift.session(2, 3, kg: 100, reps: 5),
            Lift.session(5, 1, kg: 110, reps: 3),
            Lift.session(30, 1, kg: 140, reps: 1),
            Lift.session(40, 1, kg: 150, reps: 1),
        ]
        let estimate = ProgressionEngine.estimatedOneRepMax(history: history, context: Lift.context("back-squat"))
        #expect(estimate == 140)
        let known = Lift.context(
            "back-squat", knownLifts: [KnownLift(exerciseID: "back-squat", weightKg: 100, reps: 5)])
        #expect(abs((ProgressionEngine.estimatedOneRepMax(history: [], context: known) ?? 0) - 116.667) < 0.001)
    }

    // MARK: Double progression

    @Test func topOfTheRangeOnEverySetAddsLowerBodyLoad() {
        let history = [Lift.session(4, 3, kg: 100, reps: 8)]
        let result = ProgressionEngine.next(
            planned: Lift.plan(3, range), history: history, context: Lift.context("back-squat"))
        #expect(Lift.working(result).map(\.loadKg) == [102.5, 102.5, 102.5])
        #expect(Lift.working(result).allSatisfy { $0.reps == 6 && $0.repsMax == 8 && $0.restSeconds == 150 })
        #expect(result.reason.kind == .addLoad)
        #expect(result.reason.changeKg == 2.5)
        #expect(result.reason.loadKg == 102.5)
        #expect(result.reason.sets == 3)
        #expect(result.reason.sourceDate == Lift.daysAgo(4))
    }

    @Test func insideTheRangeKeepsTheLoad() {
        let history = [
            ExercisePerformance(
                date: Lift.daysAgo(3),
                sets: [
                    SetPerformance(order: 0, weightKg: 100, reps: 8),
                    SetPerformance(order: 1, weightKg: 100, reps: 7),
                    SetPerformance(order: 2, weightKg: 100, reps: 6),
                ])
        ]
        let result = ProgressionEngine.next(
            planned: Lift.plan(3, range), history: history, context: Lift.context("back-squat"))
        #expect(Lift.working(result).map(\.loadKg) == [100, 100, 100])
        #expect(result.reason.kind == .buildReps)
        #expect(result.reason.changeKg == 0)
    }

    @Test func imperialLowerBodyAddsFivePounds() {
        let history = [Lift.session(2, 3, kg: Lift.pounds(225), reps: 8)]
        let result = ProgressionEngine.next(
            planned: Lift.plan(3, range), history: history, context: Lift.context("back-squat", system: .imperial))
        #expect(Lift.working(result).map { Lift.display($0.loadKg, .imperial) } == [230, 230, 230])
        #expect(Lift.display(result.reason.changeKg, .imperial) == 5)
    }

    @Test(arguments: [
        ("bench-press", UnitSystem.metric, 60.0, 62.5),
        ("dumbbell-bench-press", .metric, 20, 22),
        ("bench-press", .imperial, 135, 140),
        ("dumbbell-curl", .imperial, 25, 30),
        ("romanian-deadlift", .metric, 80, 82.5),
    ])
    func upperBodyStepsRoundToWhatsLoadable(id: String, system: UnitSystem, before: Double, after: Double) {
        let start = system == .metric ? before : Lift.pounds(before)
        let history = [Lift.session(2, 3, kg: start, reps: 8)]
        let result = ProgressionEngine.next(
            planned: Lift.plan(3, range), history: history, context: Lift.context(id, system: system))
        #expect(Lift.display(Lift.working(result).first?.loadKg, system) == after)
    }

    @Test func customIncrementsApply() {
        var settings = ProgressionSettings()
        settings.setIncrement(5, for: .lower, system: .metric)
        let history = [Lift.session(2, 3, kg: 100, reps: 8)]
        let result = ProgressionEngine.next(
            planned: Lift.plan(3, range), history: history, context: Lift.context("back-squat", settings: settings))
        #expect(result.reason.changeKg == 5)
    }

    @Test func aStepTooSmallToLoadStillMovesUpOnePlate() {
        var settings = ProgressionSettings()
        settings.setIncrement(0.5, for: .lower, system: .metric)
        let history = [Lift.session(2, 3, kg: 100, reps: 8)]
        let result = ProgressionEngine.next(
            planned: Lift.plan(3, range), history: history, context: Lift.context("back-squat", settings: settings))
        #expect(result.reason.loadKg == 102.5)
    }

    // MARK: Linear

    @Test func fixedRepsAtOrUnderTargetRPEAddLoad() {
        let history = [Lift.session(2, 5, kg: 100, reps: 5, rpe: 8)]
        let result = ProgressionEngine.next(
            planned: Lift.plan(5, fives), history: history, context: Lift.context("back-squat"))
        #expect(result.reason.kind == .addLoad)
        #expect(result.reason.loadKg == 102.5)
        #expect(result.reason.sets == 5)
        #expect(result.reason.rpe == 8)
        #expect(result.reason.targetRPE == 8)
    }

    @Test func fixedRepsHarderThanTargetHold() {
        let history = [Lift.session(2, 3, kg: 100, reps: 5, rpe: 9)]
        let result = ProgressionEngine.next(
            planned: Lift.plan(3, fives), history: history, context: Lift.context("back-squat"))
        #expect(result.reason.kind == .holdEffort)
        #expect(result.reason.loadKg == 100)
    }

    @Test func missesRetryThenHoldThenDrop() {
        let miss = { (days: Int) in Lift.session(days, 3, kg: 100, reps: 4) }
        let context = Lift.context("back-squat")
        let once = ProgressionEngine.next(planned: Lift.plan(3, fives), history: [miss(2)], context: context)
        #expect(once.reason.kind == .retry)
        #expect(once.reason.misses == 1)
        #expect(once.reason.loadKg == 100)

        let twice = ProgressionEngine.next(planned: Lift.plan(3, fives), history: [miss(2), miss(5)], context: context)
        #expect(twice.reason.kind == .hold)
        #expect(twice.reason.misses == 2)
        #expect(twice.reason.loadKg == 100)

        let thrice = ProgressionEngine.next(
            planned: Lift.plan(3, fives), history: [miss(2), miss(5), miss(9)], context: context)
        #expect(thrice.reason.kind == .drop)
        #expect(thrice.reason.misses == 3)
        #expect(Lift.working(thrice).map(\.loadKg) == [90, 90, 90])
        #expect(thrice.reason.changeKg == -10)
        #expect(thrice.reason.fraction == 0.9)
    }

    @Test func imperialDropRoundsToFivePounds() {
        let history = (0..<3).map { Lift.session(2 + $0 * 3, 3, kg: Lift.pounds(225), reps: 3) }
        let result = ProgressionEngine.next(
            planned: Lift.plan(3, fives), history: history, context: Lift.context("back-squat", system: .imperial))
        #expect(Lift.display(result.reason.loadKg, .imperial) == 205)
    }

    @Test func aHitBreaksTheRunOfMisses() {
        let history = [
            Lift.session(2, 3, kg: 100, reps: 5),
            Lift.session(5, 3, kg: 100, reps: 4),
            Lift.session(9, 3, kg: 100, reps: 4),
        ]
        let result = ProgressionEngine.next(
            planned: Lift.plan(3, fives), history: history, context: Lift.context("back-squat"))
        #expect(result.reason.kind == .addLoad)
    }

    @Test func aSkippedSetIsAMiss() {
        var session = Lift.session(2, 3, kg: 100, reps: 5)
        session.sets[2].isCompleted = false
        let result = ProgressionEngine.next(
            planned: Lift.plan(3, fives), history: [session], context: Lift.context("back-squat"))
        #expect(result.reason.kind == .retry)
    }

    @Test func warmUpsAreIgnoredAndKept() {
        let warmUp = SetTarget(reps: 5, loadKg: 60, isWarmUp: true)
        var session = Lift.session(2, 3, kg: 100, reps: 5)
        session.sets.insert(SetPerformance(order: -1, weightKg: 60, reps: 2, isWarmUp: true), at: 0)
        let result = ProgressionEngine.next(
            planned: Lift.plan(3, fives, warmUp: warmUp), history: [session], context: Lift.context("back-squat"))
        #expect(result.reason.kind == .addLoad)
        #expect(result.reason.sets == 3)
        #expect(result.targets.first == Lift.plan(3, fives, warmUp: warmUp).first)
        #expect(Lift.working(result).map(\.loadKg) == [102.5, 102.5, 102.5])
    }

    @Test func recordedTargetsWinOverTodaysPlan() {
        // Logged against 3 × 3, so five reps topped it out even though today asks for five.
        let target = SetTarget(reps: 5, repsMax: 5, loadKg: 100)
        let history = [Lift.session(2, 3, kg: 100, reps: 4, target: SetTarget(reps: 3, loadKg: 100))]
        let result = ProgressionEngine.next(
            planned: Lift.plan(3, target), history: history, context: Lift.context("back-squat"))
        #expect(result.reason.kind == .fromEstimate)
        let judged = ProgressionEngine.next(
            planned: Lift.plan(3, SetTarget(reps: 3, loadKg: 100)), history: history,
            context: Lift.context("back-squat"))
        #expect(judged.reason.kind == .addLoad)
    }

    @Test func anotherRepSchemeLoadsFromTheEstimate() {
        let history = [Lift.session(2, 3, kg: 60, reps: 10, target: SetTarget(reps: 10, loadKg: 60))]
        let result = ProgressionEngine.next(
            planned: Lift.plan(3, fives), history: history, context: Lift.context("back-squat"))
        #expect(result.reason.kind == .fromEstimate)
        #expect(abs((result.reason.oneRepMaxKg ?? 0) - 80) < 0.001)
        // 80 / (1 + 7/30) ≈ 64.9, rounded to 65.
        #expect(Lift.working(result).map(\.loadKg) == [65, 65, 65])
    }
}

// RPE, percentages, deloads and holds.
extension ProgressionEngineTests {
    // MARK: RPE

    @Test(arguments: [
        (6.0, ProgressionReason.Kind.rpeUp, 105.0),
        (9.5, .rpeDown, 97.5),
        (8.25, .rpeOnTarget, 100),
    ])
    func rpeTargetsMoveTheLoadByHowFarOffItWas(logged: Double, kind: ProgressionReason.Kind, load: Double) {
        let byFeel = SetTarget(reps: 5, rpe: 8)
        let history = [Lift.session(2, 3, kg: 100, reps: 5, rpe: logged)]
        let result = ProgressionEngine.next(
            planned: Lift.plan(3, byFeel), history: history, context: Lift.context("back-squat"))
        #expect(result.reason.kind == kind)
        #expect(result.reason.loadKg == load)
        #expect(result.reason.rpe == logged)
        #expect(result.reason.targetRPE == 8)
    }

    @Test func rpeTargetsWithoutLoggedRPEFallBackToLinear() {
        let history = [Lift.session(2, 3, kg: 100, reps: 5)]
        let result = ProgressionEngine.next(
            planned: Lift.plan(3, SetTarget(reps: 5, rpe: 8)), history: history, context: Lift.context("back-squat"))
        #expect(result.reason.kind == .addLoad)
    }

    // MARK: Percentages

    @Test func percentagesResolveFromTheEstimate() {
        let percent = SetTarget(reps: 5, percentOneRepMax: 0.75)
        let history = [Lift.session(2, 3, kg: 100, reps: 5)]
        let result = ProgressionEngine.next(
            planned: Lift.plan(3, percent), history: history, context: Lift.context("back-squat"))
        #expect(result.reason.kind == .percentOfMax)
        #expect(result.reason.fraction == 0.75)
        // 0.75 × 116.7 = 87.5.
        #expect(Lift.working(result).map(\.loadKg) == [87.5, 87.5, 87.5])

        let known = Lift.context(
            "back-squat", knownLifts: [KnownLift(exerciseID: "back-squat", weightKg: 100, reps: 5)])
        let first = ProgressionEngine.next(planned: Lift.plan(3, percent), history: [], context: known)
        #expect(first.reason.kind == .percentOfMax)
        #expect(first.reason.loadKg == 87.5)
    }

    @Test func percentagesWithoutAnEstimateCalibrate() {
        let result = ProgressionEngine.next(
            planned: Lift.plan(3, SetTarget(reps: 5, percentOneRepMax: 0.75)), history: [],
            context: Lift.context("back-squat"))
        #expect(result.reason.kind == .calibrate)
        #expect(result.reason.loadKg == nil)
    }

    // MARK: Deload and holds

    @Test func deloadKeepsSixtyPercentOfSetsAtNinetyPercentLoad() {
        let warmUp = SetTarget(reps: 5, loadKg: 60, isWarmUp: true)
        let history = [Lift.session(2, 5, kg: 100, reps: 4), Lift.session(5, 5, kg: 100, reps: 4)]
        let result = ProgressionEngine.next(
            planned: Lift.plan(5, fives, warmUp: warmUp), history: history,
            context: Lift.context(
                "back-squat", deload: true, settings: ProgressionSettings(heldExerciseIDs: ["back-squat"])))
        #expect(result.reason.kind == .deload)
        #expect(result.reason.sets == 3)
        #expect(result.reason.fraction == 0.9)
        #expect(result.targets.map(\.order) == [0, 1, 2, 3])
        #expect(result.targets.first?.isWarmUp == true)
        #expect(Lift.working(result).map(\.loadKg) == [90, 90, 90])
        #expect(result.reason.changeKg == -10)
    }

    @Test func deloadWithoutHistoryLightensThePlan() {
        let result = ProgressionEngine.next(
            planned: Lift.plan(3, fives), history: [], context: Lift.context("back-squat", deload: true))
        #expect(Lift.working(result).map(\.loadKg) == [90, 90])
    }

    @Test func deloadTrimsIntervalRounds() {
        let intervals = SetTarget(seconds: 30, rounds: 8, intervalRestSeconds: 30)
        let result = ProgressionEngine.next(
            planned: Lift.plan(1, intervals), history: [], context: Lift.context("rower-intervals", deload: true))
        #expect(result.targets.map(\.rounds) == [5])
    }

    @Test func heldExercisesRepeatTheirLastLoad() {
        var settings = ProgressionSettings()
        settings.toggleHold("back-squat")
        #expect(settings.isHeld("back-squat"))
        let history = [Lift.session(2, 3, kg: 100, reps: 8)]
        let result = ProgressionEngine.next(
            planned: Lift.plan(3, range), history: history, context: Lift.context("back-squat", settings: settings))
        #expect(result.reason.kind == .held)
        #expect(Lift.working(result).map(\.loadKg) == [100, 100, 100])
        settings.toggleHold("back-squat")
        #expect(!settings.isHeld("back-squat"))
    }

    @Test func heldWithoutHistoryCalibrates() {
        let result = ProgressionEngine.next(
            planned: Lift.plan(3, range), history: [],
            context: Lift.context("back-squat", settings: ProgressionSettings(heldExerciseIDs: ["back-squat"])))
        #expect(result.reason.kind == .calibrate)
    }
}
