import Testing
import TransmuteCore

@testable import TransmuteIntelligence

struct PlanningPromptTests {
    @Test func instructionsCarryTheGuardrails() {
        let text = PlannerInstructions.make(experience: .intermediate, exercises: .offeredList)
        #expect(text.contains("not a doctor or dietitian"))
        #expect(text.contains("hard constraints"))
        #expect(text.contains("nutrition to professionals"))
    }

    @Test func instructionsNameFindExercisesOnlyWhenTheToolIsPassed() {
        let withTool = PlannerInstructions.make(experience: .intermediate, exercises: .lookupTool)
        let withList = PlannerInstructions.make(experience: .intermediate, exercises: .offeredList)
        #expect(withTool.contains("findExercises"))
        #expect(!withList.contains("findExercises"))
        #expect(withList.contains("exact ids"))
    }

    @Test func brewRequestsPassNoToolAndDontNameOne() {
        let brewer = PlanBrewer(service: PreviewIntelligenceService())
        let brief = TrainingBrief.tennisPlayer
        let spec = PlanBrewer.DaySpec(
            phase: PlanPhase(name: "Build", focus: "Base", firstWeek: 1, lastWeek: 3),
            outline: .init(focus: "Day", kind: DayKind.fullBody.rawValue, intensity: "hard"), weekday: 1,
            kind: .fullBody)
        let requests = [
            brewer.blueprintRequest(brief, days: [1, 3, 5]),
            brewer.dayRequest(brief, spec: spec, offered: DayShortlist.candidates(for: .fullBody, brief: brief)),
        ]
        for request in requests {
            #expect(request.makeTools().isEmpty)
            #expect(!request.instructions.contains("findExercises"))
        }
    }

    @Test func warmUpProbePassesTheLookupToolAndNamesIt() {
        let request = WarmUpProbe.request(focus: "legs")
        #expect(request.makeTools().map(\.name) == ["findExercises"])
        #expect(request.instructions.contains("findExercises"))
    }

    @Test func beginnersGetPlainTargets() {
        let beginner = PlannerInstructions.make(experience: .beginner, exercises: .offeredList)
        let advanced = PlannerInstructions.make(experience: .advanced, exercises: .offeredList)
        #expect(beginner.contains("Do not use percentages"))
        #expect(!advanced.contains("Do not use percentages"))
    }

    @Test func briefDescribesTheTennisPlayer() {
        let text = TrainingBrief.tennisPlayer.promptDescription
        #expect(text.contains("175 cm"))
        #expect(text.contains("79 kg"))
        #expect(text.contains("Sport: tennis"))
        #expect(text.contains("Fixed commitment: Match on Saturday (hard)"))
        #expect(text.contains("Training days: Monday, Tuesday, Thursday, Friday"))
    }

    @Test func briefSaysBodyweightOnlyWhenThereIsNoKit() {
        let brief = TrainingBrief(equipment: [])
        #expect(brief.promptDescription.contains("Equipment: bodyweight only"))
        #expect(brief.promptDescription.contains("Limitations: none"))
    }

    @Test func budgetLeavesRoomForTheResponse() {
        let budget = ContextBudget.onDevice
        #expect(budget.promptAllowance == 5_192)
        #expect(budget.fits(promptTokens: 5_000))
        #expect(!budget.fits(promptTokens: 6_000))
        #expect(ContextBudget.estimatedTokens(in: String(repeating: "a", count: 300)) >= 75)
    }

    @Test(arguments: TrainingBrief.evaluationSet.map(\.brief))
    func everyEvaluationPromptFitsOnDevice(_ brief: TrainingBrief) {
        let instructions = PlannerInstructions.make(experience: brief.experience, exercises: .offeredList)
        let prompt = instructions + brief.promptDescription
        #expect(ContextBudget.onDevice.fits(promptTokens: ContextBudget.estimatedTokens(in: prompt)))
    }
}
