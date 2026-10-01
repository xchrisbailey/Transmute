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
