# Documentation Maintenance Protocol (`documentation-maintenance`)

How **product documentation** and **ADRs** are structured, written, and kept current. Read this
**before** writing or editing any product doc, `README` or ADR. For the `.agent/contexts/` knowledge
base, follow [context-updater.md](context-updater.md) instead — the two doc sets have different
rules; don't cross-apply them.

## Where the docs live

Docs are organised by **doc unit** — each workspace package in a monorepo, the repo itself in a
single repo. The repo profile ([.agent/repo.md](../../repo.md), "Doc units") says which applies and
gives the exact paths. Every doc unit converges on the same scaffold. **This is the target layout,
not a guarantee** — when you touch a unit's docs, create the missing piece you need from it; never
invent a different layout.

```
<doc unit>/
  README.md          # landing page: install, short usage, links into docs/
  docs/
    README.md        # documentation hub / index
    architecture.md  # system design, data flows, key design decisions
    configuration.md # every option/parameter, with usage + validation notes
    error-handling.md# error scenarios, detection, recovery, debugging
    examples.md      # progressive runnable examples (basic → production)
    adr/             # decisions local to this unit (monorepo; in a single repo this is the repo's ADRs)
```

## Architecture Decision Records — two tiers

ADRs here are written **before** implementation, so the design moves while it is being built. The
tree separates the record of that movement from the statement of what was settled.

```
docs/adr/
  README.md              how the tiers work + the Topics table (the composed record's index)
  <topic>.md             the composed record for one subject — named, never numbered
  history/
    README.md            every step, chronological, with its status
    NNNN-kebab-title.md  one decision step, as it was made
```

### `history/` is the design record

One file per decision step, numbered in a single global sequence that is **never reused and never
renumbered**. A step is written when the design is proposed and appended to as building reveals
things.

- **Mutable while in flight** — `**Status:** Draft`, with `**Branch:**` and `**Affects:**` lines.
  The design is still moving and the file moves with it.
- **Frozen when the task lands** — `**Status:** Accepted, <date>`, after the agent asks the user
  ([landing.md](landing.md), step 5). Freezing is the **last** act of landing: first carry across
  everything the task's progression record learned — the options, the measurements, what was ruled
  out and why ([task-progression-document.md](task-progression-document.md), "Landing a heavy
  step") — because after that the step is never edited: a later change is a new step, not a rewrite.
- **A step that lost during implementation** is marked `**Status:** Abandoned, <date>` with one line
  on why — also after asking. Because ADRs here precede implementation, some will lose — and an
  unmarked losing proposal is something a reader will implement from.
- **A reconstructed step** — written during bootstrap from evidence rather than at decision time —
  carries `**Provenance:** reconstructed` and an `## Evidence` section listing what it rests on
  (comments, commits, PR threads, with references). Its date is the date of the evidence, or
  `unknown`; never the day it was written. Reasons not supported by evidence are stated as unknown.

### `<topic>.md` is the composed record

It states the combined, current result of every step on its subject, in current-state voice, with
no "we first decided X" narration. It is **mutable by design**: when a step lands, it is patched with
exactly what that step changed. The README's Topics table indexes all topic docs; together they are
the composed state of the architecture.

Topic docs are **named, not numbered** — there is no sequence to renumber, and no gap to look like a
mistake. One subject per topic doc keeps each loadable on its own; a single all-in-one composed file
would grow until no task could afford to load it.

The fold is part of finishing the step, not a separate chore. A step at `Accepted` whose decision is not
yet reflected in its topic doc is outstanding work.

A topic doc ends with a **`## Ruled out`** list: one line per approach considered and not taken, as
`<approach> → <the reason, stated as a checkable fact> (<step>)`, with `revisit if <condition>` where
one is known. Reasons only — a verdict (`don't use X`) cannot be re-checked and forecloses the option
forever. This list is the **only mutable surface a frozen step's reasoning has**: when a later step
removes the reason, the line is amended or struck *here*.

### What goes where

**Reasoning stays in history; the contract stays in the topic doc.** Alternatives, measurements and
the arguments that ruled things out belong to the step that made them. A topic doc links its steps
rather than repeating them.

**Everything else links the topic doc.** Product docs, `README`s and `.agent/contexts/` cite
`docs/adr/<topic>.md`, never a history step. Cite a step only when the point *is* the reasoning
behind a choice that was later replaced.

## House style — write in current-state voice

- **Describe what the system does now**, present tense. Do **not** write "changed from…",
  "previously…", "the old approach…", or `// New:` markers in the doc body. History belongs in
  release notes/changelogs; the rationale for a hard-to-reverse choice goes in an ADR step or the
  unit's `architecture.md` "Key Design Decisions" section.
- Top of each `docs/*.md`: a `>` blockquote one-line tagline, then a back-link
  `[← Back to Documentation](./README.md)`, then a `## Table of Contents`.
- Footer of each doc: a "Related Documentation" / "Next Steps" list linking the sibling docs.
- Unit `README.md`: emoji section headers (🎯 Features, 📚 Documentation, 🚀 Installation,
  🛠 Usage, 🔧 Development, 🏗 Architecture, …); in a monorepo, a back-link to the root `README.md`.
- Diagrams: **mermaid** for flows and lifecycles; fenced ` ```text ` ASCII boxes for simple layouts;
  **tables** for matrices (support, performance, memory).
- Code: fenced blocks in the repo's language with realistic config objects; `examples.md` ordered
  basic → production-ready. Constants, formulas and units concrete and **verified against source**.
- In a monorepo, reference packages by their npm name (the workspace scope), not by directory path.

## When to update the docs

### After an approved code change (do it as a follow-up)

Once the user **approves** a change that alters documented behavior — public API, config options,
data flow, error/recovery behavior, constants/units, or a design decision — update the affected
doc(s) in that doc unit:

| Change touches…                          | Update                                              |
| ---------------------------------------- | --------------------------------------------------- |
| behavior / data flow / design decision   | `architecture.md`                                   |
| a new or changed option/parameter        | `configuration.md`                                  |
| a new failure mode or recovery path      | `error-handling.md`                                 |
| a new capability or usage pattern        | `examples.md` and/or `README.md` · `docs/README.md` |
| a hard-to-reverse architectural decision | a step in the right `history/`, folded into its topic doc once it lands |

Write the update in current-state voice; the before→after story belongs in the commit/release
notes. If the target doc doesn't exist yet, create it from the scaffold above.

### When asked for a commit message or a code review

Before producing a commit message or a code review, **ask the user whether the documentation needs
updating** for the changes in scope. If yes, update the relevant docs (per the table above) as part
of the work; if no, proceed.

## Relationship to `context-updater.md`

- **This protocol** governs product docs, `README`s and ADRs. Updating them after an approved change
  is expected, follow-up work; landing an ADR step is asked first.
- **[context-updater.md](context-updater.md)** governs `.agent/contexts/`: every operation happens
  at landing, needs no approval, and is reported to the user.
