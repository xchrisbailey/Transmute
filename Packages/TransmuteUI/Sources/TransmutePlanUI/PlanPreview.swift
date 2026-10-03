import SwiftUI
import TransmuteCore
import TransmuteIntelligence
import TransmuteUI

/// A freshly brewed plan before it's kept: name, why, phases and the first week in full.
struct PlanPreview: View {
    let plan: BrewedPlan
    let units: Units
    var library = ExerciseLibrary.bundled
    @Environment(\.effortDisplay) private var effort

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(verbatim: plan.name)
                .brandFont(.largeTitle)
                .foregroundStyle(Color.brand(\.ink))
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: plan.goalSummary)
                .brandFont(.exerciseTitle)
                .foregroundStyle(Color.brandText(\.subtext))
            Text(Copy.whyThisPlan(plan.rationale))
                .brandFont(.body)
                .foregroundStyle(Color.brand(\.ink))
            PhaseBar(phases: plan.phases, weekCount: plan.weekCount)
            Text(BrewCopy.week(1))
                .brandFont(.exerciseTitle)
                .foregroundStyle(Color.brand(\.ink))
                .accessibilityAddTraits(.isHeader)
            ForEach(plan.days(inWeek: 1), id: \.weekday) { day in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(verbatim: "\(TrainingBrief.weekdayName(day.weekday)) · \(day.focus)")
                            .brandFont(.exerciseTitle)
                            .foregroundStyle(Color.brand(\.ink))
                        Spacer()
                        Text(BrewCopy.minutes(Int(PlanAssembler.estimatedMinutes(day.exercises).rounded())))
                            .brandFont(.label)
                            .foregroundStyle(Color.brandText(\.subtext))
                    }
                    if !day.why.isEmpty {
                        Text(verbatim: day.why)
                            .brandFont(.label)
                            .foregroundStyle(Color.brandText(\.subtext))
                    }
                    ForEach(Array(day.exercises.enumerated()), id: \.offset) { _, exercise in
                        LabeledContent {
                            Text(verbatim: SetTargets(exercise.sets).summary(units: units, showing: effort))
                                .brandNumberFont(size: 15)
                                .foregroundStyle(Color.brand(\.ink))
                        } label: {
                            Text(verbatim: library.exercise(id: exercise.exerciseID)?.name ?? exercise.exerciseID)
                                .brandFont(.body)
                        }
                    }
                }
                .padding()
                .background(Color.brand(\.mantle), in: .rect(cornerRadius: 16))
            }
        }
    }
}

/// The plan's phases as proportional segments, with names and weeks in text so it reads
/// without colour (#22).
public struct PhaseBar: View {
    let phases: [PlanPhase]
    let weekCount: Int
    var currentWeek: Int?

    public init(phases: [PlanPhase], weekCount: Int, currentWeek: Int? = nil) {
        self.phases = phases
        self.weekCount = weekCount
        self.currentWeek = currentWeek
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { proxy in
                HStack(spacing: 3) {
                    ForEach(phases, id: \.firstWeek) { phase in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(fill(for: phase))
                            .frame(
                                width: max(
                                    8,
                                    (proxy.size.width - CGFloat(phases.count - 1) * 3)
                                        * CGFloat(phase.weeks.count) / CGFloat(max(1, weekCount))))
                    }
                }
            }
            .frame(height: 8)
            .accessibilityHidden(true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { labels }
                VStack(alignment: .leading, spacing: 2) { labels }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var labels: some View {
        ForEach(phases, id: \.firstWeek) { phase in
            Text(
                verbatim:
                    "\(phase.name) \(phase.firstWeek == phase.lastWeek ? "\(phase.firstWeek)" : "\(phase.firstWeek)–\(phase.lastWeek)")"
            )
            .brandFont(.label)
            .foregroundStyle(
                currentWeek.map(phase.weeks.contains) == true ? Color.brand(\.ink) : Color.brandText(\.subtext))
        }
    }

    private func fill(for phase: PlanPhase) -> Color {
        if let currentWeek, phase.weeks.contains(currentWeek) { return Color.brand(\.now) }
        return phase.isDeload ? Color.brand(\.surface1) : Color.brand(\.magic).opacity(0.7)
    }
}
