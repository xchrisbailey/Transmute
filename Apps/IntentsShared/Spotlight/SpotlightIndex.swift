import AppIntents
import CoreSpotlight
import OSLog
import SwiftData
import SwiftUI
import TransmuteCore

extension View {
    /// Keeps logged workouts and plans in Spotlight (#19). The index is rebuilt once at
    /// launch, which also clears anything deleted on another device meanwhile; after that
    /// each save of the store indexes what changed and takes out what was deleted.
    func indexesSpotlight() -> some View {
        modifier(SpotlightIndexing())
    }
}

private struct SpotlightIndexing: ViewModifier {
    @Environment(\.modelContext) private var context
    /// Bumped by each save; the task below waits for saves to settle before it reads.
    @State private var saves = 0

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
                saves += 1
            }
            .task(id: saves) {
                // Logging a set saves too. Wait out a burst rather than index on each one.
                guard (try? await Task.sleep(for: .seconds(saves == 0 ? 0 : 2))) != nil else { return }
                await SpotlightIndex.shared.update(from: context)
            }
    }
}

/// What Transmute has put in Spotlight this launch, so each update only sends the changes.
@MainActor
final class SpotlightIndex {
    static let shared = SpotlightIndex()

    private static let logger = Logger(subsystem: Transmute.bundlePrefix, category: "spotlight")
    /// The text indexed for each workout and plan. `nil` until the first rebuild.
    private var workouts: [UUID: String]?
    private var plans: [UUID: String]?

    func update(from context: ModelContext) async {
        do {
            let workouts = try WorkoutQuery.finished(in: context)
            self.workouts = try await send(workouts, text: workouts.map(\.indexedText), indexed: self.workouts)
            let plans = try PlanQuery.all(in: context)
            self.plans = try await send(plans, text: plans.map(\.indexedText), indexed: self.plans)
        } catch {
            Self.logger.error("Couldn't update Spotlight: \(error)")
        }
    }

    /// Sends one type's changes and returns what's indexed now. The first pass clears the
    /// type and indexes everything; so does deleting the last item.
    private func send<Entity: IndexedEntity>(_ entities: [Entity], text: [String], indexed: [UUID: String]?)
        async throws -> [UUID: String]
    where Entity.ID == UUID {
        let current = Dictionary(zip(entities.map(\.id), text)) { $1 }
        let changes = IndexChanges(indexed: indexed ?? [:], current: current)
        let index = CSSearchableIndex.default()
        if indexed == nil || (entities.isEmpty && !changes.removed.isEmpty) {
            try await index.deleteAppEntities(ofType: Entity.self)
        } else if !changes.removed.isEmpty {
            try await index.deleteAppEntities(identifiedBy: Array(changes.removed), ofType: Entity.self)
        }
        let updated = entities.filter { changes.updated.contains($0.id) }
        if !updated.isEmpty {
            try await index.indexAppEntities(updated)
        }
        return current
    }
}
