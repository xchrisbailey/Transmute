import Foundation

/// Strings for the About section of Settings (#58). All plain; the `voice.about` line is
/// `Copy.about(version:)`, and the licence text itself is shown as the file has it.
enum SettingsAboutCopy {
    static let build = LocalizedStringResource(
        "plain.settings.about.build",
        defaultValue: "Build",
        bundle: .main, comment: "plain. Label before the app's build number.")

    static let catalog = LocalizedStringResource(
        "plain.settings.about.catalog",
        defaultValue: "Every exercise in the catalog was written for Transmute.",
        bundle: .main, comment: "plain. Where the exercise catalog comes from.")

    static let licence = LocalizedStringResource(
        "plain.settings.about.licence",
        defaultValue: "Geist and Geist Mono licence",
        bundle: .main, comment: "plain. Row and screen title for the SIL Open Font License the fonts ship under.")

    static let done = LocalizedStringResource(
        "plain.done",
        defaultValue: "Done",
        bundle: .main, comment: "plain. Button.")

    static let licenceMissing = LocalizedStringResource(
        "plain.settings.about.licenceMissing",
        defaultValue: "The licence file is missing from this build.",
        bundle: .main, comment: "plain. Shown instead of the font licence when its file can't be read.")
}
