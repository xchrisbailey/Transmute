import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteIntelligence
import TransmuteUI

/// An exercise in a grid card: name and one-line targets. Click to edit the targets; drag to
/// reorder or move to another day, or use the menu.
struct PlanGridExerciseRow: View {
    let planned: PlannedExercise
    let day: PlanDay
    let plan: Plan
    let units: Units
    @Environment(\.effortDisplay) private var effort

    @State private var showsTargets = false
    @State private var isTargeted = false
    let library = ExerciseLibrary.bundled

    private var name: String {
        library.exercise(id: planned.exerciseID)?.name ?? planned.exerciseID
    }

    private var index: Int {
        day.orderedExercises.firstIndex { $0 === planned } ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: name)
                    .brandFont(.label)
                    .foregroundStyle(Color.brand(\.ink))
                    .fixedSize(horizontal: false, vertical: true)
                if planned.supersetGroup != nil {
                    Image(systemName: "link")
                        .font(.caption)
                        .foregroundStyle(Color.brandText(\.magic))
                        .accessibilityLabel(Text(PlanCopy.superset))
                }
            }
            Text(verbatim: SetTargets(planned.orderedSets).summary(units: units, showing: effort))
                .brandNumberFont(size: 12, relativeTo: .caption)
                .foregroundStyle(Color.brandText(\.subtext))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(Color.brand(\.surface0).opacity(0.5), in: .rect(cornerRadius: 6))
        .overlay {
            if isTargeted {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.brand(\.magic), lineWidth: 2)
            }
        }
        .contentShape(.rect)
        .onTapGesture {
            showsTargets = true
        }
        .draggable(PlanGridItem(day: day, in: plan, exercise: planned)) {
            Text(verbatim: name)
                .brandFont(.label)
                .padding(8)
                .background(Color.brand(\.mantle), in: .rect(cornerRadius: 8))
        }
        .dropDestination(for: PlanGridItem.self) { items, _ in
            items.first?.drop(in: plan, week: day.week, weekday: day.weekday, onto: planned) ?? false
        } isTargeted: {
            isTargeted = $0
        }
        .popover(isPresented: $showsTargets, arrowEdge: .trailing) {
            PlanGridTargetsEditor(planned: planned, name: name, units: units)
        }
        .contextMenu { actions }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            showsTargets = true
        }
        .accessibilityActions { actions }
    }

    /// Everything a drag can do to an exercise, for the context menu and VoiceOver (#22).
    @ViewBuilder private var actions: some View {
        Button {
            showsTargets = true
        } label: {
            Text(PlanGridCopy.editTargets)
        }
        Divider()
        Button {
            PlanEditor.move(planned, to: day, at: index - 1)
        } label: {
            Text(PlanGridCopy.moveUp)
        }
        .disabled(index == 0)
        Button {
            PlanEditor.move(planned, to: day, at: index + 1)
        } label: {
            Text(PlanGridCopy.moveDown)
        }
        .disabled(index >= day.orderedExercises.count - 1)
        Menu {
            ForEach(1...max(1, plan.weekCount), id: \.self) { week in
                let others = plan.orderedDays.filter { $0.week == week && $0 !== day }
                if !others.isEmpty {
                    Menu {
                        ForEach(others) { other in
                            Button {
                                PlanEditor.move(planned, to: other)
                            } label: {
                                Text(verbatim: "\(PlanGridCopy.weekdayName(other.weekday)) · \(other.focus)")
                            }
                        }
                    } label: {
                        Text(BrewCopy.week(week))
                    }
                }
            }
        } label: {
            Text(PlanGridCopy.moveToDay)
        }
    }
}

/// The popover behind an exercise: how many sets, then the same target controls the day
/// screen uses, applied to every set.
struct PlanGridTargetsEditor: View {
    let planned: PlannedExercise
    let name: String
    let units: Units

    @Environment(\.modelContext) private var context
    let library = ExerciseLibrary.bundled

    private var sets: Binding<Int> {
        Binding {
            planned.orderedSets.count
        } set: {
            PlanEditor.setSetCount(of: planned, to: $0, in: context)
        }
    }

    var body: some View {
        Form {
            Section {
                Stepper(value: sets, in: 1...12) {
                    LabeledContent {
                        Text(planned.orderedSets.count, format: .number)
                            .brandNumberFont(size: 17)
                    } label: {
                        Text(PlanGridCopy.sets)
                    }
                }
                if let first = planned.orderedSets.first {
                    SetTargetEditor(
                        number: nil, set: first,
                        tracking: library.exercise(id: planned.exerciseID)?.tracking ?? .weightReps, units: units
                    ) { change in
                        for target in planned.orderedSets {
                            change(target)
                        }
                        PlanEditor.touched(planned)
                    }
                }
            } header: {
                Text(verbatim: name)
                    .brandFont(.exerciseTitle)
                    .foregroundStyle(Color.brand(\.ink))
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 320)
    }
}
