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

## Still open, and why

| # | Requirement | Status |
| --- | --- | --- |
| 6 | `challenge_marker` semantics | Owner decision. Deferred, hook dormant |
| — | `objective_marker` / `signage_module` navigation language | Owner decision. Not engineering's to invent |
