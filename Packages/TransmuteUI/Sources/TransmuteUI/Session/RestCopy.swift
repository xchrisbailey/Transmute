import Foundation

/// What the rest timer says to VoiceOver and to Voice Control (#59). All plain.
extension Copy {
    /// Spoken as rest ticks down, e.g. "1 minute of rest left".
    public static func restLeft(_ time: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.session.restLeftSpoken", defaultValue: "\(time) of rest left", bundle: .main,
            comment: "plain. Spoken by VoiceOver during rest; the argument is the time left in words, e.g. 1 minute.")
    }

    /// Spoken when a rest runs out.
    public static let restOverSpoken = LocalizedStringResource(
        "plain.session.restOverSpoken", defaultValue: "Rest over", bundle: .main,
        comment: "plain. Spoken by VoiceOver when the rest timer runs out.")

    /// What someone can say to tap the +15 s button, beside its full label.
    public static let addRestSpoken = LocalizedStringResource(
        "plain.session.addRestVoiceControl", defaultValue: "Add time", bundle: .main,
        comment: "plain. Voice Control name for the +15 s rest button; short, to be said aloud.")

    /// What someone can say to tap the -15 s button, beside its full label.
    public static let lessRestSpoken = LocalizedStringResource(
        "plain.session.lessRestVoiceControl", defaultValue: "Less time", bundle: .main,
        comment: "plain. Voice Control name for the -15 s rest button; short, to be said aloud.")

    /// What someone can say to tap the skip button, beside its full label.
    public static let skipRestSpoken = LocalizedStringResource(
        "plain.session.skipRestVoiceControl", defaultValue: "Skip", bundle: .main,
        comment: "plain. Voice Control name for the skip rest button; short, to be said aloud.")
}
