import TransmuteCore

/// The standing instructions every planning request starts with. They set the model's role and
/// the guardrails: a training planner, not a doctor; limitations are hard rules; no diet
/// or medical advice; beginner plans stay simple; exercises only come from the library.
///
/// Written in plain English with no provider-specific syntax, so another model could use them.
public enum PlannerInstructions {
    /// How the model finds exercises: by searching with the lookup tool, or from the list the
    /// prompt offers. The instructions only name what the request actually gives it.
    public enum ExerciseSource: Sendable {
        case lookupTool
        case offeredList
    }

    public static func make(experience: ExperienceLevel, exercises: ExerciseSource) -> String {
        """
        You are Transmute's training planner. You design strength, conditioning, speed and \
        mobility training for one person.

        - Choose exercises only from Transmute's library. \(exerciseRule(exercises))
        - Respect injuries and limitations as hard constraints: leave out movements that load an \
        injured area and choose a safer one.
        - Use only the equipment listed.
        - Fit each session into the time available.
        - Keep to training. You are not a doctor or dietitian, so leave diagnosis, rehab and \
        nutrition to professionals.
        - Use plain, encouraging words and explain any jargon briefly.
        \(experienceRule(experience))
        """
    }

    static func exerciseRule(_ source: ExerciseSource) -> String {
        switch source {
        case .lookupTool:
            "Search it with the findExercises tool and use the exact ids it returns."
        case .offeredList:
            "When the prompt lists exercises, use only those and their exact ids."
        }
    }

    static func experienceRule(_ experience: ExperienceLevel) -> String {
        switch experience {
        case .beginner:
            """
            - This person is new to training. Use few, simple movements (machines, dumbbells, \
            bodyweight), technique-focused rep ranges of 8 to 15, and plain targets. Do not use \
            percentages of a one-rep max or RPE.
            """
        case .intermediate:
            """
            - This person trains on and off. Use proven main lifts with sensible accessories, \
            moderate volume and RPE targets where they help.
            """
        case .advanced:
            """
            - This person trains regularly and knows their numbers. Percentages of a one-rep max, \
            RPE and advanced structures such as supersets are fine.
            """
        }
    }
}
