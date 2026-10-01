import Foundation
import TransmuteCore

extension PlanAssembler {
    /// A template day as it falls in a given week of its phase. Week one is the template; each
    /// week after adds 2.5% load, or half a point of effort, a rep (not for power work) or five
    /// seconds where there's no load. A deload drops a set and eases off by 15%.
    public func progressed(_ exercises: [BrewedExercise], weekInPhase: Int, isDeload: Bool) -> [BrewedExercise] {
        let step = Double(max(0, weekInPhase - 1))
        return exercises.map { exercise in
            var exercise = exercise
            let found = library.exercise(id: exercise.exerciseID)
            let equipment = found?.allEquipment ?? []
            // Power work progresses by quality, not volume: its reps stay put.
            let isPower = found?.category == .power
            exercise.sets = exercise.sets.map { set in
                var set = set
                if isDeload {
                    set.loadKg = set.loadKg.map { LoadableWeight.round($0 * 0.85, for: equipment, system: units) }
                    set.rpe = set.rpe.map { max(5, $0 - 1.5) }
                    set.rounds = set.rounds.map { max(2, $0 - 2) }
                } else if let load = set.loadKg {
                    set.loadKg = LoadableWeight.round(load * (1 + 0.025 * step), for: equipment, system: units)
                } else if let rpe = set.rpe {
                    set.rpe = min(9.5, rpe + 0.5 * step)
                } else if let reps = set.reps, !isPower {
                    set.reps = reps + min(3, Int(step))
                } else if let seconds = set.seconds, set.rounds == nil {
                    set.seconds = seconds + min(30, 5 * step)
                } else if let rounds = set.rounds {
                    set.rounds = rounds + min(2, Int(step / 2))
                }
                return set
            }
            if isDeload, exercise.sets.count > 1 {
                exercise.sets.removeLast()
            }
            return exercise
        }
    }

    /// How many distinct template weeks a brew writes.
    public static let maxTemplates = 2

    /// The whole plan: each phase's template days repeated over its weeks with progression.
    /// Deload phases reuse the template before them.
    public func assemble(
        blueprint: PlanBlueprint, phases: [PlanPhase],
        templates: [[TemplateDay]]
    ) -> BrewedPlan {
        var days: [BrewedDay] = []
        var templateIndex = -1
        for phase in phases {
            // Each new phase takes the next template; deloads and phases past the last template
            // reuse the latest one.
            if !phase.isDeload || templateIndex < 0 { templateIndex = min(templateIndex + 1, templates.count - 1) }
            guard templateIndex >= 0 else { break }
            for week in phase.weeks {
                for day in templates[templateIndex] {
                    days.append(
                        BrewedDay(
                            week: week, weekday: day.weekday, focus: day.focus, why: day.why, kind: day.kind,
                            exercises: progressed(
                                day.exercises, weekInPhase: week - phase.firstWeek + 1, isDeload: phase.isDeload)))
                }
            }
        }
        return BrewedPlan(
            name: blueprint.name.trimmingCharacters(in: .whitespacesAndNewlines),
            goalSummary: blueprint.goalSummary.trimmingCharacters(in: .whitespacesAndNewlines),
            rationale: blueprint.rationale.trimmingCharacters(in: .whitespacesAndNewlines), phases: phases,
            weekCount: brief.schedule.weeks, days: days)
    }
}

/// One day of a phase's first week, before it's repeated and progressed.
public struct TemplateDay: Sendable, Equatable {
    public var weekday: Weekday
    public var focus: String
    public var why: String
    public var kind: DayKind
    public var exercises: [BrewedExercise]
}
