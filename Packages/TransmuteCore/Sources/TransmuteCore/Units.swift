import Foundation

/// Which units the user sees. Everything is stored metric and converted at the edges.
public enum UnitSystem: String, Codable, CaseIterable, Sendable {
    /// Kilograms, centimetres, kilometres.
    case metric
    /// Pounds, feet and inches, miles.
    case imperial

    /// The system the locale uses. The US, Liberia and Myanmar get imperial.
    public static func preferred(for locale: Locale = .current) -> UnitSystem {
        locale.measurementSystem == .metric ? .metric : .imperial
    }
}

/// Converts and formats metric values for display. Create one per screen from the profile's
/// preference, falling back to the locale.
public struct Units: Sendable {
    public let system: UnitSystem
    public let locale: Locale

    public static let poundsPerKilogram = 2.204_622_621_8
    public static let centimetresPerInch = 2.54
    public static let metresPerMile = 1_609.344

    public init(system: UnitSystem? = nil, locale: Locale = .current) {
        self.system = system ?? .preferred(for: locale)
        self.locale = locale
    }

    // MARK: Weight

    /// The symbol a weight is shown with: "kg" or "lb".
    public var weightSymbol: String {
        system == .metric ? "kg" : "lb"
    }

    /// A stored weight in the user's unit.
    public func displayWeight(kg: Double) -> Double {
        system == .metric ? kg : kg * Self.poundsPerKilogram
    }

    /// A weight the user entered, converted to kilograms for storage.
    public func kilograms(fromDisplay value: Double) -> Double {
        system == .metric ? value : value / Self.poundsPerKilogram
    }

    /// e.g. "115 kg" or "253.5 lb". Rounded to the nearest 0.5 in either unit.
    public func formatWeight(kg: Double) -> String {
        let value = (displayWeight(kg: kg) * 2).rounded() / 2
        return "\(value.formatted(.number.precision(.fractionLength(0...1)).locale(locale))) \(weightSymbol)"
    }

    // MARK: Height

    /// Feet and whole inches, e.g. 175.26 cm → (5, 9).
    public static func feetAndInches(cm: Double) -> (feet: Int, inches: Int) {
        let totalInches = Int((cm / centimetresPerInch).rounded())
        return (totalInches / 12, totalInches % 12)
    }

    public static func centimetres(feet: Int, inches: Double) -> Double {
        (Double(feet) * 12 + inches) * centimetresPerInch
    }

    /// e.g. "175 cm" or "5′9″".
    public func formatHeight(cm: Double) -> String {
        switch system {
        case .metric:
            return "\(Int(cm.rounded())) cm"
        case .imperial:
            let (feet, inches) = Self.feetAndInches(cm: cm)
            return "\(feet)′\(inches)″"
        }
    }

    // MARK: Distance

    /// Short distances stay in metres in both systems, as they do on a track or court.
    /// Longer ones use kilometres or miles.
    public func formatDistance(meters: Double) -> String {
        let number = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...2)).locale(locale)
        if meters < 1_000 {
            return "\(Int(meters.rounded())) m"
        }
        switch system {
        case .metric: return "\((meters / 1_000).formatted(number)) km"
        case .imperial: return "\((meters / Self.metresPerMile).formatted(number)) mi"
        }
    }

    // MARK: Time

    /// A duration as a clock, e.g. 108 → "1:48", 3_725 → "1:02:05".
    public static func clock(seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let (hours, minutes, secs) = (total / 3_600, (total % 3_600) / 60, total % 60)
        let tail = String(format: "%02d", secs)
        return hours > 0 ? "\(hours):\(String(format: "%02d", minutes)):\(tail)" : "\(minutes):\(tail)"
    }
}
