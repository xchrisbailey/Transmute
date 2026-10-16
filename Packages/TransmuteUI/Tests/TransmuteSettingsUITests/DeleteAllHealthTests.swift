import Foundation
import SwiftData
import Testing

@testable import TransmuteCore
@testable import TransmuteSettingsUI

/// What delete-all leaves in `UserDefaults` for the session link's Health deletes.
@MainActor
struct DeleteAllHealthTests {
    /// Health as the iPhone sees it: it holds these workouts until a delete removes them.
    final class RecordingHealth: HealthService, @unchecked Sendable {
        private let lock = NSLock()
        private var held: Set<UUID>
        init(holding ids: Set<UUID>) { held = ids }
        var workouts: Set<UUID> { lock.withLock { held } }

        var isAvailable: Bool { true }
        var canSaveBodyweight: Bool { true }
        func requestAccess(_ scope: HealthAccessScope) async throws {}
        func accessStatus() async -> HealthAccessStatus { HealthAccessStatus() }
        func bodyMetrics() async -> HealthBodyMetrics { HealthBodyMetrics() }
        func bodyweights(since date: Date) async -> [HealthBodyweight] { [] }
        func restingHeartRate() async -> Double? { nil }
        func vo2Max() async -> Double? { nil }
        func otherWorkouts(in interval: DateInterval) async -> [OtherWorkout] { [] }
        func save(_ workout: HealthWorkoutRecord) async throws -> UUID { UUID() }
        func saveBodyweight(kg: Double, at date: Date) async throws -> UUID { UUID() }
        func deleteWorkout(id: UUID) async throws { lock.withLock { _ = held.remove(id) } }
    }

    @Test func aLaunchRetryAfterDeleteAllDeletesNothingFromHealth() async throws {
        let suite = "settings-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let container = try SampleData.previewContainer()
        // A Health delete the link left pending, for a workout the person had deleted in History.
        let (phonesID, watchID, workoutID) = (UUID(), UUID(), UUID())
        let pending = PendingHealthDeletes(defaults: defaults)
        pending.add(.init(workoutID: workoutID, keep: watchID, remove: phonesID))
        pending.markDeleted(workoutID)
        let health = RecordingHealth(holding: [phonesID, watchID])

        try await DataEraser.eraseEverything(
            in: container, link: nil, defaults: defaults, clearsNotifications: false)
        let relaunched = SessionLink(live: UnavailableLiveWorkout(), device: .phone, defaults: defaults)
        await relaunched.retryPendingDeletes(with: health, in: container.mainContext)

        #expect(health.workouts == [phonesID, watchID])
        #expect(PendingHealthDeletes(defaults: defaults).entries.isEmpty)
        #expect(PendingHealthDeletes(defaults: defaults).deletedWorkouts.isEmpty)
    }
}
