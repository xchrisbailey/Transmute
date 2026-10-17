import Foundation
import SwiftData
import Testing
import TransmuteTestSupport

@testable import TransmuteCore

/// A restore into a store that already has a profile applies the file's plate kit only while the
/// device's kit is still the preset a new profile starts with, so a person moving phones gets their
/// kit and a customised device is never overwritten.
struct BackupKitRestoreTests {
    /// A kit no preset holds, in the unit the device's own preset isn't, so replacing the device's
    /// kit with it is visible whatever the test machine's locale is.
    static let fileKit: PlateInventory = {
        let system: UnitSystem = PlateInventory.standard().system == .metric ? .imperial : .metric
        var kit = PlateInventory(.home, system: system)
        kit.addPair(ofKg: system.kilograms(fromDisplay: 7))
        return kit
    }()

    private func backup(plates: [String: Any]?) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: "Fixtures/backup-d9dbad2", withExtension: "json"))
        var backup = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        var profile = try #require(backup["profile"] as? [String: Any])
        profile["plates"] = plates
        backup["profile"] = profile
        return try JSONSerialization.data(withJSONObject: backup)
    }

    private func encoded(_ kit: PlateInventory) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(kit)) as? [String: Any])
    }

    /// A store whose profile holds `kit`, or the preset a new profile starts with.
    @MainActor private func store(kit: PlateInventory? = nil) throws -> ModelContainer {
        let container = try TransmuteStore.makeTestContainer()
        let profile = Profile()
        if let kit { profile.plates = kit }
        container.mainContext.insert(profile)
        try container.mainContext.save()
        return container
    }

    @MainActor @Test func aKitStillTheUntouchedPresetIsReplacedByTheFilesKit() throws {
        let container = try store()
        #expect(try Profile.canonical(in: container.mainContext)?.plates == PlateInventory.standard())

        let summary = try DataTransfer.importBackup(
            backup(plates: encoded(Self.fileKit)), into: container.mainContext)

        #expect(summary.profile == .kept)
        #expect(!summary.plateKitKept)
        #expect(!summary.plateKitRepaired)
        #expect(try Profile.canonical(in: container.mainContext)?.plates == Self.fileKit)
    }

    @MainActor @Test func theFilesKitIsRepairedBeforeItReplacesTheUntouchedPreset() throws {
        let container = try store()
        var plates = try encoded(Self.fileKit)
        plates["machineStepKg"] = 250_000.0

        let summary = try DataTransfer.importBackup(backup(plates: plates), into: container.mainContext)

        #expect(summary.plateKitRepaired)
        #expect(!summary.plateKitKept)
        var expected = Self.fileKit
        expected.machineStepKg = PlateInventory(.commercialGym, system: expected.system).machineStepKg
        #expect(try Profile.canonical(in: container.mainContext)?.plates == expected)
    }

    @MainActor @Test func aCustomisedKitIsKeptAndTheSummarySaysSo() throws {
        var mine = PlateInventory.standard()
        mine.addPair(ofKg: mine.kilograms(fromDisplay: 3))
        let container = try store(kit: mine)

        let summary = try DataTransfer.importBackup(
            backup(plates: encoded(Self.fileKit)), into: container.mainContext)

        #expect(summary.profile == .kept)
        #expect(summary.plateKitKept)
        #expect(!summary.plateKitRepaired)
        #expect(try Profile.canonical(in: container.mainContext)?.plates == mine)
        #expect(summary.workouts.added == 10)
    }

    @MainActor @Test func aKitOfTheOtherUnitIsCustomisedEvenIfItIsAPreset() throws {
        let otherSystem: UnitSystem = PlateInventory.standard().system == .metric ? .imperial : .metric
        let other = PlateInventory(.commercialGym, system: otherSystem)
        let container = try store(kit: other)

        let summary = try DataTransfer.importBackup(
            backup(plates: encoded(Self.fileKit)), into: container.mainContext)

        #expect(summary.plateKitKept)
        #expect(try Profile.canonical(in: container.mainContext)?.plates == other)
    }

    @MainActor @Test func aCustomisedKitIsNotReportedKeptWhenTheFileHoldsTheSameKit() throws {
        let container = try store(kit: Self.fileKit)

        let summary = try DataTransfer.importBackup(
            backup(plates: encoded(Self.fileKit)), into: container.mainContext)

        #expect(!summary.plateKitKept)
        #expect(try Profile.canonical(in: container.mainContext)?.plates == Self.fileKit)
    }

    @MainActor @Test func aFileWithNoKitLeavesTheUntouchedKitAndSaysNothing() throws {
        let container = try store()

        let summary = try DataTransfer.importBackup(backup(plates: nil), into: container.mainContext)

        #expect(!summary.plateKitKept)
        #expect(try Profile.canonical(in: container.mainContext)?.plates == PlateInventory.standard())
    }

    @MainActor @Test func theBarWeightOnTheDevicesProfileIsLeftAlone() throws {
        let container = try store()
        let before = try #require(try Profile.canonical(in: container.mainContext)).barbellKg

        try DataTransfer.importBackup(backup(plates: encoded(Self.fileKit)), into: container.mainContext)

        #expect(try Profile.canonical(in: container.mainContext)?.barbellKg == before)
    }

    @MainActor @Test func theCreatePathStillAppliesTheFilesKitAndReportsNothingKept() throws {
        let container = try TransmuteStore.makeTestContainer()

        let summary = try DataTransfer.importBackup(
            backup(plates: encoded(Self.fileKit)), into: container.mainContext)

        #expect(summary.profile == .added)
        #expect(!summary.plateKitKept)
        #expect(try Profile.canonical(in: container.mainContext)?.plates == Self.fileKit)
    }

    @MainActor @Test func aLenientDefaultTakesTheFilesUnitNotTheDevicesLocale() throws {
        let system: UnitSystem = PlateInventory.standard().system == .metric ? .imperial : .metric
        var plates = try encoded(PlateInventory(.home, system: system))
        plates["plates"] = nil
        let container = try TransmuteStore.makeTestContainer()

        try DataTransfer.importBackup(backup(plates: plates), into: container.mainContext)

        let restored = try #require(try Profile.canonical(in: container.mainContext)).plates
        #expect(restored.system == system)
        #expect(restored.plates == PlateInventory(.commercialGym, system: system).plates)
    }
}
