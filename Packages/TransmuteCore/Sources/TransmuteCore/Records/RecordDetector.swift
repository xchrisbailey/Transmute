import Foundation

/// Finds the personal records a set sets (#13). Gold is only spent on records, so the rules
/// lean towards missing a doubtful record rather than gilding a non-record.
///
/// - **Which sets count**: completed working sets. Warm-ups and unfinished sets never do.
/// - **What each tracking type records**:
///   - weight × reps: estimated 1RM (Epley, 1–10 reps), rep maxes, and session volume. A set
///     with no load was done at bodyweight and counts for max reps instead.
///   - reps: max reps.
///   - time: longest time.
///   - distance and time: best time for that distance, and longest distance. Distance alone
///     counts for longest distance, time alone for longest time.
///   - intervals: nothing. Rounds and work-to-rest vary with the prescription, so there's no
///     fair like-for-like comparison.
/// - **Rep maxes** are kept at 1, 3, 5, 8 and 10 reps, and an N-rep max is the heaviest load
///   lifted for *at least* N reps. Six reps at 100 kg also proves a 5RM, 3RM and 1RM of at least
///   100 kg, so the set counts in each slot it beats. This keeps the table consistent (a 3RM is
///   never lighter than a 5RM) and stops a lighter triple turning gold after a heavier set of six.
///   Sets over 10 reps count for the 10RM and below.
/// - **Baselines**: a record has to beat something. The first session an exercise is logged
///   in sets its baselines and never turns gold, and neither does the first value in a slot
///   later on, such as a first ever set of eight.
/// - **Session volume** turns gold on the set that carries the session past the best volume
///   from earlier sessions, once per session.
/// - **Suspicious jumps**: a value more than `confirmationFactor` times the previous best
///   (or a time that much faster) needs the person to confirm it before anything from the set
///   counts.
public enum RecordDetector {
    /// The rep counts rep maxes are kept for.
    public static let repCounts = [1, 3, 5, 8, 10]

    /// How many times better than the previous best a value can be before it's asked about.
    ///
    /// Five catches a stray zero (10×) and a slipped decimal point, while real progress
    /// between one best and the next, even a beginner's early weeks, stays well under it.
    public static let confirmationFactor = 5.0

    /// Every value a set reaches, whether or not any of them is a record. Session volume isn't
    /// included, since it belongs to the session rather than the set.
    public static func marks(for set: RecordSet, tracking: TrackingType) -> [RecordMark] {
        guard set.counts else { return [] }
        let reps = set.reps.flatMap { $0 > 0 ? $0 : nil }
        let seconds = set.seconds.flatMap { $0 > 0 ? $0 : nil }
        let meters = set.meters.flatMap { $0 > 0 ? $0 : nil }
        switch tracking {
        case .weightReps:
            guard let reps else { return [] }
            return liftMarks(weightKg: set.weightKg ?? 0, reps: reps)
        case .reps:
            return reps.map { [RecordMark(kind: .maxReps, value: Double($0))] } ?? []
        case .time:
            return seconds.map { [RecordMark(kind: .longestTime, value: $0)] } ?? []
        case .distanceTime:
            var marks: [RecordMark] = []
            if let seconds, let meters {
                marks.append(RecordMark(kind: .bestTime, value: seconds, meters: meters))
            }
            if let meters {
                marks.append(RecordMark(kind: .longestDistance, value: meters))
            } else if let seconds {
                marks.append(RecordMark(kind: .longestTime, value: seconds))
            }
            return marks
        case .intervals:
            return []
        }
    }

    /// A loaded set's estimate and rep maxes, or max reps when it was done at bodyweight.
    private static func liftMarks(weightKg: Double, reps: Int) -> [RecordMark] {
        guard weightKg > 0 else { return [RecordMark(kind: .maxReps, value: Double(reps))] }
        var marks =
            OneRepMax.estimate(weightKg: weightKg, reps: reps).map {
                [RecordMark(kind: .estimatedOneRepMax, value: $0)]
            } ?? []
        for count in repCounts where count <= reps {
            marks.append(RecordMark(kind: .repMax, value: weightKg, reps: count))
        }
        return marks
    }

    /// The records `candidate` sets against `bests`.
    ///
    /// - Parameters:
    ///   - session: this session's sets for the exercise, the candidate included. Sets still
    ///     waiting for confirmation should be left out, so they don't add to session volume.
    ///   - bests: the best so far in each slot. Session volume's best must come from earlier
    ///     sessions only.
    ///   - isFirstSession: the exercise has no earlier session, so nothing turns gold yet.
    public static func detect(
        _ candidate: RecordSet, session: [RecordSet] = [], tracking: TrackingType, bests: RecordBests,
        isFirstSession: Bool = false
    ) -> RecordDetection {
        guard candidate.counts else { return RecordDetection() }
        var improving: [RecordMark] = []
        for mark in marks(for: candidate, tracking: tracking) {
            if let best = bests[mark.slot], mark.beats(best) {
                improving.append(mark)
            }
        }
        let suspicious =
            !candidate.isConfirmed
            && improving.contains { mark in bests[mark.slot].map(mark.isSuspicious(against:)) ?? false }

        let volumeSlot = RecordSlot(kind: .sessionVolume)
        if tracking == .weightReps, candidate.volumeKg > 0, let best = bests[volumeSlot] {
            let before = session.filter { $0.counts && $0.id != candidate.id }.reduce(0) { $0 + $1.volumeKg }
            let after = RecordMark(slot: volumeSlot, value: before + candidate.volumeKg)
            if !RecordMark(slot: volumeSlot, value: before).beats(best), after.beats(best) {
                improving.append(after)
            }
        }

        if suspicious {
            return RecordDetection(needsConfirmation: headlineFirst(improving))
        }
        return RecordDetection(records: isFirstSession ? [] : headlineFirst(improving))
    }

    /// The order a toast or summary picks from: the most specific record first, so six reps at
    /// 100 kg leads with the 5RM rather than the estimate or the 1RM.
    public static func headlineFirst(_ marks: [RecordMark]) -> [RecordMark] {
        marks.sorted { ($0.headlineRank, -($0.slot.reps ?? 0)) < ($1.headlineRank, -($1.slot.reps ?? 0)) }
    }
}

extension RecordMark {
    fileprivate var headlineRank: Int {
        switch kind {
        case .repMax: 0
        case .maxReps: 1
        case .bestTime: 2
        case .longestDistance: 3
        case .longestTime: 4
        case .estimatedOneRepMax: 5
        case .sessionVolume: 6
        }
    }
}

// MARK: - Replay

/// One session's sets for one exercise, in the order they were done.
public struct RecordSession: Hashable, Sendable {
    public var sets: [RecordSet]

    public init(sets: [RecordSet]) {
        self.sets = sets
    }
}

/// A record and the set that set it.
public struct RecordEvent: Hashable, Sendable {
    public let setID: Int
    public let mark: RecordMark

    public init(setID: Int, mark: RecordMark) {
        self.setID = setID
        self.mark = mark
    }
}

/// Every record an exercise's history holds, from replaying it in order.
public struct RecordReplay: Hashable, Sendable {
    /// In the order they were set.
    public var records: [RecordEvent] = []
    /// Sets still waiting for confirmation, with what they'd set.
    public var needsConfirmation: [RecordEvent] = []
    /// The bests after the last session.
    public var bests = RecordBests()

    public init() {}
}

extension RecordDetector {
    /// Replays an exercise's sessions, oldest first, and returns every record they set. The
    /// result depends only on the sets, so replaying after an edit or delete gives the history
    /// as if it had always been that way.
    ///
    /// A session volume record carries the session's final volume, on the set that first
    /// carried the session past the earlier best.
    public static func replay(_ sessions: [RecordSession], tracking: TrackingType) -> RecordReplay {
        var result = RecordReplay()
        var hasHistory = false
        let volumeSlot = RecordSlot(kind: .sessionVolume)
        for session in sessions {
            var trusted: [RecordSet] = []
            var volumeRecord: Int?
            for set in session.sets where set.counts {
                let detection = detect(
                    set, session: trusted + [set], tracking: tracking, bests: result.bests,
                    isFirstSession: !hasHistory)
                guard detection.needsConfirmation.isEmpty else {
                    result.needsConfirmation += detection.needsConfirmation.map { RecordEvent(setID: set.id, mark: $0) }
                    continue
                }
                trusted.append(set)
                for mark in marks(for: set, tracking: tracking) {
                    result.bests.absorb(mark)
                }
                for mark in detection.records {
                    if mark.kind == .sessionVolume { volumeRecord = result.records.count }
                    result.records.append(RecordEvent(setID: set.id, mark: mark))
                }
            }
            let volume = trusted.reduce(0) { $0 + $1.volumeKg }
            if tracking == .weightReps, volume > 0 {
                let final = RecordMark(slot: volumeSlot, value: volume)
                if let volumeRecord {
                    result.records[volumeRecord] = RecordEvent(setID: result.records[volumeRecord].setID, mark: final)
                }
                result.bests.absorb(final)
            }
            if !trusted.isEmpty { hasHistory = true }
        }
        return result
    }
}
