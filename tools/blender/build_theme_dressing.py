"""Batch 013 -- the dressing the other three themes place.

    .tools/blender/blender -b --python tools/blender/build_theme_dressing.py

Batch 010 built the dressing `_theme_props` places for the themes whose
material family existed. Batch 012 built the other three families, so these
are no longer gated -- and they are the work the owner's own steer points
at: *keep expanding ACTUALLY PLACEABLE production vocabulary rather than
merely increasing an inventory number*. Every asset here is placed in every
Zone of its theme today, out of primitives.

| ID | Theme | Replaces, in `_theme_props` |
| --- | --- | --- |
| `prop_sconce` | gothic_stone | a 0.12 x 0.5 x 0.12 bracket at 1.9 m |
| `prop_sconce_flame` | gothic_stone | a 0.2 x 0.35 x 0.2 `PrismMesh` at 2.35 m |
| `prop_transit_sign` | neon_transit | a 1.6 x 0.5 x 0.08 hanging board |
| `prop_root_fall` | temple_ruin | a 0.1 sq root, 1.2 to 3.0 m long, from the top |
| `prop_column_stump` | temple_ruin | a 0.55 r cylinder, 0.6 to 1.6 m tall |

## Three things the engine keeps

* **The sign's text.** `_theme_props` puts a `Label3D` on the transit board
  reading one of six lines -- "PLATFORM e", "MIND THE STATIC". The board is
  a HOUSING, exactly like the Hub's campaign board: an authored asset that
  baked the text would be wrong the first time the list changed.
* **The root's length.** It is randomised between 1.2 m and the room's own
  height less 0.6, so this is authored at a length that TILES: the mesh is
  a 1.0 m section with flat ends, and the engine stacks or scales it.
* **The stump's height**, 0.6 to 1.6 m, likewise. Authored at 1.20 m, the
  midpoint, with its detail in the top 0.4 m so a scaled instance still has
  a broken top rather than a stretched one.

## The flame is warm light, not hazard

`ART_BIBLE.md` §2: the facility is cold, and warm yellow appears as
*localized utility pools / fixtures within a still-cold environment*. A
torch is the purest case of that rule in the game -- an actual fire, in an
actual bracket, lighting an actual few metres. It gets the warm fixture
language and NOT the `hazard` family, and the distinction matters because
Batch 004's verdict reserved orange for warning and the owner restated it
for Batch 010: orange must remain warning / hazard language.

A flame is not a warning. It is the light you can see by.
"""

from __future__ import annotations

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from mathutils import Vector  # noqa: E402

import brushkit  # noqa: E402
import common  # noqa: E402
import propkit  # noqa: E402
import palette as pal  # noqa: E402

OUT = "batch013/dressing"


def _finish(name, theme, parts, canvas, box, why, anchor="floor",
            lit=None, lit_material=None):
    obj = common.join(parts, name)
    common.uv_project_world(obj, propkit.PROP_DENSITY, propkit.PROP_SIZE)
    common.assign(obj, common.make_textured_material(
        name, canvas.to_blender(name + "_tex"), roughness=pal.roughness(theme)))
    if lit:
        glow = common.join(lit, name + "_lit")
        common.assign(glow, lit_material)
        obj = common.join([obj, glow], name)
    common.set_origin(obj, anchor)
    common.assert_fits(obj, name, box, why)
    return common.export_glb(obj, "%s/%s.glb" % (OUT, name), "prop",
                             anchor=anchor, check_flat=False)


# ----------------------------------------------------------------------
# gothic_stone
# ----------------------------------------------------------------------

def prop_sconce():
    """The bracket. Wall-mounted, thickness on Y, face pointing -Y.

    `_theme_props` gives it 0.12 x 0.5 x 0.12 and stands it 0.16 m off the
    wall -- a post, essentially. A sconce is a post that reaches OUT and
    UP, because a bracket that does not reach out puts the fire against the
    stone, and the soot streak this theme's wall already carries has to
    come from somewhere plausible.
    """
    parts = [
        # Backplate against the stone.
        brushkit.block("sc_plate", (0.20, 0.06, 0.46), (0.0, -0.03, 0.23)),
        # The arm, canted up and out.
        brushkit.block("sc_arm", (0.09, 0.26, 0.09), (0.0, -0.16, 0.34)),
        # The bowl the fire sits in.
        brushkit.block("sc_bowl", (0.22, 0.22, 0.10), (0.0, -0.27, 0.44)),
    ]
    brushkit.spin(parts[1], "X", 24.0)
    for vertex in parts[1].data.vertices:
        vertex.co += Vector((0.0, -0.02, 0.02))
    # A strap and two pins: iron banding is this theme's made language, and
    # the sconce is one of the few made things in the room.
    for z in (0.08, 0.38):
        parts.append(brushkit.block("sc_strap_%d" % int(z * 100),
                                    (0.24, 0.04, 0.05), (0.0, -0.04, z)))
    for sx in (-1.0, 1.0):
        parts.append(brushkit.block("sc_pin_%d" % int(sx), (0.05, 0.05, 0.05),
                                    (sx * 0.08, -0.07, 0.23)))
    return _finish("prop_sconce", "gothic_stone", parts,
                   # `light`, not `dark`. Iron is dark and the first two
                   # passes proved that is not the point: at `dark` and at
                   # `mid` on gothic_stone's base ramp the bracket rendered
                   # as one black blob with no form in it, and a sconce
                   # whose arm cannot be seen is a smudge on a wall. The
                   # theme's own value hierarchy already puts the room
                   # dark; a fixture inside it has to come back up.
                   propkit.painted_metal("gothic_stone", "prop_sconce",
                                         wear=0.34, tone="light"),
                   (0.4, 0.45, 0.6),
                   "_theme_props gives the bracket 0.12 x 0.5 x 0.12 and "
                   "stands it 0.16 m off the wall.",
                   anchor="wall")


def prop_sconce_flame():
    """The fire. `centre` anchored, because a flame has no floor.

    Eight facets tapering to a point, and deliberately NOT symmetric on the
    vertical: a flame drawn as a cone is a party hat. The lean comes from
    the second frustum being offset, which costs nothing and is the only
    thing separating this from a traffic cone (ART_LESSONS L-50's cousin).

    Warm fixture light, not hazard. See the module docstring.

    **The bench cannot judge this one.** `ART_LESSONS` L-03: only the
    Compatibility renderer starts in this sandbox, so there is no glow, and
    a flame is the most glow-dependent object in the project -- what the
    sheet shows is the unbloomed mass. Squat and wide rather than tall and
    tapered is the shape that survives that: fire is widest near its
    source, and a cone is a hat at any exposure.
    """
    # FOUR TONGUES, not one cone. The first pass was two stacked frusta
    # with a 20 mm lean, which is a party hat -- and the docstring above
    # claimed it was not, which is the worse half of the mistake. A flame
    # reads as a flame because it has several tips at several heights that
    # do not agree with each other; one silhouette, however tapered, is a
    # cone.
    lit = []
    for i, (dx, dy, radius, height, base_z) in enumerate((
            (0.000, 0.000, 0.105, 0.20, -0.10),
            (0.068, 0.028, 0.052, 0.15, -0.09),
            (-0.062, 0.034, 0.046, 0.12, -0.09),
            (0.016, -0.066, 0.040, 0.09, -0.08))):
        lit.append(brushkit.prism(
            "fl_tongue_%d" % i, radius, height, 8,
            (dx, dy, base_z + height / 2.0), top_radius=radius * 0.14,
            asset_name="prop_sconce_flame"))
        # Each tongue leans its own way. A flame that leans as one body is
        # a flag.
        brushkit.spin(lit[-1], "X", (i - 1.5) * 7.0)
    obj = common.join(lit, "prop_sconce_flame")
    # `send` is the warm family the utility lamps already use -- the same
    # amber that says "a fixture is lit here", never the hazard orange that
    # says "this is about to hurt".
    # send[2] `#c8a648`, not send[3]. Step 3 is `#ffd45c` and emitting a
    # family's brightest step at full saturation is what turned the Check's
    # available state white (ART_LESSONS L-42); a fire that renders cream
    # is not a fire.
    common.assign(obj, common.make_signal_material(
        "prop_sconce_flame", pal.universal("send", 0),
        pal.universal("send", 1), saturation=0.62, roughness=0.4))
    common.set_origin(obj, "centre")
    common.assert_fits(obj, "prop_sconce_flame", (0.28, 0.28, 0.45),
                       "_theme_props draws the flame as a 0.2 x 0.35 x 0.2 "
                       "prism.")
    return common.export_glb(obj, "%s/prop_sconce_flame.glb" % OUT, "prop",
                             anchor="centre", check_flat=False)


# ----------------------------------------------------------------------
# neon_transit
# ----------------------------------------------------------------------

def prop_transit_sign():
    """A hanging board, 1.6 x 0.5 x 0.08. A HOUSING -- the text is the
    engine's, and stays the engine's.

    `_theme_props` writes one of six lines onto a `Label3D` in front of it.
    An authored asset that baked "MIND THE STATIC" into its texture would
    be wrong the first time that list changed, and would print the same
    line on every sign in the Zone. Same rule as the Hub's campaign board.

    So what the mesh contributes is everything around the message: a case
    with depth, a lit face the text sits on, and the hangers that say this
    thing is suspended rather than floating.
    """
    parts = [
        brushkit.block("ts_case", (1.56, 0.10, 0.44), (0.0, 0.02, -0.30)),
        brushkit.block("ts_hood", (1.62, 0.16, 0.07), (0.0, 0.0, -0.05)),
        brushkit.block("ts_sill", (1.62, 0.14, 0.06), (0.0, 0.01, -0.53)),
    ]
    for sx in (-1.0, 1.0):
        # Hangers, angled inward: two vertical rods read as a ladder.
        rod = brushkit.block("ts_rod_%d" % int(sx), (0.05, 0.05, 0.26),
                             (sx * 0.62, 0.0, 0.0))
        brushkit.spin(rod, "Y", sx * 7.0)
        parts.append(rod)
        parts.append(brushkit.block("ts_lug_%d" % int(sx), (0.12, 0.10, 0.07),
                                    (sx * 0.60, 0.0, -0.10)))
    lit = [brushkit.block("ts_face", (1.44, 0.04, 0.32), (0.0, -0.05, -0.30))]
    return _finish("prop_transit_sign", "neon_transit", parts,
                   propkit.painted_metal("neon_transit", "prop_transit_sign",
                                         wear=0.16),
                   # 0.70, not the board's own 0.5: `_theme_props` hangs it
                   # at `height - 0.7`, so 0.7 m is exactly the headroom
                   # between the board and the ceiling it hangs from, and
                   # the hangers have to live inside that.
                   (1.7, 0.3, 0.70),
                   "_theme_props hangs the board at `height - 0.7`, so the "
                   "whole assembly has 0.7 m of headroom.",
                   anchor="ceiling",
                   lit=lit,
                   lit_material=common.make_signal_material(
                       "prop_transit_sign_face", pal.theme("neon_transit",
                                                           "accent", 0),
                       pal.theme("neon_transit", "accent", 1),
                       saturation=0.62, roughness=0.35))


# ----------------------------------------------------------------------
# temple_ruin
# ----------------------------------------------------------------------

def prop_root_fall():
    """A 1.0 m root section that TILES, because the length is randomised.

    `_theme_props` picks a length between 1.2 m and the room's height less
    0.6 and builds one box of it. An authored root at one fixed length
    would either be stretched -- which smears its own texture along its
    length and is instantly readable as stretching -- or would leave the
    engine unable to fill the range at all.

    So this is a 1.0 m section with flat, full-width ends, built to be
    stacked. It is `ceiling` anchored: a root comes from where the roof
    failed, and the top is the end that is fixed.
    """
    parts = []
    # The main strand, kinked twice. A straight root is a cable.
    points = [(0.0, 0.0, 0.0), (0.02, 0.01, -0.34),
              (-0.02, -0.01, -0.68), (0.01, 0.0, -1.0)]
    parts.append(brushkit.sweep("rf_main", points, 0.085, 0.085))
    # Two thinner strands that split off and rejoin the wall.
    parts.append(brushkit.sweep(
        "rf_side_a", [(0.0, 0.0, -0.18), (0.06, 0.02, -0.44),
                      (0.04, 0.01, -0.72)], 0.04, 0.04))
    parts.append(brushkit.sweep(
        "rf_side_b", [(0.0, 0.0, -0.40), (-0.07, 0.02, -0.62),
                      (-0.05, 0.0, -0.92)], 0.035, 0.035))
    # A collar at the top: this is where it came THROUGH something.
    parts.append(brushkit.prism("rf_collar", 0.11, 0.06, 8,
                                (0.0, 0.0, -0.03), top_radius=0.14,
                                asset_name="prop_root_fall"))
    return _finish("prop_root_fall", "temple_ruin", parts,
                   propkit.painted_metal("temple_ruin", "prop_root_fall",
                                         wear=0.40, tone="dark"),
                   (0.35, 0.35, 1.1),
                   "_theme_props builds the root between 1.2 m and the "
                   "room height less 0.6; this section tiles at 1.0 m.",
                   anchor="ceiling")


def prop_column_stump():
    """r 0.55, authored at 1.20 m -- the midpoint of the engine's range.

    Its detail is in the TOP 0.4 m, so an instance the engine scales still
    has a broken top rather than a stretched one. Everything below is a
    plain drum, which is the part scaling may safely stretch.
    """
    parts = [
        brushkit.prism("cs_shaft", 0.55, 0.86, 8, (0.0, 0.0, 0.43),
                       top_radius=0.50, asset_name="prop_column_stump"),
        brushkit.prism("cs_base", 0.62, 0.14, 8, (0.0, 0.0, 0.07),
                       top_radius=0.57, asset_name="prop_column_stump"),
    ]
    # The break: three stepped fragments at the top, none of them level.
    for i, (r, h, z, dx) in enumerate((
            (0.48, 0.16, 0.94, 0.04), (0.40, 0.12, 1.06, -0.05),
            (0.28, 0.10, 1.15, 0.03))):
        parts.append(brushkit.prism("cs_break_%d" % i, r, h, 8,
                                    (dx, dx * 0.6, z), top_radius=r * 0.82,
                                    asset_name="prop_column_stump"))
    return _finish("prop_column_stump", "temple_ruin", parts,
                   propkit.painted_metal("temple_ruin", "prop_column_stump",
                                         wear=0.30),
                   (common.DIM["prop_footprint"],
                    common.DIM["prop_footprint"], 1.4),
                   "PROP_FOOTPRINT is 1.4 m and _theme_props builds the "
                   "stump between 0.6 and 1.6 m tall.")


def main():
    common.reset_scene()
    report = {}
    for builder in (prop_sconce, prop_sconce_flame, prop_transit_sign,
                    prop_root_fall, prop_column_stump):
        entry = builder()
        report[os.path.basename(entry["path"])[:-4]] = entry
    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch013",
                       "dressing", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")


if __name__ == "__main__":
    main()
