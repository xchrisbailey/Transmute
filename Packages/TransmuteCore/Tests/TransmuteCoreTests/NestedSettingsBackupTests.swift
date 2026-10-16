import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

/// A backup written before a member joined `Schedule`, `ProgressionSettings` or
/// `WorkoutPreferences` still restores, and that member keeps its default.
struct NestedSettingsBackupTests {
    struct Member<Value: Sendable>: Sendable, CustomTestStringConvertible {
        let key: String
        let reset: @Sendable (inout Value) -> Void
        var testDescription: String { key }
    }

    static let chosenSchedule = Schedule(
        daysPerWeek: 5, preferredWeekdays: [1, 4], sessionMinutes: 45, weeks: 8,
        commitments: [Commitment(weekday: 2, label: "Match", intensity: .hard)])
    static let chosenProgression = ProgressionSettings(
        upperBodyKg: 1, lowerBodyKg: 2, upperBodyLb: 10, lowerBodyLb: 20, heldExerciseIDs: ["back-squat"])
    static let chosenPreferences = WorkoutPreferences(
        workingRestSeconds: 150, warmUpRestSeconds: 30, restSound: false, restHaptics: false, autoStartRest: false,
        showRPE: true, showPercentOfMax: true, warmUpSets: false)

    static let scheduleMembers: [Member<Schedule>] = [
        .init(key: "daysPerWeek") { $0.daysPerWeek = Schedule().daysPerWeek },
        .init(key: "preferredWeekdays") { $0.preferredWeekdays = Schedule().preferredWeekdays },
        .init(key: "sessionMinutes") { $0.sessionMinutes = Schedule().sessionMinutes },
        .init(key: "weeks") { $0.weeks = Schedule().weeks },
        .init(key: "commitments") { $0.commitments = Schedule().commitments },
    ]
    static let progressionMembers: [Member<ProgressionSettings>] = [
        .init(key: "upperBodyKg") { $0.upperBodyKg = ProgressionSettings().upperBodyKg },
        .init(key: "lowerBodyKg") { $0.lowerBodyKg = ProgressionSettings().lowerBodyKg },
        .init(key: "upperBodyLb") { $0.upperBodyLb = ProgressionSettings().upperBodyLb },
        .init(key: "lowerBodyLb") { $0.lowerBodyLb = ProgressionSettings().lowerBodyLb },
        .init(key: "heldExerciseIDs") { $0.heldExerciseIDs = ProgressionSettings().heldExerciseIDs },
    ]
    static let preferencesMembers: [Member<WorkoutPreferences>] = [
        .init(key: "workingRestSeconds") { $0.workingRestSeconds = WorkoutPreferences().workingRestSeconds },
        .init(key: "warmUpRestSeconds") { $0.warmUpRestSeconds = WorkoutPreferences().warmUpRestSeconds },
        .init(key: "restSound") { $0.restSound = WorkoutPreferences().restSound },
        .init(key: "restHaptics") { $0.restHaptics = WorkoutPreferences().restHaptics },
        .init(key: "autoStartRest") { $0.autoStartRest = WorkoutPreferences().autoStartRest },
        .init(key: "showRPE") { $0.showRPE = WorkoutPreferences().showRPE },
        .init(key: "showPercentOfMax") { $0.showPercentOfMax = WorkoutPreferences().showPercentOfMax },
        .init(key: "warmUpSets") { $0.warmUpSets = WorkoutPreferences().warmUpSets },
    ]

    private func fixture() throws -> [String: Any] {
        let url = try #require(Bundle.module.url(forResource: "Fixtures/backup-d9dbad2", withExtension: "json"))
        return try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    private func object(_ value: some Encodable) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    }

    /// Reads a setting from the profile the fixture restores to when `profile[key]` is replaced.
    @MainActor
    private func restored<Setting>(
        _ setting: KeyPath<Profile, Setting>, replacing key: String, with value: Any
    ) throws -> Setting {
        var backup = try fixture()
        var profile = try #require(backup["profile"] as? [String: Any])
        profile[key] = value
        backup["profile"] = profile
        let container = try TransmuteStore.makeTestContainer()
        try DataTransfer.importBackup(try JSONSerialization.data(withJSONObject: backup), into: container.mainContext)
        return try #require(try Profile.canonical(in: container.mainContext))[keyPath: setting]
    }

    @MainActor @Test(arguments: scheduleMembers)
    func aScheduleMissingAMemberKeepsItsDefault(_ member: Member<Schedule>) throws {
        var saved = try object(Self.chosenSchedule)
        saved.removeValue(forKey: member.key)
        var expected = Self.chosenSchedule
        member.reset(&expected)

        let restored = try restored(\.schedule, replacing: "schedule", with: saved)

        #expect(restored == expected)
        #expect(expected != Self.chosenSchedule)
    }

    @MainActor @Test(arguments: progressionMembers)
    func progressionSettingsMissingAMemberKeepItsDefault(_ member: Member<ProgressionSettings>) throws {
        var saved = try object(Self.chosenProgression)
        saved.removeValue(forKey: member.key)
        var expected = Self.chosenProgression
        member.reset(&expected)

        let restored = try restored(\.progression, replacing: "progression", with: saved)

        #expect(restored == expected)
        #expect(expected != Self.chosenProgression)
    }

    @MainActor @Test(arguments: preferencesMembers)
    func preferencesMissingAMemberKeepItsDefault(_ member: Member<WorkoutPreferences>) throws {
        var saved = try object(Self.chosenPreferences)
        saved.removeValue(forKey: member.key)
        var expected = Self.chosenPreferences
        member.reset(&expected)

        let restored = try restored(\.preferences, replacing: "preferences", with: saved)

        #expect(restored == expected)
        #expect(expected != Self.chosenPreferences)
    }

    @MainActor @Test func emptyNestedSettingsRestoreAsTheirDefaults() throws {
        #expect(try restored(\.schedule, replacing: "schedule", with: [String: Any]()) == Schedule())
    }
}
