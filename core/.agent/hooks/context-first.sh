#!/usr/bin/env bash
# Session-start context, for any agent.
#
# Prints what an agent must know before acting on a request in this repo: which saved-context areas
# exist, the current branch's task-progression record (light .tmp/ file or Draft ADR step), and the
# tasks running in other worktrees. Agents with a prompt hook get it injected automatically
# (Claude Code: .claude/settings.json; Codex: .codex/hooks.json); others run it as their first act
# (AGENTS.md, "Session start"). Areas are discovered at runtime, so adding one needs no change here.
#
# Usage: context-first.sh [--format text|json] [--event UserPromptSubmit|SessionStart] [--source compact]
#   text  plain text on stdout (default; for agents without a JSON hook protocol)
#   json  Claude Code hook output: {"hookSpecificOutput":{"hookEventName":…,"additionalContext":…}}
#
# Never blocks a prompt: any failure exits 0 with no output. Written as facts, not imperatives —
# Claude Code wraps hook context in a system reminder and treats imperative text with suspicion.

set -u

script_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=../lib/common.sh
. "$script_dir/../lib/common.sh" 2>/dev/null || exit 0

format=text
event=UserPromptSubmit
source=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --format) format=${2:-text}; shift 2 ;;
    --event)  event=${2:-UserPromptSubmit}; shift 2 ;;
    --source) source=${2:-}; shift 2 ;;
    *) shift ;;
  esac
done

json_escape() {
  # Backslash, quote and tab escaped; lines joined with a literal \n.
  sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e "s/$(printf '\t')/\\\\t/g" \
    | awk '{ printf "%s%s", (NR > 1 ? "\\n" : ""), $0 }'
}

build_message() {
  local root ctx areas="" d branch records rec now goal lines="" others

  root=$(agent_root "$script_dir") || return 1
  ctx="$root/.agent/contexts"
  [ -d "$ctx" ] || return 1

  for d in "$ctx"/*/; do
    [ -f "${d}index.md" ] || continue
    d=${d%/}
    areas="${areas:+$areas, }${d##*/}"
  done
  [ -n "$areas" ] || return 1

  lines="Saved contexts exist under .agent/contexts/ (navigator: .agent/contexts/index.md) for these areas: $areas. Per AGENTS.md, the docs of any area this request touches are loaded before acting on it; if none apply, work proceeds normally. Repo paths and commands: .agent/repo.md."

  branch=$(current_branch "$root")
  records=$(task_records "$root" "$branch")
  if [ -n "$records" ]; then
    while IFS= read -r rec; do
      [ -n "$rec" ] || continue
      now=$(record_field "$root/$rec" Now)
      case "$rec" in
        .tmp/*) lines="$lines
Task-progression record for branch $branch: $rec${now:+ — Now: $now}." ;;
        *)      lines="$lines
ADR step in Draft for branch $branch: $rec${now:+ — Now: $now}." ;;
      esac
    done <<EOF
$records
EOF
    lines="$lines
Per AGENTS.md, the record is read before any other action and continued rather than restarted; it holds the plan, the Affects footprint, what was ruled out and why, and where the task stands."
  fi

  others=$(other_worktrees "$root" | while IFS="$(printf '\t')" read -r path obranch; do
    [ -n "$obranch" ] || continue
    rec=$(task_records "$path" "$obranch" | head -n 1)
    [ -n "$rec" ] || continue
    goal=$(record_field "$path/$rec" Goal)
    printf '%s\n' "$obranch${goal:+ ($goal)}"
  done | join_list 5)
  if [ -n "$others" ]; then
    lines="$lines
Other worktrees have tasks in flight: $others. Before editing shared code, .agent/bin/worktree-overlap compares footprints (protocol: .agent/contexts/tools/concurrent-work.md)."
  fi

  if [ "$source" = "compact" ]; then
    lines="$lines
The conversation was just compacted. Per AGENTS.md (Compaction), the task record and the area index of every previously loaded context are re-read before the next edit."
  fi

  printf '%s\n' "$lines"
}

msg=$(build_message 2>/dev/null) || exit 0
[ -n "$msg" ] || exit 0

if [ "$format" = "json" ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"},"suppressOutput":true}\n' \
    "$event" "$(printf '%s\n' "$msg" | json_escape)"
else
  printf '%s\n' "$msg"
fi
exit 0
