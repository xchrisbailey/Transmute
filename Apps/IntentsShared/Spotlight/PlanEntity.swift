import AppIntents
import CoreSpotlight
import SwiftData
import TransmuteCore
import TransmuteUI

struct PlanEntity: AppEntity, IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource(
            "plain.shortcut.plan.type", defaultValue: "Plan",
            comment: "plain. What a training plan is called in Shortcuts and Spotlight."))
    static let defaultQuery = PlanQuery()

    let id: UUID

    @Property(
        title: LocalizedStringResource(
            "plain.shortcut.plan.name", defaultValue: "Name", comment: "plain. Shortcuts, the name of a plan."))
    var name: String

    @Property(
        title: LocalizedStringResource(
            "plain.shortcut.plan.goal", defaultValue: "Goal", comment: "plain. Shortcuts, what a plan is for."))
    var goal: String

    init(_ plan: Plan) {
        id = plan.id
        name = plan.name
        goal = ShortcutCopy.planSummary(goal: plan.goalSummary, weeks: plan.weekCount)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(goal)", image: .init(systemName: "calendar"))
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.contentDescription = goal
        return attributes
    }

    /// What the index holds for this plan; a change means indexing it again.
    var indexedText: String {
        "\(name)\n\(goal)"
    }
}

struct PlanQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [PlanEntity] {
        let wanted = Set(identifiers)
        return try Self.all(in: TransmuteStore.shared.mainContext).filter { wanted.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [PlanEntity] {
        try Self.all(in: TransmuteStore.shared.mainContext)
    }

    /// Every plan with a name, the active one first, then newest first.
    @MainActor
    static func all(in context: ModelContext) throws -> [PlanEntity] {
        let plans = try context.fetch(FetchDescriptor<Plan>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
        return (plans.filter(\.isActive) + plans.filter { !$0.isActive })
            .filter { !$0.name.isEmpty }
            .map(PlanEntity.init)
    }
}

/// The app shows the active plan there; an older plan is one step away in its history.
struct OpenPlanIntent: OpenIntent {
    static let title = LocalizedStringResource(
        "plain.shortcut.plan.open", defaultValue: "Open plan",
        comment: "plain. Shortcut that shows the plan in the app.")
    static let supportedModes: IntentModes = .foreground

    @Parameter(
        title: LocalizedStringResource(
            "plain.shortcut.plan.type", defaultValue: "Plan",
            comment: "plain. What a training plan is called in Shortcuts and Spotlight."))
    var target: PlanEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        DeepLinkRouter.shared.open(.plan)
        return .result()
    }
}
