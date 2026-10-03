import Foundation
import SwiftData

extension Backup {
    /// Reads the whole store. Everything is listed in a fixed order, so two backups of the same
    /// data differ only in `exportedAt`.
    init(context: ModelContext, exportedAt: Date, appVersion: String?) throws {
        self.init(exportedAt: exportedAt, appVersion: appVersion)
        // One profile is the rule; if sync ever leaves two, the first made is the one kept.
        profile = try context.fetch(FetchDescriptor<Profile>(sortBy: [SortDescriptor(\.createdAt)])).first
            .map(ProfileBackup.init)
        customExercises = try context.fetch(FetchDescriptor<CustomExercise>())
            .sorted { ($0.createdAt, $0.exerciseID) < ($1.createdAt, $1.exerciseID) }
            .map(CustomExerciseBackup.init)
        plans = try context.fetch(FetchDescriptor<Plan>())
            .sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
            .map(PlanBackup.init)
        workouts = try context.fetch(FetchDescriptor<Workout>())
            .sorted { ($0.startedAt, $0.id.uuidString) < ($1.startedAt, $1.id.uuidString) }
            .map(WorkoutBackup.init)
        records = try context.fetch(FetchDescriptor<PersonalRecord>()).map(RecordBackup.init)
            .sorted(by: RecordBackup.precedes)
    }
}
