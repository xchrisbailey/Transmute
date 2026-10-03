import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteUI

/// The workout in progress (#11): exercise by exercise, a set table prefilled from the plan,
/// and one big button at the bottom that logs the current set or shows the rest timer. Built
/// to be run with one thumb: the button sits where the thumb is, and the list follows along.
public struct SessionView: View {
    @Bindable var workout: Workout
    let profile: Profile?
    /// Closes the screen. The workout keeps running and Today offers to resume it.
    let onHide: () -> Void

    @Environment(\.modelContext) var context
    @Environment(\.sessionLink) var link
    @Query(sort: \CustomExercise.name) private var customExercises: [CustomExercise]
    @State var editing: PersistentIdentifier?
    @State var picker: PickerPurpose?
    @State var noteFor: NoteTarget?
    @State var confirmsFinish = false
    @State var confirmsDiscard = false
    @State var summary: WorkoutSummary?
    @State var restEnded = 0
    @State var gold: GoldNotice?
    @State var suspicious: LoggedSet?
    @State var activity = SessionActivity()

    public init(workout: Workout, profile: Profile?, onHide: @escaping () -> Void) {
        self.workout = workout
        self.profile = profile
        self.onHide = onHide
    }

    var library: ExerciseLibrary {
        ExerciseLibrary.bundled.adding(customExercises.map(LibraryExercise.init))
    }

    var units: Units {
        Units(system: profile?.unitSystem)
    }

    var current: LoggedSet? {
        WorkoutSession.currentSet(of: workout)
    }

    public var body: some View {
        NavigationStack {
            ScrollViewReader { scroller in
                List {
                    ForEach(workout.orderedExercises) { exercise in
                        exerciseSection(exercise)
                    }
                    Section {
                        Button {
                            picker = .add
                        } label: {
                            Label {
                                Text(LogCopy.addExercise)
                            } icon: {
                                Image(systemName: "plus")
                            }
                        }
                        Button {
                            noteFor = .workout
                        } label: {
                            Label {
                                Text(LogCopy.workoutNotes)
                            } icon: {
                                Image(systemName: "note.text")
                            }
                        }
                        if !workout.notes.isEmpty {
                            Text(verbatim: workout.notes)
                                .brandFont(.body)
                                .foregroundStyle(Color.brandText(\.subtext))
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.brand(\.base))
                .onChange(of: current?.persistentModelID, initial: true) { _, id in
                    editing = id
                    if let id {
                        withAnimation { scroller.scrollTo(id, anchor: .center) }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                SessionBar(
                    workout: workout, current: current, exerciseName: current.map(name(of:)),
                    onLog: logCurrent, onFinish: { finish(confirming: current != nil) })
            }
            .navigationTitle(Text(verbatim: workout.title))
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { toolbar }
            .sheet(item: $picker) { purpose in
                pickerSheet(purpose)
            }
            .sheet(item: $noteFor) { target in
                NoteEditor(title: target.title, text: noteBinding(target))
            }
            .confirmationDialog(
                Text(LogCopy.finishConfirm), isPresented: $confirmsFinish, titleVisibility: .visible
            ) {
                Button {
                    finish(confirming: false)
                } label: {
                    Text(LogCopy.finish)
                }
                Button(role: .cancel) {
                } label: {
                    Text(LogCopy.keepGoing)
                }
            }
            .confirmationDialog(
                Text(LogCopy.discardConfirm), isPresented: $confirmsDiscard, titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    activity.end()
                    RestAlerts.cancel()
                    link?.discarded()
                    WorkoutSession.discard(workout, in: context)
                    onHide()
                } label: {
                    Text(LogCopy.discard)
                }
            }
            .navigationDestination(item: $summary) { summary in
                FinishView(workout: workout, summary: summary, units: units, onSave: onHide)
            }
        }
        .task(id: workout.restEndsAt) {
            await waitForRest()
        }
        .onChange(of: activityState, initial: true) { _, state in
            guard workout.endedAt == nil else { return }
            activity.update(title: workout.title, state: state)
            RestAlerts.schedule(
                at: workout.restEndsAt, next: current.map(name(of:)) ?? workout.title)
        }
        .onChange(of: SessionSnapshot(workout, library: library)) {
            // Every change made here goes to the watch.
            link?.publish()
        }
        .onAppear {
            link?.onCommand = { command, outcome in fromWatch(command, outcome) }
        }
        .overlay(alignment: .top) {
            goldToast
        }
        .confirmationDialog(Text(LogCopy.bigJump), isPresented: suspiciousBinding, titleVisibility: .visible) {
            Button {
                confirmSuspicious()
            } label: {
                Text(LogCopy.itsRight)
            }
            Button(role: .cancel) {
                fixSuspicious()
            } label: {
                Text(LogCopy.fixIt)
            }
        }
        .sensoryFeedback(.success, trigger: restEnded)
        .task {
            await RestAlerts.requestPermission()
        }
    }

    // MARK: Actions

    private func logCurrent() {
        guard let current else { return }
        toggle(current)
    }

    func finish(confirming: Bool) {
        if confirming {
            confirmsFinish = true
            return
        }
        RestAlerts.cancel()
        activity.end()
        summary = WorkoutSession.finish(workout)
    }

    /// The watch logged, reopened, finished or discarded: the workout is already changed, so
    /// this catches the screen and the records up.
    private func fromWatch(_ command: SessionCommand, _ outcome: SessionMirror.Outcome) {
        switch outcome {
        case .ignored:
            break
        case .discarded:
            activity.end()
            RestAlerts.cancel()
            onHide()
        case .finished(let summary):
            activity.end()
            RestAlerts.cancel()
            self.summary = summary
        case .applied:
            let exerciseOrder: Int? =
                switch command {
                case .logSet(let ref, _, _), .reopenSet(let ref): ref.exerciseOrder
                default: nil
                }
            guard let exercise = workout.orderedExercises.first(where: { $0.order == exerciseOrder }) else { return }
            _ = try? RecordBook(context: context, library: library).recompute(exerciseID: exercise.exerciseID)
            try? context.save()
        }
    }

    /// Sleeps until the rest ends, then buzzes, chimes and clears the timer. Runs again
    /// whenever the end moves, so skipping or adding time just restarts the wait.
    private func waitForRest() async {
        guard let remaining = WorkoutSession.restRemaining(in: workout) else {
            if workout.restEndsAt != nil { WorkoutSession.startRest(nil, in: workout) }
            return
        }
        do {
            try await Task.sleep(for: .seconds(remaining))
        } catch {
            return
        }
        RestAlerts.chime()
        restEnded += 1
        WorkoutSession.startRest(nil, in: workout)
    }

    private var activityState: SessionActivityAttributes.ContentState {
        let exercise = current?.exercise
        return SessionActivityAttributes.ContentState(
            exercise: exercise.map(name(of:)) ?? workout.title,
            setNumber: (current?.order ?? 0) + 1,
            setCount: exercise?.orderedSets.count ?? 0,
            restEndsAt: workout.restEndsAt,
            restSeconds: workout.restSeconds)
    }

}
