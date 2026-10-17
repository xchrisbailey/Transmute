---
name: verify
description: Launch the Transmute iPhone and Apple Watch apps on a private simulator, drive them with launch arguments and deep links, and capture screenshots as proof of a UI change. Use when asked to run, screenshot or verify Transmute (SwiftUI, iPhone/Watch/Mac), or before reporting a UI change as working. Not for unit tests (use scripts/check.sh).
---

# Verify Transmute

Transmute is a SwiftUI workout planner for iPhone, Apple Watch and Mac. Proof here means: build the app, run it on a simulator you created, put it on the screen you changed, take a screenshot, read the screenshot. Read `features/README.md` first, then the file for the feature you touched.

**What you cannot do.** There is no tap, swipe or typing on a simulator from here (`simctl` has no input commands; `idb`, `axe` and UI scripting are not installed or not allowed). You choose the screen with launch arguments and deep links, then look. Anything that needs a tap is listed in that feature's Gotchas as undrivable. Say so in your report; do not call it verified.

## Rules

- Create your OWN simulator (`ios-sim.sh start`) and only ever touch that one. Other sessions leave booted devices (for example "ProtoVT iPhone 17 Pro Max"): never boot, shut down, erase or install onto a device you did not create.
- Never use `xcrun simctl openurl booted transmute://...`: it stops at a system "Open in Transmute?" prompt nothing can tap. Use `-openLink` (below).
- The shell here is zsh with noclobber: overwrite files with `>|`, not `>`.
- Evidence goes to `build/verify/<timestamp>/` (gitignored, never deleted by cleanup).

## Launch

All helpers are `.claude/skills/verify/scripts/ios-sim.sh <command>`, run from the repo root (your worktree). Set `VERIFY_PLATFORM=watch` for the Apple Watch app.

```
S=.claude/skills/verify/scripts/ios-sim.sh
$S build        # scripts/build-apps.sh TransmuteiOS -> build/DerivedData (own worktree, unsigned, Debug)
$S start        # creates and boots simulator "verify-<timestamp>-<pid>" (iPhone 17 Pro, iOS 27.0); creates build/verify/<timestamp>/
$S install      # installs build/DerivedData/.../Debug-iphonesimulator/Transmute.app
$S launch -seedSample -openLink transmute://plan
```

`launch` terminates any running copy, starts the app with the given launch arguments, and waits 3 s (`VERIFY_SETTLE=<seconds>` to change; sheets and navigation animate, wait longer or screenshot twice). Ready means the screenshot shows the screen you asked for, not that the process exists.

Launch arguments are read by `DebugLaunch` (`Packages/TransmuteCore/Sources/TransmuteCore/Launch/`) in Debug builds only, and they act from an empty store:

| Argument | Effect |
| --- | --- |
| `-seedSample` | Fills an empty store with the sample tennis player, the plan "Court-ready strength" (four weeks, deload in week 4) and a log of finished workouts. Does nothing if a profile exists. Without it the app opens onboarding. |
| `-sampleSession` | With `-seedSample`: also starts this week's first session (running, with its first set logged on iPhone). The running workout is "Lower and power". |
| `-sampleRest` | Watch only, with `-sampleSession`: also logs the first set, to show the rest ring. |
| `-openLink <url>` | After launch, opens a `transmute://` link through `DeepLinkRouter`, the path Spotlight and App Intents use. Valid: `transmute://today`, `today/begin` (starts today's session, or goes back into the running one), `log`, `log/<workout-uuid>`, `plan`. Unknown URLs do nothing. |
| `-initCloudKitSchema` | Do not use for verification. It writes to CloudKit Development. |

The app also reads plain defaults from the command line, which is how you pick a tab or theme without tapping: `-rootTab today|log|progress|plan` (iPhone tab, remembered between launches) and `-appearance system|mocha|latte` (mocha is dark). Defaults persist in the simulator, so pass them every time or they carry over.

The store is per simulator, so `-seedSample` runs once per `start`; later launches keep what the previous run left (a session you started stays running).

To open a specific logged workout you need its id: `$S workout-id` prints the newest finished workout's UUID, `$S workout-id 2` the second newest, `$S workout-id running` the running one. It reads the app's SwiftData store read-only with `sqlite3`.

## Doctor

`$S doctor` is read-only. It checks Xcode, the iOS 27 runtime, `sqlite3`, that `build/DerivedData/.../Transmute.app` exists (with its build time: rebuild if older than your last edit), and, if a session exists, that its simulator is Booted, is the one this run created (by name), has Transmute installed, and that the evidence dir exists. It exits 1 and prints `FAIL` lines otherwise. Run it before driving and whenever a screenshot looks wrong. Before `start` the only expected FAIL is `no session`.

## Drive

```
S=.claude/skills/verify/scripts/ios-sim.sh
$S launch -seedSample -openLink transmute://log/$($S workout-id)   # first launch: seed. workout-id works once the store exists.
$S shot 01-open-workout                                              # -> build/verify/<timestamp>/01-open-workout.png
```

On the very first launch the store does not exist yet, so launch once with `-seedSample` (and `-sampleSession` if you need a running workout), then `workout-id`, then launch again with `-openLink`. Then read the PNG with the Read tool and say what is on it.

The recipe for each screen is in `features/`:

- [Today and starting a workout](features/today-and-start.md)
- [Logging a set in a session](features/log-a-set.md)
- [History and opening a workout (deep link)](features/history-open-workout.md)
- [Plan](features/plan.md)
- [Settings and plates](features/settings-and-plates.md)
- [Apple Watch](features/watch.md)
- [Mac](features/mac.md)

## Evidence

A proof is a screenshot you read, taken after the action, plus the argument list that produced it. Per feature:

- Screenshot after the action, named `NN-what.png`, in the run's evidence dir (the `shot` command puts it there and prints the path). For a change of state (a tab switch, a workout opening), also take one before: `00-before`.
- A side effect check next to what is visible: for anything that writes, read the store (`workout-id`, or `sqlite3 -readonly` on the path `simctl get_app_container <udid> computer.srcery.transmute data` gives, under `Library/Application Support/Transmute.store`).
- Use the real path: the launch arguments and deep links above. Do not add temporary arguments or harness code to the app.
- The system "Would Like to Send You Notifications" alert can cover a screenshot (it showed on the Progress tab after a seeded launch) and nothing can tap it. Relaunch and screenshot again, or pick a screen it does not cover, and say that it appeared.
- Report what the screenshot shows and what it cannot show. A tap-only path is unverified, not skipped.

## Cleanup

```
$S stop      # terminates the app, shuts down and DELETES the simulator this run created, removes build/verify/.session
```

It never touches another device and never deletes `build/verify/<timestamp>/`. Run it after a failed attempt too, so a half-started run does not leave a booted simulator. To check, `xcrun simctl list devices | grep verify-` should be empty (an old `verify-*` left by a dead session can be deleted with `xcrun simctl delete <udid>`; it is yours only if its name starts `verify-` and its timestamp is from a run you made). The Mac app, if you ever launch it, is a plain process: kill the pid you started, never by name.

## Helpers

| Command | What it does |
| --- | --- |
| `ios-sim.sh build` | `scripts/build-apps.sh` for the platform's scheme |
| `ios-sim.sh start` | create, boot, record the simulator and make the evidence dir |
| `ios-sim.sh install` | install the built app |
| `ios-sim.sh launch [args...]` | relaunch with launch arguments |
| `ios-sim.sh shot <name>` | screenshot into the evidence dir, prints the path |
| `ios-sim.sh workout-id [n\|running]` | UUID of a workout from the app's store |
| `ios-sim.sh doctor` | read-only health check |
| `ios-sim.sh stop` | tear down; keeps the evidence |

Run `ios-sim.sh` with no arguments for usage. Overrides: `VERIFY_PLATFORM=watch`, `VERIFY_DEVICE_TYPE`, `VERIFY_RUNTIME`, `VERIFY_SETTLE`. Session state is `build/verify/.session` (`.session-watch` for the watch), so one iPhone and one watch session can coexist per worktree.

## Isolation

Two worktrees can run side by side: each has its own `build/DerivedData`, its own simulator and its own `build/verify/`. Do not drive a simulator you did not create. The Mac app has no isolation (see `features/mac.md`).
