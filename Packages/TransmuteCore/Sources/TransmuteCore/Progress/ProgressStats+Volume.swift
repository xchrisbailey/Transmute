import Foundation

extension ProgressStats {
    /// What weekly volume is split by.
    public enum VolumeGrouping: Sendable {
        /// The exercise's category.
        case category
        /// The exercise's first primary muscle.
        case muscle
    }

    /// The group of exercises the library doesn't know, or that name no primary muscle.
    public static let otherGroup = "other"

    /// One group's share of a week.
    public struct VolumeSlice: Identifiable, Equatable, Sendable {
        /// An `ExerciseCategory` or `Muscle` raw value, or `otherGroup`.
        public var group: String
        public var kg: Double
        public var id: String { group }

        public init(group: String, kg: Double) {
            self.group = group
            self.kg = kg
        }
    }

    /// One week's volume.
    public struct WeekVolume: Identifiable, Equatable, Sendable {
        public var weekStart: Date
        /// Groups with volume, in the order `ExerciseCategory` or `Muscle` lists them.
        public var slices: [VolumeSlice]
        public var totalKg: Double
        public var id: Date { weekStart }

        public init(weekStart: Date, slices: [VolumeSlice] = []) {
            self.weekStart = weekStart
            self.slices = slices
            self.totalKg = slices.reduce(0) { $0 + $1.kg }
        }
    }

    /// Weekly volume (load × reps) by group, oldest week first, for the last `weeks` weeks up
    /// to and including `now`'s. Runs from the first to the last week with volume in that
    /// window, with the empty weeks between them.
    public static func weeklyVolume(
        _ workouts: [Workout], by grouping: VolumeGrouping, weeks: Int = 8, now: Date = .now,
        calendar: Calendar = .init(identifier: .iso8601), library: ExerciseLibrary = .bundled
    ) -> [WeekVolume] {
        guard weeks > 0 else { return [] }
        let thisWeek = week(of: now, calendar: calendar)
        let first = calendar.date(byAdding: .weekOfYear, value: 1 - weeks, to: thisWeek.lowerBound) ?? now

        var byWeek: [Date: [String: Double]] = [:]
        for workout in finished(workouts) where (first..<thisWeek.upperBound).contains(workout.startedAt) {
            let start = weekStart(of: workout.startedAt, calendar: calendar)
            for exercise in workout.orderedExercises {
                let kg = exercise.orderedSets.reduce(0) { $0 + $1.workingVolumeKg }
                guard kg > 0 else { continue }
                byWeek[start, default: [:]][group(of: exercise.exerciseID, by: grouping, in: library), default: 0] += kg
            }
        }
        guard var start = byWeek.keys.min(), let last = byWeek.keys.max() else { return [] }

        let order = groups(grouping)
        var result: [WeekVolume] = []
        while start <= last {
            let volume = byWeek[start] ?? [:]
            result.append(
                WeekVolume(
                    weekStart: start,
                    slices: order.compactMap { group in volume[group].map { VolumeSlice(group: group, kg: $0) } }))
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else { break }
            start = next
        }
        return result
    }

    /// This week's volume against last week's.
    public struct VolumeKPI: Equatable, Sendable {
        public var thisWeekKg: Double
        public var lastWeekKg: Double
        /// The change as a fraction of last week, e.g. 0.25 for a quarter more. `nil` when last
        /// week had no volume.
        public var change: Double?

        public init(thisWeekKg: Double, lastWeekKg: Double) {
            self.thisWeekKg = thisWeekKg
            self.lastWeekKg = lastWeekKg
            self.change = lastWeekKg > 0 ? (thisWeekKg - lastWeekKg) / lastWeekKg : nil
        }
    }

    public static func volumeKPI(
        _ workouts: [Workout], now: Date = .now, calendar: Calendar = .init(identifier: .iso8601)
    ) -> VolumeKPI {
        let thisWeek = week(of: now, calendar: calendar)
        let lastStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek.lowerBound) ?? thisWeek.lowerBound
        return VolumeKPI(
            thisWeekKg: volumeKg(workouts, in: thisWeek),
            lastWeekKg: volumeKg(workouts, in: lastStart..<thisWeek.lowerBound))
    }

    /// Kilograms lifted in the working sets of finished workouts started in a range.
    static func volumeKg(_ workouts: [Workout], in range: Range<Date>) -> Double {
        workouts.filter { $0.endedAt != nil && range.contains($0.startedAt) }.reduce(0) { $0 + $1.workingVolumeKg }
    }

    static func group(of exerciseID: String, by grouping: VolumeGrouping, in library: ExerciseLibrary) -> String {
        let exercise = library.exercise(id: exerciseID)
        switch grouping {
        case .category: return exercise?.category.rawValue ?? otherGroup
        case .muscle: return exercise?.primaryMuscles.first?.rawValue ?? otherGroup
        }
    }

    /// Every group in display order, `otherGroup` last.
    static func groups(_ grouping: VolumeGrouping) -> [String] {
        switch grouping {
        case .category: ExerciseCategory.allCases.map(\.rawValue) + [otherGroup]
        case .muscle: Muscle.allCases.map(\.rawValue) + [otherGroup]
        }
    }
}
