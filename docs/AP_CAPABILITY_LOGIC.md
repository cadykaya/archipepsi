# Capability gates and Archipelago logic — a proposal

**Status: proposal. Nothing here is implemented and the item pool is
unchanged.** Written because the intended gameplay — *find the grapple,
come back, open the door you could not open* — needs an Archipelago
guarantee that does not exist yet, and the shape of that guarantee is an
owner decision rather than an implementation detail.

Until it is settled the bridge keeps refusing a capability gate on any
AP-relevant route (`topology.reachability`). That restriction is
temporary and is **not** a verdict on the gameplay.

---

## 1. What has to be true

`SOLUTIONS_CATALOGUE.md` §0-bis permits a local key, a required Check or
the Zone exit to sit behind a hard capability gate, on five conditions.
Three are already enforced in the bridge (the graph agrees with AP logic;
you can leave; you can come back). **Two are not, and both are about
Archipelago:**

1. *the matching AP location logic declares the same prerequisite;*
2. *Archipelago proves the capability progression is obtainable.*

Neither is expressible today, and the reason is not a missing wire.

## 2. How a capability reaches a player today

Traced, not assumed:

| Step | Where |
|---|---|
| the player claims a Check | an ordinary AP location |
| the item belongs to **another** player | `campaign.grant_echo` scouts it |
| **Epsilon interprets that foreign item** into an Echo | `generate_echo_validated` |
| the interpretation log folds into owned components | `derive_mechanics` |
| a capability is satisfied when an owned component carries a matching **primitive** | `owned_capabilities`, `ACTIVITY_CAPABILITIES` |

So `grapple` is held when some owned component's primitive is
`grapple_to_surface`, `grapple_pull_target` or `grapple_swing` — and
whether any component ever carries one is decided by **a creative
interpretation of whatever the multiworld happened to give you.**

The AP item pool, meanwhile, is `Signal Key` ×2, `Epsilon Coin`,
`Epsilon Static`, and the location logic is tier-based on Signal Key
count. **`grapple`, `blink` and `cross_long_gap` appear nowhere in it.**

## 3. Why that is not an AP proof

The generator already refuses to require what it cannot prove — owner
ruling *no requirement before guarantee*, `capability_guarantee`, four
cases: **A** permanent baseline, **B** already possessed, **C**
established in the Zone (no producer), **D** Forge-constructible (not
implemented). Case B is what runs, and B is a statement about **now**:
*this campaign currently owns a grapple component.*

Archipelago needs a statement about **obtainability**: *any player who
reaches this location can have got a grapple by then.* B cannot supply
it, because the thing that produced the grapple was Epsilon's
interpretation of someone else's item — a convenient random reward.
Feeding that set to AP, or passing it in as a caller-supplied list,
would be the bridge telling Archipelago what Archipelago is supposed to
be proving.

## 4. Option A — explicit capability items

Add progression items to Archipepsi's own pool: `Grapple Module`,
`Blink Module`, `Traversal Module` (for `cross_long_gap`).

| | |
|---|---|
| **Where the guarantee comes from** | Archipelago's fill. A progression item is placed in logic, so the solver proves every gated location is reachable — the mechanism AP exists to provide, needing no new trust. |
| **How location rules match** | **Before seed generation, and only then.** See below. |
| **How a qualifying provider reaches the player** | The item's grant must satisfy a **functional contract** — a primitive in the family, with resolved parameters meeting the measured envelope (§8). Presentation is not part of that contract. |

### 4a. The rules exist before the Zone does

An earlier version of this section said the bridge "sends the required
capability with the Zone's allocation so the apworld can attach the rule
to those specific ids". **That cannot work**, and the reason is the
order things happen in:

```
 AP seed generation  ──>  rules are FIXED, logic is solved, items placed
        │
        ▼
 play begins  ──>  the bridge allocates location ids to Zones, one Zone
                   at a time, hours later
```

By the time a Zone exists, the access rules for its locations were
written and solved long ago. Nothing the runtime does can add one.

So the contract runs the other way:

1. **Before seed generation**, the apworld decides which location ids
   carry which capability requirement, and writes the access rules from
   that decision. It may be a whole tier, a fixed subset, or a seeded
   choice — what matters is that it is settled before fill runs.
2. **That mapping is exported to the runtime** — slot data is the
   obvious carrier, since it already crosses — as `location_id ->
   required capabilities`.
3. **The allocator and the composer obey it.** A Zone allocated location
   `L` may place a capability gate on `L`'s route only if the exported
   contract declares that capability for `L`, and must place one where
   the contract declares one and the Zone would otherwise be trivially
   open. `reachability`'s `declared_capabilities` is then fed from the
   contract rather than from a caller's opinion — which is the whole
   point: it becomes Archipelago's statement, read back.

This makes the runtime a **consumer** of AP logic rather than a
contributor to it, which is the only relationship the seed's timing
allows.

## 5. Option B — guaranteed local acquisition, represented in AP logic

Keep Epsilon and the Forge as the only source of mechanics, and make the
*timing* of acquisition something AP logic can state. AP never names a
capability; it names the milestone that guarantees one.

| | |
|---|---|
| **Where the guarantee comes from** | A **deterministic local schedule**: by milestone *M*, the campaign is certain to be able to produce a qualifying provider. Certainty is the whole requirement — "probably, by then" is not a guarantee, and AP fill is not a probabilistic argument. |
| **How location rules match** | The existing tier rule, unchanged — but the mapping in §4a is still needed. Which location ids may carry a gate is settled before fill (here: "Tier ≥ the milestone"), exported to the runtime, and obeyed by the allocator. No new item and no new rule kind, but the same one-way contract. |
| **How a qualifying provider reaches the player** | Two candidate mechanisms, and neither exists: **B1 — the Forge** (`capability_guarantee` case D): Forge access, guaranteed ingredients, and a proof that a legal configuration carrying the primitive can be built from them. **B2 — a scheduled grant**: the campaign appends an authored interpretation carrying the primitive at a defined milestone. B2 is B1 without the Forge, and is much smaller. |

**What it costs.** The schedule becomes load-bearing for solvability: if
the grant slips, or the Forge cannot actually build the thing, the seed
is unwinnable and Archipelago never knew. It also means capabilities are
never in anyone else's world — Archipepsi's own progression, with AP
merely told when it is safe to place a gated location.

## 6. Option C — the current restriction, kept

Gate only what is **not an Archipelago location at all**: a shortcut
between two rooms both otherwise reachable, a vista, flavour.

**Hidden Checks are NOT in that set, and an earlier version of this
document listed them as exempt. That was wrong.** A hidden Check is an
AP location. Archipelago's logic has to be able to say a player can
reach it, exactly as for a required one — "optional to finishing the
Zone" and "optional to AP accessibility" are different properties and
only the second one matters here. A seed whose fill placed a progression
item behind a hidden, capability-gated Check would be unwinnable, and
nothing in the Zone's own notion of "required" would notice.

So the rule under Option C is: **every AP location gets the same
guarantee**, and a capability gate may only sit where no AP location is
behind it. That is a narrower exemption than it first looks, and it is
what ships today.

It is listed because it is a real answer, not because it is the intended
one — the whole point of §0-bis is that "NOT YET" on a required route is
good gameplay.

## 7. Acquisition is not presentation

An earlier version of this document said Option A "costs Archipepsi its
rule that every item becomes an interpretation", and built the choice on
that. **It does not, and the framing was wrong.**

What a guarantee needs is a **functional contract**: after receiving the
item, the campaign owns a component whose primitive is in the family and
whose resolved parameters meet the measured envelope (§8). That is a
constraint on *function*, and it says nothing about:

| Stays interpreted | Fixed by the contract |
|---|---|
| display name, description, the Echo's whole framing | the primitive family |
| which member of the family — a swing, a pull, a surface hook all satisfy `grapple` | that it is one of them |
| cooldown, cost, resource links, slot, modifiers | resolved parameters at or above the envelope minimum |
| everything the player reads and remembers | nothing the player reads |

So a `Grapple Module` can still be Epsilon interpreting the item it came
from — the difference is that its interpretation is **validated against
the contract and regenerated or fallen back on if it misses**, exactly
as `generate_echo_validated` already validates and falls back today. The
fallback provider is the deterministic floor; Epsilon is the variation
above it.

`capability_guarantee`'s case D (Forge-constructible) already describes
the same shape from the other end — "a proof that a legal configuration
satisfying `capability` can be built" is a functional contract too.

**What actually differs between A and B**, with the presentation
confusion removed:

| | A — capability items | B — local schedule |
|---|---|---|
| who proves obtainability | Archipelago's fill | the project's own schedule |
| where the capability can be | any world in the multiworld | always this one |
| what breaks if it is wrong | fill fails loudly at generation | a seed is quietly unwinnable |
| new rule kind in the apworld | `has(item)` | none — the tier rule |
| new item pool entries | three | none |

**That is the choice**: whether capability progression is *in the
multiworld* or *beside it*. Both keep Epsilon. Both need §4a's pre-seed
contract. Neither is a different game in the way the earlier draft
claimed — the difference is where the proof lives and what it costs when
it is wrong.

**If B, one sub-choice follows:** B2 (a scheduled grant) is implementable
now; B1 (the Forge) needs a system that does not exist. B2 first, B1 as
the eventual home, is coherent.

## 8. Provider qualification — done, except the physics

**Identity is not qualification**, and §29.3.1 already drew that line for
`manipulate`: membership answers *"is this a manipulation Ability"*,
never *"can this one move the crate"*. Movement was owed the same split
and did not have it — `owned_capabilities` said `cross_long_gap` for a
4 m/s dash and a 20 m/s dash alike, so a route needing six metres was
proved by a provider that might carry three.

**An earlier version of this section proposed putting the floor into the
`stats` branch of `_capability_is_satisfied`. That was wrong twice
over.** `stats` is a set of stat *names* off the components — a floor
there would compare a number against a word — and the branch is a
Boolean intersection, which is the identity question, not the
qualification one.

What landed instead (`schemas/mechanics.py`):

- `_capability_is_satisfied` is unchanged and now says in its docstring
  that it is **identity**, and why no envelope belongs in it.
- `qualifies_for_gap(capability, mechanics, gap_m, rise_m)` is the new,
  separate question. It reads **resolved provider parameters** off the
  owned components and compares them against **the route's actual
  requirement** in metres.
- The base kit's own reach is `C.max_safe_gap(rise)` — derived from the
  same constants the engine generates its copy from — so a crossing
  inside it needs no provider and is not a gate at all
  (`within_base_kit`).
- `MOBILITY_REACH_ENVELOPE` is the measured floor per primitive, **and
  it ships empty**. With no entry, nothing qualifies, and the reason
  reported is `no_envelope_measured` — distinct from `no_provider`,
  because "the campaign owns no dash" and "nobody has measured what a
  dash crosses" are different faults.

### 8a. The number this lane must not invent

`Dash.force` is documented in `echo.py` as an **instantaneous velocity
change in m/s**, bounded 4–20. `echo_runtime.gd::_dash` spends it as:

```gdscript
var dir := -player.camera.global_transform.basis.z
player.velocity += dir * float(prim["force"])
```

It **adds** to whatever the player was already doing, along the full
camera-forward vector — so the look angle is in it too. `_air_dash`
*replaces* horizontal velocity instead and zeroes descent. How far
either carries a body depends on the speed it started at, the pitch, the
controller's friction and air damping, and how long the body stays
airborne. **There is no closed form to write in the bridge**, and
reading `force >= 8.0` as "eight metres" would be a distance guarantee
manufactured from a quantity that is not a distance.

**A design divergence to reconcile, which is not this lane's to settle.**
Design 1 §13.1 lists `DASH_IMPULSE` as *"distance in metres"* and
describes it as repositioning the player a fixed distance. The
implemented `Dash` carries a velocity in m/s. Those are different
quantities, and whichever is intended, one of the two needs to change.

### 8b. For the engine lane

The envelope is engine-owned for the same reason `scene_digest` is: the
bridge has no body, no controller and no physics frame. What is needed
is a **measured floor**, not a derivation:

> For each mobility primitive, what is the **guaranteed minimum**
> horizontal distance it carries a player at a given parameter value,
> under the worst legal conditions — standing start, level camera, the
> same pessimistic `speed_mult` / `gravity_mult` defaults `jump_reach`
> already uses?

Shape it to fill directly:

```python
MOBILITY_REACH_ENVELOPE["dash"] = ((4.0, 2.9), (12.0, 6.4), (20.0, 9.1))
#                                   ^ m/s      ^ metres, measured floor
```

A step table of measured points, read as "at or above this parameter,
at least this reach". No interpolation is invented between points; the
largest measured point at or below the provider's value is what counts.

Then §29.3.2's pattern completes itself: content is authored against the
minimum, a reference crossing is replayed at exactly that minimum, and
anything qualifying can make it. Until the table has entries,
`qualifies_for_gap` refuses and says why — which is the honest state,
and is what keeps an AP-relevant gate refused while this proceeds.

---

## What this lane does next

Nothing on the AP side until the §7 choice is made. `reachability` keeps
refusing an AP-relevant gate with no matching guarantee,
`declared_capabilities` stays unpassed by production, and composition
emits no gates — so the restriction costs nothing today and removes no
option tomorrow.

On the qualification side the seam is open and waiting on one measured
table from the engine lane.
