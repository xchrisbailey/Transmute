#!/usr/bin/env swift
// Renders the brand assets from the SVG masters in Brand/:
//   - Brand/wordmark-{mocha,latte}.svg, outlined from Geist ExtraBold
//   - the app icon PNGs in Apps/Shared/Assets.xcassets/AppIcon.appiconset
//   - Brand/icon-{mocha,latte}.png previews
//
// These stand in until the Icon Composer `.icon` is exported (#3).
// Usage: swift scripts/render-brand.swift   (from the repo root)

import AppKit
import CoreText

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let brand = root.appending(path: "Brand")
let iconSet = root.appending(path: "Apps/Shared/Assets.xcassets/AppIcon.appiconset")

struct Theme {
    let name: String
    let base, ink, mauve, peach, pink, lavender: NSColor
}

func hex(_ value: UInt32) -> NSColor {
    NSColor(
        srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
        green: CGFloat((value >> 8) & 0xFF) / 255,
        blue: CGFloat(value & 0xFF) / 255,
        alpha: 1
    )
}

let mocha = Theme(
    name: "mocha", base: hex(0x1E1E2E), ink: hex(0xCDD6F4), mauve: hex(0xCBA6F7),
    peach: hex(0xFAB387), pink: hex(0xF5C2E7), lavender: hex(0xB4BEFE))
let latte = Theme(
    name: "latte", base: hex(0xEFF1F5), ink: hex(0x4C4F69), mauve: hex(0x8839EF),
    peach: hex(0xFE640B), pink: hex(0xEA76CB), lavender: hex(0x7287FD))

// MARK: - Bitmaps

func bitmap(_ size: Int, draw: (CGContext) -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    draw(context.cgContext)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func write(_ rep: NSBitmapImageRep, to url: URL) {
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

func mark(_ theme: Theme) -> NSImage {
    NSImage(contentsOf: brand.appending(path: "mark-\(theme.name).svg"))!
}

/// Base fill with a faint mauve glow from the top, and the mark centred.
func drawIcon(_ ctx: CGContext, size: CGFloat, theme: Theme, markScale: CGFloat, glow: Bool = true) {
    ctx.setFillColor(theme.base.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
    if glow {
        let colors = [theme.mauve.withAlphaComponent(0.28).cgColor, theme.mauve.withAlphaComponent(0).cgColor]
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(
            gradient, startCenter: CGPoint(x: size / 2, y: size * 1.05), startRadius: 0,
            endCenter: CGPoint(x: size / 2, y: size * 1.05), endRadius: size * 0.85, options: [])
    }
    let side = size * markScale
    let rect = CGRect(x: (size - side) / 2, y: (size - side) / 2 - size * 0.01, width: side, height: side)
    mark(theme).draw(in: rect)
}

// MARK: - App icons

let iOSIcon = bitmap(1024) { drawIcon($0, size: 1024, theme: mocha, markScale: 0.62) }
write(iOSIcon, to: iconSet.appending(path: "icon-ios.png"))

let iOSDark = bitmap(1024) { drawIcon($0, size: 1024, theme: mocha, markScale: 0.62, glow: false) }
write(iOSDark, to: iconSet.appending(path: "icon-ios-dark.png"))

// Tinted icons are grayscale; the system applies the tint.
let tinted = bitmap(1024) { ctx in
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    let side: CGFloat = 1024 * 0.62
    mark(mocha).draw(in: CGRect(x: (1024 - side) / 2, y: (1024 - side) / 2, width: side, height: side))
    ctx.setBlendMode(.saturation)
    ctx.setFillColor(NSColor.gray.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
}
write(tinted, to: iconSet.appending(path: "icon-ios-tinted.png"))

// The watch masks to a circle, so the mark sits a little smaller on true black.
let watch = bitmap(1024) { ctx in
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    let side: CGFloat = 1024 * 0.54
    mark(mocha).draw(in: CGRect(x: (1024 - side) / 2, y: (1024 - side) / 2, width: side, height: side))
}
write(watch, to: iconSet.appending(path: "icon-watch.png"))

// macOS icons carry their own rounded square on the 824pt grid.
func macIcon(_ theme: Theme) -> NSBitmapImageRep {
    bitmap(1024) { ctx in
        let inset: CGFloat = 100
        let rect = CGRect(x: inset, y: inset, width: 1024 - inset * 2, height: 1024 - inset * 2)
        let path = CGPath(roundedRect: rect, cornerWidth: 185, cornerHeight: 185, transform: nil)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: NSColor.black.withAlphaComponent(0.3).cgColor)
        ctx.addPath(path)
        ctx.setFillColor(theme.base.cgColor)
        ctx.fillPath()
        ctx.restoreGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.translateBy(x: inset, y: inset)
        drawIcon(ctx, size: 1024 - inset * 2, theme: theme, markScale: 0.62)
    }
}

let mac = macIcon(mocha)
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.addRepresentation(mac)
    let scaled = bitmap(size) { ctx in
        ctx.interpolationQuality = .high
        image.draw(in: CGRect(x: 0, y: 0, width: size, height: size))
    }
    write(scaled, to: iconSet.appending(path: "icon-mac-\(size).png"))
}

write(macIcon(mocha), to: brand.appending(path: "icon-mocha.png"))
write(macIcon(latte), to: brand.appending(path: "icon-latte.png"))

// MARK: - Wordmark

func svgPath(_ path: CGPath) -> String {
    var d = ""
    func f(_ v: CGFloat) -> String { String(format: "%.2f", v) }
    path.applyWithBlock { element in
        let p = element.pointee.points
        switch element.pointee.type {
        case .moveToPoint: d += "M\(f(p[0].x)) \(f(p[0].y))"
        case .addLineToPoint: d += "L\(f(p[0].x)) \(f(p[0].y))"
        case .addQuadCurveToPoint: d += "Q\(f(p[0].x)) \(f(p[0].y)) \(f(p[1].x)) \(f(p[1].y))"
        case .addCurveToPoint: d += "C\(f(p[0].x)) \(f(p[0].y)) \(f(p[1].x)) \(f(p[1].y)) \(f(p[2].x)) \(f(p[2].y))"
        case .closeSubpath: d += "Z"
        @unknown default: break
        }
    }
    return d
}

func registerFont(_ name: String) {
    let url = root.appending(path: "Resources/Fonts/\(name).otf")
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
}
registerFont("Geist-ExtraBold")
registerFont("GeistMono-Bold")

let fontSize: CGFloat = 100
let font = CTFontCreateWithName("Geist-ExtraBold" as CFString, fontSize, nil)
let mono = CTFontCreateWithName("GeistMono-Bold" as CFString, fontSize, nil)
let tracking = -0.045 * fontSize
let ascent = CTFontGetAscent(font)

struct Glyph { let char: Character; let path: CGPath; let box: CGRect }
var glyphs: [Glyph] = []
var penX: CGFloat = 0
for char in "transmute" {
    var unichar = Array(String(char).utf16)
    var glyph = CGGlyph()
    CTFontGetGlyphsForCharacters(font, &unichar, &glyph, 1)
    var advance = CGSize()
    CTFontGetAdvancesForGlyphs(font, .horizontal, &glyph, &advance, 1)
    // Flip into SVG space: y grows down, baseline at `ascent`.
    var transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: penX, ty: ascent)
    let path = CTFontCreatePathForGlyph(font, glyph, &transform)!
    glyphs.append(Glyph(char: char, path: path, box: path.boundingBoxOfPath))
    penX += advance.width + tracking
}

var underscoreGlyph = CGGlyph()
var underscoreChar = Array("_".utf16)
CTFontGetGlyphsForCharacters(mono, &underscoreChar, &underscoreGlyph, 1)
var underscoreTransform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: penX + fontSize * 0.04, ty: ascent)
let underscore = CTFontCreatePathForGlyph(mono, underscoreGlyph, &underscoreTransform)!
let width = Int((underscore.boundingBoxOfPath.maxX + fontSize * 0.06).rounded(.up))
let height = Int((ascent + CTFontGetDescent(font)).rounded(.up))

let u = glyphs.first { $0.char == "u" }!
let lastE = glyphs.last!
let fillTop = u.box.maxY - u.box.height / 3

for theme in [mocha, latte] {
    func css(_ color: NSColor) -> String {
        let c = color.usingColorSpace(.sRGB)!
        return String(format: "#%02x%02x%02x", Int(c.redComponent * 255), Int(c.greenComponent * 255), Int(c.blueComponent * 255))
    }
    let letters = glyphs.map { svgPath($0.path) }.joined()
    let ringX = lastE.box.midX + fontSize * 0.12
    let ringY = lastE.box.minY - fontSize * 0.16
    let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 \(-Int(fontSize * 0.3)) \(width) \(height + Int(fontSize * 0.3))">
          <title>transmute wordmark (\(theme.name.capitalized))</title>
          <defs>
            <clipPath id="u-fill"><rect x="\(Int(u.box.minX) - 1)" y="\(String(format: "%.2f", fillTop))" width="\(Int(u.box.width) + 2)" height="\(Int(u.box.height))"/></clipPath>
          </defs>
          <path d="\(letters)" fill="\(css(theme.ink))"/>
          <path d="\(svgPath(u.path))" fill="\(css(theme.mauve))" clip-path="url(#u-fill)"/>
          <circle cx="\(String(format: "%.2f", ringX))" cy="\(String(format: "%.2f", ringY))" r="\(String(format: "%.2f", fontSize * 0.07))" fill="none" stroke="\(css(theme.pink))" stroke-width="\(String(format: "%.2f", fontSize * 0.035))"/>
          <circle cx="\(String(format: "%.2f", ringX + fontSize * 0.13))" cy="\(String(format: "%.2f", ringY - fontSize * 0.14))" r="\(String(format: "%.2f", fontSize * 0.04))" fill="\(css(theme.lavender))"/>
          <path d="\(svgPath(underscore))" fill="\(css(theme.peach))"/>
        </svg>

        """
    try! svg.write(to: brand.appending(path: "wordmark-\(theme.name).svg"), atomically: true, encoding: .utf8)
}

print("Rendered icons and wordmarks.")
