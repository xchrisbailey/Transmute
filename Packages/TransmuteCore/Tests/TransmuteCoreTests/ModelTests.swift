import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

@MainActor
struct ModelTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try TransmuteStore.makeContainer(.inMemory)
    }

    @Test func sampleRoundTrips() throws {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        SampleData.insert(into: context, now: now)
        try context.save()

        let fresh = ModelContext(container)
        let profile = try #require(try fresh.fetch(FetchDescriptor<Profile>()).first)
        #expect(profile.experience == .intermediate)
        #expect(profile.sports == ["tennis"])
        #expect(profile.goalTags.contains(.agility))
        #expect(profile.schedule.commitments.map(\.label) == ["Practice", "Practice", "Match"])
        #expect(profile.unitSystem == .imperial)
        #expect(Units.feetAndInches(cm: try #require(profile.heightCm)) == (5, 9))
        #expect(profile.bodyweights?.count == 4)
        #expect(abs(try #require(profile.latestBodyweightKg) - 78.8) < 1e-9)

        let plan = try #require(try fresh.fetch(FetchDescriptor<Plan>()).first)
        #expect(plan.orderedDays.count == 12)
        let monday = try #require(plan.orderedDays.first)
        #expect(monday.focus == "Lower and power")
        #expect(monday.orderedExercises.map(\.exerciseID).prefix(2) == ["box-jump", "back-squat"])
        #expect(monday.orderedExercises[1].orderedSets.first?.targetLoadKg == 90)

        let workouts = try fresh.fetch(FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.startedAt)]))
        #expect(workouts.count == 9)
        let first = try #require(workouts.first)
        #expect(first.planDay?.focus == "Lower and power")
        #expect(first.orderedExercises.allSatisfy { $0.orderedSets.allSatisfy(\.isCompleted) })
        // 4 × 5 × 90 + 3 × 8 × 70 + 3 × 8 × 16 back squat, RDL and split squat.
        #expect(first.volumeKg == 1_800 + 1_680 + 384)
        #expect(try #require(first.duration) > 0)
    }

    @Test func deletingAPlanCascadesButKeepsWorkouts() throws {
        let (_, plan) = SampleData.insert(into: context)
        try context.save()
        context.delete(plan)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<PlanDay>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<PlannedExercise>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<PlannedSet>()) == 0)
        let workouts = try context.fetch(FetchDescriptor<Workout>())
        #expect(workouts.count == 9)
        #expect(workouts.allSatisfy { $0.planDay == nil })
    }

    @Test func deletingAWorkoutCascadesToSetsAndKeepsRecords() throws {
        let workout = Workout(title: "Lower A")
        let exercise = LoggedExercise(exerciseID: "back-squat", order: 0)
        let set = LoggedSet(order: 0, weightKg: 115, reps: 5)
        set.complete()
        exercise.sets?.append(set)
        workout.exercises?.append(exercise)
        context.insert(workout)
        let record = PersonalRecord(exerciseID: "back-squat", kind: .repMax, value: 115, set: set)
        record.reps = 5
        context.insert(record)
        try context.save()

        context.delete(workout)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<LoggedSet>()) == 0)
        let kept = try #require(try context.fetch(FetchDescriptor<PersonalRecord>()).first)
        #expect(kept.kind == .repMax)
        #expect(kept.set == nil)
    }

    @Test func customExercisesUseTheirOwnIDSpace() throws {
        let custom = CustomExercise(name: "Serve shadow swings", category: .power, pattern: .rotation, tracking: .reps)
        custom.primaryMuscles = [.obliques, .frontDelts]
        context.insert(custom)
        try context.save()
        let fetched = try #require(try ModelContext(container).fetch(FetchDescriptor<CustomExercise>()).first)
        #expect(fetched.exerciseID.hasPrefix("custom-"))
        #expect(fetched.primaryMuscles == [.obliques, .frontDelts])
        #expect(fetched.tracking == .reps)
    }

    @Test func unknownRawValuesFallBack() {
        let profile = Profile()
        profile.experienceRaw = "wizard"
        profile.goalTagsRaw = ["strength", "flight"]
        #expect(profile.experience == .beginner)
        #expect(profile.goalTags == [.strength])
    }
}

/// CloudKit can only mirror a schema whose attributes are optional or defaulted, with no
/// unique constraints and only optional relationships.
struct CloudKitCompatibilityTests {
    @Test(arguments: TransmuteStore.schema.entities.map(\.name))
    func entityFollowsCloudKitRules(_ name: String) throws {
        let entity = try #require(TransmuteStore.schema.entities.first { $0.name == name })
        #expect(entity.uniquenessConstraints.isEmpty)
        for attribute in entity.attributes {
            #expect(!attribute.isUnique, "\(name).\(attribute.name) is unique")
            #expect(
                attribute.isOptional || attribute.defaultValue != nil,
                "\(name).\(attribute.name) needs a default or must be optional")
        }
        for relationship in entity.relationships {
            #expect(relationship.isOptional, "\(name).\(relationship.name) must be optional")
            #expect(
                relationship.inverseKeyPath != nil || relationship.inverseName != nil,
                "\(name).\(relationship.name) needs an inverse")
        }
    }
}

extension CloudKitCompatibilityTests {
    /// Guards the rule check above against passing vacuously.
    @Test func schemaReflectsDefaultsAndOptionals() throws {
        let plan = try #require(TransmuteStore.schema.entities.first { $0.name == "Plan" })
        let name = try #require(plan.attributes.first { $0.name == "name" })
        #expect(!name.isOptional)
        #expect(name.defaultValue as? String == "")
        let brewedBy = try #require(plan.attributes.first { $0.name == "brewedBy" })
        #expect(brewedBy.isOptional)
        #expect(TransmuteStore.schema.entities.count == SchemaV1.models.count)
    }
}
