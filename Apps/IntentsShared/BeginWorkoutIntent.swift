import AppIntents
import SwiftData
import TransmuteCore
import TransmuteUI

/// "Begin today's workout" (#19), from Siri, Spotlight, the Action button and the Control
/// Center button. Opens the app on Today and starts the session, the way the widget's button
/// does; with nothing to start it opens Today and says why.
///
/// The iPhone's widget extension compiles this too, for its control, but the system always
/// runs it in the app.
struct BeginWorkoutIntent: AppIntent {
    static let title = LocalizedStringResource(
        "plain.shortcut.begin.title", defaultValue: "Begin today's workout",
        comment: "plain. Shortcut that opens the app and starts today's session.")
    static let description = IntentDescription(
        LocalizedStringResource(
            "plain.shortcut.begin.description",
            defaultValue: "Opens Transmute and starts the session planned for today.",
            comment: "plain. Describes the Begin today's workout shortcut in the Shortcuts app."))
    static let supportedModes: IntentModes = .foreground

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let glance = (try? TodayGlance.load(from: TransmuteStore.shared.mainContext)) ?? TodayGlance()
        DeepLinkRouter.shared.open(ShortcutCopy.begin(glance) == .begin ? .beginToday : .today)
        return .result(dialog: IntentDialog(ShortcutCopy.beginning(glance)))
    }
}
