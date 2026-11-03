#!/usr/bin/env bash
# End-to-end checks for the installer and the .agent/ scripts, on both repo shapes.
# Each scenario builds a throwaway git repo, installs into it, and asserts on what a user would see.
#
# Usage: tests/run.sh            (needs: bash, git; jq optional — used to validate hook JSON)

set -u

here=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/hitl-tests.XXXXXX")
trap 'rm -rf "$work"' EXIT

pass=0
fail=0
ok()   { pass=$((pass + 1)); printf '  ✔ %s\n' "$1"; }
bad()  { fail=$((fail + 1)); printf '  ✘ %s\n' "$1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      /'; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected to contain: $3
--- got:
$2" ;; esac; }
lacks(){ case "$2" in *"$3"*) bad "$1" "expected NOT to contain: $3
--- got:
$2" ;; *) ok "$1" ;; esac; }

git_quiet() { git -c user.name=t -c user.email=t@t -c init.defaultBranch=main "$@" >/dev/null 2>&1; }

new_repo() {
  local dir=$1
  mkdir -p "$dir/src/render"
  git_quiet init "$dir"
  cat > "$dir/src/render/Clock.ts" <<'EOF'
export class Clock {
  private elapsedMs = 0;

  /** Advances the clock. @param dtMs elapsed time in ms */
  tick(dtMs: number): void {
    this.elapsedMs += dtMs;
  }
}
EOF
  printf 'export const VERSION = 1;\n' > "$dir/src/version.ts"
  git_quiet -C "$dir" add -A
  git_quiet -C "$dir" commit -m init
}

for shape in monorepo single-repo; do
  printf '\n%s\n' "== $shape"
  repo="$work/$shape"
  new_repo "$repo"

  # --- install ---------------------------------------------------------------------------------
  out=$("$here/install.sh" "$shape" "$repo" 2>&1)
  has "install reports success" "$out" "Installed the $shape setup"
  for f in AGENTS.md CLAUDE.md ISSUES.md .agent/repo.md .agent/contexts/index.md \
           .agent/contexts/tools/landing.md .agent/agents/self-reviewer.md \
           .claude/settings.json .claude/agents/self-reviewer.md docs/adr/README.md .tmp/.gitkeep; do
    [ -f "$repo/$f" ] && ok "installed $f" || bad "installed $f"
  done
  [ -x "$repo/.agent/bin/check-contexts" ] && ok "scripts are executable" || bad "scripts are executable"
  has "repo profile is the $shape variant" "$(head -n 1 "$repo/.agent/repo.md")" \
    "$([ "$shape" = monorepo ] && echo 'monorepo' || echo 'single repo')"
  [ ! -e "$repo/.codex" ] && ok "no Codex adapter without --with-codex" || bad "no Codex adapter without --with-codex"

  out=$("$here/install.sh" "$shape" "$repo" 2>&1)
  has "re-install copies nothing" "$out" "0 files copied"
  [ "$(grep -c '^# >>> human-in-the-loop-agentic-setup$' "$repo/.gitignore")" = 1 ] &&
    ok "gitignore block appended once" || bad "gitignore block appended once"

  printf '# mine\n' > "$repo/AGENTS.md.keep" && cp "$repo/AGENTS.md.keep" "$repo/AGENTS.md"
  out=$("$here/install.sh" "$shape" "$repo" 2>&1)
  has "an existing different file is kept and reported" "$out" "AGENTS.md"
  has "the kept file is untouched" "$(cat "$repo/AGENTS.md")" "# mine"
  git -C "$repo" checkout -q -- . 2>/dev/null; cp "$here/core/AGENTS.md" "$repo/AGENTS.md"; rm -f "$repo/AGENTS.md.keep"

  # the scratch dir and personal Claude files must stay out of git; shared ones must not
  git -C "$repo" check-ignore -q .tmp/task-x.md && ok ".tmp records are ignored" || bad ".tmp records are ignored"
  git -C "$repo" check-ignore -q .claude/settings.local.json && ok "settings.local.json is ignored" || bad "settings.local.json is ignored"
  git -C "$repo" check-ignore -q .claude/settings.json && bad "settings.json is shared" || ok "settings.json is shared"
  git -C "$repo" check-ignore -q .claude/agents/self-reviewer.md && bad ".claude/agents is shared" || ok ".claude/agents is shared"

  git_quiet -C "$repo" add -A
  git_quiet -C "$repo" commit -m "add agent setup"

  # --- hook ------------------------------------------------------------------------------------
  out=$(cd "$repo" && .agent/hooks/context-first.sh --format text)
  has "hook lists discovered areas" "$out" "dev, tools"
  lacks "hook is silent about records when none exist" "$out" "Task-progression record"

  mkdir -p "$repo/.agent/contexts/render"
  printf '# Render\n\nCovers: `src/render/**`\n' > "$repo/.agent/contexts/render/index.md"
  out=$(cd "$repo" && .agent/hooks/context-first.sh --format text)
  has "hook discovers a new area with no config change" "$out" "dev, render, tools"

  git_quiet -C "$repo" checkout -b feat/clock-units
  printf 'Goal:    ms → seconds in Clock\nAffects: `src/render/**` — contract: tick() takes seconds\nNow:     step 2 — convert callers\n' \
    > "$repo/.tmp/task-feat-clock-units.md"
  out=$(cd "$repo" && .agent/hooks/context-first.sh --format text)
  has "hook surfaces the light record by branch slug" "$out" ".tmp/task-feat-clock-units.md — Now: step 2 — convert callers"

  adr_dir=docs/adr/history
  [ "$shape" = monorepo ] && adr_dir=packages/engine/docs/adr
  mkdir -p "$repo/$adr_dir"
  printf '# 0001 — Clock in seconds\n\n**Status:** Draft\n**Branch:** feat/clock-units\n' > "$repo/$adr_dir/0001-clock-seconds.md"
  out=$(cd "$repo" && .agent/hooks/context-first.sh --format text)
  has "hook finds an untracked Draft ADR step at $adr_dir" "$out" "ADR step in Draft for branch feat/clock-units: $adr_dir/0001-clock-seconds.md"
  printf '# 0000 — Earlier decision\n\n**Status:** Accepted, 2026-01-05\n**Branch:** feat/clock-units\n' > "$repo/$adr_dir/0000-earlier.md"
  out=$(cd "$repo" && .agent/hooks/context-first.sh --format text)
  lacks "a landed step that kept its Branch line is not surfaced" "$out" "0000-earlier.md"

  out=$(cd "$repo" && .agent/hooks/context-first.sh --format json --event SessionStart --source compact)
  if command -v jq >/dev/null 2>&1; then
    ev=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.hookEventName' 2>/dev/null)
    [ "$ev" = SessionStart ] && ok "hook JSON is valid and names its event" || bad "hook JSON is valid and names its event" "$out"
    ctx=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext')
    has "compaction note is included after compact" "$ctx" "just compacted"
  else
    has "hook JSON names its event" "$out" '"hookEventName":"SessionStart"'
  fi
  out=$(cd "$repo/src" && "$repo/.agent/hooks/context-first.sh" --format text)
  has "hook works from a subdirectory" "$out" "feat/clock-units"
  out=$(cd "$work" && "$repo/.agent/hooks/context-first.sh" --format json; echo "exit=$?")
  has "hook never fails a prompt outside a repo" "$out" "exit=0"

  # --- check-contexts ---------------------------------------------------------------------------
  cat > "$repo/.agent/contexts/render/clock.md" <<'EOF'
# Clock

Covers: `src/render/**`, `src/gone/**`

- `src/render/Clock.ts:5` `Clock.tick()` — advances elapsed time (ms).
- `src/render/Clock.ts:2` `elapsedMs` — accumulated ms.
- `src/render/Clock.ts:3` — unanchored reference.
- `src/render/Missing.ts:1` `Missing` — removed file.
- `src/version.ts:1` `NOT_THERE` — symbol removed.
- Dev server on `localhost:3000` is not a reference.

```ts
// `src/fenced.ts:1` `ignored` inside a fence
```
EOF
  git_quiet -C "$repo" add -A
  git_quiet -C "$repo" commit -m "context"
  out=$(cd "$repo" && .agent/bin/check-contexts --base HEAD; echo "exit=$?")
  lacks "a valid anchored reference is not a finding" "$out" "Clock.ts:5 —"
  has "an unanchored reference is reported" "$out" "UNANCHORED   L7    src/render/Clock.ts:3"
  has "a missing file is reported" "$out" "MISSING      L8    src/render/Missing.ts:1"
  has "a vanished symbol is reported" "$out" "GONE         L9    src/version.ts:1"
  has "a Covers glob matching nothing is reported" "$out" 'EMPTY-COVER  `src/gone/**`'
  lacks "host:port is not treated as a reference" "$out" "localhost"
  lacks "fenced code is ignored" "$out" "fenced.ts"
  has "nothing changed → findings are unrelated" "$out" "Unrelated (pre-existing drift)"
  has "findings exit non-zero" "$out" "exit=1"

  # shift the code: the symbol moves, the doc is now relevant to the change
  { printf '// header\n// header\n'; cat "$repo/src/render/Clock.ts"; } > "$repo/src/render/Clock.ts.new"
  mv "$repo/src/render/Clock.ts.new" "$repo/src/render/Clock.ts"
  out=$(cd "$repo" && .agent/bin/check-contexts --base HEAD)
  has "a moved symbol is DRIFT with its new line" "$out" 'DRIFT        L5    src/render/Clock.ts:5 — `tick` now at line 7'
  has "a doc covering changed code is relevant" "$out" "(covers changed: src/render/Clock.ts)"
  has "the area index covering the change is relevant too" "$out" ".agent/contexts/render/index.md  (covers changed"
  has "a relevant doc with clean refs still asks for a content read" "$out" "content still needs a read"
  git -C "$repo" checkout -q -- src/render/Clock.ts

  # --- worktree-overlap -------------------------------------------------------------------------
  wt="$work/$shape-wt"
  git_quiet -C "$repo" worktree add -b feat/version-bump "$wt" main
  mkdir -p "$wt/.tmp"
  printf 'Goal:    bump version\nAffects: `src/version.ts`, `src/render/Clock.ts` — reads Clock\nNow:     step 1\n' \
    > "$wt/.tmp/task-feat-version-bump.md"
  printf 'export const VERSION = 2;\n' > "$wt/src/version.ts"
  printf 'export const VERSION = 3;\n' > "$repo/src/version.ts"

  out=$(cd "$repo" && .agent/bin/worktree-overlap)
  has "other worktree is listed with its record" "$out" "feat/version-bump"
  has "its goal is shown" "$out" "goal:     bump version"
  has "a file changed in both is a file overlap" "$out" "files:    src/version.ts"
  has "my declared footprint vs their declared footprint is reported" "$out" "declared: src/render/Clock.ts"
  has "summary counts the overlap" "$out" "potential overlap with 1"

  out=$(cd "$repo" && .agent/hooks/context-first.sh --format text)
  has "hook mentions other tasks in flight" "$out" "feat/version-bump (bump version)"

  out=$(cd "$wt" && "$wt/.agent/bin/worktree-overlap" 2>&1)
  has "the check runs from the other worktree and sees this task" "$out" "feat/clock-units"

  git -C "$repo" checkout -q -- src/version.ts
  git_quiet -C "$repo" worktree remove --force "$wt"
done

printf '\n== installer arguments\n'
out=$("$here/install.sh" nonsense "$work" 2>&1; echo "exit=$?")
has "unknown shape is rejected" "$out" "exit=2"
codex_repo="$work/codex"; new_repo "$codex_repo"
"$here/install.sh" --with-codex single-repo "$codex_repo" >/dev/null 2>&1
[ -f "$codex_repo/.codex/hooks.json" ] && ok "an option before the arguments works (--with-codex first)" || bad "an option before the arguments works (--with-codex first)"
out=$("$here/install.sh" --help; echo "exit=$?")
has "--help prints usage" "$out" "Usage: ./install.sh <monorepo|single-repo> <target-dir>"
has "--help exits 0" "$out" "exit=0"
out=$("$here/install.sh" single-repo "$codex_repo" --bogus 2>&1; echo "exit=$?")
has "an unknown option is rejected" "$out" "unknown option '--bogus'"
out=$("$here/install.sh" single-repo "$codex_repo" extra 2>&1; echo "exit=$?")
has "a third argument is rejected" "$out" "unexpected argument 'extra'"
out=$("$here/install.sh" single-repo 2>&1; echo "exit=$?")
has "a missing target is rejected" "$out" "exit=2"

printf '\n== migration from the original setup\n'
# original_repo <dir> — a repo shaped like the original template after setup: knowledge base under
# .claude/contexts with a project area, CLAUDE.md as the instructions file, the old hook and settings.
original_repo() {
  local d=$1
  new_repo "$d"
  mkdir -p "$d/.claude/contexts/tools" "$d/.claude/contexts/dev" "$d/.claude/contexts/render" \
    "$d/.claude/hooks" "$d/docs/adr"
  cat > "$d/CLAUDE.md" <<'MD'
# CLAUDE.md — Vidaldi Engine

Video engine. pnpm + lerna monorepo.

## Saved contexts — load on demand

**Start at the root navigator: [.claude/contexts/index.md](.claude/contexts/index.md).**

| Area | Load it when the task touches… |
| --- | --- |
<!-- setup: one row per subsystem area as it is created (tools/subsystem-context-authoring.md). -->
| [dev/](.claude/contexts/dev/index.md) | developer workflow |
| [render/](.claude/contexts/render/index.md) | the render pipeline and frame timing |
| [tools/](.claude/contexts/tools/index.md) | meta |
MD
  printf '# Contexts Index\n\n- [render/](render/index.md) — render\n- [tools/](tools/index.md) — meta\n' > "$d/.claude/contexts/index.md"
  printf '# Dev\n' > "$d/.claude/contexts/dev/index.md"
  printf '# Render\n\nRules: [CLAUDE.md](../../../CLAUDE.md). Self: `.claude/contexts/render/index.md`.\n' > "$d/.claude/contexts/render/index.md"
  printf '# old protocol\n' > "$d/.claude/contexts/tools/context-updater.md"
  printf '#!/bin/sh\n' > "$d/.claude/hooks/context-first.sh"
  printf '{ "hooks": { "UserPromptSubmit": [ { "hooks": [ { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/context-first.sh" } ] } ] } }\n' > "$d/.claude/settings.json"
  printf '# ADRs\n\nProtocol: [doc](../../.claude/contexts/tools/documentation-maintenance.md)\n' > "$d/docs/adr/README.md"
  printf '.tmp/*\n!.tmp/.gitkeep\n.claude/*\n!.claude/settings.json\n!.claude/contexts/\n!.claude/hooks/\n!.claude/skills/\n' > "$d/.gitignore"
  git_quiet -C "$d" add -A
  git_quiet -C "$d" commit -m "original setup"
}

orig="$work/original"; original_repo "$orig"
out=$("$here/install.sh" monorepo "$orig" 2>&1 < /dev/null; echo "exit=$?")
has "the original setup is detected" "$out" "This repo has an older agent setup"
has "each finding is named" "$out" ".claude/contexts/ — the knowledge base now lives in .agent/contexts/"
has "without a terminal and without --migrate, nothing changes" "$out" "Nothing changed."
if [ -d "$orig/.claude/contexts" ] && [ ! -e "$orig/AGENTS.md" ] && [ -z "$(git -C "$orig" status --porcelain)" ]; then
  ok "declining leaves the repo untouched"
else
  bad "declining leaves the repo untouched" "$(git -C "$orig" status --porcelain)"
fi

out=$("$here/install.sh" monorepo "$orig" --migrate 2>&1 < /dev/null; echo "exit=$?")
has "--migrate migrates without asking" "$out" "Migrated (originals under .tmp/migration-"
has "migration exits 0" "$out" "exit=0"
[ -f "$orig/.agent/contexts/render/index.md" ] && [ ! -e "$orig/.claude/contexts" ] &&
  ok "the knowledge base moved to .agent/contexts" || bad "the knowledge base moved to .agent/contexts"
mig=$(ls -d "$orig"/.tmp/migration-* 2>/dev/null | head -n 1)
[ -f "$mig/CLAUDE.md" ] && [ -f "$mig/.claude/hooks/context-first.sh" ] && [ -f "$mig/.claude/settings.json" ] &&
  ok "everything replaced is kept under .tmp/migration-*" || bad "everything replaced is kept under .tmp/migration-*"
[ -f "$mig/template/docs/adr/README.md" ] && ok "the template's version of a kept file is saved for the finish step" ||
  bad "the template's version of a kept file is saved for the finish step"
has "the old process docs are kept for the finish step" "$(cat "$mig/.claude/contexts/tools/context-updater.md" 2>/dev/null)" "old protocol"
has "the new process docs are installed" "$(cat "$orig/.agent/contexts/tools/context-updater.md")" "When changes happen"
has "CLAUDE.md is the new adapter" "$(head -n 1 "$orig/CLAUDE.md")" "@AGENTS.md"
has "settings.json wires the new hook" "$(cat "$orig/.claude/settings.json")" ".agent/hooks/context-first.sh"
[ ! -e "$orig/.claude/hooks" ] && ok "the old hook folder is gone" || bad "the old hook folder is gone"
agents=$(cat "$orig/AGENTS.md")
has "the project name is carried into AGENTS.md" "$agents" "# AGENTS.md — Vidaldi Engine"
has "project area rows are carried with new paths" "$agents" "| [render/](.agent/contexts/render/index.md) | the render pipeline and frame timing |"
[ "$(grep -c '^| \[dev/\]' "$orig/AGENTS.md")" = 1 ] && ok "template rows are not duplicated" || bad "template rows are not duplicated"
render=$(cat "$orig/.agent/contexts/render/index.md")
has "links inside contexts point to .agent/contexts" "$render" '`.agent/contexts/render/index.md`'
has "links to the instructions file point to AGENTS.md" "$render" "[AGENTS.md](../../../AGENTS.md)"
has "links outside contexts are rewritten too" "$(cat "$orig/docs/adr/README.md")" ".agent/contexts/tools/documentation-maintenance.md"
gi=$(cat "$orig/.gitignore")
lacks "the old gitignore exceptions are dropped" "$gi" '!.claude/contexts/'
has "the new gitignore block is added" "$gi" "# >>> human-in-the-loop-agentic-setup"
has "docs without Covers: are counted for the finish step" "$out" "context docs have no Covers: line yet"
has "the next step is finishing the migration with an agent" "$out" "Finish the migration per .agent/contexts/tools/bootstrap.md"
out=$(cd "$orig" && .agent/hooks/context-first.sh --format text)
has "the hook sees the migrated areas" "$out" "dev, render, tools"
out=$("$here/install.sh" monorepo "$orig" 2>&1 < /dev/null)
lacks "after migrating, a re-run finds nothing to migrate" "$out" "older agent setup"

plain="$work/plain-claude"; new_repo "$plain"
printf '# Notes\n\nUse tabs.\n' > "$plain/CLAUDE.md"
out=$("$here/install.sh" single-repo "$plain" 2>&1 < /dev/null)
has "a CLAUDE.md without the import is a finding" "$out" "CLAUDE.md doesn't import AGENTS.md"
"$here/install.sh" --migrate single-repo "$plain" >/dev/null 2>&1 < /dev/null
has "migrating it adds the import on top" "$(head -n 1 "$plain/CLAUDE.md")" "@AGENTS.md"
has "and keeps its content below" "$(cat "$plain/CLAUDE.md")" "Use tabs."

printf '\n== merge-strategy check\n'
hint_repo="$work/hint"; new_repo "$hint_repo"
out=$("$here/install.sh" single-repo "$hint_repo" 2>&1)
has "merge commits are recommended for PR stacks" "$out" "Recommended: merge commits"
has "no remote → the settings URL pattern" "$out" "https://github.com/<owner>/<repo>/settings"
has "keeping another strategy points at the repo profile" "$out" 'set "Stack merge" in .agent/repo.md'
for pair in \
  "git@github.com:acme/app.git|https://github.com/acme/app/settings" \
  "https://github.com/acme/app.git|https://github.com/acme/app/settings" \
  "https://github.com/acme/app/|https://github.com/acme/app/settings" \
  "ssh://git@github.com:22/acme/app.git|https://github.com/acme/app/settings" \
  "https://token@github.example.com/acme/app|https://github.example.com/acme/app/settings" \
  "git@gitlab.com:group/sub/proj.git|https://gitlab.com/group/sub/proj/-/settings/merge_requests"; do
  remote=${pair%%|*}; expect=${pair#*|}
  git -C "$hint_repo" remote remove origin >/dev/null 2>&1
  git -C "$hint_repo" remote add origin "$remote"
  out=$("$here/install.sh" single-repo "$hint_repo" 2>&1)
  has "origin $remote → $expect" "$out" "$expect"
done

junk_tpl="$work/template-with-os-junk"
cp -R "$here" "$junk_tpl"
touch "$junk_tpl/core/.DS_Store" "$junk_tpl/core/docs/._README.md" "$junk_tpl/variants/monorepo/Thumbs.db"
junk_repo="$work/junk"; new_repo "$junk_repo"
"$junk_tpl/install.sh" monorepo "$junk_repo" >/dev/null 2>&1
junk=$(find "$junk_repo" -path "$junk_repo/.git" -prune -o \( -name .DS_Store -o -name '._*' -o -name Thumbs.db -o -name desktop.ini \) -print)
[ -z "$junk" ] && ok "OS metadata files are never installed" || bad "OS metadata files are never installed" "$junk"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
