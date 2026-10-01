import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteUI

/// The bar under the thumb: the rest countdown while resting, otherwise one big button that
/// logs the current set, and Finish once every set is in.
struct SessionBar: View {
    let workout: Workout
    let current: LoggedSet?
    let exerciseName: String?
    let onLog: () -> Void
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            if let end = workout.restEndsAt, end > .now {
                RestTimer(workout: workout, end: end)
            } else if let current, let exerciseName {
                Text(
                    verbatim:
                        "\(exerciseName) · \(String(localized: LogCopy.setOf(current.order + 1, of: current.exercise?.orderedSets.count ?? 1)))"
                )
                .brandFont(.label)
                .foregroundStyle(Color.brandText(\.subtext))
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(LogCopy.allLogged)
                    .brandFont(.label)
                    .foregroundStyle(Color.brandText(\.subtext))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if current != nil {
                Button(action: onLog) {
                    Label {
                        Text(Copy.logSet)
                    } icon: {
                        Image(systemName: "checkmark")
                    }
                    .brandFont(.exerciseTitle)
                    .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brand(\.magic))
            } else {
                Button(action: onFinish) {
                    Text(LogCopy.finish)
                        .brandFont(.exerciseTitle)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brand(\.magic))
            }
        }
        .padding()
        .background(.bar)
    }
}

/// "Rest 1:48" in peach with a draining ring, and buttons to add, take away or skip.
struct RestTimer: View {
    let workout: Workout
    let end: Date

    var body: some View {
        HStack(spacing: 12) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = max(0, end.timeIntervalSince(context.date))
                let total = max(workout.restSeconds ?? remaining, 1)
                HStack(spacing: 10) {
                    ZStack {
                        Circle().stroke(Color.brand(\.surface1), lineWidth: 5)
                        Circle()
                            .trim(from: 0, to: remaining / total)
                            .stroke(Color.brand(\.now), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 36, height: 36)
                    .accessibilityHidden(true)
                    Text(Copy.rest(Units.clock(seconds: remaining.rounded(.up))))
                        .brandNumberFont(size: 24, relativeTo: .title2)
                        .foregroundStyle(Color.brandText(\.now))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .fixedSize(horizontal: true, vertical: false)
                        .contentTransition(.numericText(countsDown: true))
                }
            }
            Spacer()
            restButton("minus", label: LogCopy.lessRest) {
                WorkoutSession.adjustRest(by: -15, in: workout)
            }
            restButton("plus", label: LogCopy.addRest) {
                WorkoutSession.adjustRest(by: 15, in: workout)
            }
            restButton("forward.end", label: LogCopy.skipRest) {
                WorkoutSession.startRest(nil, in: workout)
            }
        }
    }

    private func restButton(
        _ symbol: String, label: LocalizedStringResource, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: "\(symbol).circle")
                .font(.title2)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(Text(label))
    }
}

/// A countdown for timed sets and intervals: work, then rest, round after round, with a
/// buzz at each change. Checks the set off when the last round ends.
struct TimedSet: View {
    let set: LoggedSet
    let rounds: Int
    let work: Double
    let rest: Double
    let onDone: () -> Void

    @State private var startedAt: Date?
    @State private var phaseChanges = 0

    var body: some View {
        if let startedAt {
            TimelineView(.periodic(from: startedAt, by: 0.25)) { context in
                let phase = IntervalPhase.at(
                    context.date.timeIntervalSince(startedAt), rounds: rounds, work: work, rest: rest)
                HStack {
                    VStack(alignment: .leading) {
                        Text(phase.isWork ? LogCopy.work : LogCopy.intervalRest)
                            .brandFont(.label)
                            .foregroundStyle(phase.isWork ? Color.brandText(\.now) : Color.brandText(\.subtext))
                        if rounds > 1 {
                            Text(LogCopy.round(phase.round, of: rounds))
                                .brandFont(.label)
                                .foregroundStyle(Color.brandText(\.subtext))
                        }
                    }
                    Spacer()
                    Text(verbatim: Units.clock(seconds: phase.remaining.rounded(.up)))
                        .brandNumberFont(size: 34, relativeTo: .largeTitle)
                        .foregroundStyle(Color.brand(\.ink))
                    Button {
                        self.startedAt = nil
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.title)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text(LogCopy.stop))
                }
                .onChange(of: phase.index) { _, _ in
                    phaseChanges += 1
                    if phase.isFinished {
                        self.startedAt = nil
                        onDone()
                    }
                }
            }
            .sensoryFeedback(.impact(weight: .heavy), trigger: phaseChanges)
        } else {
            Button {
                startedAt = .now
            } label: {
                Label {
                    Text(LogCopy.start)
                } icon: {
                    Image(systemName: "timer")
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
        }
    }
}

/// Where an interval timer is after some seconds: which round, work or rest, and time left.
struct IntervalPhase: Equatable {
    var round: Int
    var isWork: Bool
    var remaining: Double
    var isFinished: Bool
    /// Counts up through every work and rest phase, so a view can react to each change.
    var index: Int

    static func at(_ elapsed: Double, rounds: Int, work: Double, rest: Double) -> IntervalPhase {
        let rounds = max(rounds, 1)
        let cycle = work + rest
        let total = cycle * Double(rounds) - rest
        guard elapsed < total, cycle > 0 else {
            return IntervalPhase(round: rounds, isWork: false, remaining: 0, isFinished: true, index: rounds * 2)
        }
        let round = min(Int(elapsed / cycle), rounds - 1)
        let into = elapsed - Double(round) * cycle
        let isWork = into < work
        return IntervalPhase(
            round: round + 1, isWork: isWork, remaining: isWork ? work - into : cycle - into, isFinished: false,
            index: round * 2 + (isWork ? 0 : 1))
    }
}
