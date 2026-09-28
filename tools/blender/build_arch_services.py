"""Batch 021 -- Tier 3, the services and openings. Architecture Pri-B/C.

    .tools/blender/blender -b --python tools/blender/build_arch_services.py

Batch 020 took the seven modules a chamber is made OF. These are the six it
is fitted OUT with, and they finish every Tier 3 row that has an engine
contract to build against.

## The six

| Module | Pri | Where its numbers come from |
| --- | --- | --- |
| `arch_vent` | B | `_greeble_corridor` builds a 0.08 x 0.7 x 1.1 wall vent as a flat accent box. This is the same opening with real louvres |
| `arch_duct` | B | no procedural counterpart. Sized against `CEILING_GAP` 0.5, hung under a 4 m bay |
| `arch_catwalk` | B | deck at 2.60, which is `SAFE_BASE_JUMP_GAP` and the height the approved gallery corridor and balcony arena already use |
| `arch_tunnel_bore` | B | a 4 m bore section at `corridor_width_min` 4.0 across |
| `arch_secret_alcove` | B | `_secret_alcove`, exactly: depth 1.8, thickness 0.3, width 2.4, lip 3.05-4.2, underside clearing `TALLEST_ACTOR` + 0.15 |
| `arch_window` | C | an interior opening, `door_height` 3.2 minus a 1.0 m sill |

## Two decisions worth stating

**The bore has a flat invert.** A perfectly round tunnel would be a
different construction language from the rest of the facility, and it would
have no floor. This one is a horseshoe: a flat walkable invert, springing
lines at 1.2 m and a segmented crown over them. Twelve segments, which
`max_radial_segments` allows above a 1.5 m radius.

**The alcove is built to the letter of `_secret_alcove`.** Not close to it:
the same 1.8 x 0.3 x 2.4 slab, the same non-colliding lip rail 0.12 x 0.35
inset 0.06 from the inward edge, and the ledge top at the lip rather than
its centre. `DESIGN` s19 permits exactly one thing up there -- *a plaque and
nothing else* -- so the plaque is modelled and nothing else is.

The alcove's underside sits at `secret_underside_min` 2.75, which is
`TALLEST_ACTOR` + 0.15: below that the slab stops being a secret and
becomes a wall the brute walks into.
"""

from __future__ import annotations

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import brushkit  # noqa: E402
import build_architecture as kit  # noqa: E402
import common  # noqa: E402

DIM = common.DIM
MODULE = kit.MODULE                          # 4.00
WALL = DIM["wall_thickness"]                 # 0.40
DOOR_H = DIM["door_height"]                  # 3.20
GAP = DIM["safe_base_jump_gap"]              # 2.60
W_MIN = DIM["corridor_width_min"]            # 4.00
S_DEPTH = DIM["secret_ledge_depth"]          # 1.80
S_THICK = DIM["secret_ledge_thickness"]      # 0.30
S_WIDTH = DIM["secret_ledge_width"]          # 2.40
S_UNDER = DIM["secret_underside_min"]        # 2.75
S_LIP_MAX = DIM["secret_lip_max"]            # 4.20
OUT = "batch021/architecture"


def arch_vent():
    """`_greeble_corridor`'s wall vent, with louvres instead of a flat box.

    0.7 x 1.1 is the engine's opening and it is kept exactly. What changes
    is that it becomes a thing you can see through: `brushkit.grate` for
    the blades, a frame around them, and a recess behind so the blades have
    something dark to sit against.

    Depth is on **Y**, because `set_origin(obj, "wall")` puts the BACK face
    at Y 0 -- a wall-mounted asset built with its thickness on X mounts
    edge-on, which is how three Batch 010 props first shipped.
    """
    w, h, d = 0.70, 1.10, 0.08
    parts = [
        # The recess first, so the blades read against dark.
        brushkit.block("vent_recess", (w - 0.10, 0.14, h - 0.10),
                       (0.0, 0.07, 0.0)),
        brushkit.frame("vent_frame", (w, h), 0.07, d, (0.0, d / 2.0, 0.0)),
    ]
    blades = 7
    for i in range(blades):
        z = -(h - 0.22) / 2.0 + (h - 0.22) * (i + 0.5) / blades
        parts.append(brushkit.wedge(
            "vent_blade_%d" % i, (w - 0.16, 0.09, 0.10),
            (0.0, d / 2.0 - 0.01, z), axis="y"))
    return common.join(parts, "arch_vent")


def arch_duct():
    """A 4 m run of rectangular ducting, hung under a ceiling bay.

    `CEILING_GAP` is 0.5, which is the clearance an affordance needs under
    a ceiling, so a duct that is service and not structure lives inside it:
    0.46 deep, hung 0.22 clear, with a flanged joint at mid-run and two
    hangers. The flange is what stops a duct reading as a long box.
    """
    sec_w, sec_h, drop = 0.62, 0.46, 0.22
    z = -drop - sec_h / 2.0
    parts = [brushkit.block("duct_body", (sec_w, MODULE, sec_h), (0.0, 0.0, z))]
    for y in (-MODULE / 2.0 + 0.06, 0.0, MODULE / 2.0 - 0.06):
        parts.append(brushkit.block("duct_flange_%.0f" % (y * 10 + 30),
                                    (sec_w + 0.12, 0.10, sec_h + 0.12),
                                    (0.0, y, z)))
    for y in (-MODULE / 4.0, MODULE / 4.0):
        parts.append(brushkit.block("duct_hanger_%.0f" % (y * 10 + 20),
                                    (0.08, 0.06, drop),
                                    (0.0, y, -drop / 2.0)))
        parts.append(brushkit.block("duct_strap_%.0f" % (y * 10 + 20),
                                    (sec_w + 0.08, 0.06, 0.07),
                                    (0.0, y, z - sec_h / 2.0 - 0.035)))
    return common.join(parts, "arch_duct")


def arch_catwalk():
    """A 4 m elevated walkway with a deck at 2.60 m.

    2.60 is `SAFE_BASE_JUMP_GAP`, and it is the height the approved gallery
    corridor and balcony arena already put their decks at -- so a catwalk
    dropped into either lands level with what is there rather than
    introducing a third height.

    1.60 m wide: the player is 0.80 across, so that is two body widths, and
    it is deliberately NOT `brute_lane` 2.60. A catwalk is optional space,
    and something a brute cannot follow you onto is the point of it.
    """
    deck, width = GAP, 1.60
    parts = [
        brushkit.block("cw_deck", (width, MODULE, 0.22),
                       (0.0, 0.0, deck - 0.11)),
        # Six treads and two posts a side, not nine and three: the first
        # pass was 280 triangles against the 250 the tier allows, and the
        # rule is DELETE geometry rather than raise the ceiling.
        brushkit.grate("cw_tread", (width - 0.16, MODULE - 0.10, 0.06),
                       6, 0.12, (0.0, 0.0, deck + 0.02), axis="y"),
    ]
    for side in (-1.0, 1.0):
        x = side * (width / 2.0 - 0.05)
        parts.append(brushkit.block("cw_stringer_%d" % int(side),
                                    (0.10, MODULE, 0.34),
                                    (x, 0.0, deck - 0.28)))
        parts.append(brushkit.block("cw_rail_%d" % int(side),
                                    (0.08, MODULE, 0.08),
                                    (x, 0.0, deck + 0.95)))
        parts.append(brushkit.block("cw_rail_mid_%d" % int(side),
                                    (0.06, MODULE, 0.06),
                                    (x, 0.0, deck + 0.52)))
        for y in (-MODULE / 2.0 + 0.35, MODULE / 2.0 - 0.35):
            parts.append(brushkit.block(
                "cw_post_%d_%.0f" % (int(side), y * 10 + 30),
                (0.08, 0.08, 0.99), (x, y, deck + 0.50)))
    for y in (-MODULE / 2.0 + 0.4, MODULE / 2.0 - 0.4):
        parts.append(brushkit.wedge(
            "cw_bracket_%.0f" % (y * 10 + 30), (0.70, 0.12, 0.44),
            (0.0, y, deck - 0.42), axis="x"))
    return common.join(parts, "arch_catwalk")


def arch_tunnel_bore():
    """A 4 m bored section, `corridor_width_min` across, with a flat invert.

    A perfectly round tunnel is a different construction language from the
    rest of the facility and, more practically, has no floor. This is a
    horseshoe: a flat walkable invert, straight springing to 1.20 m, and a
    segmented crown over it -- twelve segments, which `max_radial_segments`
    permits above a 1.5 m radius.

    The rings every 2 m are what make it read as bored and lined rather
    than as a pipe.
    """
    half, spring, radius = W_MIN / 2.0, 1.20, W_MIN / 2.0
    thick, segs = 0.34, 12
    parts = [brushkit.block("tb_invert", (W_MIN, MODULE, 0.40),
                            (0.0, 0.0, -0.20))]
    for side in (-1.0, 1.0):
        parts.append(brushkit.block(
            "tb_spring_%d" % int(side), (thick, MODULE, spring),
            (side * (half + thick / 2.0), 0.0, spring / 2.0)))
    # The crown: half of a `segs`-gon, springing at `spring`.
    for i in range(segs // 2):
        a0 = math.pi * i / (segs // 2)
        a1 = math.pi * (i + 1) / (segs // 2)
        mid = (a0 + a1) / 2.0
        chord = 2.0 * radius * math.sin((a1 - a0) / 2.0)
        parts.append(brushkit.block(
            "tb_crown_%d" % i, (chord + 0.04, MODULE, thick),
            (-math.cos(mid) * (radius + thick / 2.0), 0.0,
             spring + math.sin(mid) * (radius + thick / 2.0)),
            rotation_z=0.0))
        parts[-1].rotation_euler = (0.0, -mid + math.pi / 2.0, 0.0)
    for y in (-MODULE / 2.0 + 0.18, MODULE / 2.0 - 0.18):
        for side in (-1.0, 1.0):
            parts.append(brushkit.block(
                "tb_ring_%d_%.0f" % (int(side), y * 10 + 30),
                (0.16, 0.30, spring), (side * (half - 0.08), y, spring / 2.0)))
    return common.join(parts, "arch_tunnel_bore")


def arch_secret_alcove():
    """`_secret_alcove`, to the letter.

    The slab is `SECRET_LEDGE_DEPTH` 1.8 x `SECRET_LEDGE_THICKNESS` 0.3 x
    2.4, its TOP at the lip -- not its centre -- and the lip rail is
    0.12 x 0.35, inset 0.06 from the inward edge and non-colliding, so a
    hard landing is never bounced back off a rail you meant to clear.

    Built at `SECRET_LIP_MAX` 4.2, the top of the engine's clamp, because a
    module is authored at one size and this is the one where the alcove has
    the most headroom over it. The underside then sits at 3.9, well over
    `secret_underside_min` 2.75.

    DESIGN s19 permits exactly one thing up here -- *a plaque and nothing
    else* -- so a plaque is modelled and nothing else is. No reward, no
    exit, no objective: the room plays identically if you never reach it.
    """
    lip = S_LIP_MAX
    assert lip - S_THICK >= S_UNDER, "the underside would be a wall"
    parts = [
        brushkit.block("sa_ledge", (S_DEPTH, S_WIDTH, S_THICK),
                       (0.0, 0.0, lip - S_THICK / 2.0)),
        # Non-colliding in the engine; here it is just geometry, inset from
        # the inward edge exactly as `_secret_alcove` insets it.
        brushkit.block("sa_lip", (0.12, S_WIDTH, 0.35),
                       (-(S_DEPTH / 2.0 - 0.06), 0.0, lip + 0.17)),
        brushkit.block("sa_corbel", (S_DEPTH - 0.3, S_WIDTH - 0.5, 0.26),
                       (0.12, 0.0, lip - S_THICK - 0.13)),
        brushkit.wedge("sa_corbel_slope", (S_DEPTH - 0.3, S_WIDTH - 0.5, 0.34),
                       (0.12, 0.0, lip - S_THICK - 0.43), axis="x"),
        # The plaque, and nothing else.
        brushkit.block("sa_plaque", (0.06, 0.80, 0.52),
                       (S_DEPTH / 2.0 - 0.16, 0.0, lip + 0.30)),
        brushkit.block("sa_plaque_rim", (0.09, 0.92, 0.10),
                       (S_DEPTH / 2.0 - 0.16, 0.0, lip + 0.59)),
    ]
    return common.join(parts, "arch_secret_alcove")


def arch_window():
    """An interior opening between two spaces, in a 4 m panel.

    `door_height` is 3.2 and the sill is at 1.0, so the opening is 2.20
    tall and 2.40 wide -- the same width as a door, because a window a
    player can see a fight through wants the door's own module rhythm
    rather than a size of its own.

    No glass. A pane would be the one transparent surface in the project
    and would need a material the palette does not have; the reveal and the
    mullion carry it instead.
    """
    sill, head = 1.0, DOOR_H
    open_w = DIM["door_width"]
    # The parameter is `opening_from_floor`, not a centre: the panel builds
    # its four blocks from the SILL up, which is the same convention the
    # engine's own `_perimeter` uses when it carves a door.
    parts = [brushkit.wall_with_opening(
        "arch_window", (MODULE, WALL, MODULE), (open_w, head - sill),
        opening_at_x=0.0, opening_from_floor=sill)]
    parts.append(brushkit.block("wn_sill", (open_w + 0.46, WALL + 0.22, 0.16),
                                (0.0, 0.0, sill - 0.08)))
    parts.append(brushkit.block("wn_head", (open_w + 0.46, WALL + 0.16, 0.20),
                                (0.0, 0.0, head + 0.10)))
    for side in (-1.0, 1.0):
        parts.append(brushkit.block(
            "wn_jamb_%d" % int(side), (0.20, WALL + 0.14, head - sill + 0.2),
            (side * (open_w / 2.0 + 0.10), 0.0, (sill + head) / 2.0)))
    parts.append(brushkit.block("wn_mullion", (0.12, WALL + 0.06, head - sill),
                                (0.0, 0.0, (sill + head) / 2.0)))
    return common.join(parts, "arch_window")


MODULES = [
    (arch_vent, "trim", "architecture_module", "wall"),
    (arch_duct, "trim", "architecture_module", "ceiling"),
    (arch_catwalk, "floor", "architecture_module", "floor"),
    (arch_tunnel_bore, "wall", "architecture_module", "module_floor"),
    (arch_secret_alcove, "floor", "architecture_module", "module_floor"),
    (arch_window, "wall", "architecture_module", "wall"),
]


def main():
    common.reset_scene()
    report = {}
    for builder, role, category, anchor in MODULES:
        obj = builder()
        name = obj.name
        report[name] = kit.finish(obj, name, role, category,
                                  "%s/%s.glb" % (OUT, name), anchor=anchor)
    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch021",
                       "architecture", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
    print("[art] batch021 manifest -> %s" % out)


if __name__ == "__main__":
    main()
