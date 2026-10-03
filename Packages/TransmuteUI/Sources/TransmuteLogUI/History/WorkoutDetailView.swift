import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteUI

/// One past workout (#14): every exercise and set, notes, the plan day it came from, and
/// its records. Any set can be changed or deleted, and the whole workout can go; records are
/// rebuilt after each change and progression reads the log as it is.
struct WorkoutDetailView: View {
    @Bindable var workout: Workout
    let profile: Profile
    /// Set when whoever shows this view deletes the workout itself, as the Mac's log table
    /// does: Delete workout asks them instead of confirming and dismissing here.
    var onDelete: (() -> Void)?

    @Environment(\.modelContext) private var context
    @Environment(\.health) private var health
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CustomExercise.name) private var customExercises: [CustomExercise]
    @Query private var records: [PersonalRecord]
    @State private var editing: LoggedSet?
    @State private var confirmsDelete = false
    @State private var healthDeleteFailed = false

    private var library: ExerciseLibrary {
        ExerciseLibrary.bundled.adding(customExercises.map(LibraryExercise.init))
    }

    private var units: Units {
        Units(profile)
    }

    var body: some View {
        List {
            Section {
                TextField(text: $workout.title) {
                    Text(HistoryCopy.editTitle)
                }
                .brandFont(.exerciseTitle)
                DatePicker(selection: $workout.startedAt) {
                    Text(HistoryCopy.started)
                }
                Text(planLine)
                    .brandFont(.label)
                    .foregroundStyle(Color.brandText(\.subtext))
                WorkoutRow(workout: workout, units: units, hasGold: false)
            }
            ForEach(workout.orderedExercises) { exercise in
                exerciseSection(exercise)
            }
            Section {
                TextField(text: $workout.notes, axis: .vertical) {
                    Text(LogCopy.workoutNotes)
                }
            } header: {
                Text(LogCopy.workoutNotes)
            }
            Section {
                Button(role: .destructive) {
                    if let onDelete {
                        onDelete()
                    } else {
                        confirmsDelete = true
                    }
                } label: {
                    Text(HistoryCopy.delete)
                        .frame(minHeight: 44)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.brand(\.base))
        .navigationTitle(Text(verbatim: workout.title))
        .sheet(item: $editing) { set in
            LoggedSetEditor(
                set: set, tracking: library.exercise(id: set.exercise?.exerciseID ?? "")?.tracking ?? .weightReps,
                units: units
            ) {
                try? WorkoutLog.edited(set, in: context, library: library)
            }
        }
        .confirmationDialog(
            Text(Copy.deleteWorkout(workout.title, date: workout.startedAt.formatted(.dateTime.month().day()))),
            isPresented: $confirmsDelete, titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                Task { await delete() }
            } label: {
                Text(HistoryCopy.delete)
            }
        }
        .alert(Text(HistoryCopy.healthDeleteFailed), isPresented: $healthDeleteFailed) {
            Button {
                dismiss()
            } label: {
                Text(LogCopy.keepGoing)
            }
        }
    }

    private var planLine: LocalizedStringResource {
        guard let day = workout.planDay else { return HistoryCopy.offPlan }
        return HistoryCopy.fromPlanDay(week: day.week, focus: day.focus)
    }

    private func exerciseSection(_ exercise: LoggedExercise) -> some View {
        let tracking = library.exercise(id: exercise.exerciseID)?.tracking ?? .weightReps
        let name = library.exercise(id: exercise.exerciseID)?.name ?? exercise.exerciseID
        return Section {
            SetTableHeader(tracking: tracking, units: units)
            ForEach(Array(exercise.orderedSets.enumerated()), id: \.element.persistentModelID) { index, set in
                Button {
                    editing = set
                } label: {
                    PastSetRow(
                        set: set, number: index + 1, tracking: tracking, units: units,
                        gold: records.filter { $0.set === set }.map(\.mark))
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button(role: .destructive) {
                        try? WorkoutLog.delete(set, in: context, library: library)
                    } label: {
                        Text(HistoryCopy.deleteSet)
                    }
                }
                // The same delete without a swipe, for a mouse.
                .contextMenu {
                    Button(role: .destructive) {
                        try? WorkoutLog.delete(set, in: context, library: library)
                    } label: {
                        Text(HistoryCopy.deleteSet)
                    }
                }
            }
            if !exercise.notes.isEmpty {
                Text(verbatim: exercise.notes)
                    .brandFont(.label)
                    .foregroundStyle(Color.brandText(\.subtext))
            }
            NavigationLink {
                ExerciseHistoryView(exerciseID: exercise.exerciseID, name: name, units: units)
            } label: {
                Text(HistoryCopy.exerciseHistory)
            }
        } header: {
            Text(verbatim: name)
                .brandFont(.exerciseTitle)
                .foregroundStyle(Color.brand(\.ink))
                .textCase(nil)
        }
    }

    /// Deletes here first, then the Health copy if Transmute wrote one. If Health refuses, the
    /// person is told to remove it there.
    private func delete() async {
        let healthID = try? WorkoutLog.delete(workout, in: context, library: library)
        guard let healthID, health.isAvailable else {
            dismiss()
            return
        }
        do {
            try await health.requestAccess(.workouts)
            try await health.deleteWorkout(id: healthID)
            dismiss()
        } catch {
            healthDeleteFailed = true
        }
    }
}

/// A logged set read-only: its numbers, its note, and gold for any record it set.
struct PastSetRow: View {
    let set: LoggedSet
    let number: Int
    let tracking: TrackingType
    let units: Units
    let gold: [RecordMark]

    @Environment(\.effortDisplay) private var effort

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(verbatim: set.isWarmUp ? "W" : "\(number)")
                    .brandNumberFont(size: 17)
                    .foregroundStyle(Color.brandText(\.subtext))
                    .frame(width: 44, alignment: .leading)
                ForEach(SetColumn.columns(for: tracking), id: \.self) { column in
                    Text(verbatim: column.value(of: set, units: units))
                        .brandNumberFont(size: 18)
                        .foregroundStyle(gold.isEmpty ? Color.brand(\.ink) : Color.brandText(\.gold))
                        .frame(maxWidth: .infinity)
                }
                Image(systemName: gold.isEmpty ? "pencil" : "medal.fill")
                    .foregroundStyle(gold.isEmpty ? Color.brandText(\.subtext) : Color.brand(\.gold))
                    .frame(width: 44)
            }
            if effort.showsRPE, let rpe = set.rpe {
                Text(verbatim: "RPE \(rpe.formatted(.number.precision(.fractionLength(0...1))))")
                    .brandFont(.label)
                    .foregroundStyle(Color.brandText(\.subtext))
            }
            if !gold.isEmpty {
                Text(
                    verbatim: gold.map { String(localized: RecordFormat.label($0, units: units)) }.joined(
                        separator: " · ")
                )
                .brandFont(.label)
                .foregroundStyle(Color.brandText(\.gold))
            }
            if !set.notes.isEmpty {
                Text(verbatim: set.notes)
                    .brandFont(.label)
                    .foregroundStyle(Color.brandText(\.subtext))
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text(HistoryCopy.editSet))
    }
}

/// Changes a past set with the same steppers the session uses, plus its note.
struct LoggedSetEditor: View {
    @Bindable var set: LoggedSet
    let tracking: TrackingType
    let units: Units
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                SetEditor(set: set, tracking: tracking, equipment: [], units: units, plates: nil, timers: false) {}
                Toggle(isOn: $set.isWarmUp) {
                    Text(LogCopy.warmUp)
                }
                TextField(text: $set.notes, axis: .vertical) {
                    Text(LogCopy.notes)
                }
            }
            .navigationTitle(Text(HistoryCopy.editSet))
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
        // Saves however the sheet closes, so a swipe down keeps the change too.
        .onDisappear(perform: onSave)
    }
}
