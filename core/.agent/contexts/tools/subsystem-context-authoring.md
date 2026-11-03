# Authoring a Subsystem Context (`subsystem-context-authoring`)

How to write a deep, code-anchored context **area** for a non-trivial subsystem — the kind that spans
multiple packages or modules, has more than one execution path, and carries invariants you cannot
guess from names alone.

This covers **what goes in** such a context and **how to derive it from source**. The mechanics —
two-tier index layout, `Covers:` and reference format, when changes happen — live in
[context-updater.md](context-updater.md) and are not repeated here. Follow both.

## When a subsystem deserves this treatment

Write a full area (index + leaf docs) when at least one is true:

- The subsystem spans **multiple packages, modules or threads** (e.g. a library + a worker + a shared
  util).
- It has **two or more paths that look the same but behave differently** (e.g. an interactive path
  vs a batch path), so "fixed it in one" silently breaks the other.
- Correctness depends on **non-obvious invariants** (units, axes, ordering, formats) that are easy to
  violate.
- **Other code relies on it** in ways its own source does not show — consumers, load expectations,
  timing.

If it is one file with one path and no surprises, a single leaf doc (or a doc-unit doc) is enough —
don't over-build.

## Process — derive, never invent

1. **Map the real module boundaries first.** List every file in the subsystem (`git ls-files | grep -i
   <topic>`), then group by *actual responsibility / thread / path*, not by how you wish it were
   organized. The context structure must mirror the code structure.
2. **Find the one governing fact.** The single architectural truth that explains why the layout is
   what it is — e.g. *"path A and path B are two separate implementations with almost no shared
   code."* Lead the area index with it and let it drive how you split docs and route tasks.
3. **Distill from source + JSDoc, not from memory.** Open each file. Lift the invariants, units,
   ordering rules and failure modes directly from the implementation and its JSDoc. **Verify every
   reference before writing.** Flag anything you couldn't confirm.
4. **Validate comments against code.** A comment is a claim, not a fact. Where a comment and the
   code disagree, do not pick one — record the disagreement and follow
   [evidence-conflicts.md](evidence-conflicts.md). A comment that explains *why* and agrees with the
   code is evidence for a reconstructed decision ([bootstrap.md](bootstrap.md)).
5. **Find the consumers.** For each public entry point, search its callers (`git grep -n <symbol>`).
   What they assume — ordering, units, latency, error behaviour, load — is the subsystem's
   **operational contract**, and it goes in the doc. This is what tells a later task what it can
   break.
6. **Split into leaf docs along the boundaries.** One leaf per path/concern, each self-contained: a
   reader debugging path B should never need the path-A doc.
7. **Write the area index as a router.** Its job is to get the reader to the *one* doc they need.
8. **Run `.agent/bin/check-contexts`.** A new area starts with zero findings.

## Area index blueprint (the router)

- **`Covers:` line** — the union of the area's code.
- **The governing fact**, up top, usually as a side-by-side comparison table of the divergent paths.
- **Docs list** — one line each: what's inside / when to load it.
- **Route-by-task table** — "if the task is about X → load doc Y." The highest-value section; write
  it from real symptoms ("output missing in path B", "drift during path A"), not feature names.
- **Code map** — entry-point files per path, so a reader can jump straight into source.
- **Affects / relied on by** — what changing this subsystem can break: consumers, shared contracts,
  ADR topics that govern it (link `docs/adr/<topic>.md`).
- **Shared invariants** — facts true across every path (units, formats, which path skips what).
- **Divergence checklist** — when path A ≠ path B, the ordered list of suspects.
- **Maintenance note** — authored against current source with checked refs; refresh when the
  subsystem changes (`check-contexts` flags it).

## Leaf doc blueprint

- **Title, then `Covers:`.**
- **One-line summary** stating the path's defining choice (e.g. "one native resource per object, no
  shared graph").
- **Pipeline / core model** — the end-to-end flow or the central math, read-this-first.
- **Files** — per file: path, the class/role, then the key methods as checked references with a
  one-line behavior each. This is the bulk.
- **Consumers & expectations** — who calls in, and what each one relies on.
- **Units** — every quantity tagged with its unit and axis (ms vs seconds, output timeline vs source
  timeline, 0–1 vs dB). Units bugs are the most common and the cheapest to prevent here.
- **Gotchas / risk areas** — the traps: drift, silent drops, rounding at boundaries, leaks,
  path-only behaviors.

Keep it dense and LLM-optimized: no marketing, no "this enables", no restating the obvious.

## Hard rules

- **Structure follows code.** If the docs and the module boundaries disagree, one of them is wrong —
  usually the docs.
- **Every reference is checked at authoring time** and anchored on a symbol name.
- **Tag every unit and axis.** Never write a bare number.
- **Capture cross-path divergence explicitly** — the divergence checklist is what stops a one-path
  fix from breaking the other path.
- **Flag uncertainty, don't paper over it.** "Couldn't confirm X" is more useful than a confident
  guess.
- **Register and don't duplicate** — add the area to the root `index.md` and `AGENTS.md`'s area
  table; indexes point, they never copy.
