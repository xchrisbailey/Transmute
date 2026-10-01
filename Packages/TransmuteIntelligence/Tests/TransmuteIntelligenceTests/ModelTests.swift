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
            instructions: PlannerInstructions.make(experience: brief.experience), prompt: brief.promptDescription,
            tools: [ExerciseLookupTool()])
        #expect(tokens > 100)
        #expect(ContextBudget.onDevice.fits(promptTokens: tokens))
    }

    @Test(.evaluates(SessionSketchEvaluation()))
    func sessionSketchesRespectEveryPerson() async throws {
        let result = EvaluationContext.current.result
        #expect(!result.errors.hasFailures, "\(result.errors)\n\(result.detailed)")
        for metric in SessionSketchEvaluation.metrics {
            let passRate = result.aggregateValue(.mean(of: metric))
            #expect(passRate >= 0.8, "\(metric.name) passed \(passRate)")
        }
    }
}

/// One training session, sketched. The evaluation's stand-in for a plan day until #9 brings
/// the full plan schema.
@Generable
struct SessionSketch: Codable, Sendable {
    @Guide(description: "A short name for the session's focus.")
    var focus: String

    @Guide(description: "Exercise ids from the list, in the order they are done.", .count(4...7))
    var exerciseIDs: [String]
}

/// A person from the evaluation set, and the movement patterns their limitations rule out.
struct BriefSample: SampleProtocol {
    var name: String
    var brief: TrainingBrief
    var forbiddenPatterns: Set<MovementPattern>
    var expected: SessionSketch? { nil }
    var input: String { name }
}

/// The #8 evaluation: for each person, sketch a session and check the schema held, every id is
/// real, the kit fits, limitations are respected and nothing repeats.
struct SessionSketchEvaluation: Evaluation {
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

    func subject(from sample: BriefSample) async throws -> ModelSubject<SessionSketch> {
        let brief = sample.brief
        let candidates = ExerciseCandidates(scope: brief.exerciseScope)
        let request = IntelligenceRequest(
            instructions: PlannerInstructions.make(experience: brief.experience),
            prompt: """
                Sketch the first training session of a plan for this person.

                \(brief.promptDescription)

                Choose exercises from this list:
                \(candidates.promptList)
                """,
            allowedValues: candidates.constraint, maximumResponseTokens: 600)
        let sketch = try await FoundationModelsService(settings: IntelligenceSettings())
            .respond(request, generating: SessionSketch.self)
        return ModelSubject(value: sketch)
    }

    var evaluators: Evaluators {
        Evaluator<BriefSample> { _, subject in
            let unknown = subject.value.exerciseIDs.filter { ExerciseLibrary.bundled.exercise(id: $0) == nil }
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
            let ids = subject.value.exerciseIDs
            return Set(ids).count == ids.count ? Self.variety.passing() : Self.variety.failing(rationale: "\(ids)")
        }
    }

    func aggregateMetrics(using aggregator: inout MetricsAggregator) {
        for metric in Self.metrics {
            aggregator.computeMean(of: metric)
        }
    }

    private func exercises(_ subject: ModelSubject<SessionSketch>) -> [LibraryExercise] {
        subject.value.exerciseIDs.compactMap(ExerciseLibrary.bundled.exercise(id:))
    }
}
