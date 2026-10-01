import Foundation
import TransmuteCore
import TransmuteIntelligence

/// An exercise's targets in one line, e.g. "4 × 6 · 185 lb · RPE 8" or "8 rounds of 0:20 on,
/// 0:10 off". Numbers only, so they read the same in any language; set rows for VoiceOver
/// spell them out separately.
public struct SetTargets: Equatable, Sendable {
    public var sets: Int
    public var reps: Int?
    public var seconds: Double?
    public var meters: Double?
    public var loadKg: Double?
    public var rpe: Double?
    public var rounds: Int?
    public var intervalRestSeconds: Double?
    public var restSeconds: Double?

    public init(_ sets: [BrewedSet]) {
        let first = sets.first
        self.sets = sets.count
        reps = first?.reps
        seconds = first?.seconds
        meters = first?.meters
        loadKg = first?.loadKg
        rpe = first?.rpe
        rounds = first?.rounds
        intervalRestSeconds = first?.intervalRestSeconds
        restSeconds = first?.restSeconds
    }

    public init(_ sets: [PlannedSet]) {
        let working = sets.filter { !$0.isWarmUp }
        let first = working.first ?? sets.first
        self.sets = working.count
        reps = first?.targetReps
        seconds = first?.targetSeconds
        meters = first?.targetMeters
        loadKg = first?.targetLoadKg
        rpe = first?.targetRPE
        rounds = first?.rounds
        intervalRestSeconds = first?.intervalRestSeconds
        restSeconds = first?.restSeconds
    }

    public func summary(units: Units) -> String {
        if let rounds, let seconds {
            let rest = intervalRestSeconds.map { " / \(Units.clock(seconds: $0))" } ?? ""
            return "\(rounds) × \(Units.clock(seconds: seconds))\(rest)"
        }
        var amount: String
        if let reps {
            amount = "\(sets) × \(reps)"
        } else if let meters {
            amount = "\(sets) × \(units.formatDistance(meters: meters))"
        } else if let seconds {
            amount = "\(sets) × \(Units.clock(seconds: seconds))"
        } else {
            amount = "\(sets)"
        }
        if let loadKg { amount += " · \(units.formatWeight(kg: loadKg))" }
        if let rpe { amount += " · RPE \(rpe.formatted(.number.precision(.fractionLength(0...1))))" }
        return amount
    }
}
