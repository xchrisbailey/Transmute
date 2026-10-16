import Foundation
import FoundationModels
import Testing
import TransmuteCore

@testable import TransmuteIntelligence

/// Records every request a brew sends, so prompts can be pinned as well as plans.
final class RecordingService: IntelligenceService, @unchecked Sendable {
    let providerName = "Recording"
    let availability = IntelligenceAvailability.available
    private let inner: PreviewIntelligenceService
    private let lock = NSLock()
    private var recorded: [String] = []

    init(blueprint: PlanBlueprint = .preview) {
        inner = PreviewIntelligenceService(blueprint: blueprint)
    }

    var requests: [String] { lock.withLock { recorded } }

    func stream<Content: Generable & Sendable>(_ request: IntelligenceRequest, generating type: Content.Type)
        -> AsyncThrowingStream<GenerationUpdate<Content>, any Error>
    {
        let allowed = request.allowedValues.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }
        let counts = request.arrayCounts.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }
        lock.withLock {
            recorded.append(
                [request.instructions, request.prompt, allowed.joined(separator: ";"), counts.joined(separator: ";")]
                    .joined(separator: "\n--\n"))
        }
        return inner.stream(request, generating: type)
    }
}

/// Pins what a brew writes: the plan and every prompt, for each example brief in both unit
/// systems. A digest keeps the pin small; when it changes, the failure shows the new one.
struct PlanGoldenTests {
    static let steadyBlueprint = PlanBlueprint(
        name: "Steady strength", goalSummary: "Get stronger", rationale: "Lift, recover, repeat.",
        phases: [
            .init(name: "Build", weeks: 3, focus: "Base strength"),
            .init(name: "Peak", weeks: 4, focus: "Heavier work"),
        ],
        days: [
            .init(focus: "Lower strength", kind: DayKind.lowerStrength.rawValue, intensity: "hard"),
            .init(focus: "Upper strength", kind: DayKind.upperStrength.rawValue, intensity: "moderate"),
            .init(focus: "Full body", kind: DayKind.fullBody.rawValue, intensity: "hard"),
            .init(focus: "Mobility", kind: DayKind.mobility.rawValue, intensity: "light"),
        ])

    static let sportBlueprint = PlanBlueprint(
        name: "Court and cardio", goalSummary: "Move faster and last longer", rationale: "Power, then engine.",
        phases: [
            .init(name: "Build", weeks: 3, focus: "Base"),
            .init(name: "Peak", weeks: 4, focus: "Speed"),
        ],
        days: [
            .init(focus: "Power and speed", kind: DayKind.powerSpeed.rawValue, intensity: "hard"),
            .init(focus: "Conditioning", kind: DayKind.conditioning.rawValue, intensity: "moderate"),
            .init(focus: "Lower strength", kind: DayKind.lowerStrength.rawValue, intensity: "moderate"),
            .init(focus: "Upper strength", kind: DayKind.upperStrength.rawValue, intensity: "moderate"),
        ])

    static func snapshot(
        _ brief: TrainingBrief, units: UnitSystem, blueprint: PlanBlueprint = steadyBlueprint
    ) async throws -> String {
        let service = RecordingService(blueprint: blueprint)
        var plan: BrewedPlan?
        for try await progress in PlanBrewer(service: service).brew(brief, units: units) {
            if case .finished(let finished) = progress { plan = finished }
        }
        let brewed = try #require(plan)
        let days = brewed.days.map { String(describing: $0) }.joined(separator: "\n")
        return "\(brewed.name)|\(brewed.phases)|\(brewed.weekCount)\n\(days)\n"
            + service.requests.joined(separator: "\n====\n")
    }

    static func digest(_ text: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3
        }
        return String(hash, radix: 16)
    }

    static let examples: [(name: String, brief: TrainingBrief, blueprint: PlanBlueprint)] = {
        var withLifts = TrainingBrief.experiencedLifter
        withLifts.knownLifts = [
            KnownLift(exerciseID: "back-squat", weightKg: 140, reps: 5),
            KnownLift(exerciseID: "bench-press", weightKg: 100, reps: 5),
            KnownLift(exerciseID: "romanian-deadlift", weightKg: 160, reps: 5),
        ]
        var matchWeek = TrainingBrief.tennisPlayer
        matchWeek.sports = []
        matchWeek.goalTags = [.strength]
        var shortSessions = matchWeek
        shortSessions.schedule.sessionMinutes = 30
        var longPlan = TrainingBrief.experiencedLifter
        longPlan.schedule.weeks = 12
        var shortPlan = TrainingBrief.kneeInjury
        shortPlan.schedule.weeks = 2
        let steady = [
            ("experienced lifter", TrainingBrief.experiencedLifter), ("lifter with known lifts", withLifts),
            ("knee injury", .kneeInjury), ("knee injury 2 weeks", shortPlan), ("lifter 12 weeks", longPlan),
            ("match week", matchWeek), ("match week 30 minutes", shortSessions),
        ].map { ($0.0, $0.1, steadyBlueprint) }
        let sport = [
            ("tennis player", TrainingBrief.tennisPlayer), ("weight loss beginner", .weightLossBeginner),
            ("runner", .runner),
        ].map { ($0.0, $0.1, sportBlueprint) }
        return steady + sport
    }()

    static let expected: [String: String] = [
        "experienced lifter imperial": "1388a4854ab7cd04",
        "experienced lifter metric": "1388a4854ab7cd04",
        "knee injury 2 weeks imperial": "b1c5daec6ad79a4b",
        "knee injury 2 weeks metric": "b1c5daec6ad79a4b",
        "knee injury imperial": "1c6a1a137d0fc04e",
        "knee injury metric": "1c6a1a137d0fc04e",
        "lifter 12 weeks imperial": "994a3ce94bd66b3c",
        "lifter 12 weeks metric": "994a3ce94bd66b3c",
        "lifter with known lifts imperial": "26712844ac99e8d7",
        "lifter with known lifts metric": "2cf1cf34ef5bf994",
        "match week 30 minutes imperial": "92eb6cb46508d626",
        "match week 30 minutes metric": "92eb6cb46508d626",
        "match week imperial": "ced6606bb1e876eb",
        "match week metric": "ced6606bb1e876eb",
        "runner imperial": "4fdf43233271ca8d",
        "runner metric": "4fdf43233271ca8d",
        "tennis player imperial": "fb70cd263d72caa7",
        "tennis player metric": "fb70cd263d72caa7",
        "weight loss beginner imperial": "6566f63f3ce18929",
        "weight loss beginner metric": "6566f63f3ce18929",
    ]

    @Test(arguments: examples)
    func brewsTheSamePlanAndPrompts(
        _ example: (name: String, brief: TrainingBrief, blueprint: PlanBlueprint)
    ) async throws {
        for (label, units) in [("metric", UnitSystem.metric), ("imperial", .imperial)] {
            let text = try await Self.snapshot(example.brief, units: units, blueprint: example.blueprint)
            let key = "\(example.name) \(label)"
            #expect(Self.digest(text) == Self.expected[key], "\(key): \(Self.digest(text))")
        }
    }
}
