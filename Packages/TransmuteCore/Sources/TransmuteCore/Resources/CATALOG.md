# Exercise catalog

`exercises.json` is the library Transmute ships. The AI picks plan exercises only from here (plus the user's custom exercises), so coverage decides how good plans can be.

## Source and license

Every entry was written for Transmute: names, cues, mistakes, tags and alternatives. No third-party dataset was used, so the catalog carries no outside license and is covered by this repository's terms. If an open dataset is added later, record its name, version and license here and keep its entries traceable.

## Schema (version 1)

| Field | Meaning |
|---|---|
| `id` | Stable kebab-case slug. Never rename one; plans and logs point at it. |
| `name`, `aliases` | Display name and other names people search for (e.g. RDL, 5-10-5). |
| `category` | `strength`, `power`, `speedAgility`, `conditioning` or `mobility`. |
| `pattern` | Movement pattern, e.g. `hinge`, `changeOfDirection`. |
| `primaryMuscles`, `secondaryMuscles` | `Muscle` raw values. |
| `equipment` | A list of requirements; each inner list is a choice. `[["dumbbell","kettlebell"],["bench"]]` needs a bench and either weight. Bodyweight is always available. |
| `tracking` | `weightReps`, `reps`, `time`, `distanceTime` or `intervals`. |
| `unilateral` | One side at a time. |
| `difficulty` | `beginner`, `intermediate` or `advanced`. |
| `cues` | Plain setup and movement cues for a beginner (at least two). |
| `mistakes` | Common mistakes. |
| `easier`, `harder` | Ids of a simpler and a harder alternative. |
| `sports` | `general`, `tennis`, `running`, `soccer`, `climbing`. |

Bump `version` when entries change meaning. `ExerciseLibraryTests` checks ids, references, completeness and tennis coverage.

## Demo videos

`exercise-demos.json` holds the reviewed YouTube demo for an exercise and the equipment it shows, keyed by stable `id`. Only a record that passes `ExerciseDemo.isValid` ships, and `ExerciseDemoLibraryTests` lists the approved set. Reviewing a candidate, and what a report from the app contains, are specified in `docs/specs/exercise-demo-videos.md`.

### Handling a "Wrong demo video" report

A report is a public GitHub issue, titled "Wrong demo video: ..." with the exercise ID, equipment, video link and app version. It asks for a review. It does not remove anything by itself.

1. Watch the reported video against that exercise and equipment. If it matches, reply and close the issue.
2. To replace it, edit that record's `videoID`, and redo the review fields (`reviewedBy`, `reviewedOn`, `movementReview`, `mutedReview`, and `captions` with `captionReview` where anyone speaks). A new video needs the same exact-movement and caption review as the first one.
3. To remove it, delete the record. The exercise keeps its written cues, and other equipment's demos stay.
4. Never change the `id`. Run `scripts/check.sh` and, because library content changed, `scripts/eval-intelligence.sh`.
5. Ship it in an app update, then reply on the issue. Installed apps keep the old association until they update; there is no remote removal.
