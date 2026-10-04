# Brand

Masters for the Transmute mark and wordmark. The source of truth is the brand book linked from issue #3.

| File | What |
|---|---|
| `mark-mocha.svg`, `mark-latte.svg` | Mark A, the kettlebell crucible, on dark (Mocha) and light (Latte). 64×64. |
| `wordmark-mocha.svg`, `wordmark-latte.svg` | `transmute` in Geist ExtraBold, outlined, tracking −0.045em, with the mauve-filled u, the sparkles and the peach `_`. |
| `icon-mocha.png`, `icon-latte.png` | 1024px previews of the app icon. |
| `icon-layers/` | The mark split into four 1024px layers (SVG and transparent PNG) for Icon Composer, plus `preview.png` of them stacked on the background. |

`scripts/render-brand.swift` regenerates the wordmarks, the previews and the app icon PNGs in `Apps/Shared/Assets.xcassets/AppIcon.appiconset` from these masters:

```bash
swift scripts/render-brand.swift
```

The PNG icons stand in until the Icon Composer `.icon` (default, dark and tinted variants) is exported from `mark-mocha.svg`.

Geist and Geist Mono live in `Resources/Fonts` under the SIL Open Font License (`Resources/Fonts/OFL.txt`).

## Making the Icon Composer icon

The PNGs in `AppIcon.appiconset` are placeholders. The real icon is one `AppIcon.icon` file made in Icon Composer. It covers iPhone, Mac and Apple Watch, with default, dark and tinted (mono) appearances. Icon Composer ships with Xcode 26 and later: Xcode ▸ Open Developer Tool ▸ Icon Composer.

1. **New document.** Save it as `Apps/Shared/AppIcon.icon`. The name has to be `AppIcon` because that is `ASSETCATALOG_COMPILER_APPICON_NAME` in `project.yml`, and `Apps/Shared` is already a source of all three app targets.
2. **Background.** Select the document (the top row in the sidebar), then in the inspector set Fill to a linear gradient from `#443c5a` at the top to `#1e1e2e` at the bottom. This is the Mocha base with the faint mauve glow.
3. **Layers.** Drag `icon-layers/1-handle.svg` to `4-sparkles.svg` into the canvas, in that order, so the handle is at the back and the sparkles at the front. Put handle, body and liquid in one group ("Kettlebell") and the sparkles in a second group ("Sparkles"). If an SVG renders wrong, use the PNG with the same name.
   The layers are already sized and centered on the 1024 canvas (the mark takes 62% of it, like the placeholder PNGs), so leave scale at 100% and position at 0, 0.
4. **Glass.** Keep Liquid Glass on for both groups. Turn specular down on the Sparkles group if the small shapes look smeared. Lower the body layer's opacity a little if the glass makes the liquid look washed out.
5. **Appearances.** At the bottom of the canvas, switch to:
   - **Default**: keep it as above. Mocha is the brand's default.
   - **Dark**: set the background fill to solid `#1e1e2e` (no glow), matching `icon-ios-dark.png`.
   - **Mono** (tinted): let Icon Composer derive it, then check that the handle and liquid still read as separate shapes. If they don't, set the liquid layer to white and the body to a mid gray for Mono only.
6. **Check every platform.** Use the platform switcher to preview iOS, macOS and watchOS. On the watch the icon is cropped to a circle; the sparkles sit inside it. Look at the small sizes too, 16 and 32 for the Mac sidebar and Spotlight.
7. **Wire it up.** Delete `Apps/Shared/Assets.xcassets/AppIcon.appiconset` so only one `AppIcon` exists. Then run `xcodegen generate` and build each app. In Xcode, check that `AppIcon.icon` appears under each app target's Copy Bundle Resources. If XcodeGen adds it as a plain folder instead, list it as `- path: Apps/Shared/AppIcon.icon` with `type: file` in each app target's `sources`.
8. Once the `.icon` is in, `scripts/render-brand.swift` only needs to make the wordmarks and the previews in this folder. Its app icon PNG output can go.
