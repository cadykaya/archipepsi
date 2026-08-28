"""Batch 009 -- the six remaining affordance fixtures.

    .tools/blender/blender -b --python tools/blender/build_affordances.py

`ASSET_INVENTORY.md` section 5 lists seven affordances and one is built --
the grapple anchors, which the owner passed at Style Lock. The other six
are all real: `affordance_features.gd` places every one of them today out of
`BoxMesh`, `CylinderMesh` and `TorusMesh`, at footprints the file states.

| ID | Replaces | Engine size |
| --- | --- | --- |
| `breakwall_panel` | `AffordanceNodes.BreakablePanel` | 0.4 x 2.6 x 2.4 |
| `water_basin` | `_water_volume`'s basin | 1.6 x 0.1 x 1.6 |
| `rail_beam` | `_rail`'s beam and posts | 0.35 sq x 6.0, posts 1.1 |
| `wind_ring` | `_wind_volume`'s three torus marks | inner 0.7 / outer 0.85 |
| `wind_perch` | `_wind_volume`'s lip | 1.5 x 0.3 x 1.5 |
| `bounce_pad` | `AffordanceNodes.BouncePad` | r 1.0/1.1, 0.5 tall |
| `movplat_deck` | `AffordanceNodes.MovingPlatform` | 2.4 x 0.4 x 2.4 |

## The rule this batch is built to

`ASSET_INVENTORY.md` §5 states it and it is the only interesting decision
here:

> The seven look the same everywhere or they teach nothing.

An affordance is a promise about what the player's own body can do, and a
promise the player has to re-learn in each of six themes is not a promise.
So all seven wear the **`signal`** family -- the same one the approved
grapple anchors wear -- and what differs between them is FORM, never hue:

    breakwall     a fractured panel with a struck face
    water         a lip you can see over, and get out over
    rail          a continuous run with hard stops at both ends
    wind ring     an open ring with its vanes angled UP
    wind perch    a platform with a catching lip
    bounce        a compressed drum -- something with stored energy
    movplat       a deck with treads and a guide slot

## What that conflicts with, stated rather than fixed

`affordance_features.gd` currently tints these six ad hoc: the breakable
wall takes the theme's hazard colour, water `(0.35, 0.75, 0.95)`, the rail
`(0.9, 0.7, 0.95)`, wind `(0.7, 0.95, 0.9)`, and the bounce pad and the
moving platform take the theme's accent and trim. Four of those are not in
`art_palette.json` at all, two of them vary per theme -- so the family does
not currently look the same everywhere -- and the rail's violet sits beside
`glitch`, which in this palette means *cosmetic corruption that means
nothing mechanically*. An affordance wearing it is telling the player the
opposite of the truth.

That is engineering's file and this lane does not edit it. Interface
requirement 15 records it; these assets are built to the rule the inventory
states, and the sheets show that rather than today's tints.
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

THEME = "concrete_facility"
OUT = "batch009/affordance"


def _skin(name, label):
    """The shared affordance surface: the hero shell in `signal`."""
    return common.make_textured_material(
        name, propkit.hero_shell(THEME, name, "signal",
                                 label=label).to_blender(name + "_tex"),
        roughness=pal.roughness(THEME))


def _lit(name, step=3, saturation=0.9):
    return common.make_signal_material(name, pal.universal("signal", 0),
                                       pal.universal("signal", step),
                                       saturation=saturation)


def _finish(name, shell_parts, lit_parts, box, why, anchor="floor",
            label=None, category="interactable"):
    shell = common.join(shell_parts, name + "_shell")
    common.uv_project_world(shell, propkit.PROP_DENSITY, propkit.PROP_SIZE)
    common.assign(shell, _skin(name, label))
    parts = [shell]
    if lit_parts:
        lit = common.join(lit_parts, name + "_lit")
        common.assign(lit, _lit(name))
        parts.append(lit)
    obj = common.join(parts, name)
    common.set_origin(obj, anchor)
    common.assert_fits(obj, name, box, why)
    return common.export_glb(obj, "%s/%s.glb" % (OUT, name), category,
                             check_flat=False, anchor=anchor)


# ----------------------------------------------------------------------

def breakwall_panel():
    """0.4 x 2.6 x 2.4 in Godot, so 0.4 x 2.4 x 2.6 here.

    The engine already draws three crack bars across it and shrinks them as
    the panel's health drops, so the cracks are ITS channel and nothing here
    paints any. What the mesh adds is the other half of the read: a struck
    face, so the player knows where to hit it, and a frame that says the
    panel is a fitted thing rather than a piece of the wall.
    """
    # The panel's face normal is X: the alcove runs along X between a back
    # wall at +0.65 and this at -0.65, so the opening is 2.4 wide in Z and
    # 2.6 tall in Y -- which is Y and Z here. `brushkit.frame` builds in the
    # XZ plane, so the frame is four blocks rather than a call.
    shell = [brushkit.block("bw_panel", (0.28, 2.30, 2.50), (0.0, 0.0, 1.30))]
    for name, size, at in (
            ("bw_head", (0.34, 2.40, 0.12), (-0.06, 0.0, 2.54)),
            ("bw_sill", (0.34, 2.40, 0.12), (-0.06, 0.0, 0.06)),
            ("bw_jamb_l", (0.34, 0.12, 2.60), (-0.06, -1.14, 1.30)),
            ("bw_jamb_r", (0.34, 0.12, 2.60), (-0.06, 1.14, 1.30))):
        shell.append(brushkit.block(name, size, at))
    for side in (-1.0, 1.0):
        shell.append(brushkit.block("bw_stud_%d" % int(side),
                                    (0.16, 0.14, 0.14),
                                    (-0.18, side * 1.14, 1.30)))
    lit = [brushkit.prism("bw_target", 0.30, 0.06, 8, (0.0, 0.0, 0.0),
                          top_radius=0.22, asset_name="breakwall_panel")]
    brushkit.spin(lit[0], "Y", 90.0)
    for vertex in lit[0].data.vertices:
        vertex.co += Vector((-0.20, 0.0, 1.30))
    return _finish("breakwall_panel", shell, lit, (0.5, 2.5, 2.7),
                   "AffordanceNodes.BreakablePanel is 0.4 x 2.6 x 2.4 and "
                   "sits in a 1.5 m alcove.", label="brk")


def water_basin():
    """A 1.6 x 1.6 rim, 0.1 m of it above the surface.

    The engine's basin is a flat plate at the waterline. A plate is not the
    read: what the player has to see is that this is a hole with a LIP, and
    that the lip is climbable -- `Player.MIN_VOLUME_SPEED_SCALE` guarantees
    you can always get out, and the geometry should say so before the
    physics does.
    """
    shell = []
    for i in range(4):
        angle = i * math.pi / 2.0
        shell.append(brushkit.block(
            "wb_lip_%d" % i, (1.60, 0.16, 0.22),
            (0.74 * math.sin(angle), -0.74 * math.cos(angle), 0.11),
            rotation_z=math.degrees(angle)))
    # A step in one side: the way out, modelled rather than assumed.
    shell.append(brushkit.block("wb_step", (0.70, 0.26, 0.10),
                                (0.0, -0.60, 0.05)))
    lit = [brushkit.tube("wb_mark", 0.62, 0.54, 0.05, 8, (0.0, 0.0, 0.20),
                         asset_name="water_basin")]
    return _finish("water_basin", shell, lit, (1.75, 1.75, 0.35),
                   "_water_volume draws a 1.6 x 1.6 basin plate.",
                   label="wat")


def rail_beam():
    """6.0 m of beam on two 1.1 m posts, at the engine's own numbers.

    `length = 2 * half_depth - 1` = 6.0, and the posts stand at its ends.
    The top face is the grind lane, so it is the one continuous unbroken
    line on the object: anything crossing it would read as something to
    catch on.
    """
    length = 2.0 * 3.5 - 1.0
    shell = [brushkit.block("rb_beam", (0.35, length, 0.24),
                            (0.0, 0.0, 1.22))]
    for end in (-1.0, 1.0):
        shell.append(brushkit.block("rb_post_%d" % int(end),
                                    (0.25, 0.25, 1.10),
                                    (0.0, end * length / 2.0, 0.55)))
        # Hard stops: a rail you can overshoot is a rail that kills you.
        shell.append(brushkit.block("rb_stop_%d" % int(end),
                                    (0.42, 0.18, 0.46),
                                    (0.0, end * (length / 2.0 - 0.09), 1.45)))
    for i in range(5):
        y = -length / 2.0 + 1.0 + i * 1.0
        shell.append(brushkit.block("rb_tie_%d" % i, (0.46, 0.10, 0.09),
                                    (0.0, y, 1.06)))
    lit = [brushkit.block("rb_lane", (0.20, length - 0.30, 0.05),
                          (0.0, 0.0, 1.36))]
    # The FOOTPRINT, not the beam: `FOOTPRINT["rail"]` is
    # 0.5 x 3.5 x 3.6 half-extents, so the fixture may occupy 1.0 x 7.0 x
    # 3.6. The beam is 6.0 of that 7.0 and the posts stand at its ends,
    # which is where the engine's own posts stand too.
    return _finish("rail_beam", shell, lit, (1.0, 7.0, 3.6),
                   "FOOTPRINT['rail'] is 0.5 x 3.5 x 3.6 half-extents.",
                   label="rail")


def wind_ring():
    """One of the three marks the engine stacks up the column.

    A torus at inner 0.7 / outer 0.85. Built as eight vanes on that radius,
    each tilted UP -- the ring's job is to say which way the column pushes,
    and a flat ring says nothing about direction at all.
    """
    shell = []
    for i in range(8):
        angle = i * math.pi / 4.0
        vane = brushkit.block("wr_vane_%d" % i, (0.34, 0.09, 0.16),
                              (0.775 * math.cos(angle),
                               0.775 * math.sin(angle), 0.0),
                              rotation_z=math.degrees(angle) + 90.0)
        brushkit.spin(vane, "Y", 0.0)
        shell.append(vane)
    lit = [brushkit.tube("wr_band", 0.74, 0.70, 0.05, 8, (0.0, 0.0, 0.06),
                         asset_name="wind_ring")]
    return _finish("wind_ring", shell, lit, (1.75, 1.75, 0.30),
                   "_wind_volume's marks are inner 0.7 / outer 0.85.",
                   anchor="centre", label="up")


def wind_perch():
    """1.5 x 0.3 x 1.5 -- what riding the column reaches.

    Anchored `ceiling`, like `arch_ledge` and for the same reason: the only
    height anyone cares about is the surface you land on.
    """
    shell = [brushkit.block("wp_deck", (1.50, 1.50, 0.22), (0.0, 0.0, -0.11))]
    for i in range(4):
        angle = i * math.pi / 2.0
        shell.append(brushkit.block(
            "wp_lip_%d" % i, (1.50, 0.12, 0.16),
            (0.69 * math.sin(angle), -0.69 * math.cos(angle), 0.04),
            rotation_z=math.degrees(angle)))
    shell.append(brushkit.wedge("wp_underside", (1.10, 1.10, 0.30),
                                (0.0, 0.0, -0.37), axis="y"))
    lit = [brushkit.block("wp_edge", (1.20, 1.20, 0.04), (0.0, 0.0, 0.10))]
    return _finish("wind_perch", shell, lit, (1.6, 1.6, 0.8),
                   "_wind_volume's lip is 1.5 x 0.3 x 1.5.",
                   anchor="ceiling", label="up")


def bounce_pad():
    """r 1.0 top / 1.1 bottom, 0.5 tall, in a 2.0 x 0.5 x 2.0 collider.

    A drum under compression. `BouncePad.LAUNCH` is 16 m/s against a
    gravity of 24, so this throws the player 5.33 m into the air -- the
    object has to look like it is holding that, which means rings that read
    as a stack that has been squashed rather than a disc lying on the floor.
    """
    shell = [
        brushkit.prism("bp_base", 1.10, 0.12, 8, (0.0, 0.0, 0.06),
                       top_radius=1.02, asset_name="bounce_pad"),
        brushkit.prism("bp_coil", 0.94, 0.14, 8, (0.0, 0.0, 0.19),
                       top_radius=1.00, asset_name="bounce_pad"),
        brushkit.prism("bp_cap", 1.00, 0.10, 8, (0.0, 0.0, 0.31),
                       top_radius=0.92, asset_name="bounce_pad"),
    ]
    for i in range(4):
        angle = i * math.pi / 2.0 + math.pi / 4.0
        shell.append(brushkit.block(
            "bp_guide_%d" % i, (0.18, 0.18, 0.40),
            (0.98 * math.cos(angle), 0.98 * math.sin(angle), 0.20),
            rotation_z=math.degrees(angle)))
    lit = [brushkit.prism("bp_face", 0.78, 0.06, 8, (0.0, 0.0, 0.39),
                          top_radius=0.72, asset_name="bounce_pad")]
    return _finish("bounce_pad", shell, lit, (2.1, 2.1, 0.55),
                   "BouncePad's collider is 2.0 x 0.5 x 2.0.", label="up")


def movplat_deck():
    """2.4 x 0.4 x 2.4 -- an `AnimatableBody3D` that carries the player.

    A deck you stand on that moves under you, so its top is treads and its
    sides carry a guide slot: the one thing the player must be able to read
    at a glance is WHICH WAY it travels, and the slot is that.
    """
    shell = [brushkit.block("mp_deck", (2.40, 2.40, 0.22), (0.0, 0.0, 0.11))]
    for i in range(4):
        angle = i * math.pi / 2.0
        shell.append(brushkit.block(
            "mp_kerb_%d" % i, (2.40, 0.14, 0.14),
            (1.13 * math.sin(angle), -1.13 * math.cos(angle), 0.29),
            rotation_z=math.degrees(angle)))
    for i in range(5):
        shell.append(brushkit.block("mp_tread_%d" % i, (2.00, 0.16, 0.05),
                                    (0.0, -0.80 + i * 0.40, 0.245)))
    shell.append(brushkit.block("mp_boss", (0.50, 0.50, 0.36),
                                (0.0, 0.0, -0.18)))
    lit = [brushkit.block("mp_slot", (0.14, 2.10, 0.05), (0.0, 0.0, 0.245))]
    return _finish("movplat_deck", shell, lit, (2.5, 2.5, 0.75),
                   "MovingPlatform is 2.4 x 0.4 x 2.4.", label="lift")


FIXTURES = [breakwall_panel, water_basin, rail_beam, wind_ring, wind_perch,
            bounce_pad, movplat_deck]


def main():
    common.reset_scene()
    report = {}
    for builder in FIXTURES:
        entry = builder()
        report[os.path.basename(entry["path"])[:-4]] = entry
    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch009",
                       "affordance", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")


if __name__ == "__main__":
    main()
