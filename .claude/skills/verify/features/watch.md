# Apple Watch

The watch app shows Today's planned workout, runs a session one set at a time, and shows a rest ring between sets. The Digital Crown sets reps and weight on the set screen.

## Sub-features

- `watch-today` the Today screen with the planned day.
- `watch-set` the set screen for the current set of the running workout.
- `watch-rest` the rest ring after a set is logged.
- `watch-crown` the Digital Crown changes reps or weight (cannot be driven).

## How to get to it (user POV)

- Open Transmute on the watch; Today is the first screen.
- Start the day, or open a running workout from the iPhone.

## Driving it with ios-sim.sh

Preconditions:

- A watchOS simulator created by this run (it is standalone, not paired). `VERIFY_PLATFORM=watch` selects the watch scheme, bundle id `computer.srcery.transmute.watchkitapp` and Apple Watch Series 12 (46mm).

- **Build and start.** `VERIFY_PLATFORM=watch $S build`, `start`, `install`.
- **Today.** `VERIFY_PLATFORM=watch $S launch -seedSample` then `shot 01-watch-today`.
- **Set screen.** On a fresh store: `VERIFY_PLATFORM=watch $S launch -seedSample -sampleSession` then `shot 02-watch-set`.
- **Rest ring.** On a fresh store: `VERIFY_PLATFORM=watch $S launch -seedSample -sampleSession -sampleRest` then `shot 03-watch-rest`. Run for ticket #94: the ring showed a countdown from 1:00 (`0:57` at the shot), "Rest", "+15" and skip buttons, "Next: Back squat", and the page dots.
- **Begin link.** `-openLink transmute://today/begin` starts today's session if none is running and today is not done.
- Seeding runs once per store: `-sampleSession` and `-sampleRest` do nothing on a store that already has a profile, so `stop` and `start` between the set and rest shots.
- Clean up: `VERIFY_PLATFORM=watch $S stop`.

## Gotchas

- The Digital Crown cannot be turned: `simctl` has no crown input. Reps and weight stepping by Crown are unverified. What can be checked: the set and rest screens render, the starting reps and weight shown match the plan, and the logic of the dial through `swift test --filter SetDialTests` in `Packages/TransmuteCore`.
- Taps and swipes between the watch's pages cannot be driven either.
- Heart rate and live workout sessions need HealthKit and a real workout session: they do not run in the simulator.
- Only the rest-ring recipe was run (ticket #94). Today, the set screen and the begin link are untried on the watch.
