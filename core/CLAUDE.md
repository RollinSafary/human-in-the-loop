@AGENTS.md

<!-- Claude Code adapter. AGENTS.md is canonical: keep this file to the import above plus
Claude-only notes. Claude reads AGENTS.md natively only when no CLAUDE.md exists, so this import is
what makes both files coexist. Claude-only wiring: .claude/settings.json (hooks, permissions),
.claude/agents/ (subagent adapters onto .agent/agents/). -->

## Claude Code specifics

- The session-start step runs automatically: `.claude/settings.json` wires
  `.agent/hooks/context-first.sh` to every prompt and to `SessionStart` after compaction.
- Self-review at landing uses the `self-reviewer` subagent (`.claude/agents/self-reviewer.md`),
  which runs the agent-agnostic brief in `.agent/agents/self-reviewer.md` in a fresh context.
