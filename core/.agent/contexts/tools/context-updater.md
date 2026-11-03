# Context Maintenance Protocol (`context-updater`)

Standard for creating and maintaining the saved contexts under `.agent/contexts/`. Read this
**before** adding to or changing any context doc.

## Why

Contexts are split into small, single-topic docs so a task loads only the pieces it needs. Three
rules protect that: (1) **no duplication** — indexes point, they never copy; (2) **every claim is
anchored** to code that can be re-checked; (3) **the knowledge base never changes silently or
mid-task** — every change happens when the task is complete, and the user is told exactly what
changed and why.

## Layout (two-tier index)

```
.agent/
  repo.md             # repo profile: shape, paths, commands, boundaries
  contexts/
    index.md          # ROOT navigator → lists each area folder + when to use it
    <area>/
      index.md        # AREA index → router: lists the area's docs + route-by-task
      <topic>.md      # leaf: one small, dense, self-contained topic
      <subarea>/<topic>.md
```

## Machine-checked conventions

`.agent/bin/check-contexts` reads every doc outside `tools/` and reports drift. It understands two
things, so write them exactly:

- **`Covers:` line** (every leaf and area index, right under the title): the code the doc describes,
  as backticked git pathspec globs — `` Covers: `src/render/**`, `src/shared/time.ts` ``. It decides
  whether a diff makes the doc *relevant* (its covered code changed) and flags a glob that no longer
  matches any file.
- **References:** a backticked `path:line` (or `path:start-end`), followed on the same line by the
  backticked symbol it anchors on — `` `src/render/Clock.ts:42` `Clock.tick` ``. The checker verifies
  the file exists, the line exists, and the symbol is on that line; if the symbol moved it reports
  where it is now. A reference with no symbol is reported as unanchored: line numbers drift, symbol
  names hold.

## When changes happen

**At landing — when the task is complete, before the PR opens. Never on the go.** During the task,
other work relies on the knowledge base staying stable, and the code a change would describe is still
moving. So the agent collects what it learns in the task record's `Knowledge` section, then at
landing ([landing.md](landing.md), step 4) applies every context operation in one pass:

- findings from the record's `Knowledge` section — new topics, stale or incomplete docs, docs that
  should be split, merged, renamed or removed;
- drift `check-contexts` reports on docs **relevant to this change**;
- drift on **unrelated** docs: listed for the user, who decides whether it is fixed now or left.

No operation needs approval. Every operation is **reported** to the user — see "The report" below.
The changes are committed as their own `docs:` commit, separate from product docs.

Two cases have no task to land: the user asking for docs directly ("document X", "bootstrap the
contexts", "fix the drift") — do it now and report — and the agent noticing something outside any
task — tell the user, and do it as its own small task if they want it.

## Operations

### `create`

Use when new knowledge doesn't fit an existing doc.

1. Choose the relevant area folder (or create a new one).
2. Write a new small, single-topic `.md` with its `Covers:` line. Keep it dense and self-contained;
   **verify every reference against source before writing** — don't assume.
3. Register it in that area's `index.md`: `- [<short-topic>](<relative-path>.md) — <one line: what's inside / when to load it>`
4. If you created a new area: also create `<area>/index.md` **and** add the area to the root
   `index.md` and to the area table in `AGENTS.md`.
5. **No duplication:** if info already lives in a sibling doc, link to it instead of repeating.

### `update`

Use when an existing doc is stale, wrong or incomplete. Rewrite the affected lines in current-state
voice; keep references verified; update the area `index.md` description if the doc's scope changed.
A **mechanical refresh** (drifted `file:line` refs, typos, broken links; no meaning change) is the
same operation, reported as one line per doc.

### `restructure` — delete, rename/move, split

- **Delete** (doc is obsolete/wrong): remove the file **and** its index entry; fix or drop every
  inbound link (grep the filename across `.agent/` and `AGENTS.md`).
- **Rename/move**: update the index entry and every inbound link together — never leave dangling
  pointers.
- **Split** (doc outgrew one topic): create the new leaves, shrink or delete the original, re-point
  all indexes and inbound links.

After all operations: run `.agent/bin/check-contexts` — zero findings on everything touched.

## The report

One block in the landing message, one line per operation, each with its reason:

```
Contexts
  created     render/clock.md — Clock units and consumers (found converting callers to seconds)
  updated     render/index.md — route-by-task: "frame timing drift" → clock.md
  refreshed   render/pipeline.md — 3 references (mechanical)
  split       net/index.md → net/transport.md, net/retry.md — doc covered two paths
  deleted     legacy/encoder.md — encoder removed in this change
  unrelated drift: dev/scripts.md (2 refs), net/index.md (1 ref) — fix now or leave?
```

## Quick decision

- New topic / doesn't fit any existing doc → **create**.
- Topic exists but the doc is stale/wrong/incomplete → **update**.
- Only refs/typos/links wrong, meaning unchanged → **update** (mechanical refresh).
- Doc obsolete, misplaced, or covering multiple topics → **restructure**.
- Adding an index pointer — registering a new doc, or cross-registering an existing doc in another
  area's index — is part of **create**: pointers, never content copies.

## Leaf doc authoring standards

- One topic per file; small enough to load in isolation. If it outgrows one topic, split it.
- Dense, compact — optimized as an LLM context source (no marketing, no "this enables…").
- Self-contained; repo-relative paths; references in the checked format above. Anchor on **symbol
  names + behavior** — line numbers drift; they are a convenience to refresh, not the durable
  reference.
- Say what the code **affects** and what **relies on it** — the consumers and the expectations they
  hold. That is the part a task needs to know before touching it, and the part code alone does not
  show.
- Verify against current source before writing; flag anything uncertain rather than guessing.
- Authoring a full subsystem **area**? Follow [subsystem-context-authoring.md](subsystem-context-authoring.md)
  on top of this protocol.
