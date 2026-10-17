# Today and starting a workout

Today shows the workout planned for today, a Resume row when a workout is running, a Log a workout button and Records. Beginning a workout opens its session sheet.

## Sub-features

- `today-plan` shows this week's planned day: week and day, title, estimated minutes, the plan's note and each exercise with its sets.
- `today-resume` shows "Resume workout" with the running workout's title while one is running.
- `today-begin` starts today's session from the plan (deep link `today/begin`) or goes back into the running one.
- `today-log` starts an unplanned workout with "Log a workout" (needs a tap).

## How to get to it (user POV)

- Open the app: Today is the first tab.
- Tap the Today tab.
- Tap Resume workout, or the planned day card, to open the session.
- A widget or Siri/Shortcuts "begin workout" opens `transmute://today/begin`.

## Driving it with ios-sim.sh

Preconditions:

- `ios-sim.sh doctor` has no FAIL, and the simulator is booted by this run.
- A fresh store (`stop` then `start` and `install` if a session from an earlier run is there).

- **Planned day.** Run `$S launch -seedSample -rootTab today`, then `$S shot 01-today`. The title reads "Today", the day card reads "WEEK 4 · DAY 3" and "Speed, agility and conditioning", and each exercise lists `3 × 0:10`-style targets. The dates depend on when the sample was seeded: week and day move with the calendar, so assert the structure, not the words.
- **Resume.** Run `$S launch -sampleSession` on the already-seeded store (or `-seedSample -sampleSession` on a fresh one), then `$S shot 02-resume`. The top row reads "Resume workout" over "Lower and power".
- **Begin via link, nothing running.** Run `$S launch -openLink transmute://today/begin`, then `$S shot 03-begin`. Observed: a new running workout is created from today's planned day (`sqlite3 -readonly <Transmute.store> "select count(*) from zworkout where zendedat is null"` goes from 0 to 1, and the Resume row reads "Speed, agility and conditioning"), and the Today screen shows that Resume row.
- **Begin via link, one running.** Run `VERIFY_SETTLE=6 $S launch -openLink transmute://today/begin`. Expect the same running workout, not a second one (the count stays 1). Whether the session sheet is on screen at the time of the shot varied: one run caught the "Lower and power" sheet part-way up at a 3 s settle, another showed plain Today with the Resume row at 6 s. Treat the sheet as unverified; the count of running workouts and the Resume row are the dependable evidence.
- **Side effect.** `$S workout-id running` prints one UUID whenever a workout is running.

## Gotchas

- The sample plan is dated relative to the day it is seeded. "Today" can be a rest day or a finished day, in which case there is no Begin; the screenshot shows that state instead. Check the screen before blaming the link.
- Begin does not create a second running workout while one is running, and "Log a workout" is disabled then.
- `-sampleSession` only acts when it seeds: on an already-seeded store it does nothing, so the running workout you get is whatever `today/begin` started.
- Tapping "Log a workout" cannot be driven; use `today/begin` for the same sheet.
- The notification-permission alert may cover the screen after a seeded launch.
