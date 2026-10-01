import Foundation
import TransmuteCore

extension PlanAssembler {
    /// What happened to a day's exercises on the way in, for tests and logs.
    public struct DayReport: Equatable, Sendable {
        public var dropped: [String] = []
        public var swapped: [String: String] = [:]
        public var trimmedSets = 0
    }

    /// One day of a phase's template week, checked and turned into targets.
    public func templateDay(
        _ draft: DayDraft, kind: DayKind, offered: ExerciseCandidates
    ) -> (exercises: [BrewedExercise], report: DayReport) {
        var report = DayReport()
        var seen: Set<String> = []
        var exercises: [BrewedExercise] = []
        var group = 0
        for item in draft.exercises {
            guard let exercise = usable(item.exerciseID, offered: offered, report: &report), !seen.contains(exercise.id)
            else {
                if seen.contains(item.exerciseID) { report.dropped.append(item.exerciseID) }
                continue
            }
            seen.insert(exercise.id)
            var superset: Int?
            if item.supersetWithPrevious, let previous = exercises.indices.last {
                if exercises[previous].supersetGroup == nil {
                    group += 1
                    exercises[previous].supersetGroup = group
                }
                superset = exercises[previous].supersetGroup
            }
            exercises.append(
                BrewedExercise(
                    exerciseID: exercise.id, supersetGroup: superset,
                    note: item.note.trimmingCharacters(in: .whitespacesAndNewlines),
                    sets: targets(for: exercise, item)))
        }
        report.trimmedSets = fit(&exercises)
        return (exercises, report)
    }

    /// The exercise to use for an id: itself if allowed, else its easier or harder variant, else
    /// nothing.
    func usable(_ id: String, offered: ExerciseCandidates, report: inout DayReport) -> LibraryExercise? {
        guard let exercise = library.exercise(id: id) else {
            report.dropped.append(id)
            return nil
        }
        if allowed(exercise) { return exercise }
        for alternative in [exercise.easier, exercise.harder].compactMap({ $0 }).compactMap(library.exercise(id:))
        where allowed(alternative) {
            report.swapped[id] = alternative.id
            return alternative
        }
        report.dropped.append(id)
        return nil
    }

    func allowed(_ exercise: LibraryExercise) -> Bool {
        exercise.isDoable(with: brief.equipment) && !LimitationRules.excludes(exercise, areas: brief.limitationAreas)
            && exercise.difficulty.isAtMost(brief.experience)
    }

    // MARK: Targets

    func targets(for exercise: LibraryExercise, _ item: ExerciseDraft) -> [BrewedSet] {
        let effort = Effort(rawValue: item.effort) ?? .steady
        let rest = Double(min(max(item.restSeconds, 15), 300))
        let sets = min(max(item.sets, 1), 6)
        // Jumps, throws and other power work stay crisp: few reps, full rest, no grinding.
        let isPower = exercise.category == .power
        let showsEffort = brief.experience != .beginner && !isPower
        var target = BrewedSet(restSeconds: isPower ? max(rest, 60) : rest)
        switch exercise.tracking {
        case .weightReps:
            let reps = min(item.reps > 0 ? item.reps : 8, isPower ? 6 : 20)
            target.reps = reps
            target.rpe = showsEffort ? effort.rpe : nil
            if let oneRepMax = startingOneRepMax(for: exercise) {
                let percent = Self.percentOfMax(reps: reps, rpe: isPower ? Effort.steady.rpe : effort.rpe)
                target.loadKg = LoadableWeight.round(oneRepMax * percent, for: exercise.allEquipment, system: units)
                if brief.experience == .advanced { target.percentOneRepMax = (percent * 100).rounded() / 100 }
            }
        case .reps:
            target.reps = min(item.reps > 0 ? item.reps : 10, isPower ? 6 : 30)
            target.rpe = showsEffort ? effort.rpe : nil
        case .time:
            target.seconds = Double(item.seconds > 0 ? item.seconds : 30)
        case .distanceTime:
            target.meters = Double(item.meters > 0 ? item.meters : (exercise.pattern == .sprint ? 20 : 400))
        case .intervals:
            // One entry: rounds of work and rest.
            let work = Double(item.seconds > 0 ? min(item.seconds, 120) : 30)
            return [
                BrewedSet(
                    seconds: work, restSeconds: rest, rounds: max(sets, 4),
                    intervalRestSeconds: max(10, min(rest, work * 2)))
            ]
        }
        return Array(repeating: target, count: sets)
    }

    /// Fraction of a one-rep max for a set of `reps` that should feel like `rpe`: Epley's
    /// formula with the reps left in reserve added on.
    static func percentOfMax(reps: Int, rpe: Double) -> Double {
        let inReserve = max(0, 10 - rpe)
        return 1 / (1 + (Double(reps) + inReserve) / 30)
    }

    /// From a known lift on the same exercise, or a conservative 80% of one on the same barbell
    /// pattern. `nil` means the first session calibrates (#12).
    func startingOneRepMax(for exercise: LibraryExercise) -> Double? {
        if let lift = brief.knownLifts.first(where: { $0.exerciseID == exercise.id }) {
            return lift.estimatedOneRepMaxKg
        }
        guard exercise.allEquipment.contains(.barbell) else { return nil }
        let related = brief.knownLifts.first { lift in
            guard let known = library.exercise(id: lift.exerciseID) else { return false }
            return known.pattern == exercise.pattern && known.allEquipment.contains(.barbell)
        }
        return related.map { $0.estimatedOneRepMaxKg * 0.8 }
    }

    // MARK: Session length

    /// Rough minutes for a day: warm-up, the sets, the rests and moving between exercises.
    public static func estimatedMinutes(_ exercises: [BrewedExercise]) -> Double {
        let seconds = exercises.reduce(300.0) { total, exercise in
            total + 60
                + exercise.sets.reduce(0.0) { sum, set in
                    let rounds = Double(set.rounds ?? 1)
                    let work =
                        set.seconds.map { $0 * rounds + (set.intervalRestSeconds ?? 0) * (rounds - 1) }
                        ?? set.meters.map { $0 / 4 + 10 } ?? Double(set.reps ?? 8) * 3.5
                    return sum + work + set.restSeconds
                }
        }
        return seconds / 60
    }

    /// Trims sets, last exercises first, until the day fits the session with a little slack.
    /// Returns how many sets went.
    func fit(_ exercises: inout [BrewedExercise]) -> Int {
        let budget = Double(brief.schedule.sessionMinutes) * 1.1
        var trimmed = 0
        while Self.estimatedMinutes(exercises) > budget {
            if let index = exercises.indices.reversed().first(where: { exercises[$0].sets.count > 2 }) {
                exercises[index].sets.removeLast()
            } else if exercises.count > 3 {
                trimmed += exercises.removeLast().sets.count - 1
            } else {
                break
            }
            trimmed += 1
        }
        return trimmed
    }
}

extension ExperienceLevel {
    func isAtMost(_ other: ExperienceLevel) -> Bool {
        Self.allCases.firstIndex(of: self)! <= Self.allCases.firstIndex(of: other)!
    }
}
