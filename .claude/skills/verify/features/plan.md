# Plan

The Plan tab shows the active plan: its name, summary, why-this-plan note, build and deload phases, and a row per week that opens the weeks' days and exercises. A toolbar offers undo, redo and a menu (rebrew, history). With no plan it offers to brew one with Apple Intelligence.

## Sub-features

- `plan-overview` the plan card and the Week 1..N rows.
- `plan-week` a week opens its days; a day opens its exercises and targets.
- `plan-edit` edit a day or exercise, undo and redo (needs taps).
- `plan-brew` brew a new plan with Apple Intelligence.

## How to get to it (user POV)

- Tap the Plan tab.
- Open `transmute://plan` (widgets, Spotlight and App Intents do).

## Driving it with ios-sim.sh

Preconditions:

- Seeded store (`-seedSample`).

- **Overview.** Run `$S launch -seedSample -openLink transmute://plan`, then `$S shot 01-plan`. The title is "Your plan", the card reads "Court-ready strength", "Power, first-step speed and conditioning for tennis", a "Why this plan" note, a Build 1-3 / Deload 4 bar, and rows Week 1, Week 2, Week 3 and the current week open with its days.
- **Without a plan.** An empty store with a profile and no plan shows the brew screen instead; it cannot be reached from the sample seed.
- **Tab only.** `-rootTab plan` shows the same screen and survives relaunch.

## Gotchas

- Opening a week, a day, editing, undo and redo, the rebrew sheet and the menu all need taps: unverified.
- Brewing calls Apple Intelligence, which is not available in a simulator in a way this skill checks. Do not claim a brewed plan; use the sample.
- The current week expands depending on the date, so the lower half of the screen changes day to day.
- The debug (ladybug) item in the toolbar is Debug-only and opens the Intelligence debug view; ignore it.
