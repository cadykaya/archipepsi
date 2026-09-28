"""Batch 047 — the skiff's fitted parts: shield, railings, traction.

    .tools/blender/blender -b -noaudio --python tools/blender/build_skiffkit.py

A03.2 and A03.3. Batch 045 gave the skiff a body; this gives it the
parts that are fitted TO that body and have to survive being looked at
from a rider's eye rather than from outside the vehicle.

**WHAT IT IS NOT.** No collider, body, trigger, light, camera or script.
`_shield()` already builds a real `CollisionShape3D` on an
`AnimatableBody3D`; this does not replace it, duplicate it or change its
height. Nothing here moves the parent, changes a speed or authors root
motion -- the rollers are nodes, and what turns them is Production's.

## The cover height is not ours to change

`SHIELD_HEIGHT` is 1.25 and the panel is 0.3 x 1.25 x 4.0 centred at
local (-1.85, 0.825, 0) in the carrier's frame, on the side away from
the docks. The visual is authored around exactly that box:

* its TOP stays at 1.25 above the deck, because that is the cover height
  a rider crouches behind and shoots over;
* nothing is added above it, because anything above it is the sight line
  a rider needs;
* the two DOCK sides stay clear, because `DOCK_OUT` puts a platform hard
  against the deck's outer edge and a fitting there is a fitting in the
  doorway.

## THE BOGIE CANNOT GO UNDER THE DECK, AND THAT IS A FINDING

`_track()` lays pieces 0.5 x 0.35 centred on the rail at 0.6, so the
visible track spans world 0.425 to 0.775. The deck spans 0.600 to 1.000.
**The beam already passes 0.175 m into the bottom of the deck** -- there
is no space beneath it for a truck, because the rail is in there.

So the traction assembly hangs BESIDE the beam instead: the beam is
0.5 m wide (+-0.25 of the rail centre) and the trucks stand at +-0.45,
with contact shoes that reach in to the beam's own sides. That is a real
arrangement -- outside-frame trucks running on a centre beam -- and it
is the only one this geometry allows. Reported rather than solved by
moving Production's numbers.
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import brushkit  # noqa: E402
import common  # noqa: E402
import materials  # noqa: E402
import palette as pal  # noqa: E402
import roomcollision  # noqa: E402

THEME = common.THEME
OUT = "batch047/skiffkit"
DENSITY = materials.ARCH_DENSITY
SIZE = materials.ARCH_SIZE

#: Production's numbers, from `railway_scenario.gd`. Mirrored, and the
#: assertions below are what stops a mirror from drifting.
RAIL_Y = 0.6
DECK = (4.0, 0.4, 4.0)
SHIELD_HEIGHT = 1.25
SHIELD_THICK = 0.3
#: `_shield()`: local x = -(DECK.x * 0.5 - 0.15), y = DECK.y * 0.5 +
#: SHIELD_HEIGHT * 0.5. Node origin is the deck box CENTRE.
SHIELD_X = -(DECK[0] * 0.5 - 0.15)
SHIELD_Z = DECK[1] * 0.5 + SHIELD_HEIGHT * 0.5
#: Their track piece: 0.5 wide, 0.35 tall, centred on the rail.
BEAM_HALF_W = 0.25
BEAM_HALF_H = 0.175
#: Where a traction truck hangs: clear of the beam's 0.25 half width,
#: inside the deck's 2.0. A pair, one each side, mirrored.
MOUNT_X = 0.45

_IMAGES = {}
_MATERIALS = {}


def _image(role):
    if role not in _IMAGES:
        canvas, _ = materials.paint(THEME, role)
        _IMAGES[role] = canvas.to_blender("sk_%s_%s" % (THEME, role))
    return _IMAGES[role]


def _paint(obj, role, collide=None):
    if role not in _MATERIALS:
        _MATERIALS[role] = common.make_textured_material(
            role, _image(role), roughness=pal.roughness(THEME))
    common.assign(obj, _MATERIALS[role])
    return roomcollision.paint_role(obj, collide or role)


def _b(tag, size, at, role="wall", collide=None):
    return _paint(brushkit.block(tag, size, at), role, collide)


def assert_cover_intact(objects, label):
    """The cover height and the firing line are Production's, not ours.

    Two things, and both have been got wrong by somebody adding a nice
    coping to a shield:

    * the top must be AT `SHIELD_HEIGHT` above the deck, not above it --
      a visual that raises the cover by 6 cm raises the crouch line;
    * nothing may stand proud on the OUTBOARD face beyond the panel's
      own thickness, because that face is what a shooter is behind.
    """
    vec = __import__("mathutils").Vector
    top = max((o.matrix_world @ vec(c)).z
              for o in objects for c in o.bound_box)
    want = DECK[1] * 0.5 + SHIELD_HEIGHT
    if top > want + 1e-6:
        raise SystemExit(
            "%s reaches node z %.3f and Production's cover tops at %.3f "
            "(SHIELD_HEIGHT %.2f above the deck). A visual that raises "
            "the shield raises the height a rider has to shoot over."
            % (label, top, want, SHIELD_HEIGHT))
    return top


def assert_clear_of_docks(objects, label, margin=0.001):
    """Nothing overhangs the deck on the lateral axis.

    `_docks()` takes `side = UP.cross(along)` for all three platforms,
    so every dock is on the carrier's +x -- and `DOCK_OUT` puts the pad
    hard against the deck's outer edge, with the inner edges meeting
    exactly. A fitting past that line is a fitting in the doorway.

    The -x side is the shield's, and `_shield()` puts the panel flush
    with the deck edge (centre -1.85, thickness 0.30, so -2.00 to
    -1.70). Flush is the limit there too: a coping that overhangs the
    hull by 3 cm is 3 cm of something to catch on a dock the carrier
    passes, and the assertion caught exactly that in this batch's own
    first cut.
    """
    vec = __import__("mathutils").Vector
    half = DECK[0] * 0.5
    for obj in objects:
        xs = [(obj.matrix_world @ vec(c)).x for c in obj.bound_box]
        if max(xs) > half + margin or min(xs) < -half - margin:
            raise SystemExit(
                "%s: %s spans x %.3f..%.3f and the deck is +-%.2f. The "
                "sides are where the docks meet the deck -- a fitting "
                "past that line is a fitting in the doorway."
                % (label, obj.name, min(xs), max(xs), half))


def assert_clear_of_beam(objects, label, mount_x=0.0):
    """Nothing occupies the rail beam's own volume, WHERE IT IS MOUNTED.

    Their track spans +-0.25 laterally and 0.425..0.775 in world height,
    which is node z -0.375..-0.025 about the deck centre. A truck drawn
    where the beam is does not read as riding it; it reads as clipping.

    `mount_x` is where the asset actually hangs, because checking an
    asset at its authoring origin answers the wrong question. The truck
    is authored about its own hanger and mounts at +-`MOUNT_X`, so BOTH
    placements are checked -- the second mirrored, since that is how the
    pair is fitted.
    """
    vec = __import__("mathutils").Vector
    lo = RAIL_Y - BEAM_HALF_H - (RAIL_Y + DECK[1] * 0.5)
    hi = RAIL_Y + BEAM_HALF_H - (RAIL_Y + DECK[1] * 0.5)
    for sign in (1.0, -1.0):
        for obj in objects:
            corners = [obj.matrix_world @ vec(c) for c in obj.bound_box]
            xs = [sign * (c.x + mount_x) for c in corners]
            x0, x1 = min(xs), max(xs)
            z0 = min(c.z for c in corners)
            z1 = max(c.z for c in corners)
            if x0 > BEAM_HALF_W or x1 < -BEAM_HALF_W:
                continue
            if z0 > hi or z1 < lo:
                continue
            raise SystemExit(
                "%s: mounted at x %+.2f, %s occupies x %.3f..%.3f, "
                "z %.3f..%.3f, which is inside the rail beam (x +-%.2f, "
                "z %.3f..%.3f). The beam is solid geometry Production "
                "lays; art does not share its volume."
                % (label, sign * mount_x, obj.name, x0, x1, z0, z1,
                   BEAM_HALF_W, lo, hi))


def skiff_shield():
    """`sp_skiff_shield` -- the cover, given a face and a firing edge.

    Authored about the carrier's node origin (the deck box centre), so
    it drops in where `_shield()` puts its panel and needs no offset.

    The panel is 0.30 thick and the visual stays inside that: ribs on
    the INBOARD face where a rider sees them, a plain outboard face
    because that is the one being shot at, and a capping rail exactly at
    the cover height rather than above it.
    """
    parts = []
    half_len = DECK[2] * 0.5
    # The panel itself, exactly Production's box.
    body = _b("shield_panel", (SHIELD_THICK, DECK[2], SHIELD_HEIGHT),
              (SHIELD_X, 0, SHIELD_Z), "wall")
    # The capping rail, INSIDE the cover height: it eats 0.08 of the
    # panel rather than adding 0.08 to it.
    # Grown INBOARD only: the outboard face stays flush with the deck
    # edge at -2.00, because that is the hull line.
    parts.append(_b("shield_cap", (SHIELD_THICK + 0.06, DECK[2], 0.08),
                    (SHIELD_X + 0.03, 0,
                     SHIELD_Z + SHIELD_HEIGHT * 0.5 - 0.04),
                    "accent", "trim"))
    # Inboard ribs -- what a rider standing behind it actually sees.
    for i, y in enumerate((-1.4, -0.47, 0.47, 1.4)):
        parts.append(_b("shield_rib_%d" % i,
                        (0.09, 0.18, SHIELD_HEIGHT - 0.16),
                        (SHIELD_X + SHIELD_THICK * 0.5 + 0.045, y,
                         SHIELD_Z - 0.04), "trim"))
    # A kick plate at the foot, where boots go.
    parts.append(_b("shield_kick", (SHIELD_THICK + 0.05, DECK[2], 0.22),
                    (SHIELD_X + 0.025, 0,
                     SHIELD_Z - SHIELD_HEIGHT * 0.5 + 0.11), "trim"))
    # THE ATTACHMENT POINTS A03.2 ASKS FOR, as their own nodes: three
    # brackets tying the panel to the deck. A shield welded to nothing
    # is a wall somebody left on a cart.
    for i, y in enumerate((-half_len + 0.3, 0.0, half_len - 0.3)):
        parts.append(_b("shield_mount_%d" % i, (0.34, 0.22, 0.26),
                        (SHIELD_X + 0.32, y,
                         SHIELD_Z - SHIELD_HEIGHT * 0.5 + 0.13),
                        "accent", "trim"))
    return body, parts


def skiff_rail():
    """`sp_skiff_rail` -- a fitted guard for an END, with its mounts.

    Separate from the shield because it is a different job: the shield
    is cover on one flank, this is a guard across an end. Authored about
    the deck centre with the end at +y, so one asset serves both ends by
    yaw rather than by being built twice.

    Tops at 1.05 above the deck -- under `SHIELD_HEIGHT`, so the cover
    stays the tallest thing on the vehicle.
    """
    parts = []
    top = DECK[1] * 0.5
    guard = top + 1.05
    y = DECK[2] * 0.5 - 0.07
    body = _b("rail_panel", (DECK[0] - 0.4, 0.1, 0.46),
              (0, y, top + 0.23), "trim")
    parts.append(_b("rail_cap", (DECK[0] - 0.3, 0.14, 0.09),
                    (0, y, guard - 0.045), "accent", "trim"))
    for side in (-1.0, 1.0):
        parts.append(_b("rail_post_%d" % int(side),
                        (0.13, 0.13, guard - top),
                        (side * (DECK[0] * 0.5 - 0.3), y,
                         (guard + top) * 0.5), "trim"))
        # The clip that holds it to the deck: an attachment point, as
        # its own node, at the foot of each post.
        parts.append(_b("rail_mount_%d" % int(side), (0.24, 0.24, 0.12),
                        (side * (DECK[0] * 0.5 - 0.3), y, top + 0.06),
                        "accent", "trim"))
    parts.append(_b("rail_mid", (DECK[0] - 0.36, 0.08, 0.07),
                    (0, y, top + 0.62), "trim"))
    return body, parts


def skiff_bogie():
    """`sp_skiff_bogie` -- the traction truck, BESIDE the beam.

    See the module docstring: the rail head is at world 0.775 and the
    deck underside is at 0.600, so the beam is already 0.175 m inside
    the deck and there is nowhere under it for a truck. This one hangs
    off the deck's underside at x = +-0.45, clear of the 0.5 m beam, and
    reaches in with contact shoes.

    **The rollers are NODES, not motion.** `roller_0` and `roller_1`
    are separate objects whose local origin is their own axle, so a
    runtime that wants them to turn with travel can rotate them without
    touching the parent. Art declares the part; Production decides what
    spins it and how fast. Nothing here is animated and no root motion
    is authored.

    Authored about the carrier's node origin, so a pair drops in at
    x = -0.45 and x = +0.45 with no vertical offset.
    """
    parts = []
    under = -DECK[1] * 0.5           # node z of the deck's underside
    # The frame hangs from the deck and is the body, because everything
    # else on the truck is carried by it.
    body = _b("bogie_frame", (0.26, 1.6, 0.34), (0, 0, under - 0.13),
              "trim")  # authored about its own hanger; mounts at MOUNT_X
    parts.append(_b("bogie_hanger", (0.2, 0.5, 0.1), (0, 0, under + 0.03),
                    "accent", "trim"))
    for tag, y in (("0", 0.52), ("1", -0.52)):
        # The roller: an 8-sided wheel lying on its side, its axis
        # across the track, drawn at the beam's own mid-height.
        wheel = brushkit.prism("roller_%s" % tag, 0.14, 0.12, 8,
                               (-0.06, y, under - 0.18))
        brushkit.spin(wheel, "y", 90.0)
        parts.append(_paint(wheel, "accent", "trim"))
        # The shoe that reaches in to the beam's side. It stops 0.01
        # short of the beam -- `assert_clear_of_beam` refuses anything
        # that shares the beam's volume.
        parts.append(_b("shoe_%s" % tag, (0.14, 0.3, 0.1),
                        (-0.13, y, under - 0.3), "trim"))
        parts.append(_b("axle_%s" % tag, (0.1, 0.1, 0.1),
                        (0.02, y, under - 0.18), "trim"))
    # A damper between the frame and the deck: the reason the truck is a
    # truck rather than a bracket.
    parts.append(_b("bogie_damper", (0.12, 0.12, 0.2),
                    (0.05, 0, under - 0.1), "accent", "trim"))
    return body, parts


#: name, builder, which assertions apply
ASSETS = [
    ("sp_skiff_shield", skiff_shield, ("cover", "docks")),
    ("sp_skiff_rail", skiff_rail, ("docks",)),
    ("sp_skiff_bogie", skiff_bogie, ("beam",)),
]


def main():
    made = {}
    for name, build, checks in ASSETS:
        common.reset_scene()
        _IMAGES.clear()
        _MATERIALS.clear()
        body, parts = build()
        objects = [body] + parts
        # NO set_origin_group: every one of these is authored about the
        # carrier's own node origin, and re-anchoring would move it.
        if "cover" in checks:
            assert_cover_intact(objects, name)
        if "docks" in checks:
            assert_clear_of_docks(objects, name)
        if "beam" in checks:
            assert_clear_of_beam(objects, name, MOUNT_X)
        for obj in objects:
            common.uv_project_world(obj, DENSITY, SIZE)
        common.assert_parts_touch(body, parts, name)
        entry = common.export_glb(body, "%s/%s.glb" % (OUT, name), "prop",
                                  tier="architecture", texture_size=SIZE,
                                  anchor="centre", parts=parts)
        entry["parts"] = [p.name for p in parts]
        entry["origin_means"] = "RailCarrier node origin: the deck box centre"
        made[name] = entry
        print("[skiffkit] %-18s %4d tris, %d part(s)"
              % (name, entry["triangles"], len(parts)))

    path = os.path.join(common.MODEL_DIR, OUT, "manifest.json")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    shared = {
        "batch": "047", "kind": "carrier_fitting",
        "status": "PROPOSAL -- visual only, review-pending, not a "
                  "production default",
        "carries": "mesh and named parts only. No collider, body, trigger, "
                   "light, camera or script. No animation, no root motion.",
        "fitted_to": {
            "production_ref": "claude/archipepsi-0-4-blindside",
            "rail_y": RAIL_Y, "deck": list(DECK),
            "shield_height": SHIELD_HEIGHT,
            "shield_local_centre": [SHIELD_X, SHIELD_Z, 0.0],
            "beam_half_width": BEAM_HALF_W,
            "bogie_mount_x": MOUNT_X,
        },
        "texels_per_metre": DENSITY,
        "not_changed": ["collision", "cover height", "speeds", "timings",
                        "placement", "route availability",
                        "any approved asset"],
    }
    with open(path, "w", encoding="utf-8") as handle:
        json.dump({k: dict(shared, **v) for k, v in made.items()},
                  handle, indent=2, sort_keys=True)
    common.log("manifest %s" % path)


if __name__ == "__main__":
    main()
