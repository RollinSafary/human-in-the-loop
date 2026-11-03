# shellcheck shell=bash
# Shared helpers for the .agent/ scripts. Sourced, never executed.
#
# Portability: bash 3.2 (macOS default) and Git Bash on Windows — no associative arrays, no mapfile,
# no ${var,,}; POSIX awk/sed only. Everything path-related goes through git so ignore rules and
# glob semantics are the same as the repo's.

# Sort/compare bytewise everywhere, so `comm` and `sort -u` agree across locales.
export LC_ALL=C

# agent_root <script_dir>
# The worktree the caller is in when it carries the setup, else the one the script lives in.
# Claude Code pins $CLAUDE_PROJECT_DIR to the session's starting root even inside another worktree,
# so the caller's working directory is the better signal.
agent_root() {
  local top
  top=$(git rev-parse --show-toplevel 2>/dev/null) || top=""
  if [ -n "$top" ] && [ -d "$top/.agent" ]; then
    printf '%s\n' "$top"
    return 0
  fi
  (cd "$1/../.." && pwd)
}

# current_branch <root> — empty when detached or not a repo.
current_branch() {
  local b
  b=$(git -C "$1" rev-parse --abbrev-ref HEAD 2>/dev/null) || b=""
  [ "$b" = "HEAD" ] && b=""
  printf '%s\n' "$b"
}

# branch_slug <branch> — "/" becomes "-": the key for .tmp/task-<slug>.md and .tmp/review-<slug>.md.
branch_slug() {
  printf '%s\n' "${1//\//-}"
}

# base_ref <root> — what "changed in this task" is measured against.
# $AGENT_BASE wins; then origin/HEAD; then the first of main/master that exists.
base_ref() {
  local root=$1 ref
  if [ -n "${AGENT_BASE:-}" ]; then
    printf '%s\n' "$AGENT_BASE"
    return 0
  fi
  ref=$(git -C "$root" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null) || ref=""
  if [ -n "$ref" ]; then
    printf '%s\n' "$ref"
    return 0
  fi
  for ref in main master origin/main origin/master; do
    if git -C "$root" rev-parse -q --verify "$ref^{commit}" >/dev/null 2>&1; then
      printf '%s\n' "$ref"
      return 0
    fi
  done
  printf '\n'
}

# changed_files <root> <base> — every file this worktree changed: committed since the merge base
# with <base>, staged, unstaged, and untracked (ignored files excluded). Sorted, unique.
changed_files() {
  local root=$1 base=$2
  {
    if [ -n "$base" ]; then
      git -C "$root" diff --name-only "$base...HEAD" -- 2>/dev/null
    fi
    git -C "$root" diff --name-only HEAD -- 2>/dev/null
    git -C "$root" diff --name-only --cached -- 2>/dev/null
    git -C "$root" ls-files --others --exclude-standard 2>/dev/null
  } | sort -u
}

# expand_globs <root> <glob>... — files (tracked or untracked, not ignored) matching git pathspec
# globs, where `**` crosses directories. Sorted, unique. No globs → no output.
expand_globs() {
  local root=$1
  shift
  [ "$#" -eq 0 ] && return 0
  local specs=() g
  for g in "$@"; do
    specs+=(":(glob)$g")
  done
  {
    git -C "$root" ls-files -- "${specs[@]}" 2>/dev/null
    git -C "$root" ls-files --others --exclude-standard -- "${specs[@]}" 2>/dev/null
  } | sort -u
}

# backticked_globs — reads one line on stdin, prints each backticked token before the first
# " — " (or " -- "), one per line. That prefix is the machine-read part of `Covers:` and `Affects:`;
# the prose after the dash is for humans.
backticked_globs() {
  local line
  IFS= read -r line || true
  line=${line%% — *}
  line=${line%% -- *}
  printf '%s\n' "$line" | awk '{
    s = $0
    while ((i = index(s, "`")) > 0) {
      s = substr(s, i + 1)
      j = index(s, "`")
      if (j == 0) break
      tok = substr(s, 1, j - 1)
      if (tok != "") print tok
      s = substr(s, j + 1)
    }
  }'
}

# record_field <file> <Field> — the value of a header line `Field: …` (light record) or
# `**Field:** …` (ADR step). First match only; leading spaces trimmed.
record_field() {
  local file=$1 field=$2
  [ -f "$file" ] || return 0
  awk -v f="$field" '
    index($0, f ":") == 1 { v = substr($0, length(f) + 2); sub(/^[ \t]+/, "", v); print v; exit }
    index($0, "**" f ":**") == 1 { v = substr($0, length(f) + 5); sub(/^[ \t]+/, "", v); print v; exit }
  ' "$file"
}

# task_records <root> <branch> — the light record path (if it exists) and every ADR step in Draft
# that names this branch, relative to <root>, one per line.
task_records() {
  local root=$1 branch=$2 slug
  [ -n "$branch" ] || return 0
  slug=$(branch_slug "$branch")
  [ -f "$root/.tmp/task-$slug.md" ] && printf '%s\n' ".tmp/task-$slug.md"
  # A Draft step is often still untracked, so list tracked and untracked ADR files, then match whole
  # lines (git grep has no whole-line fixed-string mode). A landed step keeps its Branch line, so
  # only steps still in Draft count.
  expand_globs "$root" '**/docs/adr/**/*.md' | while IFS= read -r f; do
    grep -qxF -- "**Branch:** $branch" "$root/$f" 2>/dev/null &&
      grep -qxF -- "**Status:** Draft" "$root/$f" 2>/dev/null &&
      printf '%s\n' "$f"
  done
  return 0
}

# other_worktrees <root> — "<path>\t<branch>" for every other live worktree of this repo.
other_worktrees() {
  local root=$1
  git -C "$root" worktree list --porcelain 2>/dev/null | awk -v self="$root" '
    /^worktree / { path = substr($0, 10); branch = ""; skip = 0; next }
    /^branch /   { branch = substr($0, 8); sub(/^refs\/heads\//, "", branch); next }
    /^bare$/ || /^prunable/ { skip = 1; next }
    /^$/ { if (path != "" && path != self && !skip) printf "%s\t%s\n", path, branch; path = "" }
    END  { if (path != "" && path != self && !skip) printf "%s\t%s\n", path, branch }
  '
}

# join_list <max> — joins stdin lines with ", ", showing at most <max> and a "+N more" tail.
join_list() {
  awk -v max="$1" '
    { n++; if (n <= max) out = (out == "" ? $0 : out ", " $0) }
    END { if (n > max) out = out ", +" (n - max) " more"; print out }
  '
}
