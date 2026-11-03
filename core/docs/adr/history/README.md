# Decision history

One file per decision step, in the order they were made. **These are the record, not the current contract** — read [the topic docs](../README.md#topics) for what is true now.

A step is frozen once its task lands (the user is asked first) and is never edited afterwards; a later change is a new step. The reasoning, the measurements and the rejected alternatives live here, which is why a topic doc can stay short.

| # | Step | Date | Folded into |
| --- | --- | --- | --- |

<!-- Step template — history/NNNN-kebab-title.md:

# NNNN — <the decision, stated as a sentence>

**Status:** Draft
**Branch:** <git branch, verbatim>
**Affects:** `<path glob>`, … — <contracts/behaviours>

## Context
<the problem and the constraints that make it a decision>

## Criteria
Ranked before anything is tried: <criterion 1> → <criterion 2> → …

## Options

### A — <approach> — dead | chosen | viable, not chosen
<what was seen, with the measurement; for viable-not-chosen: "Revisit if <condition>">

## Decision
<what is settled; constraints later work must honour>

## Progress
<light-tier shape while Draft — deleted at landing>

Reconstructed steps (bootstrap) replace Branch/Affects with `**Provenance:** reconstructed` and add
`## Evidence` and `## Unknown` sections.

-->
