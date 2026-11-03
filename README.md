# Human-in-the-loop agentic setup

A portable operating layer for coding agents, for monorepos and single repos. The agent is treated
as a capable contractor with two built-in weaknesses: it forgets everything between sessions, and it
leans toward "make it green and move on". The setup turns the repository into the agent's long-term
memory and its rulebook, keeps both in git, and loads them only when a task needs them.

**Agents execute; humans decide.** The agent investigates, plans, implements, tests, reviews its own
work and records what it learned. It stops for the human only where judgement or ownership is
needed — a hard-to-reverse choice, a trade-off between credible options, conflicting evidence about
intended behaviour, landing an ADR step, a conflict with another task in flight — and when it does,
it brings the problem, the evidence, the options with their trade-offs, and a recommendation with
its reason.

## What it solves

| Problem with agents | Mechanism |
| --- | --- |
| **Cold start.** Every session starts blank; the agent reads too much or guesses. | A two-tier knowledge base (`.agent/contexts/`: root index → area routers → single-topic docs) that says what each subsystem does, what it affects and what relies on it. A hook surfaces it on every prompt. |
| **Losing the search.** After compaction the agent re-tries what it already ruled out. | Task-progression records (none / light `.tmp/` file / heavy ADR step): entries only when a fork closes, with the observation that closed it; `Ruled out` is permanent; re-surfaced after every compaction. |
| **Made-up codebase knowledge.** | Every context claim is a `path:line` anchored on a symbol name, derived from source; `check-contexts` verifies them. |
| **The agent rewriting its memory mid-task.** | Every context operation — create, update, delete, rename, split — happens once the task is complete, before the PR, and is reported to the user line by line with its reason. Nothing changes silently or on the go. |
| **Gaming the tests.** | "Red never bends": known defects are expected-failure tests listed in `ISSUES.md`; thresholds come from measurements; a fix moves the reproduction to the regressions spec, never deletes it. |
| **Settling on the first option that works.** | ADR steps rank criteria before trying options and keep *dead / chosen / viable-not-chosen* with `revisit if`; the agent asks before freezing a step at landing. |
| **Review churn on stacked PRs.** | An open layer never gets another commit: review fixes arrive as a new layer on top, so the stack is never rebased, and it merges as a whole, top-down, without conflicts. |
| **Grading its own homework.** | Self-review by a fresh-context reviewer that never saw the implementation, writing a fix-ready handoff. |
| **Parallel agents colliding.** | Detection is mechanical and quiet: files changed on both sides, declared `Affects:` footprints, uses of symbols the other side changed, textual merge conflicts, and main moving underneath. A possible collision reaches the conversation as one line; an edit into another task's footprint is stopped until the user decides — ignore, a quick look, or a full investigation that merges both and runs the tests on the combination. |
| **Conflicting sources of truth.** | A protocol that dates code, comments, ADRs and callers, classifies the divergence, and recommends based on what dependents actually rely on. |

## Repository layout

```
install.sh                    installer: ./install.sh <monorepo|single-repo> <target> [--with-codex] [--migrate]
core/                         everything shared by both shapes (copied into the target as-is)
variants/
  monorepo/                   .agent/repo.md (repo profile) + .claude/settings.json (autonomy profile)
  single-repo/                the same two files for a single-package repo
adapters/codex/               optional Codex hook wiring
tests/run.sh                  end-to-end tests: installs both shapes into scratch repos
LICENSE                       MIT
```

The two shapes differ only where the repo shape matters, and all of it is in **`.agent/repo.md`, the
repo profile**: doc units, ADR locations, test paths, commands, module boundaries. Every protocol
refers to "the regressions spec" or "the verify gate" and the profile says where and what — so the
protocols are identical in both shapes.

## What lands in a target repo

```
AGENTS.md                     canonical instructions for every agent
CLAUDE.md                     Claude Code adapter: `@AGENTS.md` + Claude-only notes
ISSUES.md                     open defects, each an expected-failure scenario
docs/adr/                     topic docs (composed record) + history/ (decision steps)
.tmp/                         git-ignored: task records, review handoffs
.agent/
  repo.md                     repo profile (shape-specific)
  contexts/                   the knowledge base: index.md → dev/, tools/, <your areas>/
    tools/                    the protocols (task records, landing, decisions, conflicts, …)
  agents/self-reviewer.md     agent-agnostic reviewer brief
  hooks/context-first.sh      session-start context, text or Claude-hook JSON; prints only on change
  hooks/edit-guard.sh         stops an edit into another task's footprint until the user decides
  bin/check-contexts          context drift report, relevant vs unrelated to the change
  bin/worktree-overlap        collision detection, ignore, quick look, full investigation
  lib/common.sh               shared shell helpers
.claude/
  settings.json               autonomy profile + hook wiring (see below)
  agents/self-reviewer.md     subagent adapter onto .agent/agents/self-reviewer.md
.codex/                       only with --with-codex
```

## Install

```sh
./install.sh monorepo    ~/code/my-monorepo
./install.sh single-repo ~/code/my-app --with-codex
./install.sh --help
```

Options can go anywhere on the line. It never overwrites: files the target already has are kept and
listed for a hand merge. Re-running is safe.

**Repos on the original setup.** If the target still has `.claude/contexts/`, the old hook, or a
`CLAUDE.md` that doesn't import `AGENTS.md`, the installer lists what it found and **asks** whether to
migrate; declining changes nothing (non-interactive runs need `--migrate`). A migration moves the
knowledge base to `.agent/contexts/`, rewrites links, keeps everything it replaces under
`.tmp/migration-<timestamp>/`, and carries the project name and area rows into `AGENTS.md`. The rest
needs judgement, so the installer ends by telling you to ask the agent to finish it
(`tools/bootstrap.md`, "Migrating from the original setup").

**Merge strategy.** The installer also prints a check for PR stacks: merge commits are recommended
(stacks merge top-down and keep every layer in history), and many repos disable them — it prints the
settings URL from the target's `origin` remote (GitHub or GitLab), or the URL pattern when there is
none. Keeping squash or rebase is fine: set "Stack merge" in `.agent/repo.md`.

Then open a fresh agent session in the target and ask:

> Bootstrap the agent setup per `.agent/contexts/tools/bootstrap.md`.

The agent fills the repo profile and the standards from the code, proposes the subsystem areas to
document, authors the ones you pick, reconstructs ADRs only where the repo holds evidence (marked
`Provenance: reconstructed`), and reports everything it wrote — with any conflicts that need your
decision — before committing.

## Agent support

`AGENTS.md` and `.agent/` are agent-agnostic. Each agent gets a thin adapter, never a copy:

| Agent | Instructions | Session-start context | Self-review |
| --- | --- | --- | --- |
| **Claude Code** | `CLAUDE.md` imports `AGENTS.md` (Claude reads `AGENTS.md` natively only when no `CLAUDE.md` exists) | `UserPromptSubmit` + `SessionStart(compact)` hooks in `.claude/settings.json` | `self-reviewer` subagent |
| **Codex** | reads `AGENTS.md` natively | optional `.codex/hooks.json` (`--with-codex`); hooks are experimental and version-dependent — if they don't fire, enable `features.hooks` in `~/.codex/config.toml` | a fresh session given `.agent/agents/self-reviewer.md` |
| **Others reading `AGENTS.md`** | natively | `AGENTS.md` tells the agent to run `.agent/hooks/context-first.sh` as its first act and after compaction | a fresh session with the brief |

## Recommended: auto-compact at ~200k tokens

Configure your agent to compact at about **200k tokens**. With this structure it is the most
cost-effective point, as measured on real tasks: everything that must survive a compaction — the
plan, the footprint, what was ruled out and why — is on disk in the task record, and the hook
re-surfaces it right after compaction, so compacting earlier loses little while keeping every turn
cheaper and the window sharp.

| Agent | Setting |
| --- | --- |
| Claude Code | `"autoCompactWindow": 200000` in `.claude/settings.json` (shipped); per machine: `CLAUDE_CODE_AUTO_COMPACT_WINDOW=200000` |
| Codex | `model_auto_compact_token_limit = 200000` in `.codex/config.toml` (shipped with `--with-codex`; project config loads for trusted projects) or `~/.codex/config.toml` |
| Others | the agent's own compaction threshold, if it exposes one; otherwise compact manually around 200k |

## Autonomy profile — `.claude/settings.json`

This file decides **how much the agent may do without asking**. The shipped one is one reasonable
profile, not a recommendation for every team — **review it and configure it for yourself** before
relying on it.

What it sets:

- **allow** — reading and editing files, the `.agent/` scripts, the toolchain's build/test/lint
  commands, and read-only `git`/`gh` commands. Nothing outside the repo.
- **ask** — `git push`, opening/merging PRs, deleting or renaming branches, hard resets, `git clean`,
  removing worktrees, adding or removing dependencies.
- **deny** — publishing and releasing (`pnpm/npm/lerna/changeset publish`, `lerna version`, release
  scripts), force-push, deleting tags, and rewriting remotes. Deny beats ask beats allow, so these
  stay blocked even inside compound commands. Releasing is a human action.
- **`autoCompactWindow: 200000`** — see "Recommended: auto-compact at ~200k tokens" above.
- **`attribution` empty and `includeCoAuthoredBy: false`** — no co-author trailer or PR footer,
  matching the commit rules (`attribution` for current Claude Code, `includeCoAuthoredBy` for older
  versions).
- **`autoContinueAtUsageLimit: true`** — keep working after a usage limit resets. Claude Code
  documents this key as user- or managed-scope, so if a project file doesn't take effect, set it in
  `~/.claude/settings.json` too.
- **`showThinkingSummaries: true`** — show the agent's reasoning summaries; display only.
- **hooks** — the session-start context on every prompt and after compaction.

Permission rules match command text; they are guard-rails for an honest agent, **not a security
boundary**. Tune them to your risk appetite:

- **More autonomy** (unattended runs, Remote Control): move `git push` and `gh pr create` from `ask`
  to `allow`; `remoteControlAtStartup` is honoured only in `~/.claude/settings.json`.
- **Less autonomy**: move toolchain commands out of `allow` so each run prompts.
- **Machine-specific allowances** (paths outside the repo, local tools): `.claude/settings.local.json`,
  which is git-ignored. Never put them in the shared file.

## Scripts

All are bash + git + POSIX awk/sed, written for bash 3.2 (macOS) and Git Bash; no `jq` needed.

| Script | What it does |
| --- | --- |
| `.agent/hooks/context-first.sh [--format text\|json] [--dedupe]` | Lists the context areas, the current branch's task record or Draft ADR step (with its `Now:`), and undecided collisions with other tasks. With `--dedupe` it prints only when something changed in this session (always after compaction). Never fails a prompt. |
| `.agent/hooks/edit-guard.sh` | Pre-edit hook: denies an edit to a file inside another task's footprint until the user has decided on that collision. Reads only the cached detection; allows anything it can't read. |
| `.agent/bin/check-contexts [--base <ref>]` | Verifies every context reference and `Covers:` glob; reports `DRIFT` (with the new line), `MISSING`, `GONE`, `BROKEN`, `UNANCHORED`, `EMPTY-COVER`; splits docs into relevant-to-this-change and unrelated. Exit 1 on findings. |
| `.agent/bin/worktree-overlap [--base <ref>]` | Detects possible collisions with every other worktree and with main: both change, declared, symbol uses, merge conflicts. `--brief` prints one line per undecided collision (cached). |
| `.agent/bin/worktree-overlap ignore\|quick\|full <branch\|main>` | The user's three choices: record an ignore (quiet until the overlap grows); write a quick look (their goal + overlapping changes) to `.tmp/`; merge both in a throwaway worktree and run `--test "<command>"` on the combination. |

The base ref is `$AGENT_BASE`, else `origin/HEAD`, else `main`/`master`.

### Conventions the scripts read

```
Covers: `src/render/**`, `src/shared/time.ts`                       # context doc, under the title
- `src/render/Clock.ts:42` `Clock.tick` — advances elapsed time (ms)  # reference + anchoring symbol
Affects: `src/store/**` — contract: batch write returns per-record status   # task record header
```

Globs are git pathspec globs (`**` crosses directories). In `Covers:` and `Affects:`, backticked
tokens before ` — ` are read; the prose after it is for people.

## Tests

```sh
tests/run.sh
```

Builds throwaway git repos, installs both shapes, and checks the installer (idempotence, never
overwriting, gitignore), the hook (area discovery, light and Draft-ADR records in both shapes,
worktrees, compaction, JSON validity, failure-safety), the drift checker (each finding kind,
relevance classification, fenced code, host:port false positives) and the overlap report.

## Design notes

- **`AGENTS.md` is canonical, adapters import it.** Restating instructions per agent guarantees
  they drift apart; an import or a native read keeps one source.
- **Topic docs are the composed ADR record.** One topic doc per subject, indexed in
  `docs/adr/README.md`, together form the composed state; a single all-in-one file would grow until
  no task could afford to load it.
- **ADR steps land with the task, after asking.** The agent asks one line before freezing: what is
  frozen, the comparison result, the scenarios that prove it.
- **Contexts change at landing, in the open.** No approval per operation, but never mid-task — the
  knowledge base stays stable while work is in flight — and every operation is reported with its
  reason. Unrelated drift is listed for the user to decide.
- **The scripts report; they don't decide.** Overlaps are *potential* until the agent assesses them;
  drift on relevant docs still needs a content read. Judgement stays with the agent, decisions with
  the human.

## License

[MIT](LICENSE). The files `install.sh` copies into your repo are yours to change
once installed.
