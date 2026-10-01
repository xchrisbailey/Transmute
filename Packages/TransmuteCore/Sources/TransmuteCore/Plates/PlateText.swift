import Foundation

/// Plates as short text, for the watch (#15) and anywhere a drawn bar won't fit.
public enum PlateText {
    /// A plate's weight without trailing zeros, e.g. 20, 2.5, 1.25.
    public static func weight(_ value: Double, locale: Locale = .current) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).locale(locale))
    }

    /// One side's plates joined with middle dots, e.g. "20 · 10 · 2.5".
    public static func plates(_ loading: PlateLoading, locale: Locale = .current) -> String {
        loading.perSide.map { weight($0, locale: locale) }.joined(separator: " · ")
    }

    /// e.g. "per side: 20 · 10 · 2.5", or "just the bar".
    public static func compact(_ loading: PlateLoading, locale: Locale = .current) -> String {
        if loading.isBarOnly {
            return String(localized: justTheBar)
        }
        return String(localized: perSide(plates(loading, locale: locale)))
    }

    static let justTheBar = LocalizedStringResource(
        "plain.plates.justTheBarCompact", defaultValue: "just the bar", bundle: .main,
        comment: "plain. Watch plate text when nothing goes on the bar.")

    static func perSide(_ plates: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.plates.perSideCompact", defaultValue: "per side: \(plates)", bundle: .main,
            comment: "plain. Watch plate text; the argument is one side's plates, e.g. 20 · 10 · 2.5.")
    }
}
