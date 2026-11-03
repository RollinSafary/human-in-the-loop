# PR Stacks (`pr-stacks`)

How a task lands as a stack of PRs, how review fixes enter it, and how it merges. Load before opening
PRs for a task with more than one reviewable step, and before acting on review feedback on a stack.

## The governing rule

**Once a layer's PR is open, its branch never receives another commit.** Not a fix, not a rebase, not
a force-push. Every change after that — review fixes, follow-ups, a missed test — arrives as a **new
layer on top**. Because no lower branch ever moves, no upper branch ever needs rebasing, and the stack
can merge top-down without a single conflict.

This holds for a task that opened as a single PR too: its first review fix makes it a stack.

## Building the stack

1. **Plan the layers before the first commit.** Each layer is one reviewable step from the task
   record's Plan: small enough to review in one sitting, coherent on its own, ordered so each builds
   only on the ones below.
2. **One branch per layer**, each cut from the layer below:
   `<task>/1-<step>`, `<task>/2-<step>`, … — the first from the default branch.
3. **Open the PRs bottom-up**, each based on the layer below:
   ```sh
   gh pr create --base <task>/1-<step> --head <task>/2-<step> --title "<type>: <purpose>" --body-file <body>
   ```
4. **Every body starts with its position** — `2/4 — builds on #121` — then follows
   [commit-and-pr-authoring.md](commit-and-pr-authoring.md). The bottom PR's body also lists the whole
   stack, and is updated when a layer is added.

Opening PRs is an outside action: done when the user asked for it in this task, otherwise asked first
([human-decisions.md](human-decisions.md)).

## Review fixes — new layers

When review lands on any layer:

1. Collect the findings for this review round, across every layer they touch.
2. **Decide how to split them into layers** — the same judgement as building the stack: each fix
   layer reviewable in one sitting and coherent on its own. Small findings usually share one layer;
   a fix that changes a contract, or that reviewers of different layers will want to judge
   separately, gets its own. When the split is not obvious — or a finding is really a scope question
   — ask the user ([human-decisions.md](human-decisions.md)).
3. Each fix layer is a new top branch cut from the current top: `<task>/<n>-fix-<what>`. Each commit
   names what it corrects: `fix: <what> (review on #121)`.
4. Open its PR on top of the stack; the body is `n/N — review fixes for #121, #123` followed by one
   line per finding with a link to its review thread.
5. Reply in each review thread with a link to the fix layer, and update the bottom PR's stack list.

A lower layer's own CI may stay red for a defect a fix layer resolves; its PR thread says which layer
fixes it. The gate that counts is the **top** of the stack: gates green there means the whole stack is
green.

Follow-up work found during review (not a fix) is a new layer the same way, titled for what it does.

## Merging — the whole stack, top-down

The stack merges as one unit, only when it is complete: every layer approved, the top of the stack
green. Merging is the user's call — ask once for the whole stack:

```
Merge stack #120–#124 into main?  5 layers approved · top (#124) green · merges top-down, then #120 → main
```

On yes, merge **from the top down**, each PR into the layer below, then the bottom PR into the default
branch — every merge with the repo's method (`.agent/repo.md`, "Stack merge"):

```sh
gh pr merge 124 --merge --delete-branch   # fix layer → layer 4
gh pr merge 123 --merge --delete-branch   # layer 4 → layer 3
…
gh pr merge 120 --merge --delete-branch   # layer 1 → main
```

Top-down never conflicts — each base branch is unchanged since its PR opened — and deleting a merged
head branch is safe because nothing open is based on it any more. Never merge a layer bottom-up on its
own: a lower layer merged alone ships without the fixes stacked above it.

Once the stack is merged, clean up ([landing.md](landing.md), "After merge").

### Merge method

**Recommended: merge commits** (`--merge`). The default branch then keeps every layer and every
review-fix layer as reviewed, and `git log --first-parent` still reads as one entry per stack. The
repo host must allow merge commits, and no branch rule may require linear history.

A repo that keeps squash or rebase sets that in the repo profile, and the same top-down order works:
with `--squash`, each layer folds into the one below and the default branch gets one commit for the
whole stack — the per-layer history then lives only in the closed PRs. If a merge is refused because
the host disallows the method, stop and ask; never switch methods on your own.

## Anti-patterns

- A commit, amend or force-push on a layer whose PR is open.
- Rebasing the stack to fold a fix into the layer it belongs to.
- A fix layer that also changes behaviour nobody reviewed.
- Merging part of a stack.
- A stack whose layers are not reviewable on their own — one giant layer with fixes on top is a single
  PR in disguise.
