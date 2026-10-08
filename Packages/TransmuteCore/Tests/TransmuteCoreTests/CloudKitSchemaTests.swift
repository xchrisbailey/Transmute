#if DEBUG
    import CoreData
    import SwiftData
    import Testing

    @testable import TransmuteCore

    struct CloudKitSchemaTests {
        /// `-initCloudKitSchema` pushes this model to CloudKit, so a model it left out would
        /// have no record type in Production. This needs no CloudKit and no entitlements.
        @Test func theSchemaModelCoversEveryModelInTheSchema() throws {
            let model = try TransmuteStore.cloudKitSchemaModel()
            let schemaNames = Set(TransmuteStore.schema.entities.map(\.name))
            #expect(!schemaNames.isEmpty)
            #expect(Set(model.entitiesByName.keys) == schemaNames)
        }
    }
#endif
