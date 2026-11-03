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

# symbols_from_diff — reads a unified diff on stdin; prints the identifiers it declares or encloses,
# sorted and unique. A language-agnostic heuristic: a changed line, or a hunk header's enclosing
# context, that starts (after modifiers such as export/pub/static) with a declaration keyword. Local
# const/let/var count only when unindented or exported. Names shorter than 4 characters are dropped.
symbols_from_diff() {
  awk '
    function scan(line,   t, indented, exported, name) {
      indented = (line ~ /^[ \t]/)
      t = line
      sub(/^[ \t]+/, "", t)
      exported = 0
      while (match(t, /^(export|default|declare|abstract|async|pub|public|private|protected|static|final|override|internal|open)[ \t]+/)) {
        if (substr(t, 1, 6) == "export" || substr(t, 1, 3) == "pub") exported = 1
        t = substr(t, RLENGTH + 1)
      }
      name = ""
      if (match(t, /^(function|class|interface|type|enum|namespace|module|struct|trait|def|func|fn)\*?[ \t]+\*?[A-Za-z_$][A-Za-z0-9_$]*/)) {
        name = substr(t, RSTART, RLENGTH)
      } else if ((!indented || exported) && match(t, /^(const|let|var)[ \t]+[A-Za-z_$][A-Za-z0-9_$]*/)) {
        name = substr(t, RSTART, RLENGTH)
      }
      if (name == "") return
      sub(/^[a-z]+\*?[ \t]+\*?/, "", name)
      if (length(name) >= 4) print name
    }
    /^@@/ { i = index(substr($0, 3), "@@"); if (i > 0) scan(substr($0, i + 5)); next }
    /^(\+\+\+|---)( |$)/ { next }
    /^[+-]/ { scan(substr($0, 2)) }
  ' | sort -u
}

# changed_symbols <root> <base> — symbols_from_diff over everything this worktree changed:
# committed since the merge base with <base>, and uncommitted.
changed_symbols() {
  local root=$1 base=$2
  {
    if [ -n "$base" ]; then
      git -C "$root" diff -U0 --no-color "$base...HEAD" -- 2>/dev/null
    fi
    git -C "$root" diff -U0 --no-color HEAD -- 2>/dev/null
  } | symbols_from_diff
}

# symbol_uses <root> <files-list> <symbols-list> [<suffix>] — "<file> uses `<symbol>`<suffix>" for
# every listed file (that exists in <root>) mentioning one of the symbols as a whole word.
symbol_uses() {
  local root=$1 files=$2 syms=$3 suffix=${4:-} f s
  [ -s "$syms" ] && [ -s "$files" ] || return 0
  while IFS= read -r f; do
    [ -n "$f" ] && [ -f "$root/$f" ] || continue
    grep -owF -f "$syms" "$root/$f" 2>/dev/null | sort -u | while IFS= read -r s; do
      printf '%s uses `%s`%s\n' "$f" "$s" "$suffix"
    done
  done < "$files"
}

# merge_conflicts <root> <ours> <theirs> — files that would conflict textually if the two commits
# merged, via `git merge-tree --write-tree` (no worktree touched). Returns 2 when this git is older
# than 2.38 and cannot tell.
merge_conflicts() {
  local out rc
  out=$(git -C "$1" merge-tree --write-tree --name-only --no-messages "$2" "$3" 2>/dev/null)
  rc=$?
  case "$rc" in
    0) return 0 ;;
    1) printf '%s\n' "$out" | sed 1d | sed '/^$/d' | sort -u; return 0 ;;
    *) return 2 ;;
  esac
}

# read_hook_payload — the JSON a hook receives on stdin, without ever blocking: an interactive
# terminal or a silent pipe yields nothing.
read_hook_payload() {
  local line payload=""
  [ -t 0 ] && return 0
  while IFS= read -r -t 1 line || [ -n "$line" ]; do
    payload="$payload$line"
    line=""
  done
  printf '%s' "$payload"
}

# json_field <json> <key> — the string value of a top-level-looking "key": "value" pair; enough for
# hook payloads (session_id, file_path), not a JSON parser.
json_field() {
  printf '%s' "$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n 1
}
