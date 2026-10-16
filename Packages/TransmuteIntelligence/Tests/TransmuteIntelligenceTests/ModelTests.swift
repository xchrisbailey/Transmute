import Evaluations
import Foundation
import FoundationModels
import Testing
import TransmuteCore

@testable import TransmuteIntelligence

/// Tests that call the real model. They're slow and the output varies, so they only run when
/// asked: `scripts/eval-intelligence.sh`, on a Mac with Apple Intelligence turned on.
enum ModelTesting {
    static let isEnabled =
        ProcessInfo.processInfo.environment["TRANSMUTE_MODEL_TESTS"] == "1" && SystemLanguageModel.default.isAvailable
}

@Suite(.enabled(if: ModelTesting.isEnabled), .serialized)
struct ModelTests {
    let library = ExerciseLibrary.bundled

    @Test func debugProbeStreamsRealExercises() async throws {
        var partials = 0
        var result: WarmUpProbe?
        let service = FoundationModelsService(settings: IntelligenceSettings())
        let request = WarmUpProbe.request(focus: "legs")
        for try await update in service.stream(request, generating: WarmUpProbe.self) {
            switch update {
            case .partial: partials += 1
            case .complete(let content): result = content
            }
        }
        let probe = try #require(result)
        #expect(partials > 1, "Partial snapshots should stream in")
        #expect(probe.moves.count == 3)
        for move in probe.moves {
            #expect(library.exercise(id: move.exerciseID) != nil, "\(move.exerciseID) isn't in the library")
        }
    }

    @Test func requestsAreCountedWithTheRealTokenizer() async throws {
        let brief = TrainingBrief.tennisPlayer
        let service = FoundationModelsService(settings: IntelligenceSettings())
        let tokens = try await service.tokenCount(
            instructions: PlannerInstructions.make(experience: brief.experience, exercises: .lookupTool),
            prompt: brief.promptDescription,
            tools: [ExerciseLookupTool()])
        #expect(tokens > 100)
        #expect(ContextBudget.onDevice.fits(promptTokens: tokens))
    }

    @Test(.evaluates(DayDraftEvaluation()))
    func dayDraftsRespectEveryPerson() async throws {
        let result = EvaluationContext.current.result
        #expect(!result.errors.hasFailures, "\(result.errors)\n\(result.detailed)")
        for metric in DayDraftEvaluation.metrics {
            let passRate = result.aggregateValue(.mean(of: metric))
            #expect(passRate >= 0.8, "\(metric.name) passed \(passRate)")
        }
    }
}

struct BriefSample: SampleProtocol {
    var name: String
    var brief: TrainingBrief
    var forbiddenPatterns: Set<MovementPattern>
    var expected: DayDraft? { nil }
    var input: String { name }
}

/// The evaluation: for each person, write a full-body day the way `PlanBrewer` does and check the
/// schema held, every id is real, the kit fits, limitations are respected and nothing repeats.
struct DayDraftEvaluation: Evaluation {
    static let validIDs = Metric("validIDs")
    static let equipmentFits = Metric("equipmentFits")
    static let limitationsRespected = Metric("limitationsRespected")
    static let variety = Metric("variety")
    static let metrics = [validIDs, equipmentFits, limitationsRespected, variety]

    var dataset: ArrayLoader<BriefSample> {
        ArrayLoader(
            samples: TrainingBrief.evaluationSet.map { name, brief in
                BriefSample(
                    name: name, brief: brief,
                    forbiddenPatterns: brief.limitations.contains("knee") ? [.jump, .lunge, .sprint] : [])
            })
    }

    func subject(from sample: BriefSample) async throws -> ModelSubject<DayDraft> {
        let brief = sample.brief
        let brewer = PlanBrewer(service: PreviewIntelligenceService())
        let spec = PlanBrewer.DaySpec(
            phase: PlanPhase(name: "Build", focus: "Base", firstWeek: 1, lastWeek: 3),
            outline: .init(focus: "Full body", kind: DayKind.fullBody.rawValue, intensity: "moderate"),
            weekday: 1, kind: .fullBody)
        let request = brewer.dayRequest(
            brief, spec: spec, offered: DayShortlist.candidates(for: .fullBody, brief: brief))
        let draft = try await FoundationModelsService(settings: IntelligenceSettings())
            .respond(request, generating: DayDraft.self)
        return ModelSubject(value: draft)
    }

    var evaluators: Evaluators {
        Evaluator<BriefSample> { _, subject in
            let unknown = ids(subject).filter { ExerciseLibrary.bundled.exercise(id: $0) == nil }
            return unknown.isEmpty ? Self.validIDs.passing() : Self.validIDs.failing(rationale: "\(unknown)")
        }
        Evaluator<BriefSample> { sample, subject in
            let misfits = exercises(subject).filter { !$0.isDoable(with: sample.brief.equipment) }.map(\.id)
            return misfits.isEmpty ? Self.equipmentFits.passing() : Self.equipmentFits.failing(rationale: "\(misfits)")
        }
        Evaluator<BriefSample> { sample, subject in
            let broken = exercises(subject).filter { sample.forbiddenPatterns.contains($0.pattern) }.map(\.id)
            return broken.isEmpty
                ? Self.limitationsRespected.passing() : Self.limitationsRespected.failing(rationale: "\(broken)")
        }
        Evaluator<BriefSample> { _, subject in
            let ids = ids(subject)
            return Set(ids).count == ids.count ? Self.variety.passing() : Self.variety.failing(rationale: "\(ids)")
        }
    }

    func aggregateMetrics(using aggregator: inout MetricsAggregator) {
        for metric in Self.metrics {
            aggregator.computeMean(of: metric)
        }
    }

    private func ids(_ subject: ModelSubject<DayDraft>) -> [String] {
        subject.value.exercises.map(\.exerciseID)
    }

    private func exercises(_ subject: ModelSubject<DayDraft>) -> [LibraryExercise] {
        ids(subject).compactMap(ExerciseLibrary.bundled.exercise(id:))
    }
}
