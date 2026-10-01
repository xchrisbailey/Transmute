import SwiftUI
import TransmuteCore

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

extension Color {
    /// A fixed color from the palette.
    public init(_ brand: BrandColor) {
        self.init(.sRGB, red: brand.red, green: brand.green, blue: brand.blue)
    }

    /// A palette role that follows appearance: Mocha in dark mode, Latte in light mode, and
    /// the true-black watch palette on Apple Watch.
    ///
    ///     .foregroundStyle(Color.brand(\.magic))
    public static func brand(_ role: KeyPath<BrandPalette, BrandColor>) -> Color {
        adaptive(dark: BrandPalette.mocha[keyPath: role], light: BrandPalette.latte[keyPath: role])
    }

    /// The text shade of a palette role, which passes WCAG AA on base and cards.
    public static func brandText(_ role: KeyPath<BrandPalette.TextTones, BrandColor>) -> Color {
        adaptive(dark: BrandPalette.mocha.text[keyPath: role], light: BrandPalette.latte.text[keyPath: role])
    }

    private static func adaptive(dark: BrandColor, light: BrandColor) -> Color {
        #if os(watchOS)
            // The watch is always dark; its own palette only differs in base and platters.
            return Color(dark)
        #elseif canImport(UIKit)
            return Color(
                uiColor: UIColor { traits in
                    UIColor(traits.userInterfaceStyle == .dark ? dark : light)
                })
        #elseif canImport(AppKit)
            return Color(
                nsColor: NSColor(name: nil) { appearance in
                    let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    return NSColor(isDark ? dark : light)
                })
        #endif
    }
}

#if os(watchOS)
    extension Color {
        /// Watch-only roles: the true-black screen and the platters cards sit on.
        public static let watchScreen = Color(BrandPalette.watch.base)
        public static let watchPlatter = Color(BrandPalette.watch.mantle)
    }
#endif

#if canImport(UIKit)
    extension UIColor {
        convenience init(_ brand: BrandColor) {
            self.init(red: brand.red, green: brand.green, blue: brand.blue, alpha: 1)
        }
    }
#elseif canImport(AppKit)
    extension NSColor {
        convenience init(_ brand: BrandColor) {
            self.init(srgbRed: brand.red, green: brand.green, blue: brand.blue, alpha: 1)
        }
    }
#endif
