# AGENTS.md — <project-name>

<!-- setup: one line on what the project is. Everything shape-specific (monorepo vs single repo,
paths, commands, boundaries) lives in .agent/repo.md, not here. -->
<One-line description of the project>. Repo shape, paths, commands and module boundaries:
[.agent/repo.md](.agent/repo.md) — the **repo profile**, the single source for every path and command
the protocols below refer to.

This file is the canonical instruction set for any coding agent working here. Agent-specific files
(`CLAUDE.md`, `.claude/`, `.codex/`) are thin adapters onto it and never restate it.

## Operating model — agents execute, humans decide

The agent owns execution: investigating, planning, implementing, testing, reviewing its own work and
keeping the record of what it learned. The human owns decisions that need judgement or ownership:
anything hard to reverse, a trade-off between credible options, conflicting evidence about intended
behaviour, landing an ADR step, and a conflict with another task in flight. For those the agent stops and asks **with enough to decide in one read** — the problem, the
evidence, the options with their trade-offs, a recommendation and why — per
[tools/human-decisions.md](.agent/contexts/tools/human-decisions.md). Everything else it decides
itself and states the assumption it made. Human-in-the-loop means asking where it matters, not
asking for every step.

## Session start (every agent)

1. Run `.agent/hooks/context-first.sh --format text` and act on what it prints. Agents with a
   prompt hook wired (Claude Code via `.claude/settings.json`, Codex via `.codex/` if installed)
   get this automatically on every prompt and after every compaction; others run it as their first
   act and again after any compaction.
2. If it names a task-progression record for this branch, read it **before anything else** and
   continue it rather than starting over.
3. If it lists other worktrees with active tasks and this task will touch shared code, run
   `.agent/bin/worktree-overlap` before editing
   ([tools/concurrent-work.md](.agent/contexts/tools/concurrent-work.md)).

## Saved contexts — load on demand

A curated, two-tier knowledge base lives under [.agent/contexts/](.agent/contexts/). It is the source
of truth for how subsystems work, what each one affects, and how to work in them.

**Start at the root navigator: [.agent/contexts/index.md](.agent/contexts/index.md).** Each area has
its own `index.md` that routes a task to the one doc it needs. **Load only the areas and docs the
task touches** — never preload everything.

<!-- setup: one row per subsystem area as it is created (tools/subsystem-context-authoring.md). -->
| Area | Load it when the task touches… |
| --- | --- |
| [dev/](.agent/contexts/dev/index.md) | developer workflow — the build/test/release command surface. |
| [tools/](.agent/contexts/tools/index.md) | process — how to plan, test, review, land, ask, and maintain the knowledge base. |

A repo without contexts yet starts with [tools/bootstrap.md](.agent/contexts/tools/bootstrap.md).

## Working rules

- **Starting a task:** decide its progression tier — **none** for ordinary work; **light**
  (`.tmp/task-<branch>.md`) when it will outlive one context window or the search itself is the
  expensive artifact; **heavy** (an ADR history step, `Draft`) when the decision is hard to reverse or
  two credible approaches differ on capability, performance or memory. Full rule and record shapes:
  [tools/task-progression-document.md](.agent/contexts/tools/task-progression-document.md). A
  record's `Affects:` line declares what the task will touch, so concurrent tasks can see it.
- **Building a feature or fixing a bug:** tests ship in the same change as the code. A feature lands
  with the slow-tier scenario proving what a user would notice broken, plus fast-tier cases for new
  pure logic. A bug fix lands with its reproduction: while open it lives in [ISSUES.md](ISSUES.md) as
  an expected-failure scenario (`test.fail()` / `it.fails`); once fixed the marker comes off and the
  scenario **moves** to the regressions spec named in the repo profile (a fast-tier one stays beside
  its subject). A reproduction is **never deleted**, and a test is never weakened to go green.
- **Writing or reviewing tests:** load
  [tools/test-authoring-standards.md](.agent/contexts/tools/test-authoring-standards.md) first.
- **Reviewing code:** load [tools/code-review-standards.md](.agent/contexts/tools/code-review-standards.md)
  first; a review ends in a `.tmp/review-<branch>.md` handoff.
- **Conflicting evidence** — code, comments, docs, ADRs and callers disagree about what something is
  supposed to do: never pick one silently; follow
  [tools/evidence-conflicts.md](.agent/contexts/tools/evidence-conflicts.md) and bring the human a
  decision request.
- **Editing product docs or ADRs:** follow
  [tools/documentation-maintenance.md](.agent/contexts/tools/documentation-maintenance.md). Before
  freezing an ADR step at landing, ask the user.
- **The knowledge base (`.agent/contexts/`)** changes only through
  [tools/context-updater.md](.agent/contexts/tools/context-updater.md). Every operation — create,
  update, delete, rename, split — happens **when the task is complete, before the PR**, never on the
  go. None needs approval; each is **reported to the user** with its reason. Every context reference
  is a verified `file:line` anchored on a symbol name.
- **Commits and PRs:** follow [tools/commit-and-pr-authoring.md](.agent/contexts/tools/commit-and-pr-authoring.md)
  — purpose-first; **never** AI-specific language or co-authoring metadata. Multi-step tasks land as
  a PR stack ([tools/pr-stacks.md](.agent/contexts/tools/pr-stacks.md)): review fixes come as a new
  layer on top, never a rebase, and the stack merges as a whole.
- **Never** publish, release, push, force-push, delete branches/tags, or rewrite remotes without the
  human asking for that specific action.

## Landing a task

A task is done when the full pipeline in [tools/landing.md](.agent/contexts/tools/landing.md) has run,
in order: gates green → self-review in a fresh context → fixes → overlap re-check → contexts and
ISSUES updated and reported → ADR step landed after asking → commits → PR (or PR stack).

## Compaction

Compaction is expected; the setup is built so that it loses nothing that matters. What must survive
is on disk, not in the conversation: the task-progression record holds the plan, `Now:`, the
`Affects:` footprint and — permanently — `Ruled out`, the failed approaches with the observation
that killed each one. That half is the most expensive to rediscover, so it is never collapsed.
What compaction may drop is tool output, narration and progress along the chosen path; git has the
latter.

When summarising, keep: the task as the human stated it, the record's path, the context docs loaded
and why, open decision requests and the human's answers, and constraints the human set this session.

After compaction, before the next edit: re-run the session-start step, re-read the record, and
reload the area index of every context that was loaded.
