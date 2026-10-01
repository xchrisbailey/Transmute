import FoundationModels
import Synchronization
import TransmuteCore

/// Lets the model search Transmute's exercise library, so plans only use real exercise ids.
///
/// Results are already limited to what the person can do: their equipment, their level, and
/// anything their limitations rule out. The model never sees an exercise it couldn't pick.
public struct ExerciseLookupTool: Tool {
    public let name = "findExercises"
    public let description = """
        Searches Transmute's exercise library. Returns matching exercises as "id: name \
        (category, pattern)". Use the exact id in the plan.
        """

    public let library: ExerciseLibrary
    /// The base query every search starts from: equipment, difficulty and sport.
    public let scope: ExerciseQuery
    /// Ids the plan must not use, e.g. because of an injury.
    public let excludedIDs: Set<String>
    public let maxResults: Int
    /// Searches allowed per request. The small on-device model sometimes searches in a loop
    /// until it runs out of context; past this the tool throws `SearchLimitReached`, which
    /// ends the attempt quickly so it can be retried.
    public let maxCalls: Int
    private let calls = CallCounter()

    public init(
        library: ExerciseLibrary = .bundled, scope: ExerciseQuery = ExerciseQuery(), excludedIDs: Set<String> = [],
        maxResults: Int = 8, maxCalls: Int = 4
    ) {
        self.library = library
        self.scope = scope
        self.excludedIDs = excludedIDs
        self.maxResults = maxResults
        self.maxCalls = maxCalls
    }

    /// How many times the model has searched with this tool.
    public var callCount: Int {
        calls.value
    }

    @Generable
    public struct Arguments {
        @Guide(description: "Words to look for in exercise names, e.g. squat or lateral lunge. Empty to browse.")
        public var search: String

        @Guide(
            description: "Category to narrow to, or any.", .anyOf(["any"] + ExerciseCategory.allCases.map(\.rawValue)))
        public var category: String

        @Guide(
            description: "Movement pattern to narrow to, or any.",
            .anyOf(["any"] + MovementPattern.allCases.map(\.rawValue)))
        public var pattern: String

        public init(search: String, category: String = "any", pattern: String = "any") {
            self.search = search
            self.category = category
            self.pattern = pattern
        }
    }

    @concurrent public func call(arguments: Arguments) async throws -> String {
        guard calls.increment() <= maxCalls else {
            throw SearchLimitReached()
        }
        let results = search(arguments)
        guard !results.isEmpty else {
            return "No exercises match. Try fewer words, or search by category or pattern instead."
        }
        return results.map { "\($0.id): \($0.name) (\($0.category.rawValue), \($0.pattern.rawValue))" }
            .joined(separator: "\n")
    }

    /// Thrown when the model keeps searching past `maxCalls`.
    public struct SearchLimitReached: Error {}

    /// The exercises a call returns. When the words match nothing, the filters alone are tried,
    /// so the model always gets something to choose from.
    public func search(_ arguments: Arguments) -> [LibraryExercise] {
        var query = scope
        if let category = ExerciseCategory(rawValue: arguments.category) { query.categories = [category] }
        if let pattern = MovementPattern(rawValue: arguments.pattern) { query.patterns = [pattern] }
        query.text = arguments.search
        var results = library.search(query).filter { !excludedIDs.contains($0.id) }
        if results.isEmpty, !query.text.isEmpty {
            query.text = ""
            results = library.search(query).filter { !excludedIDs.contains($0.id) }
        }
        return Array(results.prefix(maxResults))
    }
}

/// A thread-safe count, so the tool can stay a `Sendable` value.
final class CallCounter: Sendable {
    private let count = Mutex(0)

    var value: Int {
        count.withLock { $0 }
    }

    /// Adds one and returns the new count.
    func increment() -> Int {
        count.withLock { value in
            value += 1
            return value
        }
    }
}
