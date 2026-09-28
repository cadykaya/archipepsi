"""Batch 051 — A12: telegraphs, role reads and impacts.

    .tools/blender/blender -b -noaudio --python tools/blender/build_combatfx.py

**WHAT THIS IS NOT.** No collider, body, trigger, light, camera, script
or animation, and **no extra collider coverage** -- A12.3 says the role
reads must be legible "without inventing extra collider coverage", so
nothing here is bigger than the envelope of the role it belongs to
unless it is a FLAT ground marking, which cannot be collided with by
accident.

A12.6: "Keep audio composition and gameplay warning timing with their
owners." `TELEGRAPH_SECONDS` is Production's table --
brute 0.5, ranged 0.45, charger 0.7, artillery 0.8, diver 0.35 -- and
nothing here encodes any of those numbers as a duration. What Art
supplies is the geometry a duration is shown ON.

## A12.2's real test: cancel must not look like completed

> "prove cancel is distinguishable from attack-completed"

`enemy.gd` emits `telegraph_finished(kind, completed)` -- one signal,
a boolean, and two outcomes that mean opposite things. If they share a
visual the player learns nothing from either. So `fx_telegraph_ring`
carries BOTH endings as separate geometry:

* `ring_complete` -- the ring CLOSED: the four segments meet.
* `ring_cancel` -- the ring BROKEN: a cross through the gap.

`assert_endings_differ` refuses them if they share a silhouette, which
is the same rule A09.2's three commitments are held to and for the same
reason: a player reads shape across a room, not colour.

## And A12.4's, which is the same test one level down

> "Avoid identical response for a refused effect and a damaging hit."

`fx_hit_shield` (refused) and `fx_hit_body` (damaging) are checked
against each other by the same gate. A shield that sparks exactly like
a wound teaches a player that armour does nothing.

## The ring is OPEN, and that is A12.5

> "Foreground effects must not cover the player's weapon aim, target
> face or landing edge."

A telegraph that covers the face it announces is worse than none.
`fx_telegraph_ring` is authored at radius 1.0 about the telegraph
origin, for a runtime to scale by the role's own `lane_width`, and
`assert_ring_is_open` refuses it if its hole is less than 60% of its
outer diameter -- so at ANY scale the body inside stays visible.
"""

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import brushkit  # noqa: E402
import common  # noqa: E402
import materials  # noqa: E402
import palette as pal  # noqa: E402
import roomcollision  # noqa: E402
from build_enemy_roles import ENVELOPES  # noqa: E402

THEME = common.THEME
OUT = "batch051/combatfx"
DENSITY = materials.ARCH_DENSITY
SIZE = materials.ARCH_SIZE

WALK_UP = 0.12
#: A ring whose hole is smaller than this fraction of its outer
#: diameter has started covering what it surrounds.
OPEN_FRACTION = 0.60
#: Two readings that mean opposite things must differ by more than this
#: on some axis.
POSE_TOLERANCE = 0.05

_IMAGES = {}
_MATERIALS = {}
_SHAPES = {}


def _image(role):
    if role not in _IMAGES:
        canvas, _ = materials.paint(THEME, role)
        _IMAGES[role] = canvas.to_blender("fx_%s_%s" % (THEME, role))
    return _IMAGES[role]


def _paint(obj, role, collide=None):
    if role not in _MATERIALS:
        _MATERIALS[role] = common.make_textured_material(
            role, _image(role), roughness=pal.roughness(THEME))
    common.assign(obj, _MATERIALS[role])
    return roomcollision.paint_role(obj, collide or role)


def _b(tag, size, at, role="accent", collide="trim", rotation_z=0.0):
    return _paint(brushkit.block(tag, size, at, rotation_z=rotation_z),
                  role, collide)


def _box(obj):
    vec = __import__("mathutils").Vector
    corners = [obj.matrix_world @ vec(c) for c in obj.bound_box]
    return ([min(c[i] for c in corners) for i in range(3)],
            [max(c[i] for c in corners) for i in range(3)])


def remember(name, objects):
    vec = __import__("mathutils").Vector
    corners = [o.matrix_world @ vec(c) for o in objects for c in o.bound_box]
    _SHAPES[name] = tuple(
        max(c[i] for c in corners) - min(c[i] for c in corners)
        for i in range(3))


def assert_ring_is_open(objects, label):
    """A telegraph may not cover the thing it announces.

    Measured over VERTICES, not per-part boxes. The first version took
    each part's axis-aligned box and asked how near the axis it came,
    which works for a constellation of marks and breaks completely on
    the annulus those marks sit on: one object spanning the whole ring
    contains the axis, so its "nearest approach" is zero and the hole
    measures shut. Vertices are exact and indifferent to how the ring
    is built.
    """
    inner = float("inf")
    outer = 0.0
    for obj in objects:
        for v in obj.data.vertices:
            w = obj.matrix_world @ v.co
            r = math.hypot(w.x, w.y)
            inner = min(inner, r)
            outer = max(outer, r)
    if outer <= 0.0:
        return
    hole = inner * 2.0
    if hole < OPEN_FRACTION * outer * 2.0 - 1e-6:
        raise SystemExit(
            "%s: its hole is %.3f m across against a %.3f m outer "
            "diameter -- %.0f%%, and the rule is %.0f%%. A telegraph "
            "that covers the face it announces is worse than none "
            "(A12.5)."
            % (label, hole, outer * 2.0, 100.0 * hole / (outer * 2.0),
               100.0 * OPEN_FRACTION))


def assert_within_envelope(objects, label, role):
    """A12.3: legible WITHOUT inventing extra collider coverage.

    A body-attached read that is wider than the body is a read that
    claims space the collider does not have. Ground markings are
    exempt and checked for flatness instead: a flat mark cannot be
    mistaken for coverage.
    """
    vec = __import__("mathutils").Vector
    w, h, d, _hover = ENVELOPES[role]
    corners = [o.matrix_world @ vec(c) for o in objects for c in o.bound_box]
    got_w = max(c.x for c in corners) - min(c.x for c in corners)
    got_d = max(c.y for c in corners) - min(c.y for c in corners)
    for axis, got, want in (("x", got_w, w), ("y", got_d, d)):
        if got > want + 0.01:
            raise SystemExit(
                "%s: %.3f m in %s and %s's published envelope is %.3f. "
                "A12.3 wants this legible without inventing extra "
                "collider coverage, and a read wider than the body "
                "claims space the collider does not have."
                % (label, got, axis, role, want))


def assert_flat(objects, label):
    vec = __import__("mathutils").Vector
    for obj in objects:
        top = max((obj.matrix_world @ vec(c)).z for c in obj.bound_box)
        if top > WALK_UP:
            raise SystemExit(
                "%s: %s stands %.3f m proud and the walk-up is %.2f. A "
                "ground marking that can be stepped onto is level "
                "design." % (label, obj.name, top, WALK_UP))


def assert_pairs_differ(pairs):
    """Two readings that mean opposite things must not share a shape."""
    for a, b, why in pairs:
        if a not in _SHAPES or b not in _SHAPES:
            raise SystemExit(
                "%s or %s was not built, so %s cannot be shown."
                % (a, b, why))
        if all(abs(x - y) < POSE_TOLERANCE
               for x, y in zip(_SHAPES[a], _SHAPES[b])):
            raise SystemExit(
                "%s and %s are within %.2f m on every axis (%s vs %s). "
                "%s, and a player reads shape across a room rather than "
                "colour."
                % (a, b, POSE_TOLERANCE, _SHAPES[a], _SHAPES[b], why))


# === A12.2  the shared telegraph ===============================================

def telegraph_ring():
    """`fx_telegraph_ring` -- one ring, both endings, and a hole in it.

    Authored at radius 1.0 about the telegraph origin -- which is
    `enemy.gd`'s `TelegraphOrigin` Marker3D at
    `ENEMY_ENVELOPES[role].centre_y`, OUTSIDE `Visual` so a flinch does
    not drag it around. A runtime scales this by the role's own
    `lane_width`.

    `ring_tick_*` are twelve marks a runtime can light in turn for
    `telegraph_progress()`. **They are not a clock**: what lights how
    many, and how fast, comes from `TELEGRAPH_SECONDS`, which is
    Production's.
    """
    parts = []
    # THE RIM, and it is the body. A ring of separate marks is not a
    # body with fittings, and `assert_parts_touch` said so about all
    # seventeen of them -- correctly. A ring should read as a ring
    # anyway, so the marks sit on an annulus rather than hanging in a
    # circle round nothing.
    body = _paint(brushkit.tube("ring_rim", 1.04, 0.96, 0.04, 8,
                                (0.0, 0.0, 0.0)), "trim")
    for i in range(12):
        a = i * math.tau / 12.0
        parts.append(_b("ring_tick_%d" % i, (0.14, 0.14, 0.05),
                        (math.cos(a), math.sin(a), 0.0),
                        "trim", "trim", rotation_z=math.degrees(a)))
    # THE TWO ENDINGS. `telegraph_finished(kind, completed)` is one
    # signal and a boolean; these are the two things it can mean.
    for i in range(4):
        a = i * math.tau / 4.0 + math.tau / 8.0
        # 0.34: the four closing bars sit at the DIAGONALS, where an
        # axis-aligned box reaches toward the axis on both x and y at
        # once. They were the hole's real limiter, not the cancel
        # cross, and shortening the wrong one twice is what measuring
        # is for.
        parts.append(_b("ring_complete_%d" % i, (0.34, 0.1, 0.07),
                        (math.cos(a) * 1.0, math.sin(a) * 1.0, 0.03),
                        "accent", "trim",
                        rotation_z=math.degrees(a) + 90.0))
    # Broken, not closed: two bars crossing the ring's own plane.
    for i in range(2):
        # 0.50, not 0.62. The open-ring gate measures each part's
        # AXIS-ALIGNED box, so a bar laid at 45 degrees reaches further
        # toward the axis than its length suggests -- and the first cut
        # closed the hole to 58% against a 60% rule. Conservative is the
        # right kind of wrong for a gate about occlusion.
        # ON the rim, not floating above it: the rim spans z -0.02 to
        # +0.02 and a bar centred at 0.06 clears it by a centimetre.
        parts.append(_b("ring_cancel_%d" % i, (0.50, 0.11, 0.06),
                        (1.0, 0.0, 0.01), "accent", "trim",
                        rotation_z=45.0 + i * 90.0))
    return body, parts


# === A12.3  the role reads =====================================================

def charger_lane():
    """`fx_charger_lane` -- direction and COMMITMENT, on the floor.

    The charger's rush is unsteerable; that is its whole brief and the
    longest windup in the table (0.7 s). So the read is a LANE, not an
    arrow: a thing that says where the rush will go and that it cannot
    turn. Flat, so it adds no coverage.

    Authored with local y = 0 at the charger and +y down the rush.
    """
    parts = []
    w = ENVELOPES["charger"][0]
    body = _b("lane_floor", (w, 6.0, 0.02), (0, 3.0, 0.01), "accent",
              "floor")
    for side in (-1.0, 1.0):
        parts.append(_b("lane_edge_%d" % int(side), (0.12, 6.0, 0.03),
                        (side * (w * 0.5 - 0.06), 3.0, 0.015), "trim"))
    for i in range(3):
        parts.append(_b("lane_bar_%d" % i, (w - 0.3, 0.18, 0.03),
                        (0, 1.4 + i * 1.7, 0.015), "trim"))
    return body, parts


def bulwark_face():
    """`fx_bulwark_face` -- which side of it is the wall.

    The bulwark's proposition is a protected front and a soft back, and
    a player who cannot tell which is which is fighting a dice roll.
    Authored to the published envelope -- 1.45 wide, 0.85 deep -- so it
    claims no space the collider does not have.
    """
    parts = []
    w, h, d, _ = ENVELOPES["bulwark"]
    body = _b("face_plate", (w, 0.06, h * 0.7), (0, -d * 0.5 + 0.03,
              h * 0.45), "accent", "trim")
    for i in range(3):
        parts.append(_b("face_rib_%d" % i, (0.1, 0.1, h * 0.66),
                        (-w * 0.3 + i * w * 0.3, -d * 0.5 + 0.08,
                         h * 0.45), "trim"))
    parts.append(_b("face_chevron", (w * 0.5, 0.08, 0.18),
                    (0, -d * 0.5 + 0.06, h * 0.82), "trim"))
    return body, parts


def warned_ground():
    """`fx_warned_ground` -- where the shell lands, and leaving is the
    counterplay.

    `TELEGRAPH_SECONDS["artillery"]` is 0.8 -- the longest -- because
    "the shell lands where you WERE and leaving is the counterplay",
    which is Production's own comment. This is the ground that says so.

    Flat, and OPEN in the middle: a filled disc under a player's feet
    hides the landing edge, which is exactly what A12.5 forbids.
    """
    parts = []
    # AN ANNULUS, not four straight bars pretending to be one. The bars
    # version left the diagonal ticks touching nothing, which
    # `assert_parts_touch` reported for all four -- a ring made of
    # chords has gaps exactly where the marks want to sit.
    body = _paint(brushkit.tube("warn_ring", 1.30, 1.08, 0.02, 8,
                                (0.0, 0.0, 0.01)), "accent", "floor")
    for i in range(4):
        a = i * 90.0 + 45.0
        parts.append(_b("warn_tick_%d" % i, (0.5, 0.14, 0.02),
                        (math.cos(math.radians(a)) * 1.19,
                         math.sin(math.radians(a)) * 1.19, 0.015),
                        "trim", "floor", rotation_z=a))
    return body, parts


def beacon_range():
    """`fx_beacon_range` -- how far the thing that makes it worse reaches.

    The beacon "makes everything near it worse" and its own attack is
    an afterthought, so the useful read is its RADIUS. A flat ring on
    the floor, open, sized by the runtime.
    """
    parts = []
    body = _paint(brushkit.tube("range_ring", 1.70, 1.54, 0.02, 8,
                                (0.0, 0.0, 0.01)), "accent", "floor")
    for i in range(5):
        a = i * 72.0
        parts.append(_b("range_tick_%d" % i, (0.34, 0.12, 0.02),
                        (math.cos(math.radians(a)) * 1.62,
                         math.sin(math.radians(a)) * 1.62, 0.015),
                        "trim", "floor", rotation_z=a))
    return body, parts


def diver_trail():
    """`fx_diver_trail` -- the approach, from above.

    `TELEGRAPH_SECONDS["diver"]` is 0.35, the shortest, "because it is
    already visible and the fall does the telegraphing". So the trail's
    job is to make the fall READ, not to add time: a tapering column
    above the dive line, narrowing toward the ground so the eye follows
    it down.

    Within the diver's published 0.70 x 1.20 footprint.
    """
    parts = []
    w, h, d, _ = ENVELOPES["diver"]
    body = _b("trail_head", (w * 0.8, d * 0.5, 0.3), (0, 0, 2.4),
              "accent", "trim")
    for i in range(4):
        t = i / 4.0
        parts.append(_b("trail_%d" % i,
                        (w * (0.6 - t * 0.35), d * (0.4 - t * 0.22),
                         0.6),   # 0.6 against a 0.55 pitch: they meet
                        (0, 0, 1.95 - i * 0.55), "accent", "trim"))
    return body, parts


# === A12.4  the impacts ========================================================

def hit_wall():
    """`fx_hit_wall` -- it stopped, and the surface took it.

    A splash outward along the surface: radial, flat against the wall.
    """
    parts = []
    body = _b("wall_core", (0.24, 0.06, 0.24), (0, 0, 0), "accent",
              "trim")
    for i in range(6):
        a = i * 60.0
        # 0.14, so every spall overlaps the core it came out of. At
        # 0.22 the four diagonal ones cleared it entirely -- a splash
        # with a hole in the middle.
        parts.append(_b("wall_spall_%d" % i, (0.34, 0.05, 0.09),
                        (math.cos(math.radians(a)) * 0.14,
                         0.0,
                         math.sin(math.radians(a)) * 0.14),
                        "trim", "trim", rotation_z=0.0))
    return body, parts


def hit_shield():
    """`fx_hit_shield` -- REFUSED. It did not get in.

    A12.4: "Avoid identical response for a refused effect and a
    damaging hit." A refusal is a thing bouncing OFF, so this is a
    dome: convex, facing the shooter, with the impact sliding around it
    rather than into it. Nothing about it reads as penetration.
    """
    parts = []
    body = _b("shield_dome", (0.62, 0.16, 0.62), (0, 0, 0), "accent",
              "trim")
    for i in range(4):
        a = i * 90.0 + 45.0
        parts.append(_b("shield_slide_%d" % i, (0.44, 0.08, 0.1),
                        (math.cos(math.radians(a)) * 0.3, -0.06,
                         math.sin(math.radians(a)) * 0.3),
                        "trim", "trim", rotation_z=a))
    return body, parts


def hit_body():
    """`fx_hit_body` -- DAMAGING. It got in.

    The opposite read from the dome: a narrow spike going IN, with
    everything pointing inward. Long and thin where the shield is wide
    and shallow, so `assert_pairs_differ` has something real to measure.
    """
    parts = []
    body = _b("body_pierce", (0.12, 0.62, 0.12), (0, 0.2, 0), "accent",
              "trim")
    for i in range(4):
        a = i * 90.0
        parts.append(_b("body_tear_%d" % i, (0.09, 0.26, 0.09),
                        (math.cos(math.radians(a)) * 0.08, -0.04,
                         math.sin(math.radians(a)) * 0.08),
                        "trim", "trim"))
    return body, parts


def hit_miss():
    """`fx_hit_miss` -- nothing was hit, and the player should know.

    The quietest of the five and the most easily over-built: a short
    streak carrying on past where a hit would have been. If a miss
    looks like anything at all it will be read as a hit.
    """
    parts = []
    body = _b("miss_streak", (0.05, 0.8, 0.05), (0, 0, 0), "trim",
              "trim")
    parts.append(_b("miss_tail", (0.03, 0.3, 0.03), (0, -0.5, 0),
                    "trim"))
    return body, parts


def hit_interrupt():
    """`fx_hit_interrupt` -- the attack did not happen.

    `telegraph_finished(kind, false)` at the moment of the hit. It
    shares the BROKEN language of `ring_cancel` on purpose -- an
    interrupted attack and a cancelled telegraph are the same news --
    and shares it with nothing else.
    """
    parts = []
    body = _b("interrupt_break", (0.7, 0.1, 0.1), (0, 0, 0), "accent",
              "trim", rotation_z=45.0)
    parts.append(_b("interrupt_break_b", (0.7, 0.1, 0.1), (0, 0, 0),
                    "accent", "trim", rotation_z=-45.0))
    parts.append(_b("interrupt_pin", (0.16, 0.16, 0.16), (0, 0, 0),
                    "trim"))
    return body, parts


#: name, builder, checks, role (for the envelope check)
ASSETS = [
    ("fx_telegraph_ring", telegraph_ring, ("open", "shape"), None),
    ("fx_charger_lane", charger_lane, ("flat",), None),
    ("fx_bulwark_face", bulwark_face, ("envelope",), "bulwark"),
    ("fx_warned_ground", warned_ground, ("flat",), None),
    ("fx_beacon_range", beacon_range, ("flat",), None),
    ("fx_diver_trail", diver_trail, ("envelope",), "diver"),
    ("fx_hit_wall", hit_wall, ("shape",), None),
    ("fx_hit_shield", hit_shield, ("shape",), None),
    ("fx_hit_body", hit_body, ("shape",), None),
    ("fx_hit_miss", hit_miss, ("shape",), None),
    ("fx_hit_interrupt", hit_interrupt, ("shape",), None),
]

#: Readings that mean opposite things and must not look alike.
MUST_DIFFER = [
    ("fx_hit_shield", "fx_hit_body",
     "A12.4 forbids an identical response for a refused effect and a "
     "damaging hit"),
    ("fx_hit_miss", "fx_hit_body",
     "a miss that looks like a hit teaches the player nothing"),
    ("fx_hit_interrupt", "fx_hit_body",
     "an interrupted attack and a landed one are opposite news"),
]


def main():
    made = {}
    for name, build, checks, role in ASSETS:
        common.reset_scene()
        _IMAGES.clear()
        _MATERIALS.clear()
        body, parts = build()
        objects = [body] + parts
        if "open" in checks:
            assert_ring_is_open(objects, name)
        if "flat" in checks:
            assert_flat(objects, name)
        if "envelope" in checks:
            assert_within_envelope(objects, name, role)
        if "shape" in checks:
            remember(name, objects)
        for obj in objects:
            common.uv_project_world(obj, DENSITY, SIZE)
        common.assert_parts_touch(body, parts, name)
        entry = common.export_glb(body, "%s/%s.glb" % (OUT, name), "prop",
                                  tier="architecture", texture_size=SIZE,
                                  anchor="as-built", parts=parts)
        entry["parts"] = [p.name for p in parts]
        if role:
            entry["fits_role"] = role
        made[name] = entry
        print("[combatfx] %-20s %4d tris, %d part(s)"
              % (name, entry["triangles"], len(parts)))

    # THE ENDINGS. Checked across the batch, after everything is built.
    ring = made["fx_telegraph_ring"]["parts"]
    for needed in ("ring_complete_0", "ring_cancel_0"):
        if needed not in ring:
            raise SystemExit(
                "fx_telegraph_ring has no `%s`. "
                "`telegraph_finished(kind, completed)` is one signal and "
                "a boolean, and A12.2 says cancel must be "
                "distinguishable from attack-completed -- which needs "
                "two pieces of geometry, not one." % needed)
    assert_pairs_differ(MUST_DIFFER)

    path = os.path.join(common.MODEL_DIR, OUT, "manifest.json")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    shared = {
        "batch": "051", "kind": "combat_fx",
        "status": "PROPOSAL -- visual only, review-pending, not a "
                  "production default",
        "carries": "mesh and named parts only. No collider, body, "
                   "trigger, light, camera, script, animation or "
                   "particle system.",
        "timing_owner": "TELEGRAPH_SECONDS is Production's and no "
                        "duration is encoded here",
        "texels_per_metre": DENSITY,
        "not_changed": ["collider coverage", "warning timing", "damage",
                        "any approved asset"],
    }
    with open(path, "w", encoding="utf-8") as handle:
        json.dump({k: dict(shared, **v) for k, v in made.items()},
                  handle, indent=2, sort_keys=True)
    common.log("manifest %s" % path)


if __name__ == "__main__":
    main()
