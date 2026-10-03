import Foundation
import UserNotifications

#if os(iOS)
    import AudioToolbox
#endif

/// Tells you rest is up: a chime in the app, and a notification with sound when Transmute is
/// in the background. The haptic comes from the session screen. The sound and the haptic can
/// each be turned off (#18); the notification itself still arrives, silently.
enum RestAlerts {
    static let identifier = "transmute.rest"

    /// Asks once, the first time a session starts.
    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    /// Replaces any pending rest alert with one at `date`, or clears it for `nil`.
    static func schedule(at date: Date?, next exercise: String, sound: Bool = true) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard let date, date > .now else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: LogCopy.restOver)
        content.body = String(localized: LogCopy.restOverNext(exercise))
        content.sound = sound ? .default : nil
        content.interruptionLevel = .timeSensitive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: date.timeIntervalSinceNow, repeats: false)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// A short system sound, for when rest ends with the app open.
    static func chime() {
        #if os(iOS)
            AudioServicesPlaySystemSound(1_005)
        #endif
    }
}
