import Foundation
import OSLog
import SwiftData

/// Builds the `ModelContainer` every app and widget shares.
public enum TransmuteStore {
    public enum Kind: Sendable {
        /// The real store: in the App Group container when the app has one, and synced through
        /// the private CloudKit database when the app is signed with iCloud.
        case persistent
        /// On this device only, never synced.
        case local
        /// In memory, for previews and tests.
        case inMemory
    }

    public static let schema = Schema(versionedSchema: SchemaV1.self)

    public static func makeContainer(_ kind: Kind = .persistent) throws -> ModelContainer {
        try ModelContainer(
            for: schema, migrationPlan: TransmuteMigrationPlan.self, configurations: configuration(kind))
    }

    /// The container an app launches with. If the synced store can't open, the app still
    /// starts on a local store rather than crashing, and the failure is logged.
    public static func makeAppContainer() -> ModelContainer {
        for kind in [Kind.persistent, .local, .inMemory] {
            do {
                return try makeContainer(kind)
            } catch {
                logger.error("Couldn't open the \(String(describing: kind)) store: \(error)")
            }
        }
        preconditionFailure("Even the in-memory store failed to open.")
    }

    /// The one container an app's process uses: its windows and its App Intents (#19) read
    /// and write through this, so an intent's save shows up on screen and the synced store is
    /// only opened once.
    public static let shared = makeAppContainer()

    private static let logger = Logger(subsystem: Transmute.bundlePrefix, category: "store")

    static func configuration(_ kind: Kind) -> ModelConfiguration {
        switch kind {
        case .persistent:
            // `.automatic` syncs with the container named in the entitlements, and stays local
            // when there are none, so unsigned builds and previews still run.
            ModelConfiguration(
                "Transmute", schema: schema, groupContainer: groupContainer, cloudKitDatabase: .automatic)
        case .local:
            ModelConfiguration("Transmute", schema: schema, groupContainer: groupContainer, cloudKitDatabase: .none)
        case .inMemory:
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        }
    }

    /// The App Group when this build is entitled to it, so widgets read the same store.
    static var groupContainer: ModelConfiguration.GroupContainer {
        let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Transmute.appGroup)
        return url == nil ? .none : .identifier(Transmute.appGroup)
    }
}
