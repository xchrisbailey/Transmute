import TransmuteCore

/// Turns limitations into exercises to leave out. The model is told about limitations too,
/// but these rules make sure nothing risky is even offered (#9).
public enum LimitationRules {
    /// Movement patterns and primary muscles that load each area.
    static func risks(for area: BodyArea) -> (patterns: Set<MovementPattern>, muscles: Set<Muscle>) {
        switch area {
        case .neck: ([], [.neck, .traps])
        case .shoulder: ([.verticalPush, .throw], [.frontDelts, .sideDelts, .rotatorCuff])
        case .elbow: ([], [.triceps, .biceps, .forearms])
        case .wrist: ([], [.forearms])
        case .upperBack: ([], [.traps, .upperBack])
        case .lowerBack: ([.hinge], [.lowerBack])
        case .hip: ([.lunge, .changeOfDirection], [.hipFlexors, .adductors])
        case .knee: ([.jump, .lunge, .sprint, .changeOfDirection], [])
        case .ankle: ([.jump, .sprint, .changeOfDirection, .locomotion], [.calves])
        }
    }

    /// Whether an exercise is off limits for these areas. Mobility work is kept, since gentle
    /// range of motion usually helps; the model is still told to go easy.
    public static func excludes(_ exercise: LibraryExercise, areas: Set<BodyArea>) -> Bool {
        guard exercise.category != .mobility else { return false }
        return areas.contains { area in
            let risk = risks(for: area)
            return risk.patterns.contains(exercise.pattern) || !risk.muscles.isDisjoint(with: exercise.primaryMuscles)
        }
    }

    static let words: [BodyArea: [String]] = [
        .neck: ["neck"], .shoulder: ["shoulder", "shoulders", "rotator"], .elbow: ["elbow", "elbows"],
        .wrist: ["wrist", "wrists"], .upperBack: ["upper back"], .lowerBack: ["lower back", "back pain", "disc"],
        .hip: ["hip", "hips", "groin"], .knee: ["knee", "knees", "acl", "meniscus", "patella"],
        .ankle: ["ankle", "ankles", "achilles"],
    ]

    /// Areas the limitation text names, e.g. "sore left knee" → knee.
    public static func areas(mentionedIn text: String) -> Set<BodyArea> {
        let lowered = " " + text.lowercased().map { $0.isLetter ? $0 : " " }.reduce(into: "") { $0.append($1) } + " "
        return Set(words.filter { _, words in words.contains { lowered.contains(" \($0) ") } }.keys)
    }
}
