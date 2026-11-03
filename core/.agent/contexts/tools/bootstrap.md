# Bootstrapping the Setup (`bootstrap`)

How the knowledge base and decision record come to exist. Two modes:

- **Continuous** — a new project. Contexts, ADR steps and `ISSUES.md` grow with the code from the
  first task, through the normal protocols. Nothing to reconstruct.
- **Bootstrap** — an existing codebase. The human opens a session and asks to prepare the docs. The
  agent builds everything from **verifiable evidence in the repo** and never invents history it
  cannot see.
- **Migration** — a repo that ran the original setup (`.claude/contexts/`, `CLAUDE.md` as the
  instructions file). `install.sh` asks, moves things mechanically, and leaves the judgement to the
  agent: see "Migrating from the original setup" at the end.

The rest of this doc is the bootstrap procedure. The human asking for it is the request: every
context operation below is done without approval and reported, like any context change.

## 1. Repo profile

Fill `.agent/repo.md` from the repo, not from assumptions: workspace config and globs, `package.json`
scripts (or the language's build files), CI workflows, git hooks, test runner configs. Every command
written there is one that exists. Then the setup placeholders:

```sh
git grep -n -e '<!-- setup' -e '<project-name>' -e '<One-line' -- AGENTS.md .agent docs ISSUES.md
```

## 2. Conventions, described not prescribed

Fill [code-review-standards.md](code-review-standards.md) §1, §10, §11 and
[test-authoring-standards.md](test-authoring-standards.md)'s tier table from the repo. Sample the code
for §2–§6: a rule the codebase does not follow is rewritten to what it does, or deleted. The
standards are descriptive; a rulebook the code contradicts teaches the agent to ignore it.

## 3. Map the areas

List candidate subsystems with the evidence for each (file groups, entry points, packages, the
reason it qualifies under [subsystem-context-authoring.md](subsystem-context-authoring.md), "When a
subsystem deserves this treatment"). Present the list with a suggested order (most-touched first —
`git log --since=6.months --name-only` is a fair proxy) and let the human choose what to author now.
Full areas are expensive; a large repo is bootstrapped in passes.

## 4. Author the areas

One area at a time, per [subsystem-context-authoring.md](subsystem-context-authoring.md), including
its comment validation and consumer mapping. Write `.agent/contexts/dev/scripts.md` for the command
surface. Run `.agent/bin/check-contexts` after each area: zero findings before moving on.

## 5. Conflicts found on the way

Bootstrapping reads more code against its comments and docs than any task will. Each disagreement is
handled per [evidence-conflicts.md](evidence-conflicts.md) — collected and presented together rather
than one interruption each. A confirmed defect becomes an `ISSUES.md` entry with its expected-failure
scenario.

## 6. Reconstructed decisions

The decision history before bootstrap is mostly unknown, and the record says so. A decision gets a
reconstructed ADR step only when the repo holds evidence of **what** was decided and **why** — a
comment block explaining a rejected alternative, a commit body, a linked PR or issue, an existing
design doc. Then:

```
# NNNN — <the decision, as a sentence>

**Status:** Accepted, <date of the evidence, or "unknown">
**Provenance:** reconstructed

## Context
## Decision
## Evidence
- `src/cache/LruStore.ts:12` `LruStore` — comment: "not a Map: entries must expire by size, see #214"
- commit a1b2c3d (2025-03-02) "fix: bound cache by bytes, Map grew to 2 GB in the export job"
## Unknown
- whether a TTL-based design was considered
```

What the evidence does not state is listed under `## Unknown`, never filled in. Fold each into a
topic doc as usual. A choice visible in the code with no recorded reason is described in the
subsystem context ("uses X") — it is not an ADR.

## 7. Report and commit

Report the bootstrap in one message: areas written (with their check results), the profile, the
standards changes, reconstructed steps, `ISSUES.md` entries — and, separately, the conflicts that
still need the user's decision. Commit as `docs:` commits (contexts, ADRs and product docs
separately).

## Migrating from the original setup

`install.sh --migrate` (or answering yes when it asks) has already: moved `.claude/contexts/` to
`.agent/contexts/` and rewritten links to it; retired the original process docs, `CLAUDE.md`, the old
hook and the old `.claude/settings.json` into `.tmp/migration-<timestamp>/`; installed the new files;
carried the project name and area rows into `AGENTS.md`. What is left needs judgement — the human
asking to finish it is the request, so every step is done without approval and reported:

1. **Read the leftovers** in `.tmp/migration-<timestamp>/`.
2. **Carry the filled-in rules** from the retired process docs into the new ones: code-review §1
   (gates), §10, §11 and any §2–§6 rule rewritten to match the code; the test tier table. Facts about
   the repo — paths, commands, the regressions spec, module boundaries — go to `.agent/repo.md`, not
   into the protocols.
3. **`AGENTS.md`:** the one-line project description from the old `CLAUDE.md`; check the carried area
   rows against `.agent/contexts/index.md`. Anything else project-specific the old `CLAUDE.md` said
   goes where it belongs now (repo profile, a context, or `CLAUDE.md` below the import if it is
   Claude-only).
4. **Kept files:** the installer never overwrites, so files the repo already had — `ISSUES.md`,
   `docs/adr/README.md`, `docs/adr/history/README.md`, the context indexes — were kept, and the
   template's version of each is under `.tmp/migration-<timestamp>/template/`. Bring in the
   template's text and keep the repo's own content: open `ISSUES.md` entries, the Topics and steps
   tables, the project rows in the indexes.
5. **`.claude/settings.json`:** add the old `allow` entries that are this repo's toolchain commands.
   Never move anything out of `ask` or `deny`, and drop the old hook wiring. Personal keys go to the
   user's own settings.
6. **Contexts:** add a `Covers:` line to every doc, anchor every reference on its symbol, and refresh
   the root and area index descriptions; run `.agent/bin/check-contexts` until it is clean.
7. **Leftovers:** `git grep -n -e '\.claude/contexts' -e 'CLAUDE\.md'` — every hit is either
   rewritten or deliberately Claude-specific.
8. **Report** in the context-updater format plus one line per file carried, then commit (`chore:` for
   the setup files, `docs:` for contexts). Delete `.tmp/migration-<timestamp>/` once nothing in it is
   left uncarried, and say so in the report.
