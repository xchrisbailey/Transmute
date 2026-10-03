import Foundation
import SwiftData

/// Adds workouts read from another app's CSV to the store. See `DataTransfer.importCSV` for
/// the rules.
struct WorkoutCSVMerge {
    let file: ImportedWorkouts
    let context: ModelContext
    let library: ExerciseLibrary
    private var matcher: ExerciseNameMatcher
    private var summary: ImportSummary
    private var touched: Set<String> = []

    init(file: ImportedWorkouts, context: ModelContext, library: ExerciseLibrary) {
        self.file = file
        self.context = context
        self.library = library
        self.matcher = ExerciseNameMatcher(library: library)
        self.summary = ImportSummary(source: file.source)
    }

    mutating func run() throws -> ImportSummary {
        summary.unreadableRows = file.unreadableRows
        var known = Set(try context.fetch(FetchDescriptor<Workout>()).map { Self.key($0.startedAt, $0.title) })
        var custom: [LibraryExercise] = []
        for imported in file.workouts {
            guard known.insert(Self.key(imported.startedAt, imported.title)).inserted else {
                summary.workouts.skipped += 1
                continue
            }
            let workout = Workout(title: imported.title, startedAt: imported.startedAt)
            workout.endedAt = imported.endedAt
            workout.notes = imported.notes
            for (order, exercise) in imported.exercises.enumerated() {
                let match = matcher.match(exercise.name) ?? addCustomExercise(named: exercise.name, to: &custom)
                workout.exercises?.append(logged(exercise, as: match.id, order: order, in: imported))
                touched.insert(match.id)
            }
            context.insert(workout)
            summary.workouts.added += 1
        }
        let before = try context.fetchCount(FetchDescriptor<PersonalRecord>())
        let records = RecordBook(context: context, library: library.adding(custom))
        for exerciseID in touched {
            try records.recompute(exerciseID: exerciseID)
        }
        summary.recordsAdded = max(0, try context.fetchCount(FetchDescriptor<PersonalRecord>()) - before)
        try context.save()
        return summary
    }

    /// Start times to the second, since that's all either app writes.
    private static func key(_ start: Date, _ title: String) -> String {
        "\(Int(start.timeIntervalSince1970.rounded()))|\(title)"
    }

    private mutating func logged(
        _ imported: ImportedWorkouts.Exercise, as exerciseID: String, order: Int, in workout: ImportedWorkouts.Workout
    ) -> LoggedExercise {
        let exercise = LoggedExercise(exerciseID: exerciseID, order: order)
        exercise.notes = imported.notes
        for (index, values) in imported.sets.enumerated() {
            let set = LoggedSet(
                order: index, weightKg: values.weightKg, reps: values.reps, seconds: values.seconds,
                meters: values.meters, rpe: values.rpe)
            set.isWarmUp = values.isWarmUp
            set.notes = values.notes
            // Neither app says when a set was done; the workout's end is the closest there is.
            set.complete(at: workout.endedAt ?? workout.startedAt)
            exercise.sets?.append(set)
        }
        summary.setsAdded += imported.sets.count
        return exercise
    }

    /// A custom exercise for a name the library doesn't know, measured the way the file's sets
    /// for it are. Later rows with the same name reuse it.
    private mutating func addCustomExercise(named name: String, to custom: inout [LibraryExercise]) -> LibraryExercise {
        let sets = file.workouts.flatMap(\.exercises).filter { $0.name == name }.flatMap(\.sets)
        let tracking: TrackingType =
            if sets.contains(where: { $0.weightKg != nil }) {
                .weightReps
            } else if sets.contains(where: { $0.meters != nil }) {
                .distanceTime
            } else if sets.contains(where: { $0.reps != nil }) {
                .reps
            } else if sets.contains(where: { $0.seconds != nil }) {
                .time
            } else {
                .weightReps
            }
        let exercise = CustomExercise(name: name, category: .strength, pattern: .isolation, tracking: tracking)
        context.insert(exercise)
        let entry = LibraryExercise(exercise)
        matcher.add(entry)
        custom.append(entry)
        summary.customExercises.added += 1
        summary.unmatchedExerciseNames.append(name)
        return entry
    }
}
