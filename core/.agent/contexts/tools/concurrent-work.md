# Concurrent Work Across Worktrees (`concurrent-work`)

Agents run tasks in parallel, one git worktree per task. Worktrees isolate files; they do not stop two
tasks from making incompatible decisions about shared code. This protocol splits the problem in two:
**detection** is mechanical, automatic and quiet; **investigation** costs time and attention, so it
happens only when the user chooses it.

## The footprint

Every task with a record declares `Affects:` in its header — path globs in backticks, then the
contracts or behaviours it changes ([task-progression-document.md](task-progression-document.md)).
A heavy step carries the same line while Draft. Detection adds what the code itself shows, so a
missing or stale declaration narrows what is seen but never hides an actual change.

## Detection — automatic, informative

`.agent/bin/worktree-overlap` compares this task with every other worktree, and with the base branch
("main") once it has moved since this branch left it. Every signal is mechanical:

| Signal | Means |
| --- | --- |
| **both change** | files changed on both sides — committed, staged, unstaged or untracked |
| **declared** | files one side changed or declared in `Affects:` inside the other's declared footprint |
| **uses** | files one side changed that use a symbol the other side changed (a heuristic over the diff: declarations on, or enclosing, changed lines) |
| **merge** | files that would conflict textually if the two committed states merged (`git merge-tree`; reported as n/a on git older than 2.38) |

It runs on its own: the session-start hook asks for `--brief` on every prompt (cached — recomputed only
when a worktree, a record or the base moved), and the edit guard (`.agent/hooks/edit-guard.sh`, where
the agent supports a pre-edit hook) stops an edit to a file inside another task's footprint. Run the
full report yourself after writing the plan and at landing ([landing.md](landing.md), step 3).

What enters the conversation is one line per **undecided** collision, and nothing at all when there is
none. Detection never reads the other task's record or diff into the context.

## The user decides — ignore, quick look, full investigation

Every hit is a *possible* collision. Before work touching it continues, ask the user once, with all
current collisions in one message:

```
Possible collision with feat/y (bump version): both change src/version.ts; merge: textual conflict.
  1. Ignore             — keep going; asked again only if the overlap grows
  2. Quick look         — their goal and the overlapping changes, judged: disjoint or likely conflict
  3. Full investigation — merge both, run the tests on the combination, classify, recommend
```

No numbers about cost: the user is choosing how much certainty they want, not a budget.

### 1. Ignore

`worktree-overlap ignore <branch|main>` records it, covering the collision's files, symbol uses and
textual conflict as they are now; `--path <file>` adds a file not touched yet (the edit guard names
it). The collision stays quiet until it **grows** — a new file, a new use, or a textual conflict where
there was none. Note it in the record's `Live` section: "collision with <branch> on <files> —
ignored by the user".

### 2. Quick look

`worktree-overlap quick <branch|main>` writes `.tmp/collision-<this>-<other>.md`: their goal,
`Affects:` and `Now:` (or, for main, the commits since this branch left it) and both sides' changes
to the overlapping files. Read that file — nothing else of theirs — and answer with one verdict and a
short reason:

- **disjoint** → record it as ignored (`worktree-overlap ignore …`), tell the user, continue;
- **likely conflict** → ask again: ignore, or full investigation.

### 3. Full investigation

`worktree-overlap full <branch|main> --test "<command>"` merges the two committed states in a
throwaway worktree and runs `<command>` on the combination — the fast tier from the repo profile,
prefixed by whatever a fresh checkout needs (for example a dependency install). It writes the verdict
and the test output to the same `.tmp/collision-…` file and prints one line:

| Verdict | Meaning |
| --- | --- |
| confirmed: textual conflict | the merge itself conflicts |
| confirmed: tests pass here alone but fail on the combination | a behavioural collision, with a failing test as evidence |
| no collision found | merges cleanly and the tests pass on the combination |
| inconclusive | the tests already fail without the merge — fix that first |

Uncommitted changes are not part of the merge; the file says how many there were on each side.
Then classify what remains, using both records and the verdict:

| Kind | Confirmed when |
| --- | --- |
| **File-level** | the merge conflicts, or one side moves/renames what the other edits |
| **Architectural** | the two make different decisions about the same component — contracts, data shapes, ownership, lifecycles — compare their `Affects:` prose and ADR steps |
| **Behavioural** | one changes behaviour (ordering, units, timing, errors) the other relies on — the combined test run is the evidence |

A confirmed collision ends in a decision request ([human-decisions.md](human-decisions.md)) with the
realistic options: sequence the tasks (one lands first, the other rebases), extract the shared change
into its own task both depend on, agree a contract now (an ADR step if it is hard to reverse), or
narrow this task's footprint. "No collision found" is recorded as ignored, like a disjoint quick look.

## Keeping the context clean

- Detection output is one line per undecided collision; ignored ones stay silent.
- Quick looks and investigations write to `.tmp/collision-<this>-<other>.md`; only the verdict and the
  path enter the conversation. Open the file when the detail is needed.
- Never edit another worktree's files or record. Whatever is decided goes into this task's record,
  and the report says what the other task's owner should know.

## When nobody is there to answer

Unattended runs take the quick look automatically. On *disjoint*, continue. On *likely conflict*,
keep working locally but stop before pushing or opening a PR, and put the question first in the
report.

A worktree whose branch has already merged is a leftover, not a task in flight: say so rather than
assessing it ([landing.md](landing.md), "After merge").
