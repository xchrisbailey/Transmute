import Foundation

/// What a record is kept for: its kind, plus the rep count for a rep max or the distance for a
/// best time. A 5RM and a 3RM are different slots; so are a best 20 m and a best 400 m.
public struct RecordSlot: Hashable, Sendable {
    public let kind: RecordKind
    /// The rep count for a rep max, otherwise `nil`.
    public let reps: Int?
    /// The distance for a best time, to the nearest 10 cm, otherwise `nil`.
    public let meters: Double?

    public init(kind: RecordKind, reps: Int? = nil, meters: Double? = nil) {
        self.kind = kind
        self.reps = kind == .repMax ? reps : nil
        self.meters = kind == .bestTime ? meters.map { ($0 * 10).rounded() / 10 } : nil
    }

    /// A best time is the only record where less wins.
    public var lowerIsBetter: Bool {
        kind == .bestTime
    }
}

/// One value a set reached in one slot, e.g. a 5RM of 115 kg.
public struct RecordMark: Hashable, Sendable {
    public let slot: RecordSlot
    /// Kilograms, reps, seconds or metres, depending on the kind.
    public let value: Double

    public init(slot: RecordSlot, value: Double) {
        self.slot = slot
        self.value = value
    }

    public init(kind: RecordKind, value: Double, reps: Int? = nil, meters: Double? = nil) {
        self.init(slot: RecordSlot(kind: kind, reps: reps, meters: meters), value: value)
    }

    public var kind: RecordKind { slot.kind }

    /// Ties aren't records, and float noise from unit conversion isn't a tie-breaker.
    static let tolerance = 1e-6

    /// Strictly better than `best`.
    public func beats(_ best: Double) -> Bool {
        slot.lowerIsBetter ? value < best - Self.tolerance : value > best + Self.tolerance
    }

    /// Better than `best` by more than `RecordDetector.confirmationFactor`, which is more
    /// likely a typo than a training effect.
    public func isSuspicious(against best: Double) -> Bool {
        guard best > 0 else { return false }
        let factor = RecordDetector.confirmationFactor
        return slot.lowerIsBetter ? value * factor < best : value > best * factor
    }
}

/// A logged set as record detection sees it. Quantities are metric, as stored.
public struct RecordSet: Hashable, Sendable {
    /// The caller's handle for the set, e.g. its index in a list. Detection only compares ids.
    public var id: Int
    public var weightKg: Double?
    public var reps: Int?
    public var seconds: Double?
    public var meters: Double?
    public var isWarmUp: Bool
    public var isCompleted: Bool
    /// The person said a suspiciously big jump is real.
    public var isConfirmed: Bool

    public init(
        id: Int, weightKg: Double? = nil, reps: Int? = nil, seconds: Double? = nil, meters: Double? = nil,
        isWarmUp: Bool = false, isCompleted: Bool = true, isConfirmed: Bool = false
    ) {
        self.id = id
        self.weightKg = weightKg
        self.reps = reps
        self.seconds = seconds
        self.meters = meters
        self.isWarmUp = isWarmUp
        self.isCompleted = isCompleted
        self.isConfirmed = isConfirmed
    }

    /// Only finished working sets count towards records.
    public var counts: Bool {
        isCompleted && !isWarmUp
    }

    /// Load × reps, or 0 without both.
    public var volumeKg: Double {
        guard let weightKg, let reps, weightKg > 0, reps > 0 else { return 0 }
        return weightKg * Double(reps)
    }
}

/// The best value so far in each slot, for one exercise.
public struct RecordBests: Hashable, Sendable {
    public private(set) var values: [RecordSlot: Double]

    public init(_ values: [RecordSlot: Double] = [:]) {
        self.values = values
    }

    /// The best of these marks in each slot, e.g. from an exercise's stored records.
    public init(_ marks: [RecordMark]) {
        self.init()
        for mark in marks {
            absorb(mark)
        }
    }

    public subscript(slot: RecordSlot) -> Double? {
        values[slot]
    }

    /// Keeps the mark if it's the first in its slot or better than the best.
    public mutating func absorb(_ mark: RecordMark) {
        if let best = values[mark.slot], !mark.beats(best) { return }
        values[mark.slot] = mark.value
    }
}

/// What one set did for an exercise's records.
public struct RecordDetection: Hashable, Sendable {
    /// New records, the headline first.
    public var records: [RecordMark]
    /// Records the set would set but that jump too far to trust. Nothing from the set counts
    /// until the person confirms it.
    public var needsConfirmation: [RecordMark]

    public init(records: [RecordMark] = [], needsConfirmation: [RecordMark] = []) {
        self.records = records
        self.needsConfirmation = needsConfirmation
    }
}
