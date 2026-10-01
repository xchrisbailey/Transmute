import Foundation

/// Applies Health data to the profile without overwriting what the person typed or importing
/// anything twice.
public enum HealthImport {
    /// Fills empty profile fields from Health. Fields the person already set are kept. Returns
    /// whether anything changed.
    @discardableResult
    public static func prefill(_ profile: Profile, from metrics: HealthBodyMetrics, on date: Date = .now) -> Bool {
        var changed = false
        if profile.heightCm == nil, let height = metrics.heightCm {
            profile.heightCm = height
            changed = true
        }
        if profile.birthYear == nil, let year = metrics.birthYear {
            profile.birthYear = year
            changed = true
        }
        if profile.sex == nil, let sex = metrics.sex {
            profile.sex = sex
            changed = true
        }
        if profile.latestBodyweightKg == nil, let weight = metrics.weightKg {
            profile.bodyweights?.append(BodyweightEntry(date: date, kg: weight))
            changed = true
        }
        return changed
    }

    /// Adds Health bodyweights the profile doesn't have yet. Samples already imported, and ones
    /// Transmute wrote from an entry, are skipped. Returns how many were added.
    @discardableResult
    public static func merge(_ samples: [HealthBodyweight], into profile: Profile) -> Int {
        let known = Set((profile.bodyweights ?? []).compactMap(\.healthKitSampleID))
        let fresh = samples.filter { !$0.isFromTransmute && !known.contains($0.id) }
        for sample in fresh {
            profile.bodyweights?.append(BodyweightEntry(date: sample.date, kg: sample.kg, healthKitSampleID: sample.id))
        }
        return fresh.count
    }
}

/// How much other training happened in a stretch of time, for showing the week and for
/// reworking plans around it.
public struct OutsideLoad: Equatable, Sendable {
    public var sessions: Int
    public var minutes: Int
    /// Minutes by activity, e.g. ["tennis": 180].
    public var minutesByActivity: [String: Int]

    public init(_ workouts: [OtherWorkout]) {
        sessions = workouts.count
        minutes = Int((workouts.reduce(0) { $0 + $1.duration } / 60).rounded())
        minutesByActivity = workouts.reduce(into: [:]) { totals, workout in
            totals[workout.activity, default: 0] += Int((workout.duration / 60).rounded())
        }
    }

    /// e.g. "3 sessions outside Transmute: tennis 180 min, running 40 min".
    public var promptDescription: String {
        guard sessions > 0 else { return "No other training recorded." }
        let parts = minutesByActivity.sorted { ($1.value, $0.key) < ($0.value, $1.key) }
            .map { "\($0.key) \($0.value) min" }
        return "\(sessions) sessions outside Transmute: \(parts.joined(separator: ", "))"
    }
}
