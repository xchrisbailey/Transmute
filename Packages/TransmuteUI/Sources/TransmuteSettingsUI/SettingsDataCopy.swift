import Foundation

/// Strings for privacy, export, import and delete-all in Settings (#18). All plain.
enum SettingsDataCopy {
    static let privacy = LocalizedStringResource(
        "plain.settings.privacy.statement",
        defaultValue: """
            Transmute has no analytics, no ads and no code from other companies. Your data stays on your devices and \
            in your own iCloud. Crash reports reach the developer only through Apple, and only if you've chosen to \
            share them in the device's Settings.
            """,
        bundle: .main, comment: "plain. The privacy statement.")

    static let export = LocalizedStringResource(
        "plain.settings.export.title",
        defaultValue: "Export",
        bundle: .main, comment: "plain. Section heading.")

    static let exportCSV = LocalizedStringResource(
        "plain.settings.export.csv",
        defaultValue: "Export workouts as CSV",
        bundle: .main, comment: "plain. Button.")

    static let exportBackup = LocalizedStringResource(
        "plain.settings.export.backup",
        defaultValue: "Export a full backup",
        bundle: .main, comment: "plain. Button.")

    static let exportNote = LocalizedStringResource(
        "plain.settings.export.note",
        defaultValue: """
            CSV is a table with one row per set, which opens in any spreadsheet. The backup is a JSON file with \
            everything: profile, plans, workouts and records. It can be imported back into Transmute.
            """,
        bundle: .main, comment: "plain. Footer under the export buttons.")

    static let exportSaved = LocalizedStringResource(
        "plain.settings.export.saved",
        defaultValue: "Saved.",
        bundle: .main, comment: "plain. Shown after an export was saved.")

    static let exportFailed = LocalizedStringResource(
        "plain.settings.export.failed",
        defaultValue: "Couldn't make the file. Nothing was saved.",
        bundle: .main, comment: "plain. Export failed.")

    static let importTitle = LocalizedStringResource(
        "plain.settings.import.title",
        defaultValue: "Import",
        bundle: .main, comment: "plain. Section heading.")

    static let importFile = LocalizedStringResource(
        "plain.settings.import.file",
        defaultValue: "Import a file",
        bundle: .main, comment: "plain. Button: pick a backup or a CSV export to import.")

    static let importNote = LocalizedStringResource(
        "plain.settings.import.note",
        defaultValue: """
            Choose a Transmute backup, or a CSV export from Strong or Hevy. Anything already in Transmute is \
            skipped, so importing a file twice is safe. If a file doesn't say kg or lb, your weight unit is used.
            """,
        bundle: .main, comment: "plain. Footer under the import button.")

    static let importDone = LocalizedStringResource(
        "plain.settings.import.done",
        defaultValue: "Import finished",
        bundle: .main, comment: "plain. Heading of the result of an import that added something.")

    static let importNothingNew = LocalizedStringResource(
        "plain.settings.import.nothingNew",
        defaultValue: "Nothing new to import",
        bundle: .main, comment: "plain. Heading of the result of an import that added nothing.")

    static let importAllThere = LocalizedStringResource(
        "plain.settings.import.allThere",
        defaultValue: "Everything in this file is already in Transmute.",
        bundle: .main, comment: "plain. Result line when an import added nothing.")

    static let importFromBackup = LocalizedStringResource(
        "plain.settings.import.fromBackup",
        defaultValue: "From a Transmute backup.",
        bundle: .main, comment: "plain. Result line: where the import came from.")

    static let importFromStrong = LocalizedStringResource(
        "plain.settings.import.fromStrong",
        defaultValue: "From a Strong export.",
        bundle: .main, comment: "plain. Result line: where the import came from.")

    static let importFromHevy = LocalizedStringResource(
        "plain.settings.import.fromHevy",
        defaultValue: "From a Hevy export.",
        bundle: .main, comment: "plain. Result line: where the import came from.")

    static func workoutsAdded(_ count: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.settings.import.workoutsAdded",
            defaultValue: "Workouts added: \(count)",
            bundle: .main, comment: "plain. Result line.")
    }

    static func workoutsSkipped(_ count: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.settings.import.workoutsSkipped",
            defaultValue: "Workouts already here, skipped: \(count)",
            bundle: .main, comment: "plain. Result line.")
    }

    static func setsAdded(_ count: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.settings.import.setsAdded",
            defaultValue: "Sets added: \(count)",
            bundle: .main, comment: "plain. Result line.")
    }

    static func plansAdded(_ count: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.settings.import.plansAdded",
            defaultValue: "Plans added: \(count)",
            bundle: .main, comment: "plain. Result line.")
    }

    static func plansSkipped(_ count: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.settings.import.plansSkipped",
            defaultValue: "Plans already here, skipped: \(count)",
            bundle: .main, comment: "plain. Result line.")
    }

    static func bodyweightsAdded(_ count: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.settings.import.bodyweightsAdded",
            defaultValue: "Bodyweight entries added: \(count)",
            bundle: .main, comment: "plain. Result line.")
    }

    static func recordsAdded(_ count: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.settings.import.recordsAdded",
            defaultValue: "Records added: \(count)",
            bundle: .main, comment: "plain. Result line.")
    }

    static func customExercisesAdded(_ count: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.settings.import.customExercisesAdded",
            defaultValue: "Your own exercises added: \(count)",
            bundle: .main, comment: "plain. Result line: custom exercises restored from a backup.")
    }

    static let profileAdded = LocalizedStringResource(
        "plain.settings.import.profileAdded",
        defaultValue: "Your profile was restored.",
        bundle: .main, comment: "plain. Result line.")

    static let profileKept = LocalizedStringResource(
        "plain.settings.import.profileKept",
        defaultValue: "The profile already here was kept as it is.",
        bundle: .main, comment: "plain. Result line.")

    static func unmatchedNames(_ names: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.settings.import.unmatchedNames",
            defaultValue: """
                These exercise names aren't in Transmute's library, so they were added as your own exercises: \
                \(names).
                """,
            bundle: .main, comment: "plain. Result line; the argument is a list of exercise names.")
    }

    static func unreadableRows(_ count: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.settings.import.unreadableRows",
            defaultValue: "Rows that couldn't be read and were left out: \(count)",
            bundle: .main, comment: "plain. Result line.")
    }

    static let importFailed = LocalizedStringResource(
        "plain.settings.import.failed",
        defaultValue: "Import didn't work",
        bundle: .main, comment: "plain. Heading of a failed import.")

    static let errorEmptyFile = LocalizedStringResource(
        "plain.settings.import.error.emptyFile",
        defaultValue: "That file is empty. Nothing was changed.",
        bundle: .main, comment: "plain. Import error.")

    static let errorUnreadableBackup = LocalizedStringResource(
        "plain.settings.import.error.unreadableBackup",
        defaultValue: "That file isn't a Transmute backup, or it's damaged. Nothing was changed.",
        bundle: .main, comment: "plain. Import error.")

    static let errorNewerBackup = LocalizedStringResource(
        "plain.settings.import.error.newerBackup",
        defaultValue: """
            That backup was made by a newer version of Transmute. Update Transmute, then import it again. Nothing \
            was changed.
            """,
        bundle: .main, comment: "plain. Import error.")

    static let errorUnrecognizedCSV = LocalizedStringResource(
        "plain.settings.import.error.unrecognizedCSV",
        defaultValue: "That file doesn't look like a CSV export from Strong or Hevy. Nothing was changed.",
        bundle: .main, comment: "plain. Import error.")

    static let errorCantOpen = LocalizedStringResource(
        "plain.settings.import.error.cantOpen",
        defaultValue: "Couldn't open that file. Nothing was changed.",
        bundle: .main, comment: "plain. Import error: the file couldn't be read from disk.")

    static let errorCantSave = LocalizedStringResource(
        "plain.settings.import.error.cantSave",
        defaultValue: "Couldn't save the import. Nothing was changed.",
        bundle: .main, comment: "plain. Import error: saving to the store failed.")

    static let deleteTitle = LocalizedStringResource(
        "plain.settings.delete.title",
        defaultValue: "Delete",
        bundle: .main, comment: "plain. Section heading.")

    static let deleteAll = LocalizedStringResource(
        "plain.settings.delete.all",
        defaultValue: "Delete all data…",
        bundle: .main, comment: "plain. Destructive button; opens a confirmation.")

    static let deleteNote = LocalizedStringResource(
        "plain.settings.delete.note",
        defaultValue: """
            Removes everything you've put into Transmute, here and in iCloud. Export a backup first if you might \
            want it back.
            """,
        bundle: .main, comment: "plain. Footer under the delete button.")

    static let deleteConfirmTitle = LocalizedStringResource(
        "plain.settings.delete.confirmTitle",
        defaultValue: "Delete everything?",
        bundle: .main, comment: "plain. Title of the delete-all confirmation.")

    static let deleteConfirmMessage = LocalizedStringResource(
        "plain.settings.delete.confirmMessage",
        defaultValue: """
            This deletes your profile, plans, workouts and records from this device and from iCloud, which removes \
            them from your other devices too. It can't be undone.
            """,
        bundle: .main, comment: "plain. Message of the delete-all confirmation.")

    static let deleteConfirm = LocalizedStringResource(
        "plain.settings.delete.confirm",
        defaultValue: "Delete everything, here and in iCloud",
        bundle: .main, comment: "plain. Destructive button in the delete-all confirmation.")

    static let cancel = LocalizedStringResource(
        "plain.settings.cancel",
        defaultValue: "Cancel",
        bundle: .main, comment: "plain. Button.")

    static let deleting = LocalizedStringResource(
        "plain.settings.delete.deleting",
        defaultValue: "Deleting…",
        bundle: .main, comment: "plain. Shown while delete-all runs.")

    static let deleteFailed = LocalizedStringResource(
        "plain.settings.delete.failed",
        defaultValue: "Couldn't delete. Nothing was removed.",
        bundle: .main, comment: "plain. Delete-all failed on this device.")

    static let erasedEverywhere = LocalizedStringResource(
        "plain.settings.erased.everywhere",
        defaultValue: "Everything was deleted from this device and from iCloud.",
        bundle: .main, comment: "plain. Report after delete-all.")

    static let erasedLocalOnly = LocalizedStringResource(
        "plain.settings.erased.localOnly",
        defaultValue: """
            Everything was deleted from this device. This copy of Transmute doesn't sync with iCloud, so there was \
            nothing to delete there.
            """,
        bundle: .main, comment: "plain. Report after delete-all in a build that doesn't sync.")

    static let erasedCloudFailed = LocalizedStringResource(
        "plain.settings.erased.cloudFailed",
        defaultValue: """
            Everything was deleted from this device, but iCloud couldn't be reached. A copy may still be in iCloud. \
            Check your connection and try again.
            """,
        bundle: .main, comment: "plain. Report after delete-all when the iCloud step failed.")

    static let erasedRetry = LocalizedStringResource(
        "plain.settings.erased.retry",
        defaultValue: "Try iCloud again",
        bundle: .main, comment: "plain. Button: retry deleting from iCloud.")

    static let erasedDismiss = LocalizedStringResource(
        "plain.settings.erased.dismiss",
        defaultValue: "OK",
        bundle: .main, comment: "plain. Button: dismiss the report after delete-all.")
}
