## Agent skills

### Issue tracker

Issues and specs live in GitHub Issues for `xchrisbailey/Transmute`. See `docs/agents/issue-tracker.md`.

### Triage labels

Use the five default triage labels. See `docs/agents/triage-labels.md`.

### Domain docs

Use a single-context layout. See `docs/agents/domain.md`.

### Git workflow

Write each commit subject as a plain imperative sentence ending in its issue number, such as `Add the Settings screen (#18)`.
Work reaches `main` through a pull request. There is no hosted CI, so run `scripts/check.sh` before pushing.

### Orchestration

The main session (Opus 5.5) plans, delegates, reviews, and merges; all coding and test writing goes to the `coder` agent. A session spawned as a `coder`, `reviewer`, `shepherd`, `scout`, or `adversary` follows its own file in `.claude/agents/` instead. When delegating a ticket, starting an agent team, reviewing a coder's branch, or running `/implement-spec`, read `docs/agents/orchestration.md`.

### Coding standards

Review a diff against `CODING_STANDARDS.md`.
