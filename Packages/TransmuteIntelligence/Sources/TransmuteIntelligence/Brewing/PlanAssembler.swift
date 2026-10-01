import Foundation
import TransmuteCore

/// Turns what the model wrote into a plan that's safe to save. Everything here is rules, so it
/// can be tested without the model:
///
/// - phases are stretched or squeezed to the plan's length, and long plans end on a deload;
/// - days land on the person's training days, with leg-heavy days kept off the day before a
///   hard match or practice;
/// - each day is checked against the library, the person's kit and limitations, and fitted to
///   the session length;
/// - targets become numbers by tracking type, starting loads come from known lifts, and later
///   weeks progress by fixed rules.
public struct PlanAssembler: Sendable {
    public let brief: TrainingBrief
    public let units: UnitSystem
    public let library: ExerciseLibrary

    public init(brief: TrainingBrief, units: UnitSystem, library: ExerciseLibrary = .bundled) {
        self.brief = brief
        self.units = units
        self.library = library
    }

    // MARK: Phases

    /// The blueprint's phases fitted to the plan's length. Plans of six weeks or more end with a
    /// one-week deload if the model didn't include one.
    public func phases(from blueprint: [PlanBlueprint.Phase]) -> [PlanPhase] {
        let total = max(1, brief.schedule.weeks)
        var drafts = blueprint.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        if drafts.isEmpty { drafts = [PlanBlueprint.Phase(name: "Build", weeks: total, focus: "Steady progress")] }
        var deload = drafts.last.map(Self.isDeload) ?? false
        if !deload, total >= 6 {
            drafts.append(PlanBlueprint.Phase(name: "Deload", weeks: 1, focus: "A lighter week to recover"))
            deload = true
        }
        // A deload is always one week; the rest share what's left in proportion.
        let main = deload ? Array(drafts.dropLast()) : drafts
        let available = total - (deload ? 1 : 0)
        let requested = max(1, main.reduce(0) { $0 + max(1, $1.weeks) })
        var lengths = main.map {
            max(1, Int((Double(max(1, $0.weeks)) * Double(available) / Double(requested)).rounded()))
        }
        while lengths.reduce(0, +) > available, let index = lengths.indices.max(by: { lengths[$0] < lengths[$1] }),
            lengths[index] > 1
        {
            lengths[index] -= 1
        }
        while lengths.reduce(0, +) < available {
            lengths[lengths.count - 1] += 1
        }
        // Too many phases for a short plan: drop from the end.
        while lengths.reduce(0, +) > available, lengths.count > 1 {
            lengths.removeLast()
        }
        var phases: [PlanPhase] = []
        var week = 1
        for (draft, length) in zip(main, lengths) {
            phases.append(PlanPhase(name: draft.name, focus: draft.focus, firstWeek: week, lastWeek: week + length - 1))
            week += length
        }
        if deload, let last = drafts.last {
            phases.append(
                PlanPhase(name: last.name, focus: last.focus, firstWeek: total, lastWeek: total, isDeload: true))
        }
        return phases
    }

    static func isDeload(_ phase: PlanBlueprint.Phase) -> Bool {
        let words = (phase.name + " " + phase.focus).lowercased()
        return words.contains("deload") || words.contains("taper") || words.contains("recover")
    }

    // MARK: Days of the week

    /// The person's training days, or a sensible spread if they didn't pick.
    public var weekdays: [Weekday] {
        let schedule = brief.schedule
        if schedule.preferredWeekdays.count == schedule.daysPerWeek { return schedule.preferredWeekdays.sorted() }
        return ProfileDraft.suggestedWeekdays(days: schedule.daysPerWeek, commitments: schedule.commitments)
    }

    /// Puts outlines on weekdays in order, then moves leg-heavy days off the day before a hard
    /// commitment by swapping with a lighter day.
    public func arrange(_ outlines: [PlanBlueprint.DayOutline]) -> [(
        weekday: Weekday, outline: PlanBlueprint.DayOutline
    )] {
        var slots = Array(zip(weekdays, outlines)).map { (weekday: $0.0, outline: $0.1) }
        let beforeHard = Set(
            brief.schedule.commitments.filter { $0.intensity == .hard }.map { ($0.weekday + 5) % 7 + 1 })
        func risky(_ index: Int) -> Bool {
            beforeHard.contains(slots[index].weekday) && Self.kind(of: slots[index].outline).isHardOnLegs
        }
        for index in slots.indices where risky(index) {
            let swap = slots.indices.first { other in
                !beforeHard.contains(slots[other].weekday) && !Self.kind(of: slots[other].outline).isHardOnLegs
            }
            if let swap {
                let outline = slots[index].outline
                slots[index].outline = slots[swap].outline
                slots[swap].outline = outline
            } else {
                // Nothing lighter to swap with: keep the day but make it moderate.
                slots[index].outline.intensity = "moderate"
            }
        }
        return slots
    }

    /// Kinds of day the goal calls for: speed and power for sport, conditioning for weight
    /// loss and fitness. Only as many as there are days to spare.
    public static func requiredKinds(for brief: TrainingBrief, days: Int) -> [DayKind] {
        let tags = Set(brief.goalTags)
        var kinds: [DayKind] = []
        if !brief.sports.isEmpty || !tags.isDisjoint(with: [.sportPerformance, .power, .speed, .agility]) {
            kinds.append(.powerSpeed)
        }
        if !tags.isDisjoint(with: [.weightLoss, .conditioning, .endurance]), brief.sports.isEmpty || days >= 4 {
            kinds.append(.conditioning)
        }
        if tags.contains(.mobility), days >= 5 { kinds.append(.mobility) }
        return Array(kinds.prefix(max(0, days - 2)))
    }

    /// The blueprint's days with any missing required kind swapped in, so a tennis plan always
    /// has its speed day and a weight-loss plan its conditioning. A repeated kind goes first;
    /// otherwise a full-body day when lower and upper days already cover it, then a lower day
    /// when a speed day already works the legs.
    public func balanced(_ outlines: [PlanBlueprint.DayOutline]) -> [PlanBlueprint.DayOutline] {
        var outlines = outlines
        let required = Self.requiredKinds(for: brief, days: outlines.count)
        for kind in required where !outlines.contains(where: { Self.kind(of: $0) == kind }) {
            let kinds = outlines.map(Self.kind(of:))
            let replaceable = outlines.indices.filter { !required.contains(kinds[$0]) }
            let repeated = replaceable.last { index in kinds.filter { $0 == kinds[index] }.count > 1 }
            let preference: [DayKind] =
                (kinds.contains(.lowerStrength) && kinds.contains(.upperStrength) ? [.fullBody] : [])
                + (kinds.contains(.powerSpeed) ? [.lowerStrength] : []) + [
                    .mobility, .upperStrength, .lowerStrength, .fullBody,
                ]
            let preferred = preference.lazy.compactMap { wanted in replaceable.last { kinds[$0] == wanted } }.first
            guard let index = repeated ?? preferred else { break }
            outlines[index] = PlanBlueprint.DayOutline(
                focus: kind.defaultFocus, kind: kind.rawValue, intensity: "moderate")
        }
        return outlines
    }

    static func kind(of outline: PlanBlueprint.DayOutline) -> DayKind {
        DayKind(rawValue: outline.kind) ?? .fullBody
    }

    /// The weekday before a hard commitment, if this one is.
    public func isBeforeHardCommitment(_ weekday: Weekday) -> Bool {
        brief.schedule.commitments.contains { $0.intensity == .hard && ($0.weekday + 5) % 7 + 1 == weekday }
    }
}
