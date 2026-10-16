# History and opening a workout (deep link)

The Log tab lists finished workouts; opening one shows its title, start time, the plan day it came from, its duration and set count, and a table per exercise.

## Sub-features

- `history-list` the Log tab lists workouts, newest first, with search and filters.
- `history-open` opens one workout by `transmute://log/<workout-uuid>`, as Spotlight does.
- `history-missing` a link to an id that is gone leaves the Log open.

## How to get to it (user POV)

- Tap the Log tab, then a workout.
- Tap a workout result in Spotlight (the app receives `transmute://log/<id>`).

## Driving it with ios-sim.sh

Preconditions:

- The sample store is seeded (`$S launch -seedSample` has run once on this simulator).

- **List.** Run `$S launch -rootTab log`, then `$S shot 01-log`. The Log tab is selected and lists workouts including "Speed, agility and conditioning".
- **Open by link.** Run `id=$($S workout-id)`, then `$S shot 00-before`, then `$S launch -openLink transmute://log/$id`, then `$S shot 01-open-workout`. The Log tab is selected and the detail shows the title, "Started" with a date and time, "From your plan: week N, ...", a duration and set count line such as `41:25 · 22 sets`, and the exercise tables. The title is the one the database gave for that id: `sqlite3 -readonly <Transmute.store> "select ztitle from zworkout where hex(zid)=upper(replace('$id','-',''))"`.
- **Missing id.** Run `$S launch -openLink transmute://log/00000000-0000-0000-0000-000000000000`. The Log tab is open and no detail is pushed.

## Gotchas

- The workout id is a random UUID per seeded store, so get it from `workout-id` after the first launch; it is never the same twice. On a brand-new store the first launch must be `-seedSample` alone, since the id does not exist yet.
- `workout-id` only returns finished workouts by default; `workout-id running` returns the running one.
- Do not use `simctl openurl booted`: it raises a system prompt that cannot be tapped.
- The detail is pushed onto the Log tab's stack. A second `-openLink` after relaunch starts from a fresh stack, so there is no stale detail.
- Verified on the iOS 27 simulator for ticket #94: the opened detail was "Speed, agility and conditioning", matching the title the store gave for that id; an all-zero id left the Log list open.
