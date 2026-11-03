# Code Review Standards (`code-review-standards`)

The rubric a reviewer (human or agent) applies to a diff in this repo. Read this **before**
reviewing code here. Rules are **descriptive of the current codebase**, not aspirational. When a
rule and the code disagree, the code is probably right: update this doc via
[context-updater.md](context-updater.md) (at landing, reported) rather than enforcing a divergent style.

<!-- setup: fill in §1, §10 and §11 from this repo; rewrite any rule in §2–§8 the code does not
follow, so the doc stays descriptive. -->

Organized from "blocks merge" (automated gates) down to "judgement calls". For the documentation
side of a review (does this change need doc updates), pair this with
[documentation-maintenance.md](documentation-maintenance.md).

---

## 0. Quick review checklist

Use this as the pass/fail summary; each item links to a section below.

- [ ] **Gates green** — the repo's verify gate passes, and the test tiers the diff touches are green (§1)
- [ ] **Tests ship with the change** — a feature carries its slow-tier scenario, a bug fix its
      reproduction (`AGENTS.md` working rule; rubric: [test-authoring-standards.md](test-authoring-standards.md))
- [ ] **No `any`** — use generics, `unknown`, or a precise type (§3)
- [ ] **Naming** — per §2
- [ ] **Types modeled correctly** — interface vs type alias per §3; discriminated unions get
      `is*` guards and exhaustive `switch`
- [ ] **Encapsulation** — private state behind `private`; read-only state exposed via getters /
      `readonly` props, not public fields (§4)
- [ ] **Async safety** — `async/await`, in-flight promises cached/guarded, resources released (§5)
- [ ] **Errors** — structured across boundaries, logged via the shared logger, thrown only when
      unrecoverable (§5)
- [ ] **Boundaries** — imports respect the boundaries in the repo profile; no reaching into
      another package's or module's internals (§7)
- [ ] **JSDoc** — on public classes/methods/types; units, ranges and ownership on `@param`/`@returns` (§8)
- [ ] **Comments** — inline `//` explains _why_, in a line or two rather than a wall (§8)
- [ ] **Docs** — the doc unit's docs updated for behavior changes (§9)
- [ ] **Knowledge** — contexts whose `Covers:` match the diff are named for the drift report
      (`landing.md`, step 4); no context changed before landing
- [ ] **Handoff written** — confirmed findings saved to `.tmp/` as a compacted, fix-ready context (see "Review output")

---

## Review output: the `.tmp/` handoff file

After a review, write the result to a markdown file in `.tmp/` (git-ignored scratch — only
`.tmp/.gitkeep` is tracked, so handoffs are never committed). The file is a **compacted, fix-ready
context**: enough for a _fresh_ session — one with none of this review's conversation — to fix every
issue without re-reviewing.

- **Name:** `.tmp/review-<branch-or-topic>.md` (branch with `/` replaced by `-`).
- **Audience:** a new session whose only job is to apply the fixes. Write for that reader, not for a
  human skimming the PR.

**Include — everything the fixer needs:**

- A scope line: branch / commit range / files reviewed, plus the gate status (§1).
- One entry per **confirmed** finding, ordered by severity (blocker → nit). For each:
  `file:line`, a one-line statement of what's wrong, the rule it breaks (cite the `§`/rule from this
  doc), and a concrete **fix direction** — not just "this is wrong".
- Cross-file or ordering constraints between fixes (do A before B; this interface change ripples to
  N implementers/call-sites).
- How to verify: the gate(s) to re-run and any package-specific check.

**Drop — compaction, keep it fix-focused:**

- Anything that **passed**, or areas confirmed clean — the fixer doesn't need a clean bill of health.
- Lookups/investigation that led nowhere or only served to _reach_ a verdict.
- Re-statements of the full rubric, long code quotes, or file dumps the fixer can just reopen at the
  cited `file:line`.
- Praise, narrative summaries, and "considered but not needed" notes.

Rule of thumb: if a detail isn't needed to _make a fix_, leave it out. The handoff is a punch list,
not a review transcript.

**Skeleton:**

```md
# Review handoff — <topic>

Scope: <branch> @ <commit>; files: <list>. Gates: <pass/fail + which failed>.

## Findings (fix these)

1. [blocker] <file>:<line> — <what's wrong>. Breaks §<n> <rule>. Fix: <direction>.
2. [major] <file>:<line> — …
3. [nit] <file>:<line> — …

## Constraints / order

- <e.g. finding #2 changes an interface — update its implementers before re-compiling>

## Verify

- <scoped verify command from the repo profile>
- <the test tiers the diff touches>
```

---

## 1. Automated quality gates (non-negotiable, blocks merge)

<!-- setup: fill in from the repo's package.json scripts, lint/format config and git hooks. -->

The verify gate (command: repo profile, "Commands") = **`<compile && lint && format>`**; in a
monorepo it runs per package and the root runs it across the workspace. The test suite is separate: <root test command(s) and what each tier runs>. Git hooks:
<which hooks run what — and, just as important, which gates they do **not** run>. Run the suite
tiers the diff touches yourself as part of any review. Never approve a diff that breaks any of these:

| Gate           | Command                     | Rule                              |
| -------------- | --------------------------- | --------------------------------- |
| **Type-check** | `<tsc --build>`             | `<strict: true>`; compiles clean. |
| **Lint**       | `<eslint . --max-warnings 0>` | <zero warnings tolerated>       |
| **Format**     | `<prettier --check>`        | Must already be formatted.        |

Lint rules with teeth: <list the rules that are errors, and any deliberate overrides with the reason>.
Formatting is owned by the formatter — reviewers do not nitpick it by hand.

---

## 2. Naming conventions

| Kind                                 | Convention                         |
| ------------------------------------ | ---------------------------------- |
| Interface                            | `I<Name>`                          |
| Type alias                           | `T<Name>`                          |
| Enum (all enums)                     | `E<Name>`                          |
| Class                                | `PascalCase`                       |
| Method / function                    | `camelCase`                        |
| File-level constant                  | `UPPER_SNAKE_CASE`                 |
| Type guard                           | `is*` predicate returning `x is T` |
| Private field                        | plain `camelCase` (no underscore)  |
| Private _backing_ field for a getter | `_camelCase` ↔ `get camelCase()`   |

The `_` prefix is reserved for the private storage behind a public getter of the same name, and for
deliberately-unused bindings. If the `I`/`T`/`E` prefixes are lint-enforced (`naming-convention`),
say so here — a missing prefix then blocks merge, not just review.

**Files & folders:** class module → `PascalCase` folder and file; domain / utility / config module →
lowercase or `kebab-case`; every directory with more than one file has an `index.ts` barrel.

---

## 3. Type system

- **`any` is banned.** Reach for generics or `unknown` and narrow.
- **Interface vs type alias — by intent:** `interface` for object/contract shapes, especially
  anything `implements`/`extends`ed; `type` for unions, intersections, tuples, function signatures.
- **Compose small interfaces upward** rather than writing wide ones; reuse shared base shapes from
  the shared types package instead of duplicating fields.
- **Discriminated unions get an exhaustive `switch`** with a `never` default:
  ```ts
  default: {
    const _exhaustive: never = obj.kind;
    throw new Error(`Unhandled kind: ${_exhaustive}`);
  }
  ```
- **Runtime narrowing goes through an `is*` type guard**, not inline `as` casts.

---

## 4. Classes, OOP & encapsulation

- **Member order:** statics → instance properties (`public` → `protected` → `private`) →
  constructor → public, protected, private methods.
- Explicit `private` / `protected` / `public`; `readonly` for fields set once.
- **Expose read-only state through getters, not public mutable fields.**
- Keep methods small and single-responsibility; a longer one must be one cohesive algorithm with
  inline comments on its steps.
- **Dependency injection is constructor-based** — pass collaborators in; no globals or service
  locators. Match the existing Singleton/Factory/Manager shapes exactly rather than inventing new ones.

---

## 5. Async & error handling

- **`async/await` is the default.** Raw `Promise` only for event-bridging or retry chains.
- **Guard re-entrant async work** — cache the in-flight promise and return it on re-entry.
- **Version stale async results** — where newer requests supersede older ones, discard (and clean
  up) the stale responses.
- **Throw only for genuinely unrecoverable cases**; otherwise retry (bounded by a named constant) or
  degrade gracefully.
- **Cross-boundary errors are structured, not strings** — a typed error object across the boundary,
  wrapped in a dedicated `Error` subclass on the receiving side.
- **Log through the shared logger**, not bare `console.*`. Catch and narrow:
  `error instanceof Error ? error : new Error(String(error))`.

---

## 6. Functional style & immutability

- Utilities are pure, named exports; stateful helpers become classes.
- **No default exports** — named exports re-exported through barrels.
- **Immutability by default** — build new objects with spread; in-place mutation only through an
  explicit, clearly-named mutation utility where it is intentional.

---

## 7. Module & package boundaries

The boundary rules are shape-specific and live in the repo profile:
[.agent/repo.md](../../repo.md), "Boundaries" (cross-package imports in a monorepo, module/layer
direction in a single repo). A diff that crosses one blocks merge like any other rule here.

---

## 8. Comments & documentation

- **Public classes, methods, and exported types carry JSDoc.** Class JSDoc leads with a one-line
  summary and a **Responsibilities** list (`@remarks` for non-obvious lifecycle).
- **`@param`/`@returns` carry units, ranges, and ownership** — ms vs seconds, `0..1` vs `0..100`,
  who must release a returned resource, whether a bound is inclusive. A signature can't express any
  of it, and it's the highest-value thing JSDoc holds.
- **Inline `//` comments explain _why_, not _what_.** Don't narrate self-evident code.
- **One or two lines, not a wall.** A `//` block stacked four or five lines above a statement has
  stopped being a note and become an essay, and the one non-obvious sentence inside it gets skimmed
  past. Say that sentence and stop. A rejected alternative, a measurement, a defect's history and an
  argument for the code's shape belong in `@remarks`, an ADR, or the commit that made the change.
- **Rationale doesn't go in JSDoc.** A rejected alternative, or a platform bug that shaped the code,
  is an inline `//` at the line that looks wrong — that reader is the one about to "simplify" it
  back. A decision that shaped several files is an ADR under `docs/adr/`; the code carries a
  one-line pointer to it, not the argument.
- If spelling is linted, new domain terms go in the dictionary, not inline ignores.

---

## 9. Doc-unit documentation (required, not optional)

A behavior or API change that lands without a doc update is an incomplete change. Structure, house
style, and the change→doc routing table live in
[documentation-maintenance.md](documentation-maintenance.md). When asked for a commit message or a
code review, **first ask whether the docs need updating** for the changes in scope.

---

## 10. What this codebase does _not_ have (so don't expect it in review)

<!-- setup: list the things a reviewer might expect and should not block on — e.g. no test run on
commit, no path aliases beyond the workspace scope, no native `#private` fields, no default exports. -->

---

## 11. Commits, versioning & releases

<!-- setup: fill in — commit subject style (see commit-and-pr-authoring.md), whether versions are
unified across packages or independent, which commands
release, and what must never be hand-bumped. -->

---

_Maintained per `AGENTS.md`. If the code diverges from a rule here, fix the doc (at landing, reported
with its reason) rather than enforcing a style the codebase has moved away from._
