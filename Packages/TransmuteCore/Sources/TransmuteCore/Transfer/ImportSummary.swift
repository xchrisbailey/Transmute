/// What an import did, for the screen to report back.
public struct ImportSummary: Equatable, Sendable {
    /// How many of one kind of thing were added, and how many were already in the store.
    public struct Count: Equatable, Sendable {
        public var added = 0
        public var skipped = 0

        public init(added: Int = 0, skipped: Int = 0) {
            self.added = added
            self.skipped = skipped
        }
    }

    /// Where the data came from.
    public enum Source: String, Equatable, Sendable {
        case backup, strong, hevy
    }

    public enum ProfileOutcome: Equatable, Sendable {
        /// The file had no profile.
        case absent
        /// The store had none, so the file's profile was added.
        case added
        /// The store already had one, and its settings were left alone.
        case kept
    }

    public var source: Source
    public var profile = ProfileOutcome.absent
    public var bodyweights = Count()
    public var customExercises = Count()
    public var plans = Count()
    public var workouts = Count()
    /// Sets inside the workouts that were added.
    public var setsAdded = 0
    /// Records added. Records are derived from sets, so none are ever skipped.
    public var recordsAdded = 0
    /// Exercise names in a CSV that matched nothing in the library, in the order they appeared.
    /// Each one became a custom exercise.
    public var unmatchedExerciseNames: [String] = []
    /// CSV rows that couldn't be read, e.g. without a date or an exercise name.
    public var unreadableRows = 0

    public init(source: Source) {
        self.source = source
    }

    /// Whether the import changed the store at all.
    public var addedAnything: Bool {
        profile == .added || setsAdded > 0 || recordsAdded > 0
            || [bodyweights, customExercises, plans, workouts].contains { $0.added > 0 }
    }
}
