import Foundation
import SwiftData
import TransmuteCore

extension DayKind {
    /// The kind a saved day is, judged from its exercises.
    public static func infer(from exercises: [LibraryExercise]) -> DayKind {
        guard !exercises.isEmpty else { return .fullBody }
        let share = { (categories: Set<ExerciseCategory>) in
            Double(exercises.filter { categories.contains($0.category) }.count) / Double(exercises.count)
        }
        if share([.mobility]) > 0.5 { return .mobility }
        if share([.conditioning]) >= 0.5 { return .conditioning }
        if share([.power, .speedAgility]) >= 0.5 { return .powerSpeed }
        let lower = exercises.filter { [.squat, .hinge, .lunge].contains($0.pattern) }.count
        let upper = exercises.filter {
            [.horizontalPush, .verticalPush, .horizontalPull, .verticalPull].contains($0.pattern)
        }.count
        if lower > 0, upper == 0 { return .lowerStrength }
        if upper > 0, lower == 0 { return .upperStrength }
        return .fullBody
    }
}

/// What a "Rework this day" note asks for, read by rules so the model can't miss it: kit to
/// leave out, a shorter session, or a sore area.
public struct ReworkNote: Equatable, Sendable {
    public var withoutEquipment: Set<Equipment> = []
    public var minutes: Int?
    public var areas: Set<BodyArea> = []

    static let equipmentWords: [Equipment: [String]] = [
        .barbell: ["barbell", "bar"], .dumbbell: ["dumbbell", "dumbbells", "dbs"],
        .kettlebell: ["kettlebell", "kettlebells"],
        .machine: ["machine", "machines"], .cable: ["cable", "cables"], .bench: ["bench"],
        .rack: ["rack", "squat rack"],
        .pullUpBar: ["pull-up bar", "pullup bar"], .box: ["box"], .bike: ["bike"], .rower: ["rower"],
        .treadmill: ["treadmill"], .band: ["band", "bands"], .sled: ["sled"],
        .medicineBall: ["med ball", "medicine ball"],
    ]

    public init(_ note: String) {
        let text = " " + note.lowercased() + " "
        for (equipment, words) in Self.equipmentWords {
            let missing = words.contains { word in
                ["no \(word)", "without \(word)", "without a \(word)", "no \(word)s"].contains {
                    text.contains(" \($0) ")
                }
                    || text.contains(" \(word) is taken") || text.contains(" \(word)s are taken")
            }
            if missing { withoutEquipment.insert(equipment) }
        }
        if let match = text.firstMatch(of: /(\d{2,3})\s*(?:min|minutes|mins)/), let value = Int(match.1) {
            minutes = value
        }
        areas = LimitationRules.areas(mentionedIn: note)
    }

    /// The brief with the note applied.
    public func applied(to brief: TrainingBrief) -> TrainingBrief {
        var brief = brief
        brief.equipment.subtract(withoutEquipment)
        if let minutes { brief.schedule.sessionMinutes = min(brief.schedule.sessionMinutes, max(15, minutes)) }
        brief.limitationAreas.formUnion(areas)
        return brief
    }
}

/// The saved day a rework starts from, as plain values.
public struct ReworkTarget: Sendable {
    public var focus: String
    public var weekday: Weekday
    public var currentIDs: [String]
    public var phase: PlanPhase
    public var week: Int

    public init(focus: String, weekday: Weekday, currentIDs: [String], phase: PlanPhase, week: Int) {
        self.focus = focus
        self.weekday = weekday
        self.currentIDs = currentIDs
        self.phase = phase
        self.week = week
    }

    /// A saved day, in its plan's phase.
    public init(_ day: PlanDay, in plan: Plan) {
        self.init(
            focus: day.focus, weekday: day.weekday, currentIDs: day.orderedExercises.map(\.exerciseID),
            phase: plan.phase(forWeek: day.week)
                ?? PlanPhase(name: plan.name, focus: plan.goalSummary, firstWeek: 1, lastWeek: plan.weekCount),
            week: day.week)
    }
}

extension PlanBrewer {
    /// Rewrites one day around a note like "no barbell today", "only 30 minutes" or "knee's
    /// sore" (#10). Returns the new exercises for the day's week of its phase; nothing changes
    /// until the caller applies them.
    public func rework(_ target: ReworkTarget, note: String, brief: TrainingBrief, units: UnitSystem) async throws
        -> TemplateDay
    {
        let (focus, weekday, currentIDs, phase, week) = (
            target.focus, target.weekday, target.currentIDs, target.phase, target.week
        )
        let reading = ReworkNote(note)
        let brief = reading.applied(to: brief)
        let assembler = PlanAssembler(brief: brief, units: units, library: library)
        let kind = DayKind.infer(from: currentIDs.compactMap(library.exercise(id:)))
        var spec = DaySpec(
            phase: phase, outline: .init(focus: focus, kind: kind.rawValue, intensity: "moderate"), weekday: weekday,
            kind: kind, beforeMatch: assembler.isBeforeHardCommitment(weekday))
        let current = currentIDs.compactMap(library.exercise(id:)).map(\.name).joined(separator: ", ")
        spec.earlier = []
        var request = dayRequest(brief, spec: spec, offered: offered(for: kind, brief: brief, keeping: currentIDs))
        request.prompt =
            """
            Rework this session. It was: \(current).
            The person says: "\(note.trimmingCharacters(in: .whitespacesAndNewlines))"
            Keep what still fits and change what the note asks for.

            """ + request.prompt
        var day = try await writeDay(spec, brief: brief, assembler: assembler, request: request) { _ in }
        day.exercises = assembler.progressed(
            day.exercises, weekInPhase: week - phase.firstWeek + 1, isDeload: phase.isDeload)
        return day
    }

    /// The day's usual shortlist plus whatever it already has, so a rework can keep exercises.
    func offered(for kind: DayKind, brief: TrainingBrief, keeping ids: [String]) -> ExerciseCandidates {
        let assembler = PlanAssembler(brief: brief, units: .metric, library: library)
        let current = ids.compactMap(library.exercise(id:)).filter(assembler.allowed)
        let shortlist = DayShortlist.candidates(
            for: kind, brief: brief, library: library, limit: DayShortlist.limit - current.count)
        return ExerciseCandidates(current + shortlist.exercises.filter { !ids.contains($0.id) })
    }
}

extension TemplateDay {
    /// Puts these exercises on a saved day in place of what it had, and marks it edited.
    @MainActor
    public func replaceExercises(of day: PlanDay, in context: ModelContext) {
        for exercise in day.exercises ?? [] {
            context.delete(exercise)
        }
        day.exercises = exercises.makePlannedExercises()
        if !why.isEmpty { day.notes = why }
        day.isEdited = true
    }
}
