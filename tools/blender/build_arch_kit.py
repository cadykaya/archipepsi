"""Batch 020 -- Tier 3, the structural half of architecture Pri-B.

    .tools/blender/blender -b --python tools/blender/build_arch_kit.py

`ASSET_INVENTORY.md` §3 lists 29 architecture modules. Batch 001 built the
Pri-A surfaces and Batch 007 the five Pri-A traversal pieces; 15 of 29 are
done and everything left is Pri B or C. This batch takes the seven that are
**what a chamber is made of**, and Batch 021 will take the services and
openings.

## These are not invented

Every module here replaces geometry `chamber_builders` already builds
procedurally, so each one has real numbers to be measured against:

    rib             0.22 wide x height x 0.35 deep, at +/-(width/2 - 0.13),
                    one every ~6 m            _greeble_corridor
    ceiling beam    width x 0.25 x 0.35 at height - 0.12   _greeble_corridor
    buttress        0.5 x height x 0.5 at +/-(width/2 - 0.3)  _greeble_room
    crate           0.7 to 1.3 cube, accent material         _greeble_room

Where a module has no procedural counterpart -- the floor grate, the wall
variants -- it is built to the kit's own `MODULE` 4.0 m grid and the
engine's 0.40 m wall thickness, so it tiles against Batch 001's panels.

## The seven

| Module | What it is for |
| --- | --- |
| `arch_wall_variant_a` | a panel with a horizontal service band and a recessed field: the wall a corridor has when something runs along it |
| `arch_wall_variant_b` | a panel with a tall recessed bay and a stepped head: the wall a room has when something used to be set into it |
| `arch_ceiling_plain` | the flat 4 m ceiling bay Batch 001's coffered one is the alternative to |
| `arch_trim_ceiling` | `_greeble_corridor`'s ceiling beam, authored: 0.25 x 0.35 across the module, with the rib feet that carry it |
| `arch_floor_grate` | a 4 m floor bay of open grating over a shallow void, for where a facility drains |
| `arch_column` | a freestanding column on the buttress's 0.5 m footprint, with a base and a capital built TO the surfaces they meet (L-55) |
| `arch_beam_span` | a beam crossing a 4 m bay with a haunch at each end, for spanning what the ceiling bay cannot |

## What is NOT in this batch, and why

`arch_signage_mount` and `arch_objective_socket` are Pri B and stay
**blocked**: they are mount points for `objective_marker` and
`signage_module`, which wait on a deliberate navigation-language review. A
socket's size and shape prejudge what plugs into it, so building one now
would decide the language sideways.

`arch_vista_socket` is Pri C with no contract in the engine to build
against.
"""

from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import brushkit  # noqa: E402
import build_architecture as kit  # noqa: E402
import common  # noqa: E402

DIM = common.DIM
MODULE = kit.MODULE                          # 4.00
WALL = DIM["wall_thickness"]                 # 0.40
OUT = "batch020/architecture"

#: `_greeble_corridor`'s own figures, so an authored rib and beam land where
#: the procedural ones do.
RIB_W, RIB_D = 0.22, 0.35
BEAM_H, BEAM_D = 0.25, 0.35
BUTTRESS = 0.50                              # _greeble_room's corner post


def arch_wall_variant_a():
    """A 4 m panel with a service band and a recessed field.

    Batch 001's `arch_wall_panel` is flat and `arch_wall_ribbed` is four
    pilasters. What neither gives is a wall that says something RUNS along
    it, which is what a corridor wall mostly is -- so this one has a band
    at 2.20 m with a shallow recess above and below it.

    The band sits at 2.20 because `reach_standing` is 2.93 and
    `player_eye_height` is 1.60: it reads as being above head height
    without being lost against the ceiling.
    """
    face = WALL / 2.0
    parts = [brushkit.block("wa_face", (MODULE, WALL, MODULE),
                            (0.0, 0.0, MODULE / 2.0))]
    for i, (z0, z1) in enumerate(((0.28, 2.02), (2.38, MODULE - 0.28))):
        parts.append(brushkit.block(
            "wa_recess_%d" % i, (MODULE - 0.56, 0.10, z1 - z0),
            (0.0, -face + 0.05, (z0 + z1) / 2.0)))
    parts.append(brushkit.block("wa_band", (MODULE, 0.18, 0.36),
                                (0.0, -face - 0.09, 2.20)))
    for side in (-1.0, 1.0):
        parts.append(brushkit.block(
            "wa_bracket_%d" % int(side), (0.16, 0.26, 0.20),
            (side * (MODULE / 2.0 - 0.5), -face - 0.13, 2.20)))
    return common.join(parts, "arch_wall_variant_a")


def arch_wall_variant_b():
    """A 4 m panel with a tall recessed bay and a stepped head.

    The wall a room has where something used to be set into it -- a
    cabinet, a hatch, a panel somebody removed. The bay is 1.60 x 2.60,
    which clears `tallest_actor` 2.60 exactly, so nothing the engine can
    spawn is taller than the hole it stands in front of.
    """
    face = WALL / 2.0
    bay_w, bay_h, bay_d = 1.60, 2.60, 0.22
    parts = [brushkit.block("wb_face", (MODULE, WALL, MODULE),
                            (0.0, 0.0, MODULE / 2.0))]
    parts.append(brushkit.block("wb_bay", (bay_w, bay_d, bay_h),
                                (0.0, face - bay_d / 2.0, bay_h / 2.0)))
    for i, (inset, h) in enumerate(((0.0, 0.22), (0.14, 0.18))):
        parts.append(brushkit.block(
            "wb_head_%d" % i, (bay_w + 0.44 - inset * 2, 0.20 + inset * 0.5, h),
            (0.0, -face - 0.10 - inset * 0.25, bay_h + 0.11 + i * 0.20)))
    parts.append(brushkit.block("wb_sill", (bay_w + 0.30, 0.26, 0.14),
                                (0.0, -face - 0.13, 0.07)))
    return common.join(parts, "arch_wall_variant_b")


def arch_ceiling_plain():
    """The flat 4 m ceiling bay, which Batch 001's coffered one alternates
    with.

    A kit needs the plain one or the detailed one has nothing to be a
    change from. Its only relief is a 0.06 m shadow gap at the perimeter,
    so two bays butted together read as two bays.
    """
    parts = [brushkit.block("cp_deck", (MODULE, MODULE, 0.25),
                            (0.0, 0.0, -0.125))]
    for axis, sx, sy, px, py in (("a", MODULE, 0.12, 0.0, MODULE / 2.0 - 0.06),
                                 ("b", MODULE, 0.12, 0.0, -MODULE / 2.0 + 0.06),
                                 ("c", 0.12, MODULE, MODULE / 2.0 - 0.06, 0.0),
                                 ("d", 0.12, MODULE, -MODULE / 2.0 + 0.06, 0.0)):
        parts.append(brushkit.block("cp_edge_%s" % axis, (sx, sy, 0.16),
                                    (px, py, -0.33)))
    return common.join(parts, "arch_ceiling_plain")


def arch_trim_ceiling():
    """`_greeble_corridor`'s ceiling beam, authored.

    The procedural one is a bare `width x 0.25 x 0.35` box floating 0.12 m
    under the ceiling with nothing carrying it. This is the same beam with
    the rib feet the corridor greeble puts on the walls at the same z --
    which is the whole point: the rib and the beam are one structural bay
    in the engine's own layout, and drawing them as one part is what makes
    the corridor read as built rather than decorated.
    """
    parts = [brushkit.block("tc_beam", (MODULE, BEAM_D, BEAM_H),
                            (0.0, 0.0, -BEAM_H / 2.0))]
    parts.append(brushkit.block("tc_soffit", (MODULE, BEAM_D + 0.14, 0.08),
                                (0.0, 0.0, -BEAM_H - 0.04)))
    for side in (-1.0, 1.0):
        parts.append(brushkit.block(
            "tc_foot_%d" % int(side), (RIB_W, RIB_D, 0.62),
            (side * (MODULE / 2.0 - RIB_W / 2.0), 0.0, -BEAM_H - 0.31)))
    return common.join(parts, "arch_trim_ceiling")


def arch_floor_grate():
    """A 4 m floor bay of open grating over a shallow void.

    Bars on a 0.24 m pitch across a 0.30 m recess, with a frame. Two
    reasons it is bars rather than a painted plate: a facility that never
    drains anywhere is a facility with no depth, and the value break under
    the bars is the only dark thing in a floor otherwise built from one
    mid-grey.
    """
    parts = [brushkit.block("fg_void", (MODULE - 0.24, MODULE - 0.24, 0.30),
                            (0.0, 0.0, -0.15 - 0.06))]
    for axis, sx, sy, px, py in (("a", MODULE, 0.24, 0.0, MODULE / 2.0 - 0.12),
                                 ("b", MODULE, 0.24, 0.0, -MODULE / 2.0 + 0.12),
                                 ("c", 0.24, MODULE - 0.48, MODULE / 2.0 - 0.12,
                                  0.0),
                                 ("d", 0.24, MODULE - 0.48, -MODULE / 2.0 + 0.12,
                                  0.0)):
        parts.append(brushkit.block("fg_frame_%s" % axis, (sx, sy, 0.12),
                                    (px, py, -0.06)))
    # `brushkit.grate` exists for exactly this, and its docstring is the
    # reason to use it rather than paint one: a grate's job is to be a
    # silhouette you see light and geometry through.
    # A 0.24 m pitch with three bearers came to 264 triangles against the
    # 250 the architecture_module tier allows, and the rule for that is to
    # DELETE geometry rather than raise the ceiling. 0.32 m is a coarser
    # grating and a truer one -- industrial bar grating you walk on is
    # nearer this than the fine mesh a drain cover uses -- and one central
    # bearer still gives the underside something to read against.
    span = MODULE - 0.48
    parts.append(brushkit.grate("fg_bars", (span, span, 0.09),
                                int(span / 0.32), 0.09, (0.0, 0.0, -0.055),
                                axis="y"))
    parts.append(brushkit.block("fg_bearer", (0.07, span, 0.16),
                                (0.0, 0.0, -0.14)))
    return common.join(parts, "arch_floor_grate")


def arch_column():
    """A freestanding column on `_greeble_room`'s 0.5 m buttress footprint.

    Built to the surfaces it meets rather than to its own centre: the base
    starts at z 0 and the capital ends at the module height. Batch 016's
    arena grid got that wrong first and rendered sixteen collars hovering
    0.15 m off the floor (L-55).
    """
    h = MODULE
    parts = [brushkit.block("co_shaft", (BUTTRESS, BUTTRESS, h),
                            (0.0, 0.0, h / 2.0))]
    for z, flare, t in ((0.0, 0.26, 0.28), (h - 0.24, 0.18, 0.24)):
        parts.append(brushkit.block(
            "co_%s" % ("base" if z < 1.0 else "cap"),
            (BUTTRESS + flare, BUTTRESS + flare, t), (0.0, 0.0, z + t / 2.0)))
    for side in (-1.0, 1.0):
        parts.append(brushkit.block(
            "co_flute_%d" % int(side), (0.09, BUTTRESS - 0.16, h - 0.9),
            (side * (BUTTRESS / 2.0 - 0.045), 0.0, h / 2.0 + 0.05)))
    return common.join(parts, "arch_column")


def arch_beam_span():
    """A beam across a 4 m bay, with a haunch at each end.

    `arch_trim_ceiling` is a beam UNDER a ceiling; this one spans a bay
    that has no ceiling of its own -- over a grate, across a tower shaft,
    between two runs. The haunches are what say it is carrying something,
    and they are why it is not just the ceiling trim rotated.
    """
    depth = 0.46
    parts = [brushkit.block("bs_web", (MODULE, 0.20, depth),
                            (0.0, 0.0, -depth / 2.0)),
             brushkit.block("bs_top", (MODULE, 0.44, 0.12),
                            (0.0, 0.0, -0.06)),
             brushkit.block("bs_bottom", (MODULE, 0.36, 0.11),
                            (0.0, 0.0, -depth + 0.055))]
    for side in (-1.0, 1.0):
        # `wedge` has no mirror flag: the slope always rises along +axis,
        # so the far haunch is the same wedge turned 180 degrees.
        parts.append(brushkit.wedge(
            "bs_haunch_%d" % int(side), (0.70, 0.22, 0.34),
            (side * (MODULE / 2.0 - 0.35), 0.0, -depth - 0.17),
            rotation_z=0.0 if side < 0 else 180.0, axis="x"))
        parts.append(brushkit.block(
            "bs_pad_%d" % int(side), (0.34, 0.40, 0.14),
            (side * (MODULE / 2.0 - 0.17), 0.0, -0.07)))
    return common.join(parts, "arch_beam_span")


MODULES = [
    (arch_wall_variant_a, "wall", "architecture_module", "wall"),
    (arch_wall_variant_b, "wall", "architecture_module", "wall"),
    (arch_ceiling_plain, "ceiling", "architecture_module", "ceiling"),
    (arch_trim_ceiling, "trim", "architecture_module", "ceiling"),
    (arch_floor_grate, "floor", "architecture_module", "module_floor"),
    (arch_column, "wall", "architecture_module", "floor"),
    (arch_beam_span, "trim", "architecture_module", "ceiling"),
]


def main():
    common.reset_scene()
    report = {}
    for builder, role, category, anchor in MODULES:
        obj = builder()
        name = obj.name
        report[name] = kit.finish(obj, name, role, category,
                                  "%s/%s.glb" % (OUT, name), anchor=anchor)
    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch020",
                       "architecture", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
    print("[art] batch020 manifest -> %s" % out)


if __name__ == "__main__":
    main()
