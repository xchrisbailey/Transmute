import Foundation
import SwiftData
import Testing
import TransmuteTestSupport

@testable import TransmuteCore

/// A member missing from a commitment, a known lift, the plate kit, a bar or a plate row keeps a
/// default, so a backup written before the member existed still restores. A member with no honest
/// default (a commitment's weekday, a lift's weight, the kit's unit) still fails the file, and so
/// does a key missing from a plan, day, exercise, set, workout, record, custom exercise or
/// bodyweight: those are the backup's data, and a new member there bumps `formatVersion`.
struct BackupDeeperMembersTests {
    /// A key dropped from one place in the fixture's profile, and the restored profile it should give.
    struct Removal: Sendable, CustomTestStringConvertible {
        let name: String
        let edit: @Sendable (inout [String: Any]) -> Void
        let check: @Sendable (Profile) -> Bool
        var testDescription: String { name }
    }

    /// The fixture's kit is in pounds, so a default taken from the preset is too.
    static let preset = PlateInventory(.commercialGym, system: .imperial)

    static func removing(
        fromRowsOf key: String, in path: [String], _ member: String
    ) -> @Sendable (inout [String: Any]) -> Void {
        { profile in
            edit(&profile, path: path) { container in
                var rows = container[key] as? [[String: Any]] ?? []
                for index in rows.indices { rows[index][member] = nil }
                container[key] = rows
            }
        }
    }

    static func edit(_ profile: inout [String: Any], path: [String], _ change: (inout [String: Any]) -> Void) {
        guard let head = path.first else { return change(&profile) }
        var inner = profile[head] as? [String: Any] ?? [:]
        edit(&inner, path: Array(path.dropFirst()), change)
        profile[head] = inner
    }

    static func removing(_ member: String, in path: [String]) -> @Sendable (inout [String: Any]) -> Void {
        { profile in edit(&profile, path: path) { $0[member] = nil } }
    }

    static let lenient: [Removal] = [
        .init(
            name: "a commitment's intensity",
            edit: removing(fromRowsOf: "commitments", in: ["schedule"], "intensity"),
            check: { $0.schedule.commitments.count == 3 && $0.schedule.commitments.allSatisfy { $0.intensity == .moderate } }),
        .init(
            name: "a known lift's reps",
            edit: { profile in
                var lifts = profile["knownLifts"] as? [[String: Any]] ?? []
                for index in lifts.indices { lifts[index]["reps"] = nil }
                profile["knownLifts"] = lifts
            },
            check: { $0.knownLifts == [KnownLift(exerciseID: "back-squat", weightKg: 100, reps: 1)] }),
        .init(
            name: "the kit's chosen bar", edit: removing("barKind", in: ["plates"]),
            check: { $0.plates.barKind == .standard }),
        .init(
            name: "the kit's bars", edit: removing("bars", in: ["plates"]),
            check: { $0.plates.bars == PlateInventory.defaultBars(.imperial) }),
        .init(
            name: "the kit's plates", edit: removing("plates", in: ["plates"]),
            check: { $0.plates.plates == preset.plates }),
        .init(
            name: "the kit's dumbbell step", edit: removing("dumbbellStepKg", in: ["plates"]),
            check: { $0.plates.dumbbellStepKg == preset.dumbbellStepKg }),
        .init(
            name: "the kit's heaviest dumbbell", edit: removing("heaviestDumbbellKg", in: ["plates"]),
            check: { $0.plates.heaviestDumbbellKg == preset.heaviestDumbbellKg }),
        .init(
            name: "the kit's machine step", edit: removing("machineStepKg", in: ["plates"]),
            check: { $0.plates.machineStepKg == preset.machineStepKg }),
        .init(
            name: "a bar's weight",
            edit: removing(fromRowsOf: "bars", in: ["plates"], "kg"),
            check: { $0.plates.bars == PlateInventory.defaultBars(.imperial) }),
        .init(
            name: "a plate row's pairs",
            edit: removing(fromRowsOf: "plates", in: ["plates"], "pairs"),
            check: { profile in
                profile.plates.plates.count == 6 && profile.plates.plates.allSatisfy { $0.pairs == 0 }
            }),
    ]

    static let strict: [Removal] = [
        .init(
            name: "a commitment's weekday", edit: removing(fromRowsOf: "commitments", in: ["schedule"], "weekday"),
            check: { _ in true }),
        .init(
            name: "a commitment's label", edit: removing(fromRowsOf: "commitments", in: ["schedule"], "label"),
            check: { _ in true }),
        .init(
            name: "a known lift's exercise",
            edit: { profile in
                var lifts = profile["knownLifts"] as? [[String: Any]] ?? []
                for index in lifts.indices { lifts[index]["exerciseID"] = nil }
                profile["knownLifts"] = lifts
            },
            check: { _ in true }),
        .init(
            name: "a known lift's weight",
            edit: { profile in
                var lifts = profile["knownLifts"] as? [[String: Any]] ?? []
                for index in lifts.indices { lifts[index]["weightKg"] = nil }
                profile["knownLifts"] = lifts
            },
            check: { _ in true }),
        .init(name: "the kit's unit", edit: removing("system", in: ["plates"]), check: { _ in true }),
        .init(
            name: "a bar's kind", edit: removing(fromRowsOf: "bars", in: ["plates"], "kind"), check: { _ in true }),
        .init(
            name: "a plate row's weight", edit: removing(fromRowsOf: "plates", in: ["plates"], "kg"),
            check: { _ in true }),
    ]

    private func fixtureObject() throws -> [String: Any] {
        let url = try #require(Bundle.module.url(forResource: "Fixtures/backup-d9dbad2", withExtension: "json"))
        return try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    private func fixture(editingProfile edit: (inout [String: Any]) -> Void) throws -> Data {
        var backup = try fixtureObject()
        var profile = try #require(backup["profile"] as? [String: Any])
        edit(&profile)
        backup["profile"] = profile
        return try JSONSerialization.data(withJSONObject: backup)
    }

    @MainActor @Test(arguments: lenient)
    func aMemberWithADefaultMissingFromTheFileKeepsItsDefaultAndTheRestRestores(_ removal: Removal) throws {
        let data = try fixture(editingProfile: removal.edit)
        let container = try TransmuteStore.makeTestContainer()

        let summary = try DataTransfer.importBackup(data, into: container.mainContext)

        let restored = try #require(try Profile.canonical(in: container.mainContext))
        #expect(removal.check(restored))
        #expect(!summary.plateKitRepaired)
        #expect(summary.workouts.added == 10)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Workout>()) == 10)
    }

    @MainActor @Test(arguments: strict)
    func aMemberWithNoHonestDefaultMissingFromTheFileStillFailsIt(_ removal: Removal) throws {
        let data = try fixture(editingProfile: removal.edit)
        let container = try TransmuteStore.makeTestContainer()

        #expect {
            try DataTransfer.importBackup(data, into: container.mainContext)
        } throws: { error in
            guard case .unreadableBackup = error as? DataTransferError else { return false }
            return true
        }
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Profile>()) == 0)
    }

    /// The backup's own data: a key missing from any of these fails the file, and a new member
    /// there needs a `formatVersion` bump.
    @MainActor @Test(arguments: [
        ("plans", "name"), ("plans", "weekCount"), ("workouts", "title"), ("workouts", "startedAt"),
        ("customExercises", "name"), ("records", "kind"),
    ])
    func aKeyMissingFromTheBackupsOwnRecordsStillFailsTheFile(_ collection: String, _ key: String) throws {
        var backup = try fixtureObject()
        var rows = try #require(backup[collection] as? [[String: Any]])
        rows[0][key] = nil
        backup[collection] = rows
        let data = try JSONSerialization.data(withJSONObject: backup)
        let container = try TransmuteStore.makeTestContainer()

        #expect {
            try DataTransfer.importBackup(data, into: container.mainContext)
        } throws: { error in
            guard case .unreadableBackup = error as? DataTransferError else { return false }
            return true
        }
    }

    @MainActor @Test func aKitOverTheRowCapRestoresTheFirstRowsAndSaysItWasRepaired() throws {
        let cap = PlateInventory.mostPlateRows
        let rows = (1...(cap + 1)).map { ["kg": Double($0), "pairs": 1] as [String: Any] }
        let data = try fixture { $0["plates"] = BackupDeeperMembersTests.kit(withRows: rows, in: $0) }
        let container = try TransmuteStore.makeTestContainer()

        let summary = try DataTransfer.importBackup(data, into: container.mainContext)

        #expect(summary.plateKitRepaired)
        let restored = try #require(try Profile.canonical(in: container.mainContext)).plates
        #expect(restored.plates.count == cap)
        #expect(restored.plates.map(\.kg) == (1...cap).map(Double.init))
    }

    @MainActor @Test func aKitAtTheRowCapRestoresAsWritten() throws {
        let cap = PlateInventory.mostPlateRows
        let rows = (1...cap).map { ["kg": Double($0), "pairs": 1] as [String: Any] }
        let data = try fixture { $0["plates"] = BackupDeeperMembersTests.kit(withRows: rows, in: $0) }
        let container = try TransmuteStore.makeTestContainer()

        let summary = try DataTransfer.importBackup(data, into: container.mainContext)

        #expect(!summary.plateKitRepaired)
        #expect(try Profile.canonical(in: container.mainContext)?.plates.plates.count == cap)
    }

    @MainActor @Test func rowsThatMergeOrDropDoNotCountTowardTheCap() throws {
        let cap = PlateInventory.mostPlateRows
        var rows = (1...cap).map { ["kg": Double($0), "pairs": 1] as [String: Any] }
        rows.append(["kg": 1.0, "pairs": 1])
        rows.append(["kg": -3.0, "pairs": 1])
        let data = try fixture { $0["plates"] = BackupDeeperMembersTests.kit(withRows: rows, in: $0) }
        let container = try TransmuteStore.makeTestContainer()

        try DataTransfer.importBackup(data, into: container.mainContext)

        let restored = try #require(try Profile.canonical(in: container.mainContext)).plates
        #expect(restored.plates.count == cap)
        #expect(restored.plates.first == .init(kg: 1, pairs: 2))
    }

    /// The fixture's `profile.plates` with its rows replaced.
    static func kit(withRows rows: [[String: Any]], in profile: [String: Any]) -> [String: Any] {
        var kit = profile["plates"] as? [String: Any] ?? [:]
        kit["plates"] = rows
        return kit
    }
}
