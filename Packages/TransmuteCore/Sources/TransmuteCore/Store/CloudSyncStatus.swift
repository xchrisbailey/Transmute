import Foundation
import SwiftData

#if canImport(CloudKit)
    import CloudKit
#endif

/// Whether the store is syncing with iCloud, as far as the app can tell, for Settings (#18).
public enum CloudSyncStatus: Equatable, Sendable {
    /// This build doesn't sync: it isn't signed for iCloud, or the synced store couldn't open.
    case notSyncing
    /// The build syncs and the device is signed in to iCloud.
    case available
    /// The build syncs, but nobody is signed in to iCloud on this device.
    case signedOut
    /// iCloud is blocked on this device, by Screen Time or a management profile.
    case restricted
    /// Signed in, but iCloud isn't ready yet. Sync resumes on its own.
    case temporarilyUnavailable
    /// The account couldn't be checked.
    case unknown
}

extension TransmuteStore {
    /// Whether this container syncs, and if it does, the state of the iCloud account.
    ///
    /// Never touches CloudKit unless the container is syncing, because making a `CKContainer`
    /// without the iCloud entitlement crashes.
    public static func cloudSyncStatus(of container: ModelContainer) async -> CloudSyncStatus {
        #if canImport(CloudKit)
            guard let identifier = DataTransfer.cloudContainerIdentifier(of: container) else { return .notSyncing }
            guard let status = try? await CKContainer(identifier: identifier).accountStatus() else { return .unknown }
            return CloudSyncStatus(status)
        #else
            return .notSyncing
        #endif
    }
}

#if canImport(CloudKit)
    extension CloudSyncStatus {
        init(_ status: CKAccountStatus) {
            switch status {
            case .available: self = .available
            case .noAccount: self = .signedOut
            case .restricted: self = .restricted
            case .temporarilyUnavailable: self = .temporarilyUnavailable
            case .couldNotDetermine: self = .unknown
            @unknown default: self = .unknown
            }
        }
    }
#endif
