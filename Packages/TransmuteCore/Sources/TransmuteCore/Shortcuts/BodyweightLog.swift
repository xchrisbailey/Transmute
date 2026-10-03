import Foundation
import SwiftData

/// Logging a bodyweight from outside the profile screen (#19): the Log bodyweight shortcut
/// hands over a measurement in whatever unit the person said.
public enum BodyweightLog {
    /// What a person can weigh. Anything else is a slip of the tongue or the wrong unit.
    public static let plausibleKg = ProfileDraft.weightRange

    /// A measurement in kilograms, to the nearest 10 grams, as it's stored.
    public static func kilograms(_ weight: Measurement<UnitMass>) -> Double {
        (weight.converted(to: .kilograms).value * 100).rounded() / 100
    }

    /// Adds an entry to the first profile and saves. `nil` when there's no profile yet or the
    /// weight isn't one a person can have; nothing is stored then.
    @discardableResult
    public static func add(_ weight: Measurement<UnitMass>, at date: Date = .now, in context: ModelContext) throws
        -> BodyweightEntry?
    {
        let kg = kilograms(weight)
        guard plausibleKg.contains(kg) else { return nil }
        let profiles = try context.fetch(FetchDescriptor<Profile>(sortBy: [SortDescriptor(\.createdAt)]))
        guard let profile = profiles.first else { return nil }
        let entry = BodyweightEntry(date: date, kg: kg)
        profile.bodyweights?.append(entry)
        try context.save()
        return entry
    }

    /// A bodyweight as it's said aloud in the person's unit, to one decimal: "79.4 kilograms",
    /// "175 pounds".
    public static func spoken(kg: Double, units: Units) -> String {
        let value = (units.displayWeight(kg: kg) * 10).rounded() / 10
        return Measurement(value: value, unit: units.system == .metric ? UnitMass.kilograms : .pounds).formatted(
            .measurement(
                width: .wide, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0...1))
            ).locale(units.locale))
    }
}
