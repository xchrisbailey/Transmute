import AppIntents
import CoreSpotlight
import OSLog
import SwiftData
import TransmuteCore

/// Keeps logged workouts and plans in Spotlight, and what Transmute has put there this launch,
/// so each update only sends the changes. The index is rebuilt once at launch, which also clears
/// anything deleted on another device meanwhile; after that each save of the store indexes what
/// changed and takes out what was deleted.
@MainActor
final class SpotlightIndex {
    static let shared = SpotlightIndex()
    static let settleDelay = Duration.seconds(2)

    private static let logger = Logger(subsystem: Transmute.bundlePrefix, category: "spotlight")
    /// The text indexed for each workout and plan. `nil` until the first rebuild.
    private var workouts: [UUID: String]?
    private var plans: [UUID: String]?
    private var observer: NSObjectProtocol?
    private var pending: Task<Void, Never>?

    /// Starts indexing after each save of the store. Call it once from an `App`'s `init`, so it's
    /// listening before an App Intent that launched the process in the background saves: no
    /// view needs to be on screen. A burst of saves, as a workout logs sets, settles into one update.
    func listen() {
        guard observer == nil else { return }
        schedule(after: .zero)
        observer = NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: nil, queue: nil) {
            [weak self] _ in
            Task { @MainActor in self?.schedule(after: Self.settleDelay) }
        }
    }

    private func schedule(after delay: Duration) {
        pending?.cancel()
        pending = Task {
            guard (try? await Task.sleep(for: delay)) != nil else { return }
            await update(from: TransmuteStore.shared.mainContext)
        }
    }

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

    /// Sends one type's changes and returns what's indexed now.
    private func send<Entity: IndexedEntity>(_ entities: [Entity], text: [String], indexed: [UUID: String]?)
        async throws -> [UUID: String]
    where Entity.ID == UUID {
        let current = Dictionary(zip(entities.map(\.id), text)) { $1 }
        let changes = IndexChanges(indexed: indexed, current: current)
        let index = CSSearchableIndex.default()
        if changes.isFullReset {
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
