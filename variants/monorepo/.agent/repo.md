# Repo profile — monorepo

The single source for every path, command and boundary rule the protocols under
`.agent/contexts/tools/` refer to. Protocols say "the regressions spec" or "the verify gate"; this
file says where and what. Keep it factual and current; it is edited like any other context
(`tools/context-updater.md`).

<!-- setup: replace every <placeholder>. Derive each value from the repo (package.json scripts,
workspace config, CI, git hooks), never from memory — tools/bootstrap.md, step 1. -->

## Shape

- **Shape:** monorepo. Workspace tooling: `<pnpm + lerna / npm workspaces + turbo / nx / …>`.
- **Workspace globs:** `<packages/* , apps/* , …>` (from `<pnpm-workspace.yaml / package.json#workspaces>`).
- **Package scope:** `<@scope>/` — packages are referenced by npm name, not directory.
- **Default branch:** `<main>`. Scripts auto-detect `origin/HEAD`; `AGENT_BASE=<ref>` overrides.

## Doc units

A **doc unit** is each workspace package. Every package converges on the scaffold in
`tools/documentation-maintenance.md`:

| What | Where |
| --- | --- |
| Package docs | `<package>/README.md`, `<package>/docs/` |
| Cross-package ADRs | `docs/adr/` (topic docs) + `docs/adr/history/` (steps) |
| Package-local ADRs | `<package>/docs/adr/` (same shape; adopts `history/` once it has a thread) |
| Monorepo-wide architecture notes | `docs/architecture/` |

## Tests

| Tier | Runner | Root command | One package |
| --- | --- | --- | --- |
| fast | `<vitest>` | `<pnpm test:unit>` | `<pnpm --filter <pkg> test:unit>` |
| slow | `<Playwright>` | `<pnpm test:e2e>` | `<pnpm --filter <pkg> test:e2e>` |

- **The real runtime** (what earns a claim the slow tier): `<a real browser / database / network / real time>`.
- **Known-issues spec** (open defects, expected failures): `<package>/tests/e2e/known-issues.spec.ts`.
- **Regressions spec** (fixed defects, slow tier): `<package>/tests/e2e/regressions.spec.ts`.
  Fast-tier regressions stay beside their subject.
- **Test machinery docs** (runner projects, helpers, fixtures, goldens): `tests/README.md`.

## Commands

| Purpose | Command |
| --- | --- |
| Verify gate (read-only: compile, lint, format) | `<pnpm verify>` |
| Its mutating twin | `<pnpm verify:fix>` |
| Verify one package | `<pnpm --filter <pkg> verify>` |
| Build (and order) | `<pnpm build — tiers: shared → libs → apps>` |
| Stack merge (every PR in a stack, top-down) | `merge commit` (recommended) — or `squash` / `rebase` if the repo host disallows merge commits (`tools/pr-stacks.md`, "Merge method") |
| Release | `<lerna publish …>` — **human-only**; agents never run it |

## Boundaries

- **Cross-package imports use the workspace scope** (`<@scope>/<pkg>`), never a relative path that
  climbs into another package.
- **Within a package, relative imports.**
- **Import only a package's public barrel**, never its internal files.
- Shared types and shared logic live in their shared packages (`<@scope>/shared-…>`); new shared code
  goes there, not duplicated locally.
- Workspace deps are declared `"workspace:*"`; don't add a dependency a package already gets from a
  shared package.
