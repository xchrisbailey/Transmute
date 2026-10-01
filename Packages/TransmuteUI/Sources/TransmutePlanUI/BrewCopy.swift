import Foundation

/// Strings for brewing and reading a plan (#9, #10). Voice for brewing; plain for the
/// disclaimer, errors and numbers (#3).
public enum BrewCopy {
    public static let intro = LocalizedStringResource(
        "voice.brew.intro",
        defaultValue:
            "Transmute distils your profile into a plan, one day at a time, with Apple Intelligence on this device.",
        bundle: .main,
        comment: "voice. Brew screen intro.")

    public static let disclaimer = LocalizedStringResource(
        "plain.brew.disclaimer",
        defaultValue:
            "Plans are general training, not medical advice. Stop if something hurts, and check with a professional about injuries.",
        bundle: .main,
        comment: "plain. Short disclaimer on the brew screen.")

    public static let outlining = LocalizedStringResource(
        "voice.brew.outlining", defaultValue: "Sketching the plan…", bundle: .main,
        comment: "voice. Shown while the blueprint is generated.")

    public static func distillingDay(_ focus: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "voice.brew.distillingDay", defaultValue: "Distilling \(focus)…", bundle: .main,
            comment: "voice. Shown while one day is generated, e.g. Distilling Lower strength…")
    }

    public static let keep = LocalizedStringResource(
        "voice.brew.keep", defaultValue: "Keep this plan", bundle: .main,
        comment: "voice. Accept a freshly brewed plan.")

    public static let brewAgain = LocalizedStringResource(
        "voice.brew.again", defaultValue: "Brew again", bundle: .main,
        comment: "voice. Throw away the preview and brew a new one.")

    public static let replacesActive = LocalizedStringResource(
        "plain.brew.replacesActive",
        defaultValue: "Your current plan is kept in history, with everything you've logged.", bundle: .main,
        comment: "plain. Note when a new plan will replace the active one.")

    public static func week(_ week: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.week", defaultValue: "Week \(week)", bundle: .main,
            comment: "plain. Week heading.")
    }

    public static func weeks(_ first: Int, _ last: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.weekRange", defaultValue: "Weeks \(first)–\(last)", bundle: .main,
            comment: "plain. Phase week range, e.g. Weeks 1–3.")
    }

    public static func minutes(_ minutes: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.minutesShort", defaultValue: "About \(minutes) min", bundle: .main,
            comment: "plain. Estimated session length.")
    }

    public static func exercisesCount(_ count: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.exerciseCount", defaultValue: "\(count) exercises", bundle: .main,
            comment: "plain. Number of exercises in a day.")
    }

    public static let deload = LocalizedStringResource(
        "plain.deload", defaultValue: "Lighter week", bundle: .main,
        comment: "plain. Badge on a deload week.")

    public static func profileSummary(_ days: Int, _ minutes: Int, _ weeks: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.brew.profileSummary", defaultValue: "\(days) days a week · \(minutes) min · \(weeks) weeks",
            bundle: .main,
            comment: "plain. Schedule summary on the brew screen.")
    }

    public static let editProfile = LocalizedStringResource(
        "plain.brew.editProfile", defaultValue: "Change profile", bundle: .main,
        comment: "plain. Link to the profile from the brew screen.")

    public static let phases = LocalizedStringResource(
        "plain.phases", defaultValue: "Phases", bundle: .main,
        comment: "plain. Phase bar heading.")

    public static let activePlan = LocalizedStringResource(
        "plain.activePlan", defaultValue: "Your plan", bundle: .main,
        comment: "plain. Title of the active plan screen.")
}
