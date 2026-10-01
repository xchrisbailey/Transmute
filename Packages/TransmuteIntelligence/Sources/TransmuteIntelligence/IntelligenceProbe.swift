import FoundationModels
import TransmuteCore

/// A small structured result for the debug screen: proves streaming, guided generation and the
/// library tool work end to end on a device, without brewing a whole plan.
@Generable
public struct WarmUpProbe: Sendable, Equatable {
    @Guide(description: "A short title for the warm-up.")
    public var title: String

    @Guide(description: "Three warm-up moves from the library.", .count(3))
    public var moves: [Move]

    @Generable
    public struct Move: Sendable, Equatable {
        @Guide(description: "The exercise id exactly as findExercises returned it.")
        public var exerciseID: String

        @Guide(description: "How long or how many, e.g. 10 reps or 30 seconds.")
        public var dose: String
    }
}

extension WarmUpProbe {
    /// The request the debug screen sends.
    public static func request(focus: String, library: ExerciseLibrary = .bundled) -> IntelligenceRequest {
        IntelligenceRequest(
            instructions: PlannerInstructions.make(experience: .beginner),
            prompt: "Build a short warm-up of three moves before a session focused on \(focus).",
            tools: [ExerciseLookupTool(library: library, scope: ExerciseQuery(categories: [.mobility, .power]))],
            maximumResponseTokens: 400)
    }
}
