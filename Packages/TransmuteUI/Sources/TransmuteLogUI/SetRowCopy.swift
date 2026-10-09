import Foundation

/// What the set row says to Voice Control and VoiceOver, and shows when it stacks (#60).
extension LogCopy {
    /// Shown on the stacked row and said to Voice Control: "Set 3".
    static func setNumber(_ number: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.session.setNumber", defaultValue: "Set \(number)", bundle: .main,
            comment: "plain. Names a set row; also what someone says to Voice Control, e.g. Set 3.")
    }

    /// Shown on the stacked row and said to Voice Control: "Warm-up 1".
    static func warmUpNumber(_ number: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.session.warmUpNumber", defaultValue: "Warm-up \(number)", bundle: .main,
            comment: "plain. Names a warm-up set row; also what someone says to Voice Control, e.g. Warm-up 1.")
    }

    static let personalRecord = LocalizedStringResource(
        "plain.session.personalRecord", defaultValue: "Personal record", bundle: .main,
        comment: "plain. VoiceOver, added to a set that set a record.")

    static let logSetVoiceControl = LocalizedStringResource(
        "plain.session.logSetVoiceControl", defaultValue: "Log", bundle: .main,
        comment: "plain. Voice Control name for the log set button; short, to be said aloud.")

    static let finishVoiceControl = LocalizedStringResource(
        "plain.session.finishVoiceControl", defaultValue: "Finish workout", bundle: .main,
        comment: "plain. Voice Control name for the finish button under the sets, apart from the one in the toolbar.")
}
