# Brand

Masters for the Transmute mark and wordmark. The source of truth is the brand book linked from issue #3.

| File | What |
|---|---|
| `mark-mocha.svg`, `mark-latte.svg` | Mark A, the kettlebell crucible, on dark (Mocha) and light (Latte). 64×64. |
| `wordmark-mocha.svg`, `wordmark-latte.svg` | `transmute` in Geist ExtraBold, outlined, tracking −0.045em, with the mauve-filled u, the sparkles and the peach `_`. |
| `icon-mocha.png`, `icon-latte.png` | 1024px previews of the app icon. |
| `icon-layers/` | The mark split into four 1024px layers (SVG and transparent PNG), the masters for the layers in `Apps/Shared/AppIcon.icon`, plus `preview.png` of them stacked on the background. |

`scripts/render-brand.swift` regenerates the wordmarks and the previews from these masters:

```bash
swift scripts/render-brand.swift
```

Geist and Geist Mono live in `Resources/Fonts` under the SIL Open Font License (`Resources/Fonts/OFL.txt`).

## The app icon

The app icon is `Apps/Shared/AppIcon.icon`, an Icon Composer document: `icon.json` plus the four layer SVGs in `Assets/`. It covers iPhone, Mac and Apple Watch, with default, dark, tinted and clear appearances. Open it in Icon Composer (Xcode ▸ Open Developer Tool ▸ Icon Composer) to adjust it, or edit `icon.json` by hand.

- **Background.** A linear gradient from `#443c5a` at the top to `#1e1e2e` at the bottom, the Mocha base with the faint mauve glow. In the dark appearance it is solid `#1e1e2e`.
- **Groups.** "Sparkles" in front and "Kettlebell" behind it, holding liquid, body and handle from front to back. The layers are already sized and centered on the 1024 canvas (the mark takes 62% of it), so they sit at 100% scale and 0, 0.
- **Tinted and clear.** Derived by the system from the layers.
- **Platforms.** Squares for iOS and macOS, a circle for watchOS.

The name has to be `AppIcon` because that is `ASSETCATALOG_COMPILER_APPICON_NAME` in `project.yml`. Each app target lists the document there with `type: file`, so XcodeGen adds it as one resource and not as a folder of sources.

If a layer changes in `icon-layers/`, copy the SVG over the one in `AppIcon.icon/Assets/` (`1-handle.svg` is `handle.svg`, and so on). To see the result without opening Icon Composer, render it with `ictool`:

```bash
ictool="/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
"$ictool" Apps/Shared/AppIcon.icon --export-image --output-file icon.png \
  --platform iOS --rendition Default --width 1024 --height 1024 --scale 1
```

Platforms are `iOS`, `macOS` and `watchOS`. Renditions are `Default`, `Dark`, `TintedDark`, `TintedLight`, `ClearDark` and `ClearLight`.
