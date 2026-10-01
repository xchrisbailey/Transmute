# Brand

Masters for the Transmute mark and wordmark. The source of truth is the brand book linked from issue #3.

| File | What |
|---|---|
| `mark-mocha.svg`, `mark-latte.svg` | Mark A, the kettlebell crucible, on dark (Mocha) and light (Latte). 64×64. |
| `wordmark-mocha.svg`, `wordmark-latte.svg` | `transmute` in Geist ExtraBold, outlined, tracking −0.045em, with the mauve-filled u, the sparkles and the peach `_`. |
| `icon-mocha.png`, `icon-latte.png` | 1024px previews of the app icon. |

`scripts/render-brand.swift` regenerates the wordmarks, the previews and the app icon PNGs in `Apps/Shared/Assets.xcassets/AppIcon.appiconset` from these masters:

```bash
swift scripts/render-brand.swift
```

The PNG icons stand in until the Icon Composer `.icon` (default, dark and tinted variants) is exported from `mark-mocha.svg`.

Geist and Geist Mono live in `Resources/Fonts` under the SIL Open Font License (`Resources/Fonts/OFL.txt`).
