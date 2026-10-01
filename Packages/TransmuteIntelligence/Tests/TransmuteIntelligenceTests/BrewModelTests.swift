import Foundation
import FoundationModels
import Testing
import TransmuteCore

@testable import TransmuteIntelligence

/// The #9 "done when": every person in the evaluation set, including both epic examples,
/// brews a valid plan on-device in reasonable time.
@Suite(.enabled(if: ModelTesting.isEnabled), .serialized)
struct BrewModelTests {
    @Test(arguments: TrainingBrief.evaluationSet)
    func brewsAValidPlan(_ name: String, _ brief: TrainingBrief) async throws {
        let brewer = PlanBrewer(service: FoundationModelsService(settings: IntelligenceSettings()))
        let clock = ContinuousClock()
        let start = clock.now
        var plan: BrewedPlan?
        for try await progress in brewer.brew(brief, units: .imperial) {
            if case .finished(let finished) = progress { plan = finished }
        }
        let brewed = try #require(plan)
        let elapsed = clock.now - start
        print("BREW \(name) in \(elapsed): \(brewed.name). \(brewed.rationale)")
        print("BREW phases: \(brewed.phases.map { "\($0.name) \($0.firstWeek)-\($0.lastWeek)" })")
        for day in brewed.days(inWeek: 1) {
            let names = day.exercises.map {
                "\(ExerciseLibrary.bundled.exercise(id: $0.exerciseID)!.name) \($0.sets.count)x\($0.sets[0].reps ?? 0)"
            }
            let minutes = Int(PlanAssembler.estimatedMinutes(day.exercises))
            print(
                "BREW  \(TrainingBrief.weekdayName(day.weekday)) \(day.focus) [\(day.kind.rawValue)] \(minutes)m: \(names)"
            )
        }
        let problems = PlanCheck.problems(in: brewed, brief: brief)
        #expect(problems.isEmpty, "\(problems)")
        #expect(elapsed < .seconds(240))
    }
}
