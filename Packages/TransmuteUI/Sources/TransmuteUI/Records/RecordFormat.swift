import Foundation
import TransmuteCore

/// How a record reads: its label ("5RM", "Est. 1RM", "Best 20 m") and its value in the
/// person's units ("115 kg", "12 reps", "2.85 s", "1:48").
public enum RecordFormat {
    public static func label(_ slot: RecordSlot, units: Units) -> LocalizedStringResource {
        switch slot.kind {
        case .estimatedOneRepMax: RecordCopy.estimatedOneRepMax
        case .repMax: RecordCopy.repMax(reps: slot.reps ?? 1)
        case .maxReps: RecordCopy.maxReps
        case .bestTime: RecordCopy.bestTime(distance: units.formatDistance(meters: slot.meters ?? 0))
        case .longestTime: RecordCopy.longestTime
        case .longestDistance: RecordCopy.longestDistance
        case .sessionVolume: RecordCopy.sessionVolume
        }
    }

    public static func label(_ mark: RecordMark, units: Units) -> LocalizedStringResource {
        label(mark.slot, units: units)
    }

    public static func value(_ mark: RecordMark, units: Units) -> String {
        switch mark.kind {
        case .estimatedOneRepMax, .repMax, .sessionVolume:
            units.formatWeight(kg: mark.value)
        case .maxReps:
            String(localized: RecordCopy.reps(Int(mark.value.rounded())))
        case .bestTime, .longestTime:
            time(seconds: mark.value, locale: units.locale)
        case .longestDistance:
            units.formatDistance(meters: mark.value)
        }
    }

    /// Under a minute to the hundredth, as sprints are timed ("2.85 s"); longer as a clock.
    static func time(seconds: Double, locale: Locale) -> String {
        guard seconds < 60 else { return Units.clock(seconds: seconds) }
        return "\(seconds.formatted(.number.precision(.fractionLength(0...2)).locale(locale))) s"
    }

    /// The toast and VoiceOver sentence, e.g. "Gold. Squat 5RM, 115 kg."
    public static func gold(_ mark: RecordMark, exercise: String, units: Units) -> LocalizedStringResource {
        Copy.gold(
            exercise: exercise, record: String(localized: label(mark, units: units)), value: value(mark, units: units))
    }
}
