import Foundation

/// An exercise as plans, the picker and the AI see it, whether it ships in the bundled
/// catalog or the user added it.
public struct LibraryExercise: Codable, Hashable, Identifiable, Sendable {
    /// Stable across catalog versions. Custom exercises start with `custom-`.
    public var id: String
    public var name: String
    public var aliases: [String]
    public var category: ExerciseCategory
    public var pattern: MovementPattern
    public var primaryMuscles: [Muscle]
    public var secondaryMuscles: [Muscle]
    /// Everything the exercise needs. Each inner list is a choice: one of its items is enough.
    /// `[[.dumbbell, .kettlebell], [.bench]]` needs a bench and either a dumbbell or a kettlebell.
    public var equipment: [[Equipment]]
    public var tracking: TrackingType
    public var unilateral: Bool
    public var difficulty: ExperienceLevel
    /// Plain setup and movement cues, written for a beginner.
    public var cues: [String]
    /// Common mistakes to watch for.
    public var mistakes: [String]
    /// A simpler alternative's id.
    public var easier: String?
    /// A harder progression's id.
    public var harder: String?
    /// Sports this suits: tennis, running, soccer, climbing, general.
    public var sports: [String]
    public var isCustom: Bool { id.hasPrefix("custom-") }

    public init(
        id: String, name: String, aliases: [String] = [], category: ExerciseCategory, pattern: MovementPattern,
        primaryMuscles: [Muscle], secondaryMuscles: [Muscle] = [], equipment: [[Equipment]],
        tracking: TrackingType, unilateral: Bool = false, difficulty: ExperienceLevel = .beginner,
        cues: [String] = [], mistakes: [String] = [], easier: String? = nil, harder: String? = nil,
        sports: [String] = []
    ) {
        self.id = id
        self.name = name
        self.aliases = aliases
        self.category = category
        self.pattern = pattern
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
        self.equipment = equipment
        self.tracking = tracking
        self.unilateral = unilateral
        self.difficulty = difficulty
        self.cues = cues
        self.mistakes = mistakes
        self.easier = easier
        self.harder = harder
        self.sports = sports
    }

    /// Every piece of equipment the exercise can use.
    public var allEquipment: Set<Equipment> {
        Set(equipment.joined())
    }

    /// Whether it can be done with what's available. Bodyweight is always available.
    public func isDoable(with available: Set<Equipment>) -> Bool {
        let have = available.union([.bodyweight])
        return equipment.allSatisfy { !have.isDisjoint(with: $0) }
    }
}

extension LibraryExercise {
    /// A custom exercise as the library sees it.
    public init(_ custom: CustomExercise) {
        self.init(
            id: custom.exerciseID, name: custom.name, aliases: custom.aliases, category: custom.category,
            pattern: custom.pattern, primaryMuscles: custom.primaryMuscles, secondaryMuscles: custom.secondaryMuscles,
            equipment: custom.equipment.isEmpty ? [[.bodyweight]] : [custom.equipment], tracking: custom.tracking,
            unilateral: custom.isUnilateral, difficulty: custom.difficulty, cues: custom.cues,
            sports: custom.sportTags)
    }
}
