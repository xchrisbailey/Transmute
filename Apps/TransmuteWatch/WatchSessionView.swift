import SwiftUI
import TransmuteCore
import TransmuteUI
import WatchKit

/// The workout on the wrist: controls to the left, the current set or the rest ring in the
/// middle, and the exercise list to the right.
struct WatchSessionView: View {
    @Bindable var session: WatchSession
    let units: Units
    /// Whether the wrist is tapped when rest ends (#18).
    var restHaptics = true
    /// Leaves the workout screen once the workout is finished or discarded.
    let onClose: () -> Void

    enum Page: Hashable {
        case controls, now, exercises
    }

    @State private var page = Page.now
    @State private var restEnded = 0

    private var snapshot: SessionSnapshot { session.snapshot }

    var body: some View {
        Group {
            if let summary = session.summary {
                WatchSummaryView(session: session, summary: summary, units: units, onDone: onClose)
            } else {
                TabView(selection: $page) {
                    WatchControlsView(session: session) { page = .now }
                        .tag(Page.controls)
                    now
                        .tag(Page.now)
                    WatchExercisesView(snapshot: snapshot)
                        .tag(Page.exercises)
                }
                .tabViewStyle(.page)
            }
        }
        .background(Color.watchScreen)
        .overlay(alignment: .top) { recordToast }
        .task(id: snapshot.restEndsAt) { await waitForRest() }
        .onChange(of: session.isDiscarded) { _, isDiscarded in
            if isDiscarded { onClose() }
        }
        .confirmationDialog(Text(WatchCopy.bigJump), isPresented: suspiciousBinding, titleVisibility: .visible) {
            Button {
                session.confirmSuspicious()
            } label: {
                Text(WatchCopy.itsRight)
            }
            Button(role: .cancel) {
                session.fixSuspicious()
            } label: {
                Text(WatchCopy.fixIt)
            }
        }
    }

    @ViewBuilder private var now: some View {
        if let end = snapshot.restEndsAt, snapshot.restRemaining(at: .now) != nil {
            WatchRestView(session: session, end: end)
        } else if let ref = snapshot.current {
            WatchSetView(session: session, ref: ref, units: units)
                .id(ref)
        } else {
            VStack(spacing: 12) {
                Text(WatchCopy.allLogged)
                    .brandFont(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.brand(\.ink))
                Button {
                    session.perform(.finish(at: .now))
                } label: {
                    Text(WatchCopy.finish)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brand(\.magic))
                .foregroundStyle(Color.watchScreen)
            }
            .padding(.horizontal, 4)
        }
    }

    /// Sleeps until the rest ends, then taps the wrist, unless that's off, and clears the timer. Runs again
    /// whenever the end moves, so skipping or adding time just restarts the wait.
    private func waitForRest() async {
        guard let remaining = snapshot.restRemaining(at: .now) else {
            if snapshot.restEndsAt != nil { session.perform(.startRest(seconds: nil, at: .now)) }
            return
        }
        do {
            try await Task.sleep(for: .seconds(remaining))
        } catch {
            return
        }
        if restHaptics { WKInterfaceDevice.current().play(.notification) }
        restEnded += 1
        session.perform(.startRest(seconds: nil, at: .now))
    }

    /// "New record" in gold at the top, gone after a few seconds or a tap.
    @ViewBuilder private var recordToast: some View {
        if let record = session.record {
            WatchRecordToast(mark: record.mark, units: units)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: record.id) {
                    WKInterfaceDevice.current().play(.success)
                    try? await Task.sleep(for: .seconds(4))
                    withAnimation { session.record = nil }
                }
                .onTapGesture {
                    withAnimation { session.record = nil }
                }
        }
    }

    private var suspiciousBinding: Binding<Bool> {
        Binding {
            session.suspicious != nil
        } set: {
            if !$0 { session.suspicious = nil }
        }
    }
}

/// A new personal record. Gold is only ever for this.
struct WatchRecordToast: View {
    let mark: RecordMark
    let units: Units

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "medal.fill")
                .foregroundStyle(Color.brand(\.gold))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(WatchCopy.newRecord)
                    .brandFont(.label)
                    .foregroundStyle(Color.brand(\.ink))
                Text(verbatim: "\(String(localized: RecordFormat.label(mark, units: units))) · \(value)")
                    .brandNumberFont(size: 13, relativeTo: .footnote)
                    .foregroundStyle(Color.brandText(\.gold))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.watchPlatter, in: .capsule)
        .overlay(Capsule().strokeBorder(Color.brand(\.gold), lineWidth: 1.5))
        .accessibilityElement(children: .combine)
    }

    private var value: String {
        RecordFormat.value(mark, units: units)
    }
}
