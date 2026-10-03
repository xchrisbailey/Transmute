import Foundation
import FoundationModels
import Testing

@testable import TransmuteIntelligence

struct WeekSummaryTests {
    static let strongWeek = WeekSummaryInput(
        sessionsDone: 4, sessionsPlanned: 4, volume: "8,420 kg", volumeChangePercent: 6,
        records: ["Back squat 5RM, 115 kg"], wentUp: ["Bench press est. max 92.5 → 95 kg"], streakWeeks: 5,
        goal: "Hit harder serves by spring")
    static let stalledWeek = WeekSummaryInput(
        sessionsDone: 3, sessionsPlanned: 3, volume: "6,100 kg", volumeChangePercent: -12,
        stalled: ["Overhead press", "Barbell row"])
    static let lightWeek = WeekSummaryInput(sessionsDone: 1, sessionsPlanned: 4, volume: "2,050 kg")
    static let emptyWeek = WeekSummaryInput(sessionsDone: 0, sessionsPlanned: 4, streakWeeks: 3)

    @Test func templateCelebratesAStrongWeek() {
        let summary = WeekSummaryWriter.template(Self.strongWeek)
        #expect(summary.headline == "A week turned to gold.")
        #expect(
            summary.lines == [
                "You did all 4 planned sessions.", "Total volume was 8,420 kg, up 6% on last week.",
                "New record: Back squat 5RM, 115 kg.", "Moving up: Bench press est. max 92.5 → 95 kg.",
            ])
        #expect(!summary.suggestsRework)
        #expect(!summary.isFromAI)
    }

    @Test func templateOffersAReworkWhenLiftsStall() {
        let summary = WeekSummaryWriter.template(Self.stalledWeek)
        #expect(summary.suggestsRework)
        #expect(summary.headline == "A full week, distilled.")
        #expect(
            summary.lines == [
                "You did all 3 planned sessions.", "Total volume was 6,100 kg, down 12% on last week.",
                "Holding steady and ready for a fresh approach: Overhead press, Barbell row.",
            ])
    }

    @Test func templateNeverShamesALightWeek() {
        let summary = WeekSummaryWriter.template(Self.lightWeek)
        #expect(summary.lines == ["You got 1 of 4 planned sessions in.", "Total volume was 2,050 kg."])
        #expect(summary.suggestsRework, "Under half the planned sessions were done")
        let text = ([summary.headline] + summary.lines).joined(separator: " ").lowercased()
        for word in ["missed", "failed", "only", "should have"] {
            #expect(!text.contains(word), "\(word) reads as guilt")
        }
        #expect(!WeekSummaryWriter.template(WeekSummaryInput(sessionsDone: 2, sessionsPlanned: 4)).suggestsRework)
    }

    @Test func templateHasWordsForAnEmptyWeek() {
        #expect(Self.emptyWeek.isEmpty)
        #expect(!Self.lightWeek.isEmpty)
        let summary = WeekSummaryWriter.template(Self.emptyWeek)
        #expect(summary.headline == "A quiet week.")
        #expect(summary.lines.count == 2)
        #expect(!summary.isFromAI)
        let text = summary.lines.joined(separator: " ").lowercased()
        for word in ["missed", "failed", "only", "should have"] {
            #expect(!text.contains(word), "\(word) reads as guilt")
        }
    }

    @Test func templateKeepsToFourLinesAndAlwaysHasTwo() {
        var busy = Self.strongWeek
        busy.stalled = ["Overhead press"]
        busy.records = ["A", "B", "C", "D", "E"]
        let summary = WeekSummaryWriter.template(busy)
        #expect(summary.lines.count == 4)
        #expect(summary.lines.contains("New records: A; B; C; and 2 more."))
        #expect(summary.lines.contains { $0.contains("Overhead press") }, "Stalls outrank volume and streak")
        #expect(WeekSummaryWriter.template(WeekSummaryInput(sessionsDone: 1, sessionsPlanned: 0)).lines.count == 2)
    }

    @Test func modelWritesTheSummaryWhenAvailable() async {
        let summary = await WeekSummaryWriter(service: PreviewIntelligenceService()).write(Self.stalledWeek)
        #expect(summary.isFromAI)
        #expect(summary.headline == "Your week, distilled.")
        #expect(summary.lines.first == "Sessions done: 3 of 3 planned.")
        #expect((2...4).contains(summary.lines.count))
        #expect(summary.suggestsRework, "Decided by rule from the input, whoever writes the words")
    }

    @Test func promptCarriesTheFactsAndStaysShort() {
        let request = WeekSummaryWriter.request(Self.strongWeek)
        for fact in [
            "4 of 4 planned", "8,420 kg, up 6%", "Back squat 5RM, 115 kg", "92.5 → 95 kg", "5 weeks", "serves",
        ] {
            #expect(request.prompt.contains(fact), "\(fact)")
        }
        #expect(ContextBudget.estimatedTokens(in: request.instructions + request.prompt) < 600)
    }

    @Test func fallsBackWhenTheModelIsUnavailable() async {
        for state in [IntelligenceAvailability.turnedOff, .modelNotReady, .deviceNotEligible] {
            let writer = WeekSummaryWriter(service: PreviewIntelligenceService(availability: state))
            #expect(await writer.write(Self.strongWeek) == WeekSummaryWriter.template(Self.strongWeek))
        }
    }

    @Test func emptyWeeksSkipTheModel() async {
        let service = DraftService(draft: WeekSummaryDraft(headline: "Gold!", lines: ["You did it.", "Well done."]))
        #expect(
            await WeekSummaryWriter(service: service).write(Self.emptyWeek)
                == .some(WeekSummaryWriter.template(Self.emptyWeek)))
    }

    @Test func fallsBackWhenTheModelThrowsOrRefuses() async {
        for error in [IntelligenceError.guardrail, .refused(explanation: "No"), .failed(detail: "boom")] {
            let writer = WeekSummaryWriter(service: DraftService(error: error))
            #expect(await writer.write(Self.strongWeek) == WeekSummaryWriter.template(Self.strongWeek))
        }
    }

    @Test func rejectsNumbersThatAreNotInTheFacts() async {
        let invented = WeekSummaryDraft(
            headline: "A week turned to gold.", lines: ["You did all 4 sessions.", "Your squat reached 120 kg."])
        let writer = WeekSummaryWriter(service: DraftService(draft: invented))
        #expect(await writer.write(Self.strongWeek) == WeekSummaryWriter.template(Self.strongWeek))

        // Part of a real number is still an invented one.
        let partial = WeekSummaryDraft(headline: "Distilled.", lines: ["You lifted 420 kg.", "You did 4 sessions."])
        #expect(await WeekSummaryWriter(service: DraftService(draft: partial)).write(Self.strongWeek).isFromAI == false)
    }

    @Test func acceptsAndTidiesAGoodDraft() async {
        let draft = WeekSummaryDraft(
            headline: "  Four sessions, turned to gold. ",
            lines: [
                " You did 4 of 4 planned sessions. ", "", "Volume reached 8,420 kg, up 6%.",
                "Bench press went from 92.5 to 95 kg.", "Back squat 5RM is now 115 kg.", "That makes 5 weeks in a row.",
            ])
        let summary = await WeekSummaryWriter(service: DraftService(draft: draft)).write(Self.strongWeek)
        #expect(summary.isFromAI)
        #expect(summary.headline == "Four sessions, turned to gold.")
        #expect(summary.lines.count == 4)
        #expect(summary.lines.first == "You did 4 of 4 planned sessions.")
        #expect(!summary.lines.contains(""))
    }

    @Test func rejectsDraftsThatBreakTheShape() {
        func accepted(_ headline: String, _ lines: [String]) -> Bool {
            let facts = WeekSummaryWriter.request(Self.lightWeek).prompt
            let draft = WeekSummaryDraft(headline: headline, lines: lines)
            return WeekSummaryWriter.validated(draft, facts: facts, input: Self.lightWeek) != nil
        }
        #expect(accepted("A start, distilled.", ["You got a session in.", "Next week is open."]))
        #expect(!accepted(" ", ["You got a session in.", "Next week is open."]))
        #expect(!accepted("A start.", ["You got a session in.", "  "]), "One line is too few")
        #expect(!accepted("A start.", ["You got a session in.", String(repeating: "long ", count: 40)]))
        #expect(!accepted(String(repeating: "long ", count: 20), ["You got a session in.", "Next week is open."]))
        #expect(!accepted("A start.", ["You only got 1 session in.", "Next week is open."]), "Guilt wording")
        #expect(!accepted("A start.", ["You missed 3 sessions.", "Next week is open."]))
    }
}

/// Plays back one draft, or throws, in place of the model.
struct DraftService: IntelligenceService {
    let providerName = "Draft"
    let availability = IntelligenceAvailability.available
    var draft: WeekSummaryDraft?
    var error: IntelligenceError = .malformedOutput

    func stream<Content: Generable & Sendable>(_ request: IntelligenceRequest, generating type: Content.Type)
        -> AsyncThrowingStream<GenerationUpdate<Content>, any Error>
    {
        AsyncThrowingStream { continuation in
            guard let content = draft as? Content else {
                continuation.finish(throwing: error)
                return
            }
            continuation.yield(.complete(content))
            continuation.finish()
        }
    }
}

/// The real model writes a week. Runs with the other model tests: `scripts/eval-intelligence.sh`.
@Suite(.enabled(if: ModelTesting.isEnabled), .serialized)
struct WeekSummaryModelTests {
    @Test(arguments: [WeekSummaryTests.strongWeek, WeekSummaryTests.stalledWeek, WeekSummaryTests.lightWeek])
    func writesAWeekFromItsFacts(_ input: WeekSummaryInput) async throws {
        let service = FoundationModelsService(settings: IntelligenceSettings())
        let request = WeekSummaryWriter.request(input)
        let draft = try await service.respond(request, generating: WeekSummaryDraft.self)
        print("SUMMARY draft: \(draft.headline) | \(draft.lines.joined(separator: " | "))")
        let summary = try #require(
            WeekSummaryWriter.validated(draft, facts: request.prompt, input: input), "The draft was rejected")
        #expect(summary.isFromAI)
        #expect((2...4).contains(summary.lines.count))
        #expect(summary.suggestsRework == input.suggestsRework)
    }
}
