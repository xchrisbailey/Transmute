import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteIntelligence
import TransmuteUI

/// One planned exercise: how to do it, and its sets to change. Steppers and number fields
/// rather than pickers, so it's easy with big text and switch control (#22).
struct PlannedExerciseView: View {
    @Bindable var planned: PlannedExercise
    let equipment: Set<Equipment>
    let units: Units

    @Environment(\.modelContext) private var context
    @State private var applyToAll = true
    @State private var showsSwap = false
    let library = ExerciseLibrary.bundled

    private var exercise: LibraryExercise? {
        library.exercise(id: planned.exerciseID)
    }

    var body: some View {
        List {
            if let exercise {
                Section {
                    ForEach(exercise.cues, id: \.self) { cue in
                        Label {
                            Text(verbatim: cue)
                        } icon: {
                            Image(systemName: "checkmark")
                        }
                    }
                } header: {
                    Text(PlanCopy.howTo)
                }
                if !exercise.mistakes.isEmpty {
                    Section {
                        ForEach(exercise.mistakes, id: \.self) { mistake in
                            Label {
                                Text(verbatim: mistake)
                            } icon: {
                                Image(systemName: "exclamationmark.triangle")
                            }
                        }
                    } header: {
                        Text(PlanCopy.watchFor)
                    }
                }
            }
            Section {
                Toggle(isOn: $applyToAll) {
                    Text(PlanCopy.applyToAll)
                }
                ForEach(Array(planned.orderedSets.enumerated()), id: \.element.persistentModelID) { index, set in
                    if !applyToAll || index == 0 {
                        SetTargetEditor(
                            number: index + 1, set: set, tracking: exercise?.tracking ?? .weightReps, units: units
                        ) { change in
                            for target in applyToAll ? planned.orderedSets : [set] {
                                change(target)
                            }
                            PlanEditor.touched(planned)
                        }
                    }
                }
                HStack {
                    Button {
                        PlanEditor.addSet(to: planned)
                    } label: {
                        Label {
                            Text(PlanCopy.addSet)
                        } icon: {
                            Image(systemName: "plus")
                        }
                    }
                    Spacer()
                    Button(role: .destructive) {
                        PlanEditor.removeSet(from: planned, in: context)
                    } label: {
                        Label {
                            Text(PlanCopy.removeSet)
                        } icon: {
                            Image(systemName: "minus")
                        }
                    }
                    .disabled(planned.orderedSets.count <= 1)
                }
                .buttonStyle(.borderless)
            } header: {
                Text(PlanCopy.targets)
            }
            Section {
                Button {
                    showsSwap = true
                } label: {
                    Label {
                        Text(PlanCopy.swap)
                    } icon: {
                        Image(systemName: "arrow.left.arrow.right")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.brand(\.base))
        .navigationTitle(Text(verbatim: exercise?.name ?? planned.exerciseID))
        .toolbar { UndoButtons() }
        .sheet(isPresented: $showsSwap) {
            SwapSheet(planned: planned, equipment: equipment)
        }
    }
}

/// The fields one set needs, by how the exercise is measured.
struct SetTargetEditor: View {
    /// The set's number for its heading; nil where the fields stand for every set (#17).
    let number: Int?
    let set: PlannedSet
    let tracking: TrackingType
    let units: Units
    /// Applies a change, to this set or every set.
    let change: ((PlannedSet) -> Void) -> Void

    @Environment(\.effortDisplay) private var effort

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let number {
                Text(PlanCopy.setNumber(number))
                    .brandFont(.label)
                    .foregroundStyle(Color.brandText(\.subtext))
            }
            switch tracking {
            case .weightReps:
                intStepper(PlanCopy.reps, value: set.targetReps ?? 8, range: 1...30) { $0.targetReps = $1 }
                weightField
                rpeStepper
            case .reps:
                intStepper(PlanCopy.reps, value: set.targetReps ?? 10, range: 1...100) { $0.targetReps = $1 }
                rpeStepper
            case .time:
                intStepper(PlanCopy.seconds, value: Int(set.targetSeconds ?? 30), range: 5...600, step: 5) {
                    $0.targetSeconds = Double($1)
                }
            case .distanceTime:
                intStepper(PlanCopy.meters, value: Int(set.targetMeters ?? 20), range: 5...10_000, step: 5) {
                    $0.targetMeters = Double($1)
                }
            case .intervals:
                intStepper(PlanCopy.rounds, value: set.rounds ?? 8, range: 1...30) { $0.rounds = $1 }
                intStepper(PlanCopy.seconds, value: Int(set.targetSeconds ?? 20), range: 5...300, step: 5) {
                    $0.targetSeconds = Double($1)
                }
            }
            intStepper(PlanCopy.rest, value: Int(set.restSeconds ?? 60), range: 0...600, step: 15) {
                $0.restSeconds = Double($1)
            }
        }
    }

    private var weightField: some View {
        LabeledContent {
            TextField(
                value: Binding(
                    get: { set.targetLoadKg.map { (units.displayWeight(kg: $0) * 2).rounded() / 2 } },
                    set: { value in change { $0.targetLoadKg = value.map(units.kilograms(fromDisplay:)) } }),
                format: .number.precision(.fractionLength(0...1))
            ) {
                Text(PlanCopy.load)
            }
            // The row already has its label; the Mac would draw the field's as well.
            .labelsHidden()
            .multilineTextAlignment(.trailing)
            .brandNumberFont(size: 17)
            #if os(iOS)
                .keyboardType(.decimalPad)
            #endif
            Text(verbatim: units.weightSymbol)
                .accessibilityHidden(true)
        } label: {
            Text(PlanCopy.load)
        }
    }

    @ViewBuilder private var rpeStepper: some View {
        if effort.showsRPE, let rpe = set.targetRPE {
            Stepper(
                value: Binding(get: { rpe }, set: { value in change { $0.targetRPE = value } }), in: 5...10, step: 0.5
            ) {
                LabeledContent {
                    Text(rpe, format: .number.precision(.fractionLength(0...1)))
                        .brandNumberFont(size: 17)
                } label: {
                    Text(PlanCopy.rpe)
                }
            }
        }
    }

    private func intStepper(
        _ label: LocalizedStringResource, value: Int, range: ClosedRange<Int>, step: Int = 1,
        apply: @escaping (PlannedSet, Int) -> Void
    ) -> some View {
        Stepper(
            value: Binding(get: { value }, set: { new in change { apply($0, new) } }), in: range, step: step
        ) {
            LabeledContent {
                Text(value, format: .number)
                    .brandNumberFont(size: 17)
            } label: {
                Text(label)
            }
        }
    }
}

/// Swap for something similar (same pattern, doable with the kit), or search everything.
struct SwapSheet: View {
    let planned: PlannedExercise
    let equipment: Set<Equipment>
    @Environment(\.dismiss) private var dismiss
    @State private var searchesEverything = false
    let library = ExerciseLibrary.bundled

    var body: some View {
        NavigationStack {
            Group {
                if searchesEverything {
                    ExercisePicker(initialQuery: ExerciseQuery(availableEquipment: equipment.union([.bodyweight]))) {
                        pick($0)
                    }
                } else {
                    List {
                        Section {
                            ForEach(
                                PlanEditor.alternatives(
                                    to: planned.exerciseID, equipment: equipment.union([.bodyweight]))
                            ) { exercise in
                                Button {
                                    pick(exercise)
                                } label: {
                                    ExerciseRow(exercise: exercise)
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Text(PlanCopy.similar)
                        }
                        Button {
                            searchesEverything = true
                        } label: {
                            Label {
                                Text(PlanCopy.searchAll)
                            } icon: {
                                Image(systemName: "magnifyingglass")
                            }
                        }
                    }
                }
            }
            .navigationTitle(
                Text(PlanCopy.swapTitle(library.exercise(id: planned.exerciseID)?.name ?? planned.exerciseID))
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text(ProfileCopy.cancel)
                    }
                }
            }
        }
    }

    private func pick(_ exercise: LibraryExercise) {
        PlanEditor.swap(planned, for: exercise)
        dismiss()
    }
}
