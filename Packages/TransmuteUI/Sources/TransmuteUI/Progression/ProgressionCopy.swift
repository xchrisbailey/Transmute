import Foundation
import TransmuteCore

/// Strings for progression (#12): the templated "From your plan" sentence built from the
/// engine's `ProgressionReason`, and the progression settings. All plain, since they're read
/// mid-session.
///
/// Phrasing the sentence with the on-device model is left for later; the template is always
/// the fallback.
public enum ProgressionCopy {
    public static let fromYourPlan = LocalizedStringResource(
        "plain.progression.fromYourPlan", defaultValue: "From your plan", bundle: .main,
        comment: "plain. Label above the sentence explaining today's targets.")

    public static let holdWeight = LocalizedStringResource(
        "plain.progression.holdWeight", defaultValue: "Hold this weight", bundle: .main,
        comment: "plain. Session button that stops an exercise's targets going up.")

    public static let letItProgress = LocalizedStringResource(
        "plain.progression.letItProgress", defaultValue: "Let it progress", bundle: .main,
        comment: "plain. Button that releases a held exercise.")

    public static func letNamedProgress(_ exercise: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.progression.letNamedProgress", defaultValue: "Let \(exercise) progress", bundle: .main,
            comment: "plain. VoiceOver label for releasing a held exercise; the argument is its name.")
    }

    public static let title = LocalizedStringResource(
        "plain.progression.title", defaultValue: "Progression", bundle: .main,
        comment: "plain. Progression settings screen title and Profile row.")

    static let increments = LocalizedStringResource(
        "plain.progression.increments", defaultValue: "Weight increments", bundle: .main,
        comment: "plain. Settings section.")

    static let incrementsNote = LocalizedStringResource(
        "plain.progression.incrementsNote",
        defaultValue: "How much a lift goes up when every set moves well. Loads round to what your kit can make.",
        bundle: .main,
        comment: "plain. Under the increment pickers.")

    static let upperBody = LocalizedStringResource(
        "plain.progression.upperBody", defaultValue: "Upper body", bundle: .main,
        comment: "plain. Increment picker for pushes and pulls.")

    static let lowerBody = LocalizedStringResource(
        "plain.progression.lowerBody", defaultValue: "Lower body", bundle: .main,
        comment: "plain. Increment picker for squats, hinges and lunges.")

    static let held = LocalizedStringResource(
        "plain.progression.heldSection", defaultValue: "Held weights", bundle: .main,
        comment: "plain. Settings section listing held exercises.")

    static let heldNote = LocalizedStringResource(
        "plain.progression.heldNote", defaultValue: "These stay where they are until you let them progress.",
        bundle: .main,
        comment: "plain. Under the held exercises.")

    static let noneHeld = LocalizedStringResource(
        "plain.progression.noneHeld",
        defaultValue: "Nothing held. Choose Hold this weight during a workout to keep an exercise where it is.",
        bundle: .main,
        comment: "plain. Empty held exercises list.")
}

// The "From your plan" sentence.
extension ProgressionCopy {
    /// The sentence for a reason, e.g. "Back Squat goes up 2.5 kg since every set moved well on
    /// Thursday."
    /// - Parameters:
    ///   - exercise: The exercise's display name.
    ///   - now: Today, to say "Thursday" for this week and "Sep 28" for older sessions.
    public static func sentence(
        for reason: ProgressionReason, exercise: String, units: Units, now: Date = .now,
        calendar: Calendar = .current
    ) -> LocalizedStringResource {
        let parts = Parts(reason: reason, units: units, now: now, calendar: calendar)
        switch reason.kind {
        case .calibrate, .deload, .held, .percentOfMax, .fromEstimate, .steady:
            return setUp(reason, exercise, parts)
        case .addLoad, .buildReps, .addReps, .holdEffort, .rpeUp, .rpeDown, .rpeOnTarget:
            return load(reason, exercise, parts)
        case .retry, .hold, .drop:
            return missed(reason, exercise, parts)
        case .addTime, .addDistance, .faster, .addRound, .shorterRest:
            return volume(reason, exercise, parts)
        }
    }

    /// The numbers a sentence needs, formatted.
    struct Parts {
        let load: String?
        let change: String?
        let day: String
        let seconds: String
        let distance: String
        let oneRepMax: String
        let percent: String
        let rpe: String
        let targetRPE: String
        let sets: String
        let misses: String

        var loadText: String { load ?? "" }

        init(reason: ProgressionReason, units: Units, now: Date, calendar: Calendar) {
            let number = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...1)).locale(units.locale)
            load = reason.loadKg.map { units.formatWeight(kg: $0) }
            change = reason.changeKg.map { units.formatWeight(kg: abs($0)) }
            day = Self.day(reason.sourceDate, now: now, calendar: calendar, locale: units.locale)
            seconds = abs(reason.change ?? 0).formatted(number)
            distance = units.formatDistance(meters: abs(reason.change ?? 0))
            oneRepMax = reason.oneRepMaxKg.map { units.formatWeight(kg: $0) } ?? ""
            percent = (reason.fraction ?? 0).formatted(.percent.precision(.fractionLength(0)).locale(units.locale))
            rpe = (reason.rpe ?? 0).formatted(number)
            targetRPE = (reason.targetRPE ?? 0).formatted(number)
            sets = (reason.sets ?? 0).formatted(.number.locale(units.locale))
            misses = (reason.misses ?? 0).formatted(.number.locale(units.locale))
        }

        /// "on Thursday" within the last week, "on Sep 28" before that, "last time" without a date.
        static func day(_ date: Date?, now: Date, calendar: Calendar, locale: Locale) -> String {
            guard let date else { return String(localized: ProgressionCopy.lastTime) }
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: now).day ?? 0
            var style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            style = days < 7 ? style.weekday(.wide) : style.month(.abbreviated).day()
            return String(localized: ProgressionCopy.onDay(date.formatted(style)))
        }
    }

    static let lastTime = LocalizedStringResource(
        "plain.progression.lastTime", defaultValue: "last time", bundle: .main,
        comment: "plain. Ends a From your plan sentence when the session's date isn't known.")

    static func onDay(_ day: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.progression.onDay", defaultValue: "on \(day)", bundle: .main,
            comment: "plain. Ends a From your plan sentence; the argument is a weekday or a date.")
    }

    private static func setUp(_ reason: ProgressionReason, _ exercise: String, _ parts: Parts)
        -> LocalizedStringResource
    {
        switch reason.kind {
        case .deload:
            guard let load = parts.load else {
                return LocalizedStringResource(
                    "plain.progression.deloadNoLoad",
                    defaultValue: "Deload week: \(exercise) drops to \(parts.sets) sets so you recover.", bundle: .main,
                    comment: "plain. From your plan; arguments are the exercise and the number of sets.")
            }
            return LocalizedStringResource(
                "plain.progression.deload",
                defaultValue:
                    "Deload week: \(exercise) drops to \(parts.sets) sets at \(load), about \(parts.percent) of the usual load.",
                bundle: .main,
                comment: "plain. From your plan; arguments are the exercise, sets, load and a percentage.")
        case .held:
            guard let load = parts.load else {
                return LocalizedStringResource(
                    "plain.progression.heldNoLoad", defaultValue: "\(exercise) stays where it was, as you asked.",
                    bundle: .main, comment: "plain. From your plan for a held exercise without a load.")
            }
            return LocalizedStringResource(
                "plain.progression.heldLoad", defaultValue: "\(exercise) stays at \(load), as you asked.",
                bundle: .main, comment: "plain. From your plan for a held exercise; arguments are the name and load.")
        case .percentOfMax:
            return LocalizedStringResource(
                "plain.progression.percentOfMax",
                defaultValue:
                    "\(exercise) is \(parts.percent) of your estimated max of \(parts.oneRepMax): \(parts.loadText).",
                bundle: .main,
                comment:
                    "plain. From your plan; arguments are the exercise, a percentage, the estimated max and the load.")
        case .fromEstimate:
            return LocalizedStringResource(
                "plain.progression.fromEstimate",
                defaultValue:
                    "\(exercise) starts at \(parts.loadText) today, from your estimated max of \(parts.oneRepMax).",
                bundle: .main,
                comment: "plain. From your plan; arguments are the exercise, the load and the estimated max.")
        case .steady:
            return LocalizedStringResource(
                "plain.progression.steady",
                defaultValue: "\(exercise) stays the same. This work is about quality, not more volume.", bundle: .main,
                comment: "plain. From your plan for speed, power and mobility work.")
        default:
            return LocalizedStringResource(
                "plain.progression.calibrate",
                defaultValue: "First time through: today's working sets of \(exercise) set the baseline.",
                bundle: .main, comment: "plain. From your plan when there's no history yet.")
        }
    }

    private static func load(_ reason: ProgressionReason, _ exercise: String, _ parts: Parts)
        -> LocalizedStringResource
    {
        let load = parts.load ?? ""
        let change = parts.change ?? ""
        switch reason.kind {
        case .addLoad:
            return LocalizedStringResource(
                "plain.progression.addLoad",
                defaultValue: "\(exercise) goes up \(change) since every set moved well \(parts.day).", bundle: .main,
                comment: "plain. From your plan, e.g. Back Squat goes up 2.5 kg since every set moved well on Thursday."
            )
        case .buildReps:
            return LocalizedStringResource(
                "plain.progression.buildReps",
                defaultValue: "\(exercise) stays the same. Aim for the top of the range on every set.", bundle: .main,
                comment: "plain. From your plan when a rep range wasn't topped out.")
        case .addReps:
            return LocalizedStringResource(
                "plain.progression.addReps",
                defaultValue: "\(exercise) goes up a rep since every set hit its target \(parts.day).", bundle: .main,
                comment: "plain. From your plan for reps-only work.")
        case .holdEffort:
            return LocalizedStringResource(
                "plain.progression.holdEffort",
                defaultValue: "\(exercise) stays at \(load) since the sets felt harder than planned \(parts.day).",
                bundle: .main, comment: "plain. From your plan when reps were hit above the target RPE.")
        case .rpeUp:
            return LocalizedStringResource(
                "plain.progression.rpeUp",
                defaultValue:
                    "\(exercise) goes up \(change) since the sets felt easier than planned \(parts.day): RPE \(parts.rpe) against \(parts.targetRPE).",
                bundle: .main, comment: "plain. From your plan; the last two arguments are the logged and target RPE.")
        case .rpeDown:
            return LocalizedStringResource(
                "plain.progression.rpeDown",
                defaultValue:
                    "\(exercise) comes down \(change) since the sets felt harder than planned \(parts.day): RPE \(parts.rpe) against \(parts.targetRPE).",
                bundle: .main, comment: "plain. From your plan; the last two arguments are the logged and target RPE.")
        default:
            return LocalizedStringResource(
                "plain.progression.rpeOnTarget",
                defaultValue: "\(exercise) stays at \(load) since the effort was right on target \(parts.day).",
                bundle: .main, comment: "plain. From your plan when the logged RPE matched the target.")
        }
    }

    private static func missed(_ reason: ProgressionReason, _ exercise: String, _ parts: Parts)
        -> LocalizedStringResource
    {
        switch reason.kind {
        case .retry:
            return LocalizedStringResource(
                "plain.progression.retry",
                defaultValue: "\(exercise) stays the same for another go after a missed set \(parts.day).",
                bundle: .main, comment: "plain. From your plan after one miss.")
        case .hold:
            return LocalizedStringResource(
                "plain.progression.hold",
                defaultValue:
                    "\(exercise) holds steady after missing twice in a row. It goes up again once every set lands.",
                bundle: .main, comment: "plain. From your plan after two misses in a row.")
        default:
            guard let load = parts.load else {
                return LocalizedStringResource(
                    "plain.progression.dropNoLoad",
                    defaultValue: "\(exercise) eases back about 10% after \(parts.misses) misses in a row.",
                    bundle: .main, comment: "plain. From your plan; the second argument is the number of misses.")
            }
            return LocalizedStringResource(
                "plain.progression.drop",
                defaultValue:
                    "\(exercise) comes down about 10% to \(load) after \(parts.misses) misses in a row. Build back from there.",
                bundle: .main,
                comment: "plain. From your plan; arguments are the exercise, the new load and the number of misses.")
        }
    }

    private static func volume(_ reason: ProgressionReason, _ exercise: String, _ parts: Parts)
        -> LocalizedStringResource
    {
        switch reason.kind {
        case .addDistance:
            return LocalizedStringResource(
                "plain.progression.addDistance",
                defaultValue: "\(exercise) goes up \(parts.distance) since every set was done \(parts.day).",
                bundle: .main, comment: "plain. From your plan; the second argument is a distance, e.g. 20 m.")
        case .faster:
            return LocalizedStringResource(
                "plain.progression.faster",
                defaultValue: "\(exercise) aims \(parts.seconds) s faster since you made the time \(parts.day).",
                bundle: .main, comment: "plain. From your plan; the second argument is seconds.")
        case .addRound:
            return LocalizedStringResource(
                "plain.progression.addRound",
                defaultValue: "\(exercise) adds a round since you finished them all \(parts.day).", bundle: .main,
                comment: "plain. From your plan for intervals.")
        case .shorterRest:
            return LocalizedStringResource(
                "plain.progression.shorterRest",
                defaultValue:
                    "\(exercise) gets \(parts.seconds) s less rest between rounds since you finished them all \(parts.day).",
                bundle: .main, comment: "plain. From your plan for intervals; the second argument is seconds.")
        default:
            return LocalizedStringResource(
                "plain.progression.addTime",
                defaultValue: "\(exercise) goes up \(parts.seconds) s since every set was done \(parts.day).",
                bundle: .main, comment: "plain. From your plan for timed work; the second argument is seconds.")
        }
    }
}
