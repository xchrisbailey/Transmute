import SwiftUI

/// The type scale from the brand book (#3). Geist for words, Geist Mono for numbers.
public enum BrandTextStyle: CaseIterable, Sendable {
    /// Geist 28 / 800.
    case largeTitle
    /// Geist 20 / 700.
    case exerciseTitle
    /// Geist 15 / 400, line height 1.6.
    case body
    /// Geist 13.5 / 500.
    case label

    var size: CGFloat {
        switch self {
        case .largeTitle: 28
        case .exerciseTitle: 20
        case .body: 15
        case .label: 13.5
        }
    }

    var weight: GeistWeight {
        switch self {
        case .largeTitle: .extraBold
        case .exerciseTitle: .bold
        case .body: .regular
        case .label: .medium
        }
    }

    /// The system style each one scales with under Dynamic Type.
    var relativeTo: Font.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .exerciseTitle: .title3
        case .body: .body
        case .label: .subheadline
        }
    }

    /// Extra space between lines, so body copy reads at 1.6.
    var lineSpacing: CGFloat {
        self == .body ? size * 0.6 : 0
    }
}

/// The bundled faces. Their PostScript names match the files in Resources/Fonts.
enum GeistWeight: Int, Comparable, Sendable {
    case regular = 400, medium = 500, semiBold = 600, bold = 700, extraBold = 800

    static func < (lhs: GeistWeight, rhs: GeistWeight) -> Bool { lhs.rawValue < rhs.rawValue }

    /// One step heavier, for the Bold Text accessibility setting.
    var bolder: GeistWeight {
        switch self {
        case .regular: .semiBold
        case .medium: .bold
        case .semiBold, .bold, .extraBold: .extraBold
        }
    }

    var geist: String {
        switch self {
        case .regular: "Geist-Regular"
        case .medium: "Geist-Medium"
        case .semiBold: "Geist-SemiBold"
        case .bold: "Geist-Bold"
        case .extraBold: "Geist-ExtraBold"
        }
    }

    /// Geist Mono ships up to Bold here; heavier requests use Bold.
    var geistMono: String {
        switch self {
        case .regular: "GeistMono-Regular"
        case .medium: "GeistMono-Medium"
        case .semiBold: "GeistMono-SemiBold"
        case .bold, .extraBold: "GeistMono-Bold"
        }
    }

    var system: Font.Weight {
        switch self {
        case .regular: .regular
        case .medium: .medium
        case .semiBold: .semibold
        case .bold: .bold
        case .extraBold: .heavy
        }
    }
}

extension Font {
    /// A brand text style that scales with Dynamic Type.
    ///
    /// On Apple Watch, words use the system font (SF Compact); only numbers use Geist Mono.
    /// Prefer the `brandFont(_:)` modifier in views, which also honours Bold Text.
    public static func brand(_ style: BrandTextStyle, bold: Bool = false) -> Font {
        let weight = bold ? style.weight.bolder : style.weight
        #if os(watchOS)
            return .system(style.relativeTo, weight: weight.system)
        #else
            return .custom(weight.geist, size: style.size, relativeTo: style.relativeTo)
        #endif
    }

    /// Geist Mono SemiBold for weights, reps, timers and volume. The face is monospaced, so
    /// figures are tabular and columns of numbers line up.
    public static func brandNumber(size: CGFloat, relativeTo style: Font.TextStyle = .body, bold: Bool = false) -> Font
    {
        let weight: GeistWeight = bold ? .bold : .semiBold
        return .custom(weight.geistMono, size: size, relativeTo: style)
    }

    /// The one big number on a watch screen, about 46pt.
    public static var brandBigNumber: Font {
        brandNumber(size: 46, relativeTo: .largeTitle)
    }
}

extension View {
    /// Applies a brand text style, its line spacing and the Bold Text setting.
    public func brandFont(_ style: BrandTextStyle) -> some View {
        modifier(BrandFontModifier(style: style))
    }

    /// Applies the brand number font and honours Bold Text.
    public func brandNumberFont(size: CGFloat, relativeTo style: Font.TextStyle = .body) -> some View {
        modifier(BrandNumberFontModifier(size: size, relativeTo: style))
    }
}

private struct BrandFontModifier: ViewModifier {
    let style: BrandTextStyle
    @Environment(\.legibilityWeight) private var legibilityWeight

    func body(content: Content) -> some View {
        content
            .font(.brand(style, bold: legibilityWeight == .bold))
            .lineSpacing(style.lineSpacing)
    }
}

private struct BrandNumberFontModifier: ViewModifier {
    let size: CGFloat
    let relativeTo: Font.TextStyle
    @Environment(\.legibilityWeight) private var legibilityWeight

    func body(content: Content) -> some View {
        content.font(.brandNumber(size: size, relativeTo: relativeTo, bold: legibilityWeight == .bold))
    }
}
