# v0.10 research memo — capability progression that Archipelago understands

Written overnight after Playtest 2.5. **Nothing here is implemented.** One
memo rather than a packet, because the last packet validated perfectly and
shipped a boring game.

Where a real choice exists, the options are enumerated so they can be
cherry-picked rather than accepted as a block.

---

## 0. The result that matters

**Architecture D works. It is proven, not argued.**

A disposable patch added a capability event and gated five tier-2 locations
behind it, then ran real `Generate.py`:

| | |
| --- | --- |
| Capability event + gated locations | **solo and multiworld generate clean** |
| Same gate, event removed (negative control) | **generation FAILS** |

The negative control is the important half. The access rule is genuinely
enforced, which means **an unsatisfiable capability gate is a seed-generation
error, not a player discovering at hour twenty that their seed is dead.**
Archipelago polices this for us.

The patch was reverted; `apworld/tests` is green at 39 passed / 627 subtests.

---

## 1–3. Can D work, what is the smallest structure, what would kill it

**Yes.** The mechanism already exists in this repo. `Location.is_event` is
just `address is None` (`.archipelago/BaseClasses.py:1531`), and
`sweep_for_advancements` collects items from every *reachable* location,
re-sweeping to a fixpoint (`BaseClasses.py:917`). Archipepsi already ships
one: `VICTORY_EVENT_NAME` in tier 2.

**Smallest structure:**

```python
cap = ArchipepsiLocation(player, "Archipepsi Grapple Event", None, region_of_check_037)
cap.place_locked_item(ArchipepsiItem("Grapple Capability", progression, None, player))
region_of_check_037.locations.append(cap)

# later locations, in their own regions
loc.access_rule = lambda state: state.has("Grapple Capability", player)
```

Check 037 keeps its ordinary randomized item for whichever player. The event
rides alongside it and is invisible to the client — no second Check appears.

**The semantics to understand (their Q3):** AP collects the event on
**reachability**, not on the player actually claiming Check 037. That is
safe, and the direction matters: AP's model is a *relaxation* of the player's
situation. Anything AP believes reachable, the player can realise by walking
over and claiming it. There is no case where AP is more optimistic than
reality in a way the player cannot close.

**What does NOT kill it:** Archipelago. Nothing in fill, `CollectionState`,
accessibility or cross-player placement objects to this.

**What DOES kill it — all three are ours, at runtime:**

1. **Epsilon might not produce a grapple.** AP believes GRAPPLE exists the
   moment Check 037 is reachable. If Epsilon reads *Power Star* as a shotgun,
   the seed is unwinnable in practice while AP thinks it is fine. **This is
   the real constraint, and it is a validator problem, not an AP problem.**
   The capability must be decided by Python and *enforced* on the
   interpretation — an Echo that does not carry the required family must be
   REJECTED, the same way an illegal primitive is. Epsilon picks flavour,
   stats and name inside a family Python has already fixed. That is exactly
   the existing boundary: Epsilon never invents reachability truth.
2. **The Forge could reforge the capability away** (§7 below).
3. **Python's allocator could place a gated Check on the base route** (§5).

---

## 4. A / B / C / D

| | AP-safe | Gives "not yet" | Reward quality | Fantasy | Cost |
| --- | --- | --- | --- | --- | --- |
| **A** owned-at-generation | total | ✗ — never blocks | full | intact | very low |
| **B** EXCLUDED locations | yes | ✓ | **filler only**, and breaks `Accessibility: full` | intact | low |
| **C** native capability items | total | ✓ | full | **weakened** — foreign items stop being the source | low |
| **D** capability events on Checks | **proven** | ✓ | full | **intact** | medium |

**B should not be the progression model.** `can_fill` restricts an excluded
location to items that are neither `advancement` nor `useful`, so the
best-hidden secret in the game pays out the worst item in the multiworld. It
also silently breaks AP's `full` accessibility promise ("ensure everything can
be reached and acquired"). Keep it in the toolbox for genuinely throwaway
optional content, not for the spine.

**A is not a fallback so much as a subset of D** — D with the event placed on
a Check the player has already claimed. Worth keeping as the conservative
mode for early Zones.

**C is the honest safety net.** If the Epsilon-constraint work in §1 proves
too unreliable, C ships the same gameplay with a weaker story.

**Recommendation: D, with C's item type as the fallback representation.**
They are not exclusive — the event item in D *is* a native item; D just
attaches its acquisition to a foreign Check rather than to a pool slot.

---

## 5. Fixed AP logic vs dynamically generated Zones

The hard requirement: **the AP logic graph and the physical Zone graph must
agree**, while Zones are still generated at runtime.

The seam already exists. `fill_slot_data` (`apworld/archipepsi/__init__.py:150`)
already ships a per-location logical map — `tiers` is exactly that. Extend it:

```python
"capabilities": {
    "grants":   {"89100037": "grapple", "89100112": "blink"},
    "requires": {"89100200": ["grapple"], "89100241": ["grapple", "blink"]},
}
```

Then the allocator's rule is one sentence: **a location may only be placed in
content whose gates are exactly its declared requirements.** Options for
enforcing that, weakest to strongest:

1. **Filter at allocation.** Only offer Epsilon locations whose requirements
   match the gates it was told to build. Simple; the allocator already
   filters by tier.
2. **Two-pool allocation.** Split each Zone's Checks into ungated and gated
   sets up front, and place them into spine and gated content respectively.
3. **Validator refusal.** `validate_zone` rejects a Zone whose gate structure
   contradicts the requirements of its allocated locations. Catches provider
   error rather than preventing it.
4. **Requirement-driven generation.** The request tells Epsilon "this Zone
   must contain a grapple gate," making the gate a design constraint rather
   than a coincidence.
5. **Post-hoc reachability proof.** Python walks the accepted Zone graph and
   proves each location's physical prerequisites match its AP tags.

1 + 3 is the cheap honest pair: filter going in, refuse coming out. 4 is what
makes Zones *feel* designed around your tools. 5 is the real validator and it
is the expensive one.

---

## 6. CLEARED ≠ EXHAUSTED — minimum lifecycle change

Today `ZoneRecord.state` reaches COMPLETE only when every allocated Check is
confirmed, and that single fact drives `completed_zone_count`, shop cadence
and the ability to request the next Zone.

**Minimum viable split:**

- `CLEARED` — 5 Checks claimed **and** exit reached. Advances the campaign,
  the shop and the Zone counter.
- `EXHAUSTED` — derived, never stored: `claimed == allocated`. It is a
  *query*, not a state, so it cannot disagree with the log.

Consequences to accept deliberately:

- `zones` must stay resident rather than being retired on completion; they
  already persist in the save, so this is mostly removing a terminal
  transition.
- `active_zone_id` becomes "the Zone I am standing in", not "the Zone I owe".
- Re-entry needs a persistent anchor per Zone (§9).
- The finale can no longer count Checks. Options: count CLEARED Zones; count
  Signal Keys; count CLEARED plus a Check floor; or make the finale itself a
  Zone that requires a capability. **Not tuned tonight.**

---

## 7. The Forge, and the capability it might destroy

The append-only fold already solves reference survival: `aliases` map an
absorbed id to a survivor, "fully resolved (never a chain)"
(`mechanics.py:122`), honoured in `derive_mechanics` and
`_check_rule_references`. **Reforge is supersession, and supersession is
what MERGE already does.** The log is not the hard part.

The hard parts are two:

**(a) Mk and upgrade headroom.** Reforging across families changes the
primitive type, so four accumulated `damage +4` upgrades have nowhere to
land. Options: carry Mk as an abstract level and re-derive stats in the new
family; bank the upgrades and re-apply those that map; reset to Mk I and
refund; forbid cross-family reforge of an upgraded component; or let the new
family inherit only upgrades whose field it also has.

**(b) The progression capability.** If AP believes Check 037 granted GRAPPLE,
the player must never be able to end up with no grapple. Options:

1. **Capability is a campaign fact, not a component.** The flag is granted on
   confirmation and is permanent; Echoes are its *expression*. Cleanest
   model, but the flag alone does not get you across the shaft.
2. **The Forge refuses** a reforge that would remove your last Echo in a
   family you are logically required to have. Deterministic, Python-owned,
   one validation rule. **Cheapest correct answer.**
3. **Auto-transfer** — the reforge must produce something in the required
   family, so the capability moves rather than dying.
4. **Reforge the expression, keep a base-level capability** — a weak
   permanent grapple survives, the fancy one can change.
5. **Progression-bearing Echoes are simply not reforgeable**, and are marked
   as such in the archive.

2 and 4 combine well: refuse the removal, and if the player really wants the
change, leave them a base-level version.

---

## 8. Local Coins

Small. `coins_available` is computed `max(0, received - spent)` with
`_reject_underfunded_ledger` guarding it. Add one persisted term:

```
received (AP) + earned (local) - spent = available
```

The real work is anti-farming, and **the precedent already exists**:
`local_rewards` persists `reward_id` + `source_zone_id` so a source pays once.
A coin cache is the same shape. Options for enemy drops specifically: no coin
drops at all (caches only); per-Zone deterministic budget; first-kill-only per
spawn id; or a per-Zone cap that death does not reset.

---

## 9. Smallest next playable slice

**Slice A, unchanged from your Idea 2, and none of it needs any of the above:**

- enemy drops + healing pickups
- a real baseline melee
- checkpoint respawn instead of the Zone entrance

That is an evening, it is the highest fun-per-hour on either list, and it
tests the thing Playtest 2.5 actually indicted — that rooms have nothing to
do and dying wastes minutes.

**Do D's groundwork second, in this order:** the capability map in
`slot_data` → the allocator filter → the interpretation validator that
*enforces* the family. The last one is the risky piece and deserves its own
proof, because it is where D actually lives or dies.

---

## What Playtest 2.5 established, preserved

Scaling geometry without interaction failed. 23 rooms, 921 content points,
32 activities across 19 rooms — and the player's summary was "nothing to do".
Cleaned of conversation time, the Zone runs 8–11 minutes against a 40-minute
target, and **the configurable budget ceiling of 2000 cannot reach 40 minutes
at any setting** (0.706 s/point ⇒ 23.5 min at max). The target was never
purchasable with content volume.
