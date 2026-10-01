import Observation
import TransmuteIntelligence

/// The AI's availability as a screen sees it. While the model is downloading it checks again
/// every few seconds, so brewing becomes possible without the user doing anything.
@MainActor @Observable
public final class IntelligenceStatus {
    public private(set) var availability: IntelligenceAvailability
    public let service: any IntelligenceService

    public init(service: any IntelligenceService) {
        self.service = service
        self.availability = service.availability
    }

    public func refresh() {
        availability = service.availability
    }

    /// Re-checks while waiting would help. Run from a view's `.task` so it stops with the view.
    public func watch(every interval: Duration = .seconds(3)) async {
        refresh()
        while !availability.canGenerate, !Task.isCancelled {
            try? await Task.sleep(for: interval)
            refresh()
        }
    }
}
