# Tools Context — index

Process protocols. They are **generic** — conventions and procedure, not knowledge of specific
code; every repo-specific path or command they mention resolves through
[../../repo.md](../../repo.md).

## Route by moment

| Moment | Load |
| --- | --- |
| Starting any task | [task-progression-document.md](task-progression-document.md) — tier decision first |
| Task will touch code another worktree may touch | [concurrent-work.md](concurrent-work.md) |
| Sources disagree about intended behaviour | [evidence-conflicts.md](evidence-conflicts.md) |
| About to ask the human anything | [human-decisions.md](human-decisions.md) |
| Writing or reviewing tests | [test-authoring-standards.md](test-authoring-standards.md) |
| Reviewing code | [code-review-standards.md](code-review-standards.md) |
| Implementation complete | [landing.md](landing.md) |
| Writing a commit or PR | [commit-and-pr-authoring.md](commit-and-pr-authoring.md) |
| Opening, fixing or merging a PR stack | [pr-stacks.md](pr-stacks.md) |
| Editing product docs or ADRs | [documentation-maintenance.md](documentation-maintenance.md) |
| Creating or editing a context | [context-updater.md](context-updater.md) |
| Documenting a whole subsystem | [subsystem-context-authoring.md](subsystem-context-authoring.md) |
| A repo with no contexts yet | [bootstrap.md](bootstrap.md) |

## Docs

- [task-progression-document.md](task-progression-document.md) — the **tier decision** (none /
  light `.tmp/task-<branch>.md` / heavy ADR step), the record shapes with the `Affects:` footprint,
  the fork-only entry rules, landing a heavy step, and routing the record at landing.
- [landing.md](landing.md) — the end-of-task pipeline: gates → fresh-context self-review → overlap
  re-check → contexts and ISSUES updated and reported → ADR step landed after asking → record
  routing → commits and PR stack.
- [human-decisions.md](human-decisions.md) — when the agent asks and when it decides, the
  decision-request format, and behaviour when nobody answers.
- [evidence-conflicts.md](evidence-conflicts.md) — historical / structural / operational truth,
  dated investigation, classification (defect, regression, evolution, drift, obsolete), reporting.
- [concurrent-work.md](concurrent-work.md) — automatic collision detection (both change, declared,
  symbol uses, merge conflicts, main moved), then the user's choice: ignore, quick look, or full
  investigation (merge + tests); keeping the context clean.
- [bootstrap.md](bootstrap.md) — continuous vs bootstrap mode; building contexts on an existing
  codebase from evidence; reconstructed ADRs with provenance.
- [context-updater.md](context-updater.md) — create / update / restructure, all applied at landing
  without approval and reported; the `Covers:` and reference formats `check-contexts` verifies.
- [subsystem-context-authoring.md](subsystem-context-authoring.md) — deriving a subsystem area from
  source: router index, leaf blueprint, consumers & expectations, comment validation.
- [documentation-maintenance.md](documentation-maintenance.md) — doc-unit scaffold, current-state
  voice, ADR tiers (history steps + composed topic docs), landing and reconstructed steps.
- [code-review-standards.md](code-review-standards.md) — the review rubric and the `.tmp/` handoff.
- [test-authoring-standards.md](test-authoring-standards.md) — tier rule, the 13 principles, house
  style.
- [commit-and-pr-authoring.md](commit-and-pr-authoring.md) — purpose-first commits and laconic PRs;
  no AI-specific language or co-authoring metadata.
- [pr-stacks.md](pr-stacks.md) — one branch and PR per reviewable step; an open layer never gets
  another commit, so review fixes are new layers on top; the stack merges as a whole, top-down.
