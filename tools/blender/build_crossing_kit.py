#!/usr/bin/env python3
"""Batch 063 -- the combined Crossing's readability kit. PROPOSAL.

    .tools/blender/blender -b --python tools/blender/build_crossing_kit.py \
        [-- <review-models-dir>]

With a review directory, the builder also writes review-only variants there
(the lever OFF and ON, the power route unpowered and live). They are views,
not assets, and never land under `assets/`.

## What it is for

Small and generic: the pieces every room in the proposed Crossing D needs
to read, and nothing bespoke. A landmark, a room's dressing and its
lighting plan wait for the Crossing's own brief.

The owner's playtest of Wisp's prototypes found three faults:
* power lines that floated on diagonals;
* levers that floated and showed no physical change or visible connection;
* stair sides whose texture did not match the walls around them.

Wisp repaired all three in prototype code. This kit carries the lessons
into the art pipeline, where a check enforces each one:
* **Every moving part has a pivot.** Each throw is a hinge with declared
  positions (Batch 049's `_hinge`, reused unchanged), so a state is a
  physical position and not only a colour.
* **Every fixture meets a surface.** The lever has a foot with bolts. Each
  raceway sits on a carrier strip, is strapped by a saddle every 1.00 m,
  and turns a corner through a real elbow fitting. Nothing floats.
* **One axis per run.** A raceway piece is straight or a 90 degree corner.
  A diagonal cannot be built from these.
* **The house texture at the house density.** Theme textures from
  `materials.paint` at 32 texels/m, with `export_glb` checking every part.
  The stair fault was a trim tile stretched over a panel. Wisp's repaired
  stairs also reuse a wall texture from before the course ruling, so on a
  current baseline they would mismatch again.

## The meanings (owner, 2026-10-02: "Locked visual meanings")

    orange              destructible objects, including enemies
    blue                movement features
    green               electrical power
    yellow-and-black    hazards

The hexes are Wisp's `interaction_palette.gd`, the colours the owner played.
They are kit-local on purpose. `assets/art_palette.json` still says green is
Epsilon, orange is "this will hurt you" and yellow is the Check's send beam.
Reconciling those is the owner's decision and is flagged in the handoff. It
is not taken here, and no library colour changes.

A material that carries a meaning is never named for a theme role. In
Production a material named `hazard` is re-skinned by the theme binding to
the universal orange ramp, which would undo the yellow and black.

## Frames

Each piece is authored in its final frame, so `as-built` is the anchor.
* **The lever** stands on the floor, origin at the foot's centre. The
  player works it from authoring -Y, which is Godot +Z.
* **Raceway pieces** lie on a surface at local z = 0 with +Z out of it
  (Godot +Y). A run goes along +X. To mount one on a wall, turn Godot +Y
  to the wall's outward normal.
"""

from __future__ import annotations

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
import mathutils  # noqa: E402

import brushkit  # noqa: E402
import common  # noqa: E402
import materials  # noqa: E402
import paintkit  # noqa: E402
import palette as pal  # noqa: E402
import roomcollision  # noqa: E402
from build_connect import _hinge, _to_runtime  # noqa: E402  (Batch 049)

THEME = common.THEME
OUT = "batch063/crossing_kit"
DENSITY = materials.ARCH_DENSITY            # 32 texels per metre
SIZE = materials.ARCH_SIZE                  # 128 px canvases, as Batch 049
K = DENSITY / float(SIZE)                   # UV units per metre
REVIEW = None
if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 1:
    REVIEW = os.path.abspath(sys.argv[sys.argv.index("--") + 1])

#: Owner ruling 2026-10-02, at Wisp's hexes (`interaction_palette.gd`).
MEANING = {
    "power_live": "#55e078",
    "power_idle": "#347b46",
    "movement": "#3266ee",
    "destructible": "#f48a36",
    "hazard_light": "#f4cf46",
    "hazard_dark": "#20251f",
}
NEUTRAL = "#d1d5d2"          # Wisp's NEUTRAL: printed words, the grip
LABEL_PLATE = "#2a2f35"      # the label plate behind the words
#: Emission strength for the LIVE review variants. The shipped files carry
#: the idle colour and no emission: lighting a state is the runtime's job.
LIVE_STRENGTH = 0.8

# --- the lever: Production's CallLever footprint, standing on the floor ---
#: Production's lever base is 0.70 x 0.70 m and its throw 55 degrees
#: (`call_lever.gd`). Keeping the footprint keeps its collider, and keeping
#: the throw keeps what the owner already learned from Wisp's study.
THROW = 55.0
#: CROSSING D'S LEVER, VOLUME FOR VOLUME (repair, 2026-10-07).
#:
#: D's latching lever (`crossing_d_parts.gd`, `Lever` over Production's
#: `CallLever`) keeps its colliders on the code body, and it has to: the
#: interact ray takes the collider it hits and does not walk up to a parent
#: (`player.gd`, `_update_interact_target`). So the art takes D's volumes:
#: * the foot, 0.70 x 0.10 x 0.70;
#: * the pedestal, 0.46 x 0.825 x 0.46 from the floor;
#: * the head (`CallLever.BASE`), 0.70 x 0.35 x 0.70, from 0.825 to 1.175 m;
#: * the arm (`CallLever.ARM`), pivoting at the head's top centre;
#: * the pilot, 0.69 m up the pedestal's face.
#: The first cut (2026-10-02) had a 0.34 m deep head with the arm hung in
#: front of it. Under D's 0.70 m BASE collider that left 18 cm of invisible
#: lever in front of and behind the visible head, at chest height.
FOOT = (0.70, 0.70, 0.10)                # z 0 .. 0.10
PEDESTAL = (0.46, 0.46, 0.825)           # z 0 .. 0.825, through the foot, as D's
HEAD = (0.70, 0.70, 0.35)                # z 0.825 .. 1.175
PIVOT = (0.0, 0.0, 1.175)                # CallLever's arm origin
ARM = (0.12, 0.12, 0.84)                 # CallLever.ARM's 0.80, plus a 4 cm heel
PILOT_AT = (0.0, -0.256, 0.69)
#: 22 texels wide, so the two words land on whole texels; centred on the
#: height of D's own ON/OFF marks.
PLATE = (22 / DENSITY, 0.012, 6 / DENSITY)
PLATE_Z0 = 1.0 - 3 / DENSITY

# --- the raceway -----------------------------------------------------------
PIPE_Z = 0.065            # pipe centre above the surface it is mounted on
PIPE = 0.09               # square pipe section
CARRIER = (0.18, 0.02)    # carrier strip: width across, thickness
CORE = (0.04, 0.012)      # the state stripe on the pipe's outward face
SADDLE_PITCH = 1.00       # a strap every metre: Wisp's limit was 1.40
LEG = 0.50                # each corner leg, from the corner line

_IMAGES = {}
_MATERIALS = {}


# --- materials --------------------------------------------------------------

def _canvas(name):
    """The painted canvas behind one kit material."""
    if name in ("wall", "trim", "floor"):
        canvas, _ = materials.paint(THEME, name)
        return canvas
    if name == "ck_power":
        return paintkit.Canvas(SIZE, MEANING["power_idle"])
    if name == "ck_power_live":
        return paintkit.Canvas(SIZE, MEANING["power_live"])
    if name == "ck_neutral":
        return paintkit.Canvas(SIZE, NEUTRAL)
    if name == "ck_label":
        return _label_canvas()
    if name == "ck_movement":
        return _movement_canvas()
    if name == "ck_destructible":
        return _destructible_canvas()
    if name == "ck_hazard":
        canvas = paintkit.Canvas(SIZE, MEANING["hazard_dark"])
        # The library's own stripe painter at the library's own pitch
        # (`materials.py`: 0.1 m, three texels), in the ruled colours.
        paintkit.hazard_stripes(canvas, 0, 0, SIZE, SIZE,
                                MEANING["hazard_dark"],
                                MEANING["hazard_light"], pitch=3)
        return canvas
    raise KeyError(name)


def _label_canvas():
    """OFF and ON in the project's 3x5 stencil, on the label plate.

    The plate maps to the canvas's bottom six rows, 22 texels wide (see
    `_planar_uv`). Seen from the front, ON sits on the left and OFF on the
    right, under the side the arm rests on in each state: the convention
    Wisp's study taught the owner.
    """
    canvas = paintkit.Canvas(SIZE, LABEL_PLATE)
    top = SIZE - 6 + 0                    # the plate's top texel row

    def word(text, x, colour):
        for glyph in text:
            paintkit.stencil(canvas, None, x, top, paintkit.GLYPHS[glyph],
                             colour)
            x += 4

    word("ON", 2, MEANING["power_live"])
    word("OFF", 11, NEUTRAL)
    return canvas


def _movement_canvas():
    """Blue, with chevrons pointing along +U: the direction of travel.

    A strip maps to the canvas's bottom four rows (`_strip_uv`), so each
    chevron is drawn in those rows, two texels thick, every 0.25 m.
    """
    canvas = paintkit.Canvas(SIZE, MEANING["movement"])
    light = "#9db4f7"
    rows = [SIZE - 4, SIZE - 3, SIZE - 2, SIZE - 1]
    bend = [0, 1, 1, 0]
    for start in range(1, SIZE, 8):
        for row, shift in zip(rows, bend):
            canvas.set(start + shift, row, light)
            canvas.set(start + shift + 1, row, light)
    return canvas


def _destructible_canvas():
    """Orange, scored: staggered score marks every 0.125 m say "breaks here"
    without a second colour."""
    canvas = paintkit.Canvas(SIZE, MEANING["destructible"])
    dark = "#a8571c"
    for x in range(0, SIZE, 4):
        rows = (SIZE - 4, SIZE - 3) if (x // 4) % 2 == 0 \
            else (SIZE - 2, SIZE - 1)
        for row in rows:
            canvas.set(x, row, dark)
    return canvas


def _material(name):
    if name not in _MATERIALS:
        if name not in _IMAGES:
            _IMAGES[name] = _canvas(name).to_blender(
                "ck_%s_%s" % (THEME, name) if name in ("wall", "trim", "floor")
                else name)
        mat = common.make_textured_material(
            name, _IMAGES[name], roughness=pal.roughness(THEME))
        if name == "ck_power_live":
            _emit(mat, MEANING["power_live"], LIVE_STRENGTH)
        _MATERIALS[name] = mat
    return _MATERIALS[name]


def _emit(mat, hex_colour, strength):
    """Emission for a REVIEW variant. The hex is sRGB and Blender's socket
    is linear, so it is converted (FU-4 is exactly this trap)."""
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    rgb = [int(hex_colour[i:i + 2], 16) / 255.0 for i in (1, 3, 5)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
           for c in rgb]
    bsdf.inputs["Emission Color"].default_value = (lin[0], lin[1], lin[2],
                                                   1.0)
    bsdf.inputs["Emission Strength"].default_value = strength


def _b(tag, size, at, mat="trim", collide=False):
    """A brush block in a kit material. `collide` marks a structural part
    that gets a collider twin; everything else is decoration."""
    obj = brushkit.block(tag, size, at)
    common.assign(obj, _material(mat))
    return roomcollision.paint_role(obj, "wall" if collide else "trim")


# --- UVs --------------------------------------------------------------------

def _planar_uv(obj, origin, axes):
    """Map every loop from two world axes at the house density, so one
    texel is 1/32 m on both. For pieces whose texture is placed by hand
    (the label plate and the accent strips) rather than tiled by
    `uv_project_world`. `origin` is where texel (0, 0) of the canvas's
    BOTTOM-left lands: `Canvas.to_blender` flips rows, so the canvas's last
    row is v = 0."""
    mesh = obj.data
    if not mesh.uv_layers:
        mesh.uv_layers.new(name="UVMap")
    uv = mesh.uv_layers.active.data
    world = obj.matrix_world
    a, b = axes
    for poly in mesh.polygons:
        for loop in poly.loop_indices:
            co = world @ mesh.vertices[mesh.loops[loop].vertex_index].co
            uv[loop].uv = ((co[a] - origin[0]) * K, (co[b] - origin[1]) * K)


def _tile(objects):
    for obj in objects:
        common.uv_project_world(obj, DENSITY, SIZE)


# --- the pieces ---------------------------------------------------------------

def floor_lever():
    """`ck_floor_lever` -- a permanent lever that stands on the floor.

    Returns (structure, decoration, parts, hinges). The structure (foot,
    pedestal, head) gets collider twins that equal Crossing D's code
    colliders. The arm rises from a bearing on the head's top centre and
    throws left (ON) or right (OFF), over a label plate on the head's face.
    The pilot turns from a flat bar (OFF) to an upright one (ON) as it
    lights. Both read with the colour removed.
    """
    fx, fy, fz = FOOT
    px, py, pz = PEDESTAL
    hx, hy, hz = HEAD
    structure = [
        _b("lever_foot", FOOT, (0.0, 0.0, fz / 2.0), "trim", collide=True),
        _b("lever_pedestal", PEDESTAL, (0.0, 0.0, pz / 2.0), "wall",
           collide=True),
        _b("lever_head", HEAD, (0.0, 0.0, pz + hz / 2.0), "trim",
           collide=True),
    ]
    decoration = []
    for x in (-0.27, 0.27):
        for y in (-0.27, 0.27):
            decoration.append(_b("lever_bolt", (0.06, 0.06, 0.03),
                                 (x, y, fz + 0.015)))
    # The power exit, at the rear and at raceway height: the line starts
    # where the lever stands, rather than somewhere near it.
    decoration.append(_b("lever_gland", (0.14, 0.13, 0.11),
                         (0.0, py / 2.0 + 0.065, PIPE_Z)))
    # The bearing the arm turns on: an axle boss across the head's top
    # centre, half sunk into it.
    decoration.append(_b("lever_bearing", (0.14, 0.30, 0.14), PIVOT))
    plate = _b("lever_label", PLATE,
               (0.0, -hy / 2.0 - PLATE[1] / 2.0, PLATE_Z0 + PLATE[2] / 2.0),
               "ck_label")
    decoration.append(plate)
    decoration.append(_b("pilot_bezel", (0.20, 0.02, 0.20),
                         (0.0, -py / 2.0 - 0.01, PILOT_AT[2])))
    ax, ay, az = ARM
    arm = _b("lever_arm", ARM, (0.0, 0.0, PIVOT[2] - 0.04 + az / 2.0))
    grip = _b("lever_grip", (0.26, 0.18, 0.15),
              (0.0, 0.0, PIVOT[2] + 0.80 - 0.04), "ck_neutral")
    pilot = _b("pilot_bar", (0.14, 0.012, 0.04), PILOT_AT, "ck_power")
    _tile(structure + decoration + [arm, grip, pilot])
    _planar_uv(plate, (-PLATE[0] / 2.0, PLATE_Z0), (0, 2))
    hinges = [
        {"node": "lever_hinge", "moving": [arm, grip], "pivot": PIVOT,
         # Godot +Z faces the player. +55 about it carries the arm's top
         # to the player's LEFT, which is ON (the label's left word), the
         # same sign and side as D's `Lever` (OFF_DEGREES -55, ON +55).
         "axis": "z", "positions_degrees": {"off": -THROW, "upright": 0.0,
                                            "on": THROW},
         "as_built": "upright"},
        {"node": "pilot_hinge", "moving": [pilot], "pivot": PILOT_AT,
         "axis": "z", "positions_degrees": {"off": 0.0, "on": 90.0},
         "as_built": "off"},
    ]
    return structure, decoration, [arm, grip, pilot], hinges


def _run_blocks(prefix, start, end, along="x"):
    """One straight leg's carrier, pipe and state core, from `start` to
    `end` along x on the z = 0 surface, or along z on the x = 0 surface.
    Returns (body blocks, core block)."""
    span = end - start
    mid = (start + end) / 2.0
    cw, ct = CARRIER
    lift = PIPE_Z + PIPE / 2.0 + CORE[1] / 2.0
    if along == "x":
        blocks = [_b(prefix + "_carrier", (span, cw, ct), (mid, 0.0, ct / 2.0)),
                  _b(prefix + "_pipe", (span, PIPE, PIPE), (mid, 0.0, PIPE_Z))]
        core = _b(prefix + "_core", (span, CORE[0], CORE[1]),
                  (mid, 0.0, lift), "ck_power")
    else:
        blocks = [_b(prefix + "_carrier", (ct, cw, span), (ct / 2.0, 0.0, mid)),
                  _b(prefix + "_pipe", (PIPE, PIPE, span), (PIPE_Z, 0.0, mid))]
        core = _b(prefix + "_core", (CORE[1], CORE[0], span),
                  (lift, 0.0, mid), "ck_power")
    return blocks, core


def _saddle(tag, at, along="x"):
    """A strap over the pipe, wider than the carrier so it reads as the
    thing holding the run to the surface."""
    if along == "x":
        return _b(tag, (0.06, 0.22, 0.105), (at, 0.0, 0.0525 + 0.02))
    return _b(tag, (0.105, 0.22, 0.06), (0.0525 + 0.02, 0.0, at))


def _coupling(tag, at, along="x"):
    if along == "x":
        return _b(tag, (0.03, 0.12, 0.12), (at, 0.0, PIPE_Z))
    return _b(tag, (0.12, 0.12, 0.03), (PIPE_Z, 0.0, at))


def raceway_run():
    """`ck_raceway_run` -- 1.00 m straight, on any surface.

    Centred on its length, so runs tile end to end: the couplings meet at
    every joint and a saddle straps the middle, one strap per metre.
    """
    blocks, core = _run_blocks("run", -0.5, 0.5)
    blocks.append(_saddle("run_saddle", 0.0))
    for tag, x in (("run_coupling_a", -0.485), ("run_coupling_b", 0.485)):
        blocks.append(_coupling(tag, x))
    core.name = "power_core"
    _tile(blocks + [core])
    return blocks, [core]


def _elbow():
    s = PIPE + 0.04
    return _b("elbow", (s, PIPE + 0.04, s), (PIPE_Z, 0.0, PIPE_Z))


def raceway_inside():
    """`ck_raceway_inside` -- a concave 90 degree corner (floor to wall,
    or wall to wall).

    Authored about the corner line itself: one leg along +X on the z = 0
    surface, one up +Z on the x = 0 surface, which faces +X. It drops into
    any inside corner without an offset. The elbow covers the corner, so
    both legs start at the pipe's own centre line.
    """
    a, core_a = _run_blocks("leg_a", PIPE_Z, LEG, "x")
    b, core_b = _run_blocks("leg_b", PIPE_Z, LEG, "z")
    blocks = a + b + [
        _elbow(),
        _saddle("saddle_a", 0.33, "x"), _saddle("saddle_b", 0.33, "z"),
        _coupling("coupling_a", LEG - 0.015, "x"),
        _coupling("coupling_b", LEG - 0.015, "z"),
    ]
    core_a.name, core_b.name = "power_core_a", "power_core_b"
    _tile(blocks + [core_a, core_b])
    return blocks, [core_a, core_b]


def raceway_outside():
    """`ck_raceway_outside` -- a convex 90 degree corner, over an edge.

    The solid is the quadrant x < 0, z < 0: one leg lies on its top face
    (z = 0) running in from -X, and one runs down its side face (x = 0),
    which faces +X. The elbow stands proud of the edge, as a real fitting
    would.
    """
    a, core_a = _run_blocks("leg_a", -LEG, 0.0, "x")
    b, core_b = _run_blocks("leg_b", -LEG, 0.0, "z")
    blocks = a + b + [
        _elbow(),
        _saddle("saddle_a", -0.33, "x"), _saddle("saddle_b", -0.33, "z"),
        _coupling("coupling_a", -LEG + 0.015, "x"),
        _coupling("coupling_b", -LEG + 0.015, "z"),
    ]
    core_a.name, core_b.name = "power_core_a", "power_core_b"
    _tile(blocks + [core_a, core_b])
    return blocks, [core_a, core_b]


def raceway_turn():
    """`ck_raceway_turn` -- a 90 degree turn on ONE surface.

    The corner that climbs a wall and then runs along it, or that turns
    a floor run. Legs along +X and +Y on the z = 0 surface, meeting at an
    elbow over the origin. The playtest's diagonals were this corner,
    left out.
    """
    a, core_a = _run_blocks("leg_a", PIPE_Z, LEG, "x")
    b, core_b = _run_blocks("leg_b", PIPE_Z, LEG, "x")
    # Leg B is leg A turned a quarter about the surface normal.
    turn = mathutils.Matrix.Rotation(math.radians(90.0), 4, "Z")
    for obj in b + [core_b]:
        obj.data.transform(turn)
    saddle_b = _saddle("saddle_b", 0.33, "x")
    coupling_b = _coupling("coupling_b", LEG - 0.015, "x")
    for obj in (saddle_b, coupling_b):
        obj.data.transform(turn)
    elbow = _b("elbow", (PIPE + 0.04, PIPE + 0.04, PIPE + 0.04),
               (0.0, 0.0, PIPE_Z))
    blocks = a + b + [elbow, _saddle("saddle_a", 0.33, "x"), saddle_b,
                      _coupling("coupling_a", LEG - 0.015, "x"), coupling_b]
    core_a.name, core_b.name = "power_core_a", "power_core_b"
    _tile(blocks + [core_a, core_b])
    return blocks, [core_a, core_b]


def raceway_terminal():
    """`ck_raceway_terminal` -- where a run ends at the thing it powers.

    A small box on the surface with a gland on its -X side at pipe height,
    so a run along -X enters it. `power_lens` on its face is the
    destination's own state, the badge on a door or a bridge.
    """
    blocks = [
        _b("terminal_box", (0.36, 0.26, 0.16), (0.0, 0.0, 0.08), "wall"),
        _b("terminal_lid", (0.30, 0.20, 0.02), (0.0, 0.0, 0.17)),
        _b("terminal_gland", (0.06, 0.12, 0.12), (-0.21, 0.0, PIPE_Z)),
    ]
    lens = _b("power_lens", (0.12, 0.12, 0.012), (0.05, 0.0, 0.186),
              "ck_power")
    _tile(blocks + [lens])
    return blocks, [lens]


def accent_strip(meaning):
    """`ck_accent_<meaning>` -- a 1.00 x 0.125 m bolt-on strip, flush.

    For the edge of a launch pad, the lip of a rail or a ledge, the band
    round a breakable. 0.125 m is four texels, so the pattern registers
    with the strip exactly (`_planar_uv`). It is deliberately an accent,
    not a recolour of the thing it marks.
    """
    width, thick = 4 / DENSITY, 0.015
    strip = _b("accent_" + meaning, (1.0, width, thick),
               (0.5, width / 2.0, thick / 2.0), "ck_" + meaning)
    _planar_uv(strip, (0.0, 0.0), (0, 1))
    # Centre it on its length, after the UVs are fixed to the pattern.
    strip.data.transform(mathutils.Matrix.Translation((-0.5, -width / 2.0,
                                                       0.0)))
    return [strip], []


# --- export -------------------------------------------------------------------

def _hinge_entry(spec):
    return {
        "node": spec["node"],
        "carries": [p.name for p in spec["moving"]],
        "pivot_runtime": _to_runtime(spec["pivot"]),
        "axis": spec["axis"],
        "positions_degrees": spec["positions_degrees"],
        "as_built": spec["as_built"],
        "drive": "rotate the `%s` node about its own local %s axis to a "
                 "declared angle; it is an empty at the pin and carries its "
                 "parts at identity. Positive follows the right-hand rule "
                 "about the runtime axis." % (spec["node"],
                                              spec["axis"].upper()),
    }


def _export(name, body_objs, parts, hinges=(), collide=()):
    """Join, hinge, export through `common.export_glb`. Returns the
    manifest entry."""
    twins = roomcollision.build(list(collide), name) if collide else []
    body = common.join(body_objs, name)
    common.assert_parts_touch(body, parts, name)
    out_parts = list(parts)
    for spec in hinges:
        empty = _hinge(spec["node"], spec["moving"], spec["pivot"])
        first = out_parts.index(spec["moving"][0])
        out_parts.insert(first, empty)
    entry = common.export_glb(body, "%s/%s.glb" % (OUT, name), "prop",
                              tier="architecture", texture_size=SIZE,
                              anchor="as-built", parts=out_parts,
                              collision=twins)
    entry["parts"] = [p.name for p in out_parts]
    entry["colliders"] = [t.name for t in twins]
    if hinges:
        entry["hinges"] = [_hinge_entry(s) for s in hinges]
    return entry, body, out_parts


ASSETS = ["ck_floor_lever", "ck_raceway_run", "ck_raceway_inside",
          "ck_raceway_outside", "ck_raceway_turn", "ck_raceway_terminal",
          "ck_accent_movement",
          "ck_accent_destructible", "ck_accent_hazard"]

MOUNT_SURFACE = ("authored lying on a surface at local Godot y = 0, with +Y "
                 "out of the surface. Floor: as built. Wall or ceiling: turn "
                 "+Y to the surface's outward normal.")
RACEWAY_COLLISION = ("none. Proud of its surface by at most 0.13 m (0.19 m "
                     "at a terminal); presentation, as Batch 043 rules "
                     "conduits. Keep floor runs along wall bases. A run that "
                     "must cross a walking line gets a code-side box no taller "
                     "than the run, inside the 1.0 m step and the enemies' "
                     "0.6 m footing.")
POWER_STATE = {"node_prefix": "power_", "idle": MEANING["power_idle"],
               "live": MEANING["power_live"],
               "how": "as built the state nodes carry the idle colour. Live: "
                      "set their albedo to `live` and emit it. Unpowered "
                      "stays dark green, so an off line still reads as a "
                      "power line."}


def build_asset(name):
    """Build one asset in a fresh scene. Returns (entry, body, parts)."""
    common.reset_scene()
    _IMAGES.clear()
    _MATERIALS.clear()
    if name == "ck_floor_lever":
        structure, decoration, parts, hinges = floor_lever()
        entry, body, out = _export(name, structure + decoration, parts,
                                   hinges, collide=structure)
        entry["mount"] = ("floor; origin at the foot's centre. The player "
                          "works it from Godot +Z. Crossing D's Lever, volume "
                          "for volume: under a D `Lever` node, whose origin "
                          "stands 1.0 m above its floor, place this at local "
                          "(0, -1, 0).")
        entry["states"] = {
            "off": {"lever_hinge": -THROW, "pilot_hinge": 0.0,
                    "pilot_bar": "idle"},
            "on": {"lever_hinge": THROW, "pilot_hinge": 90.0,
                   "pilot_bar": "live"},
            "reads_without_colour": "the arm rests left (ON) or right (OFF) "
                                    "seen from the front, under the "
                                    "stencilled word; the pilot is a "
                                    "horizontal bar OFF and a vertical one "
                                    "ON",
        }
        entry["power_state"] = POWER_STATE
        entry["collision"] = ("convex twins on the foot, pedestal and head "
                              "(`-convcolonly`), each equal to Crossing D's "
                              "code collider (Foot, Pedestal, CallLever.BASE). "
                              "Under a D Lever, free the GLB's StaticBody3D "
                              "nodes: the interact ray takes the collider it "
                              "hits and does not walk up to a parent, so only "
                              "the code body may answer it. The arm, grip and "
                              "pilot move and carry none.")
        entry["power_exit"] = {
            "at_runtime": _to_runtime((0.0, PEDESTAL[1] / 2.0 + 0.13,
                                       PIPE_Z)),
            "note": "a floor run leaves the gland's rear face here, along "
                    "Godot -Z, at the raceway's own pipe height"}
        return entry, body, out
    if name.startswith("ck_raceway_"):
        blocks, parts = {"ck_raceway_run": raceway_run,
                         "ck_raceway_inside": raceway_inside,
                         "ck_raceway_outside": raceway_outside,
                         "ck_raceway_turn": raceway_turn,
                         "ck_raceway_terminal": raceway_terminal}[name]()
        entry, body, out = _export(name, blocks, parts)
        entry["mount"] = MOUNT_SURFACE
        entry["pipe_centre_above_surface_m"] = PIPE_Z
        entry["supports"] = "a saddle every %.2f m and a coupling at each " \
                            "joint" % SADDLE_PITCH
        entry["collision"] = RACEWAY_COLLISION
        entry["power_state"] = POWER_STATE
        return entry, body, out
    meaning = name[len("ck_accent_"):]
    blocks, parts = accent_strip(meaning)
    entry, body, out = _export(name, blocks, parts)
    entry["mount"] = MOUNT_SURFACE + " Flush trim: 0.015 m."
    entry["meaning"] = {"movement": "movement features",
                        "destructible": "destructible objects, including "
                                        "enemies",
                        "hazard": "hazards"}[meaning]
    entry["collision"] = "none; flush trim"
    return entry, body, out


def save_swatches():
    """The meaning textures as files too, for code-built meshes in
    Production that cannot take a .glb strip."""
    common.reset_scene()
    _IMAGES.clear()
    _MATERIALS.clear()
    out = {}
    for name in ("ck_power", "ck_power_live", "ck_movement",
                 "ck_destructible", "ck_hazard"):
        image = _canvas(name).to_blender(name + "_png")
        out[name] = common.save_texture(image, "batch063/%s.png" % name)
    return out


def main():
    made = {}
    for name in ASSETS:
        entry, _, _ = build_asset(name)
        made[name] = entry
        print("[kit] %-24s %4d tris, %d part(s), %d collider(s)"
              % (name, entry["triangles"], len(entry["parts"]),
                 len(entry["colliders"])))
    textures = save_swatches()
    shared = {
        "batch": "063", "kind": "crossing_readability_kit",
        "status": "PROPOSAL -- for the combined Crossing; review pending; "
                  "not in the content pack; not integrated",
        "meanings": {"ruling": "owner, 2026-10-02 (Locked visual meanings)",
                     "colours": MEANING,
                     "kit_local": "assets/art_palette.json is unchanged; "
                                  "reconciling it is the owner's decision"},
        "reuses": ["Batch 049 `_hinge` and runtime frame",
                   "concrete_facility wall and trim from materials.paint",
                   "the 3x5 stencil alphabet",
                   "paintkit.hazard_stripes at the library's 0.1 m pitch",
                   "roomcollision convex twins"],
        "texels_per_metre": DENSITY,
        "textures": textures,
        "not_changed": ["any approved asset", "any library colour",
                        "the content pack", "Production"],
    }
    path = os.path.join(common.MODEL_DIR, OUT, "manifest.json")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        json.dump({k: dict(shared, **v) for k, v in made.items()},
                  handle, indent=2, sort_keys=True)
    common.log("manifest %s" % path)
    if REVIEW:
        import crossing_kit_review  # noqa: E402  (review-only views)
        crossing_kit_review.write(REVIEW, sys.modules[__name__])


if __name__ == "__main__":
    main()
