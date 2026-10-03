import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

@MainActor
struct DeleteAllTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try TransmuteStore.makeContainer(.inMemory)
    }

    private func count<Model: PersistentModel>(_ model: Model.Type, in context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<Model>())
    }

    @Test func deleteAllLeavesNothingBehind() throws {
        SampleData.insert(into: context)
        context.insert(
            CustomExercise(name: "Sled drag", category: .conditioning, pattern: .locomotion, tracking: .distanceTime))
        try RecordBook(context: context).recomputeAll()
        // A child that lost its parent still has to go.
        context.insert(LoggedSet(order: 0, weightKg: 50, reps: 5))
        try context.save()
        for model in SchemaV1.models {
            #expect(try count(model, in: context) > 0, "\(model) should start with something")
        }
        let total = try SchemaV1.models.reduce(0) { $0 + (try count($1, in: context)) }

        let deleted = try DataTransfer.deleteAll(in: context)

        #expect(deleted == total)
        let fresh = ModelContext(container)
        for model in SchemaV1.models {
            #expect(try count(model, in: fresh) == 0, "\(model) left behind")
        }
        #expect(!context.hasChanges)
        #expect(try DataTransfer.deleteAll(in: context) == 0)
    }

    @Test func aStoreCanBeFilledAgainAfterwards() throws {
        SampleData.insert(into: context)
        try context.save()
        let backup = try DataTransfer.exportBackup(from: context)

        try DataTransfer.deleteAll(in: context)
        let summary = try DataTransfer.importBackup(backup, into: context)

        #expect(summary.profile == .added)
        #expect(try context.fetchCount(FetchDescriptor<Workout>()) == 9)
    }

    /// Test builds have no iCloud entitlement, so this must answer without making a `CKContainer`.
    @Test func cloudDeletionStandsDownWithoutSync() async throws {
        #expect(DataTransfer.cloudContainerIdentifier(of: container) == nil)
        #expect(await DataTransfer.deleteCloudRecords(for: container) == .notSyncing)
    }
}
