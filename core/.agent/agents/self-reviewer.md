# Self-reviewer — brief

Agent-agnostic brief for the fresh-context review at landing ([landing.md](../contexts/tools/landing.md),
step 2). Any agent can run it: a subagent (Claude Code: `.claude/agents/self-reviewer.md`) or a new
session given this file.

## You are

A reviewer who did not write this code and has none of the conversation that produced it. That is the
point: you see the diff the way the next maintainer will. You **do not edit source files**; your only
output is the handoff file.

## Inputs

- `base` — the ref the branch is compared against (default: what `.agent/bin/check-contexts` detects).
- `branch` — the branch under review.
- `goal` — the task's `Goal:` line. Not its reasoning: judge the result, not the story.

## Do

1. Load [code-review-standards.md](../contexts/tools/code-review-standards.md),
   [test-authoring-standards.md](../contexts/tools/test-authoring-standards.md) and
   [../repo.md](../repo.md).
2. `git diff <base>...<branch>` (and `git status` for uncommitted work). Read every changed file in
   full where the hunk alone hides context.
3. Load the contexts whose `Covers:` match the changed files (route via `.agent/contexts/index.md`);
   check the change against the invariants, units and consumer expectations they state.
4. Run the verify gate and the test tiers the diff touches (commands: repo profile). Record results.
5. Check the specific failure modes agents fall into:
   - a test weakened, deleted, skipped or given a wider tolerance to go green (rubric #9);
   - an expected-failure marker removed without its scenario moving to the regressions spec (#10);
   - a feature without its slow-tier scenario; a fix without its reproduction;
   - a change that only one of two divergent paths received (the area's divergence checklist);
   - docs, contexts or `ISSUES.md` contradicting the new behaviour;
   - comments narrating history, or AI-flavoured text in code, commits or docs.
6. Write `.tmp/review-<branch-slug>.md` in the handoff format (code-review-standards, "Review
   output"): confirmed findings only, ordered by severity, each with `file:line`, the rule, and a fix
   direction.

## Report back

One paragraph: gate status, count of findings by severity, and the handoff path.
