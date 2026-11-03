# Known issues

Open defects, each one found by something in the suite and reproducible by hand. One entry per
defect; an entry is deleted when the defect is fixed, or when it is measured, bounded and
deliberately accepted, because git history is the record of what was once wrong and this file is the
record of what still is.

Environment facts that are **not** defects — a target that lacks a capability, a platform quirk the
code already works around — belong in the test machinery docs (path: `.agent/repo.md`, "Tests") and
are deliberately not repeated here.

Every entry carries a **Verify** line: the command that reproduces it, and the command a fix is
checked with before the whole suite is worth running. Where the check is a scenario it lives in the
known-issues spec (path: `.agent/repo.md`) stating the behavior the code is *supposed* to have,
marked as an expected failure (`test.fail()`; `it.fails` in vitest). So an open defect is an expected
failure and the suite stays green, and the moment a fix lands the runner reports "expected to fail,
but passed" and turns the run red.

That red means **move the scenario, do not delete it.** A slow-tier scenario goes to the regressions
spec with the marker removed; a fast-tier one stays beside its subject and only the marker comes off.
The symptom and the cause go into the commit that fixes it. A reproduction is expensive to find and
trivial to lose, and it only becomes a regression test at the moment it starts passing — deleting it
then throws away the one thing standing between the fix and its own quiet reversal. The entry itself
goes; the assertion stays forever.

An entry can also leave **by decision rather than by fix** — a human decision
(`.agent/contexts/tools/human-decisions.md`). When the behavior is measured, bounded and judged
acceptable, it stops being a defect and becomes a stated tolerance: the scenario still moves to the
regressions spec, asserting the bound instead of the exactness and losing the marker, and the promise
it now carries is written where the contract lives — the doc unit's own docs. What is never
acceptable is widening a gate until a red goes away.

A third exit is **parking**, and it belongs only to a defect nobody can reproduce: a symptom seen
once, hunted deliberately, not seen again, and left with an instrument that will name it if it
returns. It leaves with what was learned written into the commit that removes it, and it comes back
the day the symptom does. Parking is not a quiet exit for a defect that is merely tiresome to chase.

New entries are added at landing and reported to the user (`.agent/contexts/tools/landing.md`, step 4).
Entries are numbered once and never reused.

---

<!-- Entry template:

## <n>. <the symptom, as a user would notice it>

**Where:** <doc unit / file / subsystem>
**Found by:** <the scenario or run that exposed it>
**Cause:** <what is known; "unknown" is allowed — say what was ruled out>
**Verify:** `<command that reproduces it>` · scenario: `<path>` — "<test name>"

-->

_No open issues._
