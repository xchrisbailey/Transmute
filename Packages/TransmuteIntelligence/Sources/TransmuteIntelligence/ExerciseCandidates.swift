import TransmuteCore

/// A shortlist of library exercises written into a prompt, with the ids the answer is held to.
///
/// The small on-device model chooses more reliably from a list in front of it than by
/// searching, and pairing the list with `SchemaConstraint` means it can't pick anything else.
public struct ExerciseCandidates: Sendable, Equatable {
    public let exercises: [LibraryExercise]

    public init(_ exercises: [LibraryExercise]) {
        self.exercises = exercises
    }

    /// Everything inside the scope, minus excluded ids, in catalog order.
    public init(
        library: ExerciseLibrary = .bundled, scope: ExerciseQuery, excluding excludedIDs: Set<String> = []
    ) {
        self.init(library.search(scope).filter { !excludedIDs.contains($0.id) })
    }

    public var ids: [String] {
        exercises.map(\.id)
    }

    /// One line per exercise, grouped by category: "back-squat: Back squat (squat)".
    public var promptList: String {
        ExerciseCategory.allCases.compactMap { category in
            let lines = exercises.filter { $0.category == category }.map {
                "\($0.id): \($0.name) (\($0.pattern.rawValue))"
            }
            return lines.isEmpty ? nil : "\(category.rawValue):\n" + lines.joined(separator: "\n")
        }
        .joined(separator: "\n\n")
    }

    /// The constraint for `IntelligenceRequest.allowedValues`.
    public var constraint: [String: [String]] {
        ["exerciseID": ids, "exerciseIDs": ids]
    }
}
