import Foundation
import SwiftData

extension SessionLink {
    /// What the watch said about Health for the workout this device ended last.
    enum WatchReply: Equatable {
        case healthWorkout(UUID)
        case nothingSaved
    }

    /// The Health side of the workout this device ended last. It outlives `owned`, so the
    /// watch's answer can still land after the workout ended.
    @MainActor
    final class Ending {
        let workoutID: UUID
        let context: ModelContext?
        /// Whether the watch was recording this workout when it ended, so it will answer with a
        /// Health id or a `nil`. This is a fact about the workout, not about the connection now:
        /// the watch's session may have closed by the time the person taps Save.
        let expectsWatchReply: Bool
        var health: (any HealthService)?
        var reply: WatchReply?
        /// The Health workout the iPhone saved itself, until the watch's replaces it.
        var phoneSaved: UUID?
        /// The save in flight, so a second call joins it instead of starting another.
        var saving: Task<Void, any Error>?
        private var waiter: CheckedContinuation<Void, Never>?
        private var timer: Task<Void, Never>?

        init(workoutID: UUID, context: ModelContext?, expectsWatchReply: Bool) {
            self.workoutID = workoutID
            self.context = context
            self.expectsWatchReply = expectsWatchReply
        }

        /// Returns when the watch answers, or after `timeout` on `clock`.
        func awaitReply(timeout: Duration, clock: any Clock<Duration>) async {
            guard reply == nil else { return }
            await withCheckedContinuation { continuation in
                waiter = continuation
                timer = Task {
                    try? await clock.sleep(for: timeout)
                    guard !Task.isCancelled else { return }
                    resumeWaiter()
                }
            }
        }

        func resumeWaiter() {
            timer?.cancel()
            timer = nil
            waiter?.resume()
            waiter = nil
        }
    }
}
