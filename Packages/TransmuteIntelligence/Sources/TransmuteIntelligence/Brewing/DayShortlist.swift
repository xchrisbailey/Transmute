import TransmuteCore

extension DayKind {
    var categories: Set<ExerciseCategory> {
        switch self {
        case .lowerStrength, .upperStrength, .fullBody: [.strength, .mobility]
        case .powerSpeed: [.power, .speedAgility, .strength]
        case .conditioning: [.conditioning, .speedAgility, .mobility]
        case .mobility: [.mobility]
        }
    }

    /// The category the day is about, which the shortlist ranks first.
    var mainCategory: ExerciseCategory {
        switch self {
        case .lowerStrength, .upperStrength, .fullBody: .strength
        case .powerSpeed: .power
        case .conditioning: .conditioning
        case .mobility: .mobility
        }
    }

    var patterns: Set<MovementPattern>? {
        switch self {
        case .lowerStrength: [.squat, .hinge, .lunge, .carry, .core, .antiRotation, .mobility]
        case .upperStrength:
            [
                .horizontalPush, .verticalPush, .horizontalPull, .verticalPull, .isolation, .core, .rotation,
                .antiRotation, .mobility,
            ]
        case .powerSpeed:
            [.jump, .throw, .sprint, .changeOfDirection, .squat, .hinge, .rotation, .locomotion]
        case .fullBody, .conditioning, .mobility: nil
        }
    }

    /// Whether a day of this kind loads the legs heavily, so it shouldn't sit before a match.
    var isHardOnLegs: Bool {
        self == .lowerStrength || self == .powerSpeed || self == .fullBody
    }
}

/// Picks the exercises a day's prompt offers: what the person can do, suited to the day, with
/// anything their limitations rule out removed. Exercises tagged for their sport come first.
public enum DayShortlist {
    /// Kept small enough that the list and the schema fit the on-device context.
    public static let limit = 60

    public static func candidates(
        for kind: DayKind, brief: TrainingBrief, library: ExerciseLibrary = .bundled,
        excluding excluded: Set<String> = [],
        limit: Int = limit
    ) -> ExerciseCandidates {
        var query = brief.exerciseScope
        query.categories = kind.categories
        if let patterns = kind.patterns { query.patterns = patterns }
        let sports = Set(brief.sports.compactMap(sportTag(for:)))
        let usable = library.search(query).filter {
            !excluded.contains($0.id) && !LimitationRules.excludes($0, areas: brief.limitationAreas)
        }
        let ranked = usable.enumerated().sorted { lhs, rhs in
            RankKey(lhs.element, catalogIndex: lhs.offset, sports: sports, main: kind.mainCategory)
                < RankKey(rhs.element, catalogIndex: rhs.offset, sports: sports, main: kind.mainCategory)
        }
        let mobility = ranked.filter { $0.element.category == .mobility }.prefix(kind == .mobility ? limit : 8)
        let rest = ranked.filter { $0.element.category != .mobility }.prefix(limit - mobility.count)
        return ExerciseCandidates((rest + mobility).sorted { $0.offset < $1.offset }.map(\.element))
    }

    /// Sport-specific exercises first, then the day's main category, then the rest, each group
    /// in catalog order.
    private struct RankKey: Comparable {
        let isOffSport: Bool
        let isOffCategory: Bool
        let catalogIndex: Int

        init(_ exercise: LibraryExercise, catalogIndex: Int, sports: Set<String>, main: ExerciseCategory) {
            isOffSport = sports.isDisjoint(with: exercise.sports)
            isOffCategory = exercise.category != main
            self.catalogIndex = catalogIndex
        }

        static func < (lhs: RankKey, rhs: RankKey) -> Bool {
            if lhs.isOffSport != rhs.isOffSport { return rhs.isOffSport }
            if lhs.isOffCategory != rhs.isOffCategory { return rhs.isOffCategory }
            return lhs.catalogIndex < rhs.catalogIndex
        }
    }

    static func sportTag(for sport: String) -> String? {
        let lowered = sport.lowercased()
        let tags = [
            ("tennis", ["tennis", "pickleball", "padel", "squash", "badminton"]), ("running", ["run", "marathon"]),
            ("soccer", ["soccer", "football"]), ("climbing", ["climb", "boulder"]),
        ]
        return tags.first { _, words in words.contains { lowered.contains($0) } }?.0
    }
}
