import AppIntents

/// The shortcuts Transmute offers with no setup (#19): in the Shortcuts app, Spotlight and
/// Siri, and for the Action button. Every phrase has to name the app; translations of the
/// phrases go in `AppShortcuts.xcstrings`, which is the table the system reads them from.
struct TransmuteShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: BeginWorkoutIntent(),
            phrases: [
                "Begin today's workout in \(.applicationName)",
                "Start my \(.applicationName) workout",
                "Begin the work in \(.applicationName)",
            ],
            shortTitle: LocalizedStringResource(
                "plain.shortcut.begin.short", defaultValue: "Begin workout",
                comment: "plain. Short name of the Begin today's workout shortcut."),
            systemImageName: "flame")
        AppShortcut(
            intent: LogBodyweightIntent(),
            phrases: [
                "Log my bodyweight in \(.applicationName)",
                "Log my weight in \(.applicationName)",
                "Add a weigh-in to \(.applicationName)",
            ],
            shortTitle: LocalizedStringResource(
                "plain.shortcut.weight.short", defaultValue: "Log bodyweight",
                comment: "plain. Short name of the Log bodyweight shortcut."),
            systemImageName: "scalemass")
        AppShortcut(
            intent: TodayWorkoutIntent(),
            phrases: [
                "What's my workout today in \(.applicationName)",
                "What's my \(.applicationName) workout today",
                "What's today in \(.applicationName)",
            ],
            shortTitle: LocalizedStringResource(
                "plain.shortcut.today.short", defaultValue: "Today's workout",
                comment: "plain. Short name of the What's my workout today? shortcut."),
            systemImageName: "calendar")
    }

    static let shortcutTileColor = ShortcutTileColor.purple
}
