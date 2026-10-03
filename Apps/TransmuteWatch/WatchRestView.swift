import SwiftUI
import TransmuteCore
import TransmuteUI

/// Rest: a mauve ring draining around the time left, with the next set underneath.
struct WatchRestView: View {
    let session: WatchSession
    let end: Date

    private var snapshot: SessionSnapshot { session.snapshot }

    var body: some View {
        VStack(spacing: 4) {
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                let remaining = max(0, end.timeIntervalSince(context.date))
                let total = max(snapshot.restSeconds ?? remaining, 1)
                ZStack {
                    Circle()
                        .stroke(Color.brand(\.surface0), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: remaining / total)
                        .stroke(Color.brand(\.magic), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text(verbatim: Units.clock(seconds: remaining.rounded(.up)))
                            .brandNumberFont(size: 34, relativeTo: .largeTitle)
                            .foregroundStyle(Color.brand(\.ink))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .contentTransition(.numericText(countsDown: true))
                        Text(WatchCopy.rest)
                            .font(.caption2)
                            .foregroundStyle(Color.brandText(\.subtext))
                    }
                    .padding(.horizontal, 14)
                }
                .padding(4)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(WatchCopy.rest))
                .accessibilityValue(Text(verbatim: Units.clock(seconds: remaining.rounded(.up))))
            }
            HStack(spacing: 4) {
                cornerButton(WatchCopy.addRest) {
                    session.perform(.adjustRest(by: 15, at: .now))
                } label: {
                    Text(verbatim: "+15")
                        .brandNumberFont(size: 13, relativeTo: .footnote)
                }
                Group {
                    if let next {
                        Text(WatchCopy.nextSet(next))
                    } else {
                        Color.clear
                    }
                }
                .font(.footnote)
                .foregroundStyle(Color.brandText(\.subtext))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                cornerButton(WatchCopy.skipRest) {
                    session.perform(.startRest(seconds: nil, at: .now))
                } label: {
                    Image(systemName: "forward.end.fill")
                }
            }
        }
        .padding(.horizontal, 4)
    }

    /// A small round button for the corners under the ring.
    private func cornerButton(
        _ name: LocalizedStringResource, action: @escaping () -> Void, @ViewBuilder label: () -> some View
    ) -> some View {
        Button(action: action) {
            label()
                .foregroundStyle(Color.brand(\.ink))
                .frame(width: 40, height: 40)
                .background(Color.brand(\.surface0), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(name))
    }

    private var next: String? {
        snapshot.current.flatMap { snapshot.exercise(at: $0)?.name }
    }
}
