import SwiftData
import SwiftUI
import TransmuteCore
import UserNotifications

/// Hears a tap on a reminder, so the app can open on Today. The app calls `listen()` as it
/// launches; `trainingReminders(plan:onOpen:)` acts on the tap.
@MainActor @Observable
public final class ReminderTaps: NSObject, UNUserNotificationCenterDelegate {
    public static let shared = ReminderTaps()

    /// A reminder was tapped and the app hasn't shown Today for it yet.
    public var opensToday = false

    public func listen() {
        UNUserNotificationCenter.current().delegate = self
    }

    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.notification.request.identifier.hasPrefix(ReminderPlanner.identifierPrefix) {
            Task { @MainActor in opensToday = true }
        }
        completionHandler()
    }

    /// A reminder still shows with the app in front, as a Mac app often is all day. Anything
    /// else, the rest alert included, stays quiet in the app as it did without a delegate.
    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let isReminder = notification.request.identifier.hasPrefix(ReminderPlanner.identifierPrefix)
        completionHandler(isReminder ? [.banner, .list, .sound] : [])
    }
}

/// Keeps the pending reminders in step with the plan, the log and the settings (#19).
struct TrainingReminders: ViewModifier {
    let plan: Plan?
    let onOpen: () -> Void

    @Query(TrainingReminders.latestWorkout) private var latest: [Workout]
    @AppStorage(ReminderSettings.trainingDayKey) private var remindsOnTrainingDays = false
    @AppStorage(ReminderSettings.trainingDayMinutesKey) private var minutes = ReminderSettings.defaultMinutes
    @AppStorage(ReminderSettings.missedDayKey) private var nudgesAfterMissedDay = false
    @Environment(\.scenePhase) private var scenePhase
    private let taps = ReminderTaps.shared

    static var latestWorkout: FetchDescriptor<Workout> {
        var descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return descriptor
    }

    /// What should be pending right now. Reading the plan here means a moved day, a started
    /// workout or a deleted one changes the result, and the change is what reschedules.
    private var reminders: [PlannedReminder] {
        ReminderPlanner.reminders(
            plan: plan, lastWorkoutAt: latest.first?.startedAt,
            settings: ReminderSettings(
                remindsOnTrainingDays: remindsOnTrainingDays, trainingDayMinutes: minutes,
                nudgesAfterMissedDay: nudgesAfterMissedDay))
    }

    func body(content: Content) -> some View {
        content
            .task(id: reminders) {
                await ReminderScheduler.schedule(reminders)
            }
            .onChange(of: scenePhase) { _, phase in
                // Time has passed, and permission may have changed in the system's settings.
                guard phase == .active else { return }
                let reminders = reminders
                Task { await ReminderScheduler.schedule(reminders) }
            }
            .onChange(of: taps.opensToday, initial: true) { _, opens in
                guard opens else { return }
                taps.opensToday = false
                onOpen()
            }
    }
}

extension View {
    /// Schedules training reminders for the active plan: on launch, when the app comes to the
    /// front, and when the plan, the log or the reminder settings change. `onOpen` runs when a
    /// reminder is tapped, to show Today.
    public func trainingReminders(plan: Plan?, onOpen: @escaping () -> Void) -> some View {
        modifier(TrainingReminders(plan: plan, onOpen: onOpen))
    }
}
