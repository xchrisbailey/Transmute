/// Estimated one-rep max from a weight × reps set, shared by progression (#12) and records (#13).
public enum OneRepMax {
    /// Sets above this many reps say little about a single, so they aren't used to estimate.
    public static let maxReps = 10

    /// The Epley formula, weight × (1 + reps / 30). A single is taken as is. `nil` when there's
    /// no load, no reps, or more than `maxReps`.
    public static func estimate(weightKg: Double, reps: Int) -> Double? {
        guard weightKg > 0, (1...maxReps).contains(reps) else { return nil }
        return reps == 1 ? weightKg : weightKg * (1 + Double(reps) / 30)
    }
}
