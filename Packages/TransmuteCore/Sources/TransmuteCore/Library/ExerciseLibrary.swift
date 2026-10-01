import Foundation

/// Filters for searching the library. Empty sets don't filter.
public struct ExerciseQuery: Hashable, Sendable {
    /// Matched against names and aliases, ignoring case, accents and punctuation.
    public var text: String
    public var categories: Set<ExerciseCategory>
    public var patterns: Set<MovementPattern>
    /// Matches primary or secondary muscles.
    public var muscles: Set<Muscle>
    /// Matches exercises that use any of these.
    public var equipment: Set<Equipment>
    /// Only exercises doable with this kit. `nil` doesn't filter.
    public var availableEquipment: Set<Equipment>?
    public var sports: Set<String>
    public var tracking: Set<TrackingType>
    /// Hides exercises above this level.
    public var maxDifficulty: ExperienceLevel?

    public init(
        text: String = "", categories: Set<ExerciseCategory> = [], patterns: Set<MovementPattern> = [],
        muscles: Set<Muscle> = [], equipment: Set<Equipment> = [], availableEquipment: Set<Equipment>? = nil,
        sports: Set<String> = [], tracking: Set<TrackingType> = [], maxDifficulty: ExperienceLevel? = nil
    ) {
        self.text = text
        self.categories = categories
        self.patterns = patterns
        self.muscles = muscles
        self.equipment = equipment
        self.availableEquipment = availableEquipment
        self.sports = sports
        self.tracking = tracking
        self.maxDifficulty = maxDifficulty
    }
}

/// The bundled catalog plus the user's custom exercises, with lookup and search.
///
/// Plans only ever reference exercises that are in here; the AI picks from it (#9) and the
/// picker searches it (#10).
public struct ExerciseLibrary: Sendable {
    public let catalogVersion: Int
    public let exercises: [LibraryExercise]
    private let byID: [String: Int]
    /// Folded name and aliases per exercise, in the same order as `exercises`.
    private let searchKeys: [[String]]

    public init(catalogVersion: Int, exercises: [LibraryExercise]) {
        self.catalogVersion = catalogVersion
        self.exercises = exercises
        self.byID = Dictionary(exercises.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.searchKeys = exercises.map { exercise in
            ([exercise.name] + exercise.aliases).map(Self.fold)
        }
    }

    /// The catalog that ships in the app.
    public static let bundled: ExerciseLibrary = {
        do {
            return try load(from: Bundle.module.url(forResource: "exercises", withExtension: "json")!)
        } catch {
            preconditionFailure("The bundled exercise catalog is unreadable: \(error)")
        }
    }()

    public static func load(from url: URL) throws -> ExerciseLibrary {
        let catalog = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))
        return ExerciseLibrary(catalogVersion: catalog.version, exercises: catalog.exercises)
    }

    struct Catalog: Codable {
        let version: Int
        let exercises: [LibraryExercise]
    }

    /// This library with the user's custom exercises added after the catalog.
    public func adding(_ custom: [LibraryExercise]) -> ExerciseLibrary {
        let fresh = custom.filter { byID[$0.id] == nil }
        return ExerciseLibrary(catalogVersion: catalogVersion, exercises: exercises + fresh)
    }

    public func exercise(id: String) -> LibraryExercise? {
        byID[id].map { exercises[$0] }
    }

    /// Exercises matching every filter. With text, the best name matches come first;
    /// otherwise catalog order is kept.
    public func search(_ query: ExerciseQuery) -> [LibraryExercise] {
        let terms = Self.fold(query.text).split(separator: " ").map(String.init)
        var matches: [(score: Int, index: Int)] = []
        for (index, exercise) in exercises.enumerated() where passesFilters(exercise, query) {
            if terms.isEmpty {
                matches.append((0, index))
            } else if let score = Self.score(keys: searchKeys[index], terms: terms) {
                matches.append((score, index))
            }
        }
        return matches.sorted { ($0.score, $0.index) < ($1.score, $1.index) }.map { exercises[$0.index] }
    }

    private func passesFilters(_ exercise: LibraryExercise, _ query: ExerciseQuery) -> Bool {
        if !query.categories.isEmpty, !query.categories.contains(exercise.category) { return false }
        if !query.patterns.isEmpty, !query.patterns.contains(exercise.pattern) { return false }
        if !query.tracking.isEmpty, !query.tracking.contains(exercise.tracking) { return false }
        if !query.sports.isEmpty, query.sports.isDisjoint(with: exercise.sports) { return false }
        if !query.equipment.isEmpty, query.equipment.isDisjoint(with: exercise.allEquipment) { return false }
        if !query.muscles.isEmpty,
            query.muscles.isDisjoint(with: exercise.primaryMuscles + exercise.secondaryMuscles)
        {
            return false
        }
        if let available = query.availableEquipment, !exercise.isDoable(with: available) { return false }
        if let max = query.maxDifficulty, exercise.difficulty.rank > max.rank { return false }
        return true
    }

    /// Lower is better: 0 for an exact name, 1 for a prefix, 2 when every term starts a word,
    /// 3 when every term appears somewhere. `nil` when a term is missing.
    static func score(keys: [String], terms: [String]) -> Int? {
        let phrase = terms.joined(separator: " ")
        var best: Int?
        for key in keys {
            let words = key.split(separator: " ")
            let score: Int?
            if key == phrase {
                score = 0
            } else if key.hasPrefix(phrase) {
                score = 1
            } else if terms.allSatisfy({ term in words.contains { $0.hasPrefix(term) } }) {
                score = 2
            } else if terms.allSatisfy({ key.contains($0) }) {
                score = 3
            } else {
                score = nil
            }
            if let score, score < (best ?? .max) { best = score }
        }
        return best
    }

    /// Lowercased, without accents or apostrophes, with other punctuation as spaces:
    /// "Farmer's carry" → "farmers carry", "90/90 hip switch" → "90 90 hip switch".
    static func fold(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\u{2019}", with: "")
        let spaced = folded.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
        return String(spaced).split(separator: " ").joined(separator: " ")
    }
}

extension ExperienceLevel {
    var rank: Int {
        switch self {
        case .beginner: 0
        case .intermediate: 1
        case .advanced: 2
        }
    }
}
