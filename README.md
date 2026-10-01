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

With no team set, the apps are signed to run locally: everything works in the simulators, and the Mac app runs without iCloud. To sign for a device with iCloud, HealthKit and App Groups, copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and set your team.

## Checks

```bash
scripts/check.sh           # everything below, in order
scripts/test-packages.sh   # swift test for every package
scripts/build-apps.sh      # build all three apps, unsigned
scripts/eval-intelligence.sh  # real-model tests and the planning evaluation set (not in check.sh)
```

`eval-intelligence.sh` calls Apple Intelligence on this Mac, so it needs it turned on. The output varies run to run, so run it when prompts, schemas or the exercise library change rather than on every push.

There's no hosted CI, because GitHub's macOS runners lag behind the Xcode and SDKs this project needs. Run `scripts/check.sh` before pushing.

Brand strings live in `Apps/Shared/Localizable.xcstrings` and are read through `Copy` in TransmuteUI. Each key starts with `voice.` (alchemy verbs) or `plain.` (mid-set, watch, errors, deletes, Health).

