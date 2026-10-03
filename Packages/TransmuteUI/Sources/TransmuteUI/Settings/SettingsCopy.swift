import Foundation

/// Settings strings (#18). All plain.
public enum SettingsCopy {
    public static let appearanceSystem = LocalizedStringResource(
        "plain.settings.appearance.system", defaultValue: "Match the device", bundle: .main,
        comment: "plain. Appearance choice: follow the system's light or dark mode.")

    public static let appearanceMocha = LocalizedStringResource(
        "plain.settings.appearance.mocha", defaultValue: "Mocha (dark)", bundle: .main,
        comment: "plain. Appearance choice: always the dark palette, which is called Mocha.")

    public static let appearanceLatte = LocalizedStringResource(
        "plain.settings.appearance.latte", defaultValue: "Latte (light)", bundle: .main,
        comment: "plain. Appearance choice: always the light palette, which is called Latte.")
}
