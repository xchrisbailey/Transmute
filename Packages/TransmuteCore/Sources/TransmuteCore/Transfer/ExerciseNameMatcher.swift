import Foundation

/// Finds the library exercise another app's exercise name means.
///
/// Names are compared the way search folds them, against names and aliases. Strong and Hevy
/// put the equipment last, as in "Bench Press (Barbell)", so that form is also tried as
/// "barbell bench press", and then as plain "bench press" if that exercise uses a barbell.
struct ExerciseNameMatcher {
    private var byName: [String: LibraryExercise] = [:]

    init(library: ExerciseLibrary) {
        library.exercises.forEach { add($0) }
    }

    /// Makes an exercise findable by its name and aliases. Earlier exercises keep a name.
    mutating func add(_ exercise: LibraryExercise) {
        for name in [exercise.name] + exercise.aliases {
            let key = ExerciseLibrary.fold(name)
            if byName[key] == nil { byName[key] = exercise }
        }
    }

    func match(_ name: String) -> LibraryExercise? {
        if let exact = byName[ExerciseLibrary.fold(name)] { return exact }
        guard name.hasSuffix(")"), let open = name.lastIndex(of: "(") else { return nil }
        let base = ExerciseLibrary.fold(String(name[..<open]))
        let qualifier = ExerciseLibrary.fold(String(name[open...]))
        if let reordered = byName["\(qualifier) \(base)"] { return reordered }
        guard let equipment = Self.equipment[qualifier], let plain = byName[base],
            plain.allEquipment.contains(equipment)
        else { return nil }
        return plain
    }

    /// The equipment words the two apps put in brackets.
    private static let equipment: [String: Equipment] = [
        "barbell": .barbell, "dumbbell": .dumbbell, "kettlebell": .kettlebell, "machine": .machine,
        "cable": .cable, "band": .band, "bodyweight": .bodyweight, "plate": .plate, "trap bar": .trapBar,
    ]
}
