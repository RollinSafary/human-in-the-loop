# Task Progression Document (`task-progression-document`)

How a non-trivial task keeps a running record of its own reasoning — the plan, the footprint, the
options, what was tried, what was ruled out and why, and where the work stands — so that a
compaction, a new session, a parallel task in another worktree, or a change request a month later
resumes from the record instead of re-walking the search. Read this **before** starting any task; the
first section decides whether the task gets a record at all.

## Why

A context window forgets, and git remembers only what was kept, never what was tried. The expensive
artifact of a hard task is the search: the approach that died on a constraint three steps away, the
option that worked but lost on memory. None of that is recoverable from the code. This record keeps
it, at one line per closed fork, and routes it somewhere permanent when the task lands.

What compaction is allowed to lose is the opposite half: tool output, narration, and progress along
the chosen path. **The failed paths are the part that is kept** — `Ruled out` is permanent — because
they are what a fresh session would otherwise walk again.

## Tier decision — at the start, re-checked at the first closed fork

Answer in order; the first **yes** decides.

1. **Does the task decide something whose reversal would cost more than the task itself?** A
   cross-unit contract; a system-level property — what the system can do, its performance envelope,
   its memory footprint, what it ships; or a choice between two or more credible approaches that
   differ on a non-functional axis (performance, memory, scalability). → **Heavy**: the record is an
   ADR history step.
2. **Will the task outlive one context window, is the search itself the expensive artifact, or will
   it run beside other tasks in other worktrees?** More than one session, or large enough to
   compact; a hunt where an approach is expected to be rejected on evidence (debugging, an unknown
   platform behaviour); concurrent work that needs its footprint visible; or the human asked for a
   plan. → **Light**: the record is `.tmp/task-<branch>.md`.
3. Otherwise → **None.** A one-file fix, added tests, a mechanical refactor: the diff and the commit
   message are the record, and none costs nothing.

**Re-check at the first closed fork.** A light record that grows a second credible option differing
on a non-functional axis was mis-tiered: open the step, carry the ledger across as its Options,
delete the `.tmp/` file. The reverse does not happen — a heavy step whose options collapse to one is
still a decision, and stays a step.

`<branch>` is the git branch with `/` replaced by `-` — the same key the review handoff uses
(`.tmp/review-<branch>.md`). `.tmp/*` is git-ignored except `.tmp/.gitkeep`; a light record is never
committed. Each git worktree has its own `.tmp/`, so each task's record lives in the worktree that
runs it; `.agent/bin/worktree-overlap` reads the others' ([concurrent-work.md](concurrent-work.md)).
A record lives until the task's PR (or stack) merges, and is deleted in the cleanup after merge
([landing.md](landing.md), "After merge") — a stale record shows a finished task as still in flight.

## Rules common to both tiers

- **An entry exists only when a fork closes.** An approach abandoned, a hypothesis killed by a
  measurement, a constraint discovered. Progress along a chosen path is not an entry — git has it.
  This one rule is what keeps the record short; "summarize progress" does not.
- **No entry without an observation.** `tried: X → <what was seen, with the run or measurement>`,
  never `<what was expected>`. A prediction is not a finding.
- **Reasons, not verdicts.** `→ the sandboxed build has no filesystem access` can be re-checked with
  a grep; `don't use the file cache` cannot, and forecloses an option forever. A stale falsification
  is worse than none — it steers with the authority of a record.
- **Supersede, never delete.** A later entry that reverses an earlier one strikes the earlier line
  (`~~…~~`) and says what changed. "Tried Y, came back to X" is the loop the record exists to stop
  repeating.
- **Read first, after any gap.** A new session or a post-compaction turn reads the record before
  touching code, and continues it rather than starting over. The session-start hook
  (`.agent/hooks/context-first.sh`) surfaces the record for the current branch; where no hook is
  wired, running it is the session's first act (`AGENTS.md`, "Session start").
- **Declare the footprint.** `Affects:` is written as soon as the plan exists and kept current: the
  path globs the task will change, plus any contract or behaviour other code relies on. It is what
  concurrent tasks and the drift report read.
- **Laconic.** No restating the task, no tool output, no narrative. The reader has none of this
  conversation and needs to act in one read.

## Light tier — `.tmp/task-<branch>.md`

```
Goal:    <the deliverable, one line>
Affects: `src/store/**`, `src/api/client.ts` — contract: batch write returns per-record status
Now:     step 3 — batch the writes
Open:    does the store accept a partial batch on timeout?

## Plan
1. ~~paged fetch~~ → landed: fetch yields pages, not the full result
2. ~~record mapping~~ → landed
3. batch writes  ← current
4. measure the retry overhead

## Live (step 3)
- tried: one write per record → 40 s for 10k records (run 3)
- doing: batches of 500, because the store caps a request at 1 MB
- costs: a failed batch retries 500 records; measure against step 4

## Ruled out
- (1) fetch everything, then write → 4× peak memory on the large fixture (measured 1.9 GB)
- (2) mapping inside the fetcher → callers already map; would double-convert

## Landed
- 1. fetch yields pages; later steps must not assume the full result
- 2. landed

## Knowledge
- (finding for a context) the store client retries 429s internally — callers must not wrap it
- (defect, not fixed) export drops the last page when the count is a multiple of 500
```

- **Header** — four lines, kept current. This is the part a re-primed session acts on, and `Now:` is
  the first line it trusts. `Affects:` holds backticked path globs (git pathspec glob syntax, `**`
  crosses directories) followed by prose for contracts and behaviours; the scripts read the globs.
- **Plan** — the split of the task into steps, one line each, status inline. On a long task this
  section *is* the decomposition.
- **Live** — entries for the current step only, as `tried / doing / costs`. Soft cap ≈ 40 lines.
  Hitting it is a **signal, not a limit**, with exactly two readings: noise (tighten back to the fork
  rule) or a step too big (split it in Plan and collapse what is already settled).
- **Ruled out** — permanent, never collapsed, one line per falsification, tagged with its step and
  carrying its reason. This is the half that is recoverable from nothing.
- **Landed** — the collapsed half: one line per finished step keeping **only what constrains later
  steps**. Everything else drops; git has it. A step that constrains nothing is `landed`.
- **Knowledge** — what `.agent/contexts/` and `ISSUES.md` should gain at landing: findings about how
  a subsystem behaves, docs this task proved stale or wrongly split, defects found and not fixed.
  Collected here and applied at landing, never mid-task ([landing.md](landing.md), step 4).

**A step lands** when its change is complete and its tests are green — the repo's definition of done
(`AGENTS.md`, working rules). At that moment its Live entries collapse: the falsifications go to
Ruled out, the constraint to Landed.

**A step un-lands** when work returns to it — a fix, a change request. It moves back to Live with its
Ruled out lines as context, Plan marks it current again, and it re-collapses when green. A task is
not linear, and a record that pretends it is will lie to the next session about where the work
stands.

## Heavy tier — an ADR history step

The record **is** the step: `docs/adr/history/NNNN-<kebab-title>.md` for a cross-unit decision, or
the doc unit's own `docs/adr/` for a local one (paths: `.agent/repo.md`, "Doc units"). It is opened
as `**Status:** Draft` before implementation — which is what the ADR protocol already asks for
([documentation-maintenance.md](documentation-maintenance.md), "`history/` is the design record") —
appended to as building reveals things, and frozen at landing. One artifact, committed, no
transcription. There is no `.tmp/` file.

Directly under the status line, while Draft, the step carries `**Branch:** <git branch>` — verbatim,
not the slug — so the hook can find it, and `**Affects:**` with the same shape as the light header.

While Draft, the step has these sections in addition to its Context and Decision:

```
## Criteria
Ranked before anything is tried: correctness → peak memory → latency.

## Options

### X — write-through on the request path — dead
The store rejects concurrent writes to one key (run 3). Functional; never revisit.

### Y — queue + single writer — chosen
240 ms p95, 180 MB peak.

### Z — sharded writers — viable, not chosen
Spiked on `spike/z-sharded-writers` (pushed, not merged). 210 ms p95, 340 MB peak.
Loses on criterion 2 only. Revisit if the memory budget rises above 512 MB.

## Progress
<the light tier's header, Plan, Live, Landed and Knowledge — same shape>
```

- **Criteria are ranked before any option is tried.** Otherwise the winner defines the criteria
  retroactively.
- **Every option is enumerated up front**, whether or not it is ever built. "Considered Z and set it
  aside" is a different fact from "never thought of Z", and only the record can tell them apart.
- **Three states, not two.** *Dead* — a functional failure, crossed off. *Chosen*. *Viable, not
  chosen* — it works and lost a ranked comparison; it carries the numbers and a `Revisit if
  <condition>` line. Collapsing the last two states into "ruled out" is how a viable option gets
  buried forever.
- **A working option does not end the search.** When one passes, every remaining viable option is
  validated against it on the ranked criteria — a reasoned estimate at minimum, a spike wherever the
  axis is measurable. This is the step time pressure skips, so it is a **gate before landing**, not
  an intention.
- **Product questions count.** A step is not ready to land while a product question it raised is
  open; list them under `Open:` in Progress until the human answers.
- **A spike is a branch, pushed and named in the step.** Re-deriving a measurement is cheap;
  re-writing the spike is not.

**Landing a heavy step**, in order — after asking the user ([landing.md](landing.md), step 5):

1. The comparison gate above.
2. `## Progress` is deleted — its falsifications are already in `## Options`, its Landed constraints
   move into `## Decision`, and its Knowledge lines were applied at landing.
3. `**Status:** Accepted, <date>`. Freezing is the **last** act of landing, never the first.
4. Fold into the topic doc, including one line per option not chosen in the topic's `## Ruled out`
   list — `<approach> → <reason> (<step>)`, with `revisit if …` where one is known. That list is the
   only mutable surface a frozen step's reasoning has; see
   [documentation-maintenance.md](documentation-maintenance.md), "`<topic>.md` is the composed record".

A design that lost is `**Status:** Abandoned, <date>` with the reason — also after asking.

## Landing a light record — route it; never delete it with knowledge still in it

| Content | Destination |
| --- | --- |
| The `doing … because` lines | the PR body's solution bullets — already the *because-of-X-we-do-Y* form ([commit-and-pr-authoring.md](commit-and-pr-authoring.md)) |
| A finding about how a subsystem behaves | a context operation at landing, in current-state voice, reported to the user ([context-updater.md](context-updater.md)) — a rewrite, not a move |
| A defect found and not fixed | an [ISSUES.md](../../../ISSUES.md) entry with its expected-failure scenario |
| A falsification that turns out to be architectural | it earned a heavy step after all — open one, `Accepted` at once (after asking the user), with the ledger as its Options |
| Everything else | dies with the branch; git holds the change |

The test for the second row: **would the sentence be true on a branch that never existed?** If it is
only true about this change, it is history, not knowledge.

## Anti-patterns

- A record written and never re-read.
- A record (or worktree) left behind after its task merged.
- Entries on progress ("implemented the batch writer"). Not a fork, not an entry.
- Predictions as findings ("this should fix it").
- Verdicts without reasons.
- Collapsing Ruled out. Landed collapses; Ruled out never does.
- An `Affects:` line that is missing or stale — concurrent tasks plan against it.
- Opening a record for a one-file fix. The tier decision says none.
- A stale `Now:` line.
