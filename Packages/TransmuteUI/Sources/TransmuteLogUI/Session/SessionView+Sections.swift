import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteUI

/// The exercise sections, menus, sheets and names the session screen is built from.
extension SessionView {
    // MARK: Sections

    @ViewBuilder func exerciseSection(_ exercise: LoggedExercise) -> some View {
        let tracking = library.exercise(id: exercise.exerciseID)?.tracking ?? .weightReps
        let equipment = library.exercise(id: exercise.exerciseID)?.allEquipment ?? []
        Section {
            if !exercise.isSkipped {
                // Stacked rows name their own fields, so the columns' header goes (#60).
                if !typeSize.isAccessibilitySize {
                    SetTableHeader(tracking: tracking, units: units)
                }
                ForEach(Array(exercise.orderedSets.enumerated()), id: \.element.persistentModelID) { index, set in
                    SetRow(
                        set: set, number: index + 1, total: exercise.orderedSets.count, tracking: tracking,
                        equipment: equipment, units: units,
                        plates: usesPlates(equipment) ? profile?.plates : nil, isCurrent: set === current,
                        isEditing: editing == set.persistentModelID,
                        onTap: { editing = editing == set.persistentModelID ? nil : set.persistentModelID },
                        onToggle: { toggle(set) },
                        onNote: { noteFor = .set(set, number: index + 1) },
                        onRemove: { WorkoutSession.remove(set, from: exercise) }
                    )
                    .id(set.persistentModelID)
                }
                Button {
                    let set = WorkoutSession.addSet(to: exercise)
                    editing = set.persistentModelID
                } label: {
                    Label {
                        Text(LogCopy.addSet)
                    } icon: {
                        Image(systemName: "plus")
                    }
                }
                .buttonStyle(.borderless)
            }
        } header: {
            ExerciseHeader(
                name: name(of: exercise), substitutedFor: exercise.substitutedFromID.map(name(ofID:)),
                notes: exercise.notes, isSkipped: exercise.isSkipped
            ) {
                exerciseMenu(exercise)
            }
        }
    }

    @ViewBuilder func exerciseMenu(_ exercise: LoggedExercise) -> some View {
        Button {
            picker = .substitute(exercise)
        } label: {
            Label {
                Text(LogCopy.substitute)
            } icon: {
                Image(systemName: "arrow.left.arrow.right")
            }
        }
        Button {
            noteFor = .exercise(exercise)
        } label: {
            Label {
                Text(LogCopy.notes)
            } icon: {
                Image(systemName: "note.text")
            }
        }
        Button {
            WorkoutSession.setSkipped(exercise, !exercise.isSkipped)
        } label: {
            Label {
                Text(exercise.isSkipped ? LogCopy.unskip : LogCopy.skip)
            } icon: {
                Image(systemName: exercise.isSkipped ? "arrow.uturn.backward" : "forward")
            }
        }
        if let profile {
            let isHeld = profile.progression.isHeld(exercise.exerciseID)
            Button {
                profile.toggleProgressionHold(for: exercise.exerciseID)
                try? context.save()
            } label: {
                Label {
                    Text(isHeld ? ProgressionCopy.letItProgress : ProgressionCopy.holdWeight)
                } icon: {
                    Image(systemName: isHeld ? "arrow.up.right" : "pause")
                }
            }
        }
    }

    @ToolbarContentBuilder var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                onHide()
            } label: {
                Label {
                    Text(LogCopy.minimise)
                } icon: {
                    Image(systemName: "chevron.down")
                }
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Menu {
                Button {
                    finish(confirming: current != nil)
                } label: {
                    Text(LogCopy.finish)
                }
                Button(role: .destructive) {
                    confirmsDiscard = true
                } label: {
                    Text(LogCopy.discard)
                }
            } label: {
                Text(LogCopy.finish)
            } primaryAction: {
                finish(confirming: current != nil)
            }
        }
    }

    @ViewBuilder func pickerSheet(_ purpose: PickerPurpose) -> some View {
        NavigationStack {
            ExercisePicker(
                initialQuery: ExerciseQuery(
                    availableEquipment: Set(profile?.equipment ?? Equipment.allCases).union([.bodyweight]))
            ) { exercise in
                switch purpose {
                case .add:
                    let added = WorkoutSession.add(exercise, to: workout)
                    editing = added.orderedSets.first?.persistentModelID
                case .substitute(let logged):
                    WorkoutSession.substitute(logged, with: exercise, in: workout, library: library)
                }
                picker = nil
            }
            .navigationTitle(Text(purpose.title))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        picker = nil
                    } label: {
                        Text(LogCopy.keepGoing)
                    }
                }
            }
        }
    }

    // MARK: Names and notes

    func name(of exercise: LoggedExercise) -> String {
        name(ofID: exercise.exerciseID)
    }

    func name(of set: LoggedSet) -> String {
        set.exercise.map(name(of:)) ?? workout.title
    }

    func name(ofID id: String) -> String {
        library.exercise(id: id)?.name ?? id
    }

    func noteBinding(_ target: NoteTarget) -> Binding<String> {
        switch target {
        case .workout:
            Binding {
                workout.notes
            } set: {
                workout.notes = $0
            }
        case .exercise(let exercise):
            Binding {
                exercise.notes
            } set: {
                exercise.notes = $0
            }
        case .set(let set, _):
            Binding {
                set.notes
            } set: {
                set.notes = $0
            }
        }
    }

    /// Barbell and trap bar lifts get the plate calculator, when the person has one.
    func usesPlates(_ equipment: Set<Equipment>) -> Bool {
        let kit = Set(profile?.equipment ?? [])
        return !equipment.isDisjoint(with: [.barbell, .trapBar]) && !kit.isDisjoint(with: [.barbell, .trapBar])
    }
}
