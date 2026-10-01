import Foundation

/// Every brand string, looked up in the app's `Localizable.xcstrings`.
///
/// "Voice" strings use the alchemy verbs; "plain" strings stay literal: mid-set, on the
/// watch, errors, deletes and Health prompts. Each key's catalog comment says which.
public enum Copy {
    public static let brewPlan = LocalizedStringResource(
        "voice.brewPlan", defaultValue: "Brew a plan", bundle: .main, comment: "voice. Generate a plan.")

    public static func distilling(week: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "voice.distilling", defaultValue: "Distilling week \(week)…", bundle: .main,
            comment: "voice. Shown while the AI generates a plan, one week at a time.")
    }

    public static let rebrew = LocalizedStringResource(
        "voice.rebrew", defaultValue: "Rebrew", bundle: .main, comment: "voice. Regenerate the whole plan.")

    public static let reworkDay = LocalizedStringResource(
        "voice.reworkDay", defaultValue: "Rework this day", bundle: .main, comment: "voice. Edit one day with AI.")

    public static func whyThisPlan(_ reason: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "voice.whyThisPlan", defaultValue: "Why this plan: \(reason)", bundle: .main,
            comment: "voice. Plan rationale card; the argument is one sentence from the AI.")
    }

    public static func brewedOn(device: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "voice.brewedOn", defaultValue: "Brewed on this \(device) with Apple Intelligence", bundle: .main,
            comment: "voice. Under a generated plan; the argument is iPhone or Mac.")
    }

    public static let beginWork = LocalizedStringResource(
        "voice.beginWork", defaultValue: "Begin the work", bundle: .main, comment: "voice. Start a workout.")

    public static let logSet = LocalizedStringResource(
        "plain.logSet", defaultValue: "Log set", bundle: .main, comment: "plain. Log a set, mid-workout.")

    public static func rest(_ remaining: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.rest", defaultValue: "Rest \(remaining)", bundle: .main,
            comment: "plain. Rest timer; the argument is the time left, e.g. 1:48.")
    }

    public static func gold(exercise: String, record: String, value: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "voice.gold", defaultValue: "Gold. \(exercise) \(record), \(value).", bundle: .main,
            comment: "voice. A new personal record, e.g. Gold. Squat 5RM, 115 kg.")
    }

    public static func workDone(sets: Int, moved: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "voice.workDone", defaultValue: "The work is done. \(sets) sets, \(moved) moved.", bundle: .main,
            comment: "voice. Workout finished; the second argument is total volume, e.g. 8,420 kg.")
    }

    public static let weekDistilled = LocalizedStringResource(
        "voice.weekDistilled", defaultValue: "This week, distilled", bundle: .main,
        comment: "voice. Title of the weekly summary.")

    public static func streak(weeks: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "voice.streak", defaultValue: "The fire's lit · \(weeks) weeks", bundle: .main,
            comment: "voice. Training streak in weeks.")
    }

    public static let emptyLog = LocalizedStringResource(
        "voice.emptyLog", defaultValue: "The crucible's empty. Brew a plan to begin.", bundle: .main,
        comment: "voice. Empty workout log.")

    public static func deleteWorkout(_ name: String, date: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.deleteWorkout", defaultValue: "Delete \(name) from \(date)? This can't be undone.", bundle: .main,
            comment: "plain. Confirm deleting a workout, e.g. Delete Lower A from Sep 28?")
    }

    public static let healthAccess = LocalizedStringResource(
        "plain.healthAccess",
        defaultValue: "Transmute reads heart rate and bodyweight from Health to adjust your plan.", bundle: .main,
        comment: "plain. Explains Health access before the system prompt.")

    public static let aiUnavailable = LocalizedStringResource(
        "plain.aiUnavailable",
        defaultValue: "Plans need Apple Intelligence, which is off. Turn it on in Settings. Logging works without it.",
        bundle: .main, comment: "plain. Apple Intelligence is turned off.")

    public static let savePlanError = LocalizedStringResource(
        "plain.savePlanError", defaultValue: "Couldn't save the plan. Your sets are still saved on this device.",
        bundle: .main, comment: "plain. Saving a plan failed.")

    public static func about(version: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "voice.about", defaultValue: "Transmute \(version), forged at srcery.computer", bundle: .main,
            comment: "voice. About screen; the argument is the app version.")
    }
}
