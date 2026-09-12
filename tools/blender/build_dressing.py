"""Batch 010 -- the dressing the generator actually places.

    .tools/blender/blender -b --python tools/blender/build_dressing.py

## The finding this batch came from

`ASSET_INVENTORY.md` §8 lists twenty-two universal props -- `prop_barrel`,
`prop_locker`, `prop_canister`, `prop_fan` and so on. **Nothing places any
of them.** `chamber_builders._theme_props` is the only thing in the
generator that puts dressing in a Zone, and it places exactly one prop per
theme, chosen by theme:

| Theme | What it places | In §8? |
| --- | --- | --- |
| concrete_facility | a bolted warning plate | no |
| rusted_industrial | an oil drum, sometimes stacked, or a wall valve wheel | no |
| gothic_stone | a torch sconce with a lit flame | no |
| neon_transit | hanging signage | no |
| temple_ruin | root tendrils, or a column stump | no |
| void_glitch | a `Label3D` reading `prop_missing.mdl` | no |

So the inventory's prop section describes a library the game does not use,
and the six props every Zone in the game actually contains were not in the
inventory at all. §9's *signature dressing props* row is the right home for
them and it was `—` for all six themes.

## What this batch builds, and what it does not

Three, and the gate is which theme families exist:
`materials.built_themes()` is `concrete_facility`, `rusted_industrial` and
`void_glitch`. A gothic torch sconce cannot be painted before gothic_stone
has a material family, and building it against another theme's ramps would
be a prop that has to be rebuilt.

    prop_wall_plate     concrete_facility   0.06 x 0.9 x 0.6, wall-mounted
    prop_oil_drum       rusted_industrial   r 0.42, 0.95 tall, STACKABLE
    prop_valve_wheel    rusted_industrial   0.1 x 0.7 x 0.7 plate and a hub

void_glitch's prop is deliberately a text label reading `prop_missing.mdl`
-- the prop that never loaded. Authoring a mesh for it would destroy the
joke, which is the theme's whole identity. It stays engineering's.

The other three wait on their theme kits, which is Tier 9 and a larger
decision than a heartbeat should take on its own.

## The drum stacks, so it must tile

`_theme_props` duplicates the drum at `position.y += 0.95` four times in
ten. So the mesh is exactly 0.95 tall with flat, full-width faces top and
bottom: a rolled lip that overhung either end would leave a visible gap in
every stack, and a taper would leave a worse one.
"""

from __future__ import annotations

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import brushkit  # noqa: E402
import common  # noqa: E402
import propkit  # noqa: E402
import palette as pal  # noqa: E402

OUT = "batch010/dressing"
FOOTPRINT = common.DIM["prop_footprint"]      # 1.4


def _finish(name, theme, parts, canvas, box, why, anchor="floor",
            roughness=None):
    obj = common.join(parts, name)
    common.uv_project_world(obj, propkit.PROP_DENSITY, propkit.PROP_SIZE)
    common.assign(obj, common.make_textured_material(
        name, canvas.to_blender(name + "_tex"),
        roughness=pal.roughness(theme) if roughness is None else roughness))
    common.set_origin(obj, anchor)
    common.assert_fits(obj, name, box, why)
    return common.export_glb(obj, "%s/%s.glb" % (OUT, name), "prop",
                             tier="prop", texture_size=propkit.PROP_SIZE,
                             anchor=anchor, check_flat=False)


def prop_wall_plate():
    """concrete_facility's bolted warning plate.

    `_theme_props` hangs a 0.06 x 0.6 x 0.9 box on the wall at a random
    height between 1.2 and 2.0 m, in the theme's hazard material. It is the
    ONLY dressing a concrete_facility Zone gets, so it carries the whole
    weight of "somebody worked here" -- which is why it gets a frame, four
    bolts and a fold at the bottom rather than being a flat rectangle.
    """
    # Thickness along Y, because `set_origin(obj, "wall")` puts the BACK
    # face at Y 0 -- so a wall asset's depth axis is Y and its face points
    # -Y. Built with the thickness on X (which is how the engine states the
    # box, since its wall normal is X) the anchor mounts the plate EDGE-ON,
    # and the review sheet is a photograph of a 50 mm stripe.
    parts = [brushkit.block("wp_plate", (0.86, 0.05, 0.56),
                            (0.0, -0.025, 0.30))]
    for name, size, at in (
            ("wp_head", (0.90, 0.08, 0.07), (0.0, -0.01, 0.585)),
            ("wp_foot", (0.90, 0.10, 0.09), (0.0, -0.02, 0.045))):
        parts.append(brushkit.block(name, size, at))
    for sx in (-1.0, 1.0):
        for z in (0.14, 0.48):
            parts.append(brushkit.block(
                "wp_bolt_%d_%d" % (int(sx), int(z * 100)),
                (0.08, 0.05, 0.08), (sx * 0.37, -0.04, z)))
    return _finish("prop_wall_plate", "concrete_facility", parts,
                   propkit.placard("concrete_facility", "prop_wall_plate",
                                   label="warn"),
                   (1.0, 0.2, 0.7),
                   "_theme_props hangs a 0.06 x 0.6 x 0.9 plate on the wall.",
                   anchor="wall")


def prop_oil_drum():
    """rusted_industrial's oil drum. Exactly 0.95 tall, because it stacks.

    Eight sides at 0.42 m radius -- `art_budgets.json` caps radial segments
    at 8 below a 1.5 m radius, and a smooth drum is the single most modern
    thing that could stand in a 1998 corridor.
    """
    parts = [brushkit.prism("od_body", 0.42, 0.95, 8, (0.0, 0.0, 0.475),
                            asset_name="prop_oil_drum")]
    # Rolling hoops, INSIDE the body radius. A hoop standing proud would
    # leave a gap in every stack -- see the module docstring.
    for z in (0.26, 0.69):
        parts.append(brushkit.tube("od_hoop_%d" % int(z * 100), 0.42, 0.36,
                                   0.07, 8, (0.0, 0.0, z),
                                   asset_name="prop_oil_drum"))
    # A bung, off centre so a stack does not read as one column -- and set
    # FLUSH with the top face, not standing on it. A 20 mm boss would put
    # the drum at 0.97 and every stacked pair would interpenetrate by
    # exactly that, which is the kind of gap nobody sees until it is in a
    # screenshot of a corridor.
    parts.append(brushkit.prism("od_bung", 0.09, 0.05, 8,
                                (0.20, 0.10, 0.925), top_radius=0.07,
                                asset_name="prop_oil_drum"))
    return _finish("prop_oil_drum", "rusted_industrial", parts,
                   propkit.painted_metal("rusted_industrial", "prop_oil_drum",
                                         band=True, wear=0.24),
                   (FOOTPRINT, FOOTPRINT, 1.0),
                   "PROP_FOOTPRINT is 1.4 m and _theme_props stacks the "
                   "drum at 0.95 m intervals.")


def prop_valve_wheel():
    """rusted_industrial's wall valve, for corridors too narrow for a drum.

    `_theme_props` reaches for this when `span_x - 2 * PROP_FOOTPRINT` will
    not admit the brute -- so it is the NARROW-corridor prop, and it stands
    0.24 m off the wall, which is what the engine's own plate-plus-hub
    reaches. Anything deeper would be the thing the floor-prop rule exists
    to prevent.
    """
    # Same axis convention as the plate: depth on Y, face pointing -Y.
    parts = [brushkit.block("vw_plate", (0.62, 0.08, 0.62), (0.0, -0.04, 0.0)),
             brushkit.prism("vw_hub", 0.09, 0.16, 8, (0.0, 0.0, 0.0),
                            top_radius=0.07, asset_name="prop_valve_wheel")]
    brushkit.spin(parts[1], "X", 90.0)
    for vertex in parts[1].data.vertices:
        vertex.co.y -= 0.14
    # The wheel itself: a rim on six spokes, which is a silhouette. A solid
    # disc at this size is a dinner plate bolted to a wall.
    rim = brushkit.tube("vw_rim", 0.30, 0.24, 0.07, 8, (0.0, 0.0, 0.0),
                        asset_name="prop_valve_wheel")
    brushkit.spin(rim, "X", 90.0)
    for vertex in rim.data.vertices:
        vertex.co.y -= 0.19
    parts.append(rim)
    for i in range(6):
        angle = i * math.pi / 3.0
        spoke = brushkit.block("vw_spoke_%d" % i, (0.05, 0.05, 0.28),
                               (0.0, 0.0, 0.14))
        brushkit.spin(spoke, "Y", math.degrees(angle))
        for vertex in spoke.data.vertices:
            vertex.co.y -= 0.19
        parts.append(spoke)
    obj_box = (0.7, 0.4, 0.7)
    return _finish("prop_valve_wheel", "rusted_industrial", parts,
                   propkit.painted_metal("rusted_industrial",
                                         "prop_valve_wheel", wear=0.3),
                   obj_box,
                   "_theme_props places a 0.1 x 0.7 x 0.7 valve on the wall "
                   "of a corridor too narrow for a floor prop.",
                   anchor="wall")


def main():
    common.reset_scene()
    report = {}
    for builder in (prop_wall_plate, prop_oil_drum, prop_valve_wheel):
        entry = builder()
        report[os.path.basename(entry["path"])[:-4]] = entry
    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch010",
                       "dressing", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")


if __name__ == "__main__":
    main()
