# Logging a set in a session

The session sheet lists the workout's exercises with a table of sets; completing a set checks it and starts the rest timer, and the set editor changes reps, weight or time (and shows plates for a barbell lift).

## Sub-features

- `set-complete` a completed set is checked and tinted green.
- `set-add` "Add set" appends a set to an exercise.
- `set-edit` the pencil or the weight opens the set editor (needs taps).
- `session-finish` "Finish" ends the workout and files it in the Log.

## How to get to it (user POV)

- Today, then Resume workout or the planned day, opens the session sheet.
- Open a set in the sheet to edit it.

## Driving it with ios-sim.sh

Preconditions:

- A running workout with its first set done: `-seedSample -sampleSession` on a fresh store.

- **Open the session.** Run `VERIFY_SETTLE=6 $S launch -seedSample -sampleSession -openLink transmute://today/begin`, then `$S shot 01-session`. In one run the sheet titled "Lower and power" showed "Box jump" with set 1, `4` reps and a green check, then "Add set", then "Back squat" with its set table: the first set is the one `-sampleSession` logged. That shot was taken while the sheet was still sliding up, and a later run did not show the sheet at all (see Today's Gotchas), so retake it and read what is there.
- **Side effect.** `sqlite3 -readonly "<Transmute.store>" "select count(*) from ZLOGGEDSET where ZISCOMPLETED = 1"` is at least 1 once `-sampleSession` ran, and the running workout's set shows the check. Table and column names are SwiftData's: `.schema ZLOGGEDSET` first.

## Gotchas

- Completing a second set, adding a set, editing, the plate sheet and Finish all need taps. They cannot be driven here: unverified.
- The sheet slides up: a screenshot at the default 3 s can catch it mid-animation. Use `VERIFY_SETTLE=6`.
- A running workout survives relaunch on the same simulator. `-sampleSession` does nothing the second time because the store already has a profile.
- Rest timer values tick: do not assert a countdown number from a screenshot.
