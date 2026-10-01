import TransmuteCore

/// Checks a brewed plan against the person, the way #9's validation and the evaluation set
/// see it. Empty means the plan is safe to save.
public enum PlanCheck {
    public static func problems(in plan: BrewedPlan, brief: TrainingBrief, library: ExerciseLibrary = .bundled)
        -> [String]
    {
        var problems: [String] = []
        if plan.weekCount != brief.schedule.weeks {
            problems.append("\(plan.weekCount) weeks, not \(brief.schedule.weeks)")
        }
        if plan.phases.last?.lastWeek != brief.schedule.weeks { problems.append("Phases don't cover every week") }
        if plan.name.isEmpty || plan.rationale.isEmpty { problems.append("Missing name or rationale") }
        let assembler = PlanAssembler(brief: brief, units: .metric, library: library)
        for week in 1...max(1, brief.schedule.weeks) {
            let days = plan.days(inWeek: week)
            if days.count != brief.schedule.daysPerWeek {
                problems.append("Week \(week) has \(days.count) days")
            }
            for day in days {
                problems += dayProblems(day, assembler: assembler)
            }
        }
        return problems
    }

    static func dayProblems(_ day: BrewedDay, assembler: PlanAssembler) -> [String] {
        let label = "Week \(day.week) \(TrainingBrief.weekdayName(day.weekday))"
        var problems: [String] = []
        if day.exercises.count < 2 { problems.append("\(label) has \(day.exercises.count) exercises") }
        if Set(day.exercises.map(\.exerciseID)).count != day.exercises.count { problems.append("\(label) repeats") }
        for exercise in day.exercises {
            guard let found = assembler.library.exercise(id: exercise.exerciseID) else {
                problems.append("\(label): unknown \(exercise.exerciseID)")
                continue
            }
            if !assembler.allowed(found) { problems.append("\(label): \(found.id) not allowed") }
            if exercise.sets.isEmpty { problems.append("\(label): \(found.id) has no sets") }
        }
        let minutes = PlanAssembler.estimatedMinutes(day.exercises)
        if minutes > Double(assembler.brief.schedule.sessionMinutes) * 1.15 {
            problems.append("\(label) runs \(Int(minutes)) min")
        }
        if assembler.isBeforeHardCommitment(day.weekday), day.kind == .lowerStrength {
            problems.append("\(label) is a lower-strength day before a match")
        }
        return problems
    }
}
