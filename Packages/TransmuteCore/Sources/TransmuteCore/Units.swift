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

/// Converts and formats metric values for display. Create one per screen with
/// `Units(profile)`, which reads the profile's choices and falls back to the locale.
///
/// Weight, height and distance can each be chosen on their own (#18); one left alone follows
/// the overall `system`. This is the only place that decides which unit a quantity is shown in.
public struct Units: Sendable {
    /// The overall system, which any quantity without its own choice follows.
    public let system: UnitSystem
    /// Kilograms or pounds.
    public let weight: UnitSystem
    /// Centimetres, or feet and inches.
    public let height: UnitSystem
    /// Kilometres or miles.
    public let distance: UnitSystem
    public let locale: Locale

    public static let poundsPerKilogram = 2.204_622_621_8
    public static let centimetresPerInch = 2.54
    public static let metresPerMile = 1_609.344

    /// - Parameters:
    ///   - system: The overall system; `nil` follows the locale.
    ///   - weight: The unit for weights; `nil` follows `system`. Likewise `height` and `distance`.
    public init(
        system: UnitSystem? = nil, weight: UnitSystem? = nil, height: UnitSystem? = nil, distance: UnitSystem? = nil,
        locale: Locale = .current
    ) {
        let system = system ?? .preferred(for: locale)
        self.system = system
        self.weight = weight ?? system
        self.height = height ?? system
        self.distance = distance ?? system
        self.locale = locale
    }

    /// The units a profile asks for. With no profile, the locale's.
    public init(_ profile: Profile?, locale: Locale = .current) {
        self.init(
            system: profile?.unitSystem, weight: profile?.weightUnit, height: profile?.heightUnit,
            distance: profile?.distanceUnit, locale: locale)
    }

    // MARK: Weight

    /// The symbol a weight is shown with: "kg" or "lb".
    public var weightSymbol: String {
        weight == .metric ? "kg" : "lb"
    }

    /// A stored weight in the user's unit.
    public func displayWeight(kg: Double) -> Double {
        weight == .metric ? kg : kg * Self.poundsPerKilogram
    }

    /// A weight the user entered, converted to kilograms for storage.
    public func kilograms(fromDisplay value: Double) -> Double {
        weight == .metric ? value : value / Self.poundsPerKilogram
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
        switch height {
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
        switch distance {
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
