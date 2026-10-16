import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

/// `Fixtures/backup-d9dbad2.json` is a backup as the code at `d9dbad2` wrote it. The format is
/// a promise to people's files, so these tests keep reading it and writing it back unchanged.
@MainActor
struct BackupFixtureTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try TransmuteStore.makeTestContainer()
    }

    private func fixture() throws -> Data {
        let url = try #require(Bundle.module.url(forResource: "Fixtures/backup-d9dbad2", withExtension: "json"))
        return try Data(contentsOf: url)
    }

    @Test func restoringTheFixtureGivesEverythingItHolds() throws {
        let summary = try DataTransfer.importBackup(try fixture(), into: context)

        #expect(summary.profile == .added)
        #expect(summary.plans == .init(added: 1))
        #expect(summary.workouts == .init(added: 10))
        #expect(summary.customExercises == .init(added: 1))
        #expect(summary.bodyweights == .init(added: 5))
        #expect(summary.recordsAdded == 56)
        let profile = try #require(try context.fetch(FetchDescriptor<Profile>()).first)
        #expect(profile.sex == .female)
        #expect(profile.heightCm == 171)
        #expect(profile.birthYear == 1990)
        #expect(profile.heightUnit == .metric)
        #expect(profile.weightUnit == nil)
        #expect(profile.unitSystem == .imperial)
        #expect(profile.limitationAreas == [.shoulder])
        #expect(profile.knownLifts.first?.weightKg == 100)
        #expect(profile.preferences.workingRestSeconds == 120)
        let workouts = try context.fetch(FetchDescriptor<Workout>())
        #expect(workouts.count { $0.planDay != nil } == 10)
        let records = try context.fetch(FetchDescriptor<PersonalRecord>())
        #expect(records.allSatisfy { $0.set != nil })
    }

    @Test func theFixtureWritesBackAsTheSameBytes() throws {
        let data = try fixture()
        let backup = try Backup(data: data)
        try DataTransfer.importBackup(data, into: context)

        let again = try DataTransfer.exportBackup(
            from: context, exportedAt: backup.exportedAt, appVersion: backup.appVersion)

        #expect(again == data)
    }

    @Test func workoutsAttachToTheDaysOfAPlanAlreadyHere() throws {
        let data = try fixture()
        try DataTransfer.importBackup(data, into: context)
        try deleteHistory()

        let summary = try DataTransfer.importBackup(data, into: context)

        #expect(summary.plans == .init(skipped: 1))
        #expect(summary.workouts == .init(added: 10))
        let workouts = try context.fetch(FetchDescriptor<Workout>())
        #expect(workouts.count { $0.planDay != nil } == 10)
    }

    @Test func workoutsDoNotAttachToAPlanEditedSinceTheBackup() throws {
        let data = try fixture()
        try DataTransfer.importBackup(data, into: context)
        try deleteHistory()
        let plan = try #require(try context.fetch(FetchDescriptor<Plan>()).first)
        plan.days?.append(PlanDay(week: 9, weekday: 2, focus: "Added since"))
        try context.save()

        let summary = try DataTransfer.importBackup(data, into: context)

        #expect(summary.workouts == .init(added: 10))
        let workouts = try context.fetch(FetchDescriptor<Workout>())
        #expect(workouts.allSatisfy { $0.planDay == nil })
    }

    private func everySettingChosen() -> Profile {
        let profile = Profile()
        profile.id = UUID()
        profile.createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        profile.heightCm = 181
        profile.birthYear = 1985
        profile.sex = .male
        profile.experience = .advanced
        profile.sports = ["tennis"]
        profile.goalText = "Serve harder"
        profile.goalTags = [.power]
        profile.schedule = Schedule(daysPerWeek: 5, sessionMinutes: 45, weeks: 6)
        profile.equipment = [.kettlebell]
        profile.limitations = "Left knee"
        profile.limitationAreas = [.knee]
        profile.progression = ProgressionSettings(upperBodyKg: 2, heldExerciseIDs: ["back-squat"])
        profile.knownLifts = [KnownLift(exerciseID: "bench-press", weightKg: 80, reps: 5)]
        profile.barbellKg = 15
        profile.plates = PlateInventory(.home, system: .imperial)
        profile.unitSystem = .imperial
        profile.weightUnit = .metric
        profile.heightUnit = .imperial
        profile.distanceUnit = .metric
        profile.preferences.workingRestSeconds = 95
        return profile
    }

    @Test func everyProfileSettingIsWrittenUnderItsOwnKey() throws {
        context.insert(everySettingChosen())

        let data = try DataTransfer.exportBackup(from: context)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let written = try #require(json["profile"] as? [String: Any])
        #expect(written["heightCm"] as? Double == 181)
        #expect(written["birthYear"] as? Int == 1985)
        #expect(written["sex"] as? String == "male")
        #expect(written["experience"] as? String == "advanced")
        #expect(written["sports"] as? [String] == ["tennis"])
        #expect(written["goalText"] as? String == "Serve harder")
        #expect(written["goalTags"] as? [String] == ["power"])
        #expect(written["equipment"] as? [String] == ["kettlebell"])
        #expect(written["limitations"] as? String == "Left knee")
        #expect(written["limitationAreas"] as? [String] == ["knee"])
        #expect(written["barbellKg"] as? Double == 15)
        #expect(written["unitSystem"] as? String == "imperial")
        #expect(written["weightUnit"] as? String == "metric")
        #expect(written["heightUnit"] as? String == "imperial")
        #expect(written["distanceUnit"] as? String == "metric")
        #expect(Set(written.keys).isSuperset(of: ["id", "createdAt", "schedule", "progression", "knownLifts"]))
        #expect(Set(written.keys).isSuperset(of: ["plates", "preferences", "bodyweights"]))
    }

    @Test func everyProfileSettingIsRestoredToItsOwnProperty() throws {
        let profile = everySettingChosen()
        context.insert(profile)
        let data = try DataTransfer.exportBackup(from: context)

        let other = try TransmuteStore.makeTestContainer()
        try DataTransfer.importBackup(data, into: other.mainContext)
        let restored = try #require(try Profile.canonical(in: other.mainContext))
        #expect(restored.id == profile.id)
        #expect(restored.createdAt == profile.createdAt)
        #expect(restored.heightCm == 181)
        #expect(restored.birthYear == 1985)
        #expect(restored.sex == .male)
        #expect(restored.experience == .advanced)
        #expect(restored.sports == ["tennis"])
        #expect(restored.goalText == "Serve harder")
        #expect(restored.goalTags == [.power])
        #expect(restored.schedule == profile.schedule)
        #expect(restored.equipment == [.kettlebell])
        #expect(restored.limitations == "Left knee")
        #expect(restored.limitationAreas == [.knee])
        #expect(restored.progression == profile.progression)
        #expect(restored.knownLifts == profile.knownLifts)
        #expect(restored.barbellKg == 15)
        #expect(restored.plates == profile.plates)
        #expect(restored.unitSystem == .imperial)
        #expect(restored.weightUnit == .metric)
        #expect(restored.heightUnit == .imperial)
        #expect(restored.distanceUnit == .metric)
        #expect(restored.preferences == profile.preferences)
    }

    private func deleteHistory() throws {
        for record in try context.fetch(FetchDescriptor<PersonalRecord>()) { context.delete(record) }
        for workout in try context.fetch(FetchDescriptor<Workout>()) { context.delete(workout) }
        try context.save()
    }
}
