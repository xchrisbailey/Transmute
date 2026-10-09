import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteUI

/// A record just set, for the toast.
struct GoldNotice: Equatable, Identifiable {
    let id = UUID()
    let mark: RecordMark
    let exercise: String
}

/// Records during the session (#13): checked on every check-off, recomputed when a check is
/// taken back, and a plain question when a set is far beyond the previous best.
extension SessionView {
    func toggle(_ set: LoggedSet) {
        if set.isCompleted {
            WorkoutSession.reopen(set, in: workout)
            if let exerciseID = set.exercise?.exerciseID {
                _ = try? RecordBook(context: context, library: library).recompute(exerciseID: exerciseID)
                try? context.save()
            }
        } else {
            WorkoutSession.complete(set, in: workout, preferences: preferences)
            checkRecords(set)
        }
    }

    func checkRecords(_ set: LoggedSet) {
        guard let check = try? RecordBook(context: context, library: library).check(set) else { return }
        try? context.save()
        showGold(check, for: set)
        if check.gold.isEmpty, !check.needsConfirmation.isEmpty {
            suspicious = set
        }
    }

    func confirmSuspicious() {
        guard let set = suspicious else { return }
        suspicious = nil
        guard let check = try? RecordBook(context: context, library: library).confirm(set) else { return }
        try? context.save()
        showGold(check, for: set)
    }

    func fixSuspicious() {
        guard let set = suspicious else { return }
        suspicious = nil
        WorkoutSession.reopen(set, in: workout)
        editing = set.persistentModelID
    }

    private func showGold(_ check: RecordCheck, for set: LoggedSet) {
        if let record = check.gold.first {
            motion.animate(reducedTo: Motion.fade) { gold = GoldNotice(mark: record.mark, exercise: name(of: set)) }
        }
    }

    /// The toast at the top, gone after a few seconds.
    @ViewBuilder var goldToast: some View {
        if let gold {
            GoldToast(gold.mark, exercise: gold.exercise, units: units, trigger: gold.id)
                .padding(.top, 8)
                .motionTransition(.move(edge: .top).combined(with: .opacity))
                .task(id: gold.id) {
                    try? await Task.sleep(for: .seconds(4))
                    motion.animate(reducedTo: Motion.fade) { self.gold = nil }
                }
                .onTapGesture {
                    motion.animate(reducedTo: Motion.fade) { self.gold = nil }
                }
        }
    }

    var suspiciousBinding: Binding<Bool> {
        Binding {
            suspicious != nil
        } set: {
            if !$0 { suspicious = nil }
        }
    }
}
