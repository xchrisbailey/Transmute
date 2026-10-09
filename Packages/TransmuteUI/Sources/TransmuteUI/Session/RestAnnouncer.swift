import Accessibility
import Foundation
import TransmuteCore

#if os(watchOS)
    import WatchKit
#elseif os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

/// Counts down a rest and, when VoiceOver is running, says how much is left at the marks in
/// `RestAnnouncements` (#59). The session screens call it from where they already wait for
/// rest to end, so it speaks whichever page is showing, and on whichever device has VoiceOver on.
@MainActor
public enum RestAnnouncer {
    /// Waits until `end`, announcing along the way and "Rest over" at the end. Returns `true`
    /// when the rest ran out, and `false` when the waiting task was cancelled first (rest
    /// skipped, or time added or taken away, which starts a fresh countdown from what is
    /// left). A cancelled countdown says nothing more.
    public static func countdown(until end: Date) async -> Bool {
        for mark in RestAnnouncements.marks(remaining: end.timeIntervalSinceNow) {
            let wait = end.timeIntervalSinceNow - Double(mark)
            if wait > 0 {
                do {
                    try await Task.sleep(for: .seconds(wait))
                } catch {
                    return false
                }
            }
            guard !Task.isCancelled else { return false }
            // A late wake-up skips the marks it missed rather than speaking them back to back.
            let secondsLate = Double(mark) - end.timeIntervalSinceNow
            if RestAnnouncements.isWorthSaying(mark: mark, secondsLate: secondsLate) {
                announce(mark)
            }
        }
        return true
    }

    private static func announce(_ mark: Int) {
        guard isVoiceOverRunning else { return }
        let words =
            mark == 0
            ? String(localized: Copy.restOverSpoken)
            : String(localized: Copy.restLeft(spoken(seconds: mark)))
        // UIAccessibilityPriorityLow: "Announcements are queued and spoken when other speech
        // utterances have completed."
        var text = AttributedString(words)
        text.accessibilitySpeechAnnouncementPriority = .low
        AccessibilityNotification.Announcement(text).post()
    }

    /// Seconds in words, e.g. 90 → "1 minute, 30 seconds".
    static func spoken(seconds: Int) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.minutes, .seconds], width: .wide))
    }

    private static var isVoiceOverRunning: Bool {
        #if os(watchOS)
            WKAccessibilityIsVoiceOverRunning()
        #elseif os(iOS)
            UIAccessibility.isVoiceOverRunning
        #else
            NSWorkspace.shared.isVoiceOverEnabled
        #endif
    }
}
