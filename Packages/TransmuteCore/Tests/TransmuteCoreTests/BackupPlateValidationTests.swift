import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

/// A backup is a file anyone can edit, and the setup screen takes any weight above zero. A restore
/// never throws away a person's kit: it drops a plate row whose weight can't be real, resets a bar or
/// step that can't be real to the preset's value in the file's own unit, caps pairs at what the
/// screen offers, and keeps everything else as written. Either way the kit never reaches the plate
/// maths, where it would trap.
struct BackupPlateValidationTests {
    /// A kit edit, the kit the restore should leave from it, and whether the report should say a
    /// setting was repaired.
    struct BadKit: Sendable, CustomTestStringConvertible {
        let name: String
        let repaired: Bool
        let edit: @Sendable (inout [String: Any]) -> Void
        let expected: @Sendable (PlateInventory) -> PlateInventory
        var testDescription: String { name }
    }

    static func rows(_ rows: [(kg: Double, pairs: Int)]) -> [[String: Any]] {
        rows.map { ["kg": $0.kg, "pairs": NSNumber(value: $0.pairs)] }
    }

    static func plates(_ rows: [(kg: Double, pairs: Int)]) -> [PlateInventory.Plate] {
        rows.map { .init(kg: $0.kg, pairs: $0.pairs) }
    }

    /// The expected kit when only the plate rows differ from the fixture's.
    static func keeping(plates rows: [PlateInventory.Plate]) -> @Sendable (PlateInventory) -> PlateInventory {
        { kit in
            var kit = kit
            kit.plates = rows
            return kit
        }
    }

    /// The fixture's kit is in pounds, so the preset values a reset field falls back to are too.
    static let preset = PlateInventory(.commercialGym, system: .imperial)

    static let badKits: [BadKit] = [
        .init(
            name: "a negative row among good ones", repaired: true,
            edit: { $0["plates"] = rows([(20, 3), (20, -1), (10, 2)]) },
            expected: keeping(plates: Self.plates([(20, 3), (10, 2)]))),
        .init(
            name: "a negative row cancelling a good one", repaired: true,
            edit: { $0["plates"] = rows([(20, 1), (20, -1)]) },
            expected: keeping(plates: Self.plates([(20, 1)]))),
        .init(
            name: "a negative row on its own", repaired: true,
            edit: { $0["plates"] = rows([(15, -4)]) },
            expected: keeping(plates: Self.plates([(15, 0)]))),
        .init(
            name: "pairs that overflow when rows of one weight merge", repaired: false,
            edit: { $0["plates"] = rows([(20, Int.max), (20, 1)]) },
            expected: keeping(plates: Self.plates([(20, PlateInventory.mostPairsPerPlate)]))),
        .init(
            name: "one pair more than the setup screen offers", repaired: false,
            edit: { $0["plates"] = rows([(20, PlateInventory.mostPairsPerPlate + 1)]) },
            expected: keeping(plates: Self.plates([(20, PlateInventory.mostPairsPerPlate)]))),
        .init(
            name: "more pairs than anyone owns", repaired: false,
            edit: { $0["plates"] = rows([(20, 1_000_000)]) },
            expected: keeping(plates: Self.plates([(20, PlateInventory.mostPairsPerPlate)]))),
        .init(
            name: "a plate weight past what hundredths hold", repaired: true,
            edit: { $0["plates"] = rows([(20, 1), (1e300, 1)]) },
            expected: keeping(plates: Self.plates([(20, 1)]))),
        .init(
            name: "a plate weight just past what hundredths hold", repaired: true,
            edit: { $0["plates"] = rows([(9.3e16, 1), (9.3e16, 2)]) },
            expected: keeping(plates: [])),
        .init(
            name: "a negative plate weight", repaired: true,
            edit: { $0["plates"] = rows([(-20, 1)]) },
            expected: keeping(plates: [])),
        .init(
            name: "a plate weight of zero", repaired: true,
            edit: { $0["plates"] = rows([(0, 3), (10, 1)]) },
            expected: keeping(plates: Self.plates([(10, 1)]))),
        .init(
            name: "a bar weight past what hundredths hold", repaired: true,
            edit: { $0["bars"] = [["kind": "standard", "kg": 1e300]] },
            expected: {
                var kit = $0
                kit.bars = [.init(.standard, kg: preset.bar(.standard).kg)]
                return kit
            }),
        .init(
            name: "a dumbbell step past what hundredths hold", repaired: true,
            edit: { $0["dumbbellStepKg"] = 1e300 },
            expected: {
                var kit = $0
                kit.dumbbellStepKg = preset.dumbbellStepKg
                return kit
            }),
        .init(
            name: "a heaviest dumbbell past what hundredths hold", repaired: true,
            edit: { $0["heaviestDumbbellKg"] = 1e300 },
            expected: {
                var kit = $0
                kit.heaviestDumbbellKg = preset.heaviestDumbbellKg
                return kit
            }),
        .init(
            name: "a machine step past what hundredths hold", repaired: true,
            edit: { $0["machineStepKg"] = 1e300 },
            expected: {
                var kit = $0
                kit.machineStepKg = preset.machineStepKg
                return kit
            }),
    ]

    private func fixtureBackup(editingPlates edit: (inout [String: Any]) -> Void) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: "Fixtures/backup-d9dbad2", withExtension: "json"))
        var backup = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        var profile = try #require(backup["profile"] as? [String: Any])
        var plates = try #require(profile["plates"] as? [String: Any])
        edit(&plates)
        profile["plates"] = plates
        backup["profile"] = profile
        return try JSONSerialization.data(withJSONObject: backup)
    }

    /// The fixture's kit as the restore leaves it when nothing in it is wrong.
    @MainActor private func untouchedKit() throws -> PlateInventory {
        let container = try TransmuteStore.makeTestContainer()
        try DataTransfer.importBackup(fixtureBackup { _ in }, into: container.mainContext)
        return try #require(try Profile.canonical(in: container.mainContext)).plates
    }

    @MainActor @Test(arguments: badKits)
    func aKitThatCouldNotBeRealKeepsEverythingButTheFieldsThatWereWrongAndTheRestRestores(_ kit: BadKit) throws {
        let data = try fixtureBackup(editingPlates: kit.edit)
        let container = try TransmuteStore.makeTestContainer()

        let summary = try DataTransfer.importBackup(data, into: container.mainContext)

        let restored = try #require(try Profile.canonical(in: container.mainContext))
        #expect(restored.plates == kit.expected(try untouchedKit()))
        #expect(summary.profile == .added)
        #expect(summary.plateKitRepaired == kit.repaired)
        #expect(summary.workouts.added == 10)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Workout>()) == 10)
    }

    @MainActor @Test(arguments: badKits)
    func aKitThatCouldNotBeRealIsIgnoredWhenTheStoreAlreadyHasAProfile(_ kit: BadKit) throws {
        let data = try fixtureBackup(editingPlates: kit.edit)
        let container = try TransmuteStore.makeTestContainer()
        let existing = Profile()
        existing.plates = PlateInventory(.home, system: .metric)
        container.mainContext.insert(existing)
        try container.mainContext.save()

        let summary = try DataTransfer.importBackup(data, into: container.mainContext)

        #expect(summary.profile == .kept)
        #expect(!summary.plateKitRepaired)
        #expect(summary.workouts.added == 10)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Workout>()) == 10)
        #expect(try Profile.canonical(in: container.mainContext)?.plates == PlateInventory(.home, system: .metric))
    }

    @MainActor @Test func theLimitsOfTheSetupScreenStillRestoreAsWritten() throws {
        let rows = Self.rows([(20, PlateInventory.mostPairsPerPlate), (10, 0)])
        let data = try fixtureBackup { $0["plates"] = rows }
        let container = try TransmuteStore.makeTestContainer()

        let summary = try DataTransfer.importBackup(data, into: container.mainContext)

        #expect(!summary.plateKitRepaired)
        let restored = try #require(try Profile.canonical(in: container.mainContext))
        #expect(restored.plates.plates == [.init(kg: 20, pairs: 20), .init(kg: 10, pairs: 0)])
    }

    @MainActor @Test func aKitWithMoreThanTheCapOfPairsInARowRestoresWithThatRowAtTheCapAndEverythingElseIntact() throws
    {
        let over = PlateInventory.mostPairsPerPlate + 1
        let rows = Self.rows([(20.41, over), (10, 2)])
        let data = try fixtureBackup { $0["plates"] = rows }
        let container = try TransmuteStore.makeTestContainer()

        let summary = try DataTransfer.importBackup(data, into: container.mainContext)

        #expect(!summary.plateKitRepaired)
        var expected = try untouchedKit()
        expected.plates = Self.plates([(20.41, PlateInventory.mostPairsPerPlate), (10, 2)])
        #expect(try Profile.canonical(in: container.mainContext)?.plates == expected)
    }

    @MainActor @Test func aMetricKitWithOneImplausibleFieldRestoresAsMetricWithOnlyThatFieldReset() throws {
        let data = try fixtureBackup {
            $0["system"] = "metric"
            $0["plates"] = Self.rows([(25, 4), (7.5, 2), (1.25, 1)])
            $0["machineStepKg"] = 250_000.0
        }
        let container = try TransmuteStore.makeTestContainer()

        let summary = try DataTransfer.importBackup(data, into: container.mainContext)

        #expect(summary.plateKitRepaired)
        let restored = try #require(try Profile.canonical(in: container.mainContext)).plates
        var expected = try untouchedKit()
        expected.system = .metric
        expected.plates = Self.plates([(25, 4), (7.5, 2), (1.25, 1)])
        expected.machineStepKg = PlateInventory(.commercialGym, system: .metric).machineStepKg
        #expect(restored == expected)
        #expect(restored.machineStepKg == 5)
    }

    @MainActor @Test func twoRowsOfOneWeightMergeWithinTheCap() throws {
        let cap = PlateInventory.mostPairsPerPlate
        let rows = Self.rows([(20, cap), (20, cap), (10, 1)])
        let data = try fixtureBackup { $0["plates"] = rows }
        let container = try TransmuteStore.makeTestContainer()

        let summary = try DataTransfer.importBackup(data, into: container.mainContext)

        #expect(!summary.plateKitRepaired)
        let restored = try #require(try Profile.canonical(in: container.mainContext))
        #expect(restored.plates.plates == Self.plates([(20, cap), (10, 1)]))
    }

    @MainActor @Test func aMachineStepTheSetupScreenAcceptsStillRestoresEveryWorkoutIntoAStoreWithAProfile() throws {
        let data = try fixtureBackup { $0["machineStepKg"] = 150_000.0 }
        let container = try TransmuteStore.makeTestContainer()
        container.mainContext.insert(Profile())
        try container.mainContext.save()

        let summary = try DataTransfer.importBackup(data, into: container.mainContext)

        #expect(summary.workouts.added == 10)
    }

    @MainActor @Test func aRowWithNoPairsIsAKitTheAppCanWriteSoItRestoresAsWritten() throws {
        let rows = Self.rows([(20, 2), (10, 0), (5, 1)])
        let data = try fixtureBackup { $0["plates"] = rows }
        let container = try TransmuteStore.makeTestContainer()

        try DataTransfer.importBackup(data, into: container.mainContext)

        let restored = try #require(try Profile.canonical(in: container.mainContext))
        #expect(restored.plates.plates == [.init(kg: 20, pairs: 2), .init(kg: 10, pairs: 0), .init(kg: 5, pairs: 1)])
    }
}
