import Foundation
import TransmuteCore

/// What an import did, in plain words for the screen (#18): a heading and one line per thing
/// worth saying. Counts of zero are left out.
struct ImportReport: Equatable {
    var succeeded: Bool
    var heading: LocalizedStringResource
    var lines: [LocalizedStringResource]

    init(_ summary: ImportSummary) {
        succeeded = true
        heading = summary.addedAnything ? SettingsDataCopy.importDone : SettingsDataCopy.importNothingNew
        var lines = [Self.source(summary.source)]
        if !summary.addedAnything { lines.append(SettingsDataCopy.importAllThere) }
        switch summary.profile {
        case .added: lines.append(SettingsDataCopy.profileAdded)
        case .kept: lines.append(SettingsDataCopy.profileKept)
        case .absent: break
        }
        let counts: [(Int, (Int) -> LocalizedStringResource)] = [
            (summary.workouts.added, SettingsDataCopy.workoutsAdded),
            (summary.setsAdded, SettingsDataCopy.setsAdded),
            (summary.workouts.skipped, SettingsDataCopy.workoutsSkipped),
            (summary.plans.added, SettingsDataCopy.plansAdded),
            (summary.plans.skipped, SettingsDataCopy.plansSkipped),
            (summary.bodyweights.added, SettingsDataCopy.bodyweightsAdded),
            (summary.recordsAdded, SettingsDataCopy.recordsAdded),
        ]
        lines += counts.filter { $0.0 > 0 }.map { $0.1($0.0) }
        // A CSV names the exercises it had to add; a backup only has a count.
        if !summary.unmatchedExerciseNames.isEmpty {
            lines.append(SettingsDataCopy.unmatchedNames(summary.unmatchedExerciseNames.formatted(.list(type: .and))))
        } else if summary.customExercises.added > 0 {
            lines.append(SettingsDataCopy.customExercisesAdded(summary.customExercises.added))
        }
        if summary.unreadableRows > 0 {
            lines.append(SettingsDataCopy.unreadableRows(summary.unreadableRows))
        }
        self.lines = lines
    }

    /// A failed import. Every case says that nothing was changed, which the importers promise.
    init(_ error: any Error) {
        succeeded = false
        heading = SettingsDataCopy.importFailed
        lines = [Self.message(for: error)]
    }

    static func source(_ source: ImportSummary.Source) -> LocalizedStringResource {
        switch source {
        case .backup: SettingsDataCopy.importFromBackup
        case .strong: SettingsDataCopy.importFromStrong
        case .hevy: SettingsDataCopy.importFromHevy
        }
    }

    static func message(for error: any Error) -> LocalizedStringResource {
        switch error {
        case DataTransferError.emptyFile: SettingsDataCopy.errorEmptyFile
        case DataTransferError.unreadableBackup: SettingsDataCopy.errorUnreadableBackup
        case DataTransferError.newerBackup: SettingsDataCopy.errorNewerBackup
        case DataTransferError.unrecognizedCSV: SettingsDataCopy.errorUnrecognizedCSV
        case ImportFailure.cantOpen: SettingsDataCopy.errorCantOpen
        // Anything else came from saving to the store.
        default: SettingsDataCopy.errorCantSave
        }
    }

    /// The whole report as one string, for VoiceOver to announce.
    var spoken: String {
        ([heading] + lines).map { String(localized: $0) }.joined(separator: " ")
    }
}
