# Settings and plates

Settings holds General (units, equipment and plate setup, appearance), Workout (rest timers), Intelligence, Health, Data (import, export, delete all) and About. Plate setup records the bar and plates a person owns; the plate sheet, opened from a set's weight, shows what to load on the bar.

## Sub-features

- `settings-open` the gear in the toolbar opens Settings (iPhone) or the Settings window (Mac).
- `settings-units` weight, height and distance units.
- `plates-setup` bar and plate inventory (General, Equipment, Plate setup).
- `plates-sheet` loaded bar and nearest loadable weights for a set's target.
- `settings-appearance` Mocha, Latte or system.

## How to get to it (user POV)

- Tap the gear in the top toolbar of any tab, then General, then Equipment.
- Open a set in a session and tap its weight to see the plate sheet.
- Mac: Transmute menu, Settings (Cmd+,).

## Driving it with ios-sim.sh

Preconditions:

- Seeded store.

- **Appearance (not the Settings screen).** `$S launch -seedSample -appearance mocha` then `$S shot 01-mocha`, and `-appearance latte` for light. This checks the theme on the screen you reach, not the Settings control.
- **Settings and Plate setup.** No launch argument or deep link reaches them. Nothing here can drive it: reported as unverified.
- **Plate maths without UI.** `swift test` in `Packages/TransmuteCore` with `--filter PlateTests` runs the plate solver and `PlateStorageTests` the stored inventory. That proves the numbers, not the screen.

## Gotchas

- The only way into Settings and the plate sheet is a tap. A UI change here cannot be proven with this skill today. Say so rather than screenshotting a neighbouring screen.
- To make it drivable: a DebugLaunch argument that sets the iPhone tab's navigation (for example `-openLink transmute://settings`) would need a new `DeepLink` case, which is a product decision, not a debug hook.
- `-appearance` is a stored default: it stays set on that simulator until you pass another value.
- Delete all, import and Health are destructive or need permissions: never drive them against a store you did not create.
