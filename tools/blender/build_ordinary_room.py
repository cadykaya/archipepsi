#!/usr/bin/env python3
"""Batch 062 -- one ORDINARY room worth walking through before anything is in it.

    blender --background --python tools/blender/build_ordinary_room.py

`shell_concourse_pier`, an `arena`-type shell of standard size: interior
16 x 22 m, 7.0 m to the roof. Not a showcase and not a landmark. It is
the size of the fallback's own ordinary arenas (12-24 x 10-22 m, walls
4.5-7 m), with its space arranged instead of left as one box.

What the room does, before any content arrives. Sides are as you see
them coming in through the entrance: +x is on your LEFT.

  * **You come in low.** The door opens under a 4 m deep front gallery
    whose underside is the door's own head height (3.2 m). You then step
    out into the full 7.0 m volume.
  * **The pier hides the way on.** A 5.6 x 5 m solid pier, 3.5 m tall,
    stands between the entry (centred) and the exit (4.8 m off-centre,
    on your left, in the far wall). The straight line from door to door
    passes through it. Either way round it is a floor route: 4.4 m clear
    on the exit side, 3.6-6 m on the stair side.
  * **A second route that comes back.** Stair A climbs the wall on your
    right to the gallery. The gallery overlooks the room you just
    entered, and a bridge crosses from it to the pier top, where the
    room's reward goes when a chamber has one. Stair B comes down behind
    the pier to a 2.1 m landing beside the exit. The upper loop and the
    floor routes rejoin at the exit, and the pier's open edges let you
    drop straight back to the floor.
  * **The upper level is not a tunnel.** 7.0 m to the roof leaves 3.5 m
    over the decks. At 6.4 m the first pictures through the real
    player's camera showed the roof 1.3 m above the eye up there, and
    the bridge read as a corridor.

Everything is the house kit: `brushkit` blocks, the room roles
`roomcollision` reads, the concrete_facility theme every shell uses,
doors at `DIM`'s 2.4 x 3.2 m at grade, and the P1 room contract written
by `roomcontract`. The stairs are `roomkit.flight`'s construction: flat,
level treads, each overlapping the next by `FLIGHT_OVERLAP` so no seam
opens. The rise is 0.35 m, not flight's 0.9 m ceiling, so it sits
inside the player's 1.0 m step and the enemies' footing. Each stair is
solid below, a stepped mass rather than a stack of floating treads, so
no one walks into the space under it. Parapets are 1.1 m, above the
1.0 m step, so a railing never becomes a stair.

Every declared walk is proved at build time by `traversallaw` over the
colliders this build places. `room_audit.gd`'s real-capsule flood stays
the authority, and `tools/content/run_room_walk.sh` walks Production's
own `Player` through the room at a pinned revision.
"""

from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import brushkit  # noqa: E402
import common  # noqa: E402
import materials  # noqa: E402
import roomcollision  # noqa: E402
import roomcontract  # noqa: E402
import roomkit  # noqa: E402
import traversallaw  # noqa: E402
import palette as pal  # noqa: E402

OUT = "batch062/shells"
CID = "shell_concourse_pier"
THEME = common.THEME
DIM = common.DIM
WALL = DIM["wall_thickness"]                 # 0.40
DOOR_W = DIM["door_width"]                   # 2.40
DOOR_H = DIM["door_height"]                  # 3.20

#: The plan, in Godot coordinates: x across, z into the room from the
#: entry, heights up. Every literal below is read by BOTH the geometry and
#: the contract, so the manifest cannot describe a different room.
W, D, H = 16.0, 22.0, 7.0
DECK = 3.5                  # gallery, bridge and pier tops
SLAB = DECK - DOOR_H        # 0.30: the deck's underside is the door head
EXIT_X = 4.8
GALLERY = (-W / 2.0, W / 2.0, 0.0, 4.0)
PIER = (-2.0, 3.6, 8.0, 13.0)
BRIDGE = (0.0, 2.4, 4.0, 8.0)
STAIR_A = (-W / 2.0, -W / 2.0 + 2.4, 4.0, 11.9)   # on your right, entering
# Down behind the pier. It stops 2.1 m short of the back wall: the first
# version ran to 1.1 m, and the real player's walk (tools/content/
# room_walk.gd) came off the last tread onto its edge, facing the wall.
STAIR_B = (1.2, 3.6, 13.0, 19.9)
RISE = 0.35
# Where a chamber's reward goes: on the pier, west of the line from the
# bridge to stair B so it never stands in that path. Undeclared, the
# runtime puts it at the room's centre, which is inside the pier --
# Production's own census (`--room-contract`) found exactly that.
REWARD = (-0.6, 10.5)
PARAPET_H, PARAPET_T = 1.1, 0.20

_IMAGES = {}


def _image(role):
    if role not in _IMAGES:
        canvas, _ = materials.paint(THEME, role)
        _IMAGES[role] = canvas.to_blender("room_%s_%s" % (THEME, role))
    return _IMAGES[role]


_MATERIALS = {}


def _material(role):
    """One material per role, NAMED as the role: `floor`, `wall`, `trim`,
    `ceiling` (the authority draft's 8.4, what `check_theme_roles.py` asks
    of a shell authored after it). A new shell is not a legacy one, so it
    does not take a `<prefix>_<role>` name and an exemption. One material
    per PART would reach the export as `floor.001`, which 8.4 refuses
    rather than normalises -- hence the cache.
    """
    if role not in _MATERIALS:
        _MATERIALS[role] = common.make_textured_material(
            role, _image(role), roughness=pal.roughness(THEME))
    return _MATERIALS[role]


def _paint(obj, name, role):
    """Texture a part, and record what that role means for the player."""
    common.assign(obj, _material(role))
    return roomcollision.paint_role(obj, role)


def _y(z_godot):
    """Godot depth -> Blender y. The one conversion, spelled out."""
    return -z_godot


def _box(parts, name, tag, x0, x1, z0, z1, y0, y1, role):
    """A block by its EDGES in Godot coordinates."""
    parts.append(_paint(brushkit.block(
        "%s_%s" % (name, tag), (x1 - x0, z1 - z0, y1 - y0),
        ((x0 + x1) / 2.0, _y((z0 + z1) / 2.0), (y0 + y1) / 2.0)),
        name, role))


def _stair(parts, name, tag, x0, x1, z0, z1, high_at):
    """`roomkit.flight`'s treads at a 0.35 m rise, solid down to the floor.

    `high_at` is the z where the stair meets its deck. Each tread is level
    and reaches FLIGHT_OVERLAP into its successor's slice of the run,
    exactly as `flight` builds them, and the tops are held to the same
    `roomkit.assert_walkable` rule.
    """
    steps = int(round(DECK / RISE))
    per = DECK / steps
    run = z1 - z0
    made = []
    for i in range(steps):
        top = per * (i + 1)
        t0 = run * (i / float(steps))
        t1 = run * ((i + 1) / float(steps))
        if i < steps - 1:
            t1 += roomkit.FLIGHT_OVERLAP
        # Measured from the LOW end, which is the end away from the deck.
        if high_at == z0:
            a, b = z1 - t1, z1 - t0
        else:
            a, b = z0 + t0, z0 + t1
        _box(parts, name, "%s_tread%d" % (tag, i), x0, x1, a, b, 0.0, top,
             "floor")
        made.append(((x0, x1, a, b), top))
    roomkit.assert_walkable(name, tag, 0.0, made)
    return made


def build():
    name = "cp"
    parts = []
    stones, heights, snames = [], [], []

    def surface(tag, x0, x1, z0, z1, top):
        stones.append((((x0 + x1) / 2.0, _y((z0 + z1) / 2.0)),
                       (x1 - x0, z1 - z0)))
        heights.append(top)
        snames.append(tag)

    half = W / 2.0
    # --- the box ------------------------------------------------------
    _box(parts, name, "floor", -half, half, 0.0, D, -0.5, 0.0, "floor")
    surface("floor", -half, half, 0.0, D, 0.0)
    _box(parts, name, "roof", -half - WALL, half + WALL, -WALL, D + WALL,
         H, H + WALL, "ceiling")
    for side in (-1.0, 1.0):
        x0 = half if side > 0 else -half - WALL
        _box(parts, name, "side_%d" % int(side), x0, x0 + WALL, -WALL,
             D + WALL, 0.0, H, "wall")
    # Front wall: the entry, centred -- the socket is the shell's origin.
    for side, (x0, x1) in ((-1, (-half, -DOOR_W / 2.0)),
                           (1, (DOOR_W / 2.0, half))):
        _box(parts, name, "front_%d" % side, x0, x1, -WALL, 0.0, 0.0, H,
             "wall")
    _box(parts, name, "front_lintel", -DOOR_W / 2.0, DOOR_W / 2.0, -WALL,
         0.0, DOOR_H, H, "wall")
    # Back wall: the exit, 4.8 m to +x of the entry's line (your left).
    ex0, ex1 = EXIT_X - DOOR_W / 2.0, EXIT_X + DOOR_W / 2.0
    _box(parts, name, "back_l", -half, ex0, D, D + WALL, 0.0, H, "wall")
    _box(parts, name, "back_r", ex1, half, D, D + WALL, 0.0, H, "wall")
    _box(parts, name, "back_lintel", ex0, ex1, D, D + WALL, DOOR_H, H,
         "wall")

    # --- the covered entry: a front gallery at door-head height -------
    gx0, gx1, gz0, gz1 = GALLERY
    _box(parts, name, "gallery", gx0, gx1, gz0, gz1, DOOR_H, DECK, "floor")
    surface("gallery", gx0, gx1, gz0, gz1, DECK)

    # --- the pier: solid mass, a deck on top ---------------------------
    px0, px1, pz0, pz1 = PIER
    _box(parts, name, "pier", px0, px1, pz0, pz1, 0.0, DOOR_H, "wall")
    _box(parts, name, "pier_top", px0, px1, pz0, pz1, DOOR_H, DECK, "floor")
    surface("pier", px0, px1, pz0, pz1, DECK)

    # --- the bridge, gallery to pier, railed both sides ----------------
    bx0, bx1, bz0, bz1 = BRIDGE
    _box(parts, name, "bridge", bx0, bx1, bz0, bz1, DOOR_H, DECK, "floor")
    surface("bridge", bx0 + PARAPET_T, bx1 - PARAPET_T, bz0, bz1, DECK)
    for tag, x0 in (("l", bx0), ("r", bx1 - PARAPET_T)):
        _box(parts, name, "bridge_rail_%s" % tag, x0, x0 + PARAPET_T,
             bz0, bz1, DECK, DECK + PARAPET_H, "wall")

    # --- the gallery's edge: railed, open at the stair and the bridge ---
    ax0, ax1, az0, az1 = STAIR_A
    for tag, (x0, x1) in (("a", (ax1, bx0)), ("b", (bx1, gx1))):
        _box(parts, name, "gallery_rail_%s" % tag, x0, x1,
             gz1 - PARAPET_T, gz1, DECK, DECK + PARAPET_H, "wall")

    # --- the two stairs -------------------------------------------------
    _stair(parts, name, "stair_a", ax0, ax1, az0, az1, high_at=az0)
    sx0, sx1, sz0, sz1 = STAIR_B
    _stair(parts, name, "stair_b", sx0, sx1, sz0, sz1, high_at=sz0)

    # --- trim: deck edges and skirting, looked at, never stood on -------
    _box(parts, name, "gallery_fascia", ax1, gx1, gz1, gz1 + 0.08,
         DOOR_H - 0.1, DECK, "trim")
    for tag, (x0, x1, z0, z1) in (
            ("f", (px0, px1, pz0 - 0.08, pz0)),
            ("k", (px0, sx0, pz1, pz1 + 0.08)),
            ("w", (px0 - 0.08, px0, pz0, pz1)),
            ("e", (px1, px1 + 0.08, pz0, pz1))):
        _box(parts, name, "pier_band_%s" % tag, x0, x1, z0, z1,
             DOOR_H - 0.1, DECK, "trim")
    for side in (-1.0, 1.0):
        x0 = half - 0.10 if side > 0 else -half
        _box(parts, name, "skirt_%d" % int(side), x0, x0 + 0.10, 0.0, D,
             0.0, 0.22, "trim")
    return name, parts, stones, heights, snames


def main():
    common.reset_scene()
    name, parts, stones, heights, snames = build()

    colliders = roomcollision.build(parts, name)
    roomcollision.assert_exact(name, parts, colliders)
    roomcollision.assert_supports(name, colliders, stones, heights, snames)
    roomcollision.assert_standable(name, colliders, stones, heights, snames)
    probe = roomcollision.measure_probe(colliders, stones, heights, snames)

    obj = common.join(parts, name)
    common.uv_project_world(obj, materials.ARCH_DENSITY, materials.ARCH_SIZE)
    entry = common.export_glb(obj, "%s/%s.glb" % (OUT, CID), "room",
                              tier="architecture",
                              texture_size=materials.ARCH_SIZE,
                              anchor="entrance", check_flat=False,
                              collision=colliders)
    if probe:
        # RECORDED, not corrected: a declared surface that measures
        # otherwise travels with the asset (the floor under the pier).
        entry["surface_probe"] = probe

    entry["exit_offset"] = [EXIT_X, 0.0, D]
    entry["exit_yaw"] = 0.0
    entry["check_anchor"] = None
    entry["enemy_anchors"] = []
    entry["bounds"] = [[-W / 2.0, -1.0, 0.0], [W, H + 1.0, D]]
    entry["interior"] = [W, H, D]

    entry["surfaces"] = roomcontract.surfaces_from_stones(
        stones, heights, snames)

    def seg(tag, a, b, mandatory):
        return {"name": tag, "kind": "walk", "mandatory": mandatory,
                "start": roomcontract.godot(a[0], _y(a[2]), a[1]),
                "end": roomcontract.godot(b[0], _y(b[2]), b[1])}

    ax0, ax1, az0, az1 = STAIR_A
    sx0, sx1, sz0, sz1 = STAIR_B
    entry["traversal"] = [
        # The only mandatory route: door to door on the floor, round the
        # pier. Points are (x, height, z).
        seg("entry_to_exit", (0.0, 0.0, 1.0), (EXIT_X, 0.0, D - 1.0), True),
        # The upper loop, optional by design: up, across, down.
        seg("floor_to_gallery", ((ax0 + ax1) / 2.0, 0.0, az1 + 0.8),
            ((ax0 + ax1) / 2.0, DECK, 2.0), False),
        seg("gallery_to_pier", (1.2, DECK, 2.0), (0.8, DECK, 10.5), False),
        seg("pier_to_exit", ((sx0 + sx1) / 2.0, DECK, 10.5),
            (EXIT_X, 0.0, D - 1.0), False),
    ]

    px0, px1, pz0, pz1 = PIER

    def block(tag, x0, x1, z0, z1, top):
        return roomcontract.volume(tag, "no_build",
                                   ((x0 + x1) / 2.0, _y((z0 + z1) / 2.0),
                                    top / 2.0),
                                   (x1 - x0, z1 - z0, top))

    entry["volumes"] = [
        block("pier", px0, px1, pz0, pz1, DECK),
        block("stair_a", ax0, ax1, az0, az1, DECK),
        block("stair_b", sx0, sx1, sz0, sz1, DECK),
        roomcontract.volume("arrival", "player_entry",
                            (0.0, -1.6, 1.0), (DOOR_W, 2.0, 2.0)),
        roomcontract.volume("reward", "objective",
                            (REWARD[0], _y(REWARD[1]), DECK + 1.0),
                            (2.4, 2.4, 2.0)),
    ]
    entry["sockets"] = [
        roomcontract.socket("entry", "doorway", (0.0, 0.0, 0.0), yaw=180.0,
                            width=DOOR_W, height=DOOR_H, surface_id="floor"),
        roomcontract.socket("exit", "doorway", (EXIT_X, _y(D), 0.0),
                            yaw=0.0, width=DOOR_W, height=DOOR_H,
                            surface_id="floor"),
    ]

    # Production's walk law, over the boxes this build just placed: every
    # declared walk -- the mandatory floor route and the optional loop --
    # has continuous ground, or the build stops.
    traversallaw.assert_declared(colliders, entry, CID,
                                 roomcollision._world_box)

    entry["size_godot"] = [round(entry["size"][0], 3),
                           round(entry["size"][2], 3),
                           round(entry["size"][1], 3)]
    roomcontract.assert_axis_order(CID, entry["size"], entry["interior"],
                                   entry["size_godot"])

    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch062",
                       "shells", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump({CID: entry}, handle, indent=2, sort_keys=True)
    print("[art] batch062 manifest -> %s" % out)


if __name__ == "__main__":
    main()
