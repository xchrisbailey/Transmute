#if DEBUG && canImport(CloudKit)
    import CloudKit
    import CoreData
    import Foundation
    import OSLog
    import SwiftData

    private let logger = Logger(subsystem: Transmute.bundlePrefix, category: "store")

    enum CloudKitSchemaError: Error, LocalizedError {
        case noModel
        case notSignedForICloud

        var errorDescription: String? {
            switch self {
            case .noModel: "Core Data couldn't build a model from the schema's types"
            case .notSignedForICloud:
                "this build isn't signed with the iCloud entitlement, or its synced store didn't open"
            }
        }
    }

    extension TransmuteStore {
        /// The managed object model for every model in the current schema, which is what
        /// CloudKit's schema is derived from.
        static func cloudKitSchemaModel() throws -> NSManagedObjectModel {
            guard let model = NSManagedObjectModel.makeManagedObjectModel(for: SchemaV1.models) else {
                throw CloudKitSchemaError.noModel
            }
            return model
        }

        /// Creates every record type and field of the current schema in CloudKit's Development
        /// environment, and returns how many entities it covered.
        ///
        /// SwiftData builds the Development schema just in time, from records that hold a value,
        /// so a field nobody has filled yet is missing there, and from Production once deployed. This
        /// pushes the whole schema in one go. It loads the model into a throwaway store in a
        /// temporary directory, so the app's own store is never touched.
        ///
        /// Throws instead of touching CloudKit when this build isn't entitled to it, because
        /// making a CloudKit container without the entitlement crashes.
        ///
        /// Needs an iCloud account, the iCloud entitlement and a network connection.
        @discardableResult
        public static func initializeCloudKitSchema() throws -> Int {
            guard DataTransfer.cloudContainerIdentifier(of: shared) != nil else {
                throw CloudKitSchemaError.notSignedForICloud
            }
            let model = try cloudKitSchemaModel()
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("TransmuteCloudKitSchema-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }

            let description = NSPersistentStoreDescription(url: directory.appendingPathComponent("Schema.sqlite"))
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: Transmute.cloudKitContainer)
            description.shouldAddStoreAsynchronously = false

            var failure: Error?
            autoreleasepool {
                let container = NSPersistentCloudKitContainer(name: "Transmute", managedObjectModel: model)
                container.persistentStoreDescriptions = [description]
                container.loadPersistentStores { _, error in
                    if let error { failure = error }
                }
                guard failure == nil else { return }
                do {
                    try container.initializeCloudKitSchema()
                } catch {
                    failure = error
                }
                // Detach the store so the file can be removed and nothing keeps syncing.
                for store in container.persistentStoreCoordinator.persistentStores {
                    try? container.persistentStoreCoordinator.remove(store)
                }
            }
            if let failure { throw failure }
            return model.entities.count
        }

        /// Runs `initializeCloudKitSchema()` for the `-initCloudKitSchema` launch argument,
        /// logs and prints the outcome, and never throws: the app carries on launching.
        public static func initializeCloudKitSchemaForLaunch() {
            let line: String
            do {
                let count = try initializeCloudKitSchema()
                line = "CloudKit schema: initialized \(count) entities in \(Transmute.cloudKitContainer) (Development)."
                logger.info("\(line)")
            } catch {
                line = "CloudKit schema: failed, \(error.localizedDescription)"
                logger.error("\(line) (\(error))")
            }
            print(line)
        }
    }
#endif
