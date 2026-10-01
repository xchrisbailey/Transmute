import Testing

@testable import TransmuteCore

struct BrandPaletteTests {
    static let palettes: [(String, BrandPalette)] = [("mocha", .mocha), ("latte", .latte), ("watch", .watch)]

    @Test func colorChannels() {
        let mauve = BrandColor(0xCBA6F7)
        #expect(mauve.red == Double(0xCB) / 255)
        #expect(mauve.green == Double(0xA6) / 255)
        #expect(mauve.blue == Double(0xF7) / 255)
    }

    @Test func contrastMatchesWCAGReference() {
        #expect(BrandColor(0x000000).contrast(with: BrandColor(0xFFFFFF)).rounded() == 21)
        #expect(BrandColor(0x777777).contrast(with: BrandColor(0x777777)) == 1)
    }

    @Test func accentIsMauve() {
        #expect(BrandPalette.mocha.magic == BrandColor(0xCBA6F7))
        #expect(BrandPalette.latte.magic == BrandColor(0x8839EF))
    }

    @Test func watchIsTrueBlackWithMochaAccents() {
        #expect(BrandPalette.watch.base == BrandColor(0x000000))
        #expect(BrandPalette.watch.mantle == BrandColor(0x1B1B24))
        #expect(BrandPalette.watch.magic == BrandPalette.mocha.magic)
        #expect(BrandPalette.watch.now == BrandPalette.mocha.now)
        #expect(BrandPalette.watch.alert == BrandPalette.mocha.alert)
    }

    @Test(arguments: palettes)
    func textPassesWCAGAA(_ name: String, _ palette: BrandPalette) {
        let tones = [
            ("ink", palette.ink), ("subtext", palette.text.subtext), ("magic", palette.text.magic),
            ("now", palette.text.now), ("gold", palette.text.gold), ("done", palette.text.done),
            ("alert", palette.text.alert),
        ]
        for background in [palette.base, palette.mantle] {
            for (role, tone) in tones {
                #expect(tone.contrast(with: background) >= 4.5, "\(name) \(role) on \(background.hex)")
            }
        }
    }
}
