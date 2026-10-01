import Testing
import TransmuteCore

@testable import TransmuteIntelligence

struct PlanningPromptTests {
    @Test func instructionsCarryTheGuardrails() {
        let text = PlannerInstructions.make(experience: .intermediate)
        #expect(text.contains("not a doctor or dietitian"))
        #expect(text.contains("findExercises"))
        #expect(text.contains("hard constraints"))
        #expect(text.contains("nutrition to professionals"))
    }

    @Test func beginnersGetPlainTargets() {
        #expect(PlannerInstructions.make(experience: .beginner).contains("Do not use percentages"))
        #expect(!PlannerInstructions.make(experience: .advanced).contains("Do not use percentages"))
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
        let prompt = PlannerInstructions.make(experience: brief.experience) + brief.promptDescription
        #expect(ContextBudget.onDevice.fits(promptTokens: ContextBudget.estimatedTokens(in: prompt)))
    }
}
