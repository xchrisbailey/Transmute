import AppIntents
import CoreSpotlight
import SwiftData
import TransmuteCore
import TransmuteUI

/// A logged workout as Shortcuts, Spotlight and Apple Intelligence see it (#19): its name,
/// when it was, and a line such as "6 exercises · 8,420 kg".
struct WorkoutEntity: AppEntity, IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource(
            "plain.shortcut.workout.type", defaultValue: "Workout",
            comment: "plain. What a logged workout is called in Shortcuts and Spotlight."))
    static let defaultQuery = WorkoutQuery()

    /// The workout's own `Workout.id`, the same on every device.
    let id: UUID

    @Property(
        title: LocalizedStringResource(
            "plain.shortcut.workout.name", defaultValue: "Name",
            comment: "plain. Shortcuts, the name of a logged workout."))
    var name: String

    @Property(
        title: LocalizedStringResource(
            "plain.shortcut.workout.date", defaultValue: "Date",
            comment: "plain. Shortcuts, when a workout was done."))
    var date: Date

    /// Exercises and volume, e.g. "6 exercises · 8,420 kg".
    let summary: String

    init(_ workout: Workout, units: Units) {
        id = workout.id
        summary = ShortcutCopy.workoutSummary(WorkoutSummary(workout), units: units)
        name = workout.title
        date = workout.startedAt
    }

    /// The date, then the summary: "Mon 28 Sep · 6 exercises · 8,420 kg".
    var subtitle: String {
        "\(date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))) · \(summary)"
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)", subtitle: "\(subtitle)", image: .init(systemName: "figure.strength.training.traditional")
        )
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.contentDescription = subtitle
        attributes.contentCreationDate = date
        return attributes
    }

    /// What the index holds for this workout; a change means indexing it again.
    var indexedText: String {
        "\(name)\n\(date.timeIntervalSinceReferenceDate)\n\(summary)"
    }
}

/// Finds logged workouts by id, and suggests the most recent ones.
struct WorkoutQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [WorkoutEntity] {
        let wanted = Set(identifiers)
        return try Self.finished(in: TransmuteStore.shared.mainContext).filter { wanted.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [WorkoutEntity] {
        try Self.finished(in: TransmuteStore.shared.mainContext, limit: 12)
    }

    /// Finished workouts, newest first. One still running isn't in the log yet.
    @MainActor
    static func finished(in context: ModelContext, limit: Int? = nil) throws -> [WorkoutEntity] {
        var descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.endedAt != nil }, sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        descriptor.fetchLimit = limit
        let units = Units(system: try context.fetch(FetchDescriptor<Profile>()).first?.unitSystem)
        return try context.fetch(descriptor).map { WorkoutEntity($0, units: units) }
    }
}

/// "Open workout": brings the app to one logged workout, from Spotlight or a shortcut.
struct OpenWorkoutIntent: OpenIntent {
    static let title = LocalizedStringResource(
        "plain.shortcut.workout.open", defaultValue: "Open workout",
        comment: "plain. Shortcut that shows one logged workout in the app.")
    static let supportedModes: IntentModes = .foreground

    @Parameter(
        title: LocalizedStringResource(
            "plain.shortcut.workout.type", defaultValue: "Workout",
            comment: "plain. What a logged workout is called in Shortcuts and Spotlight."))
    var target: WorkoutEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        DeepLinkRouter.shared.open(.workout(target.id))
        return .result()
    }
}
