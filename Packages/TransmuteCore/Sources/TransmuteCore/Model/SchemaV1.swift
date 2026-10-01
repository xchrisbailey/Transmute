import Foundation
import SwiftData

/// The first shipped schema. Later versions copy the models they change into a new
/// `SchemaVn` and add a stage to `TransmuteMigrationPlan`.
///
/// CloudKit rules every model follows: each attribute is optional or has a default, no
/// attribute is unique, and every relationship is optional with an explicit inverse.
/// Quantities are metric: kilograms, centimetres, metres and seconds.
public enum SchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            Profile.self, BodyweightEntry.self, CustomExercise.self,
            Plan.self, PlanDay.self, PlannedExercise.self, PlannedSet.self,
            Workout.self, LoggedExercise.self, LoggedSet.self, PersonalRecord.self,
        ]
    }
}
