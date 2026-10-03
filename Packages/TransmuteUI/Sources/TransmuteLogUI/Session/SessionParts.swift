import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteUI

enum PickerPurpose: Identifiable {
    case add
    case substitute(LoggedExercise)

    var id: String {
        switch self {
        case .add: "add"
        case .substitute(let exercise): "substitute-\(exercise.persistentModelID.hashValue)"
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .add: LogCopy.addExercise
        case .substitute: LogCopy.substitute
        }
    }
}

enum NoteTarget: Identifiable {
    case workout
    case exercise(LoggedExercise)
    case set(LoggedSet, number: Int)

    var id: String {
        switch self {
        case .workout: "workout"
        case .exercise(let exercise): "exercise-\(exercise.persistentModelID.hashValue)"
        case .set(let set, _): "set-\(set.persistentModelID.hashValue)"
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .workout: LogCopy.workoutNotes
        case .exercise: LogCopy.notes
        case .set(_, let number): LogCopy.setNote(number)
        }
    }
}

/// An exercise's name over its sets, with a menu for substituting, notes and skipping.
struct ExerciseHeader<Actions: View>: View {
    let name: String
    let substitutedFor: String?
    let notes: String
    let isSkipped: Bool
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: name)
                    .brandFont(.exerciseTitle)
                    .foregroundStyle(isSkipped ? Color.brandText(\.subtext) : Color.brand(\.ink))
                    .strikethrough(isSkipped)
                    .accessibilityAddTraits(.isHeader)
                if let substitutedFor {
                    Text(LogCopy.substitutedFor(substitutedFor))
                        .brandFont(.label)
                        .foregroundStyle(Color.brandText(\.subtext))
                }
                if isSkipped {
                    Text(LogCopy.skipped)
                        .brandFont(.label)
                        .foregroundStyle(Color.brandText(\.subtext))
                }
                if !notes.isEmpty {
                    Text(verbatim: notes)
                        .brandFont(.label)
                        .foregroundStyle(Color.brandText(\.subtext))
                }
            }
            Spacer()
            Menu {
                actions()
            } label: {
                Image(systemName: "ellipsis.circle")
                    .imageScale(.large)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel(Text(LogCopy.more))
            }
        }
        .textCase(nil)
    }
}

/// A sheet with one text editor, for workout, exercise and set notes.
struct NoteEditor: View {
    let title: LocalizedStringResource
    @Binding var text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .brandFont(.body)
                .padding()
                .navigationTitle(Text(title))
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Text(LogCopy.save)
                        }
                    }
                }
        }
        .presentationDetents([.medium])
    }
}
