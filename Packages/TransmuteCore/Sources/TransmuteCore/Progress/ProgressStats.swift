import Foundation

/// Progress and insights (#16): the numbers behind the charts, tiles and weekly summary.
///
/// Everything is computed from what's passed in, in metric units. Only finished workouts and
/// completed working sets count; warm-ups and sessions still running are left out.
public enum ProgressStats {
    /// Differences smaller than this are float noise, not progress.
    static let tolerance = 1e-6

    // MARK: Estimated one-rep max

    /// The best estimated one-rep max of one session.
    public struct MaxPoint: Identifiable, Equatable, Sendable {
        /// When the session started.
        public var date: Date
        public var kg: Double
        /// The session set an estimated one-rep max record.
        public var isRecord: Bool
        public var id: Date { date }

        public init(date: Date, kg: Double, isRecord: Bool = false) {
            self.date = date
            self.kg = kg
            self.isRecord = isRecord
        }
    }

    /// An exercise's estimated one-rep max over time: the best estimate of each finished
    /// session, oldest first. Sessions without a set that can be estimated from are left out.
    public static func maxTrend(of exerciseID: String, workouts: [Workout], records: [PersonalRecord]) -> [MaxPoint] {
        let recordSessions = Set(
            records.filter { $0.exerciseID == exerciseID && $0.kind == .estimatedOneRepMax }
                .compactMap { $0.set?.exercise?.workout }.map(ObjectIdentifier.init))
        return finished(workouts).compactMap { workout in
            let best = workout.workingSets(of: exerciseID)
                .compactMap { set in set.weightKg.flatMap { OneRepMax.estimate(weightKg: $0, reps: set.reps ?? 0) } }
                .max()
            guard let best else { return nil }
            return MaxPoint(
                date: workout.startedAt, kg: best, isRecord: recordSessions.contains(ObjectIdentifier(workout)))
        }
    }

    // MARK: Key lifts

    /// The plan's key lifts: its weight × reps exercises, the ones with the most planned working
    /// sets first and ties in library order. Without a plan, or when the plan has none, the
    /// weight × reps exercises with the most logged working sets.
    public static func keyLifts(
        of plan: Plan?, workouts: [Workout], library: ExerciseLibrary = .bundled, limit: Int = 4
    ) -> [String] {
        var planned: [String: Int] = [:]
        for exercise in (plan?.days ?? []).flatMap({ $0.exercises ?? [] }) {
            planned[exercise.exerciseID, default: 0] += (exercise.sets ?? []).count { !$0.isWarmUp }
        }
        let fromPlan = ranked(planned, tracking: [.weightReps], library: library, limit: limit)
        guard fromPlan.isEmpty else { return fromPlan }

        var logged: [String: Int] = [:]
        for exercise in finished(workouts).flatMap(\.orderedExercises) {
            logged[exercise.exerciseID, default: 0] += exercise.orderedSets.count(where: \.isWorking)
        }
        return ranked(logged, tracking: [.weightReps], library: library, limit: limit)
    }

    /// Where a key lift's estimated one-rep max stands.
    public struct LiftKPI: Identifiable, Equatable, Sendable {
        public var exerciseID: String
        /// The exercise's library name, or its id when the library doesn't have it.
        public var name: String
        /// The latest session's best estimate.
        public var currentKg: Double
        /// Against the first session in the window. `nil` with only one session.
        public var changeKg: Double?
        public var id: String { exerciseID }

        public init(exerciseID: String, name: String, currentKg: Double, changeKg: Double? = nil) {
            self.exerciseID = exerciseID
            self.name = name
            self.currentKg = currentKg
            self.changeKg = changeKg
        }
    }

    /// One tile per key lift that has a session on or after `since`.
    public static func liftKPIs(
        plan: Plan?, workouts: [Workout], records: [PersonalRecord], since: Date? = nil,
        library: ExerciseLibrary = .bundled
    ) -> [LiftKPI] {
        keyLifts(of: plan, workouts: workouts, library: library).compactMap { exerciseID in
            let points = maxTrend(of: exerciseID, workouts: workouts, records: records)
                .filter { since == nil || $0.date >= since! }
            guard let first = points.first, let last = points.last else { return nil }
            return LiftKPI(
                exerciseID: exerciseID, name: name(of: exerciseID, in: library), currentKg: last.kg,
                changeKg: points.count > 1 ? last.kg - first.kg : nil)
        }
    }
}

// MARK: - Shared helpers

extension ProgressStats {
    /// Finished workouts, oldest first.
    static func finished(_ workouts: [Workout]) -> [Workout] {
        workouts.filter { $0.endedAt != nil }.sorted { $0.startedAt < $1.startedAt }
    }

    static func name(of exerciseID: String, in library: ExerciseLibrary) -> String {
        library.exercise(id: exerciseID)?.name ?? exerciseID
    }

    /// Exercise ids with the given tracking, highest count first and ties in library order.
    static func ranked(_ counts: [String: Int], tracking: Set<TrackingType>, library: ExerciseLibrary, limit: Int)
        -> [String]
    {
        let order = Dictionary(
            library.exercises.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
        let ids = counts.filter { id, count in
            count > 0 && library.exercise(id: id).map { tracking.contains($0.tracking) } == true
        }
        .keys.sorted { (-counts[$0]!, order[$0] ?? .max) < (-counts[$1]!, order[$1] ?? .max) }
        return Array(ids.prefix(max(limit, 0)))
    }

    /// The start of the week a date falls in.
    static func weekStart(of date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    /// The week a date falls in, start inclusive and end exclusive.
    static func week(of date: Date, calendar: Calendar) -> Range<Date> {
        let start = weekStart(of: date, calendar: calendar)
        return start..<(calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? start)
    }
}

extension LoggedSet {
    /// Completed and not a warm-up.
    var isWorking: Bool {
        isCompleted && !isWarmUp
    }

    /// Load × reps of a working set, or 0.
    var workingVolumeKg: Double {
        guard isWorking, let weightKg, let reps, weightKg > 0, reps > 0 else { return 0 }
        return weightKg * Double(reps)
    }
}

extension Workout {
    /// The working sets of an exercise, wherever it appears in the workout.
    func workingSets(of exerciseID: String) -> [LoggedSet] {
        orderedExercises.filter { $0.exerciseID == exerciseID }.flatMap(\.orderedSets).filter(\.isWorking)
    }

    /// Kilograms lifted in working sets.
    var workingVolumeKg: Double {
        orderedExercises.flatMap(\.orderedSets).reduce(0) { $0 + $1.workingVolumeKg }
    }
}
