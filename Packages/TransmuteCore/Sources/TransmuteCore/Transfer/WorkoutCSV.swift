import Foundation

/// The CSV export: one row per logged set, for spreadsheets and other apps (#18).
///
/// Quantities are metric as stored, the date is the workout's start in ISO 8601 (UTC), and
/// `set_order` counts from 1 within the exercise. Empty cells mean the set doesn't track that
/// measure. The header row is part of the format; add columns at the end.
enum WorkoutCSV {
    static let header = [
        "date", "workout", "exercise", "exercise_id", "set_order", "weight_kg", "reps", "seconds", "meters", "rpe",
        "warm_up", "completed", "notes",
    ]

    static func text(for workouts: [Workout], library: ExerciseLibrary) -> String {
        var text = CSV.line(header)
        let ordered = workouts.sorted { ($0.startedAt, $0.id.uuidString) < ($1.startedAt, $1.id.uuidString) }
        for workout in ordered {
            let date = workout.startedAt.formatted(.iso8601)
            for exercise in workout.orderedExercises {
                let name = library.exercise(id: exercise.exerciseID)?.name ?? exercise.exerciseID
                for (index, set) in exercise.orderedSets.enumerated() {
                    text += CSV.line([
                        date, workout.title, name, exercise.exerciseID, String(index + 1), number(set.weightKg),
                        set.reps.map(String.init) ?? "", number(set.seconds), number(set.meters), number(set.rpe),
                        String(set.isWarmUp), String(set.isCompleted), set.notes,
                    ])
                }
            }
        }
        return text
    }

    /// "90" for 90.0 and "92.5" for 92.5, always with a point.
    static func number(_ value: Double?) -> String {
        guard let value else { return "" }
        return value == value.rounded() && abs(value) < 1e15 ? String(Int(value)) : String(value)
    }
}
