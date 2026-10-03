import Foundation

/// Why the engine set an exercise's targets, in machine form. TransmuteUI turns it into the
/// "From your plan" sentence; the numbers here are all that sentence needs.
public struct ProgressionReason: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        /// No history yet: targets as planned, and the first working sets set the baseline.
        case calibrate
        /// A deload week: fewer sets and a lighter load.
        case deload
        /// The person is holding this exercise's targets.
        case held
        /// A percentage of one-rep max, resolved from the estimate.
        case percentOfMax
        /// History only at another rep scheme, so the load comes from the estimated max.
        case fromEstimate
        /// Every working set hit its target: more load.
        case addLoad
        /// A rep range not yet topped out: same load, chase the top of the range.
        case buildReps
        /// Every set hit its reps and there's no load to add: more reps.
        case addReps
        /// Reps were hit, but harder than the target RPE: same load.
        case holdEffort
        /// Sets felt easier than the target RPE: more load.
        case rpeUp
        /// Sets felt harder than the target RPE: less load.
        case rpeDown
        /// Sets landed on the target RPE: same load.
        case rpeOnTarget
        /// Missed once: same targets again.
        case retry
        /// Missed twice in a row: hold.
        case hold
        /// Missed three or more times in a row: back off about 10%.
        case drop
        /// Longer holds or efforts.
        case addTime
        /// Further.
        case addDistance
        /// The same distance in less time.
        case faster
        /// One more interval round.
        case addRound
        /// Shorter rest between interval rounds.
        case shorterRest
        /// Speed, power and mobility work that stays the same, since it's about quality.
        case steady
    }

    public var exerciseID: String
    public var kind: Kind
    /// The new working load, when there is one.
    public var loadKg: Double?
    /// Signed change in load from the session judged.
    public var changeKg: Double?
    /// Signed change in reps, seconds, metres or rounds, by kind.
    public var change: Double?
    /// The fraction applied: 0.9 for a drop or a deload's load, or a percentage of max.
    public var fraction: Double?
    /// The estimated one-rep max used, in kilograms.
    public var oneRepMaxKg: Double?
    /// Working sets judged, or a deload's sets.
    public var sets: Int?
    /// Misses in a row.
    public var misses: Int?
    /// Average logged RPE of the working sets judged, and the target.
    public var rpe: Double?
    public var targetRPE: Double?
    /// The workout the judgement came from.
    public var sourceDate: Date?

    public init(
        exerciseID: String, kind: Kind, loadKg: Double? = nil, changeKg: Double? = nil, change: Double? = nil,
        fraction: Double? = nil, oneRepMaxKg: Double? = nil, sets: Int? = nil, misses: Int? = nil,
        rpe: Double? = nil, targetRPE: Double? = nil, sourceDate: Date? = nil
    ) {
        self.exerciseID = exerciseID
        self.kind = kind
        self.loadKg = loadKg
        self.changeKg = changeKg
        self.change = change
        self.fraction = fraction
        self.oneRepMaxKg = oneRepMaxKg
        self.sets = sets
        self.misses = misses
        self.rpe = rpe
        self.targetRPE = targetRPE
        self.sourceDate = sourceDate
    }
}
