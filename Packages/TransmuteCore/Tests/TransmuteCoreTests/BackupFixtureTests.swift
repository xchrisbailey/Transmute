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
        container = try TransmuteStore.makeContainer(.inMemory)
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

    private func deleteHistory() throws {
        for record in try context.fetch(FetchDescriptor<PersonalRecord>()) { context.delete(record) }
        for workout in try context.fetch(FetchDescriptor<Workout>()) { context.delete(workout) }
        try context.save()
    }
}
