# Archipepsi — v0.8 changelog

v0.5 through v0.7 were hardening passes: five hostile reviews, each finding
recorded here with its resolution. **v0.8 is not that.** It is one
deliberate widening, requested after the POC was built and played, and the
only system it touches is the Echo.

Everything else in the packet is the v0.7 text, version-stamped and
otherwise unchanged. `APWORLD_SPEC.md` in particular is byte-for-byte the
v0.7 contract below its header: Echoes 2.0 changes what an Echo means
locally and touches nothing on the Archipelago side.

---

## Why

The POC proved the loop. It also showed what the loop could not express.

One foreign item became one Echo; an Echo was one activated ability or one
passive multiplier; exactly one was equipped. So every interpretation had
to land as a gun, a dash, a heal or a stat multiplier — twenty-six Echoes
read as one thing with twenty-six names, twenty-five of them were dead
weight, and no item could answer another. The premise is that the
multiworld gradually builds a character around you, and v0.7 had no way to
represent a character.

---

## The seven changes to the approved direction

The architecture was approved in direction with seven required changes.
Each is recorded here with where it landed.

### 1. Fold ordering is grant order, never location id

**Change.** Do not sort the complete interpretation log by
`source_location_id`. Persist an immutable sequence assigned at grant time
and fold by that; location id may be the deterministic tie-break for
several Checks discovered in one reconciliation batch.

**Resolution.** `ECHOES.md` §2.1. `interpretation_seq` is assigned once,
monotonically, at grant time and is immutable thereafter; the fold orders
by it and by nothing else. Within a reconciliation batch, sequence numbers
are assigned in `source_location_id` order — a tie-break for *assignment*
only. `next_interpretation_seq` is persisted so a reload can never reuse a
number. Also `TECHNICAL_ARCHITECTURE.md` §7.0.1, `ACCEPTANCE_TESTS.md`
I6/I11.

**Why it mattered.** An interpretation may target a component that existed
when it was generated. Location ids come from Archipelago, not from the
order you find them, so folding by location id can replay a
later-received, lower-numbered interpretation *before* its target exists.
That is a corrupt fold reachable by ordinary play, not a corner case.

### 2. Rule-event boundaries are explicit

**Change.** Effects still never emit events. When an effect moves state
across an engine-event threshold, the resulting event must be
edge-triggered and deferred to a later tick, never dispatched recursively
inside the current dispatch.

**Resolution.** `ECHOES.md` §5.1, as five numbered rules: effects write
state only; threshold events are derived at end of tick on the crossing
edge; derived events are deferred at least one tick; one dispatch
considers each rule at most once against the state as it stood when the
dispatch began; cooldowns ≥ 0.1 s and a per-tick firing cap. Also
`TECHNICAL_ARCHITECTURE.md` §14, `ACCEPTANCE_TESTS.md` I5.

**Why it mattered.** "Effects never emit events" was necessary and not
sufficient — a `resource_add` that fills a bar is exactly the case where
the engine, not the effect, produces the event.

### 3. MERGE is hardened

**Change.** Canonical alias resolution, no self-merge, no alias cycles,
targets must resolve to live canonical components, absorbed ids resolve
permanently, provenance from both sides preserved.

**Resolution.** `ECHOES.md` §3.1, all six plus two more: capacity policy
is declared rather than guessed, and only resources may merge — actions,
traits and rules evolve through `UPGRADE`/`MODIFY`, so there is exactly
one identity mechanism. `ACCEPTANCE_TESTS.md` I10.

### 4. An expanded Action primitive catalog, with its own stage

**Change.** Echoes 2.0 must broaden the active verbs as well as the
systemic mechanics. Design a closed, validated catalog; give it an
implementation stage. Deployables may remain deferred.

**Resolution.** `ECHOES.md` §6 — twenty-eight primitives across close
combat, ranged, movement, defence and utility, each with bounded
parameters and a slot category. Three carry mandatory conditions rather
than mere bounds: `beam_sustained` and `hover` must be `powers`-linked to
a resource, and `blink` resolves only along a validated ray to a surface
hit with a clearance test at the landing point. The catalog is **S2**, the
first stage the player can feel, and it ships closed. Deployables stay
after S10. `ACCEPTANCE_TESTS.md` I14.

### 5. Source identity and semantic colour are separated

**Change.** Source game provides deterministic glyph, accent, sound and
particle identity. Epsilon chooses the HUD resource's own colour and name
from a safe palette according to the interpretation.

**Resolution.** `ECHOES.md` §7.1 as a two-row table of who chooses what
and which question each answers. Ocarina's Magic Meter creates a resource
Epsilon names **MP** and paints **green**; when Dark Souls later
contributes Blue Estus to the same economy, the refill pips carry Dark
Souls' accent and glyph while the bar stays green. The palette is a closed
set of named hues with light and dark pairs, so a chosen colour is legible
on both grounds and cannot collide with the HUD's reserved semantic
colours.

### 6. Affordances require a supported capability

**Change.** The registry must prevent optional water, rail, breakable and
grapple features appearing unless the derived player mechanics can
actually interact with them. Still forbidden from mandatory paths and AP
rewards.

**Resolution.** `ECHOES.md` §13.1 as a registry table mapping each tag to
the capability that pays for it, evaluated over **owned** rather than
equipped components — you can always slot what you own. §13.2 keeps the
mandatory-path and AP-reward prohibitions. Also `DESIGN.md` §19,
`EPSILON_SPEC.md` §13, `ACCEPTANCE_TESTS.md` I12.

**Why it mattered.** A water volume in a run with no way to move through
water is set dressing that looks like content, which is worse than nothing.

### 7. Info components and a local-reward catalog

**Change.** Flesh out Info components and a tiny safe catalog of local
rewards for Echo-only secrets and challenges. Never AP items or Checks.

**Resolution.** `ECHOES.md` §14.1 lists ten readouts; §14.2 lists six
local rewards — Epsilon notes, challenge markers, cosmetics, Hub
decorations, Lab fixtures, archive entries — with the prohibition stated
as a rule rather than an intention: never an AP item, location, Check,
Coin, Key or Echo, and never on a mandatory path.
`ACCEPTANCE_TESTS.md` I13.

---

## The four settled decisions

| | Decision | Settled as |
|---|---|---|
| 1 | Resource persistence | Current values reset on Zone entry, like HP. Definitions, maxima and upgrades persist with the log. |
| 2 | Permanent severe curses | Never. Severe downsides must be removable and equipment-bound. |
| 3 | Geometry-changing `tiny` / `huge` | Deferred past S10. |
| 4 | Packet shape | A complete v0.8 authority packet: v0.7 rolled forward, only what Echoes 2.0 touches changed, no broad review reopened. |

---

## What changed, file by file

| File | Change |
|---|---|
| `ECHOES.md` | **New.** Normative for the v8 Echo contract. |
| `README.md` | Version, read order, authority order, and the one temporary exception (prose outranks `schemas/echo.py` until S1) with its expiry. |
| `CLAUDE_HANDOFF.md` | Mission is now Echoes 2.0, not the POC. `ECHOES.md` added to the read-first list. |
| `DESIGN.md` | §3.5 append-only log; §6 two new terms; §7 four slots; §15.2–15.4 components, contextual validation, provenance in the archive; §19 affordances and local rewards. |
| `EPSILON_SPEC.md` | §8 interpretation shape and operations; §8.1 the new primitives and their mandatory conditions; §10 the request carrying `owned`, `aliases` and `budgets`; §11.2 the rewritten system instruction; §12.2 fallback stays boring, mock must grow; §13 owned mechanics as generator vocabulary. |
| `TECHNICAL_ARCHITECTURE.md` | §7.0 two new transitions; §7.0.1 derived mechanics are never persisted; §14 why the rule engine does not weaken the security boundary. |
| `IMPLEMENTATION_PLAN.md` | §2.5, the ten stages, and why S1's bar is higher than the rest. |
| `ACCEPTANCE_TESTS.md` | §5.7, one test per invariant with the stage that owns it, plus the two migration tests. Test D extended to affordances. |
| `DECISIONS_TO_REVIEW.md` | Deployables and geometry-changing forms added as open/deferred; the four settled decisions recorded. |
| `APWORLD_SPEC.md` | Header only. The Archipelago side does not change. |
| `schemas/` | **Unchanged — still v7.** S1 lands v8. |

---

## What has not changed, and is not up for discussion

- Archipelago owns randomized truth. Epsilon never invents, replaces,
  deletes, reroutes or mutates a real item or location.
- Nothing generated is ever executed.
- Mandatory progression is completable with base movement and Static Pulse
  alone. v0.8 makes this *stronger*: derived movement stats have a hard
  floor at base, so `max_safe_gap` and every generated jump stay valid
  unmodified.
- Campaign state is replaced, never edited, through the transition layer.
- Quit, reload and reconnect lose nothing and duplicate nothing.
