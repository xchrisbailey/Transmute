import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

@MainActor
struct BackupTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let now = Date(timeIntervalSince1970: 1_790_000_000)

    init() throws {
        container = try TransmuteStore.makeContainer(.inMemory)
    }

    /// The sample, plus one of everything it leaves out: a custom exercise, records, notes,
    /// Health ids, a fractional date and a session still running.
    private func fill(_ context: ModelContext) throws {
        let (profile, plan) = SampleData.insert(into: context, now: now)
        profile.knownLifts = [KnownLift(exerciseID: "back-squat", weightKg: 100, reps: 3)]
        profile.limitationAreas = [.shoulder]
        profile.bodyweights?.append(BodyweightEntry(date: now, kg: 78.25, healthKitSampleID: UUID()))

        let custom = CustomExercise(
            name: "Racket \"snap\" throw", category: .power, pattern: .rotation, tracking: .reps)
        custom.aliases = ["snap throw"]
        custom.primaryMuscles = [.obliques]
        custom.equipment = [.medicineBall]
        custom.sportTags = ["tennis"]
        context.insert(custom)

        let day = try #require(plan.orderedDays.last)
        day.isEdited = true
        day.notes = "Keep it light"
        let running = Workout(title: "Friday, in progress", startedAt: now.addingTimeInterval(0.25), planDay: day)
        running.notes = "Felt quick"
        running.healthKitWorkoutID = UUID()
        running.restEndsAt = now.addingTimeInterval(90)
        running.restSeconds = 90
        running.startedOn = .watch
        let logged = LoggedExercise(exerciseID: custom.exerciseID, order: 0)
        logged.substitutedFromID = "med-ball-rotational-throw"
        let set = LoggedSet(order: 0, reps: 6, rpe: 7)
        set.isWarmUp = true
        set.notes = "Left side, then right"
        set.targetReps = 6
        set.complete(at: now.addingTimeInterval(60.5))
        logged.sets = [set, LoggedSet(order: 1, reps: 6)]
        running.exercises = [logged]
        context.insert(running)

        try RecordBook(context: context).recomputeAll()
        try context.save()
    }

    /// How many of each model there are, in schema order.
    private func counts(in context: ModelContext) throws -> [Int] {
        func count<Model: PersistentModel>(_ model: Model.Type) throws -> Int {
            try context.fetchCount(FetchDescriptor<Model>())
        }
        return try SchemaV1.models.map { try count($0) }
    }

    @Test func exportRoundTripsThroughImport() throws {
        try fill(context)
        let first = try DataTransfer.exportBackup(from: context, exportedAt: now, appVersion: "1.0")

        let other = try TransmuteStore.makeContainer(.inMemory)
        let summary = try DataTransfer.importBackup(first, into: other.mainContext)
        let second = try DataTransfer.exportBackup(
            from: ModelContext(other), exportedAt: now.addingTimeInterval(3_600), appVersion: "1.0")

        var original = try Backup(data: first)
        let restored = try Backup(data: second)
        #expect(original.exportedAt != restored.exportedAt)
        original.exportedAt = restored.exportedAt
        #expect(original == restored)
        #expect(try original.encoded() == second)

        // The backup holds something of every model, with the relationships that cross the tree.
        #expect(try counts(in: context) == counts(in: other.mainContext))
        #expect(try counts(in: context).allSatisfy { $0 > 0 })
        #expect(original.workouts.count { $0.planDay != nil } == 10)
        #expect(!original.records.isEmpty)
        #expect(original.records.allSatisfy { $0.set != nil })
        #expect(summary.profile == .added)
        #expect(summary.plans == .init(added: 1))
        #expect(summary.workouts == .init(added: 10))
        #expect(summary.customExercises == .init(added: 1))
        #expect(summary.bodyweights == .init(added: 5))
        #expect(summary.recordsAdded == original.records.count)
        #expect(summary.setsAdded == (try context.fetchCount(FetchDescriptor<LoggedSet>())))
    }

    @Test func restoredRelationshipsPointAtTheSameThings() throws {
        try fill(context)
        let other = try TransmuteStore.makeContainer(.inMemory)
        try DataTransfer.importBackup(try DataTransfer.exportBackup(from: context), into: other.mainContext)

        let fresh = ModelContext(other)
        let running = try #require(try fresh.fetch(FetchDescriptor<Workout>()).first { $0.endedAt == nil })
        #expect(running.planDay?.notes == "Keep it light")
        #expect(running.planDay?.plan?.name == "Court-ready strength")
        #expect(running.startedOn == .watch)
        #expect(running.startedAt == now.addingTimeInterval(0.25))
        #expect(running.orderedExercises.first?.orderedSets.first?.completedAt == now.addingTimeInterval(60.5))
        for record in try fresh.fetch(FetchDescriptor<PersonalRecord>()) {
            #expect(record.set?.exercise?.exerciseID == record.exerciseID)
        }
        let profile = try #require(try fresh.fetch(FetchDescriptor<Profile>()).first)
        #expect(profile.schedule.commitments.count == 3)
        #expect(profile.unitSystem == .imperial)
        #expect(profile.knownLifts.first?.weightKg == 100)
    }

    @Test func importingTwiceAddsNothing() throws {
        try fill(context)
        let data = try DataTransfer.exportBackup(from: context, exportedAt: now)
        let before = try counts(in: context)

        let summary = try DataTransfer.importBackup(data, into: context)

        #expect(try counts(in: context) == before)
        #expect(!summary.addedAnything)
        #expect(summary.profile == .kept)
        #expect(summary.plans == .init(skipped: 1))
        #expect(summary.workouts == .init(skipped: 10))
        #expect(summary.customExercises == .init(skipped: 1))
        #expect(summary.bodyweights == .init(skipped: 5))
        #expect(try DataTransfer.exportBackup(from: context, exportedAt: now) == data)
    }

    @Test func importingOverOtherDataMergesAndKeepsTheProfile() throws {
        try fill(context)
        let data = try DataTransfer.exportBackup(from: context)

        let other = try TransmuteStore.makeContainer(.inMemory)
        let target = other.mainContext
        let mine = Profile()
        mine.goalText = "Mine"
        mine.bodyweights?.append(BodyweightEntry(date: now, kg: 70))
        target.insert(mine)
        let plan = Plan(name: "Already here")
        target.insert(plan)
        let workout = Workout(title: "Earlier", startedAt: now.addingTimeInterval(-90 * 86_400))
        let squat = LoggedExercise(exerciseID: "back-squat", order: 0)
        let heavy = LoggedSet(order: 0, weightKg: 140, reps: 5)
        heavy.complete(at: workout.startedAt)
        squat.sets = [heavy]
        workout.exercises = [squat]
        workout.endedAt = workout.startedAt.addingTimeInterval(1_800)
        target.insert(workout)
        try RecordBook(context: target).recomputeAll()
        try target.save()

        let summary = try DataTransfer.importBackup(data, into: target)

        #expect(summary.profile == .kept)
        let profiles = try target.fetch(FetchDescriptor<Profile>())
        #expect(profiles.count == 1)
        #expect(profiles.first?.goalText == "Mine")
        #expect(profiles.first?.bodyweights?.count == 6)
        #expect(summary.bodyweights == .init(added: 5))
        #expect(summary.plans == .init(added: 1))
        #expect(summary.workouts == .init(added: 10))
        #expect(try target.fetchCount(FetchDescriptor<Workout>()) == 11)
        // The plan that was here stays the active one.
        let plans = try target.fetch(FetchDescriptor<Plan>())
        #expect(plans.filter(\.isActive).map(\.name) == ["Already here"])
        // Records are derived again from the merged history. The backup's squat estimates beat
        // a 90 kg baseline; behind the 140 kg set that was already here, none of them stand.
        let isSquatEstimate = { (id: String, kind: String) in
            id == "back-squat" && kind == RecordKind.estimatedOneRepMax.rawValue
        }
        #expect(try Backup(data: data).records.contains { isSquatEstimate($0.exerciseID, $0.kind) })
        let records = try target.fetch(FetchDescriptor<PersonalRecord>())
        #expect(!records.contains { isSquatEstimate($0.exerciseID, $0.kindRaw) })
        #expect(records.contains { $0.exerciseID == "bench-press" })
        #expect(summary.recordsAdded > 0)
    }

    @Test func aNewerBackupIsTurnedAway() throws {
        let data = Data(#"{"formatVersion": 2, "exportedAt": "2026-10-03T09:30:00Z", "shape": "unknown"}"#.utf8)
        #expect(throws: DataTransferError.newerBackup(formatVersion: 2, supported: 1)) {
            try DataTransfer.importBackup(data, into: context)
        }
    }

    @Test func somethingElseIsUnreadable() throws {
        #expect(throws: DataTransferError.emptyFile) {
            try DataTransfer.importBackup(Data(), into: context)
        }
        for text in ["date,workout\r\n", #"{"exportedAt": "2026-10-03T09:30:00Z"}"#, #"{"formatVersion": 1}"#] {
            do {
                try DataTransfer.importBackup(Data(text.utf8), into: context)
                Issue.record("\(text) should not import")
            } catch let error as DataTransferError {
                guard case .unreadableBackup = error else {
                    Issue.record("\(error)")
                    continue
                }
            }
        }
        #expect(try counts(in: context).allSatisfy { $0 == 0 })
    }

    /// An older backup won't have settings added since. They keep their defaults.
    @Test func missingKeysKeepDefaults() throws {
        let json = """
            {
              "formatVersion": 1,
              "exportedAt": "2026-10-03T09:30:00.250Z",
              "profile": { "goalText": "Get strong", "experience": "advanced", "bodyweights": [
                { "date": "2026-10-01T07:00:00Z", "kg": 80.5 }
              ] }
            }
            """
        let summary = try DataTransfer.importBackup(Data(json.utf8), into: context)

        #expect(summary.profile == .added)
        let profile = try #require(try context.fetch(FetchDescriptor<Profile>()).first)
        #expect(profile.goalText == "Get strong")
        #expect(profile.experience == .advanced)
        #expect(profile.schedule == Schedule())
        #expect(profile.progression == ProgressionSettings())
        #expect(profile.plates == Profile().plates)
        #expect(profile.latestBodyweightKg == 80.5)
        #expect(try context.fetchCount(FetchDescriptor<Workout>()) == 0)
    }

    @Test func datesAreISO8601ToTheMillisecond() throws {
        let whole = Date(timeIntervalSince1970: 1_790_000_000)
        #expect(BackupDate.string(from: whole) == "2026-09-21T14:13:20Z")
        #expect(BackupDate.string(from: whole.addingTimeInterval(0.25)) == "2026-09-21T14:13:20.250Z")
        #expect(BackupDate.string(from: whole.addingTimeInterval(0.999_9)) == "2026-09-21T14:13:21Z")
        for offset in [0, 0.001, 0.123, 0.5, 0.999] {
            let text = BackupDate.string(from: whole.addingTimeInterval(offset))
            let read = try #require(BackupDate.date(from: text))
            #expect(BackupDate.string(from: read) == text)
        }
        let json = try #require(
            String(data: try DataTransfer.exportBackup(from: context, exportedAt: whole), encoding: .utf8))
        #expect(json.contains(#""exportedAt" : "2026-09-21T14:13:20Z""#))
        #expect(json.contains(#""formatVersion" : 1"#))
    }
}
