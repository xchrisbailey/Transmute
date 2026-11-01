# Exercise demo sheet — throwaway #111

Question: which information hierarchy helps a beginner without hiding their workout?

Standalone HTML next to the logging UI, **not a production route or implementation**. No dependencies, network media, persistence, real workout mutations, or player integration. Never merge this branch. Human review is pending; no layout has won.

## Open

Double-click `index.html`, or from the worktree root:

```sh
python3 -m http.server 8111 --bind 127.0.0.1 --directory Packages/TransmuteUI/Sources/TransmuteLogUI/Session/PrototypeExerciseDemo
```

Open <http://127.0.0.1:8111/?variant=A>. The same URL supports `?variant=B` and `?variant=C`. The bottom arrows and left/right keys cycle layouts, except when editing a field, select, or editable content. Reload preserves only the URL variant, not workout state. The switcher exists only in this standalone artifact; it is not included in any app target.

- **A · Video first:** prominent media area, all three cues below.
- **B · One cue at a time:** compact player, large cue and previous/next navigation.
- **C · Demo / Form:** quick overview with separate Demo and Form sections.

The logging scaffold reflects `SessionView.swift`, `SessionView+Sections.swift`, `SessionParts.swift`, `SetRow.swift`, and `LogCopy.swift`: workout title and Finish, exercise header, Set/kg/Reps rows, expanded current-set fields, rest countdown, and bottom session context. Sample workout data is invented; this is not a pixel-accurate native rendering. Only draft fields and prototype controls work.

## Human review

1. Enter a draft weight and reps. Scroll a little while leaving Watch demo reachable.
2. Open Watch demo beside Back squat. Check the live state: playback starts stopped; timer continues.
3. Tap Play simulation, then Done or Escape. Check that playback is stopped, draft values and logged set are unchanged, and the workout returns to the same scroll position.
4. Reopen and compare A/B/C. In B, move through cues. In C, switch between Demo and Form. Which helps you get back to your set fastest? Does C hide the cues too much? Does B require too much tapping?
5. Choose the unavailable example. It remains Back squat, with no substituted movement or playable media. This is an exploratory fallback, not an agreed missing-video policy.
6. Tell the orchestrator which parts to keep and why. Record feedback in #111; do not close it or change map #109 until the human has evaluated it.

## Manual browser validation

Headless Chromium via an isolated agent-browser session; no user's desktop used. No prototype tests were added.

- Entered 47.5 kg and 7 reps; ArrowRight in the input kept variant A.
- Opened at workout scroll 24 px; sheet opened with simulated playback stopped at zero.
- Explicit Play changed simulated state to playing. Escape stopped/reset it, retained 47.5 × 7 and the logged 40 × 8 set, and returned to 24 px.
- Rest countdown continued while viewing and dismissing the sheet (2:56 on dismissal, 2:23 later while viewing missing media). It is a wall-clock deadline, independent of simulated playback.
- Keyboard and floating arrows switched layouts; B cue navigation and C Form section were exercised. Missing-media selection retained the same exercise and exposed no Play button.
- At a 390 × 844 viewport, the sheet stayed within the 390 px document width; captured [mobile A](mobile-A.png). This is browser responsiveness, not a simulator check.
- Screenshots: [logging](logging.png), [A](variant-A.png), [B](variant-B.png), [C Demo](variant-C.png), [C Form](variant-C-form.png), [missing video](missing-video.png).

## Limits / decisions still open

All media is a labeled placeholder, with a simulated 30-second play/pause counter. There is no actual video or audio to stop, no provider selected, no licensing claim, and no fullscreen behavior. Cues are illustrative, not expert-reviewed or advice to follow. The rest timer is a silent three-minute sample and is not reset by layout changes. Native presentation, swipe dismissal, actual playback lifecycle/audio, accessibility/Dynamic Type, keyboard avoidance and device behavior still need a later implementation and validation. Missing-video policy and hierarchy selection await human decisions. This artifact cannot prove SwiftUI state preservation.
