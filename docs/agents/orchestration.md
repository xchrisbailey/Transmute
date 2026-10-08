# Orchestration

**Roles.**

- **Opus 5.5** (`claude-opus-5-5`) is the main session, and the lead of an agent team. It plans, breaks work into tickets, delegates, reviews, merges, and decides. Orchestration, merging, and the review verdict are never delegated.
- **Sonnet 5.5, high reasoning** (`claude-sonnet-5-5`, `high`) does all delegated coding and test writing, through the `coder` agent in `.claude/agents/coder.md`.
- On an agent team, three more agents in `.claude/agents/` take work off the lead:
  - `reviewer` (Sonnet 5.5, high) gives each coder's branch a first-pass review;
  - `shepherd` (Haiku 5.5) reruns the local checks on a coder's branch and cleans up after merges;
  - `scout` (Haiku 5.5) is a read-only lookup subagent for gathering what a brief needs. It works in either mode.
- **Fable 5.1** (`claude-fable-5-1`) runs the `adversary` subagent, which tries to break a ticket breakdown or a risky branch. Opus calls it; it is never a teammate.
- Opus fixes trivial review nits itself. Anything larger goes back to a coder.
- When a spec or ticket records execution assignments, it uses these roles unless the user names others for that work.

**Skills.**

The engineering skills describe their own subagents and steps. In this repo they run through the roles above, and where a skill and this file disagree, this file wins:

- `/implement-spec`:
  - its **implementer subagent** is a `coder`, whose base is the integration branch and whose own instructions already cover the `tdd` skill, the worktree, and merging the integration branch tip before it reports;
  - its **exploration subagent** is a `scout`, briefed with a notes path outside the repo;
  - it has no **merger subagent**: Opus merges each ticket's branch into the integration branch itself, after that ticket's review below has passed;
  - its closing `code-review` on the integration branch still runs, as the pass over the whole spec, and its fixes go to one `coder`;
  - the integration branch reaches `main` through a draft pull request, as the skill describes for a tracker that closes work through PRs;
  - worktree cleanup goes to the `shepherd` on a team, and to Opus otherwise.
- `/implement` is for work Opus has been told to do itself in the current checkout. It doesn't change who codes delegated tickets.
- `/code-review` is how Opus carries out its own review in the Review section: its Standards and Spec passes are that review's two halves. The `reviewer` agent is a separate, earlier pass that only exists on a team.
- `/to-spec`, `/to-tickets`, and `/grill-with-docs` run in the main session, before any delegation. The adversary's breakdown pass comes after `/to-tickets` publishes and before the first coder starts.
- A coder can't confirm test seams with the user, which the `tdd` skill asks for. The spec's Testing Decisions section is that agreement; a ticket whose seams it doesn't cover goes back to Opus before a coder starts.

**Delegation.**

- Each delegated task is confined to one ticket, or one clearly bounded piece of one.
- Run it in a subagent or a new thread with its own git worktree and branch.
- The brief must stand alone. Include:
  - the ticket link and its acceptance criteria;
  - the spec, and the relevant ADRs and `GLOSSARY.md` terms where those exist;
  - what is out of bounds;
  - the base branch, and the build and test commands;
  - what to report back: the branch, its head commit, a summary, and anything left open.
- Coders don't widen scope or make product or architecture decisions. They stop and report any open question to Opus.
- A coder that goes idle with a check still running may never wake to report. When one says it is waiting on a run and then goes quiet, Opus asks it for the result, or has the check rerun on the pushed head.

**Agent teams.**

- Delegate a single ticket to a `coder` subagent. Start an agent team when two or more tickets are ready at once. A team costs tokens for every teammate, so it has to buy parallel work.
- The roster is up to three coders, one `reviewer`, and one `shepherd`. Spawn each from its agent type, which sets its model, and name each coder `coder-<issue>`.
- A teammate starts in the main checkout with none of the lead's conversation. The brief still stands alone, and a coder's brief also names its branch, its worktree path `.claude/worktrees/<issue>-<slug>`, and its base.
- The main checkout stays clean, on `main` or on the integration branch while a spec is being implemented. Only the lead works in it.
- Give each ticket three tasks, each subject starting with `#<issue>`, and each depending on the one before:
  - `#<issue> code`, for its coder;
  - `#<issue> review`, for the reviewer;
  - `#<issue> verify`, for the shepherd.
  A ticket's `code` task also depends on the `code` task of each ticket that blocks it.
- When the session has no shared task list, keep the same three steps per ticket and drive them by message: spawn `reviewer` and `shepherd` once as named agents, brief each with the ticket and the coder's branch, and have the coder message `reviewer` and the lead message `shepherd` when a branch is ready.
- The coder and reviewer settle first-pass findings between themselves. A question about the spec, an ADR, or product behaviour comes to the lead from either of them.
- Teammates don't survive `/resume`, so GitHub holds everything that matters: coders push their branch early, and the reviewer posts findings as a comment on the ticket. Brief a replacement teammate from the branch and the ticket's comments.
- Shut a teammate down once its tasks are completed.

**Adversarial pass.**

- Run the `adversary` subagent at two points:
  - on the ticket breakdown, before delegating work that spans two or more tickets;
  - on a ticket's branch, before the Opus review, when it touches the mirrored session between iPhone and watch, the SwiftData schema or iCloud sync, backup and import, or what is saved to Health.
- Give it the tickets or the branch, the spec, and a path outside the repo for its report. Keep your own conclusions and the reviewer's pass out of the brief, so its read isn't anchored on them.
- A finding counts when it comes with a scenario that reproduces it. Opus decides each one: fix the breakdown, send it to the coder, or set it aside with the reason on the ticket.

**Review.**

- Opus reviews every ticket's branch before it is merged, with the `code-review` skill against the branch's base, checking it against:
  - the ticket's acceptance criteria;
  - the spec and ADRs;
  - the glossary;
  - `CODING_STANDARDS.md` and `AGENTS.md`.
- Opus also confirms the checks pass. There is no hosted CI, so `scripts/check.sh` is the gate: SwiftLint, swift-format, every package's tests, and an unsigned build of all three apps. It keeps no record, so the evidence is a report that names the branch's current head commit and quotes `All checks passed.` for it. Before merging, Opus compares that commit with the branch's head; when they differ, or no such report exists, the check goes to the shepherd to run, or back to the coder.
- A change to prompts, schemas, or the exercise library also needs `scripts/eval-intelligence.sh`, which Opus runs itself; it calls the on-device model and isn't part of `scripts/check.sh`.
- On a team, the `reviewer` passes a branch before Opus reviews it. Its pass covers the coding standards, the glossary, and the acceptance criteria; the spec, the ADRs, and the verdict stay with Opus.
- Review findings go back to the same coder, which keeps its context, until the review passes.
- Opus reports the result to the user.
