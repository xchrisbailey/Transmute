# Transmute verification map

This directory is the maintained source for verifying what a person sees in Transmute. Read this index, then the feature file that matches your change, and drive it with `../scripts/ios-sim.sh` (see `../SKILL.md` for launch arguments, cleanup and rules).

## Baseline preconditions

- Build once: `ios-sim.sh build`. Rebuild after every source change; the simulator runs whatever you last installed.
- Your own simulator: `ios-sim.sh start`, then `ios-sim.sh install`. `ios-sim.sh doctor` must print no `FAIL`.
- First launch uses `-seedSample` so the store has the sample tennis player ("Court-ready strength" plan, finished workouts). Add `-sampleSession` when a workout must be running.
- Never drive a simulator this run did not create. Never use `simctl openurl`.

## Driving conventions

- There are no taps. Choose the screen with `-openLink <transmute://...>` or `-rootTab <today|log|progress|plan>`, wait for the settle delay, take a screenshot, read it.
- Start each recipe from the state in its Preconditions. The store persists between launches on one simulator, so a session you started stays running: use `ios-sim.sh stop` and `start` for a clean store.
- Pass `-appearance mocha` (dark) or `-appearance latte` (light) to check both themes.
- Do not edit the app to add harness code. The one permanent debug hook is `-openLink`.

## Proof and skip reporting

- Capture a `00-before` and a `NN-after` screenshot with `ios-sim.sh shot`, record the launch arguments used, and say what you read on the screen.
- A screen you cannot reach without a tap is unverified. Name the feature, the missing step and why. Do not claim it passed through a neighbouring screen.
- Mention the notification-permission alert if it covers a screenshot.

## Feature entry contract

Each feature file starts with an H1 and one paragraph of user-visible behaviour, then exactly four H2s in order: `Sub-features`, `How to get to it (user POV)`, `Driving it with ios-sim.sh`, `Gotchas`.

## Features

- [Today and starting a workout](today-and-start.md): the Today screen, resuming and beginning a session, `transmute://today/begin`.
- [Logging a set in a session](log-a-set.md): the session sheet, the logged first set, the set editor.
- [History and opening a workout (deep link)](history-open-workout.md): the Log tab and `transmute://log/<id>`.
- [Plan](plan.md): the plan overview and weeks, `transmute://plan`.
- [Settings and plates](settings-and-plates.md): units, equipment and plate setup. Mostly not drivable without taps.
- [Apple Watch](watch.md): the watch's Today, set and rest screens, and what the Digital Crown cannot do here.
- [Mac](mac.md): the Mac app. Recipe only, not run.
