# Concurrent Work Across Worktrees (`concurrent-work`)

Agents run tasks in parallel, one git worktree per task. Worktrees isolate files; they do not stop two
tasks from making incompatible decisions about shared code. This protocol makes each task's footprint
visible to the others and decides when an overlap needs the human.

## The footprint

Every task with a record declares `Affects:` in its header — path globs in backticks, then the
contracts or behaviours it changes ([task-progression-document.md](task-progression-document.md)).
A heavy step carries the same line while Draft. Keep it current; it is what the others plan against.

## The check — `.agent/bin/worktree-overlap`

Run it after writing the plan (before the first edit to shared code), whenever the plan's footprint
grows, and at landing ([landing.md](landing.md), step 3). For every other worktree it prints the
branch, its `Goal:`/`Now:`/`Affects:`, and two kinds of overlap with this task:

- **files** — files changed in both worktrees (committed since the merge base, staged, unstaged or
  untracked);
- **declared** — files one task changed or declared that fall inside the other's `Affects:` globs.

The session-start hook lists the other active tasks on every prompt, so their existence is never a
surprise; the script is what compares them.

## Assessing an overlap

An overlap is **potential** until assessed. Overlapping files do not mean incompatible tasks.

| Kind | Question | Confirmed when |
| --- | --- | --- |
| **File-level** | will the two diffs conflict textually? | both edit the same region, or one moves/renames what the other edits |
| **Architectural** | do they make incompatible decisions about a shared component? | different contracts, data shapes, ownership or lifecycles for the same thing — compare their `Affects:` prose and ADR steps |
| **Behavioural** | does one invalidate what the other assumes? | one changes behaviour (ordering, units, timing, errors) the other's code or tests rely on |

Read the other task's record and diff to decide; never edit another worktree's files or record.
A worktree whose branch has already merged is a leftover, not a task in flight: say so to the user
rather than assessing it ([landing.md](landing.md), "After merge").

## Acting on it

- **Not confirmed** → one line in this task's record (`Live`: "overlap with <branch> on <path> —
  disjoint regions"); continue.
- **Confirmed** → a decision request ([human-decisions.md](human-decisions.md)). Typical options:
  sequence the tasks (one lands first, the other rebases); extract the shared change into its own
  task both depend on; agree a contract now and record it (an ADR step if it is hard to reverse);
  narrow this task's footprint.
- Whatever is decided is written into **both** records' `Live` sections by the agent that owns each
  — this agent writes its own and includes the note for the other in the report.
