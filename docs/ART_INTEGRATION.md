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

## Authored cluster placement (requirement 5)

**Contract:** `constants.ClusterFootprint` and
`cluster_placement_errors()`, with the numbers exported to
`Constants.CLUSTER_*` and enforced by the content registry at load.

`PROP_FOOTPRINT` is 1.4 m — right for an L0 prop, far too small for an
L2 station or a storytelling cluster, which is a composed group that
reads as one thing. Art could not author one without guessing how much
room the runtime would give it, so it did not author one.

### The envelope

| | |
| --- | --- |
| `CLUSTER_MAX_WIDTH` | 6.0 m along the wall it hangs on |
| `CLUSTER_MAX_HEIGHT` | 4.0 m |
| `CLUSTER_MAX_DEPTH` | 2.5 m out from the wall |
| `CLUSTER_CLEARANCE` | 0.4 m walk-around margin |
| `CLUSTER_MOUNTED_UNDERSIDE_MIN` | 2.75 m — a walker passes beneath |

### The anchor grammar

`floor_wall`, `floor_corner`, `wall`, `ceiling`.

**There is deliberately no free-standing floor anchor.** A cluster in the
middle of a room is a cluster on the mandatory path, and I4 says the
mandatory path is independent of optional content — an island setpiece
would either block the route or have to be walked around, and neither is
a thing to discover at runtime.

### What decides whether it fits

The **walking lane**. A floor cluster that the player can walk into costs
`depth + clearance` out of the room's span, and what remains must still
admit the widest actor (`BRUTE_LANE`). A cluster that does not collide,
or does not touch the ground, costs the lane nothing — declared rather
than inferred, because "does this have collision", read off a scene at
runtime, is exactly the question the validator and the builder answer
differently.

Orientation is explicit: `cluster_placement_errors(footprint, wall_run,
across, room_height, lane)`. `wall_run` is the wall's length, which the
width must fit along; `across` is the perpendicular span the depth
reaches into. Not `span_x` / `span_z`, because a side wall and an end
wall swap them and half the callers would swap them wrong.

### Deterministic validation

The same footprint on the same wall always gets the same answer, and
every refusal names its reason. Art asks in advance instead of finding
out when the generator declines to place something already built.

The registry checks a declared `footprint` at **load**, in the
`cluster` category (level 2, the same as a fixture), reading the same
exported numbers — so the art toolchain and the runtime cannot hold
different opinions about how big a cluster may be.

### What art can now do

Author a cluster against a published envelope, declare its footprint in
a manifest, and know before building whether it will be placeable in a
corridor, an arena or neither.

**Not decided here:** what a cluster contains. That is art's, and
inventing it would be engineering authoring content.

---

## Room-shell integration (Tier 7)

**Contract:** `archipepsi_bridge.shells`, the `room_shells` entry in the
generation request's catalog, `legal_shell_ids` on `validate_zone`, and
`chamber.shell_id` in `ContentInstantiator.build_chamber`.

D1 built most of this and the loop was never closed. `zone.py` carried
`shell_id`, `size_class` and `intent`; `validate_zone` refused a
`shell_id` that was not offered; the registry resolved fallback chains
and gated `review: pending`. **But nothing ever offered a shell.**
`legal_shell_ids` defaulted to empty everywhere in the live pipeline, so
Epsilon was never told a shell existed — and `content_instantiator.gd`
mapped a chamber type straight to its procedural id without ever reading
what Epsilon chose. Three broken links, and every link's own test passed.

### The loop, closed

```
registry manifests
  -> shells.shell_catalog()          offerable shells, by chamber type
  -> request.catalog["room_shells"]  IDS, never paths
  -> Epsilon names one               shell_id on a chamber
  -> validate_zone(legal_shell_ids)  refused if it was not offered
  -> ContentInstantiator             resolves the id, measures the result
```

### What is offerable

Three gates, and the middle one is the art lane's:

- it is a `room_shell`;
- it is **not** `review: pending` — a file existing in the tree is not
  approval, and offering a pending asset decides for whoever is still
  deciding;
- it is **authored**. A procedural entry is what the builder reaches
  anyway, so offering it would let Epsilon "choose" the thing it gets by
  choosing nothing.

Shells are matched by `semantic_tags`, and the offer is sorted — a
catalog that reshuffles makes two identical campaigns generate
differently. A chamber type with no authored shell is **absent** from the
catalog rather than present-and-empty.

### Ids, never paths

An Epsilon that can name a resource path can name any file (art
requirement 1). The catalog carries short ids from a closed list; Godot
resolves them. A test serialises the request and refuses `res://` and
`.tscn` anywhere in it.

### What the engine still owns

Unchanged from D1, and worth restating because this is the seam that
makes it load-bearing: the authored shell owns its exact geometry, Godot
**measures the instantiated result** rather than trusting the manifest,
a shell that fails measurement degrades to the placeholder, and there is
no arbitrary stretching of collision-critical geometry — discrete size
classes instead. A shell id a registry no longer carries is a downgrade,
not a crash: a saved Zone outlives a registry edit.

### Today's state, stated honestly

The committed registry is **entirely procedural**, so the catalog is
empty and Epsilon is offered nothing. That is correct: the game is ready
to receive authored shells and has none in this branch. The moment art's
approved shells land as authored entries with `review: pass`, they appear
in the catalog with no code change — and a test will fail, telling
whoever lands them to start asserting the offer rather than its absence.

**Assets were deliberately not copied across.** The seam is the
deliverable; the assets arrive when the branches are reconciled.

---

## Projectile silhouettes (requirement 13)

**Contract:** `ProjectileSilhouette` (`FAMILY`, `for_behaviour`,
`content_id`, `build`, `profile`, `reads_apart`), the `projectile_visual`
registry category, and `ContentInstantiator.projectile_visual`.

One primitive family flies three ways, and until now it looked one way:
a sphere, scaled 1.5x for a lob. The three facts a player has to read
before the shot lands were not on screen at all.

| Silhouette | Worn when | Says |
| --- | --- | --- |
| `straight` | no gravity, no blast | goes where you pointed |
| `falling` | `gravity_scale > 0` | it drops; lead the shot up |
| `lobbed` | `blast_radius > 0` | fused, and it explodes |

`blast_radius` is tested first on purpose: an `arc_lob` is ALSO fully
gravity-affected, so a selector that asked about gravity first would show
every grenade as a falling bolt.

### Colour is not available for this

An Echo is tinted by the SOURCE WORLD whose item it reinterprets, so
colour already means provenance. Spending it on behaviour would overwrite
identity with mechanics and lose both. The difference has to survive
greyscale, so it is shape:

```
straight   0.64 x 0.13 m   elongation 4.92   balance 0.59
falling    0.66 x 0.30 m   elongation 2.20   balance 0.23
lobbed     0.34 x 0.46 m   elongation 0.74   balance 0.50
```

`elongation` is length over width; `balance` is where the widest part
sits along the travel axis, 0 at the nose and 1 at the tail. Two
silhouettes read apart when elongation differs by 1.8x or balance by
0.15. Part count is deliberately not a measure — at distance a shape
built from three meshes and the same shape built from one look
identical. `make godot-legible` checks every pair, with all three built
in ONE colour so a pair that only separates by hue fails there.

### What art can now do

Author three meshes, register them as `projectile_visual` under
`projectile_straight` / `projectile_falling` / `projectile_lobbed`, and
they are used with no code change. Two rules are enforced rather than
asked for:

- **A projectile mesh carries no collision.** The hitbox is one 0.25 m
  sphere on the body for all three, and a mesh shipping its own is
  refused at instantiation — installing it would otherwise make the
  lobbed shot a different weapon from the straight one.
- **Presentation lives under a `Visual` container** and is what gets
  rotated to face the arc. Same rule and same reason as the enemy
  telegraph: `scale` on a body scales its collider.

Meshes were deliberately NOT copied from the art lane. The selection and
the intake seam are the deliverable; batch 008 arrives when the branches
are reconciled.

---

## Check state legibility (requirement 11)

**Contract:** `RewardObject.STATE_FORM_NAME`, `state_profile()`,
`forms_read_apart()`.

**The invariant is not "the destination ring exists".** It is that a
player across a room can tell a Check they have not opened from one they
already sent. Two channels were carrying that and neither reaches across
a room: the label, which is words, and the item's tint, which went from
`(0.35, 0.35, 0.4)` to `(0.25, 0.3, 0.28)` — two greys a fraction of a
shade apart, and the same grey to anyone who does not separate those
hues.

So state is carried by FORM, in the 005-R language:

| State | Form | Measured |
| --- | --- | --- |
| `locked` | an open cradle around the item — held, not yours yet | top 2.51 m, height 1.45 |
| `available` | the item alone, free, spinning fast | top 2.05 m, height 0.70 |
| `confirmed` | a collapsed chunky spent mass on the cap | top 1.28 m, height 0.28 |

`sending` is a sub-second transient between two of these and is not one
of the forms a player reads at distance.

Two states read apart when their tops differ by 0.35 m or one is 1.8x
taller. The gap is wider than twice the item's 0.12 m idle bob on
purpose: two states separated by less than the idle animation would
cross each other every second.

The measurement reads GEOMETRY and never a material, and the suite
proves it by repainting every state one flat colour at one emission and
re-measuring. The destination ring is the DESTINATION channel and is not
load bearing for state — art may move, replace or drop it without taking
the state read with it.

### What art can now do

Author a cradle and a spent mass. Any pair answers the measurement the
same way the placeholders do; nothing in the suite pins a particular
mesh, only that the forms differ.

---

## Still open, and why

| # | Requirement | Status |
| --- | --- | --- |
| 6 | `challenge_marker` semantics | Owner decision. Deferred, hook dormant |
| 14 | Telegraphs for melee and ranged | **Combat decision.** The seam exists; those two roles have no windup to attach it to, and adding one changes difficulty |
| 7 | Behaviour for the seven enveloped roles | **Combat decision.** They can be built and measured; they cannot yet be placed |
| 22 | `arch_affordance_socket` | **Art decision, and art has not made it.** Does an affordance sit on an authored mount that SHOWS its reserved footprint, or do features stay floor-placed and the row is struck? Engineering can build either; choosing is inventing a visual contract |
| 18 | Neutral `concrete_facility` dressing | **Art decision.** The one facility dressing prop is a warning plate, and the ruling forbids recolouring it. The fix is neutral vocabulary art has not built, plus a placement rule reserving the plate for warning semantics |
| — | `objective_marker` / `signage_module` navigation language | Owner decision. Not engineering's to invent |
