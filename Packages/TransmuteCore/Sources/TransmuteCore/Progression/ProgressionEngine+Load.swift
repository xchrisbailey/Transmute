import Foundation

// Weight × reps and reps-only work.
extension ProgressionRun {
    var increment: Double {
        context.settings.incrementKg(for: BodyRegion(context.exercise), system: context.system)
    }

    /// Planned by RPE alone: a fixed rep count and a target RPE, with no load or percentage.
    var isRPEBased: Bool {
        guard let today = firstWorking else { return false }
        return today.rpe != nil && today.loadKg == nil && today.percentOneRepMax == nil && !today.isRange
    }

    func loadProgression() -> ProgressionResult {
        let matching = matchingHistory
        guard let last = matching.first else { return fromEstimate() ?? calibrate() }
        guard last.pairs.contains(where: { $0.set.weightKg != nil }) else { return repsProgression() }
        let misses = consecutiveMisses(matching)
        if misses > 0 { return missed(last, misses: misses) }
        guard let today = firstWorking else { return calibrate() }
        if today.isRange {
            return last.toppedOut ? addLoad(last) : sameLoad(.buildReps, last)
        }
        if isRPEBased, let logged = last.averageRPE, let target = last.targetRPE ?? today.rpe {
            return rpeAdjust(last, logged: logged, target: target)
        }
        return last.effortHigh ? sameLoad(.holdEffort, last) : addLoad(last)
    }

    func addLoad(_ last: Judgement) -> ProgressionResult {
        changeLoads(.addLoad, last) { raise($0, by: increment) }
    }

    func sameLoad(_ kind: ProgressionReason.Kind, _ last: Judgement) -> ProgressionResult {
        changeLoads(kind, last) { $0 }
    }

    /// About 2.5% of the load per point of RPE off target, up when it felt easier and down when
    /// it felt harder. Within half a point is on target.
    func rpeAdjust(_ last: Judgement, logged: Double, target: Double) -> ProgressionResult {
        let difference = min(max(target - logged, -4), 4)
        guard abs(difference) >= 0.5 else { return sameLoad(.rpeOnTarget, last) }
        let share = ProgressionEngine.loadPerRPE * abs(difference)
        if difference > 0 {
            return changeLoads(.rpeUp, last) { raise($0, by: $0 * share) }
        }
        return changeLoads(.rpeDown, last) { lower($0, by: $0 * share) }
    }

    /// Today's reps with each working set's last load changed.
    func changeLoads(
        _ kind: ProgressionReason.Kind, _ last: Judgement, _ change: (Double) -> Double
    ) -> ProgressionResult {
        let targets = mapWorking { index, today in
            var next = today
            next.loadKg = (last.load(at: index) ?? today.loadKg).map(change)
            return next
        }
        let before = last.load(at: 0)
        let after = targets.first { !$0.isWarmUp }?.loadKg
        let changeKg = both(before, after).map { $1 - $0 }
        return ProgressionResult(
            targets: targets, reason: reason(kind, from: last, targets: targets, changeKg: changeKg))
    }

    /// History only at another rep scheme: a load from the estimated max that leaves a couple
    /// of reps in reserve at today's rep count.
    func fromEstimate() -> ProgressionResult? {
        guard let oneRepMax, firstWorking?.reps != nil else { return nil }
        let targets = mapWorking { _, today in
            var next = today
            if let reps = today.reps {
                next.loadKg = loadable(oneRepMax / (1 + Double(reps + ProgressionEngine.repsInReserve) / 30))
            }
            return next
        }
        var why = reason(.fromEstimate, targets: targets)
        why.oneRepMaxKg = oneRepMax
        why.sourceDate = history.first?.date
        return ProgressionResult(targets: targets, reason: why)
    }

    /// Once repeats the last targets, twice in a row holds them, three times backs off about 10%.
    func missed(_ last: Judgement, misses: Int) -> ProgressionResult {
        let result: ProgressionResult
        if misses >= 3 {
            result = drop(last)
        } else {
            let targets = repeatLast(last)
            result = ProgressionResult(
                targets: targets, reason: reason(misses == 1 ? .retry : .hold, from: last, targets: targets))
        }
        var why = result.reason
        why.misses = misses
        return ProgressionResult(targets: result.targets, reason: why)
    }

    func drop(_ last: Judgement) -> ProgressionResult {
        let fraction = ProgressionEngine.dropFraction
        var result: ProgressionResult
        if context.tracking == .weightReps, last.load(at: 0) != nil {
            result = changeLoads(.drop, last) { lower($0, by: $0 * (1 - fraction)) }
        } else {
            let targets = repeatLast(last).map { target in
                target.isWarmUp ? target : lessVolume(target, fraction: fraction)
            }
            let change = volumeChange(from: last.target(at: 0), to: targets.first { !$0.isWarmUp })
            result = ProgressionResult(
                targets: targets, reason: reason(.drop, from: last, targets: targets, change: change))
        }
        result.reason.fraction = fraction
        return result
    }

    /// Reps-only work, or weight × reps logged without a weight: more reps once every set hits
    /// the top of its range or its fixed count. A range moves up as a whole.
    func repsProgression() -> ProgressionResult {
        let matching = matchingHistory
        guard let last = matching.first else { return calibrate() }
        let misses = consecutiveMisses(matching)
        if misses > 0 { return missed(last, misses: misses) }
        guard last.toppedOut else {
            let targets = repeatLast(last)
            return ProgressionResult(targets: targets, reason: reason(.buildReps, from: last, targets: targets))
        }
        let targets = mapWorking { index, today in
            var next = today
            let previous = last.target(at: index)
            next.loadKg = last.load(at: index) ?? today.loadKg
            next.reps = higher((previous?.reps).map { $0 + 1 }, today.reps)
            next.repsMax = higher((previous?.repsMax).map { $0 + 1 }, today.repsMax)
            return next
        }
        return ProgressionResult(targets: targets, reason: reason(.addReps, from: last, targets: targets, change: 1))
    }
}

/// The larger of two optionals, or whichever is there.
func higher<T: Comparable>(_ first: T?, _ second: T?) -> T? {
    guard let first else { return second }
    guard let second else { return first }
    return max(first, second)
}

/// The smaller of two optionals, or whichever is there.
func lowerOf<T: Comparable>(_ first: T?, _ second: T?) -> T? {
    guard let first else { return second }
    guard let second else { return first }
    return min(first, second)
}
