import Foundation
import FoundationModels

/// What the model fills in for the weekly summary. Small on purpose: the model only chooses
/// words, and every number in them is checked against the facts it was given.
@Generable
public struct WeekSummaryDraft: Sendable, Equatable {
    @Guide(description: "One short headline sentence for the week, e.g. A steady week, distilled.")
    public var headline: String

    @Guide(description: "Short, plain sentences about the week, each built on one of the facts.", .count(2...4))
    public var lines: [String]
}

/// Writes "This week, distilled" (#16): by the model when it's available, by a template when it
/// isn't, the week is empty, or the model's draft doesn't hold up.
public struct WeekSummaryWriter: Sendable {
    public var service: any IntelligenceService

    public init(service: any IntelligenceService) {
        self.service = service
    }

    static let maxLines = 4
    static let minLines = 2
    static let maxHeadlineLength = 80
    static let maxLineLength = 160
    /// How many items of each list go in the prompt, to keep it short.
    static let maxFactItems = 5
    static let maxGoalLength = 200
    /// Words that read as guilt about a light week. A draft using one is dropped.
    static let guiltWords = ["missed", "failed", "only", "should have"]

    /// The summary for the week. Never fails: anything that goes wrong gives the template.
    public func write(_ input: WeekSummaryInput) async -> WeekSummary {
        guard service.availability.canGenerate, !input.isEmpty else { return Self.template(input) }
        return (try? await writeWithModel(input)) ?? Self.template(input)
    }

    /// The model's summary, checked. Throws when the model fails or its draft is rejected.
    func writeWithModel(_ input: WeekSummaryInput) async throws -> WeekSummary {
        let request = Self.request(input)
        let draft = try await service.respond(request, generating: WeekSummaryDraft.self)
        guard let summary = Self.validated(draft, facts: request.prompt, input: input) else {
            throw IntelligenceError.malformedOutput
        }
        return summary
    }

    /// The deterministic summary, used when AI is off and whenever the model's draft is rejected.
    public static func template(_ input: WeekSummaryInput) -> WeekSummary {
        typealias Copy = WeekSummaryCopy
        guard !input.isEmpty else {
            return WeekSummary(
                headline: Copy.quietHeadline, lines: [Copy.nothingLogged, Copy.readyWhenYouAre],
                suggestsRework: input.suggestsRework, isFromAI: false)
        }
        // In reading order. When there are too many, the lowest ranks are the ones kept.
        var candidates = [(rank: 0, text: Copy.adherence(done: input.sessionsDone, planned: input.sessionsPlanned))]
        if let volume = input.volume?.trimmingCharacters(in: .whitespaces), !volume.isEmpty {
            candidates.append((4, Copy.volume(volume, changePercent: input.volumeChangePercent)))
        }
        if !input.records.isEmpty { candidates.append((1, Copy.records(input.records))) }
        if !input.wentUp.isEmpty { candidates.append((3, Copy.wentUp(input.wentUp))) }
        if !input.stalled.isEmpty { candidates.append((2, Copy.stalled(input.stalled))) }
        if input.streakWeeks >= 2 { candidates.append((5, Copy.streak(weeks: input.streakWeeks))) }
        let kept = Set(candidates.map(\.rank).sorted().prefix(maxLines))
        var lines = candidates.filter { kept.contains($0.rank) }.map(\.text)
        if lines.count < minLines { lines.append(Copy.keepGoing) }
        return WeekSummary(
            headline: headline(input), lines: lines, suggestsRework: input.suggestsRework, isFromAI: false)
    }

    static func headline(_ input: WeekSummaryInput) -> String {
        if !input.records.isEmpty { return WeekSummaryCopy.recordsHeadline }
        if input.sessionsPlanned > 0, input.sessionsDone >= input.sessionsPlanned {
            return WeekSummaryCopy.fullWeekHeadline
        }
        return WeekSummaryCopy.headline
    }
}

// MARK: - The model's request

extension WeekSummaryWriter {
    /// Written in plain English with no provider-specific syntax, and as what to do rather than
    /// what to avoid: prohibitions made the on-device model refuse ordinary requests.
    static let instructions = """
        You write the weekly training summary in Transmute, a workout log, for one person.

        - Speak to the person as "you", in plain, warm, encouraging words.
        - Build every sentence on the facts given, and copy numbers exactly as they are written there.
        - Keep to training. Health and medical questions belong to professionals.
        - Describe a light week by what was done, then look ahead.
        - The sentences stay plain. The headline may carry one light touch of alchemy.
        """

    /// Marks a fact line in the prompt.
    static let factPrefix = "- "

    static func request(_ input: WeekSummaryInput) -> IntelligenceRequest {
        IntelligenceRequest(
            instructions: instructions,
            prompt: """
                Write this week's summary: a headline and 2 to 4 short sentences.
                \(headlineHint(input))

                Facts:
                \(facts(input).map { factPrefix + $0 }.joined(separator: "\n"))
                """,
            temperature: 0.6, maximumResponseTokens: 300)
    }

    /// Offers the brand's alchemy voice for the headline. Gold is kept for weeks with records;
    /// offered every week, the model used it every week.
    static func headlineHint(_ input: WeekSummaryInput) -> String {
        input.records.isEmpty
            ? "For the headline, a word such as distilled fits, e.g. A steady week, distilled."
            : "For the headline, the new records can be turned to gold, e.g. A week turned to gold."
    }

    /// The week as short labelled lines. These hold the only numbers the model may use.
    static func facts(_ input: WeekSummaryInput) -> [String] {
        var facts = [
            input.sessionsPlanned > 0
                ? "Sessions done: \(input.sessionsDone) of \(input.sessionsPlanned) planned"
                : "Sessions done: \(input.sessionsDone)"
        ]
        if let volume = input.volume?.trimmingCharacters(in: .whitespaces), !volume.isEmpty {
            facts.append("Total volume: \(volume)\(volumeChange(input.volumeChangePercent))")
        }
        for (label, items) in [("New records", input.records), ("Went up", input.wentUp)] where !items.isEmpty {
            facts.append("\(label): \(items.prefix(maxFactItems).joined(separator: "; "))")
        }
        if !input.stalled.isEmpty {
            facts.append("Stalled exercises: \(input.stalled.prefix(maxFactItems).joined(separator: ", "))")
        }
        if input.streakWeeks >= 2 { facts.append("Streak: \(input.streakWeeks) weeks in a row") }
        let goal = input.goal.split(whereSeparator: \.isNewline).joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        if !goal.isEmpty { facts.append("Their goal: \(goal.prefix(maxGoalLength))") }
        return facts
    }

    static func volumeChange(_ percent: Int?) -> String {
        guard let percent else { return "" }
        if percent == 0 { return ", level with last week" }
        return percent > 0 ? ", up \(percent)% on last week" : ", down \(-percent)% on last week"
    }
}

// MARK: - Checking the draft

extension WeekSummaryWriter {
    /// The draft as a summary, or nil when it breaks a rule: a number that isn't in the facts,
    /// a blank or overlong headline, too few lines, an overlong line, or guilt wording.
    static func validated(_ draft: WeekSummaryDraft, facts: String, input: WeekSummaryInput) -> WeekSummary? {
        let headline = draft.headline.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = draft.lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            .prefix(maxLines)
        guard !headline.isEmpty, headline.count <= maxHeadlineLength, lines.count >= minLines,
            lines.allSatisfy({ $0.count <= maxLineLength })
        else { return nil }
        let text = ([headline] + lines).joined(separator: "\n")
        guard numbers(in: text).isSubset(of: numbers(in: facts)), !soundsGuilty(text) else { return nil }
        return WeekSummary(
            headline: headline, lines: Array(lines), suggestsRework: input.suggestsRework, isFromAI: true)
    }

    /// Every number in the text, as written: digits, with any separators between them, so
    /// "8,420" and "92.5" each count as one number and "420" on its own doesn't match "8,420".
    static func numbers(in text: String) -> Set<String> {
        Set(text.matches(of: /\d+(?:[.,]\d+)*/).map { String($0.output) })
    }

    static func soundsGuilty(_ text: String) -> Bool {
        let words = text.lowercased().split { !$0.isLetter }.joined(separator: " ")
        return guiltWords.contains { " \(words) ".contains(" \($0) ") }
    }
}
