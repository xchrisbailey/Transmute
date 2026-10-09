import Foundation

/// When a rest timer speaks to someone using VoiceOver (#59): how much is left at the start,
/// at each whole minute, at 30 and at 10 seconds, and when it runs out.
public enum RestAnnouncements {
    /// The remaining-seconds marks to announce, latest first, for a rest with `remaining`
    /// seconds left. The first is the time left now and the last is always 0, the end.
    ///
    /// Marks within five seconds of each other collapse into the earlier one, so a 35-second
    /// rest says 35 and 10 rather than 35 and 30. The end is never dropped. Call it again with
    /// what is left whenever time is added or taken away.
    public static func marks(remaining: TimeInterval) -> [Int] {
        let now = max(0, Int(remaining.rounded(.up)))
        let minutes = stride(from: (now - 1) / 60 * 60, through: 60, by: -60)
        var kept: [Int] = []
        for mark in [now] + minutes + [30, 10].filter({ $0 < now }) {
            if let last = kept.last, last - mark <= collapseWindow { continue }
            kept.append(mark)
        }
        // The start is dropped when it sits right beside the end.
        if let last = kept.last, last <= collapseWindow { kept.removeLast() }
        return kept + [0]
    }

    private static let collapseWindow = 5
}
