# Archipepsi v0.4 → v0.5 — Delta Audit, Pass 4

**Date:** 2026-08-26
**Subject:** `docs/design-packet-v0.5/` frozen at **`6b64e5425150064fb5aeaea943b0e759821d6b77`**
**Baseline:** `docs/design-packet-v0.4/` (frozen at `a681446`, the artifact pass 3 examined)
**Reviewers:** two independent agents, delta-scoped, neither having designed v0.5

**Test state at the frozen SHA:** 73 passed — standalone, from a parent directory, and in the nested `bridge/archipepsi_bridge/schemas/` layout the plan mandates. All four generated artifacts reproduce byte-identically.

---

## 0. Verdict

**NO-GO. One blocker, two majors. All three are small fixes; none touches the architecture.**

The revision is substantially sound. Two of the five pass-3 criticals are complete and held under sustained attack. The traversal work is the strongest thing in the packet — independently re-derived, grid-searched over the full loadout space, and brute-forced across 1.84 million legal parameter pairs with zero failures. The rename is complete and pinned by a regression test. Artifacts reproduce exactly, with drift detected in all three directions.

But **the goal Check is reserved against Zones and not against the shop** — reintroducing pass-1's B5 ("buy the ending for 6 coins") through the one path v0.5 closed only halfway, in a packet that declares its schemas structurally authoritative. And the **T−60 gate demands tests for subsystems the build order schedules four phases later**, creating a direct incentive to start the shop inside the feature freeze — the precise behaviour the freeze exists to prevent.

Both are the same failure shape as the last round: a rule fixed thoroughly in one place and left open in its neighbour.

---

## 1. Findings by classification

| # | Finding | Class |
|---|---|---|
| **D1** | Check 030 is reservable, purchasable and chargeable through the shop | **CONFIRMED BLOCKER** |
| **D2** | The T−60 gate requires tests for Phase 6 systems at the Phase 0–2 expected outcome | **CONFIRMED MAJOR** |
| **D3** | No Hub mode for `PENDING_GENERATION`; the documented generating state is inexpressible, and the finale guard is blind to it | **CONFIRMED MAJOR** |
| D4 | `PENDING_GENERATION` has no terminal exit; `abandon_zone` cannot reach it | CONFIRMED MINOR |
| D5 | `CampaignSnapshot` has no cross-field validation; the stranding shape is expressible there | CONFIRMED MINOR |
| D6 | "blocky" survives in the Epsilon system prompt — the retarget never reached the generator | CONFIRMED MINOR |
| D7 | Theme material sets are referenced by prose and absent from `constants.py` (42 values to invent) | CONFIRMED MINOR |
| D8 | Test count stale at 67 in five places, one of them a literal gate | CONFIRMED MINOR |
| D9 | Gate header says "Phase 0–3" two lines after the expected outcome says "Phases 0–2" | CONFIRMED MINOR |
| D10 | `export.py` default outdir is cwd-relative; the two most prominent documented commands refresh nothing | CONFIRMED MINOR |
| D11 | Three mutation survivors: real invariants with no test | CONFIRMED MINOR |
| D12 | `recipient_is_self` not withheld on unrevealed locations | CONFIRMED MINOR |
| D13 | `TowerChamber` has no traversal bound anywhere in the packet | CONFIRMED MINOR |
| D14 | Child-field assignment bypasses parent invariants (window: one call) | CONFIRMED MINOR |
| D15 | Zone/shop cross-reservation forbidden by prose, unenforced by schema | CONFIRMED MINOR |
| D16 | The mesh ceiling was dropped rather than widened; nothing now bans CSG/`SurfaceTool`/`ArrayMesh` | CONFIRMED MINOR |
| D17 | Art scope increased (mandatory 64×64, five texture families, props) without a plan step or estimate | CONFIRMED MINOR |
| D18 | Pydantic unpinned while a byte-exact test depends on its JSON Schema output | CONFIRMED MINOR |
| D19 | Step-numbering damage from the M11 reorder; dangling "(see below)"; finale gating scheduled twice | CONFIRMED MINOR |
| D20 | `zone.py` docstring and `CampaignSave`'s `extra="ignore"` comment both overclaim | CONFIRMED MINOR |
| — | The schema models states, not transitions: 13 illegal transitions are representable | AMBIGUITY — DESIGN CHOICE |

Nothing was classified FALSE POSITIVE or COULD NOT VERIFY. Every finding above was reproduced independently before inclusion.

---

## 2. The blocker

### D1 — The goal Check is reservable, purchasable and chargeable through the shop

`ShopStockItem.location_id`, `BuyShopStock.location_id` and `PendingCheck.location_id` are all plain `_LOC`, and `LAST_LOCATION_ID == GOAL_LOCATION_ID`. Nothing on the shop path excludes 89100030. Reproduced:

```
ACCEPTED — goal 89100030 in shop stock, goal_sent=False
buy intent accepted: 89100030
unlocked_location_ids(2) includes the goal: True
```

The save round-trips with the goal Check bought and paid for. A `status="purchased"` variant is also accepted — the schema can describe the goal having been bought while `goal_sent` is still false.

**Why this is a blocker and not a major.** Three things compound:

1. **It is pass-1's B5, verbatim.** "Six coins buys Check 030 and wins the game" was the sharpest finding of the entire project. v0.5 closed it structurally on the Zone path — `ZoneRecord` rejects a non-finale record holding the goal, and that half survived every attack — and left the shop path open.

2. **The packet's own authority order makes the schema win.** `README.md`: *"Where this document set says something a schema contradicts, the schema is right and the prose is a bug."* Five prose statements forbid this. The top authority permits it.

3. **The one helper the packet mandates hands the implementer the bug.** `unlocked_location_ids()` is documented as the function *"the APWorld region rules and the bridge allocator must both derive from"* — and its docstring reads *"Every location legal to allocate at this key count, **goal included**."* There is no `eligible_*` counterpart. An implementer building on the mandated helper, exactly as instructed, gets the goal in their shop pool.

**Consequence if it ships:** the shop sells Check 030, the bridge sends it, `CLIENT_GOAL` fires with zero of the 24 required Checks confirmed, and the finale Zone never exists — so no `is_finale` record is ever constructed and no structural check ever sees it.

**Fix (small):** add an `eligible_location_ids(signal_keys)` helper that excludes `GOAL_LOCATION_ID`, point the shop and allocator at it, and constrain the shop-path models to a `_NON_GOAL_LOC` type. Three lines of schema plus a test.

---

## 3. The majors

### D2 — The T−60 gate incentivises breaking the T−60 freeze

`IMPLEMENTATION_PLAN.md` §1.1 makes two gate rows required **unconditionally** from Phase 2:

```
| Bridge tests 1–20 (§2)                 | Phase 2 onward |
| Campaign / allocation tests 21–35 (§3) | Phase 2 onward |
```

Four tests in those bands need systems the build order schedules in **Phase 6**:

| Test | Needs | Built at |
|---|---|---|
| 27 — stock not created when it would leave <3 eligible | shop stock selection | step 40 |
| 28 — unsold reservations released before `WAITING_FOR_AP` | shop reservations | step 42 |
| 33 — confirming Check 030 sends goal exactly once | goal reporting | step 43 |
| 35 — reconnect with fewer coins than spending history | shop spending history | Phase 6 |

The escape clause covers only the **lettered** end-to-end tests. So an agent landing on the plan's own stated expected outcome — Phases 0–2 — reaches T−60 facing a gate it cannot pass without building the shop and goal reporting. The rule written to stop late subsystem starts requires one.

**Fix:** condition those rows on systems rather than phases, or extend the escape clause to the numbered tests.

### D3 — No Hub mode for `PENDING_GENERATION`

`DESIGN.md` §13's portal table specifies a generating state: *"Keep the previous mode and set `generation_in_progress`"*, portal disabled. The new `portal_enabled ↔ mode` coupling makes that unrepresentable:

```
ZONE_AVAILABLE  portal off -> REJECTED
FINALE_ONLY     portal off -> REJECTED
ZONE_READY      portal off -> REJECTED
ZONE_ACTIVE     portal off -> REJECTED
NO_CAMPAIGN     portal off -> ACCEPTED   (only the very first generation)
```

The only schema-legal option is to leave the **generate** portal live through a 120-second window, inviting a second `request_next_zone` — the orphan class C1 exists to prevent.

The same gap punches a hole in the M9 finale guard, which lists only `ZONE_READY`/`ZONE_ACTIVE`:

```
ZONE_AVAILABLE + generating + finale_available -> ACCEPTED
```

A Zone held in `PENDING_GENERATION` is invisible to a guard whose stated rationale — *"otherwise its unclaimed Checks are stranded"* — applies to it verbatim.

Both halves are one root cause: `ZoneState` has five states, `HubMode` covers four. This is a regression **introduced by a v0.5 fix** — a good invariant with an incomplete domain.

**Fix:** add a `GENERATING` Hub mode (portal disabled) and include `PENDING_GENERATION` in the held-Zone guard.

---

## 4. Verdict on the five pass-3 criticals

| | Claim | Verdict |
|---|---|---|
| **C1** | `GENERATED` unreachable and unrecoverable | **Incomplete.** The named state is fixed and mutation-tested. The *class* is not: D3 and D5 |
| **C2** | Shop chargeable twice for one location | **Complete.** Held under every attack; both mutants killed |
| **C3** | No abandon path for an unfinishable Zone | **Incomplete.** Works from `ACTIVE`/`GENERATED`; the new content validator makes `ABANDONED` unreachable from `PENDING_GENERATION` (D4), relocating the trap |
| **C4** | Goal disabled play | **Complete.** 62 of 224 `HubStatus` combinations legal; no legal one disables play with Checks outstanding |
| **C5** | Passive multipliers bounded independently | **Complete — and the strongest work in the revision.** See below |

---

## 5. What held under sustained attack

Stated plainly, because it is a real result and a future pass should not re-litigate it.

**Traversal.** Re-derived from scratch analytically and by numeric integration; both matched the module to ten significant figures. A grid search over the entire legal `(gravity_mult, speed_mult)` box — 201,000 points per height — confirmed that `jump_reach()`'s defaults really are the worst legal loadout at every height, rather than merely being asserted to be. Every `(gap_size, vertical_step)` pair the schema accepts was brute-forced at 1 mm resolution:

```
accepted chambers: 1,841,601    failures: 0
tightest margin: 1.5626 at (gap 2.4, step 0.51)  = 1/0.64, exactly the design limit
```

Boundaries clean: the exact bound accepts, +1 ULP rejects. NaN and ±inf reject as Python floats, as JSON literals and as strings. `_floor1` never rounds upward across 2.1M random and 100k gridded samples. The v0.4 max-gap-with-max-step shape is unrepresentable.

**The rename.** Complete. Exactly three surviving non-codename hits, all deliberate: the changelog record, a guard asserting no soda term appears, and a negative test asserting the old debug command is rejected. Every identity surface carries the new names — `item_name_to_id`, slot data, region rules, YAML, fixtures, generated GDScript, protocol enums.

**Generated artifacts.** Byte-identical on regeneration. The freshness test detects drift in all three directions: a mutated file, a missing file, an extra file. All 94 constants present in the GDScript with zero value mismatches and identical float reprs. The generator raises rather than dropping anything it cannot express.

**The goal reservation on the Zone path.** Survives parsing, whole-field assignment, `is_finale` flipping, in-place list mutation followed by any boundary crossing, save/load round-trip, and the fallback generator. Exactly as advertised — which is what makes D1's asymmetry the finding.

**Shop double-charge, and postgame.** Both complete, both attacked, both held.

**The test suite.** 50 semantic mutants, **47 killed**. It catches `_floor1`→`round`, the passive bounds, `max_safe_gap` ignoring step, `jump_reach` defaulting to the best loadout, shuffle direction, `team` dropped from the seed, every cap, and theme-catalog drift. Three survivors are recorded as D11.

---

## 6. Does anything require v0.6?

**Yes — D1 alone.** It reintroduces the project's original critical through an unclosed neighbour path, and the packet's own authority rules mean the schema wins over the five prose statements forbidding it.

D2 and D3 should ride along: D2 actively pushes an agent to violate the freeze, and D3 is a regression one of the fixes introduced.

The remaining seventeen are genuinely minor. **D6 is the one worth including anyway** despite its class — the Epsilon system prompt still says "Design a short **blocky** first-person Zone", so the entire GoldSrc retarget reached every document except the one sentence the generator actually reads. It is a two-word fix with disproportionate effect on output.

**Recommended v0.6 scope: D1, D2, D3, D6, D8, D9, plus D4 and D7 if cheap.** Nothing else. The six deliberately-open implementation items stay open — none was shown to corrupt campaign or AP state, and none blocks Phase 0–2.

---

## 7. GO / NO-GO

**NO-GO at `6b64e54`.** Not because the packet is unsound — it is close, and the parts that were attacked hardest held best — but because shipping it would hand Fable a schema that permits buying the ending, and a stop rule that requires breaking itself.

**GO after a v0.6 addressing D1, D2, D3 and D6.** That is a few hours of editing, mostly schema, with no architectural change. Re-audit the deltas only.

One process note for whoever runs that pass: both rounds now have found the same shape — a rule closed thoroughly on one path and left open on its neighbour (Zone vs shop; `GENERATED` vs `PENDING_GENERATION`; code vs the prose describing it). A v0.6 should not fix D1 by editing the shop path. It should ask, mechanically, *which other paths reach this invariant*, and close them together.
