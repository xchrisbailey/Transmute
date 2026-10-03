import SwiftUI
import TransmuteCore
import TransmuteUI

/// The watch's first screen: today's session by name, one mauve button to start it, and its
/// exercises underneath. Rest days say so and point at the next session.
struct WatchTodayView: View {
    let plan: Plan?
    let units: Units
    let library: ExerciseLibrary
    let onStart: (PlanDay) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let plan {
                    planned(TodayPlan(plan: plan), in: plan)
                } else {
                    empty
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
        .background(Color.watchScreen)
        .navigationTitle(Text(WatchCopy.today))
    }

    @ViewBuilder private func planned(_ today: TodayPlan, in plan: Plan) -> some View {
        if let day = today.day {
            title(day.focus)
            if today.isDone {
                note(WatchCopy.doneToday)
                if let next = today.next {
                    note(nextLine(next, in: plan))
                }
            } else {
                Button {
                    onStart(day)
                } label: {
                    Text(WatchCopy.start)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brand(\.magic))
                .foregroundStyle(Color.watchScreen)
            }
            ForEach(day.orderedExercises) { planned in
                exerciseRow(planned)
            }
        } else {
            title(String(localized: WatchCopy.restDay))
            if let next = today.next {
                note(nextLine(next, in: plan))
            } else {
                note(WatchCopy.planEnded)
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Image("Mark")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
            Text(WatchCopy.noPlan)
                .brandFont(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.brandText(\.subtext))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    private func title(_ text: String) -> some View {
        Text(verbatim: text)
            .brandFont(.exerciseTitle)
            .foregroundStyle(Color.brand(\.ink))
            .accessibilityAddTraits(.isHeader)
    }

    private func note(_ text: LocalizedStringResource) -> some View {
        Text(text)
            .brandFont(.label)
            .foregroundStyle(Color.brandText(\.subtext))
    }

    private func nextLine(_ day: PlanDay, in plan: Plan) -> LocalizedStringResource {
        WatchCopy.next(day.focus, on: PlanEditor.date(of: day, in: plan).formatted(.dateTime.weekday(.wide)))
    }

    private func exerciseRow(_ planned: PlannedExercise) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: library.exercise(id: planned.exerciseID)?.name ?? planned.exerciseID)
                .brandFont(.label)
                .foregroundStyle(Color.brand(\.ink))
            Text(verbatim: WatchTargets.summary(of: planned.orderedSets, units: units))
                .brandNumberFont(size: 13, relativeTo: .footnote)
                .foregroundStyle(Color.brandText(\.subtext))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.watchPlatter, in: .rect(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
}

/// An exercise's targets in a few characters, e.g. "5 × 5 · 80 kg" or "3 × 0:45".
enum WatchTargets {
    static func summary(of sets: [PlannedSet], units: Units) -> String {
        let working = sets.filter { !$0.isWarmUp }
        guard let first = working.first ?? sets.first else { return "" }
        let count = max(working.count, 1)
        var text: String
        if let rounds = first.rounds, let seconds = first.targetSeconds {
            text = "\(rounds) × \(Units.clock(seconds: seconds))"
        } else if let reps = first.targetReps {
            text = "\(count) × \(reps)"
        } else if let meters = first.targetMeters {
            text = "\(count) × \(units.formatDistance(meters: meters))"
        } else if let seconds = first.targetSeconds {
            text = "\(count) × \(Units.clock(seconds: seconds))"
        } else {
            text = "\(count)"
        }
        if let load = first.targetLoadKg {
            text += " · \(units.formatWeight(kg: load))"
        }
        return text
    }
}
