# Evidence Conflicts (`evidence-conflicts`)

What to do when the sources disagree about what something is supposed to do — the code says one
thing, a comment another, a context or ADR a third, and the callers rely on a fourth. Never resolve
it by picking the source that is most convenient for the task. Reconstruct how the expectation and
the implementation diverged, then bring the human a decision request.

## Three truths

| Truth | Question | Sources |
| --- | --- | --- |
| **Historical** | What was decided, and why? | ADR steps and topic docs, PR threads, commit messages, contexts |
| **Structural** | What does the code actually do today? | the implementation, its tests, a run |
| **Operational** | What does the rest of the system rely on it to do? | callers and their assumptions, load and latency expectations, scenarios that exercise it, product docs promised to users |

A conflict is a disagreement between any two. The operational truth carries the most weight when
choosing what to preserve, because it is what breaks when the choice is wrong — but it never
overrides a decision silently.

## Investigation

1. **State each claim with its source.** "Comment at `src/q.ts:40` `Queue.push` says ordered;
   implementation reorders by priority; `docs/adr/queue.md` says FIFO; 3 callers assume FIFO."
2. **Date them.** `git log -L :<symbol>:<file>` or `git log --follow -p <file>` for when the
   behaviour changed; `git blame` for the comment; the ADR step's date for the decision. Order the
   events: expectation set → implementation → change → callers added.
3. **Look for a recorded reason** for each change: an ADR step, a PR description, a commit body, an
   `ISSUES.md` entry. Git tells *when* and *who*; it tells *why* only if someone wrote it down.
   **Never assert a reason the evidence doesn't state** — write "reason not recorded".
4. **Map the dependents.** `git grep -n <symbol>` and the subsystem context's "Consumers &
   expectations". For each consumer: what it assumes, and what it would see if the behaviour changed.
5. **Measure where it matters.** If load or latency is part of the expectation, measure the current
   behaviour rather than reasoning about it.

## Classification

| Finding | Pattern | Usual recommendation |
| --- | --- | --- |
| **Initial defect** | implementation never met the expectation; callers built against the expectation | fix the code; reproduction into `ISSUES.md` first |
| **Regression** | met it once; a later change broke it without a recorded reason | fix the code; regression scenario |
| **Intentional evolution** | changed with a recorded reason; docs/comments/contexts lag behind | update the lagging sources (contexts at landing; comments in the change) |
| **Unexplained drift** | changed, no recorded reason, callers split between old and new behaviour | decision needed — this is the one most worth the human's time |
| **Obsolete expectation** | the expectation no longer matches how the system is used | propose retiring it: a new ADR step superseding the old one |

## Reporting

A decision request ([human-decisions.md](human-decisions.md)) whose Evidence section is the dated
timeline from step 2 and the dependents from step 4, whose options are the realistic resolutions
(fix code / update the record / supersede the decision), and whose recommendation rests on what the
dependents actually rely on — not on the comment or the code alone.

The resolution is recorded: a fix carries its scenario; a record update goes in the knowledge
packet; a superseded decision is a new ADR step. A comment that was wrong is corrected in the same
change.
