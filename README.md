# Transmute

A native workout planner and logger for iPhone, Apple Watch and Mac. Tell it your body and your goals, it brews a training plan with Apple Intelligence, and you log that plan set by set.

By srcery.

## Layout

| Path | What lives there |
|---|---|
| `Packages/TransmuteCore` | Models, units, the exercise library, progression, PRs, brand tokens. Pure Swift, no UI. |
| `Packages/TransmuteIntelligence` | The plan-brewing boundary over Foundation Models. |
| `Packages/TransmuteUI` | Shared SwiftUI components and brand fonts. |
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
scripts/test-packages.sh   # swift test for every package
scripts/ci-build.sh        # build all three apps, unsigned
swiftlint lint --strict
swift format lint --strict --recursive Apps Packages
```

Brand strings live in `Apps/Shared/Localizable.xcstrings` and are read through `Copy` in TransmuteUI. Each key starts with `voice.` (alchemy verbs) or `plain.` (mid-set, watch, errors, deletes, Health).

CI runs the same steps on GitHub's `xcode-27` runner.
