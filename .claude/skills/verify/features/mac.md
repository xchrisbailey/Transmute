# Mac

The Mac app has a sidebar (Today, Log, Progress, Plan), a table and grid view of the plan, and a Settings window. It follows the same `transmute://` links and the same launch arguments as the iPhone app.

## Sub-features

- `mac-sidebar` the sidebar sections open their screens.
- `mac-plan-grid` the plan as a grid of weeks and days.
- `mac-link` a launch with `-openLink` goes to the named section.

## How to get to it (user POV)

- Launch Transmute; click a section in the sidebar.
- Transmute menu, Settings (Cmd+,).

## Driving it with ios-sim.sh

Preconditions:

- The Mac app opens a real window on the user's desktop and uses a real data store, so this is a recipe for a session that is allowed to do that. A coder session that is told the desktop is closed must not run it.

- **Build.** `scripts/build-apps.sh TransmuteMac` puts `build/DerivedData/Build/Products/Debug/Transmute.app` in your worktree.
- **Launch.** Start the binary directly so you hold its pid: `build/DerivedData/Build/Products/Debug/Transmute.app/Contents/MacOS/Transmute -seedSample -openLink transmute://plan &` and keep `$!`.
- **Screenshot one window.** Find its id, then `screencapture -x -l <windowid> build/verify/<timestamp>/mac-plan.png`. The window id comes from `CGWindowListCopyWindowInfo` filtered by the owner `Transmute` and the pid you hold.
- **Cleanup.** `kill <pid>` of the process you started. Never `killall`.

## Gotchas

- Not run for ticket #94: the desktop was closed to the author. Whether `screencapture -l` works without Screen Recording permission for this terminal is unverified; it may produce a blank window. If it does, say so and do not use the image.
- Isolation is unverified: the unsigned build has no App Group, so its store lands under the user's home. `-seedSample` only fills an empty store, but a dev store is not empty. Consider a scratch home with `CFFIXED_USER_HOME` (untested) before running.
- The Mac app has no running-session to start: `-sampleSession` does nothing there.
