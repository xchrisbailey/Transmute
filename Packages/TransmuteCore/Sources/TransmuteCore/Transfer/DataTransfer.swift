import Foundation
import SwiftData

/// Export, import and delete-all for Settings (#18). Files go in and out as `Data`, so the
/// screen only needs a file exporter and importer around these calls. The CSV calls and the
/// deletes are in extensions.
///
///     let backup = try DataTransfer.exportBackup(from: context)
///     let summary = try DataTransfer.importBackup(data, into: context)
public enum DataTransfer {
    // MARK: Export

    /// Everything in the store as a JSON backup: the profile with its bodyweights, custom
    /// exercises, plans, workouts and records. See `Backup` for the format.
    public static func exportBackup(
        from context: ModelContext, exportedAt: Date = .now, appVersion: String? = bundleVersion
    ) throws -> Data {
        try Backup(context: context, exportedAt: exportedAt, appVersion: appVersion).encoded()
    }

    // MARK: Import

    /// Merges a JSON backup into the store and saves.
    ///
    /// Plans and workouts whose `id` is already in the store are skipped whole, as are custom
    /// exercises with a known `exerciseID`. The store keeps a single profile: the backup's is
    /// added only when there is none, otherwise the existing settings stay and only bodyweights
    /// the profile doesn't have are added. Records come back as written when the store has no
    /// history yet; otherwise they're recomputed from the merged sets. A plan stays active only
    /// if the store has no active plan already.
    ///
    /// Throws `DataTransferError` for a file that isn't a readable backup, and the store's own
    /// error if saving fails. Nothing is kept when it throws.
    @discardableResult
    public static func importBackup(_ data: Data, into context: ModelContext) throws -> ImportSummary {
        let backup = try Backup(data: data)
        return try rollingBack(context) {
            var restore = BackupRestore(backup: backup, context: context)
            return try restore.run()
        }
    }

    // MARK: Helpers

    /// The running app's marketing version, e.g. "1.0".
    public static var bundleVersion: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    /// Drops unsaved changes if the import throws, so a failed import leaves the store as it was.
    static func rollingBack<Result>(_ context: ModelContext, _ work: () throws -> Result) throws -> Result {
        do {
            return try work()
        } catch {
            context.rollback()
            throw error
        }
    }
}

extension ExerciseLibrary {
    /// This library plus the custom exercises in the store.
    func addingCustomExercises(in context: ModelContext) throws -> ExerciseLibrary {
        adding(try context.fetch(FetchDescriptor<CustomExercise>()).map(LibraryExercise.init))
    }
}
