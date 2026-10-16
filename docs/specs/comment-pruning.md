# Comment pruning

## Problem Statement

The codebase carries about 2,000 comment blocks. An audit at `d9dbad2` found that about 1,100 of them only restate the code next to them, record ticket history, narrate test steps, or have gone stale. About 85 more apologise for a workaround in our own code: a name that hides what a symbol does, an Optional or Int that secretly carries meaning, a magic number, or copied logic kept in sync by hand.

The audit also turned up defects that the comments were covering for:

- The brew and rework prompts tell the model to call `findExercises`, but those requests pass no tools.
- `IntelligenceDebugView` compiles into Release builds.
- Two test fixtures name the wrong weekday.
- Plan weeks are counted two ways. `PlanEditor.week(of:)` counts 7-day blocks from the start date, while Progress, the digest and the week glance count ISO Mondays. A plan that starts mid-week shows different weeks on Today and Progress.
- Two unsorted profile fetches (`TodayGlance`, `WorkoutEntity`) can pick a different profile from the rest of the app after a sync duplicate.
- `PlaceholderRoot` and `ContextBudget` have no production callers.

A reader can't tell which comments matter, and the ones that apologise keep the workaround alive.

## Solution

Delete comments that carry nothing. Fix the defects. Replace each apologetic comment with the refactor that makes it unnecessary, and delete the comment in the same change.

### What stays

A comment stays only when it is one of these:

- A behaviour forced by something we can't change: Apple frameworks (HealthKit, CloudKit, SwiftData, WidgetKit, App Intents, Foundation Models), SwiftUI platform quirks, third-party file formats (Strong, Hevy, RFC 4180), or the time zone database. Examples: the `UNUserNotificationCenter.delegate` timing in the `App` inits, HealthKit hiding read authorisation, the Foundation Models tool-loop and shortlist notes, and the SwiftData undo-manager crash in `DataTransfer+Delete.swift`.
- A doc comment on a `public` symbol that states its contract: units, what `nil` means, side effects, formats, ordering.
- A doc comment on an internal type that defines an on-disk format users keep (`Backup.swift`, `WorkoutCSV.swift`).
- The usage and exit-code contract of a script (`scripts/check.sh`, `build-apps.sh`, `render-brand.swift`).
- `// swift-tools-version`, and lint suppressions on style-only rules (`sorted_imports`).

### What goes

- Every `// MARK:` banner.
- Ticket numbers like `(#17)` in headers and docs. Git history keeps them.
- Doc comments that repeat the symbol's name or body, on any access level. A doc that says something the name doesn't (units, the meaning of `nil`, a non-obvious rule) stays, or the symbol is renamed so the doc becomes redundant.
- Narration that restates the next line, including test-phase comments ("Down:", "Weeks 1-3 logged.") and hand-derived expected values.
- Stale or false comments.
- Suppressions that silence nothing (`force_unwrapping`, which `.swiftlint.yml` doesn't enable).

### What gets refactored

Each refactor ticket names the comment and the symbol. The comment goes in the same change as the refactor. The delete-pass tickets leave those comments alone, so the coder doing the refactor still sees what it is for.

### Decisions

- A plan week starts on the ISO Monday of the week containing the plan's start date. Every screen counts weeks this way (#79).
- When the iPhone owns a workout and the watch records it to Health, a `nil` ID from the watch ends the wait and the iPhone saves its own. If the watch's ID arrives after the iPhone saved, the iPhone deletes its own Health workout and adopts the watch's (#83).
- Stored shapes don't change outside SchemaV2. That covers `Codable` attributes such as `PlateInventory` and the backup format, as well as the model schema.
- The two suspected defects in the mirrored rest bar (#70) and delete-all (#71) were checked and closed. The comments that explain them stay.

### Out of scope until SchemaV2

`Profile.barbellKg` duplicates `plates.barKg`, and the unit settings mix an overall system with per-unit overrides. Both fixes change the CloudKit schema, which is in Production. They wait for SchemaV2, a migration and a redeploy.

## Testing Decisions

- The delete passes change no behaviour. `scripts/check.sh` passing is the test. A reviewer checks the diff touches only comment lines.
- Each defect ticket names its own seam, or says how to check it where no test can reach.
- Refactors keep the existing tests green. Where a refactor exposes a rule that was only in prose (a ranking, a retry count, a "first profile wins" rule), the ticket says whether a test pins it.
- Test-only tickets keep every assertion. Splitting a test must not drop a case.

## Ordering

1. The three delete passes run in parallel. Their files don't overlap.
2. Defects and dead code next.
3. Small renames and extractions, per package.
4. Shared helpers, domain types and lifecycle changes, ordered by the files they share.
