import Foundation

/// An sRGB color stored as `0xRRGGBB`, so the palette stays free of UI frameworks.
public struct BrandColor: Hashable, Sendable {
    public let hex: UInt32

    public init(_ hex: UInt32) {
        self.hex = hex
    }

    public var red: Double { Double((hex >> 16) & 0xFF) / 255 }
    public var green: Double { Double((hex >> 8) & 0xFF) / 255 }
    public var blue: Double { Double(hex & 0xFF) / 255 }

    /// WCAG relative luminance.
    public var luminance: Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.039_28 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// WCAG contrast ratio against another color, from 1 to 21.
    public func contrast(with other: BrandColor) -> Double {
        let (lighter, darker) =
            luminance > other.luminance ? (luminance, other.luminance) : (other.luminance, luminance)
        return (lighter + 0.05) / (darker + 0.05)
    }
}

/// The roles every screen draws from. See the brand book in #3.
///
/// Rules: one `magic` action per screen; `gold` only for records; `now` means the current
/// set, the rest timer or a streak.
public struct BrandPalette: Hashable, Sendable {
    /// Page background (Catppuccin base).
    public let base: BrandColor
    /// Cards (mantle).
    public let mantle: BrandColor
    public let crust: BrandColor
    public let surface0: BrandColor
    public let surface1: BrandColor
    public let overlay0: BrandColor
    public let overlay1: BrandColor
    /// Secondary text.
    public let subtext: BrandColor
    /// Primary text.
    public let ink: BrandColor
    /// Mauve: the one primary action per screen and the app accent.
    public let magic: BrandColor
    /// Peach: the current set, the rest timer, a streak.
    public let now: BrandColor
    /// Yellow: personal records only.
    public let gold: BrandColor
    /// Green: a finished set.
    public let done: BrandColor
    /// Red: heart rate and errors.
    public let alert: BrandColor
    public let sparklePink: BrandColor
    public let sparkleLavender: BrandColor
    /// Shades of the accent roles for use as text. Latte's accents are too light to read as
    /// small text on its base and cards, so these are darkened to pass WCAG AA (#22).
    public let text: TextTones

    public struct TextTones: Hashable, Sendable {
        public let subtext: BrandColor
        public let magic: BrandColor
        public let now: BrandColor
        public let gold: BrandColor
        public let done: BrandColor
        public let alert: BrandColor
    }

    /// Catppuccin Mocha, the default dark theme.
    public static let mocha = BrandPalette(
        base: BrandColor(0x1E1E2E), mantle: BrandColor(0x181825), crust: BrandColor(0x11111B),
        surface0: BrandColor(0x313244), surface1: BrandColor(0x45475A),
        overlay0: BrandColor(0x6C7086), overlay1: BrandColor(0x7F849C),
        subtext: BrandColor(0xA6ADC8), ink: BrandColor(0xCDD6F4),
        magic: BrandColor(0xCBA6F7), now: BrandColor(0xFAB387), gold: BrandColor(0xF9E2AF),
        done: BrandColor(0xA6E3A1), alert: BrandColor(0xF38BA8),
        sparklePink: BrandColor(0xF5C2E7), sparkleLavender: BrandColor(0xB4BEFE),
        text: TextTones(
            subtext: BrandColor(0xA6ADC8), magic: BrandColor(0xCBA6F7), now: BrandColor(0xFAB387),
            gold: BrandColor(0xF9E2AF), done: BrandColor(0xA6E3A1), alert: BrandColor(0xF38BA8)
        )
    )

    /// Catppuccin Latte, the default light theme.
    public static let latte = BrandPalette(
        base: BrandColor(0xEFF1F5), mantle: BrandColor(0xE6E9EF), crust: BrandColor(0xDCE0E8),
        surface0: BrandColor(0xCCD0DA), surface1: BrandColor(0xBCC0CC),
        overlay0: BrandColor(0x9CA0B0), overlay1: BrandColor(0x8C8FA1),
        subtext: BrandColor(0x6C6F85), ink: BrandColor(0x4C4F69),
        magic: BrandColor(0x8839EF), now: BrandColor(0xFE640B), gold: BrandColor(0xDF8E1D),
        done: BrandColor(0x40A02B), alert: BrandColor(0xD20F39),
        sparklePink: BrandColor(0xEA76CB), sparkleLavender: BrandColor(0x7287FD),
        text: TextTones(
            subtext: BrandColor(0x63667A), magic: BrandColor(0x8534EF), now: BrandColor(0xB44201),
            gold: BrandColor(0x905C13), done: BrandColor(0x2F7620), alert: BrandColor(0xCD0F38)
        )
    )

    /// Apple Watch: true black with Mocha accents. Cards are the watch's platters.
    public static let watch = BrandPalette(
        base: BrandColor(0x000000), mantle: BrandColor(0x1B1B24), crust: BrandColor(0x000000),
        surface0: BrandColor(0x313244), surface1: BrandColor(0x45475A),
        overlay0: BrandColor(0x6C7086), overlay1: BrandColor(0x7F849C),
        subtext: BrandColor(0xA6ADC8), ink: BrandColor(0xCDD6F4),
        magic: BrandColor(0xCBA6F7), now: BrandColor(0xFAB387), gold: BrandColor(0xF9E2AF),
        done: BrandColor(0xA6E3A1), alert: BrandColor(0xF38BA8),
        sparklePink: BrandColor(0xF5C2E7), sparkleLavender: BrandColor(0xB4BEFE),
        text: TextTones(
            subtext: BrandColor(0xA6ADC8), magic: BrandColor(0xCBA6F7), now: BrandColor(0xFAB387),
            gold: BrandColor(0xF9E2AF), done: BrandColor(0xA6E3A1), alert: BrandColor(0xF38BA8)
        )
    )
}
