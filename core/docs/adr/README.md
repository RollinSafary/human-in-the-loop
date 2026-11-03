# Architecture Decision Records

Architecture decisions, in two tiers. In a monorepo this directory holds cross-package decisions and
each package keeps its own `docs/adr/` in the same shape (`.agent/repo.md`, "Doc units").

**Decisions here are written before implementation**, so a design moves while it is being built. The tiers separate the record of that movement from the statement of what was settled.

| | What it is | Lifecycle |
| --- | --- | --- |
| **`<topic>.md`** | the composed record — the combined current result of every step on one subject | **mutable**; patched as each step lands |
| **[`history/`](history/)** | the design record — one file per decision step | **immutable** once its task lands |

**Read the topic docs.** Reach for `history/` when you want the reasoning, the measurements, or the alternatives that were ruled out — those stay with the step that made them, which is what keeps a topic doc readable.

## Topics

| Topic | What it settles |
| --- | --- |
| _none yet_ | |

## Adding a decision

1. **Write a step** in [`history/`](history/) as `NNNN-kebab-title.md`, taking the next number in the global sequence. Mark it `**Status:** Draft` while the task is in flight — it stays editable for as long as the design is still moving. While Draft, put `**Branch:** <git branch>` directly under the status line so the session hook can surface it.
2. **Freeze it when the task lands**, after asking the user: `**Status:** Accepted, <date>`. From then on it is never edited — a later change is a new step. If the design lost during implementation, mark it `**Status:** Abandoned, <date>` (also after asking) with one line on why, so nobody implements from a proposal that did not win.
3. **Fold it into its topic doc**, rewriting whatever it changed, in current-state voice, and add the options not chosen to the topic's `## Ruled out` list. Create a new topic if none fits. This is part of finishing the step: a step at `Accepted` that is not yet reflected in a topic doc is outstanding work.

Numbers belong to steps and are never reused or renumbered. Topic docs are **named, not numbered** — there is no sequence to renumber and no gap to look like a mistake.

Everything outside this directory — package docs, `README`s, `.agent/contexts/` — links the **topic doc**. Cite a step only when the point *is* the reasoning behind a choice that was later replaced.

Steps written during bootstrap from evidence carry `**Provenance:** reconstructed` and an `## Evidence` section; what the evidence does not state is listed as unknown, never filled in.

Full protocol: [`.agent/contexts/tools/documentation-maintenance.md`](../../.agent/contexts/tools/documentation-maintenance.md).

## Package-scoped ADRs (monorepo)

<!-- - [`<package>/docs/adr/`](../../<package>/docs/adr/) — decisions local to <package>. Delete this section in a single repo. -->
