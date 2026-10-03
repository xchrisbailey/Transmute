import Foundation

/// Points at a set in a running session by where it sits: the exercise's `order`, then the
/// set's. Sets have no id that's the same on both devices.
public struct SetRef: Codable, Hashable, Sendable {
    public var exerciseOrder: Int
    public var setOrder: Int

    public init(exerciseOrder: Int, setOrder: Int) {
        self.exerciseOrder = exerciseOrder
        self.setOrder = setOrder
    }
}

/// What was done in a set. A command carries all of them and replaces the set's values, so
/// `nil` clears a value rather than leaving it alone.
public struct SetValues: Codable, Equatable, Sendable {
    public var weightKg: Double?
    public var reps: Int?
    public var seconds: Double?
    public var meters: Double?
    public var rpe: Double?

    public init(
        weightKg: Double? = nil, reps: Int? = nil, seconds: Double? = nil, meters: Double? = nil, rpe: Double? = nil
    ) {
        self.weightKg = weightKg
        self.reps = reps
        self.seconds = seconds
        self.meters = meters
        self.rpe = rpe
    }

    /// The values a set shows now, as the starting point for an edit.
    public init(_ set: SessionSnapshot.Set) {
        self.init(weightKg: set.weightKg, reps: set.reps, seconds: set.seconds, meters: set.meters, rpe: set.rpe)
    }
}

/// A change the mirroring device asks the owner to make (#15). The owner applies it with
/// `SessionMirror.apply` and sends back a fresh snapshot; the mirror applies it to its own
/// snapshot straight away with `SessionSnapshot.applying` so the screen doesn't wait.
///
/// Commands carry their own dates, so both sides land on the same rest timer.
public enum SessionCommand: Codable, Equatable, Sendable {
    /// Writes the values and checks the set off, starting its rest. Logging a set that's
    /// already logged does nothing, so a command delivered twice is harmless.
    case logSet(SetRef, SetValues, at: Date)
    /// Takes a check back, e.g. after a mis-tap.
    case reopenSet(SetRef)
    /// Changes a set's values without checking it off.
    case updateSet(SetRef, SetValues)
    /// Starts or replaces the rest timer. `nil` clears it, which is how a rest is skipped.
    case startRest(seconds: Double?, at: Date)
    /// Adds or takes away rest from the running timer.
    case adjustRest(by: Double, at: Date)
    /// Passes over an exercise, or brings it back.
    case setSkipped(exerciseOrder: Int, Bool)
    /// Ends the session, keeping what was logged.
    case finish(at: Date)
    /// Throws the session away.
    case discard
}
