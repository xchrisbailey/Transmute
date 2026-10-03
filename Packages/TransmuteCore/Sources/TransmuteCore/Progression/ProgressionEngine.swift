import Foundation

/// Decides an exercise's next targets from its logged history (#12). Deterministic and pure: the
/// same plan, history and settings always give the same numbers, and nothing is written back.
/// The AI only explains the result.
///
/// The rules, in the order they're tried:
/// 1. A deload week keeps about 60% of the working sets at about 90% of the load.
/// 2. A held exercise repeats its last targets.
/// 3. Percentages of one-rep max resolve against the best recent estimate.
/// 4. With no history, targets stay as planned and the first working sets set the baseline.
/// 5. Missed targets: once repeats them, twice in a row holds, three times backs off about 10%.
/// 6. Otherwise by tracking. Rep ranges use double progression (top of the range on every set
///    adds load); fixed reps add load when every set is done at or under the target RPE; sets
///    planned by RPE alone move the load by how far the logged RPE was off; reps, time,
///    distance and intervals add a small step of volume or density.
///
/// Warm-ups are never judged. Loads are rounded to what's loadable for the person's kit.
public enum ProgressionEngine {
    /// How many past sessions the estimated one-rep max looks at.
    public static let recentSessions = 3
    /// A deload keeps this share of the working sets…
    public static let deloadVolume = 0.6
    /// …at this share of the load.
    public static let deloadLoad = 0.9
    /// Three misses in a row back off to this share.
    public static let dropFraction = 0.9
    /// Load change per point of RPE between logged and target, as a share of the load.
    public static let loadPerRPE = 0.025
    /// Reps left in reserve when a load comes from the estimated max.
    public static let repsInReserve = 2

    /// The next targets for one exercise.
    /// - Parameters:
    ///   - planned: Today's planned sets, warm-ups included.
    ///   - history: Past sessions of this exercise. Order doesn't matter; skipped sessions are
    ///     ignored.
    ///   - context: The exercise, the phase, the person's kit, units and settings.
    public static func next(
        planned: [SetTarget], history: [ExercisePerformance], context: ProgressionContext
    ) -> ProgressionResult {
        let history = history.filter(\.wasDone).sorted { $0.date > $1.date }
        let run = ProgressionRun(
            planned: planned.sorted { $0.order < $1.order }, history: history, context: context,
            oneRepMax: estimatedOneRepMax(history: history, context: context))
        return run.result()
    }

    /// The best estimated one-rep max from the working sets of the most recent sessions,
    /// falling back to a lift the person entered.
    public static func estimatedOneRepMax(history: [ExercisePerformance], context: ProgressionContext) -> Double? {
        let recent = history.filter(\.wasDone).sorted { $0.date > $1.date }.prefix(recentSessions)
        let estimates = recent.flatMap(\.workingSets).filter(\.isCompleted).compactMap { set -> Double? in
            guard let weight = set.weightKg, let reps = set.reps else { return nil }
            return OneRepMax.estimate(weightKg: weight, reps: reps)
        }
        if let best = estimates.max() { return best }
        return context.knownLifts.first { $0.exerciseID == context.exerciseID }?.estimatedOneRepMaxKg
    }
}

/// One past session's working sets paired with what each was aiming for.
struct Judgement {
    let date: Date
    let pairs: [(set: SetPerformance, target: SetTarget)]
    let tracking: TrackingType

    /// Any working set skipped or short of its target.
    var missed: Bool {
        pairs.contains { !$0.set.isCompleted || Self.isShort($0.set, of: $0.target, tracking: tracking) }
    }

    /// Every working set done at the top of its range, or at its fixed count.
    var toppedOut: Bool {
        pairs.allSatisfy { $0.set.isCompleted && ($0.set.reps ?? 0) >= ($0.target.topReps ?? 0) }
    }

    /// Some set was logged harder than its target RPE.
    var effortHigh: Bool {
        pairs.contains { pair in
            guard let rpe = pair.set.rpe, let target = pair.target.rpe else { return false }
            return rpe > target
        }
    }

    var averageRPE: Double? {
        let values = pairs.filter(\.set.isCompleted).compactMap(\.set.rpe)
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    var targetRPE: Double? {
        pairs.lazy.compactMap(\.target.rpe).first
    }

    /// The rep scheme the session was aiming for, to match it with today's.
    var scheme: RepScheme {
        RepScheme(pairs.first?.target)
    }

    /// The logged load of a working set, by index, repeating the last for extra sets.
    func load(at index: Int) -> Double? {
        guard !pairs.isEmpty else { return nil }
        return pairs[min(index, pairs.count - 1)].set.weightKg
    }

    /// The target of a working set, by index, repeating the last for extra sets.
    func target(at index: Int) -> SetTarget? {
        guard !pairs.isEmpty else { return nil }
        return pairs[min(index, pairs.count - 1)].target
    }

    static func isShort(_ set: SetPerformance, of target: SetTarget, tracking: TrackingType) -> Bool {
        switch tracking {
        case .weightReps, .reps:
            return (set.reps ?? 0) < (target.reps ?? 0)
        case .time:
            return below(set.seconds, target.seconds)
        case .distanceTime:
            if below(set.meters, target.meters) { return true }
            guard target.meters != nil, let goal = target.seconds, let seconds = set.seconds else { return false }
            return seconds > goal
        case .intervals:
            return (set.rounds ?? target.rounds ?? 0) < (target.rounds ?? 0) || below(set.seconds, target.seconds)
        }
    }

    /// Short of a target, when both were given.
    private static func below(_ value: Double?, _ target: Double?) -> Bool {
        guard let value, let target else { return false }
        return value < target
    }
}

/// Reps and range, so a heavy day of fives isn't judged against a light day of tens.
struct RepScheme: Equatable {
    let reps: Int?
    let repsMax: Int?

    init(_ target: SetTarget?) {
        reps = target?.reps
        repsMax = target?.isRange == true ? target?.repsMax : nil
    }
}

/// One call's worth of state, so each rule reads as a short method.
struct ProgressionRun {
    let planned: [SetTarget]
    let history: [ExercisePerformance]
    let context: ProgressionContext
    let oneRepMax: Double?

    /// Today's plan with percentages of max resolved to loads where there's an estimate.
    var resolved: [SetTarget] {
        planned.map { target in
            var target = target
            if let percent = target.percentOneRepMax, let oneRepMax {
                target.loadKg = loadable(percent * oneRepMax)
            }
            return target
        }
    }

    var todaysWorking: [SetTarget] {
        resolved.filter { !$0.isWarmUp }
    }

    var firstWorking: SetTarget? {
        todaysWorking.first
    }

    func result() -> ProgressionResult {
        if context.isDeload { return deload() }
        if context.settings.isHeld(context.exerciseID) { return held() }
        if oneRepMax != nil, firstWorking?.percentOneRepMax != nil { return percentOfMax() }
        guard !history.isEmpty, firstWorking != nil else { return calibrate() }
        switch context.tracking {
        case .weightReps:
            return loadProgression()
        case .reps:
            return repsProgression()
        case .time, .distanceTime, .intervals:
            return volumeProgression()
        }
    }

    // MARK: Judging

    func judge(_ session: ExercisePerformance) -> Judgement {
        let today = todaysWorking
        let pairs = session.workingSets.enumerated().map { index, set in
            let fallback = today.isEmpty ? SetTarget() : today[min(index, today.count - 1)]
            return (set: set, target: set.target ?? fallback)
        }
        return Judgement(date: session.date, pairs: pairs, tracking: context.tracking)
    }

    /// Sessions aiming for today's rep scheme, newest first. Time, distance and intervals
    /// have no scheme, so every session counts.
    var matchingHistory: [Judgement] {
        let judged = history.map(judge)
        guard context.tracking == .weightReps || context.tracking == .reps else { return judged }
        let today = RepScheme(firstWorking)
        return judged.filter { $0.scheme == today }
    }

    /// Misses in a row, counting back from the newest session.
    func consecutiveMisses(_ judged: [Judgement]) -> Int {
        judged.prefix { $0.missed }.count
    }

    // MARK: Building targets

    /// Today's plan with each working set changed, warm-ups left as planned.
    func mapWorking(_ transform: (Int, SetTarget) -> SetTarget) -> [SetTarget] {
        var index = 0
        return resolved.map { target in
            guard !target.isWarmUp else { return target }
            defer { index += 1 }
            return transform(index, target)
        }
    }

    func reason(
        _ kind: ProgressionReason.Kind, from judged: Judgement? = nil, targets: [SetTarget] = [],
        changeKg: Double? = nil, change: Double? = nil
    ) -> ProgressionReason {
        ProgressionReason(
            exerciseID: context.exerciseID, kind: kind, loadKg: targets.first { !$0.isWarmUp }?.loadKg,
            changeKg: changeKg, change: change, sets: judged?.pairs.count, rpe: judged?.averageRPE,
            targetRPE: judged?.targetRPE, sourceDate: judged?.date)
    }

    func calibrate() -> ProgressionResult {
        let targets = resolved
        return ProgressionResult(targets: targets, reason: reason(.calibrate, targets: targets))
    }

    func percentOfMax() -> ProgressionResult {
        let targets = resolved
        var why = reason(.percentOfMax, targets: targets)
        why.fraction = firstWorking?.percentOneRepMax
        why.oneRepMaxKg = oneRepMax
        why.sourceDate = history.first?.date
        return ProgressionResult(targets: targets, reason: why)
    }

    /// The last session's targets again, with its logged loads.
    func repeatLast(_ judged: Judgement) -> [SetTarget] {
        mapWorking { index, today in
            var next = today
            let last = judged.target(at: index)
            next.loadKg = judged.load(at: index) ?? today.loadKg
            if context.tracking != .weightReps {
                next.reps = last?.reps ?? today.reps
                next.repsMax = last?.repsMax ?? today.repsMax
                next.seconds = last?.seconds ?? today.seconds
                next.meters = last?.meters ?? today.meters
                next.rounds = last?.rounds ?? today.rounds
                next.intervalRestSeconds = last?.intervalRestSeconds ?? today.intervalRestSeconds
            }
            return next
        }
    }

    func held() -> ProgressionResult {
        guard let last = matchingHistory.first ?? (history.first.map(judge)), firstWorking != nil else {
            return calibrate()
        }
        let targets = repeatLast(last)
        return ProgressionResult(targets: targets, reason: reason(.held, from: last, targets: targets))
    }

    /// About 60% of the working sets at about 90% of the load, from the last session's load when
    /// there is one. Warm-ups stay; interval rounds shrink the same way.
    func deload() -> ProgressionResult {
        let last = matchingHistory.first
        let base = last.map(repeatLast) ?? resolved
        let working = base.filter { !$0.isWarmUp }
        let keep = max(1, Int((Double(working.count) * ProgressionEngine.deloadVolume).rounded()))
        var kept = 0
        var targets: [SetTarget] = []
        for target in base {
            guard target.isWarmUp || kept < keep else { continue }
            var next = target
            if !target.isWarmUp {
                kept += 1
                next.loadKg = target.loadKg.map { lower($0, by: $0 * (1 - ProgressionEngine.deloadLoad)) }
                next.rounds = target.rounds.map { max(1, Int((Double($0) * ProgressionEngine.deloadVolume).rounded())) }
            }
            next.order = targets.count
            targets.append(next)
        }
        var why = reason(.deload, targets: targets)
        why.sets = keep
        why.fraction = ProgressionEngine.deloadLoad
        why.changeKg = both(working.first?.loadKg, targets.first { !$0.isWarmUp }?.loadKg).map { $1 - $0 }
        return ProgressionResult(targets: targets, reason: why)
    }

    // MARK: Loads

    /// The nearest loadable weight. The one place rounding happens, so an inventory-aware
    /// rounding is a one-line swap.
    func loadable(_ kg: Double) -> Double {
        if let plates = context.plates {
            return LoadableWeight.round(kg, for: context.roundingEquipment, inventory: plates)
        }
        return LoadableWeight.round(kg, for: context.roundingEquipment, system: context.system)
    }

    /// The first loadable weight above `base`, stepping up by `amount` until rounding moves it.
    func raise(_ base: Double, by amount: Double) -> Double {
        let step = max(amount, 0.1)
        for multiple in 1...40 {
            let next = loadable(base + step * Double(multiple))
            if next > base + 0.001 { return next }
        }
        return loadable(base + step)
    }

    /// The first loadable weight below `base`, stepping down by `amount` until rounding moves
    /// it. Stays at the lightest loadable weight.
    func lower(_ base: Double, by amount: Double) -> Double {
        let step = max(amount, 0.1)
        for multiple in 1...40 {
            let next = loadable(max(0, base - step * Double(multiple)))
            if next < base - 0.001 { return next }
        }
        return loadable(base)
    }
}

/// Pairs two optionals, when both are there.
func both<A, B>(_ first: A?, _ second: B?) -> (A, B)? {
    guard let first, let second else { return nil }
    return (first, second)
}
