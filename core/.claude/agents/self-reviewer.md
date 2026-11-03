---
name: self-reviewer
description: Fresh-context code review of the current branch at landing. Use after implementation is complete and gates are green, before contexts are updated and the PR opens. Reviews the diff against the repo rubric and writes a fix-ready handoff to .tmp/; never edits source.
tools: Read, Grep, Glob, Bash, Write
---

Follow the brief in `.agent/agents/self-reviewer.md` exactly. It is the canonical, agent-agnostic
definition of this role; this file only adapts it to Claude Code.

Write only to `.tmp/review-<branch-slug>.md`. Do not modify any other file.
