# Commit & PR Authoring (`commit-and-pr-authoring`)

How to write commit messages and pull request descriptions in this repo. Read this **before** committing changes or opening/describing a PR. Versioning/release mechanics live in [code-review-standards.md](code-review-standards.md), "Commits, versioning & releases"; doc-update obligations in [documentation-maintenance.md](documentation-maintenance.md).

## Ground rules (commits and PRs alike)

- **Write as the developer.** Never use AI-specific language: no "Generated with …" footers, no mention of AI/assistant/agent/model/tooling involvement, no AI-flavored boilerplate ("This commit introduces…", "We have successfully…").
- **No co-authoring metadata.** Never add `Co-Authored-By:` or any other attribution trailer, credit line, or signature — regardless of who or what produced the change. Agent tools that add one by default are configured off in their adapter (Claude Code: `attribution` in `.claude/settings.json`).
- **Understand the change before writing about it.** Read the full diff and identify its *purpose* — the problem being solved or the capability being added — before drafting a single line. The message explains **why the change exists**, not which files moved; the diff already shows the what. If the purpose can't be determined from the diff and context, ask — don't guess.
- Before producing a commit message, **ask whether the docs need updating** for the changes in scope (per [documentation-maintenance.md](documentation-maintenance.md)).

## Commit messages

- **Subject:** `type:`-prefixed where natural (`feat:`, `fix:`, `refactor:`, `chore:`, `docs:`), imperative mood, one line stating the change's purpose. Avoid vague subjects ("fixes", "updates", "misc changes").
- **Body** (for any non-trivial change): 1–5 sentences on the problem and why this approach solves it. Include ripple effects worth knowing at `git log` time (behavior changes, migrations, follow-ups required).
- **Don't:** narrate file-by-file, restate the diff, pad with process notes ("ran lint"), or violate a ground rule above.

Litmus test: a teammate reading only `git log` should understand *why* each commit exists without opening the diff.

## Pull requests

**Laconic** — readable in one pass; every sentence earns its place.

**Stacks:** a task with several reviewable steps lands as a PR stack — one PR per step, each based on
the previous, review fixes as new layers on top, merged as a whole. Building, fixing and merging:
[pr-stacks.md](pr-stacks.md). Each body still opens with what that layer alone delivers.

- **Title:** same `type:`-prefixed subject style as commits.
- **Body structure:**
  1. **Opening (1–3 sentences):** the exact, high-level description of what the PR delivers — the feature created, bug fixed, or enhancement made — and its observable effect.
  2. **Solution bullets:** the concrete steps taken to solve the problem, in order. Where a step's approach isn't self-evident, give the rationale inline using the *because-of-this-problem, we-do-it-this-way* form.
  3. **Optional closing:** verification performed (gates run), known follow-ups.
- Same ground rules as commits: no AI-specific language, no generated-with footers, no co-author credits.

**Skeleton:**

```md
<What this delivers, exactly, at a high level — feature / fix / enhancement and its effect.>

- Because <problem/constraint>, <step done this way>.
- <step>
- <step>

Verified: <the gates run, e.g. compile && lint && format && test> green across the affected code.
```
