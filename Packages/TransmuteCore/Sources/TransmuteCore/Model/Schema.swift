import SwiftData

/// The current schema. Code outside the model layer uses these names, not `SchemaV1.…`.
public typealias Profile = SchemaV1.Profile
public typealias BodyweightEntry = SchemaV1.BodyweightEntry
public typealias CustomExercise = SchemaV1.CustomExercise
public typealias Plan = SchemaV1.Plan
public typealias PlanDay = SchemaV1.PlanDay
public typealias PlannedExercise = SchemaV1.PlannedExercise
public typealias PlannedSet = SchemaV1.PlannedSet
public typealias Workout = SchemaV1.Workout
public typealias LoggedExercise = SchemaV1.LoggedExercise
public typealias LoggedSet = SchemaV1.LoggedSet
public typealias PersonalRecord = SchemaV1.PersonalRecord

public enum TransmuteMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    public static var stages: [MigrationStage] {
        []
    }
}
