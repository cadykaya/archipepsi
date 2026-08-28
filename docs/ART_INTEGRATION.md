# Engine contracts the art lane consumes

**What this file is.** The art lane authors against engine truth rather
than against its own opinion of it — `tools/blender/engine_truth.py` on
`claude/archipepsi-art` imports `bridge/archipepsi_bridge/schemas/constants.py`
directly rather than transcribing numbers out of it. This document is the
index of the contracts that exist for it to consume, what each one
guarantees, and what is still open.

It is engineering's half of the seam. It does not make art decisions, and
where an art requirement turned out to need one, that is said rather than
answered.

The art lane's own requirement table lives in `docs/art/ART_FRONTIER.md`
on `claude/archipepsi-art`, numbered 1–22. This file refers to those
numbers.

---

## Enemy physical envelopes (requirement 7)

**Contract:** `constants.ENEMY_ENVELOPES`, exported to
`Constants.ENEMY_ENVELOPES` in GDScript.

The approved production family is **ten roles**, and every one of them
now has an agreed physical envelope. Seven were blocked on exactly this.

```
melee  ranged  brute            the three with behaviour
charger  bulwark  scuttler  artillery  beacon    ground roles, no behaviour yet
diver  drifter                                    flyers, no behaviour yet
```

### What an envelope says

| Field | Meaning |
| --- | --- |
| `width` / `height` / `depth` | Named, never a positional triple |
| `hover_height` | Height of the collider's **centre** above the floor. `0.0` means the role walks |
| `centre_y` | Where the collider centre sits: half the height for a walker, the hover height for a flyer |
| `bottom_y` / `top_y` | The underside and crown. `bottom_y == 0` is what *walking* means; `> 0` is what *flying* means |
| `lane_width` | The wider ground axis — what a corridor has to give it |

### The axis order, stated once

Godot is Y-up and takes `Vector3(width, height, depth)`. The authoring
tool is Z-up and writes `[width, depth, height]`. **The same three
numbers in a different order**, and a transposed height is a model that
fits a doorway on one side of the seam and not the other.

So an envelope is named fields, and both orders are *derived*:
`godot_size()` and `authoring_size()`. A test asserts each role's
`authoring_size()` equals the `proposed_box_m` its art manifest declares,
so a transposition fails a test instead of producing a rebuild.

### An envelope is physical only

Giving a role a box is **not** giving it a fight.

- `ENEMY_ROLES` (10) — has an agreed envelope. Art builds against these.
- `ENEMY_ARCHETYPES` (3) — may be placed in a Zone. Has behaviour.

`ENEMY_ARCHETYPES` is a strict subset, and `Enemy.create()` asserts a
role has a stat block before building it. Adding a role to the placeable
set is a combat decision, not a side effect of a model existing. Tests
pin the subset relation in both directions.

### What art can now do

Build all seven blocked roles against a collider that will not move.
`Constants.ENEMY_ENVELOPES` is the number to check a model against, and
`enemy.gd` builds its collider from the same table — the three magic
vectors that used to live in a `match kind:` are gone.

### One genuine conflict, recorded rather than resolved

**The drifter is taller than the number every room was built around.**

`chamber_builders.TALLEST_ACTOR` is 2.6 — the brute — and
`SECRET_UNDERSIDE_MIN` derives from it so that a secret ledge is not a
wall the brute walks into. The drifter's crown sits at **3.025 m**.

Two constants now exist and are deliberately not collapsed:

- `TALLEST_GROUND_ACTOR` = 2.6. What the secret-ledge geometry uses.
  Flyers are excluded on purpose: a flyer is steered and can descend, so
  a low soffit is a route it does not take rather than a wall it hits.
- `TALLEST_ACTOR_INCLUDING_FLYERS` = 3.025. Recorded, used by nothing.

Collapsing them would move generated geometry for a role that has no
behaviour yet. **When a flyer becomes placeable, flyer ceiling clearance
is a real question** — it fits a 3.6 m corridor and a 3.2 m doorway with
175 mm to spare, and it does not fit under a secret ledge. That is the
open item, and it is engineering's, not art's.

---

## Enemy telegraphs (requirement 14)

**Contract:** signals `telegraph_started(kind, duration)` and
`telegraph_finished(kind, completed)` on `Enemy`, plus
`telegraph_progress()`, `is_telegraphing()`, and a `TelegraphOrigin`
`Marker3D` to attach to.

Engineering owns the event, the state and the attachment point. Art owns
what a telegraph looks like. The two meet at those three things and
nowhere else.

### The lifecycle

```
_begin_telegraph(kind, duration)   ->  telegraph_started(kind, duration)
   ... the attack's own countdown ...  telegraph_progress() 0.0 -> 1.0
attack lands                       ->  telegraph_finished(kind, true)
enemy dies or despawns first       ->  telegraph_finished(kind, false)
```

Four guarantees, each with a test:

- **It derives from the real attack state.** `telegraph_progress()` reads
  the same countdown the attack uses. A presentation with its own clock
  drifts, and a drifting telegraph is a promise broken by a rounding
  error.
- **It is deterministic.** A windup that started always resolves, and a
  second one cannot open on top of it.
- **It is always closed.** Death and despawn both emit
  `telegraph_finished(kind, false)`, so a listener is told rather than
  left announcing a slam that is never coming.
- **It is never mechanics truth.** See below.

### The attachment point

`TelegraphOrigin` is a `Marker3D` at the collider's centre —
`ENEMY_ENVELOPES[role].centre_y`, the same number the collider uses, so
the two cannot drift. It is a direct child of the body rather than of
`Visual`, so a hit flinch does not drag the telegraph around with it.
Art offsets from there.

### A real bug this found

**`scale` on a `CharacterBody3D` scales its `CollisionShape3D` child.**

The brute's windup was `scale = Vector3.ONE * (1.0 + 0.12 * sin(...))` on
the body, so **its hitbox grew 12% for the half second it telegraphed**,
and the hit flinch shrank it to 88% every time it was hit. Presentation
was mechanics truth, silently, in the one place the game most wants it
not to be.

Every mesh now hangs off a `Visual` container and nothing solid does.
Presentation scales `Visual`; the collider is a direct child of the body
and cannot move. The rule is structural rather than a discipline, and a
test walks every archetype for a mesh parented to the body.

### What art can now do

Author a telegraph for the brute's slam, attached to `TelegraphOrigin`,
driven by `telegraph_started` / `telegraph_progress()` /
`telegraph_finished`. The engine's scale swell is a fallback, not a
requirement — a listener replaces the look and never the timing.

### What is still blocked, and it is not engineering's to unblock

**Two of the three placeable archetypes make no promise at all.** The
brute has a 0.5 s windup. Melee hits the instant it is in reach; ranged
fires the instant it has line of sight. There is nothing to telegraph,
and the seam reports that honestly (`is_telegraphing()` is false)
rather than inventing a delay.

Giving melee or ranged a windup **changes how hard the game is**. That is
a combat design decision and a pacing one, not an integration detail, so
it is not made here. Until it is, an authored telegraph for those two
roles has no state to attach to.

Same for the seven roles that have envelopes and no behaviour: a
telegraph needs an attack to announce.

---

## The decided rulings, applied

Six owner rulings that had been decided and not yet built.

### The affordance signal language (requirement 15)

**Contract:** `constants.AFFORDANCE_SIGNAL_HEX` / `_RGB`, exported as
`Constants.AFFORDANCE_SIGNAL`.

> FORM tells the player WHICH affordance. COLOUR tells the player THIS IS
> A CAPABILITY OPPORTUNITY.

All seven optional traversal affordances now wear the art lane's approved
`universal.signal` anchor. They used to carry six ad-hoc tints — the rail
a violet sitting beside `glitch` (which means *cosmetic corruption, no
mechanical meaning*), the breakable wall the theme **hazard** colour, and
the bounce pad and moving platform whatever the theme's accent and trim
happened to be. Seven things that look different everywhere teach
nothing.

Theme, source-game colour and Epsilon green do not redefine it, and a
test refuses each retired literal by name.

**The two dynamic channels are preserved**, and neither costs anything,
because both ride brightness or count rather than hue:
`breakable_wall_damage` (emission energy ramps with damage taken) and
`wind_ring_count`.

### Hazard orange (requirement 20)

Two misuses removed: the corner turn stripe that said *a corridor bends
here*, and a threshold strip `_greeble_room` laid across **every** room's
doorway unconditionally. Neither is a hazard, and spending the palette's
loudest colour on ordinary architecture is how it stops meaning anything.

**Nothing replaces them.** If playtesting shows turns or thresholds need
marking, it gets a non-hazard channel — neutral architectural contrast,
light placement, a trim or value change, or the future approved signage
language. A test pins the builder's hazard budget at exactly two: the
`concrete_facility` warning plate and the `platform_path` kill pit.

### Rails (requirement 16)

**Contract:** `AffordanceFeatures.rail_ride_path()` and
`build_rail_along()`.

> `ride_path` is the authoritative geometric path shared by visual mesh
> and runtime riding geometry.

The beam and the ride volume used to be two hand-written boxes with
different centres and different sizes that happened to share one
`length`. Both are now swept along one polyline, one beam segment and one
ride volume per straight segment — the shape the ruling confirmed. A
curved authored rail arrives as more points and needs no new code.

The wider footprint for banked turns stays recorded as **future
expansion, not a blocker**, per the ruling.

*Tested against a bent three-segment path on purpose.* Through the
built rail the polyline claim is untestable — a two-point path has one
segment, and a hardcoded length is indistinguishable from a derived one
when there is only one of them. Three sabotages proved that by passing.

### Epsilon's Hub bay (requirement 4)

**Contract:** `HubAnchors.EPSILON_BAY_*`, `epsilon_bay()`,
`intruders()`, `bay_problem()`.

The installation is 8.80 × 2.61 × 3.55 m and the ruling is that it keeps
its prominent back-wall presence. The bay is therefore **reserved**, and
everything else moves around it.

At the old anchor the bay would have spanned x −7.6 to +1.2 — straight
through the portal's own doorway — and the abandon console sat inside it.
Epsilon now sits between the left wall and the portal with clearance at
both ends, and the console moved to the **other side of the portal**:
outside the footprint, still beside the Zone workflow, still the obvious
way out of GENERATING. A test refuses a bay that runs through a wall or
the doorway, names any station standing in it, and fails if the console
drifts more than 6 m from the portal.

### Room enclosure (requirement 19)

Enclosed by default was already true after playtest 2 — but the **tower
was missing from the seal suite**, so the fix held by luck rather than by
test. It is in now, at two heights. Platform paths stay open by design.

### Theme lighting (requirement 3a)

**Contract:** `ContentInstantiator.light_housing(theme)`.

Six themes shared one `concrete_facility` slab because `_light` built a
hardcoded `BoxMesh` with no way to ask for anything else. Each theme now
resolves its own housing through the registry, falling back to the
procedural slab.

**Illumination stays engine-owned, and that is enforced rather than
asked for:** a housing carrying its own `Light3D` is refused with a
warning, because a mesh that changes how bright a room is by being
installed is a gameplay change arriving as art.

---

## Still open, and why

| # | Requirement | Status |
| --- | --- | --- |
| 6 | `challenge_marker` semantics | Owner decision. Deferred, hook dormant |
| 14 | Telegraphs for melee and ranged | **Combat decision.** The seam exists; those two roles have no windup to attach it to, and adding one changes difficulty |
| 7 | Behaviour for the seven enveloped roles | **Combat decision.** They can be built and measured; they cannot yet be placed |
| — | `objective_marker` / `signage_module` navigation language | Owner decision. Not engineering's to invent |
