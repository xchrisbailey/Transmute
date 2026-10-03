import Foundation
import SwiftData

#if canImport(CloudKit)
    import CloudKit
#endif

/// What became of asking iCloud to drop Transmute's records.
public enum CloudErasure: Equatable, Sendable {
    /// The records are gone from the private database, or there were none.
    case deleted
    /// This build doesn't sync with iCloud, so there was nothing to ask.
    case notSyncing
    /// iCloud couldn't be reached or refused. The detail is for logs, not for people.
    case failed(detail: String)
}

extension DataTransfer {
    /// Deletes every object of every model and saves, so the deletions sync to iCloud like any
    /// other change. Returns how many objects went.
    ///
    /// Transmute keeps no user data outside the store: its user defaults hold only view state
    /// and the AI route, so there's nothing else to clear here.
    @discardableResult
    public static func deleteAll(in context: ModelContext) throws -> Int {
        let models = TransmuteMigrationPlan.schemas.last?.models ?? []
        let count = try models.reduce(0) { try $0 + count($1, in: context) }
        for model in models {
            try deleteEvery(model, in: context)
        }
        try context.save()
        return count
    }

    private static func count<Model: PersistentModel>(_ model: Model.Type, in context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<Model>())
    }

    /// Deletes object by object rather than in a batch, so cascades run and sync sees each one.
    private static func deleteEvery<Model: PersistentModel>(_ model: Model.Type, in context: ModelContext) throws {
        for object in try context.fetch(FetchDescriptor<Model>()) where !object.isDeleted {
            context.delete(object)
        }
    }

    /// The zone SwiftData mirrors the store into.
    static let cloudZoneName = "com.apple.coredata.cloudkit.zone"

    /// Removes Transmute's records from the person's private iCloud database directly, for when
    /// sync is off or behind. Call it after `deleteAll(in:)`, which is what empties the other
    /// devices: deleting the zone alone doesn't tell them to delete, and a device that still
    /// holds data may upload it again when it next syncs.
    ///
    /// Never throws and never touches CloudKit unless the container is syncing, because making
    /// a `CKContainer` without the iCloud entitlement crashes.
    public static func deleteCloudRecords(for container: ModelContainer) async -> CloudErasure {
        #if canImport(CloudKit)
            guard let identifier = cloudContainerIdentifier(of: container) else { return .notSyncing }
            let database = CKContainer(identifier: identifier).privateCloudDatabase
            let zone = CKRecordZone.ID(zoneName: cloudZoneName, ownerName: CKCurrentUserDefaultName)
            do {
                _ = try await database.deleteRecordZone(withID: zone)
                return .deleted
            } catch let error as CKError where error.code == .zoneNotFound {
                return .deleted
            } catch {
                return .failed(detail: String(describing: error))
            }
        #else
            return .notSyncing
        #endif
    }

    /// The CloudKit container the store syncs with. `nil` for local and in-memory stores, and
    /// for the synced configuration in a build without the iCloud entitlement.
    static func cloudContainerIdentifier(of container: ModelContainer) -> String? {
        container.configurations.lazy.compactMap(\.cloudKitContainerIdentifier).first
    }
}
