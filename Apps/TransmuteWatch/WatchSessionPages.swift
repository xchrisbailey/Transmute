import SwiftUI
import TransmuteCore
import TransmuteUI
import WatchKit

/// Left of the set screen: finish, skip the exercise, lock the screen, or throw the workout
/// away.
struct WatchControlsView: View {
    let session: WatchSession
    /// Goes back to the set screen.
    let onReturn: () -> Void

    @State private var confirmsFinish = false
    @State private var confirmsDiscard = false

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Button {
                    if session.snapshot.current == nil {
                        session.perform(.finish(at: .now))
                    } else {
                        confirmsFinish = true
                    }
                } label: {
                    label(WatchCopy.finish, "flag.checkered")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brand(\.magic))
                .foregroundStyle(Color.watchScreen)
                if let ref = session.snapshot.current {
                    Button {
                        session.perform(.setSkipped(exerciseOrder: ref.exerciseOrder, true))
                        onReturn()
                    } label: {
                        label(WatchCopy.skipExercise, "forward.end")
                    }
                }
                Button {
                    WKInterfaceDevice.current().enableWaterLock()
                    onReturn()
                } label: {
                    label(WatchCopy.waterLock, "drop.fill")
                }
                .accessibilityHint(Text(WatchCopy.waterLockHint))
                Button(role: .destructive) {
                    confirmsDiscard = true
                } label: {
                    label(WatchCopy.discard, "trash")
                }
            }
            .padding(.horizontal, 4)
        }
        .confirmationDialog(Text(WatchCopy.finishConfirm), isPresented: $confirmsFinish, titleVisibility: .visible) {
            Button {
                session.perform(.finish(at: .now))
            } label: {
                Text(WatchCopy.finish)
            }
            Button(role: .cancel) {
            } label: {
                Text(WatchCopy.keepGoing)
            }
        }
        .confirmationDialog(Text(WatchCopy.discardConfirm), isPresented: $confirmsDiscard, titleVisibility: .visible) {
            Button(role: .destructive) {
                session.perform(.discard)
            } label: {
                Text(WatchCopy.discard)
            }
            Button(role: .cancel) {
            } label: {
                Text(WatchCopy.keepGoing)
            }
        }
    }

    private func label(_ text: LocalizedStringResource, _ symbol: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: symbol)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Right of the set screen: every exercise and how much of it is logged.
struct WatchExercisesView: View {
    let snapshot: SessionSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text(WatchCopy.exercises)
                    .brandFont(.label)
                    .foregroundStyle(Color.brandText(\.subtext))
                    .accessibilityAddTraits(.isHeader)
                ForEach(snapshot.exercises, id: \.order) { exercise in
                    row(exercise)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func row(_ exercise: SessionSnapshot.Exercise) -> some View {
        let done = exercise.sets.filter(\.isCompleted).count
        let isDone = done == exercise.sets.count && done > 0
        let isCurrent = snapshot.current?.exerciseOrder == exercise.order
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: exercise.name)
                    .brandFont(.label)
                    .foregroundStyle(Color.brand(\.ink))
                Text(exercise.isSkipped ? WatchCopy.skipped : WatchCopy.setsLogged(done, of: exercise.sets.count))
                    .font(.caption2)
                    .foregroundStyle(Color.brandText(\.subtext))
            }
            Spacer(minLength: 4)
            if isDone {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.brand(\.done))
            } else if isCurrent {
                Image(systemName: "arrowtriangle.left.fill")
                    .imageScale(.small)
                    .foregroundStyle(Color.brand(\.now))
            }
        }
        .padding(8)
        .background(Color.watchPlatter, in: .rect(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}

/// After Finish: the sets, the weight moved and the time, then Done.
struct WatchSummaryView: View {
    let session: WatchSession
    let summary: WorkoutSummary
    let units: Units
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(WatchCopy.workoutDone)
                    .brandFont(.exerciseTitle)
                    .foregroundStyle(Color.brand(\.ink))
                    .accessibilityAddTraits(.isHeader)
                figure(WatchCopy.sets, "\(summary.sets)")
                if summary.volumeKg > 0 {
                    figure(WatchCopy.volume, units.formatWeight(kg: summary.volumeKg))
                }
                figure(WatchCopy.duration, Units.clock(seconds: summary.duration))
                if let bpm = session.live.averageHeartRate {
                    figure(WatchCopy.averageHeartRate, "\(Int(bpm.rounded()))")
                }
                if let energy = session.live.activeEnergyKcal {
                    figure(WatchCopy.energy, "\(Int(energy.rounded())) kcal")
                }
                if session.isSavedToHealth {
                    Label {
                        Text(WatchCopy.savedToHealth)
                    } icon: {
                        Image(systemName: "heart.fill")
                    }
                    .font(.footnote)
                    .foregroundStyle(Color.brandText(\.subtext))
                }
                Button(action: onDone) {
                    Text(WatchCopy.done)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brand(\.magic))
                .foregroundStyle(Color.watchScreen)
            }
            .padding(.horizontal, 4)
        }
    }

    private func figure(_ label: LocalizedStringResource, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .brandFont(.label)
                .foregroundStyle(Color.brandText(\.subtext))
            Spacer()
            Text(verbatim: value)
                .brandNumberFont(size: 20, relativeTo: .title3)
                .foregroundStyle(Color.brand(\.ink))
        }
        .accessibilityElement(children: .combine)
    }
}
