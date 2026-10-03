import ActivityKit
import SwiftUI
import TransmuteUI
import WidgetKit

/// The workout on the Lock Screen and in the Dynamic Island: the exercise, which set, and
/// the rest counting down in peach. Words stay plain; the numbers are Geist Mono.
struct SessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SessionActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .padding()
                .activityBackgroundTint(Color.brand(\.base))
                .activitySystemActionForegroundColor(Color.brand(\.ink))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "dumbbell.fill")
                        .foregroundStyle(Color.brand(\.magic))
                        .accessibilityHidden(true)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    RestCountdown(state: context.state, size: 22)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    SetLine(state: context.state)
                }
            } compactLeading: {
                Text(verbatim: "\(context.state.setNumber)/\(context.state.setCount)")
                    .font(.brandNumber(size: 14))
            } compactTrailing: {
                RestCountdown(state: context.state, size: 14)
            } minimal: {
                if let interval = context.state.restInterval {
                    ProgressView(timerInterval: interval, countsDown: true) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                    .progressViewStyle(.circular)
                    .tint(Color.brand(\.now))
                } else {
                    Image(systemName: "dumbbell.fill")
                        .foregroundStyle(Color.brand(\.magic))
                }
            }
        }
    }
}

private struct LockScreenView: View {
    let state: SessionActivityAttributes.ContentState

    var body: some View {
        HStack {
            SetLine(state: state)
            Spacer()
            RestCountdown(state: state, size: 34)
        }
    }
}

private struct SetLine: View {
    let state: SessionActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: state.exercise)
                .font(.headline)
                .foregroundStyle(Color.brand(\.ink))
                .lineLimit(1)
            if state.setCount > 0 {
                Text(WidgetCopy.setOf(state.setNumber, of: state.setCount))
                    .font(.subheadline)
                    .foregroundStyle(Color.brandText(\.subtext))
            }
        }
    }
}

/// The rest left, or nothing between rests.
private struct RestCountdown: View {
    let state: SessionActivityAttributes.ContentState
    let size: CGFloat

    var body: some View {
        if let interval = state.restInterval {
            Text(timerInterval: interval, countsDown: true)
                .font(.brandNumber(size: size))
                .foregroundStyle(Color.brandText(\.now))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: size * 3.2)
                .accessibilityLabel(Text(WidgetCopy.rest))
        }
    }
}

enum WidgetCopy {
    static func setOf(_ number: Int, of total: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.session.setOf", defaultValue: "Set \(number) of \(total)", bundle: .main,
            comment: "plain. Which set this is, e.g. Set 2 of 4.")
    }

    static let rest = LocalizedStringResource(
        "plain.session.intervalRest", defaultValue: "Rest", bundle: .main,
        comment: "plain. Interval phase.")
}
