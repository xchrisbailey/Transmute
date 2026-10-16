import SwiftUI

/// How the app looks on this device: follow the system, or stay in one of the two
/// palettes. Kept in `UserDefaults` rather than the profile, since a Mac on a bright desk and
/// a phone in a dim gym can want different things. The watch is always true black.
///
///     @AppStorage(Appearance.defaultsKey) private var appearance = Appearance.system
public enum Appearance: String, CaseIterable, Identifiable, Sendable {
    /// Mocha in dark mode, Latte in light mode.
    case system
    /// The dark palette, always.
    case mocha
    /// The light palette, always.
    case latte

    public static let defaultsKey = "appearance"

    public var id: Self { self }

    /// The color scheme to force, or `nil` to follow the system.
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .mocha: .dark
        case .latte: .light
        }
    }

    public var name: LocalizedStringResource {
        switch self {
        case .system: SettingsCopy.appearanceSystem
        case .mocha: SettingsCopy.appearanceMocha
        case .latte: SettingsCopy.appearanceLatte
        }
    }

    /// The choice stored on this device; `system` when nothing, or nothing known, is stored.
    public static func stored(in defaults: UserDefaults = .standard) -> Appearance {
        defaults.string(forKey: defaultsKey).flatMap(Appearance.init(rawValue:)) ?? .system
    }
}

extension View {
    /// Applies the appearance chosen on this device. Put it at the root of each window.
    public func appearance(_ appearance: Appearance) -> some View {
        preferredColorScheme(appearance.colorScheme)
    }
}
