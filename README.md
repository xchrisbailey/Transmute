# Transmute

A native workout planner and logger for iPhone, Apple Watch and Mac. Tell it your body and your goals, it brews a training plan with Apple Intelligence, and you log that plan set by set.

By srcery.

## Layout

| Path | What lives there |
|---|---|
| `Packages/TransmuteCore` | SwiftData models, units, the exercise library (`Resources/exercises.json`, see `CATALOG.md`), progression, PRs, brand tokens. No UI. |
| `Packages/TransmuteIntelligence` | `IntelligenceService` and its Foundation Models implementation: availability, guardrail instructions, context budgeting, the library tool and schema constraints that keep the AI to real exercises. |
| `Packages/TransmuteUI` | Shared SwiftUI components and brand fonts (`TransmuteUI`), plus the iPhone and Mac screens that brew and edit plans (`TransmutePlanUI`). |
| `Apps/TransmuteiOS` | iPhone app. |
| `Apps/TransmuteWatch` | Apple Watch app, embedded in the iPhone app. |
| `Apps/TransmuteMac` | Mac app. |
| `Apps/TransmuteWidgets`, `Apps/TransmuteWatchWidgets`, `Apps/TransmuteMacWidgets` | Widget extensions: the Live Activity, Today and the Control Center button on iPhone, complications and the Smart Stack on the watch, Today on the Mac desktop. |
| `Apps/WidgetsShared` | Widget views and copy the extensions share. |
| `Apps/IntentsShared` | App Intents and App Shortcuts for Siri, Shortcuts and Spotlight, shared by the apps; the iPhone widget extension compiles the one its Control Center button runs. |
| `Apps/Shared` | Asset catalog and the `Localizable.xcstrings` String Catalog used by all three apps. |
| `Config` | Shared build settings and local signing overrides. |
| `Brand` | SVG masters of the mark and wordmark. See `Brand/README.md`. |
| `Resources/Fonts` | Geist and Geist Mono (SIL OFL), bundled by every app. |

Requires Xcode 27 and the iOS 27, watchOS 27 and macOS 27 SDKs.

## Getting started

The Xcode project is generated from `project.yml` and isn't checked in.

```bash
brew install xcodegen swiftlint
xcodegen generate
open Transmute.xcodeproj
```

With no team set, the apps are signed to run locally: everything works in the simulators, and the Mac app runs without iCloud (its widgets can't share its store without the App Group, so they stay empty). To sign for a device with iCloud, HealthKit and App Groups, copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and set your team.

## Checks

```bash
scripts/check.sh           # everything below, in order, recorded against the commit
scripts/check.sh --show    # the recorded result for a commit (default HEAD)
scripts/test-packages.sh   # swift test for every package
scripts/build-apps.sh      # build all three apps, unsigned
scripts/eval-intelligence.sh  # real-model tests and the planning evaluation set (not in check.sh)
```

`eval-intelligence.sh` calls Apple Intelligence on this Mac, so it needs it turned on. The output varies run to run, so run it when prompts, schemas or the exercise library change rather than on every push.

There's no CI on pull requests, because GitHub's macOS runners lag behind the Xcode and SDKs this project needs. Run `scripts/check.sh` before pushing. It refuses uncommitted work, because the result is recorded for the commit; `--allow-dirty` runs it mid-change without a record.

Turn on the pre-push hook once per clone. It runs only the two lint steps, which take a second or two:

```bash
git config core.hooksPath scripts/hooks
```

## Product page

The dependency-free public site lives in `site/`; it has no build step or external assets.

```bash
python3 -m http.server 8080 --directory site
python3 scripts/test-site.py
```

Open `http://localhost:8080`. The integration check validates local assets, anchors,
project-relative URLs, metadata and essential semantics. In a browser, also check the
example set logger with the keyboard, reset/completion states, JavaScript disabled,
reduced motion and layouts at 1440, 768 and 390px. UI fragments are illustrative,
not app screenshots; the workout values are examples, not training advice.

`.github/workflows/pages.yml` publishes **only `site/`** on pushes to `main` that
change the site or workflow, or a manual run. A repository administrator must select
GitHub Actions as the Pages source in repository settings; the workflow uses the
`github-pages` environment. No native build runs there. The intended address is
`https://xchrisbailey.github.io/Transmute/`.

The “Follow development” links intentionally point to the repository while the app
is in early development. When a real public release exists, replace those links and
their labels together, update availability copy, and rerun the integrity/browser checks.
Keep canonical/social metadata in sync if the hosting address changes. Fonts are
bundled under the SIL OFL (`site/assets/fonts/OFL.txt`); marks come from `Brand/`.

## Native releases

Xcode Cloud archives the iPhone (with the watch app inside) and Mac apps and sends them to TestFlight when a `v*` tag is pushed. The scripts it runs are in `ci_scripts/`. `docs/TESTFLIGHT.md` walks through the one-time Apple Developer, App Store Connect and Xcode Cloud setup.

Brand strings live in `Apps/Shared/Localizable.xcstrings` and are read through `Copy` in TransmuteUI. Each key starts with `voice.` (alchemy verbs) or `plain.` (mid-set, watch, errors, deletes, Health).
