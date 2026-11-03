#!/usr/bin/env bash
# Installs the human-in-the-loop agentic setup into a target repository.
#
# Usage: ./install.sh <monorepo|single-repo> <target-dir> [--with-codex] [--migrate]
#        ./install.sh --help
#
#   --with-codex  also install the Codex adapter (.codex/)
#   --migrate     migrate an older setup found in the target without asking
#
# Options may come before, between or after the two arguments. Copies core/ (shared by both
# shapes), then variants/<shape>/ (repo profile + Claude Code autonomy profile), then
# adapters/codex/ when asked. Never overwrites: a file the target already has is kept and listed
# for a hand merge (identical files are skipped silently). Appends the .gitignore block once.
# Safe to re-run.
#
# Migration: when the target still runs the original setup (.claude/contexts/, .claude/hooks/,
# CLAUDE.md as the instructions file), or has a CLAUDE.md that doesn't import AGENTS.md,
# installing over it would leave two setups side by side. The installer says what it found and
# asks; declining changes nothing. Without a terminal to ask on, it needs --migrate. Everything a
# migration replaces is kept under .tmp/migration-<timestamp>/.

set -eu

usage() {
  awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"
}

die_usage() {
  [ -n "${1:-}" ] && echo "install: $1" >&2
  usage >&2
  exit 2
}

# --- arguments ------------------------------------------------------------------------------------

variant=""
target=""
with_codex=0
migrate=ask
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)    usage; exit 0 ;;
    --with-codex) with_codex=1 ;;
    --migrate)    migrate=yes ;;
    -*)           die_usage "unknown option '$1'" ;;
    *)
      if [ -z "$variant" ]; then variant=$1
      elif [ -z "$target" ]; then target=$1
      else die_usage "unexpected argument '$1'"
      fi ;;
  esac
  shift
done
[ -n "$variant" ] && [ -n "$target" ] || die_usage "needs a shape and a target directory"

here=$(cd "$(dirname "$0")" && pwd)
case "$variant" in
  monorepo|single-repo) ;;
  *) die_usage "unknown shape '$variant' (monorepo | single-repo)" ;;
esac
[ -d "$target" ] || { echo "install: target '$target' is not a directory" >&2; exit 2; }
target=$(cd "$target" && pwd)
is_repo=0
if git -C "$target" rev-parse --git-dir >/dev/null 2>&1; then
  is_repo=1
else
  echo "install: warning — $target is not a git repo; the scripts rely on git." >&2
fi

# --- helpers --------------------------------------------------------------------------------------

# replace_in <file> <from> <to> — literal, every occurrence; returns 1 when <from> isn't there.
# Rewrites in place through cat so the file keeps its permissions; no sed -i (GNU/BSD differ).
replace_in() {
  local file=$1 from=$2 to=$3
  grep -qF -- "$from" "$file" || return 1
  awk -v a="$from" -v b="$to" '{
    out = ""; s = $0
    while ((i = index(s, a)) > 0) { out = out substr(s, 1, i - 1) b; s = substr(s, i + length(a)) }
    print out s
  }' "$file" > "$file.hitl-tmp"
  cat "$file.hitl-tmp" > "$file"
  rm -f "$file.hitl-tmp"
}

# markdown_files — every .md in the target (tracked or untracked, not ignored), relative paths.
markdown_files() {
  if [ "$is_repo" -eq 1 ]; then
    {
      git -C "$target" ls-files -- '*.md'
      git -C "$target" ls-files --others --exclude-standard -- '*.md'
    } | sort -u
  else
    (cd "$target" && find . -name '*.md' ! -path './node_modules/*' ! -path './.git/*' | sed 's|^\./||')
  fi
}

# --- detect an older setup ------------------------------------------------------------------------

findings=""
original=0
plain_claude_md=0
found() { findings="$findings    - $1"$'\n'; }

if [ -d "$target/.claude/contexts" ]; then
  original=1
  found ".claude/contexts/ — the knowledge base now lives in .agent/contexts/"
fi
if [ -f "$target/.claude/hooks/context-first.sh" ]; then
  original=1
  found ".claude/hooks/context-first.sh — replaced by .agent/hooks/context-first.sh"
fi
if [ -f "$target/CLAUDE.md" ] && ! grep -qxF '@AGENTS.md' "$target/CLAUDE.md"; then
  if grep -qF '.claude/contexts' "$target/CLAUDE.md"; then
    original=1
    found "CLAUDE.md is the original setup's instructions file — AGENTS.md takes over"
  else
    plain_claude_md=1
    found "CLAUDE.md doesn't import AGENTS.md — Claude Code would never read the new instructions"
  fi
fi

if [ -n "$findings" ] && [ "$migrate" = ask ]; then
  printf 'This repo has an older agent setup:\n%s' "$findings"
  if [ -t 0 ]; then
    printf 'Migrate it now? Everything replaced is kept under .tmp/. [y/N] '
    answer=""
    read -r answer || true
    case "$answer" in
      y|Y|yes|Yes|YES) migrate=yes ;;
      *) migrate=no ;;
    esac
  else
    migrate=no
  fi
  if [ "$migrate" = no ]; then
    printf '\nNothing changed. Installing over it would leave two setups side by side.\n'
    printf 'Re-run with --migrate when you want to migrate it.\n'
    exit 0
  fi
fi
[ -n "$findings" ] || migrate=no

# --- migrate, part 1: move the original setup out of the way --------------------------------------

mig_dir=""
mig_report=""
old_claude_md=""
reported() { mig_report="$mig_report  $1"$'\n'; }

# retire <relpath> — move a file or directory into the migration folder, keeping its path.
retire() {
  mkdir -p "$mig_dir/$(dirname "$1")"
  mv "$target/$1" "$mig_dir/$1"
}

if [ "$migrate" = yes ]; then
  stamp=$(date +%Y%m%d-%H%M%S)
  mig_dir="$target/.tmp/migration-$stamp"
  mig_rel=".tmp/migration-$stamp"
  mkdir -p "$mig_dir"
fi

if [ "$migrate" = yes ] && [ "$original" -eq 1 ]; then
  if [ -d "$target/.claude/contexts" ]; then
    if [ -e "$target/.agent/contexts" ]; then
      echo "install: both .claude/contexts/ and .agent/contexts/ exist — merge them by hand, then re-run." >&2
      exit 1
    fi
    n_docs=$(find "$target/.claude/contexts" -type f -name '*.md' ! -path '*/tools/*' | wc -l | tr -d ' ')
    mkdir -p "$target/.agent"
    mv "$target/.claude/contexts" "$target/.agent/contexts"
    reported "moved     .claude/contexts/ → .agent/contexts/ ($n_docs project docs)"
    if [ -d "$target/.agent/contexts/tools" ]; then
      mkdir -p "$mig_dir/.claude/contexts"
      mv "$target/.agent/contexts/tools" "$mig_dir/.claude/contexts/tools"
      reported "retired   the original process docs → $mig_rel/.claude/contexts/tools/"
    fi
  fi
  if [ -f "$target/.claude/hooks/context-first.sh" ]; then
    retire .claude/hooks/context-first.sh
    rmdir "$target/.claude/hooks" 2>/dev/null || true
    reported "retired   .claude/hooks/context-first.sh → $mig_rel/"
  fi
  if [ -f "$target/.claude/settings.json" ] &&
     grep -qF '.claude/hooks/context-first.sh' "$target/.claude/settings.json"; then
    retire .claude/settings.json
    reported "retired   .claude/settings.json → $mig_rel/ (its toolchain allowances are merged in the finish step)"
  fi
  if [ -f "$target/CLAUDE.md" ] && grep -qF '.claude/contexts' "$target/CLAUDE.md" &&
     ! grep -qxF '@AGENTS.md' "$target/CLAUDE.md"; then
    retire CLAUDE.md
    old_claude_md="$mig_dir/CLAUDE.md"
    reported "retired   CLAUDE.md → $mig_rel/ (AGENTS.md takes over)"
  fi

  n_links=0
  while IFS= read -r f; do
    [ -n "$f" ] && [ -f "$target/$f" ] || continue
    case "$f" in .tmp/*) continue ;; esac
    if replace_in "$target/$f" '.claude/contexts' '.agent/contexts'; then n_links=$((n_links + 1)); fi
  done <<EOF
$(markdown_files)
EOF
  # Inside the knowledge base, "CLAUDE.md" always meant the instructions file.
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    replace_in "$f" 'CLAUDE.md' 'AGENTS.md' || true
  done <<EOF
$(find "$target/.agent/contexts" -type f -name '*.md' 2>/dev/null)
EOF
  [ "$n_links" -gt 0 ] && reported "rewrote   links to .claude/contexts → .agent/contexts (files: $n_links)"

  gitignore="$target/.gitignore"
  if [ -f "$gitignore" ] && grep -qxE '!\.claude/(contexts|hooks)/' "$gitignore"; then
    grep -vxE '!\.claude/(contexts|hooks)/' "$gitignore" > "$gitignore.hitl-tmp" || true
    cat "$gitignore.hitl-tmp" > "$gitignore"
    rm -f "$gitignore.hitl-tmp"
    reported ".gitignore  dropped !.claude/contexts/ and !.claude/hooks/"
  fi
fi

# --- install --------------------------------------------------------------------------------------

copied=0
kept=""
n_template=0

# copy_tree <source-root> — every file under it, preserving relative paths, never overwriting.
# OS metadata (Finder's .DS_Store and ._* forks, Windows' Thumbs.db/desktop.ini) is never template
# content, and a template unpacked on a Mac always has some. During a migration, the template's
# version of every kept file is saved beside the originals, so the finish step can merge it.
copy_tree() {
  local src=$1 rel dest
  while IFS= read -r rel; do
    rel=${rel#./}
    [ -n "$rel" ] || continue
    dest="$target/$rel"
    if [ -e "$dest" ]; then
      if ! cmp -s "$src/$rel" "$dest"; then
        kept="$kept  $rel"$'\n'
        if [ -n "$mig_dir" ]; then
          mkdir -p "$mig_dir/template/$(dirname "$rel")"
          cp -p "$src/$rel" "$mig_dir/template/$rel"
          n_template=$((n_template + 1))
        fi
      fi
      continue
    fi
    mkdir -p "$(dirname "$dest")"
    cp -p "$src/$rel" "$dest"
    copied=$((copied + 1))
  done <<EOF
$(cd "$src" && find . -type f ! -name .DS_Store ! -name '._*' ! -name Thumbs.db ! -name desktop.ini | sort)
EOF
}

copy_tree "$here/core"
copy_tree "$here/variants/$variant"
[ "$with_codex" -eq 1 ] && copy_tree "$here/adapters/codex"

chmod +x "$target/.agent/hooks/context-first.sh" "$target/.agent/bin/"* 2>/dev/null || true

marker='# >>> human-in-the-loop-agentic-setup'
gitignore="$target/.gitignore"
if ! grep -qxF "$marker" "$gitignore" 2>/dev/null; then
  if [ -s "$gitignore" ] && [ -n "$(tail -c 1 "$gitignore")" ]; then
    printf '\n' >> "$gitignore"
  fi
  cat >> "$gitignore" <<'EOF'

# >>> human-in-the-loop-agentic-setup
# Scratch: task-progression records, review handoffs, migration leftovers — never committed.
.tmp/*
!.tmp/.gitkeep
# Claude Code: share settings.json and agents/; everything else in .claude/ stays personal.
.claude/*
!.claude/settings.json
!.claude/agents/
!.claude/skills/
# <<< human-in-the-loop-agentic-setup
EOF
  gitignore_note="appended"
else
  gitignore_note="already present"
fi

# --- migrate, part 2: carry what can be carried mechanically --------------------------------------

[ "$n_template" -gt 0 ] &&
  reported "saved     the template's version of each kept file → $mig_rel/template/ (files: $n_template)"

if [ -n "$old_claude_md" ] && grep -qxF '| Area | Load it when the task touches… |' "$target/AGENTS.md"; then
  rows="$mig_dir/area-rows.md"
  { grep -E '^\| \[[^]]+\]\(\.claude/contexts/' "$old_claude_md" || true; } |
    { grep -vE '^\| \[(dev|tools)/\]' || true; } |
    awk '{ gsub(/\.claude\/contexts\//, ".agent/contexts/"); print }' > "$rows"
  if [ -s "$rows" ]; then
    awk -v f="$rows" '
      { print }
      prev == "| Area | Load it when the task touches… |" && /^\| --- \| --- \|$/ && !done {
        while ((getline line < f) > 0) print line
        done = 1
      }
      { prev = $0 }
    ' "$target/AGENTS.md" > "$target/AGENTS.md.hitl-tmp"
    cat "$target/AGENTS.md.hitl-tmp" > "$target/AGENTS.md"
    rm -f "$target/AGENTS.md.hitl-tmp"
    reported "carried   area rows from the old CLAUDE.md into AGENTS.md (rows: $(grep -c . "$rows"))"
  fi
  name=$(sed -n 's/^# CLAUDE\.md — \(.*\)$/\1/p' "$old_claude_md" | head -n 1)
  if [ -n "$name" ] && [ "$name" != "<project-name>" ]; then
    replace_in "$target/AGENTS.md" '# AGENTS.md — <project-name>' "# AGENTS.md — $name" &&
      reported "carried   the project name into AGENTS.md"
  fi
fi

if [ "$migrate" = yes ] && [ "$plain_claude_md" -eq 1 ]; then
  { printf '@AGENTS.md\n\n'; cat "$target/CLAUDE.md"; } > "$target/CLAUDE.md.hitl-tmp"
  cp -p "$target/CLAUDE.md" "$mig_dir/CLAUDE.md"
  cat "$target/CLAUDE.md.hitl-tmp" > "$target/CLAUDE.md"
  rm -f "$target/CLAUDE.md.hitl-tmp"
  reported "CLAUDE.md  now imports AGENTS.md; your content stays below the import (original in $mig_rel/)"
fi

if [ "$migrate" = yes ] && [ -d "$target/.agent/contexts" ]; then
  no_covers=$(find "$target/.agent/contexts" -type f -name '*.md' ! -path '*/tools/*' \
    -exec grep -L '^Covers:' {} + 2>/dev/null | wc -l | tr -d ' ')
  [ "$no_covers" -gt 0 ] && reported "to do     $no_covers context docs have no Covers: line yet (finish step)"
fi

# --- report ---------------------------------------------------------------------------------------

remote=""
[ "$is_repo" -eq 1 ] && remote=$(git -C "$target" remote get-url origin 2>/dev/null) || true

# merge_settings_url <remote-url> — where the host's merge-method settings live, or a pattern when
# the host is unknown or there is no remote. Prints "<url>\t<what to check there>".
merge_settings_url() {
  local remote=$1 rest host path
  case "$remote" in
    git@*:*)             rest=${remote#git@}; host=${rest%%:*}; path=${rest#*:} ;;
    ssh://*)             rest=${remote#ssh://}; rest=${rest#*@}; host=${rest%%/*}; host=${host%%:*}; path=${rest#*/} ;;
    http://*|https://*)  rest=${remote#*://}; rest=${rest#*@}; host=${rest%%/*}; path=${rest#*/} ;;
    *)                   host=""; path="" ;;
  esac
  path=${path%/}
  path=${path%.git}
  case "$host" in
    *github*) printf 'https://%s/%s/settings\tPull Requests → "Allow merge commits"\n' "$host" "$path" ;;
    *gitlab*) printf 'https://%s/%s/-/settings/merge_requests\tMerge method → "Merge commit"\n' "$host" "$path" ;;
    *)        printf 'https://github.com/<owner>/<repo>/settings\tPull Requests → "Allow merge commits"  (GitLab: https://gitlab.com/<group>/<project>/-/settings/merge_requests)\n' ;;
  esac
}
merge_hint=$(merge_settings_url "$remote")
merge_url=${merge_hint%%"$(printf '\t')"*}
merge_where=${merge_hint#*"$(printf '\t')"}

printf 'Installed the %s setup into %s\n' "$variant" "$target"
printf '  %d files copied · .gitignore block %s%s\n' "$copied" "$gitignore_note" \
  "$([ "$with_codex" -eq 1 ] && printf ' · Codex adapter included')"
if [ -n "$mig_report" ]; then
  printf '\nMigrated (originals under %s/):\n%s' "$mig_rel" "$mig_report"
fi
if [ -n "$kept" ]; then
  printf '\nKept existing files (differ from the template — merge by hand):\n%s' "$kept"
fi
if [ -f "$target/.claude/settings.json" ] &&
   ! grep -qF '.agent/hooks/context-first.sh' "$target/.claude/settings.json"; then
  printf '\nYour .claude/settings.json was kept and does not wire .agent/hooks/context-first.sh —\n'
  printf 'copy the "hooks" block from variants/%s/.claude/settings.json into it.\n' "$variant"
fi

cat <<EOF

PR stacks — merge strategy
  Recommended: merge commits. A stack merges as a whole, top-down — each layer into the one below,
  then the bottom PR into the default branch — and merge commits keep every layer and every
  review-fix layer in history. Many repos turn merge commits off; check yours:
    $merge_url
      $merge_where
      and that no branch protection rule or ruleset requires linear history.
  Prefer squash or rebase? Keep it: set "Stack merge" in .agent/repo.md and the agent follows it.

Next:
  1. Review .claude/settings.json — it is an autonomy profile; tune it to how much you want the
     agent to do unattended (README, "Autonomy profile").
  2. Set your agent to auto-compact at ~200k tokens — the cost-effective point for this structure
     (Claude Code: autoCompactWindow, already in .claude/settings.json; Codex:
     model_auto_compact_token_limit, in .codex/config.toml with --with-codex; others: README).
EOF
if [ -n "$mig_report" ]; then
  cat <<EOF
  3. Open a fresh agent session in the repo and ask it to finish the migration:
       "Finish the migration per .agent/contexts/tools/bootstrap.md, 'Migrating from the original setup'."
     It carries your filled-in rules, settings and project facts into the new files, adds Covers:
     lines and symbol anchors to the contexts, and reports what it changed.
EOF
else
  cat <<EOF
  3. Open a fresh agent session in the repo and ask it to bootstrap:
       "Bootstrap the agent setup per .agent/contexts/tools/bootstrap.md."
     It fills .agent/repo.md and the placeholders below from the code, then proposes the areas.
  4. Remaining placeholders:
       git grep -n -e '<!-- setup' -e '<project-name>' -e '<One-line' -- AGENTS.md .agent docs ISSUES.md
EOF
fi
