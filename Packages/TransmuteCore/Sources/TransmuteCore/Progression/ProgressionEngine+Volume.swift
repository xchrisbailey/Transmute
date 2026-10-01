import Foundation

// Time, distance and intervals: small steps of volume or density, never below today's plan.
extension ProgressionRun {
    /// Interval work adds rounds up to this many, then shortens the rest.
    static let maxRounds = 10
    /// Interval rest never goes below this.
    static let minIntervalRest = 10.0

    /// Speed, power and mobility work is about quality, so its volume stays put.
    var isQualityWork: Bool {
        guard let category = context.exercise?.category else { return false }
        return [.speedAgility, .power, .mobility].contains(category)
    }

    func volumeProgression() -> ProgressionResult {
        let judged = matchingHistory
        guard let last = judged.first else { return calibrate() }
        let misses = consecutiveMisses(judged)
        if misses > 0 { return missed(last, misses: misses) }
        if isQualityWork {
            let targets = resolved
            return ProgressionResult(targets: targets, reason: reason(.steady, from: last, targets: targets))
        }
        let kind = volumeKind(last.target(at: 0))
        let targets = mapWorking { index, today in
            last.target(at: index).map { more(kind, from: $0, today: today) } ?? today
        }
        let change = volumeChange(from: last.target(at: 0), to: targets.first { !$0.isWarmUp })
        return ProgressionResult(targets: targets, reason: reason(kind, from: last, targets: targets, change: change))
    }

    /// Which step comes next: further or faster for distance; for intervals, rounds first,
    /// then shorter rest, then longer work.
    func volumeKind(_ last: SetTarget?) -> ProgressionReason.Kind {
        switch context.tracking {
        case .distanceTime:
            return last?.meters != nil && last?.seconds != nil ? .faster : .addDistance
        case .intervals:
            if (last?.rounds ?? 0) < Self.maxRounds { return .addRound }
            return (last?.intervalRestSeconds ?? 0) > Self.minIntervalRest ? .shorterRest : .addTime
        default:
            return .addTime
        }
    }

    /// One step on from the last target, or today's plan when that already asks for more.
    func more(_ kind: ProgressionReason.Kind, from last: SetTarget, today: SetTarget) -> SetTarget {
        var next = today
        next.seconds = last.seconds ?? today.seconds
        next.meters = last.meters ?? today.meters
        next.rounds = last.rounds ?? today.rounds
        next.intervalRestSeconds = last.intervalRestSeconds ?? today.intervalRestSeconds
        switch kind {
        case .addDistance:
            next.meters = higher(next.meters.map { $0 + Self.metersStep($0) }, today.meters)
        case .faster:
            next.seconds = lowerOf(next.seconds.map { $0 - Self.fasterStep($0) }, today.seconds)
        case .addRound:
            next.rounds = higher(next.rounds.map { $0 + 1 }, today.rounds)
        case .shorterRest:
            next.intervalRestSeconds = next.intervalRestSeconds.map { max(Self.minIntervalRest, $0 - 5) }
        default:
            next.seconds = higher(next.seconds.map { $0 + Self.secondsStep($0) }, today.seconds)
        }
        return next
    }

    /// About 10% less: shorter, nearer, one round fewer, or slower for a timed distance.
    func lessVolume(_ target: SetTarget, fraction: Double) -> SetTarget {
        var next = target
        switch context.tracking {
        case .intervals:
            next.rounds = target.rounds.map { max(1, $0 - 1) }
        case .distanceTime where target.meters != nil && target.seconds != nil:
            next.seconds = target.seconds.map { ($0 / fraction).rounded() }
        case .reps, .weightReps:
            next.reps = target.reps.map { max(1, Int((Double($0) * fraction).rounded(.down))) }
            next.repsMax = target.repsMax.map { max(1, Int((Double($0) * fraction).rounded(.down))) }
        default:
            next.seconds = target.seconds.map { max(5, ($0 * fraction).rounded()) }
            next.meters = target.meters.map { max(10, ($0 * fraction / 10).rounded() * 10) }
        }
        return next
    }

    /// The signed change in the quantity that moved: rounds, rest, metres, seconds or reps.
    func volumeChange(from last: SetTarget?, to next: SetTarget?) -> Double? {
        guard let last, let next else { return nil }
        let pairs: [(Double?, Double?)] = [
            (last.rounds.map(Double.init), next.rounds.map(Double.init)),
            (last.intervalRestSeconds, next.intervalRestSeconds),
            (last.meters, next.meters),
            (last.seconds, next.seconds),
            (last.reps.map(Double.init), next.reps.map(Double.init)),
        ]
        for case let (before?, after?) in pairs where before != after {
            return after - before
        }
        return nil
    }

    /// 5 seconds, or about 10% of longer efforts, in whole 5 seconds.
    static func secondsStep(_ seconds: Double) -> Double {
        max(5, (seconds * 0.1 / 5).rounded() * 5)
    }

    /// About 5%, in whole 10 metres, at least 10.
    static func metersStep(_ meters: Double) -> Double {
        max(10, (meters * 0.05 / 10).rounded() * 10)
    }

    /// About 2% faster, at least a second.
    static func fasterStep(_ seconds: Double) -> Double {
        max(1, (seconds * 0.02).rounded())
    }
}
