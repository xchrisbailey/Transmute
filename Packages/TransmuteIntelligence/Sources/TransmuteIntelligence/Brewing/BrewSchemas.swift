import FoundationModels

// The structures the model fills in when brewing a plan (#9). Generation happens in two
// stages to fit the on-device context: a blueprint for the whole plan, then each training day
// of each phase. Numbers the plan depends on, such as loads and week-to-week progression, are
// worked out by rules afterwards, not by the model.

/// Stage 1: the outline of the plan.
@Generable
public struct PlanBlueprint: Sendable, Equatable {
    @Guide(description: "A short, motivating plan name of two to five words, e.g. Court-ready strength.")
    public var name: String

    @Guide(description: "The goal in one short phrase, e.g. Power and first-step speed for tennis.")
    public var goalSummary: String

    @Guide(
        description:
            "One sentence on why this plan fits the person, mentioning their schedule or goal, e.g. Heavy lifting sits early in the week so you're fresh for Saturday's match."
    )
    public var rationale: String

    @Guide(
        description: "The phases in order, e.g. build, strength, power. The last can be a lighter deload.",
        .count(1...4))
    public var phases: [Phase]

    @Guide(description: "One entry per training day, in the order of the training days listed.")
    public var days: [DayOutline]

    @Generable
    public struct Phase: Sendable, Equatable {
        @Guide(description: "One or two words, e.g. Build, Strength, Power or Deload.")
        public var name: String

        @Guide(description: "How many weeks this phase lasts.", .range(1...8))
        public var weeks: Int

        @Guide(description: "What this phase works on, in a short phrase.")
        public var focus: String
    }

    @Generable
    public struct DayOutline: Sendable, Equatable {
        @Guide(description: "A short name for the day, e.g. Lower strength or Speed and agility.")
        public var focus: String

        @Guide(description: "The kind of session.", .anyOf(DayKind.allCases.map(\.rawValue)))
        public var kind: String

        @Guide(description: "How demanding the session is.", .anyOf(["light", "moderate", "hard"]))
        public var intensity: String
    }
}

/// Stage 2: one training day.
@Generable
public struct DayDraft: Sendable, Equatable {
    @Guide(
        description:
            "One plain sentence for the person on what today is for, e.g. Build leg strength for quicker pushes off the baseline."
    )
    public var why: String

    @Guide(description: "The exercises in the order they're done.", .count(3...8))
    public var exercises: [ExerciseDraft]
}

@Generable
public struct ExerciseDraft: Sendable, Equatable {
    @Guide(description: "The exercise id from the list.")
    public var exerciseID: String

    @Guide(description: "Working sets.", .range(1...6))
    public var sets: Int

    @Guide(description: "Reps per set, for exercises counted in reps. Zero if timed.", .range(0...30))
    public var reps: Int

    @Guide(
        description: "Seconds of work per set, for holds, intervals and timed drills. Zero if counted in reps.",
        .range(0...600))
    public var seconds: Int

    @Guide(description: "Distance in metres for sprints, shuttles, carries or rows. Zero otherwise.", .range(0...5000))
    public var meters: Int

    @Guide(description: "How hard each set should feel.", .anyOf(Effort.allCases.map(\.rawValue)))
    public var effort: String

    @Guide(description: "Rest after each set, in seconds.", .range(15...300))
    public var restSeconds: Int

    @Guide(description: "True to pair it with the previous exercise as a superset.")
    public var supersetWithPrevious: Bool

    @Guide(description: "One short coaching cue for this person, or empty.")
    public var note: String
}

/// The session types a blueprint day can be. Each decides which library exercises the model is
/// offered for that day.
public enum DayKind: String, CaseIterable, Sendable {
    case lowerStrength = "lower strength"
    case upperStrength = "upper strength"
    case fullBody = "full body strength"
    case powerSpeed = "power and speed"
    case conditioning
    case mobility = "mobility and recovery"
}

extension DayKind {
    /// A day name for when rules, not the model, add the day.
    public var defaultFocus: String {
        switch self {
        case .lowerStrength: "Lower strength"
        case .upperStrength: "Upper strength"
        case .fullBody: "Full body strength"
        case .powerSpeed: "Speed and power"
        case .conditioning: "Conditioning"
        case .mobility: "Mobility and recovery"
        }
    }
}

/// How hard a set should feel, in words a beginner understands. Mapped to RPE for people who
/// use it.
public enum Effort: String, CaseIterable, Sendable {
    case easy, steady, hard, veryHard = "very hard"

    /// Rate of perceived exertion, out of 10.
    public var rpe: Double {
        switch self {
        case .easy: 6
        case .steady: 7
        case .hard: 8
        case .veryHard: 9
        }
    }
}
