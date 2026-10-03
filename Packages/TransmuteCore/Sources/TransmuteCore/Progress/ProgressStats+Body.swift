import Foundation

// MARK: - Bodyweight

extension ProgressStats {
    /// One weigh-in with the trend at that moment.
    public struct BodyweightPoint: Identifiable, Equatable, Sendable {
        public var date: Date
        public var kg: Double
        /// The mean of the weigh-ins in the seven days up to and including this one.
        public var trendKg: Double
        public var id: Date { date }

        public init(date: Date, kg: Double, trendKg: Double) {
            self.date = date
            self.kg = kg
            self.trendKg = trendKg
        }
    }

    /// How far back the rolling mean looks.
    static let trendWindow: TimeInterval = 7 * 86_400

    /// Weigh-ins on or after `since`, oldest first, each with a seven-day rolling mean. The mean
    /// also uses weigh-ins from before `since`, so the line doesn't jump at the window's edge.
    public static func bodyweightTrend(_ entries: [BodyweightEntry], since: Date? = nil) -> [BodyweightPoint] {
        let sorted = entries.map { (date: $0.date, kg: $0.kg) }.sorted { $0.date < $1.date }
        var points: [BodyweightPoint] = []
        var first = 0
        for (index, entry) in sorted.enumerated() {
            while sorted[first].date <= entry.date - trendWindow {
                first += 1
            }
            guard since == nil || entry.date >= since! else { continue }
            let window = sorted[first...index]
            let mean = window.reduce(0) { $0 + $1.kg } / Double(window.count)
            points.append(BodyweightPoint(date: entry.date, kg: entry.kg, trendKg: mean))
        }
        return points
    }

    /// The latest weigh-in and how the trend moved.
    public struct BodyweightKPI: Equatable, Sendable {
        /// The latest weigh-in as entered.
        public var currentKg: Double
        /// The trend now against the trend at the first weigh-in in the window. `nil` with only
        /// one weigh-in.
        public var changeKg: Double?

        public init(currentKg: Double, changeKg: Double? = nil) {
            self.currentKg = currentKg
            self.changeKg = changeKg
        }
    }

    /// `nil` when there's no weigh-in on or after `since`.
    public static func bodyweightKPI(_ entries: [BodyweightEntry], since: Date? = nil) -> BodyweightKPI? {
        let points = bodyweightTrend(entries, since: since)
        guard let first = points.first, let last = points.last else { return nil }
        return BodyweightKPI(currentKg: last.kg, changeKg: points.count > 1 ? last.trendKg - first.trendKg : nil)
    }
}

// MARK: - Conditioning

extension ProgressStats {
    /// The number that matters for work that isn't weight × reps.
    public enum ConditioningMetric: String, Sendable {
        /// Intervals: rounds completed in the session.
        case rounds
        /// Distance and time: the best pace, in seconds per 100 m. Lower is better.
        case pace
        /// Time: the longest hold or effort, in seconds.
        case longestTime
        /// Reps: the most reps in one set.
        case reps

        public init?(tracking: TrackingType) {
            switch tracking {
            case .weightReps: return nil
            case .intervals: self = .rounds
            case .distanceTime: self = .pace
            case .time: self = .longestTime
            case .reps: self = .reps
            }
        }

        public var lowerIsBetter: Bool {
            self == .pace
        }
    }

    /// One session's value.
    public struct ConditioningPoint: Identifiable, Equatable, Sendable {
        /// When the session started.
        public var date: Date
        public var value: Double
        public var id: Date { date }

        public init(date: Date, value: Double) {
            self.date = date
            self.value = value
        }
    }

    /// One exercise's sessions, oldest first.
    public struct ConditioningSeries: Identifiable, Equatable, Sendable {
        public var exerciseID: String
        public var name: String
        public var metric: ConditioningMetric
        public var points: [ConditioningPoint]
        public var id: String { exerciseID }

        public init(exerciseID: String, name: String, metric: ConditioningMetric, points: [ConditioningPoint]) {
            self.exerciseID = exerciseID
            self.name = name
            self.metric = metric
            self.points = points
        }
    }

    /// Exercises the library tracks some other way than weight × reps, with at least two
    /// sessions: the ones with the most sessions first, ties in library order.
    public static func conditioning(_ workouts: [Workout], library: ExerciseLibrary = .bundled, limit: Int = 4)
        -> [ConditioningSeries]
    {
        var points: [String: [ConditioningPoint]] = [:]
        for workout in finished(workouts) {
            for exerciseID in Set(workout.orderedExercises.map(\.exerciseID)) {
                guard let tracking = library.exercise(id: exerciseID)?.tracking,
                    let metric = ConditioningMetric(tracking: tracking),
                    let value = value(of: metric, in: workout.workingSets(of: exerciseID))
                else { continue }
                points[exerciseID, default: []].append(ConditioningPoint(date: workout.startedAt, value: value))
            }
        }
        let counts = points.mapValues(\.count).filter { $0.value >= 2 }
        let tracking = Set(TrackingType.allCases).subtracting([.weightReps])
        return ranked(counts, tracking: tracking, library: library, limit: limit).compactMap { exerciseID in
            guard let exercise = library.exercise(id: exerciseID),
                let metric = ConditioningMetric(tracking: exercise.tracking)
            else { return nil }
            return ConditioningSeries(
                exerciseID: exerciseID, name: exercise.name, metric: metric, points: points[exerciseID] ?? [])
        }
    }

    /// A session's value from its working sets, or `nil` when no set carries the numbers.
    static func value(of metric: ConditioningMetric, in sets: [LoggedSet]) -> Double? {
        switch metric {
        case .rounds:
            // A completed interval set without a round count is one round.
            sets.isEmpty ? nil : Double(sets.reduce(0) { $0 + max($1.rounds ?? 1, 0) })
        case .pace:
            sets.compactMap { set -> Double? in
                guard let seconds = set.seconds, let meters = set.meters, seconds > 0, meters > 0 else { return nil }
                return seconds * 100 / meters
            }
            .min()
        case .longestTime:
            sets.compactMap(\.seconds).filter { $0 > 0 }.max()
        case .reps:
            sets.compactMap(\.reps).filter { $0 > 0 }.max().map(Double.init)
        }
    }
}
