#!/usr/bin/env bash
# Edit guard — a PreToolUse hook for file edits (Claude Code: Edit, Write, MultiEdit).
#
# Before a file is edited, checks whether it lies in another task's footprint (what that worktree
# changed, or declared in `Affects:`) without the user having decided on that collision. If so, it
# denies the edit with the reason, so the agent asks the user first — ignore, quick look, or full
# investigation (.agent/contexts/tools/concurrent-work.md). A path the user chose to ignore passes.
#
# Reads only what worktree-overlap last cached under .tmp/.collisions/ (refreshed on every prompt),
# so it adds no measurable time to an edit. Never blocks anything it cannot read: no payload, no
# cache, or no match → allow, silently.

set -u

script_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=../lib/common.sh
. "$script_dir/../lib/common.sh" 2>/dev/null || exit 0

payload=$(read_hook_payload)
path=$(json_field "$payload" file_path)
[ -n "$path" ] || exit 0

root=$(agent_root "$script_dir") || exit 0
state="$root/.tmp/.collisions"
[ -s "$state/footprints" ] || exit 0
# git reports the physical root; resolve the edited file's directory the same way (macOS /var →
# /private/var and similar symlinks), falling back to the path as given for not-yet-created dirs.
case "$path" in
  /*) dir=$(cd "$(dirname "$path")" 2>/dev/null && pwd -P) && path="$dir/$(basename "$path")" ;;
esac
rel=${path#"$root"/}

# Tasks whose footprint holds this path and whose ignore does not cover it. Ignores are
# "<task>\t<files,…>\t<uses;…>\t<conflict>" lines in $state/ignored.
ignored="$state/ignored"
[ -f "$ignored" ] || ignored=/dev/null
blocking=$(awk -F '\t' -v p="$rel" -v ign="$ignored" '
  FILENAME == ign { n = split($2, a, ","); for (i = 1; i <= n; i++) ok[$1 SUBSEP a[i]] = 1; next }
  $2 == p && !(($1 SUBSEP p) in ok) { print $1 }
' "$ignored" "$state/footprints" 2>/dev/null | sort -u | paste -sd, - | sed 's/,/, /g')
[ -n "$blocking" ] || exit 0

reason="Possible collision: $rel is in the footprint of $blocking, and the user has not decided on it yet. Per .agent/contexts/tools/concurrent-work.md the user chooses: ignore, quick look, or full investigation. After the user chooses ignore, running .agent/bin/worktree-overlap ignore <branch> --path $rel records it and this edit can proceed."
reason=$(printf '%s' "$reason" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$reason"
exit 0
