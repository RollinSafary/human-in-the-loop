# Human Decisions (`human-decisions`)

When the agent stops for the human, and how it asks. The agent owns execution; the human owns
decisions that need judgement, ownership, or acceptance of a trade-off. A question that the code,
the contexts or a convention can answer is not a question for the human — answer it and state the
assumption.

## Ask — always

| Class | Examples |
| --- | --- |
| **Hard to reverse** | a cross-unit contract, a data migration, a public API, a dependency that shapes the architecture |
| **Trade-off between credible options** | two approaches that both work and differ on performance, memory, scalability, cost or UX |
| **Conflicting evidence about intent** | code, comments, docs, ADRs and callers disagree about what something is supposed to do ([evidence-conflicts.md](evidence-conflicts.md)) |
| **Scope change** | the task as stated can't be done as stated, or doing it right needs work outside it |
| **The shared record** | landing or abandoning an ADR step, an `ISSUES.md` entry leaving by acceptance, fixing unrelated context drift |
| **Another task in flight** | a possible collision — ignore, quick look, or full investigation — and then a confirmed one ([concurrent-work.md](concurrent-work.md)) |
| **Outside actions** | push, open PRs, publish, release, delete branches/tags, anything visible to others — unless asked for in this task |
| **Disagreeing with review** | a self-review finding the implementer believes is wrong |

## Don't ask — decide and say so

Reversible choices with a clear convention: naming that follows the code, which file a helper goes
in, test structure, the order of independent steps, a refactor inside the task's footprint. Make the
call; one line in the report or the record says what was assumed. Context operations at landing are
in this class too: done without asking, reported with their reasons.

## The decision request

One message, readable in one pass, decidable without re-reading the conversation:

```
Decision needed: <the question, one line>
Why now: <what is blocked until it is answered>
Evidence: <the facts, each with a file:line / commit / measurement>
Options:
  A — <approach> · gains: <…> · costs: <…> · reversible: <yes / at cost X / no>
  B — <approach> · gains: <…> · costs: <…> · reversible: <…>
Recommendation: <A>, because <the ranked criterion it wins on, and what it gives up>
Meanwhile: <what I will keep doing that does not depend on this — or "stopped">
```

- **Options are real alternatives**, each one the agent would carry out if chosen. Two minimum
  where a choice exists; "do it / don't" is fine for a yes-no gate.
- **Evidence, not impressions.** Every claim carries a reference or a measurement. Unknowns are
  labelled unknown.
- **The recommendation names its criterion.** "B is cleaner" is not a reason; "B keeps p95 under the
  200 ms budget at the cost of 60 MB" is.
- **Group what can be decided together.** Several independent questions go in one message, numbered,
  so the human answers once.
- The answer is recorded where it will be read again: the task record (`Landed`/`Ruled out`), the
  ADR step's Options/Decision, or the PR body.

## When the human is away

If nobody is there to answer (a scheduled run, an unanswered request): take the recommended option
for anything **reversible**, write the assumption at the top of the task record and the report, and
continue. For anything **irreversible** or outside the repo, do the preparatory work, leave the
decision request as the first thing in the report, and stop at that point.
