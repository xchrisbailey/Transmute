import Foundation
import TransmuteCore
import UserNotifications

/// Whether the system lets Transmute show notifications.
public enum ReminderPermission: Sendable {
    case notAsked
    case allowed
    case denied
}

/// Hands the planner's reminders to the system (#19). It only ever touches requests whose
/// identifier starts with `ReminderPlanner.identifierPrefix`, so the rest alert is left alone.
public enum ReminderScheduler {
    public static func permission() async -> ReminderPermission {
        switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
        case .notDetermined: .notAsked
        case .denied: .denied
        default: .allowed
        }
    }

    /// Asks when the person turns a reminder on. The system only shows its question once; after
    /// that this just reports the answer.
    @discardableResult
    public static func requestPermission() async -> ReminderPermission {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        return await permission()
    }

    /// Replaces the pending reminders with these. Without permission it only clears them.
    public static func schedule(_ reminders: [PlannedReminder], now: Date = .now) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier)
        let ours = pending.filter { $0.hasPrefix(ReminderPlanner.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)
        guard !reminders.isEmpty, await permission() == .allowed else { return }
        // The system drops requests past its limit, so keep under it with room for the rest alert.
        let room = ReminderPlanner.pendingLimit - (pending.count - ours.count) - 1
        for reminder in reminders.prefix(max(room, 0)) {
            let seconds = reminder.fireDate.timeIntervalSince(now)
            guard seconds > 0 else { continue }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
            try? await center.add(
                UNNotificationRequest(identifier: reminder.id, content: content(for: reminder), trigger: trigger))
        }
    }

    /// What a reminder says. The nudge never names what was missed (#22).
    static func content(for reminder: PlannedReminder) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        switch reminder.kind {
        case .trainingDay:
            content.title =
                reminder.sessionName.isEmpty
                ? String(localized: ReminderCopy.trainingDayUntitled)
                : String(localized: ReminderCopy.trainingDayTitle(reminder.sessionName))
            content.body = String(localized: ReminderCopy.trainingDayBody)
        case .missedDay:
            content.title = String(localized: ReminderCopy.missedDayTitle)
            content.body = String(localized: ReminderCopy.missedDayBody)
        }
        content.sound = .default
        content.threadIdentifier = ReminderPlanner.identifierPrefix
        return content
    }
}
