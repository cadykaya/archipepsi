"""Batch 064 -- blue movement and orange breakable, built like the green kit.
CANDIDATE (Arty, 2026-10-08).

    .tools/blender/blender -b --python tools/blender/build_crossing_affordances.py

The owner's Crossing D playtest (2026-10-07) loved the green power kit
because its colour is "a recognizable accent on an actual physical
mechanism, not the whole object", and found the blue pads and orange
crates "too plain (blue rectangles, orange boxes)". This batch brings one
blue movement device and one orange breakable up to the green kit's bar,
and nothing more:

* `ca_launch_cradle` -- the look for Production's existing `LaunchPad`
  (an `Area3D`, `PAD_SIZE` 2.4 x 0.5 x 2.4 m, launching toward an authored
  target). A neutral steel cradle with a kick tray, two stepped guide fins
  that rise toward the launch heading, blue emitter rails, a boom that
  drops across the tray when the device is blocked, and a rear housing
  fed by the green raceway. Blue says WHAT it does and which way; green
  says WHETHER it is fed. Grey scale still reads direction: the fins and
  the tray rise toward the front, the housing is at the back.
* `ca_breakable_brace` -- the look for Production's `DestructibleCover`
  (a `StaticBody3D`, `SIZE` 1.5 x 1.4 x 0.9 m, HP 40). A shoring frame:
  neutral steel posts and skids holding station panels in orange
  break-away clamps, with orange scored top rails and end straps that
  read from front, back, ends and above. Two panels per face hang on
  hinges, so damage is a physical change; the gaps show a dark core.
* `ca_breakable_brace_wreck` -- what is left when it breaks: skids, the
  bottom panels, post stubs and a fallen panel. No collision.

Fitted to SOURCE contracts, read on review/crossing-d-readability
(runtime bb683ce0): `affordance_nodes.gd` LaunchPad and
`destructible_cover.gd`. Dess's selected room mechanism did not exist
when this was built, so nothing here is bespoke to a room.

Frames: authored Z-up, exported Y-up (Batch 049's `_to_runtime`). The
cradle's launch heading is authoring +Y, which is Godot -Z, a Node3D's
own forward: `look_at` the target (at the pad's height) and it faces
the way it throws. The brace's origin is its box centre, the same frame
`DestructibleCover` builds its mesh and collider in.

Reuses the green kit's builder (`build_crossing_kit`): its materials,
hinges, export and meaning colours. Writes only under
`assets/models/batch064/` and changes no colour in the library.
"""

from __future__ import annotations

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh  # noqa: E402
import bpy  # noqa: E402

import brushkit  # noqa: E402
import build_crossing_kit as kit  # noqa: E402
import common  # noqa: E402
import materials  # noqa: E402
import paintkit  # noqa: E402
import roomcollision  # noqa: E402
from build_connect import _to_runtime  # noqa: E402

OUT = "batch064/crossing_affordances"
kit.OUT = OUT
SIZE = kit.SIZE
MOVE = kit.MEANING["movement"]            # #3266ee
MOVE_IDLE = "#2a4ea8"                     # unlit emitter: still blue
ORANGE = kit.MEANING["destructible"]      # #f48a36
SCORE = "#a8571c"

#: Production's contracts, as read (see the module docstring).
PAD_SIZE = (2.4, 2.4, 0.5)                # LaunchPad.PAD_SIZE, x, z(depth), y
COVER = (1.5, 0.9, 1.4)                   # DestructibleCover.SIZE: x, z, y
COVER_HP = 40.0

# --- canvases ---------------------------------------------------------------

_BASE_CANVAS = kit._canvas


def _canvas(name):
    base, accent, trim = materials._ramps(kit.THEME)
    if name == "ca_steel":
        # Quiet structural steel: the trim ramp WITHOUT the kick rail's
        # stripe, which is a steel blue that would muddy a blue device.
        # Mid-value, so the machine separates from D's dark floor at a
        # distance instead of sinking into it.
        canvas = paintkit.Canvas(SIZE, base[1])
        surface = materials.surface_for("trim", kit.THEME)
        paintkit.tonal_drift(canvas, surface, amount=0.04, cell_metres=1.0)
        paintkit.edge_wear(canvas, surface, base[0], surface.texels(0.08),
                           strength=0.35)
        return canvas
    if name == "ca_panel":
        # A station panel, pale like the walls it was taken from, with a
        # one-texel seam every 0.5 m so a slat reads as a panel.
        canvas = paintkit.Canvas(SIZE, base[2])
        surface = materials.surface_for("wall", kit.THEME)
        paintkit.tonal_drift(canvas, surface, amount=0.03, cell_metres=1.1)
        for i in range(0, SIZE, 16):
            canvas.hline(i, 0, SIZE - 1, base[1])
            canvas.vline(i, 0, SIZE - 1, base[1])
        return canvas
    if name == "ca_dark":
        return paintkit.Canvas(SIZE, "#1b1e22")
    if name == "ca_move":
        return paintkit.Canvas(SIZE, MOVE)
    if name == "ca_move_light":
        return paintkit.Canvas(SIZE, "#8fa9f4")
    if name == "ca_move_idle":
        return paintkit.Canvas(SIZE, MOVE_IDLE)
    if name == "ca_orange":
        return paintkit.Canvas(SIZE, ORANGE)
    if name == "ca_scored":
        # Orange with a diagonal score every 0.25 m: "breaks along here",
        # coarse enough not to add the high-frequency chatter the owner
        # asked to lose.
        canvas = paintkit.Canvas(SIZE, ORANGE)
        for x in range(SIZE):
            for y in range(SIZE):
                if (x + y) % 8 == 0:
                    canvas.set(x, y, SCORE)
        return canvas
    if name == "ca_tray":
        return _tray_canvas(trim)
    return _BASE_CANVAS(name)


kit._canvas = _canvas

#: The tray's top, mapped by hand (`_planar_uv`): 1.40 x 1.70 m is 45 x 54
#: texels from the canvas's bottom-left. Three blue chevrons point along
#: +V, the launch heading, on dark steel with a pale lip at the front.
TRAY = (1.40, 1.70, 0.05)


def _tray_canvas(trim):
    canvas = paintkit.Canvas(SIZE, trim[0])
    w, h = 45, 54

    def put(u, v, colour):
        if 0 <= u < SIZE and 0 <= v < SIZE:
            canvas.set(u, SIZE - 1 - v, colour)

    for u in range(w):
        for v in range(h):
            if u < 2 or u >= w - 2:
                put(u, v, trim[1])
            if v >= h - 3:
                put(u, v, "#c9ced1")
    # Chevrons: arms 3 texels thick, apex toward +V.
    for apex in (20, 33, 46):
        for d in range(0, 14):
            for t in range(3):
                put(w // 2 - d, apex - d + t - 2, MOVE)
                put(w // 2 + d, apex - d + t - 2, MOVE)
    return canvas


# --- geometry helpers ------------------------------------------------------

def _cyl(tag, radius, length, at, axis, mat):
    """An 8-sided cylinder (the house limit), centred at `at`."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=radius,
                          radius2=radius, depth=length)
    if axis == "x":
        bmesh.ops.rotate(bm, cent=(0, 0, 0), verts=bm.verts,
                         matrix=__import__("mathutils").Matrix.Rotation(
                             math.radians(90), 3, "Y"))
    elif axis == "y":
        bmesh.ops.rotate(bm, cent=(0, 0, 0), verts=bm.verts,
                         matrix=__import__("mathutils").Matrix.Rotation(
                             math.radians(90), 3, "X"))
    bmesh.ops.translate(bm, vec=at, verts=bm.verts)
    obj = common.shade_flat(common.mesh_from_bmesh(bm, tag))
    common.assign(obj, kit._material(mat))
    return roomcollision.paint_role(obj, "trim")


def _tilted(tag, size, at, degrees_x, mat):
    """A box turned about X: an edge strip that follows a slope."""
    import mathutils
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    bmesh.ops.rotate(bm, cent=(0, 0, 0), verts=bm.verts,
                     matrix=mathutils.Matrix.Rotation(math.radians(degrees_x),
                                                      3, "X"))
    bmesh.ops.translate(bm, vec=at, verts=bm.verts)
    obj = common.shade_flat(common.mesh_from_bmesh(bm, tag))
    common.assign(obj, kit._material(mat))
    return roomcollision.paint_role(obj, "trim")


def _wedge(tag, size, at, mat):
    obj = brushkit.wedge(tag, size, at, axis="y")
    common.assign(obj, kit._material(mat))
    return roomcollision.paint_role(obj, "trim")


def _hinge_spec(node, moving, pivot, axis, positions, as_built):
    return {"node": node, "moving": moving, "pivot": pivot, "axis": axis,
            "positions_degrees": positions, "as_built": as_built}


# --- ca_launch_cradle --------------------------------------------------------

def launch_cradle():
    b = kit._b
    structure = [
        b("frame_side_l", (0.20, 2.40, 0.12), (-1.10, 0.0, 0.06), "ca_steel",
          collide=True),
        b("frame_side_r", (0.20, 2.40, 0.12), (1.10, 0.0, 0.06), "ca_steel",
          collide=True),
        b("frame_front", (2.00, 0.20, 0.12), (0.0, 1.10, 0.06), "ca_steel",
          collide=True),
        # The rear housing: the accumulator the throw comes from.
        b("housing", (2.00, 0.30, 0.26), (0.0, -0.99, 0.13), "ca_steel",
          collide=True),
    ]
    decoration = [
        b("deck", (2.00, 1.84, 0.03), (0.0, 0.08, 0.015), "floor"),
        b("housing_cap", (1.20, 0.22, 0.10), (0.0, -0.99, 0.31), "ca_steel"),
        _cyl("drum_l", 0.10, 0.36, (-0.40, -0.99, 0.46), "x", "ca_steel"),
        _cyl("drum_r", 0.10, 0.36, (0.40, -0.99, 0.46), "x", "ca_steel"),
        # The tray's knuckle: a barrel across the back, the pin it kicks on.
        _cyl("knuckle", 0.04, 1.30, (0.0, -0.79, 0.06), "x", "ca_steel"),
        # The front lip, a low ramp the tray throws over.
        _wedge("lip", (1.40, 0.16, 0.10), (0.0, 0.94, 0.08), "ca_steel"),
        # The boom's post, and the power gland at the rear, pipe height.
        b("boom_post", (0.10, 0.10, 0.36), (-0.86, -0.62, 0.21), "ca_steel"),
        b("power_gland_body", (0.14, 0.06, 0.11),
          (0.0, -1.17, kit.PIPE_Z), "ca_steel"),
    ]
    for x in (-1.10, 1.10):
        for y in (-1.05, 1.05):
            decoration.append(b("bolt", (0.06, 0.06, 0.02), (x, y, 0.13)))
    tray = b("tray", TRAY, (0.0, 0.10, 0.055), "ca_tray")
    fins = {}
    for side, x in (("l", -0.86), ("r", 0.86)):
        # A stepped guide: low at the back, tall at the front, so it
        # points the way it throws even in grey. Blue on its top edge and
        # its inner face, which is what you see from the approach.
        # A wedge 0.80 m long rising to 0.82 m at the front: a fin that
        # points. The blade is the device's blue -- an "active fin", the
        # accent at height that carries the category to 20 m -- on a steel
        # foot, with a pale blue leading edge to give it form.
        low = b("fin_%s" % side, (0.05, 0.80, 0.08), (x, 0.50, 0.08),
                "ca_steel")
        high = _wedge("move_fin_%s_blade" % side, (0.05, 0.80, 0.70),
                      (x, 0.50, 0.47), "ca_move")
        rise = math.degrees(math.atan2(0.70, 0.80))
        tip = _tilted("move_fin_%s" % side, (0.065, 1.08, 0.045),
                      (x, 0.50, 0.49), rise, "ca_move_light")
        fins[side] = [low, high, tip]
    rails = [b("move_rail_%s" % s, (0.06, 2.00, 0.025), (x, 0.0, 0.1325),
               "ca_move_idle") for s, x in (("l", -1.10), ("r", 1.10))]
    boom = b("boom", (0.07, 0.07, 1.00), (-0.86, -0.62, 0.87), "ca_panel")
    boom_tip = b("boom_tip", (0.08, 0.08, 0.14), (-0.86, -0.62, 1.40),
                 "ca_dark")
    lens = b("power_lens", (0.16, 0.10, 0.012), (0.0, -0.99, 0.366),
             "ck_power")
    core = b("power_core", (0.04, 0.20, 0.012), (0.0, -1.03, 0.266),
             "ck_power")
    kit._tile(structure + decoration + [tray] + fins["l"] + fins["r"]
              + rails + [boom, boom_tip, lens, core])
    kit._planar_uv(tray, (-TRAY[0] / 2.0, 0.10 - TRAY[1] / 2.0), (0, 1))
    parts = ([tray] + fins["l"] + fins["r"] + rails + [boom, boom_tip, lens,
                                                       core])
    hinges = [
        # Kick: the tray's front rises about the knuckle as the pad fires.
        _hinge_spec("tray_hinge", [tray], (0.0, -0.74, 0.055), "x",
                    {"rest": 0.0, "fired": 24.0}, "rest"),
        # Guides: raised when the device is ready, folded flat outward
        # when it is not fed.
        # Folded INWARD, flat over the tray: inside the footprint, and an
        # unfed cradle looks shut.
        _hinge_spec("fin_hinge_l", fins["l"], (-0.86, 0.40, 0.04), "z",
                    {"raised": 0.0, "folded": -90.0}, "raised"),
        _hinge_spec("fin_hinge_r", fins["r"], (0.86, 0.40, 0.04), "z",
                    {"raised": 0.0, "folded": 90.0}, "raised"),
        # The boom: upright is clear; down across the tray is BLOCKED.
        _hinge_spec("boom_hinge", [boom, boom_tip], (-0.86, -0.62, 0.40), "z",
                    {"clear": 0.0, "blocked": -90.0}, "clear"),
    ]
    return structure, decoration, parts, hinges


CRADLE_STATES = {
    "unpowered": {"fin_hinge_l": -90.0, "fin_hinge_r": 90.0,
                  "boom_hinge": 0.0, "tray_hinge": 0.0,
                  "move_rail_*": "idle", "power_*": "idle"},
    "ready": {"fin_hinge_l": 0.0, "fin_hinge_r": 0.0, "boom_hinge": 0.0,
              "tray_hinge": 0.0, "move_rail_*": "live", "power_*": "live"},
    "blocked": {"fin_hinge_l": 0.0, "fin_hinge_r": 0.0,
                "boom_hinge": -90.0, "tray_hinge": 0.0,
                "move_rail_*": "idle", "power_*": "live"},
    "fired": {"tray_hinge": 24.0, "hold_seconds": 0.15,
              "then": "back to ready over 0.4 s",
              "when": "LaunchPad.fired -- only when a launch happened"},
    "reads_without_colour": "fins up and boom up = go; fins flat = no "
                            "feed; boom across the tray = held. The fins "
                            "and the tray rise toward the launch heading.",
}

# --- ca_breakable_brace -----------------------------------------------------

#: Slat z-centres (box frame, metres) and their face planes.
SLAT_Z = (-0.38, 0.0, 0.38)
SLAT = (1.26, 0.05, 0.34)
FACE_Y = 0.36             # inside the posts, so clamps fit the 0.9 m


def breakable_brace():
    b = kit._b
    body = [b("core", (1.20, 0.70, 1.24), (0.0, 0.0, 0.0), "ca_dark")]
    for x in (-0.69, 0.69):
        for y in (-0.39, 0.39):
            body.append(b("post", (0.12, 0.12, 1.40), (x, y, 0.0),
                          "ca_steel"))
    for x in (-0.45, 0.45):
        body.append(b("skid", (0.12, 0.90, 0.08), (x, 0.0, -0.66),
                      "ca_steel"))
    for y in (-0.42, 0.42):
        body.append(b("rail_low", (1.26, 0.06, 0.10), (0.0, y, -0.60),
                      "ca_steel"))
        body.append(b("rail_top", (1.26, 0.06, 0.10), (0.0, y, 0.60),
                      "ca_scored"))
    for x in (-0.72, 0.72):
        body.append(b("strap_end", (0.06, 0.66, 0.10), (x, 0.0, 0.60),
                      "ca_scored"))
        # And down the middle of each end, so the orange reads from the
        # side and on the way back past it.
        body.append(b("strap_end_v", (0.06, 0.12, 1.10), (x, 0.0, -0.02),
                      "ca_scored"))
    for x in (-0.33, 0.33):
        body.append(b("lid", (0.55, 0.70, 0.04), (x, 0.0, 0.66), "ca_panel"))
    parts = []
    hinges = []
    for face, sign in (("f", -1.0), ("b", 1.0)):
        y = sign * FACE_Y
        body.append(b("slat_%s_low" % face, SLAT, (0.0, y, SLAT_Z[0]),
                      "ca_panel"))
        for tag, z in (("mid", SLAT_Z[1]), ("top", SLAT_Z[2])):
            slat = b("slat_%s_%s" % (face, tag), SLAT, (0.0, y, z),
                     "ca_panel")
            parts.append(slat)
            # Hinged at the slat's bottom edge; a positive angle about
            # runtime +X leans the FRONT face (authoring -Y = Godot +Z)
            # outward, so the back face uses the negative.
            out = 1.0 if face == "f" else -1.0
            positions = {"intact": 0.0,
                         "dented": out * (18.0 if tag == "top" else 0.0),
                         "breaching": out * (75.0 if tag == "top" else 32.0)}
            hinges.append(_hinge_spec(
                "slat_hinge_%s_%s" % (face, tag), [slat],
                (0.0, y, z - SLAT[2] / 2.0 + 0.01), "x", positions, "intact"))
        # The break-away clamps at both joints, both posts, this face.
        for x in (-0.62, 0.62):
            for joint, z in (("low", -0.19), ("top", 0.19)):
                clamp = b("clamp_%s_%s_%s" % (face, joint,
                                              "l" if x < 0 else "r"),
                          (0.14, 0.06, 0.10),
                          (x, sign * 0.415, z), "ca_orange")
                parts.append(clamp)
    kit._tile(body + parts)
    return body, parts, hinges


def brace_wreck():
    b = kit._b
    body = []
    for x in (-0.45, 0.45):
        body.append(b("skid", (0.12, 0.90, 0.08), (x, 0.0, -0.66),
                      "ca_steel"))
    for y in (-0.42, 0.42):
        body.append(b("rail_low", (1.26, 0.06, 0.10), (0.0, y, -0.60),
                      "ca_steel"))
        body.append(b("slat_low", SLAT, (0.0, y * 0.96, SLAT_Z[0]),
                      "ca_panel"))
    for x in (-0.69, 0.69):
        for y in (-0.39, 0.39):
            body.append(b("post_stub", (0.12, 0.12, 0.46), (x, y, -0.47),
                          "ca_steel"))
    body.append(b("core_stub", (1.20, 0.70, 0.30), (0.0, 0.0, -0.55),
                  "ca_dark"))
    # A fallen panel and two sprung clamps on the floor in front.
    body.append(b("slat_fallen", (1.20, 0.34, 0.05), (0.05, -0.62, -0.675),
                  "ca_panel"))
    body.append(b("clamp_loose", (0.10, 0.07, 0.08), (-0.40, -0.66, -0.66),
                  "ca_orange"))
    body.append(b("clamp_loose", (0.10, 0.08, 0.07), (0.52, -0.58, -0.665),
                  "ca_orange"))
    kit._tile(body)
    return body


BRACE_STATES = {
    "drive": "from DestructibleCover.hp after each take_damage: "
             "hp > 26.7 intact; hp > 13.3 dented; hp > 0 breaching; "
             "0 or below: Production frees the cover as now, and places "
             "ca_breakable_brace_wreck at the same transform",
    "intact": {"slat_hinge_*": 0.0, "clamp_*": "visible"},
    "dented": {"slat_hinge_f_top": 18.0, "slat_hinge_b_top": -18.0,
               "clamp_*_top_*": "hidden"},
    "breaching": {"slat_hinge_f_top": 75.0, "slat_hinge_b_top": -75.0,
                  "slat_hinge_f_mid": 32.0, "slat_hinge_b_mid": -32.0,
                  "clamp_*": "hidden"},
    "reads_without_colour": "an open frame of panels with gaps onto a dark "
                            "core; damage leans panels out and drops them, "
                            "so a hit changes the silhouette",
}


# --- export -------------------------------------------------------------------

def _export(name, body, parts, hinges, collide, category):
    twins = roomcollision.build(list(collide), name) if collide else []
    joined = common.join(body, name)
    if parts:
        common.assert_parts_touch(joined, parts, name)
    out_parts = list(parts)
    for spec in hinges:
        empty = kit._hinge(spec["node"], spec["moving"], spec["pivot"])
        out_parts.insert(out_parts.index(spec["moving"][0]), empty)
    entry = common.export_glb(joined, "%s/%s.glb" % (OUT, name), category,
                              tier="architecture", texture_size=SIZE,
                              anchor="as-built", parts=out_parts,
                              collision=twins)
    entry["parts"] = [p.name for p in out_parts]
    entry["colliders"] = [t.name for t in twins]
    if hinges:
        entry["hinges"] = [kit._hinge_entry(s) for s in hinges]
    return entry


def build(name):
    common.reset_scene()
    kit._IMAGES.clear()
    kit._MATERIALS.clear()
    if name == "ca_launch_cradle":
        structure, decoration, parts, hinges = launch_cradle()
        entry = _export(name, structure + decoration, parts, hinges,
                        structure, "interactable")
        entry["fits"] = ("Production's LaunchPad (affordance_nodes.gd): the "
                         "whole device inside PAD_SIZE's 2.4 x 2.4 m plan; "
                         "walkable parts no taller than 0.13 m, the deck "
                         "and tray 0.08 m; housing and drums at the rear "
                         "only, under MAX_VERTICAL_STEP")
        entry["mount"] = ("child of the LaunchPad at local identity, then "
                          "yaw the PAD (or this node) so Godot -Z faces "
                          "the target in plan: look_at(Vector3(target.x, "
                          "pad.y, target.z)). Hide the pad's own BoxMesh "
                          "slab; keep its arc pips, which are the solved "
                          "trajectory and tell the truth")
        entry["collision"] = ("convex twins on the frame and the rear "
                              "housing only. The Area3D trigger is "
                              "Production's and unchanged. The tray, fins "
                              "and boom move and carry none")
        entry["states"] = CRADLE_STATES
        entry["power_exit"] = {"at_runtime": _to_runtime((0.0, -1.20,
                                                          kit.PIPE_Z)),
                               "note": "the gland's rear face, at the "
                                       "green raceway's pipe height; a ck "
                                       "raceway run butts straight into it"}
        entry["state_nodes"] = {"move_rail_*": {"idle": MOVE_IDLE,
                                                "live": MOVE},
                                "power_*": kit.POWER_STATE}
    elif name == "ca_breakable_brace":
        body, parts, hinges = breakable_brace()
        entry = _export(name, body, parts, hinges, (), "interactable")
        entry["fits"] = ("Production's DestructibleCover "
                         "(destructible_cover.gd): inside SIZE 1.5 x 1.4 x "
                         "0.9 m, origin at the box centre like its own mesh "
                         "and collider; HP 40")
        entry["mount"] = ("child of the DestructibleCover at identity; hide "
                          "its BoxMesh `_mesh` (and D's BreakBand strip). "
                          "Its BoxShape3D collider is unchanged")
        entry["collision"] = "none in the GLB: the cover's own SIZE box"
        entry["states"] = BRACE_STATES
    else:
        body = brace_wreck()
        entry = _export(name, body, [], [], (), "prop")
        entry["mount"] = ("at the broken cover's transform, origin at the "
                          "old box centre; no collision, nothing to shoot")
    return entry


ASSETS = ["ca_launch_cradle", "ca_breakable_brace", "ca_breakable_brace_wreck"]


def main():
    made = {}
    for name in ASSETS:
        entry = build(name)
        made[name] = entry
        print("[ca] %-26s %4d tris, %d part(s), %d collider(s)"
              % (name, entry["triangles"], len(entry.get("parts", [])),
                 len(entry.get("colliders", []))))
    shared = {
        "batch": "064", "kind": "crossing_affordances",
        "status": "CANDIDATE -- one movement device and one breakable for "
                  "review; not in the content pack; not integrated",
        "meanings": {"movement": MOVE, "movement_idle": MOVE_IDLE,
                     "destructible": ORANGE,
                     "power": {"idle": kit.MEANING["power_idle"],
                               "live": kit.MEANING["power_live"]},
                     "kit_local": "the Batch 063 hexes; no library colour "
                                  "changed"},
        "reuses": ["Batch 063 materials, hinges and power state",
                   "concrete_facility ramps from materials.py",
                   "brushkit wedges and 8-sided cylinders"],
        "texels_per_metre": kit.DENSITY,
    }
    path = os.path.join(common.MODEL_DIR, OUT, "manifest.json")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        json.dump({k: dict(shared, **v) for k, v in made.items()},
                  handle, indent=2, sort_keys=True)
    common.log("manifest %s" % path)


if __name__ == "__main__":
    main()
