# Orchestration

**Roles.**

- **Opus 5.5** (`claude-opus-5-5`) is the main session and the lead. It plans, breaks work into tickets, delegates, reviews, merges, and decides. Orchestration, merging, and the review verdict are never delegated.
- **Sonnet 5.5, high reasoning** (`claude-sonnet-5-5`, `high`) does all delegated coding and test writing, through the `coder` agent in `.claude/agents/coder.md`.
- Four more agents in `.claude/agents/` take work off the lead:
  - `reviewer` (Sonnet 5.5, high) gives each coder's branch a first-pass review;
  - `scout` (Haiku 5.5) is a read-only lookup subagent, for gathering what a brief needs or auditing what the code already does;
  - `shepherd` (Haiku 5.5) reruns the local checks on a branch and cleans up after merges, when the lead would rather not spend its own context on either;
  - `adversary` (Fable 5.1, `claude-fable-5-1`) tries to break a ticket breakdown or a risky branch.
- Opus fixes trivial review nits itself, at merge. Anything larger goes back to the coder that wrote it.
- When a spec or ticket records execution assignments, it uses these roles unless the user names others for that work.

**Skills.**

The engineering skills describe their own subagents and steps. In this repo they run through the roles above, and where a skill and this file disagree, this file wins:

- `/implement-spec`:
  - its **implementer subagent** is a `coder`, whose base is the integration branch and whose own instructions already cover the `tdd` skill, the worktree, and merging the integration branch tip before it reports;
  - its **exploration subagent** is a `scout`, briefed with a notes path outside the repo;
  - it has no **merger subagent**: Opus merges each ticket's branch into the integration branch itself, after that ticket's review below has passed;
  - its closing `code-review` on the integration branch is the closing review below, and its fixes go to one `coder`;
  - the integration branch reaches `main` through a pull request;
  - Opus cleans up the worktrees and ticket branches, or hands that to a `shepherd`.
- `/implement` is for work Opus has been told to do itself in the current checkout. It doesn't change who codes delegated tickets.
- `/code-review` is the closing review: once, over everything that is about to reach `main`.
- `/to-spec`, `/to-tickets`, and `/grill-with-docs` run in the main session, before any delegation.
- A coder can't confirm test seams with the user, which the `tdd` skill asks for. The ticket's Testing section, or the spec's Testing Decisions, is that agreement. A ticket that names no seam, or doesn't say how to check what no test can reach, goes back to Opus before a coder starts.

**Delegation.**

- Each delegated task is confined to one ticket, or one clearly bounded piece of one.
- Run it as a `coder` subagent in the background, in its own git worktree, on a branch named `<issue>-<slug>`.
- The brief must stand alone. Point at what exists instead of repeating it:
  - the ticket number, which carries the acceptance criteria;
  - the base branch and the branch name to use;
  - the files and types worth reading first, and the spec, ADRs and `GLOSSARY.md` terms where those exist;
  - what is out of bounds, naming the other tickets in flight and the files they will touch;
  - anything the adversary left unconfirmed that this ticket should settle;
  - what to report back: the branch, its head commit, the check record, each criterion with what meets it, and anything left open.
- Coders don't widen scope or make product or architecture decisions. They stop and report any open question to Opus.
- A coder that goes idle with a check still running may never wake to report. When one says it is waiting on a run and then goes quiet, Opus reads the record for the coder's head commit (`scripts/check.sh --show <commit>` exits 2 until one exists) and acts on it when it lands.

**Several tickets at once.**

- Two or more tickets go onto an **integration branch**, pushed to origin. The main checkout sits on it, stays clean, and only the lead works in it.
- Run up to three coders at a time. Each one costs tokens and a full local check, and three checks at once are slow on one Mac, so parallel work has to buy something.
- Tickets that edit the same files run one after another, and the ticket says so in its "Blocked by". The shared string catalog doesn't count: separate keys merge cleanly.
- Each ticket goes through the same steps:
  1. The coder reports. Opus reads the check record for the reported head.
  2. Opus spawns a `reviewer` on that branch and, while it reads, reads the diff itself.
  3. Findings go back to the same coder by message, which resumes it with its context. The reviewer's findings are already on the ticket.
  4. When nothing is open, Opus merges the branch into the integration branch, makes any trivial fixes, and pushes.
  5. Tickets that were blocked on this one start.
- GitHub holds everything that matters: coders push their branch, and the reviewer posts its findings as a comment on the ticket. A replacement agent is briefed from the branch and those comments.
- When every ticket is merged:
  1. Opus runs `scripts/check.sh` on the integration branch itself.
  2. Opus runs the closing review.
  3. Opus opens a pull request to `main` that closes the tickets, with the body from the `pr` skill.
  4. After the merge, Opus removes the coders' worktrees and deletes the ticket branches and the integration branch. A worktree the harness still holds a lock on is left for it to clear.

**Adversarial pass.**

- Run the `adversary` subagent on a ticket breakdown before delegating work that spans two or more tickets, after `/to-tickets` publishes and before the first coder starts. It is the most expensive single step and the one that pays most: a wrong ticket costs a coder, a review and a round trip.
- Run it on a ticket's branch, before the review, when the branch changes what is written: what the owner of a mirrored session applies or sends, a SwiftData model or migration, backup, import or delete-all, or what is saved to Health. A branch that only reads or presents those doesn't need it.
- Give it the tickets or the branch, the spec, and a path outside the repo for its report. Keep your own conclusions and the reviewer's pass out of the brief, so its read isn't anchored on them.
- A finding counts when it comes with a scenario that reproduces it. Opus decides each one: fix the breakdown, send it to the coder, or set it aside with the reason on the ticket. A product question it raises goes to the user.

**Review.**

- Every ticket's branch gets two reads before it is merged:
  - the `reviewer`'s first pass, against the ticket's acceptance criteria, `CODING_STANDARDS.md` and the glossary;
  - Opus's own read of the diff, for what the ticket and its parent meant, the ADRs, and the verdict.
  The first pass may be skipped for a ticket merged straight before the closing review.
- The checks are part of the review. There is no hosted CI, so `scripts/check.sh` is the gate: SwiftLint, swift-format, every package's tests, and an unsigned build of all three apps. It records the result against the commit, in the repository's git directory where every worktree can read it. Before merging a branch, Opus reads the record for its current head with `scripts/check.sh --show <commit>`; anything other than `RESULT: PASS` goes back to the coder, or to a shepherd to run. A report with no passing record for the head doesn't count.
- A change to prompts, schemas, or the exercise library also needs `scripts/eval-intelligence.sh`, which Opus runs itself; it calls the on-device model and isn't part of `scripts/check.sh`.
- The **closing review** is the `code-review` skill, once, against `main`, over everything about to be merged. Its job is what a per-ticket read can't see: one ticket undoing another, a string lost in a merge, a criterion met on its branch and missing from the result.
- What no test or screenshot covered is listed for the user as things to check on a device, on the pull request and on the parent issue. Nothing is reported as working that nobody saw or heard.
- Opus reports the result to the user.
