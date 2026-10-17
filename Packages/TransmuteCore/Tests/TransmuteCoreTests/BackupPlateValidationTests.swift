import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

/// A backup is a file anyone can edit, and the setup screen takes any weight above zero. A kit that
/// couldn't be real never costs the person the rest of the file: the restore swaps it for the
/// standard kit when it would have applied it, says so, and keeps everything else. Either way the
/// kit never reaches the plate maths, where it would trap.
struct BackupPlateValidationTests {
    struct BadKit: Sendable, CustomTestStringConvertible {
        let name: String
        let edit: @Sendable (inout [String: Any]) -> Void
        var testDescription: String { name }
    }

    static func rows(_ rows: [(kg: Double, pairs: Int)]) -> [[String: Any]] {
        rows.map { ["kg": $0.kg, "pairs": NSNumber(value: $0.pairs)] }
    }

    static let badKits: [BadKit] = [
        .init(name: "a negative row among good ones") {
            $0["plates"] = rows([(20, 3), (20, -1), (10, 2)])
        },
        .init(name: "a negative row cancelling a good one") {
            $0["plates"] = rows([(20, 1), (20, -1)])
        },
        .init(name: "a negative row on its own") {
            $0["plates"] = rows([(15, -4)])
        },
        .init(name: "pairs that overflow when rows of one weight merge") {
            $0["plates"] = rows([(20, Int.max), (20, 1)])
        },
        .init(name: "one pair more than the setup screen offers") {
            $0["plates"] = rows([(20, PlateInventory.mostPairsPerPlate + 1)])
        },
        .init(name: "more pairs than anyone owns") {
            $0["plates"] = rows([(20, 1_000_000)])
        },
        .init(name: "a plate weight past what hundredths hold") {
            $0["plates"] = rows([(20, 1), (1e300, 1)])
        },
        .init(name: "a plate weight just past what hundredths hold") {
            $0["plates"] = rows([(9.3e16, 1), (9.3e16, 2)])
        },
        .init(name: "a negative plate weight") {
            $0["plates"] = rows([(-20, 1)])
        },
        .init(name: "a bar weight past what hundredths hold") {
            $0["bars"] = [["kind": "standard", "kg": 1e300]]
        },
        .init(name: "a dumbbell step past what hundredths hold") {
            $0["dumbbellStepKg"] = 1e300
        },
        .init(name: "a heaviest dumbbell past what hundredths hold") {
            $0["heaviestDumbbellKg"] = 1e300
        },
        .init(name: "a machine step past what hundredths hold") {
            $0["machineStepKg"] = 1e300
        },
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

    @MainActor @Test(arguments: badKits)
    func aKitThatCouldNotBeRealIsReplacedByTheStandardKitAndTheRestRestores(_ kit: BadKit) throws {
        let data = try fixtureBackup(editingPlates: kit.edit)
        let container = try TransmuteStore.makeTestContainer()

        let summary = try DataTransfer.importBackup(data, into: container.mainContext)

        let restored = try #require(try Profile.canonical(in: container.mainContext))
        #expect(restored.plates == PlateInventory.standard())
        #expect(summary.profile == .added)
        #expect(summary.plateKitReplaced)
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
        #expect(!summary.plateKitReplaced)
        #expect(summary.workouts.added == 10)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Workout>()) == 10)
        #expect(try Profile.canonical(in: container.mainContext)?.plates == PlateInventory(.home, system: .metric))
    }

    @MainActor @Test func theLimitsOfTheSetupScreenStillRestoreAsWritten() throws {
        let rows = Self.rows([(20, PlateInventory.mostPairsPerPlate), (10, 0)])
        let data = try fixtureBackup { $0["plates"] = rows }
        let container = try TransmuteStore.makeTestContainer()

        let summary = try DataTransfer.importBackup(data, into: container.mainContext)

        #expect(!summary.plateKitReplaced)
        let restored = try #require(try Profile.canonical(in: container.mainContext))
        #expect(restored.plates.plates == [.init(kg: 20, pairs: 20), .init(kg: 10, pairs: 0)])
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
