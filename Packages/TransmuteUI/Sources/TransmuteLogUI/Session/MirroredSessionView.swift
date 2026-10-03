import SwiftUI
import TransmuteCore
import TransmuteUI

extension EnvironmentValues {
    /// The link to the watch during a workout (#15). `nil` where there's no watch to link to:
    /// the Mac and previews.
    @Entry public var sessionLink: SessionLink?
}

/// A workout the Apple Watch is running, followed live on the iPhone (#15). The watch saves
/// it; this screen shows what the watch shows and can log, rest and finish from here too.
public struct MirroredSessionView: View {
    let link: SessionLink
    let units: Units
    let onHide: () -> Void

    @State private var values = SetValues()
    @State private var confirmsFinish = false

    public init(link: SessionLink, units: Units, onHide: @escaping () -> Void) {
        self.link = link
        self.units = units
        self.onHide = onHide
    }

    private var snapshot: SessionSnapshot? { link.mirrored }

    public var body: some View {
        NavigationStack {
            List {
                if let bpm = link.remoteHeartRate, snapshot?.isFinished == false {
                    heartRate(bpm)
                }
                ForEach(snapshot?.exercises ?? [], id: \.order) { exercise in
                    Section {
                        ForEach(Array(exercise.sets.enumerated()), id: \.element.order) { index, set in
                            row(set, number: index + 1, in: exercise)
                        }
                    } header: {
                        Text(verbatim: exercise.name)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.brand(\.base))
            .safeAreaInset(edge: .bottom) { bar }
            .navigationTitle(Text(verbatim: snapshot?.title ?? ""))
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onHide) {
                        Label {
                            Text(LogCopy.minimise)
                        } icon: {
                            Image(systemName: "chevron.down")
                        }
                    }
                }
                if snapshot?.isFinished == false {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            if snapshot?.current == nil {
                                link.send(.finish(at: .now))
                            } else {
                                confirmsFinish = true
                            }
                        } label: {
                            Text(LogCopy.finish)
                        }
                    }
                }
            }
            .confirmationDialog(
                Text(LogCopy.finishConfirm), isPresented: $confirmsFinish, titleVisibility: .visible
            ) {
                Button {
                    link.send(.finish(at: .now))
                } label: {
                    Text(LogCopy.finish)
                }
                Button(role: .cancel) {
                } label: {
                    Text(LogCopy.keepGoing)
                }
            }
        }
        .onChange(of: snapshot?.current, initial: true) {
            values = snapshot?.currentSet.map(SetValues.init) ?? SetValues()
        }
        .onChange(of: snapshot == nil) { _, isGone in
            // Discarded on the watch, or the watch went out of reach.
            if isGone { onHide() }
        }
    }

    // MARK: Rows

    private func heartRate(_ bpm: Double) -> some View {
        Label {
            Text(verbatim: "\(Int(bpm.rounded()))")
                .brandNumberFont(size: 20, relativeTo: .title3)
        } icon: {
            Image(systemName: "heart.fill")
        }
        .foregroundStyle(Color.brandText(\.alert))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(LogCopy.heartRate(Int(bpm.rounded()))))
    }

    private func row(_ set: SessionSnapshot.Set, number: Int, in exercise: SessionSnapshot.Exercise) -> some View {
        let dial = dial(for: exercise)
        let numbers = dial.fields.map { field in
            let text = dial.text(for: field, in: SetValues(set))
            return field == .weight ? "\(text) \(units.weightSymbol)" : text
        }
        let isCurrent = snapshot?.current == SetRef(exerciseOrder: exercise.order, setOrder: set.order)
        return HStack {
            Text(verbatim: set.isWarmUp ? "W" : "\(number)")
                .brandNumberFont(size: 17)
                .foregroundStyle(Color.brandText(\.subtext))
                .frame(width: 44, alignment: .leading)
            Text(verbatim: numbers.joined(separator: " × "))
                .brandNumberFont(size: 20, relativeTo: .title3)
                .foregroundStyle(Color.brand(\.ink))
            Spacer()
            Image(systemName: set.isCompleted ? "checkmark.circle.fill" : isCurrent ? "circle.dotted" : "circle")
                .foregroundStyle(
                    set.isCompleted ? Color.brand(\.done) : isCurrent ? Color.brand(\.now) : Color.brand(\.overlay0))
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(verbatim: "\(String(localized: LogCopy.set)) \(number), \(numbers.joined(separator: ", "))")
        )
        .accessibilityValue(Text(set.isCompleted ? LogCopy.logged : LogCopy.notLogged))
    }

    private func dial(for exercise: SessionSnapshot.Exercise) -> SetDial {
        let known = ExerciseLibrary.bundled.exercise(id: exercise.exerciseID)
        return SetDial(
            tracking: exercise.tracking ?? known?.tracking ?? .weightReps, equipment: known?.allEquipment ?? [],
            units: units)
    }

    // MARK: Bar

    /// Under the thumb, like the session screen's own bar: the rest countdown, the current set
    /// with steppers and Log set, or the end of the workout.
    @ViewBuilder private var bar: some View {
        VStack(spacing: 10) {
            Label {
                Text(LogCopy.onWatch)
            } icon: {
                Image(systemName: "applewatch")
            }
            .brandFont(.label)
            .foregroundStyle(Color.brandText(\.subtext))
            .frame(maxWidth: .infinity, alignment: .leading)
            if let snapshot {
                if snapshot.isFinished {
                    finished
                } else if let end = snapshot.restEndsAt, end > .now {
                    rest(until: end)
                } else if let ref = snapshot.current, let exercise = snapshot.currentExercise {
                    current(ref, in: exercise)
                } else {
                    Text(LogCopy.allLogged)
                        .brandFont(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    mainButton(LogCopy.finish) { link.send(.finish(at: .now)) }
                }
            }
        }
        .padding()
        .background(.bar)
    }

    private var finished: some View {
        Group {
            Text(LogCopy.finishedOnWatch)
                .brandFont(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
            mainButton(LogCopy.done) {
                link.dismissMirrored()
                onHide()
            }
        }
    }

    private func rest(until end: Date) -> some View {
        HStack {
            // Redraws when the rest ends, so the bar moves on to the next set.
            TimelineView(.explicit([end])) { _ in
                Text(timerInterval: Date.now...max(end, .now), countsDown: true)
                    .brandNumberFont(size: 24, relativeTo: .title2)
                    .foregroundStyle(Color.brandText(\.now))
                    .accessibilityLabel(Text(LogCopy.intervalRest))
            }
            Spacer()
            Button {
                link.send(.adjustRest(by: 15, at: .now))
            } label: {
                Image(systemName: "plus.circle")
                    .font(.title2)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(Text(LogCopy.addRest))
            Button {
                link.send(.startRest(seconds: nil, at: .now))
            } label: {
                Image(systemName: "forward.end.circle")
                    .font(.title2)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(Text(LogCopy.skipRest))
        }
        .buttonStyle(.borderless)
    }

    private func current(_ ref: SetRef, in exercise: SessionSnapshot.Exercise) -> some View {
        let dial = dial(for: exercise)
        return Group {
            Text(verbatim: exercise.name)
                .brandFont(.exerciseTitle)
                .foregroundStyle(Color.brand(\.ink))
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(dial.fields, id: \.self) { field in
                Stepper {
                    Text(verbatim: stepperLabel(field, dial))
                        .brandNumberFont(size: 20, relativeTo: .title3)
                } onIncrement: {
                    values = dial.adjusting(field, by: 1, in: values)
                } onDecrement: {
                    values = dial.adjusting(field, by: -1, in: values)
                }
            }
            mainButton(Copy.logSet) {
                link.send(.logSet(ref, values, at: .now))
            }
        }
    }

    private func stepperLabel(_ field: SetField, _ dial: SetDial) -> String {
        let text = dial.text(for: field, in: values)
        switch field {
        case .weight: return "\(text) \(units.weightSymbol)"
        case .reps: return "\(text) \(String(localized: LogCopy.reps).lowercased())"
        case .seconds, .meters: return text
        }
    }

    private func mainButton(_ title: LocalizedStringResource, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .brandFont(.exerciseTitle)
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.brand(\.magic))
    }
}
