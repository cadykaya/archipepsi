# Brief for Codex — review the playtest, and bring your own solutions

Written by the engine lane (Prod) at `cd620f0`, branch
`claude/archipepsi-echoes-continuation-b1adno`, for an independent
review requested by Skyah.

## What this is

On 2026-09-13 the owner played a full default-scale Zone end to end for
the first time. It produced eighteen problems, one crash (fixed), two
retractions, and a set of design decisions. **You are being asked to
review all of it and produce 3–5 solutions of your own.**

**Independent confirmation is a real result.** A reviewer who checks the
path, finds the claimed repair addresses it, and says "close this one"
has done the more valuable thing. Disagreement is not a required output
and manufactured disagreement is not independence — insisting on it
produces a loop where each review invents a more sophisticated concern
and nothing is ever allowed to be finished.

What is wanted is fewer unresolved questions that matter to the player.
Where you do disagree, say so and say why; where you confirm, say that
plainly too.

*(An earlier revision of this brief said "a second reviewer who agrees
with the first is worth nothing". That instruction was wrong and is
withdrawn.)*

## Read in this order

1. `docs/PLAYTEST_SESSION_SYNTHESIS.md` — sections 1 to 6 only. What
   happened, what it taught us, and every problem in severity order.
   **Stop before section 7.**
2. `docs/PLAYTEST_DIAGNOSTIC_RESULT.md` — the raw findings log, written
   live, including both retractions and the corrections that followed.
3. **Form your own solutions before reading section 7 of the synthesis.**
   Then read it and say where Prod's five are wrong, incomplete, or
   solving the wrong problem.

That ordering matters. Prod's framing is load-bearing enough to
contaminate an independent reading, and the framing is exactly what
needs a second opinion.

## Ground rules, learned the hard way

**Distinguish measured claims from reasoned ones.** In this session the
engine lane formed five hypotheses by reading code and reasoning about
it. Four were wrong:

| claim | status |
|---|---|
| hazard drums are floating | **RETRACTED** — owner looked again; they are not |
| `pressure_routing` is unsolvable by construction | **RETRACTED** — plates linger 4 s, it is a routing puzzle |
| the exit portal is stranded | **WRONG** — probed; 5/5 fixtures have standable ground around it |
| the exit room has no doors | **WRONG** — an empty cut plan means defaults hold, not solid walls |
| `camera_ray` crashes on a detached player | **CORRECT** — and the only one verified against the defect before being believed |

Three further errors were found in the write-up by the independent
review and verified: **the countdown already exists**; **activity
completion requests `secret_found`, a name the tone bank does not
define**; and **keys DO immediately try to open matching locks**
(`_open_what_the_keys_allow()`). All three are corrected in the record.

A note on method, since the first draft of this brief over-corrected:
"reading code is unreliable, probing is reliable" was itself too broad.
The review found two real things by reading source. The difference is
what the reading is FOR — finding a design consequence of code that does
what it says is reliable; promoting the first plausible mechanism for an
observed symptom to a confirmed cause is not.

Every probe that was actually run returned a correct answer in minutes.
**Treat any claim in these documents that is not backed by a printed
measurement as a hypothesis.** Several are flagged as such; assume the
unflagged ones may be too.

**Known-good measurements you may rely on:**

- exit portal standable-ground probe: `5/16` positions in all five
  generated fixtures, on two opposite bearings — a portal correctly set
  in a doorway
- exit room wall probe: openings on both axis ends, walls at 4 m on the
  perpendicular, in all five fixtures
- the crash: reproduced, fixed, and the regression control verified by
  removing the fix and watching the suite exit 2
- 1526 Python tests, 19 offline Godot targets, three live-bridge suites
  green on the exact commit that contained all six correctness defects

## The ask

**3–5 solutions.** Prefer ones that address a cluster of problems rather
than one symptom. For each, state what it covers, roughly what it costs,
what could go wrong, and what would prove it worked.

Push hardest on these, where Prod is least confident:

1. **Is "one validator that plays the Zone" (S1) the right shape?** It
   is the largest proposal and the least prototyped. A flood-fill using
   the real movement law would have caught four of six correctness
   findings — but it is also the kind of thing that can be too
   permissive to prove anything, or too slow to run per-build. Is there
   a cheaper decisive test?
2. **The capability gate has no good answer yet.** Echoes are not AP
   items, so Archipelago cannot reason about them; Prod's proposals are
   "build Forge and let a conversion target a capability" or "forbid
   gates in front of AP Checks, allow them in front of local rewards."
   Both are plausible and neither is obviously right. A third option
   would be valuable.
3. **Legibility as a schema obligation (S3)** may be over-engineering.
   Note that the countdown already exists and the completion tone is one
   wrong string (`secret_found` against a bank defining `secret`), so the
   job is smaller than the first draft assumed — but a check asserting
   every requested tone name resolves in the bank would have caught that
   at build time, where a textual check for `tones.play()` would not.
4. **The activity system** is being cut from four families to two on the
   owner's ruling, with a plan to keep the plate's 4-second linger as a
   gating mechanic. Is that the right cut? What should replace what is
   lost?

## Out of scope — these are the owner's decisions, not a reviewer's

Record options and trade-offs, do not decide:

- whether activities should gate AP-relevant progression
- what a map should be and show
- whether capabilities become AP items
- whether `timed_run` and `pressure_routing` survive
- whether a `fit_low_gap` capability is worth its cost
- difficulty for new players

## Context you will need

- **Load-bearing rule, no exceptions:** a physical gate the matching AP
  location logic does not declare may never exist. Archipelago may put
  another player's progression item in any Check.
- Archipelago owns randomized truth; Python owns deterministic
  campaign/save/allocation/fold truth; Epsilon emits validated
  structured creative interpretation only; Godot simulates, renders, and
  sends player intents.
- Generated artifacts are regenerated from source, never hand-edited,
  and a test is never weakened merely to pass it.
- Prod owns the engine and the placement evidence; Dess owns the bridge
  lane (`topology.py`, `schemas/`); Arty owns art. Findings in
  `topology.py` and `schemas/zone.py` are Dess's to act on.

## One thing worth knowing about the tone of the record

The findings log contains its own retractions rather than quiet edits,
because a record that hides its wrong turns teaches the next reader
nothing. If you find more errors in it — and there may well be more —
adding them in the same style is the useful contribution.
