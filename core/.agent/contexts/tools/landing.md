# Landing a Task (`landing`)

The ordered pipeline that turns "the code works" into "the task is done". Load it when the
implementation is complete. Every step runs, in order; a step that finds work loops back to the step
that owns it. A task with tier **none** runs steps 1, 2, 4 and 7.

## 1. Gates green

The repo's verify gate and every test tier the diff touches pass (commands: `.agent/repo.md`,
"Commands" and "Tests"). Tests ship with the change (`AGENTS.md`, working rules). Red is fixed, routed
to `ISSUES.md`, or the test is corrected with the reason in the commit — never bent
([test-authoring-standards.md](test-authoring-standards.md), #9).

## 2. Self-review in a fresh context

The implementer does not grade its own work in the context that produced it. A reviewer with **no
memory of the implementation** reviews the diff against the rubric:

- Agents with subagents: spawn the `self-reviewer` (Claude Code: `.claude/agents/self-reviewer.md`).
- Agents without: start a fresh session with the brief in
  [.agent/agents/self-reviewer.md](../../agents/self-reviewer.md).

The reviewer gets the base ref, the branch, and the task's `Goal:` line — not the reasoning, so it is
not anchored on it. It writes `.tmp/review-<branch>.md`
([code-review-standards.md](code-review-standards.md), "Review output"). The implementer fixes every
blocker and major, then reruns step 1. Nits are fixed or listed in the PR body. A finding the
implementer disagrees with goes to the user as a decision request, not silently dropped.

## 3. Concurrent-work re-check

Run `.agent/bin/worktree-overlap`. Any new overlap since the task started is assessed per
[concurrent-work.md](concurrent-work.md); a confirmed conflict is a decision request before anything
is pushed.

## 4. Contexts and known issues — applied, then reported

This is the only point in a task where `.agent/contexts/` changes
([context-updater.md](context-updater.md), "When changes happen"). No approval is needed; the user is
told what changed.

1. Run `.agent/bin/check-contexts --base <base>`. Docs **relevant to this change** get their drift
   fixed and their content read against the change (the checker proves references, not meaning).
2. Apply every create, update, delete, rename and split the record's `Knowledge` section calls for.
3. Add an `ISSUES.md` entry for each defect found and not fixed, with its expected-failure scenario
   in the known-issues spec.
4. Rerun `check-contexts` — zero findings on everything touched.
5. Report, in the format of context-updater, "The report": one line per operation with its reason,
   plus the ISSUES entries added. **Unrelated** drift is listed with a question — fix it now (its own
   `docs:` commit) or leave it.

## 5. ADR — ask, then land the step

If this task carries a heavy step in `Draft`, ask the user before landing it:

```
Land ADR NNNN — <title> as Accepted?  Comparison gate: done (Y chosen, Z viable-not-chosen, X dead)
· proven by: "<scenario>", "<scenario>" (green) · folds into: docs/adr/<topic>.md
```

On yes, land it per [task-progression-document.md](task-progression-document.md), "Landing a heavy
step". On no, the step stays `Draft` with the reason recorded in its Progress; a design that lost is
marked `Abandoned` the same way — after asking.

## 6. Route the light record

Per [task-progression-document.md](task-progression-document.md), "Landing a light record": `doing …
because` lines into the PR body; findings were applied in step 4. **Keep the record** — review fixes
re-enter this pipeline and continue it; it goes in "After merge".

## 7. Commits and PR

Before writing the commit message, ask whether the product docs need updating
([documentation-maintenance.md](documentation-maintenance.md), "When to update the docs"). Commits
follow [commit-and-pr-authoring.md](commit-and-pr-authoring.md): code commits first, then the `docs:`
commits (contexts separate from product docs). Push and open the PR, or the PR stack per
[pr-stacks.md](pr-stacks.md) — pushing and opening PRs happen when the user has asked for them in
this task or approves now. The PR body closes with the verification that ran.

**Review feedback after the PR opens** re-enters this pipeline from step 1 for the fix: on a stack it
is a new layer on top, never a commit on an open layer ([pr-stacks.md](pr-stacks.md), "Review
fixes"). The stack merges as a whole, top-down, when the user says so.

## After merge — clean up

When the PR or the whole stack has merged, the task's leftovers go, so they stop showing up as work
in flight — in the session-start hook, in `worktree-overlap`, and to the next session:

1. Delete the task's scratch: `.tmp/task-<branch>.md` and every `.tmp/review-<branch>.md`, for each
   branch of the stack (route anything still unrouted first — a record is never deleted with
   knowledge in it).
2. Leave the task's worktree, then remove it: `git worktree remove <path>` (refuses if it has
   uncommitted changes — then stop and ask; never `--force` on your own) and `git worktree prune`.
3. Delete the merged local branches: `git branch -d <branch>` for each layer (refuses unmerged work —
   stop and ask; never `-D` on your own). Remote branches went with `--delete-branch`;
   `git fetch --prune` drops their refs.
4. One line in the final report: what was cleaned up, and anything left because git refused.

A task closed without merging (abandoned, superseded) is cleaned up the same way, after asking — its
record's `Ruled out` lines are routed first, because an abandoned search is still a search.

## The report the user sees

After step 7 (or when stopping earlier), one short message: what landed, the PR link(s), the
contexts block from step 4, decisions the user made along the way, and what is deliberately left
(unrelated drift kept, ADR still Draft, ISSUES added). After merge, the cleanup line.
