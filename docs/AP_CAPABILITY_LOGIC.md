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

## 8. Provider qualification — a tested helper, waiting on two things

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
  requirement** in metres, at the landing height asked for.
- The base kit's own reach is `C.max_safe_gap(rise)` — derived from the
  same constants the engine generates its copy from — so a crossing
  inside it needs no provider and is not a gate at all
  (`within_base_kit`).
- `CROSSING_EVIDENCE` holds measured crossings per primitive, **and it
  ships empty**. With nothing covering a case, nothing qualifies.

### 8a. What a measurement certifies, and what it does not

Two corrections to the first draft of this contract, both found by
instantiating it rather than reading it:

**A measurement is not a trend.** The first version stored
`(parameter, reach)` points and read "the largest point at or below the
provider's value", so a crossing measured at force 12 silently certified
force 14 and force 20. Stronger is not automatically suitable — a bigger
impulse can overshoot the landing, clip a ceiling, or carry the body
past the ledge it was meant to arrive on. `CrossingEvidence` states a
`parameter_min`/`parameter_max` band and certifies nothing outside it.

**A crossing has conditions.** Reach alone certified a six-metre gap
whose landing sat a hundred metres above the takeoff, because `rise_m`
only ever reached the base-kit comparison and never the provider's
evidence. Evidence now names the `rise_min_m`/`rise_max_m` band it was
executed at, and anything outside is `outside_measured_scope` — a
distinct answer from `no_envelope_measured`, because "measure this" and
"this was measured, just not for your case" send the engine lane to
different work.

**Providers are scoped explicitly.** `QUALIFIABLE_PARAMETER` names which
field each primitive is qualified on. A `getattr(force) or
getattr(range)` fallback reported `glide` (a fall-speed fraction) and
`hover` (seconds) as "no envelope measured", which reads as work for the
engine lane when the truth is that nobody has said what measuring them
would mean. They report `provider_not_qualifiable` instead.

**Evidence is bound to the provider it describes.** A row is read only
if it names the primitive it is filed under and the parameter that
primitive is qualified on. Neither was checked: a row saying `blink`
certified a dash, and a row certifying a band of `range` certified a
`force` reading — two different quantities compared as one.
`evidence_misfiled` is its own answer, because "measure this" and "this
was measured and filed wrong" send someone to different work.

**And to the setup it was measured against** — `expected_setup` is
compared against `setup_digest`, and a well-formed digest from another
build is refused. With no expected identity supplied the answer is
`setup_identity_unknown`, a refusal: evidence that might be about
another build is not evidence about this one.

> **`setup_digest` is recorded provenance today, not working
> stale-evidence invalidation.** The comparison exists and is tested;
> what is not settled is **where the expected identity comes from** —
> what it covers, when the engine hands it over, and whether it is one
> value for the controller or one per measurement session. That is
> §8b's to agree, and until it is agreed nothing produces the other
> half, so no measurement is actually being invalidated by anything.

### 8b. For the engine lane — the shape to fill

The evidence is engine-owned for the same reason `scene_digest` is: the
bridge has no body, no controller and no physics frame.

`Dash.force` is documented in `echo.py` as an **instantaneous velocity
change in m/s**, bounded 4–20, and `echo_runtime.gd::_dash` spends it as:

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

What is needed is a **measured crossing**, stated as what it covers:

```python
CROSSING_EVIDENCE["dash"] = (
    CrossingEvidence(
        primitive="dash", parameter="force",
        parameter_min=10.0, parameter_max=14.0,   # certified band
        rise_min_m=-1.0, rise_max_m=1.5,          # executed band
        reach_m=6.4,                              # FLOOR across both
        setup_digest="…"),                        # controller + scene
)
```

`reach_m` is a floor across **every** point in both bands, not a best
case — that is what makes it usable as §29.3.2's minimum, with content
authored against it and a reference crossing replayed at exactly that
minimum so anything qualifying can make it.

**Two things to agree, and one of them gates the other.** First, where
the **expected setup identity** comes from: the bridge compares
`setup_digest` against an `expected_setup` it is handed, and nothing
produces that yet. What does it cover — controller constants, the
character scene, the physics build? Is it one value for a build or one
per measurement session, and does it reach the bridge in slot data, in
the layout result, or somewhere else? Computing it stays engine work,
exactly like `scene_digest`; naming its source is a joint decision and
the comparison is inert until it is made.

**Second, agree the shape before measuring.** If a band is the wrong
unit of evidence — if the honest answer is one row per exact configuration, or
if rise is the wrong second axis and something else (takeoff speed,
ceiling clearance) matters more — say so and this model changes before
anyone spends time in the engine. It is a schema, not a decision
already taken.

**A design divergence to reconcile, which is not this lane's to settle.**
Design 1 §13.1 lists `DASH_IMPULSE` as *"distance in metres"* and
describes it as repositioning the player a fixed distance. The
implemented `Dash` carries a velocity in m/s. Those are different
quantities, and whichever is intended, one of the two needs to change.

### 8b-ANSWERED. Engine lane, 2026-09-12

Both questions, and one correction to the premise.

**The physics package's `scene_digest` does not answer this.** They are
different identities and folding them would certify the wrong thing.
`scene_digest` covers the SCENE a replay ran in — colliders, transforms,
gravity, materials, each body's starting state, the physics build. A
crossing depends on the CONTROLLER: `WALK_SPEED`, `AIR_CONTROL`, the
gravity the character integrates, the capsule, `floor_max_angle`, and
the body of `echo_runtime.gd::_dash` itself. Change `_dash` from adding
to velocity to replacing it and every reach in the table moves while the
scene digest of the measurement platform stays byte-identical. So the
expected setup identity is its own value.

**1. What produces it: a `controller_digest`, engine-computed.** Same
reason `scene_digest` is engine-computed — the bridge has no controller
and no physics frame — and the bridge folds it without looking inside,
exactly as it does the other one.

**What it covers:**

| in | why |
|---|---|
| every movement constant the controller reads, quantised and named | the obvious half |
| the **source digest of the movement scripts** — `player.gd`, `echo_runtime.gd` | a change to `_dash` moves the reach and no constant moves with it. This is the half a constants-only digest would miss, and it is the half that matters |
| the character body: capsule height and radius, `floor_max_angle` | a shorter capsule clears a different lip |
| the physics build — Godot version, physics backend — and the tick rate | the same reason `scene_digest` carries it: a different solver is a different experiment |

**Granularity: one per build, not one per measurement session.** The
thing being identified is *what this executable does when you press
dash*, which does not vary within a build. A per-session id would make
two measurements of the same build incomparable, which is the opposite
of what the comparison is for.

**2. How the bridge receives it: in `layout_result`.** Three reasons,
and the third is the one that decides it:

* it is already the message carrying engine measurements the bridge
  folds without re-deriving (`apertures`, `arrival_ok`, the manifest);
* it arrives per Zone entry, which is exactly when `layout.validate` —
  the consumer §8c names — needs it;
* **slot data would certify the wrong build.** Slot data is fixed at
  seed generation and the client can be updated between seeding and
  playing, so a digest sent there describes a build the player may not
  be running. `layout_result` is emitted by the build that is running,
  every time.

Sending a per-build constant on every Zone entry is mildly redundant and
that is the point: it always describes the executable in the room with
the player.

**3. The shape: the bands are right, with one scalar added.** `dash`
ADDS to current velocity, so how fast the body was already moving is in
the answer. A floor measured from a running start would over-certify a
player who dashes from standing.

```python
CrossingEvidence(
    primitive="dash", parameter="force",
    parameter_min=10.0, parameter_max=14.0,
    rise_min_m=-1.0, rise_max_m=1.5,
    entry_speed_mps=0.0,       # NEW: measured from rest
    reach_m=6.4,               # floor across both bands, at that entry
    setup_digest="…")          # the controller_digest above
```

**Measure from rest and record it.** Reach is monotone in entry speed
for a horizontal dash, so a floor taken at 0.0 m/s holds for every
approach — the guarantee becomes unconditional instead of conditional on
how the content's approach is built. The field exists so the assumption
is visible rather than implicit; a future row measured from a running
start is then honestly narrower rather than silently wrong.

Everything else in §8a stands. `reach_m` is a floor and not a best case;
outside either band is `outside_measured_scope`; stronger is not
automatically suitable.

**4. Keep unsupported qualification unavailable until both halves
exist.** Explicitly: until the engine sends `controller_digest` AND
`CROSSING_EVIDENCE` carries a row for the provider, `qualifies_for_gap`
must keep answering `setup_identity_unknown` / `no_envelope_measured`
and the gate must stay refused. **Do not wire `layout.validate` to it
before both**, for the reason §8c already gives: with the table empty,
wiring it refuses every gated Zone with a message indistinguishable from
a genuinely unsound one.

**5. The `DASH_IMPULSE` divergence, not settled here.** What the engine
implements is a velocity in m/s: `player.velocity += dir * force`, along
camera-forward, bounded 4–20 by `echo.py`. Design 1 §13.1's "distance in
metres" is not what any code does. Changing the schema to match the
implementation costs a doc edit; changing the implementation to match
the doc changes how every existing dash feels and invalidates any
measurement taken before it. That is a design call, not an engine one.

### 8c. The integration boundary, stated plainly

**`qualifies_for_gap` has test callers only.** Nothing in production
calls it, and what refuses an undeclared gate today is still
`topology.reachability`, on the Archipelago side. Saying otherwise would
put this in the same class as the checks this project keeps
cataloguing — correct, and never handed the case that fails it.

**The two obligations are separate and neither substitutes for the
other:**

| | Question | Where it is answered | State |
|---|---|---|---|
| **AP obtainability** | can a player who reaches this location have got the capability? | `topology.reachability`, from the §4a contract | enforced, by refusal (§6) |
| **Physical suitability** | does the provider they have actually make this crossing? | `layout.validate` | **helper written, not wired** |

**The consumer is `layout.validate`, and the reason is metres.** A
capability gate lives on a `TopologyEdge`, and the bridge has no
distances until the engine returns `layout_result`. At that point it
does: a gated `TRAVERSAL_ONLY` edge is reached by a plug, and the layout
already carries `anchors[source_anchor]` and `anchors[destination]` —
two points, so a gap and a rise, in metres, already validated as finite
and in-bounds. Generation cannot ask the question because the rooms are
not placed yet; validation can, and it is already the place a Zone is
refused for physical evidence it does not carry.

**It is not wired yet on purpose.** With `CROSSING_EVIDENCE` empty,
wiring it would refuse every gated Zone with `no_envelope_measured` —
true, but indistinguishable at the seam from a Zone that is genuinely
unsound, and composition emits no gates today anyway. The wiring lands
with the first evidence entry, and it lands as a `c.fail` beside the
others, with the qualification's own `reason` in the sentence.

---

## What this lane does next

Nothing on the AP side until the §7 choice is made. `reachability` keeps
refusing an AP-relevant gate with no matching guarantee,
`declared_capabilities` stays unpassed by production, and composition
emits no gates — so the restriction costs nothing today and removes no
option tomorrow.

On the qualification side: the model is tested and the seam is named.
It needs the evidence shape agreed (§8b) and then one measured row
before `layout.validate` starts asking.
