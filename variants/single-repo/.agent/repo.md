# Repo profile — single repo

The single source for every path, command and boundary rule the protocols under
`.agent/contexts/tools/` refer to. Protocols say "the regressions spec" or "the verify gate"; this
file says where and what. Keep it factual and current; it is edited like any other context
(`tools/context-updater.md`).

<!-- setup: replace every <placeholder>. Derive each value from the repo (package.json scripts or
the language's build file, CI, git hooks), never from memory — tools/bootstrap.md, step 1. -->

## Shape

- **Shape:** single repo, one deployable/publishable unit. Toolchain: `<npm / pnpm / yarn / …>`.
- **Source root:** `<src/>`. Top-level modules: `<src/<module>/ — one folder per feature or layer>`.
- **Default branch:** `<main>`. Scripts auto-detect `origin/HEAD`; `AGENT_BASE=<ref>` overrides.

## Doc units

There is one **doc unit**: the repo itself. It follows the scaffold in
`tools/documentation-maintenance.md` at the root:

| What | Where |
| --- | --- |
| Product docs | `README.md`, `docs/` |
| ADRs | `docs/adr/` (topic docs) + `docs/adr/history/` (steps) |

## Tests

| Tier | Runner | Command |
| --- | --- | --- |
| fast | `<vitest>` | `<npm run test:unit>` |
| slow | `<Playwright>` | `<npm run test:e2e>` |

- **The real runtime** (what earns a claim the slow tier): `<a real browser / database / network / real time>`.
- **Known-issues spec** (open defects, expected failures): `tests/e2e/known-issues.spec.ts`.
- **Regressions spec** (fixed defects, slow tier): `tests/e2e/regressions.spec.ts`.
  Fast-tier regressions stay beside their subject.
- **Test machinery docs** (runner config, helpers, fixtures, goldens): `tests/README.md`.

## Commands

| Purpose | Command |
| --- | --- |
| Verify gate (read-only: compile, lint, format) | `<npm run verify>` |
| Its mutating twin | `<npm run verify:fix>` |
| Build | `<npm run build>` |
| Stack merge (every PR in a stack, top-down) | `merge commit` (recommended) — or `squash` / `rebase` if the repo host disallows merge commits (`tools/pr-stacks.md`, "Merge method") |
| Release | `<npm publish / release script>` — **human-only**; agents never run it |

## Boundaries

<!-- setup: describe the module boundaries the code actually keeps; delete rules it doesn't. -->

- **Each top-level module exposes a public `index`**; other modules import only that, never its
  internal files.
- **Dependency direction:** `<ui → features → domain → shared>`; a lower layer never imports a
  higher one.
- **Path aliases:** `<@/ → src/>` — the only alias; no relative paths climbing out of a module.
- Shared types and helpers live in `<src/shared/>`; new shared code goes there, not duplicated.
