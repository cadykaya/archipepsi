"""Batch 007 -- the kit that moves you. Tier 3's five Pri-A modules.

    .tools/blender/blender -b --python tools/blender/build_traversal.py

`ASSET_INVENTORY.md` section 6 lists twenty-nine architecture modules and
nine are built. Five of the twenty unbuilt ones are **Pri A**, and they are
all the same kind of thing: the pieces that get the player from one height
to another and from one room to the next.

| ID | What it is | The engine number it answers to |
| --- | --- | --- |
| `arch_stair` | a flight that climbs 2.0 m in 4.0 m | `MAX_VERTICAL_STEP` 1.0 |
| `arch_ramp` | a slope that climbs 1.333 m in 4.0 m | `JUMP_APEX` 1.333 |
| `arch_ledge` | a 2.5 m shelf you jump to | `MIN_PLATFORM_SIZE` 2.5, `SAFE_BASE_JUMP_GAP` 2.6 |
| `arch_connector_straight` | 4 m of corridor | `CORRIDOR_HEIGHT` 3.6, `CORRIDOR_WIDTH_MIN` 4.0 |
| `arch_corner_left` / `_right` | the same, turning | as above |

Nothing here establishes new visual DNA. Every one is the approved facility
language on a module the generator already builds out of primitives.

## Why the heights are what they are

A traversal module whose dimensions were chosen for looks would teach the
player a lie about their own movement, so none of them were:

* **The stair climbs 2.0 m**, which is twice `MAX_VERTICAL_STEP` and above
  `JUMP_APEX` -- the first height the player can neither walk up nor jump.
  A stair that climbed less would be decoration on a step. Its individual
  risers are 0.25 m, well inside what `brushkit.stair` will allow, and it
  is `BRUTE_LANE` wide (2.6 m) so the largest enemy can use it.
* **The ramp climbs 1.333 m**, exactly `JUMP_APEX`. That is the sharpest
  fact about a ramp in this game: the player can jump it, and the things
  that need it are the things that cannot. Also 2.6 m wide, for the same
  reason.
* **The ledge projects 2.5 m**, `MIN_PLATFORM_SIZE` -- the smallest landing
  the generator will place -- and its front edge is what you clear a
  `SAFE_BASE_JUMP_GAP` of 2.6 m to reach.
* **The corridor pieces are 4.0 m wide and 3.6 m high inside**, which are
  `CORRIDOR_WIDTH_MIN` and `CORRIDOR_HEIGHT`. Built at the minimum on
  purpose: a module authored at the maximum cannot be used in the narrow
  case, and the narrow case is the one `zone.py` reaches for most.

## One thing about the order of operations

`build_architecture.finish` carries the rule and it applies harder here:
**the origin is final before the UVs are projected.** These modules tile
against each other and against the nine already built, so a projection
taken at a build position bakes that offset into the grain and two
neighbouring corridor sections come out misaligned. Parts get their
materials first, the object is joined, the origin is set, and only then is
anything projected.
"""

from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import brushkit  # noqa: E402
import common  # noqa: E402
import materials  # noqa: E402
import palette as pal  # noqa: E402

THEME = "concrete_facility"
OUT = "batch007/architecture"
MODULE = 4.0

DIM = common.DIM
WALL = DIM["wall_thickness"]              # 0.40
STEP = DIM["max_vertical_step"]           # 1.00
APEX = DIM["jump_apex"]                   # 1.333
LANE = DIM["brute_lane"]                  # 2.60
PLATFORM = DIM["min_platform_size"]       # 2.50
GAP = DIM["safe_base_jump_gap"]           # 2.60
C_HEIGHT = DIM["corridor_height"]         # 3.60
C_WIDTH = DIM["corridor_width_min"]       # 4.00

#: Outside face to outside face: the clear width plus a wall each side.
SPAN = C_WIDTH + WALL * 2.0               # 4.80

_IMAGES = {}


def image(role):
    if role not in _IMAGES:
        canvas, _ = materials.paint(THEME, role)
        _IMAGES[role] = canvas.to_blender("trav_%s_%s" % (THEME, role))
    return _IMAGES[role]


def paint(obj, name, role, roughness=None):
    common.assign(obj, common.make_textured_material(
        "%s_%s" % (name, role), image(role),
        roughness=pal.roughness(THEME) if roughness is None else roughness))
    return obj


def finish(name, parts, anchor="floor", category="architecture_module"):
    obj = common.join(parts, name)
    common.set_origin(obj, anchor)
    common.uv_project_world(obj, materials.ARCH_DENSITY, materials.ARCH_SIZE)
    return common.export_glb(obj, "%s/%s.glb" % (OUT, name), category,
                             tier="architecture",
                             texture_size=materials.ARCH_SIZE, anchor=anchor)


# ----------------------------------------------------------------------
# climbing
# ----------------------------------------------------------------------

def arch_stair():
    """Eight risers of 0.25 m over a 4.0 m run, 2.6 m wide.

    2.0 m of climb: twice `MAX_VERTICAL_STEP`, so it is above both what the
    player can walk up and what a base jump clears. `brushkit.stair` refuses
    a per-step rise over `MAX_VERTICAL_STEP` outright, which is a guard
    against a much worse mistake than this one.
    """
    steps = 8
    rise = 2.0 / steps
    run = MODULE / steps
    flight = paint(brushkit.stair("stair_flight", run, rise, LANE, steps),
                   "arch_stair", "floor")
    parts = [flight]
    # Stringers: a wedge each side, following the flight. Without them the
    # module is a staircase of naked blocks, which is what the generator
    # already builds and what this is here to replace.
    for side in (-1.0, 1.0):
        stringer = brushkit.wedge(
            "stair_stringer_%d" % int(side), (0.22, MODULE, 2.0),
            (side * (LANE / 2.0 + 0.11), 0.0, 1.0), axis="y")
        parts.append(paint(stringer, "arch_stair", "trim"))
    return parts


def arch_ramp():
    """A slope climbing `JUMP_APEX` over a 4.0 m run, 2.6 m wide.

    No modelled grip battens. Six of them cost 72 triangles against a 250
    ceiling and the rule from `assert_budget` is to paint what can be
    painted -- and a tread pattern is exactly that. The triangles buy kerbs
    instead, which cannot be painted, because their whole job is to be a
    silhouette that says *this edge is a drop*.
    """
    deck = brushkit.wedge("ramp_deck", (LANE, MODULE, APEX),
                          (0.0, 0.0, APEX / 2.0), axis="y")
    parts = [paint(deck, "arch_ramp", "floor")]
    for side in (-1.0, 1.0):
        kerb = brushkit.wedge(
            "ramp_kerb_%d" % int(side), (0.18, MODULE, APEX + 0.16),
            (side * (LANE / 2.0 + 0.09), 0.0, (APEX + 0.16) / 2.0), axis="y")
        parts.append(paint(kerb, "arch_ramp", "trim"))
    # A landing lip at the top, so the ramp ends ON something rather than in
    # mid-air. It is also the part the player's feet actually meet first.
    parts.append(paint(brushkit.block(
        "ramp_lip", (LANE + 0.36, 0.30, 0.10),
        (0.0, MODULE / 2.0 - 0.15, APEX + 0.05)), "arch_ramp", "trim"))
    return parts


def arch_ledge():
    """A 4.0 x 2.5 m shelf, anchored at the surface you stand on.

    `MIN_PLATFORM_SIZE` is 2.5 m and `SAFE_BASE_JUMP_GAP` is 2.6, so this is
    the smallest landing the generator will place and the front edge is what
    a base jump has to clear.

    Anchored `ceiling`, which reads oddly until you look at what that anchor
    does: highest point at Z 0. For a shelf the highest point IS the walking
    surface, so placing the module at 3.0 m puts its floor at 3.0 m -- which
    is the only height anyone cares about. `floor` would anchor it to the
    bottom of its brackets and every placement would need the thickness
    subtracted by hand.
    """
    parts = [paint(brushkit.block("ledge_deck", (MODULE, PLATFORM, 0.32),
                                  (0.0, 0.0, -0.16)), "arch_ledge", "floor")]
    # A nosing on the front edge: the one line the player aims a jump at.
    parts.append(paint(brushkit.block(
        "ledge_nose", (MODULE, 0.18, 0.42), (0.0, -PLATFORM / 2.0 + 0.09,
                                             -0.21)), "arch_ledge", "trim"))
    # Three brackets under it. A 2.5 m cantilever with nothing holding it up
    # is the reason a lot of level geometry reads as level geometry.
    for i in range(3):
        x = -MODULE / 2.0 + 0.7 + i * 1.3
        parts.append(paint(brushkit.wedge(
            "ledge_bracket_%d" % i, (0.22, PLATFORM - 0.30, 0.55),
            (x, 0.08, -0.32 - 0.275), axis="y"), "arch_ledge", "trim"))
    return parts


# ----------------------------------------------------------------------
# going somewhere
# ----------------------------------------------------------------------

def _shell(name, walls, run=None):
    """Floor, ceiling and whichever walls a piece has.

    `walls` is a list of (axis, sign): ("x", 1.0) puts a wall on the +X
    face. `run` is the length along X -- `MODULE` for a straight section,
    which is what makes it TILE, and the full `SPAN` for a junction, which
    has to be square because the corridor leaves it sideways.

    Built at `CORRIDOR_WIDTH_MIN` clear and `CORRIDOR_HEIGHT` tall, not at
    the maximum: a module authored at the maximum cannot be used in the
    narrow case, and the narrow case is the one `zone.py` reaches for most.
    """
    run = SPAN if run is None else run
    half_y = SPAN / 2.0
    half_x = run / 2.0
    parts = [
        paint(brushkit.block("%s_floor" % name, (run, SPAN, WALL),
                             (0.0, 0.0, -WALL / 2.0)), name, "floor"),
        paint(brushkit.block("%s_ceil" % name, (run, SPAN, WALL),
                             (0.0, 0.0, C_HEIGHT + WALL / 2.0)),
              name, "ceiling"),
    ]
    for axis, sign in walls:
        size = ((run, WALL, C_HEIGHT) if axis == "y"
                else (WALL, SPAN, C_HEIGHT))
        at = ((0.0, sign * (half_y - WALL / 2.0), C_HEIGHT / 2.0)
              if axis == "y"
              else (sign * (half_x - WALL / 2.0), 0.0, C_HEIGHT / 2.0))
        parts.append(paint(brushkit.block("%s_wall_%s%d"
                                          % (name, axis, int(sign)),
                                          size, at), name, "wall"))
        # A skirting where every wall meets the floor. Batch 001's finding
        # was that the kit exposes one 4 m rhythm everywhere; a continuous
        # horizontal at 0.22 m is a second rhythm that costs 12 triangles.
        skirt = ((run, 0.10, 0.22) if axis == "y" else (0.10, SPAN, 0.22))
        skirt_at = ((0.0, sign * (half_y - WALL - 0.05), 0.11) if axis == "y"
                    else (sign * (half_x - WALL - 0.05), 0.0, 0.11))
        parts.append(paint(brushkit.block("%s_skirt_%s%d"
                                          % (name, axis, int(sign)),
                                          skirt, skirt_at), name, "trim"))
    return parts


def arch_connector_straight():
    """4 m of corridor, running along X, with a services tray overhead.

    The tray sits at 2.55 m, the same height `arch_pipe_run` uses, so a
    corridor made of both does not have two service heights in it.
    """
    parts = _shell("arch_connector_straight",
                   [("y", -1.0), ("y", 1.0)], run=MODULE)
    tray = brushkit.block("conn_tray", (MODULE, 0.46, 0.12),
                          (0.0, -1.30, 2.55))
    parts.append(paint(tray, "arch_connector_straight", "accent"))
    for i in range(2):
        x = -MODULE / 2.0 + 1.0 + i * 2.0
        parts.append(paint(brushkit.block(
            "conn_hanger_%d" % i, (0.09, 0.09, 0.95), (x, -1.30, 3.13)),
            "arch_connector_straight", "trim"))
    return parts


def arch_corner(hand):
    """The same section turning 90 degrees. Enter along -X, leave along +/-Y.

    `left` because if you are walking in +X, +Y is on your left. The two
    are mirrors and both exist because a generator that only has one has to
    rotate 180 degrees to turn the other way, which puts the services tray
    and the skirting seam on the wrong side of the corridor.
    """
    sign = 1.0 if hand == "left" else -1.0
    name = "arch_corner_%s" % hand
    # Open on -X and on the turn side; walled on +X and the other side.
    parts = _shell(name, [("x", 1.0), ("y", -sign)])
    # A chamfer across the inside of the turn. A right-angled corridor
    # corner with a square inner angle is a corner nothing was ever built
    # into; a chamfer is what a real one has, and it stops the brute lane
    # from having a 90 degree pinch in it.
    half = SPAN / 2.0
    chamfer = brushkit.block("%s_chamfer" % name, (1.10, 0.34, C_HEIGHT),
                             (half - WALL - 0.30, -sign * (half - WALL - 0.30),
                              C_HEIGHT / 2.0), rotation_z=45.0 * sign)
    parts.append(paint(chamfer, name, "wall"))
    return parts


MODULES = [
    ("arch_stair", arch_stair, "floor"),
    ("arch_ramp", arch_ramp, "floor"),
    ("arch_ledge", arch_ledge, "ceiling"),
    ("arch_connector_straight", arch_connector_straight, "floor"),
    ("arch_corner_left", lambda: arch_corner("left"), "floor"),
    ("arch_corner_right", lambda: arch_corner("right"), "floor"),
]


def main():
    common.reset_scene()
    report = {}
    for name, builder, anchor in MODULES:
        report[name] = finish(name, builder(), anchor=anchor)
    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch007",
                       "architecture", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")


if __name__ == "__main__":
    main()
