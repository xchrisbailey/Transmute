import Foundation

/// Strings for training reminders (#19). All plain, and never about what was missed: the plan
/// is simply still there (#22).
enum ReminderCopy {
    // MARK: Settings

    static let title = LocalizedStringResource(
        "plain.reminders.title", defaultValue: "Reminders", bundle: .main,
        comment: "plain. Heading of the reminder settings.")

    static let trainingDay = LocalizedStringResource(
        "plain.reminders.trainingDay", defaultValue: "Remind me on training days", bundle: .main,
        comment: "plain. Switch for a notification on each day the plan has a session.")

    static let trainingDayDetail = LocalizedStringResource(
        "plain.reminders.trainingDay.detail", defaultValue: "A notification on each day your plan has a session.",
        bundle: .main, comment: "plain. Under the training day reminder switch.")

    static let time = LocalizedStringResource(
        "plain.reminders.time", defaultValue: "Reminder time", bundle: .main,
        comment: "plain. Label of the picker for the time of day the training day reminder comes.")

    static let missedDay = LocalizedStringResource(
        "plain.reminders.missedDay", defaultValue: "Nudge me after a missed day", bundle: .main,
        comment: "plain. Switch for a notification the morning after a planned day with no workout.")

    static let missedDayDetail = LocalizedStringResource(
        "plain.reminders.missedDay.detail",
        defaultValue: "One gentle note the next morning when a planned session wasn't logged. Never more than one.",
        bundle: .main, comment: "plain. Under the missed day nudge switch.")

    static let footer = LocalizedStringResource(
        "plain.reminders.footer",
        defaultValue: "Reminders are set for this device only. Your Apple Watch shows the ones from your iPhone.",
        bundle: .main, comment: "plain. Under the reminder settings.")

    static let denied = LocalizedStringResource(
        "plain.reminders.denied",
        defaultValue:
            "Notifications are turned off for Transmute, so these reminders can't be shown. You can turn them on in Settings.",
        bundle: .main, comment: "plain. A reminder is on but the system doesn't allow Transmute's notifications.")

    static let openSettings = LocalizedStringResource(
        "plain.reminders.openSettings", defaultValue: "Open notification settings", bundle: .main,
        comment: "plain. Button that opens the system's notification settings for Transmute.")

    // MARK: Notifications

    static func trainingDayTitle(_ session: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.reminders.notification.trainingDay.title", defaultValue: "Today: \(session)", bundle: .main,
            comment: "plain. Title of the training day notification, e.g. Today: Lower A.")
    }

    static let trainingDayUntitled = LocalizedStringResource(
        "plain.reminders.notification.trainingDay.untitled", defaultValue: "Training day", bundle: .main,
        comment: "plain. Title of the training day notification when the session has no name.")

    static let trainingDayBody = LocalizedStringResource(
        "plain.reminders.notification.trainingDay.body", defaultValue: "Your session is ready when you are.",
        bundle: .main, comment: "plain. Body of the training day notification.")

    static let missedDayTitle = LocalizedStringResource(
        "plain.reminders.notification.missedDay.title", defaultValue: "Still here when you're ready", bundle: .main,
        comment: "plain. Title of the nudge after a planned day with no workout. Kind, never blaming.")

    static let missedDayBody = LocalizedStringResource(
        "plain.reminders.notification.missedDay.body",
        defaultValue: "Your plan carries on from wherever you are. There's nothing to catch up on.", bundle: .main,
        comment: "plain. Body of the nudge after a planned day with no workout. Kind, never blaming.")
}
