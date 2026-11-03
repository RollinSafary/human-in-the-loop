# Test Authoring Standards (`test-authoring`)

How tests are designed in this repo. Load before writing or reviewing any test — either tier. Line numbers drift; the symbol names beside them are the durable reference.

The suite is a **regression safety net**: scenario tests that state what a user would notice broken, so a change anywhere shows up as a specific red rather than a surprise in production. It is not a unit-test suite and does not chase coverage.

**Scope split with the test machinery docs** (path: `.agent/repo.md`, "Tests"): this doc is the principles — *how to design a test*. The machinery — runner projects, capture helpers, goldens, fixture layout, commands — lives in the README and is linked, never repeated.
<!-- setup: fill the cost column below; runners, commands and paths live in .agent/repo.md. -->

## Where a claim goes

| Tier | Runner | Cost per run | What it proves |
| --- | --- | --- | --- |
| **fast** | per repo profile | <~seconds> | pure logic and arithmetic — anything with no real runtime underneath |
| **slow** | per repo profile | <~tens of seconds per spec> | behavior that only exists in the real runtime |

One decision rule: **a claim goes to the slow tier only if proving it needs the real runtime** — as the repo profile defines it (a real browser, a real database, the network, real time, …). Anything provable as arithmetic goes to the fast tier. Moving a claim down a tier is a win in its own right: the feedback loop is what keeps a suite run.

## Principles

Cited in review by number ("violates #5"). Each: rule → why.

**1 — Scenario over unit.** A test states something a user would notice broken — a page stuck on its loading state, a saved form that comes back empty, a payment recorded twice — not an internal call sequence. Internal sequencing is free to change; what the user sees is not. The fast tier is the deliberate exception: pure logic whose failure no scenario can show.

**2 — Right tier for the claim.** See the decision rule above. Choosing the slow tier out of habit costs the feedback loop; choosing the fast tier for something that actually needs the runtime proves nothing.

**3 — Measure, then assert.** No invented tolerance, ever. Every numeric gate is set by running the real thing, recording the worst honest value, and asserting with stated headroom — and the measurement is written beside the gate so the margin stays auditable (a `worst seen | asserted` table next to the constant). A gate is only trustworthy if the *failure* score is also known: if a pass scores ~1 and a real breakage scores 8, a ceiling of 3 has an eightfold gap between noise and signal.

**4 — Properties over samples.** Where the subject has a symmetry, assert the symmetry: invertibility (identity at zero, reverses itself, composes), mirror and point-symmetry, tiling with no gap or overlap, agreement with an independent second implementation. A property pins the whole function; a sample pins a point.

**5 — A relative claim needs an absolute anchor.** Any comparison of two outputs — parity, cross-target agreement, before/after — is satisfied by two identical failures. Assert each side is *alive* first: nothing still pending before capturing, a spread or size above a floor so an empty or flat output cannot pass the comparison.

**6 — Prove the gate can fail.** Hard rule for tolerance/threshold gates and relative claims: after writing one, break the subject once, watch the gate go red, restore. A `< 3` ceiling proves nothing until a real breakage's score is known (#3's other half). Recommended but not required for exact assertions (`toEqual` against a literal), where the failure mode is visible by inspection.

**7 — Assert through the public surface.** Tests restate the shapes they read instead of importing internals, so a refactor the suite should catch cannot silently co-evolve the test with it. Across a process or serialization boundary this is also physics: the restated types document what actually survives the crossing.

**8 — The why lives next to the assertion.** Every constant documents how its value was chosen; every gate says what it protects. A bare "response has an id" reads as trivia and gets relaxed in review; the same line labelled with the race it guards reads as load-bearing. A comment earns its place by making the test *readable* — what a step is for, why this value and not another, what a reader would otherwise mistake an assertion for. It does not narrate the test's own history: a defect's date, symptom and cause belong in the commit that fixed it, where `git log` hands them to anyone who asks. Where a claim fits in an `expect` message, it goes there rather than into a comment — the message is the half a failing run prints. Same cap as production source, for the same reason: [code-review-standards.md](code-review-standards.md), "Comments & documentation".

**9 — Red is information; the test never bends.** Three legitimate exits from a failing test: fix the code; route it through the known-defect lifecycle (#10); or correct a test that was itself wrong, with the reasoning stated in the commit. "Adjust the expectation until green" is not on the list — a threshold widened to pass, an assertion deleted to pass, or a wait lengthened to pass is the suite being defeated by its own maintainer.

**10 — A defect's reproduction is never deleted.** While open: an `ISSUES.md` entry plus an expected-failure scenario (`test.fail()`, or `it.fails` in vitest), so the suite stays green and a fix turns it red ("expected to fail, but passed"). On fix: the marker comes off and the scenario stays — a slow-tier one **moves** to the regressions spec, a fast-tier one stays beside its subject, which is already the file its regressions live in. The symptom and cause go into the commit that fixes it, not into a comment block above the case (#8). On **acceptance** — the behavior measured, bounded, and judged not worth its fix — the same move happens with no red to prompt it: the scenario asserts the bound it was accepted at instead of the exactness it owed, states which number is the measurement and which is the promise, and the standing gate keeps pinning the measured one. Widening a gate until a red goes away is not that move. Full lifecycle: [ISSUES.md](../../../ISSUES.md) header. Caution that motivates it: most runners count an expected failure as *passed*, so the summary line never says how many scenarios are known-broken — `ISSUES.md` is the register that does.

**11 — Determinism is the suite's job.** Where the product runs on more than one target (browsers, platforms, backends, OSes), agreement is asserted by the tests themselves — every scenario runs on each target, and results are compared side by side. Never by a human or an agent eyeballing outputs.

**12 — Fixtures are addressable.** Fixture content is designed so a probe can *query* it: known values at known positions, one shared module so every test agrees on where things are. "Where did it go" becomes a lookup, not a diff of the whole output.

**13 — State you don't control is either pinned or covered.** Warm/cold, first-run/later-run, cache state, ordering. Defects hide there: a bug that reproduces only on a *cold* start, a race that never fires on the *first* run of a session. Repeat the scenario, revisit the same state twice. A scenario that only ever runs warm is half a scenario, and the halves fail differently.

## House style

- `expect` messages state the property in domain language — "a retried checkout must not create a second order", not "orders.length should be 1".
- Constants are named and documented with their derivation (#3, #8); no magic numbers in assertions.
- A capability a target lacks is an explicit skip with a reason (`test.skip(condition, reason)`) — never a silent pass.
- Repo lint rules apply to tests unchanged.
