import FoundationModels
import TransmuteCore

/// Answers instantly with plausible content, for SwiftUI previews and tests: a fixed blueprint,
/// and days built from the first exercises each request offers.
public struct PreviewIntelligenceService: IntelligenceService {
    public let providerName = "Apple Intelligence"
    public var availability: IntelligenceAvailability
    public var blueprint: PlanBlueprint

    public init(availability: IntelligenceAvailability = .available, blueprint: PlanBlueprint = .preview) {
        self.availability = availability
        self.blueprint = blueprint
    }

    public func stream<Content: Generable & Sendable>(_ request: IntelligenceRequest, generating type: Content.Type)
        -> AsyncThrowingStream<GenerationUpdate<Content>, any Error>
    {
        let content = answer(request, type)
        return AsyncThrowingStream { continuation in
            guard availability.canGenerate else {
                continuation.finish(throwing: IntelligenceError.unavailable(availability))
                return
            }
            guard let content else {
                continuation.finish(throwing: IntelligenceError.malformedOutput)
                return
            }
            continuation.yield(.partial(content.asPartiallyGenerated()))
            continuation.yield(.complete(content))
            continuation.finish()
        }
    }

    private func answer<Content: Generable>(_ request: IntelligenceRequest, _ type: Content.Type) -> Content? {
        if type == PlanBlueprint.self {
            var blueprint = blueprint
            if let days = request.arrayCounts["days"] {
                blueprint.days = (0..<days).map { blueprint.days[$0 % blueprint.days.count] }
            }
            return blueprint as? Content
        }
        if type == DayDraft.self {
            let ids = request.allowedValues["exerciseID"] ?? []
            let count = min(ids.count, request.arrayCounts["exercises"] ?? 4)
            let exercises = ids.prefix(count).map { id in
                ExerciseDraft(
                    exerciseID: id, sets: 3, reps: 8, seconds: 30, meters: 20, effort: "steady", restSeconds: 90,
                    supersetWithPrevious: false, note: "")
            }
            return DayDraft(why: "Build a steady base.", exercises: Array(exercises)) as? Content
        }
        return nil
    }
}

extension PlanBlueprint {
    public static let preview = PlanBlueprint(
        name: "Court-ready strength", goalSummary: "Power and first-step speed for tennis",
        rationale: "Heavy lifting sits early in the week so you're fresh for Saturday's match.",
        phases: [
            Phase(name: "Build", weeks: 3, focus: "Base strength"),
            Phase(name: "Power", weeks: 4, focus: "Speed and power"),
        ],
        days: [
            DayOutline(focus: "Lower strength", kind: DayKind.lowerStrength.rawValue, intensity: "hard"),
            DayOutline(focus: "Upper strength", kind: DayKind.upperStrength.rawValue, intensity: "moderate"),
            DayOutline(focus: "Speed and power", kind: DayKind.powerSpeed.rawValue, intensity: "hard"),
            DayOutline(focus: "Conditioning", kind: DayKind.conditioning.rawValue, intensity: "moderate"),
        ])
}
