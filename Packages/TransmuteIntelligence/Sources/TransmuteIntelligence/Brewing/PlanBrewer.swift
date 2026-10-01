import Foundation
import OSLog
import TransmuteCore

/// Brews a plan from a brief (#9): a blueprint first, then each training day of each phase,
/// streaming progress so the screen can show the plan distilling day by day.
public struct PlanBrewer: Sendable {
    public let service: any IntelligenceService
    public let library: ExerciseLibrary

    public init(service: any IntelligenceService, library: ExerciseLibrary = .bundled) {
        self.service = service
        self.library = library
    }

    public enum Progress: Sendable {
        /// The outline is being written.
        case outlining
        case outlined(name: String, rationale: String, phases: [PlanPhase])
        /// A day is being written. `exercises` grows as names stream in.
        case distilling(phase: PlanPhase, focus: String, exercises: [String])
        case distilled(phase: PlanPhase, focus: String, exercises: [String])
        case finished(BrewedPlan)
    }

    /// One day to write, and what the prompt needs to know around it.
    struct DaySpec {
        var phase: PlanPhase
        var outline: PlanBlueprint.DayOutline
        var weekday: Weekday
        var kind: DayKind
        /// Earlier days this week, e.g. "Monday: Back squat, Bench press".
        var earlier: [String] = []
        var beforeMatch = false
    }

    public func brew(_ brief: TrainingBrief, units: UnitSystem) -> AsyncThrowingStream<Progress, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let plan = try await run(brief, units: units) { continuation.yield($0) }
                    continuation.yield(.finished(plan))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func run(_ brief: TrainingBrief, units: UnitSystem, report: (Progress) -> Void) async throws -> BrewedPlan {
        let assembler = PlanAssembler(brief: brief, units: units, library: library)
        report(.outlining)
        let blueprint = try await service.respond(
            blueprintRequest(brief, days: assembler.weekdays), generating: PlanBlueprint.self)
        let phases = assembler.phases(from: blueprint.phases)
        report(.outlined(name: blueprint.name, rationale: blueprint.rationale, phases: phases))

        let slots = assembler.arrange(assembler.balanced(blueprint.days))
        var templates: [[TemplateDay]] = []
        // Two templates at most: the first phase, and one for everything after it. Later phases
        // progress from the second, which keeps brewing quick on-device.
        for phase in phases.filter({ !$0.isDeload }).prefix(PlanAssembler.maxTemplates) {
            var week: [TemplateDay] = []
            for slot in slots {
                var spec = DaySpec(
                    phase: phase, outline: slot.outline, weekday: slot.weekday,
                    kind: PlanAssembler.kind(of: slot.outline),
                    beforeMatch: assembler.isBeforeHardCommitment(slot.weekday))
                spec.earlier = week.map { day in
                    "\(TrainingBrief.weekdayName(day.weekday)): \(names(day.exercises).joined(separator: ", "))"
                }
                // Nothing repeats within a week, so each day brings something new.
                let used = Set(week.flatMap { $0.exercises.map(\.exerciseID) })
                let day = try await writeDay(spec, brief: brief, assembler: assembler, excluding: used, report: report)
                report(.distilled(phase: phase, focus: day.focus, exercises: names(day.exercises)))
                week.append(day)
            }
            templates.append(week)
        }
        return assembler.assemble(blueprint: blueprint, phases: phases, templates: templates)
    }

    /// Writes and checks one day. A day that comes back short after the checks gets one more try.
    func writeDay(
        _ spec: DaySpec, brief: TrainingBrief, assembler: PlanAssembler, excluding used: Set<String>,
        report: (Progress) -> Void
    ) async throws -> TemplateDay {
        let offered = DayShortlist.candidates(for: spec.kind, brief: brief, library: library, excluding: used)
        return try await writeDay(
            spec, brief: brief, assembler: assembler, request: dayRequest(brief, spec: spec, offered: offered),
            report: report)
    }

    func writeDay(
        _ spec: DaySpec, brief: TrainingBrief, assembler: PlanAssembler, request: IntelligenceRequest,
        report: (Progress) -> Void
    ) async throws -> TemplateDay {
        let offered = ExerciseCandidates(
            (request.allowedValues["exerciseID"] ?? []).compactMap(library.exercise(id:)))
        var best = TemplateDay(
            weekday: spec.weekday, focus: spec.outline.focus, why: "", kind: spec.kind, exercises: [])
        let enough = max(2, exerciseCount(brief, kind: spec.kind) - 2)
        for _ in 0..<2 where best.exercises.count < enough {
            let draft = try await distill(request, spec: spec, report: report)
            let built = assembler.templateDay(draft, kind: spec.kind, offered: offered)
            if !built.report.dropped.isEmpty || !built.report.swapped.isEmpty {
                Self.logger.info(
                    "\(spec.outline.focus): dropped \(built.report.dropped), swapped \(built.report.swapped)")
            }
            if built.exercises.count > best.exercises.count {
                best.exercises = built.exercises
                best.why = draft.why
            }
        }
        guard best.exercises.count >= 2 else { throw IntelligenceError.malformedOutput }
        return best
    }

    private func distill(_ request: IntelligenceRequest, spec: DaySpec, report: (Progress) -> Void) async throws
        -> DayDraft
    {
        for try await update in service.stream(request, generating: DayDraft.self) {
            switch update {
            case .partial(let partial):
                let names = (partial.exercises ?? []).compactMap(\.exerciseID).compactMap {
                    library.exercise(id: $0)?.name
                }
                report(.distilling(phase: spec.phase, focus: spec.outline.focus, exercises: names))
            case .complete(let draft):
                return draft
            }
        }
        throw IntelligenceError.malformedOutput
    }

    private func names(_ exercises: [BrewedExercise]) -> [String] {
        exercises.map { library.exercise(id: $0.exerciseID)?.name ?? $0.exerciseID }
    }

    // MARK: Prompts

    func blueprintRequest(_ brief: TrainingBrief, days: [Weekday]) -> IntelligenceRequest {
        let kinds = DayKind.allCases.map(\.rawValue).joined(separator: ", ")
        let required = PlanAssembler.requiredKinds(for: brief, days: days.count)
        var lines = [
            "Outline a \(brief.schedule.weeks)-week training plan for this person.", "",
            brief.promptDescription, "",
            "The plan has \(days.count) training days a week: \(days.map(TrainingBrief.weekdayName).joined(separator: ", ")).",
            "Give one day outline for each, in that order. Kinds of day: \(kinds).",
            "Balance the week: don't put the same kind of day back to back unless it suits the goal.",
        ]
        lines += required.map { "Include a \($0.rawValue) day." }
        if !brief.schedule.commitments.isEmpty {
            lines.append("Keep hard, leg-heavy days away from the day before a hard commitment.")
        }
        lines.append("Split the weeks into phases that build towards the goal.")
        return IntelligenceRequest(
            instructions: PlannerInstructions.make(experience: brief.experience),
            prompt: lines.joined(separator: "\n"), arrayCounts: ["days": days.count], temperature: 0.6,
            maximumResponseTokens: 700)
    }

    func dayRequest(_ brief: TrainingBrief, spec: DaySpec, offered: ExerciseCandidates) -> IntelligenceRequest {
        let outline = spec.outline
        var lines = [
            "Write \(TrainingBrief.weekdayName(spec.weekday))'s session: \(outline.focus) "
                + "(\(spec.kind.rawValue), \(outline.intensity)).",
            "Phase: \(spec.phase.name), \(spec.phase.focus).",
            "It has to fit in \(brief.schedule.sessionMinutes) minutes, including a short warm-up.",
        ]
        if spec.beforeMatch { lines.append("Tomorrow is a hard match or practice, so keep the legs fresh.") }
        if !spec.earlier.isEmpty {
            lines.append("Earlier this week: \(spec.earlier.joined(separator: "; ")). Vary the exercises.")
        }
        lines.append(
            brief.experience == .beginner
                ? "Use simple exercises and easy or steady effort."
                : "Start with the most demanding exercise and finish with core or prehab work.")
        return IntelligenceRequest(
            instructions: PlannerInstructions.make(experience: brief.experience),
            prompt: """
                \(lines.joined(separator: "\n"))

                The person:
                \(brief.promptDescription)

                Choose exercises only from this list:
                \(offered.promptList)
                """,
            allowedValues: offered.constraint, arrayCounts: ["exercises": exerciseCount(brief, kind: spec.kind)],
            temperature: 0.7, maximumResponseTokens: 1_200)
    }

    /// How many exercises a day gets: about one per ten minutes, at most five for beginners,
    /// conditioning and mobility days, and three to eight in all.
    func exerciseCount(_ brief: TrainingBrief, kind: DayKind) -> Int {
        var count = brief.schedule.sessionMinutes / 10
        if brief.experience == .beginner || kind == .mobility || kind == .conditioning { count = min(count, 5) }
        return min(max(count, 3), 8)
    }

    private static let logger = Logger(subsystem: "computer.srcery.transmute", category: "brew")
}
