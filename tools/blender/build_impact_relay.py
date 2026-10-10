"""Batch 065 -- the Impact Relay G1 kit: object launcher and impact seal.
CANDIDATE (Arty, 2026-10-08).

    .tools/blender/blender -b --python tools/blender/build_impact_relay.py

For the room the owner chose (Dess's D-18, Concept A) on the mechanism
Prod proved in G0 (`review/impact-lab-g0`, `impact_lab_parts.gd`):

* `ir_object_launcher` -- the look for `ObjectPlate`: a powered floor
  plate that throws a resting object along one solved arc. Prod's
  collider is a 2.0 x 0.25 x 2.0 m box; this drawn device keeps that box
  exactly (the deck's top is at 0.25 m) and adds what Dess's brief asks
  round it, inside 2.4 x 2.4 m: side lips with blue emitter rails, a
  rising front lip and two blue fins on the throw heading, and a rear
  accumulator housing where the green raceway arrives. Three blue
  chevrons on the deck are separate nodes, so the arming ramp can fill
  them one by one toward the front: a timer the player can read.
* `ir_impact_seal` -- the look for `ImpactShutter` (3.0 x 3.0 x 0.4 m,
  rated: 1,000 J breaks it, the Pulse is refused). Six armour slabs, each
  its own node with its origin at its centre and its own orange seam
  collars, over a dark core: the seams are where it gives, the slabs are
  what falls. Three scuff marks for glances.
* `ir_seal_jamb` -- the frame round the doorway, on the hall face. A
  separate asset, so it stays when the seal is gone: an empty frame is
  the destroyed state you can read from across the hall.
* `ir_teaching_tote` and `ir_relay_weight` (added 2026-10-08, owner: the
  lesson depends on the 4 kg tote and the 36 kg weight "looking materially
  different") -- the looks for Prod's two `ManipulableBody`s in
  `impact_relay_room.gd` (G1, a3b59c46). Each fills its tested box exactly
  (0.50 x 0.36 x 0.50 and 0.45 x 0.60 x 0.45 m) with the origin at the box
  centre, where `ManipulableBody.create` puts its `BoxShape3D`; neither
  ships a collider, so mass, size and physics are untouched. The library
  had nothing to reuse at these sizes (see `_LIBRARY_CHECK`), so they are
  minimal new props in Batch 043's family rule: bare dark metal only where
  a hand takes hold.

The look borrows the grammar the owner liked in the green kit: neutral
construction, colour on the parts that act. The blue modules are
fabricated pieces bolted onto station steel by neutral brackets, a cue
for "Epsilon adapted this" -- a promising direction, not lore.

Frames: authored Z-up, exported Y-up. The launcher's throw heading is
authoring +Y = Godot -Z, the same yaw `ObjectPlate.build` gives its own
deck. The seal's hall face is authoring -Y = Godot +Z, `ImpactShutter`'s
`normal` (Vector3.BACK) in the lab. Reuses Batch 063 and 064's builders.
"""

from __future__ import annotations

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402,F401

import brushkit  # noqa: E402
import roomcollision  # noqa: E402

import build_crossing_affordances as ca  # noqa: E402
import common  # noqa: E402
import materials  # noqa: E402
import paintkit  # noqa: E402
from build_connect import _to_runtime  # noqa: E402

kit = ca.kit
OUT = "batch065/impact_relay"
ca.OUT = OUT
kit.OUT = OUT
SIZE = kit.SIZE

#: Production's contracts, read on review/impact-lab-g0 (3337769d).
PLATE = (2.0, 2.0, 0.25)          # ObjectPlate.SIZE: x, z(depth), y
SHUTTER = (3.0, 0.4, 3.0)         # ImpactShutter.size: x, z(depth), y
DEVICE = 2.4                      # D-18: the cradle's 2.4 m tray
IR_MOVE_IDLE = "#1b2d66"

#: Production's two bodies, read on review/impact-relay-g1 (a3b59c46,
#: impact_relay_room.gd): x, z(depth), y -- the BoxShape3D
#: `ManipulableBody.create` derives, centred on the body's origin.
TOTE = (0.50, 0.50, 0.36)         # CRATE_SIZE, 4 kg, LIGHT
WEIGHT = (0.45, 0.45, 0.60)       # WEIGHT_SIZE, 36 kg, MEDIUM
#: Batch 043's family colours, reused rather than restated differently:
#: `HANDLING` is where a hand takes hold; `LIGHTENED_REST` is the panel a
#: runtime lights for `lightened`. (build_physics_props.py, by value: that
#: module cannot be imported here without building its family.)
HANDLING = "#191d23"
LIGHTENED_REST = "#4a5058"
TOTE_PLASTIC = "#d8ccb0"          # satin ivory: warm, no gameplay hue
TOTE_RIM = "#e6ddc8"              # the rolled rim, a shade lighter
#: v1's plastic, kept for the record: "#c9ccc4", a pale cold grey the
#: owner read as a developer placeholder (2026-10-08).
WEIGHT_CAST = "#43474d"           # dark cast steel
WEIGHT_MACHINED = "#8a8f95"       # the bright worn edges of a heavy thing

_PREVIOUS = kit._canvas


def _canvas(name):
    base, accent, trim = materials._ramps(kit.THEME)
    surface = materials.surface_for("trim", kit.THEME)
    if name == "ir_deck":
        # Dark steel with a pale front edge band (the edge things leave by).
        canvas = paintkit.Canvas(SIZE, trim[0])
        paintkit.tonal_drift(canvas, surface, amount=0.04, cell_metres=1.0)
        return canvas
    if name == "ir_move_idle":
        # The launcher's unlit emitter: dark navy, so COCKED (lit) is a
        # change you see from the lever. Batch 064's idle stays as it was.
        return paintkit.Canvas(SIZE, IR_MOVE_IDLE)
    if name == "ir_armour":
        # Battered armour plate: mid steel, a rivet row every 0.25 m.
        canvas = paintkit.Canvas(SIZE, base[1])
        paintkit.tonal_drift(canvas, surface, amount=0.06, cell_metres=0.8)
        paintkit.broad_patches(canvas, surface, [base[0]], cell_metres=0.6,
                               density=0.2, strength=0.18)
        for y in range(4, SIZE, 8):
            for x in range(4, SIZE, 8):
                canvas.set(x, y, trim[0])
        return canvas
    if name == "ir_tote":
        # Moulded satin plastic: warm ivory, a soft flow mottle so it is
        # not one flat value, nothing like the station's painted steel.
        canvas = paintkit.Canvas(SIZE, TOTE_PLASTIC)
        paintkit.tonal_drift(canvas, surface, amount=0.035, cell_metres=0.6)
        paintkit.broad_patches(canvas, surface, [TOTE_RIM], cell_metres=0.5,
                               density=0.25, strength=0.08)
        return canvas
    if name == "ir_tote_rim":
        canvas = paintkit.Canvas(SIZE, TOTE_RIM)
        paintkit.tonal_drift(canvas, surface, amount=0.02, cell_metres=0.8)
        return canvas
    if name == "ir_cast":
        # Cast steel: dark, heavy, a slow mottle -- nothing painted on it.
        canvas = paintkit.Canvas(SIZE, WEIGHT_CAST)
        paintkit.tonal_drift(canvas, surface, amount=0.05, cell_metres=0.5)
        return canvas
    if name == "ir_machined":
        return paintkit.Canvas(SIZE, WEIGHT_MACHINED)
    if name == "ir_grip":
        return paintkit.Canvas(SIZE, HANDLING)
    if name == "ir_lightened":
        return paintkit.Canvas(SIZE, LIGHTENED_REST)
    return _PREVIOUS(name)


kit._canvas = _canvas
b = kit._b


# --- ir_object_launcher -------------------------------------------------------

def launcher():
    # Inside Prod's 2.0 x 0.25 x 2.0 box: a plinth, and the deck on top.
    structure = [
        b("lip_l", (0.20, 2.40, 0.40), (-1.10, 0.0, 0.20), "ca_steel",
          collide=True),
        b("lip_r", (0.20, 2.40, 0.40), (1.10, 0.0, 0.20), "ca_steel",
          collide=True),
        b("housing", (2.40, 0.22, 0.55), (0.0, -1.09, 0.275), "ca_steel",
          collide=True),
    ]
    decoration = [
        b("plinth", (2.0, 2.0, 0.17), (0.0, 0.0, 0.085), "ca_steel"),
        b("housing_cap", (1.60, 0.18, 0.08), (0.0, -1.09, 0.59), "ca_steel"),
        ca._cyl("drum_l", 0.11, 0.50, (-0.55, -1.09, 0.74), "x", "ca_steel"),
        ca._cyl("drum_r", 0.11, 0.50, (0.55, -1.09, 0.74), "x", "ca_steel"),
        ca._cyl("knuckle", 0.045, 1.90, (0.0, -0.96, 0.20), "x", "ca_steel"),
        # The front lip, a ramp rising along the throw.
        ca._wedge("lip_front", (2.00, 0.20, 0.36), (0.0, 1.10, 0.18),
                  "ca_steel"),
        # The power inlet, west end of the housing's rear face, at the
        # raceway's pipe height.
        b("power_gland_body", (0.14, 0.06, 0.11), (-0.90, -1.23, kit.PIPE_Z),
          "ca_steel"),
    ]
    # Neutral brackets: what bolts the fabricated blue modules to steel.
    for x in (-1.10, 1.10):
        for y in (-0.80, 0.0, 0.80):
            decoration.append(b("bracket", (0.24, 0.08, 0.04),
                                (x, y, 0.40), "ca_steel"))
    deck = b("deck", (1.92, 1.92, 0.08), (0.0, 0.0, 0.21), "ir_deck")
    chevrons = []
    # Three chevrons, apex toward the throw, 0.6 m apart so each reads as
    # an arrow on its own.
    for k, y in enumerate((-0.62, -0.02, 0.58)):
        arms = []
        for sx in (-1, 1):
            # Rotated about the arm's own centre (brushkit's rotation_z),
            # not the object origin, which brushkit leaves at the world's.
            arm = brushkit.block("arm", (0.66, 0.12, 0.012),
                                 (sx * 0.27, y - 0.10, 0.256),
                                 rotation_z=-sx * 32.0)
            common.assign(arm, kit._material("ir_move_idle"))
            arms.append(roomcollision.paint_role(arm, "trim"))
        chevrons.append(common.join(arms, "move_chevron_%d" % (k + 1)))
    rails = [b("move_rail_%s" % s, (0.07, 2.00, 0.03), (x, 0.05, 0.415),
               "ir_move_idle") for s, x in (("l", -1.10), ("r", 1.10))]
    # The same emitters seen from the side and from behind: a strip down
    # each lip's outer face, and a band round each accumulator drum.
    rails += [b("move_rail_%s_side" % s, (0.03, 2.00, 0.12),
                (x, 0.05, 0.30), "ir_move_idle")
              for s, x in (("l", -1.215), ("r", 1.215))]
    rails += [ca._cyl("move_rail_drum_%s" % s, 0.118, 0.12,
                      (x, -1.09, 0.74), "x", "ir_move_idle")
              for s, x in (("l", -0.55), ("r", 0.55))]
    fins = []
    for s, x in (("l", -1.10), ("r", 1.10)):
        fins.append(ca._wedge("move_fin_%s" % s, (0.06, 0.70, 0.50),
                              (x, 0.85, 0.65), "ca_move"))
    edge = ca._tilted("move_lip", (1.90, 0.24, 0.03), (0.0, 1.10, 0.37),
                      math.degrees(math.atan2(0.36, 0.20)) - 90.0 + 90.0,
                      "ca_move_light")
    lens = b("power_lens", (0.18, 0.10, 0.012), (-0.40, -1.09, 0.636),
             "ck_power")
    core = b("power_core", (0.04, 0.16, 0.012), (-0.90, -1.12, 0.556),
             "ck_power")
    kit._tile(structure + decoration + [deck] + chevrons + rails + fins
              + [edge, lens, core])
    parts = [deck] + chevrons + rails + [lens, core]
    body_extra = fins + [edge]
    hinges = [ca._hinge_spec("deck_hinge", [deck] + chevrons,
                             (0.0, -0.95, 0.21), "x",
                             {"rest": 0.0, "kick": 10.0}, "rest")]
    return structure, decoration + body_extra, parts, hinges


LAUNCHER_STATES = {
    "names": "Prod's ObjectPlate states, with D-18 v1's names beside them; "
             "D-18 v2 (21cc00a4) adopts Prod's states and timings",
    "dark":     {"prod": "unpowered", "dess": "DARK",
                 "move_rail_*": "idle", "move_chevron_*": "idle",
                 "power_*": "idle", "deck_hinge": 0.0},
    "cocked":   {"prod": "powered idle", "dess": "COCKED",
                 "move_rail_*": "live, steady", "move_chevron_*": "idle",
                 "power_*": "live", "deck_hinge": 0.0},
    "arming":   {"prod": "arming (0.6 s ramp)", "dess": "WIND-UP (v1; v2 takes Prod's 0.6 s arming)",
                 "move_chevron_1..3": "light one by one, back to front, "
                                      "as the ramp passes 1/3, 2/3, 3/3",
                 "move_rail_*": "pulse, faster as it fills",
                 "power_*": "live"},
    "fired":    {"prod": "throw flash", "dess": "FIRED",
                 "deck_hinge": "kick to 10 deg in 0.06 s, back in 0.25 s, "
                               "on ObjectPlate.fired only",
                 "move_*": "flash to live x2.5 for 0.12 s"},
    "rearm":    {"prod": "REARM_SECONDS (1.0)", "dess": "RE-ARM (v1 said 2 s; v2 takes Prod's 1.0 s)",
                 "move_chevron_*": "fade to idle"},
    "dud":      {"prod": "dud flicker", "dess": "--",
                 "move_chevron_*": "one dim flicker", "power_*": "stay idle "
                 "(the reason: no power)"},
    "reads_without_colour": "fins and front lip rise toward the throw; the "
                            "chevrons point it; the deck kicks only when it "
                            "throws",
}


# --- ir_impact_seal and ir_seal_jamb ------------------------------------------

COLS = (-1.02, 0.0, 1.02)          # slab centres, x
ROWS = (-0.765, 0.765)             # slab centres, z
SLAB = (0.96, 0.30, 1.47)


def seal():
    body = [b("seal_core", (2.98, 0.02, 2.98), (0.0, 0.0, 0.0), "ca_dark")]
    slabs, parts, hinges = [], [], []
    k = 0
    for r, z in enumerate(ROWS):
        for c, x in enumerate(COLS):
            k += 1
            pieces = [b("slab", SLAB, (x, 0.0, z), "ir_armour")]
            # Orange collars on this slab's seam edges, both faces: the
            # seams are where it gives, so they are drawn on what breaks.
            for face in (-1.0, 1.0):
                y = face * (SLAB[1] / 2.0 + 0.012)
                if c < 2:
                    pieces.append(b("collar", (0.06, 0.024, SLAB[2] - 0.08),
                                    (x + SLAB[0] / 2.0 - 0.03, y, z),
                                    "ca_orange"))
                if c > 0:
                    pieces.append(b("collar", (0.06, 0.024, SLAB[2] - 0.08),
                                    (x - SLAB[0] / 2.0 + 0.03, y, z),
                                    "ca_orange"))
                edge_z = z + (SLAB[2] / 2.0 - 0.03) * (1 if r == 0 else -1)
                pieces.append(b("collar", (SLAB[0] - 0.08, 0.024, 0.06),
                                (x, y, edge_z), "ca_orange"))
                # Two rating bolts where it was clamped.
                for bx in (-0.30, 0.30):
                    pieces.append(b("bolt", (0.07, 0.03, 0.07),
                                    (x + bx, y, z - 0.45 * (1 if r else -1)),
                                    "ca_steel"))
            slab = common.join(pieces, "slab_%d_mesh" % k)
            slabs.append(slab)
            hinges.append(ca._hinge_spec("slab_%d" % k, [slab], (x, 0.0, z),
                                         "x", {"intact": 0.0}, "intact"))
    scuffs = [b("scuff_%d" % (i + 1), (w, 0.006, h),
                (x, -SLAB[1] / 2.0 - 0.03, z), "ca_dark")
              for i, (w, h, x, z) in enumerate(((0.42, 0.20, -0.25, 0.10),
                                                (0.30, 0.26, 0.35, -0.12),
                                                (0.50, 0.16, 0.05, 0.35)))]
    kit._tile(body + slabs + scuffs)
    parts = slabs + scuffs
    return body, parts, hinges


def jamb():
    # On the hall face (authoring -Y) round the 3 m opening; the floor is
    # its bottom, so no sill.
    y = -0.25 - 0.04
    parts = [b("jamb_l", (0.25, 0.08, 3.25), (-1.625, y, 0.125), "ca_steel"),
             b("jamb_r", (0.25, 0.08, 3.25), (1.625, y, 0.125), "ca_steel"),
             b("jamb_head", (3.50, 0.08, 0.25), (0.0, y, 1.625), "ca_steel")]
    for x in (-1.625, 1.625):
        for z in (-1.0, 0.0, 1.0):
            parts.append(b("jamb_bolt", (0.07, 0.03, 0.07),
                           (x, y - 0.05, z), "ca_steel"))
    kit._tile(parts)
    return parts


SEAL_STATES = {
    "drive": "ImpactShutter's own events: hp, struck(amount, accepted), "
             "broken",
    "intact": {"slab_*": "in place", "scuff_*": "hidden (hide at build)"},
    "wear": {"collars": "the seams brighten as hp falls -- the shutter's "
                        "own `_paint(0.4 + 2.0 * wear)` on the collar "
                        "material, emissive orange"},
    "glance": {"scuff_n": "show the next one (1, 2, 3, then cycle)",
               "collars": "spark flash 0.15 s"},
    "refused": {"collars": "flash 0.25 s; nothing else changes"},
    "broken": {"slab_1..6": "each becomes a RigidBody at its own node "
                            "transform (origin at the slab's centre), "
                            "colliding with the world only; ~60 kg each",
               "seal_core": "freed with the shutter",
               "ir_seal_jamb": "stays: an empty frame"},
    "reads_without_colour": "six heavy slabs with dark gaps: it is built "
                            "in pieces, and it falls in pieces",
}


# --- ir_teaching_tote and ir_relay_weight --------------------------------------

_LIBRARY_CHECK = {
    "asked": "the 4 kg teaching tote and the 36 kg weight must look "
             "materially different (owner, 2026-10-08; D-18 v2 section 6)",
    "searched": "docs/art/ART_REVIEW.md and every manifest under "
                "assets/models for crates, totes, weights and ballast",
    "closest": {
        "phys_generic": "15 kg crate, 0.645 x 0.646 x 0.625 m: a solid "
                        "lidded crate, too big, and it reads heavy",
        "phys_power_cell": "40 kg, 0.34 x 0.34 x 0.60 m: an energy cell, "
                           "the wrong object and the wrong footprint",
        "phys_mechanical_part": "55 kg, 0.475 x 0.403 x 0.43 m: a "
                                "machine part, not a weight",
        "int_carryable / dec_crate_fixed": "handled industrial crate, "
                                           "0.58 x 0.50 x 0.51 m: heavy-"
                                           "looking by design",
        "prop_crate": "decoration, painted end to end, no handling",
    },
    "verdict": "nothing at the tested sizes says 'light' or 'dense'; "
               "rescaling a library body would change what it is, so two "
               "minimal props in the Batch 043 family rule",
}


def _rough(name, value):
    """The theme roughness suits painted steel. Plastic and bare grips
    are set here, once, on the cached material: Batch 043 measured a
    grip at roughness 0.30 catching the room's specular and arriving
    BRIGHTER than its body, so the grip is 0.62 as there."""
    mat = kit._material(name)
    mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"]\
        .default_value = value
    return name


def _outline(half, radius, z):
    """A rounded rectangle at height `z`: 12 points, counter-clockwise
    from +X, three a corner (two 45-degree segments), so the corners
    read as moulded, not cut. Corner c owns points 3c..3c+2; the straight
    side c runs from point 3c+2 to point 3c+3."""
    points = []
    for cx, cy, a0 in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
        for k in range(3):
            a = math.radians(a0 + 45 * k)
            points.append((cx * (half - radius) + radius * math.cos(a),
                           cy * (half - radius) + radius * math.sin(a), z))
    return points


def _lerp(a, b, f):
    return tuple(a[i] + (b[i] - a[i]) * f for i in range(3))


def _mesh(name, verts, faces, mat):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    common.assign(obj, kit._material(mat))
    return obj


#: The vents, in a side panel's own (s along, t up) parameters: three
#: upright stadium slots, about 4.7 cm wide and 17 cm tall, round-ended.
VENT_S = (0.22, 0.5, 0.78)
VENT_HALF_S = 0.065
VENT_T = (0.16, 0.70)
VENT_ARC = 4                       # segments in each round end


def _vent_panel(b0, b1, t0, t1, verts, faces):
    """One straight side, from bottom edge b0-b1 up to top edge t0-t1,
    with VENT_S's round-ended slots cut through it. Built as bands, posts
    and two small fans a slot end, so it stays a few dozen triangles."""
    def at(s, t):
        return _lerp(_lerp(b0, b1, s), _lerp(t0, t1, s), t)

    def quad(a, b_, c, d):
        base = len(verts)
        verts.extend([a, b_, c, d])
        faces.append((base, base + 1, base + 2, base + 3))

    def tri(a, b_, c):
        base = len(verts)
        verts.extend([a, b_, c])
        faces.append((base, base + 1, base + 2))

    side = math.dist(b0, b1) * 0.5 + math.dist(t0, t1) * 0.5
    height = math.dist(_lerp(b0, b1, 0.5), _lerp(t0, t1, 0.5))
    rt = VENT_HALF_S * side / height          # a round end's t radius
    lo, hi = VENT_T
    quad(at(0, 0), at(1, 0), at(1, lo), at(0, lo))
    quad(at(0, hi), at(1, hi), at(1, 1), at(0, 1))
    edges = [0.0]
    for sc in VENT_S:
        edges += [sc - VENT_HALF_S, sc + VENT_HALF_S]
    edges.append(1.0)
    for k in range(0, len(edges), 2):
        quad(at(edges[k], lo), at(edges[k + 1], lo),
             at(edges[k + 1], hi), at(edges[k], hi))
    for sc in VENT_S:
        def arc(cen_t, deg):
            a = math.radians(deg)
            return at(sc + VENT_HALF_S * math.cos(a), cen_t + rt * math.sin(a))
        step = 180.0 / VENT_ARC
        half = VENT_ARC // 2
        bottom, top = lo + rt, hi - rt
        for k in range(half):       # the two corners under the lower end
            tri(at(sc - VENT_HALF_S, lo), arc(bottom, 270 - step * k),
                arc(bottom, 270 - step * (k + 1)))
            tri(at(sc + VENT_HALF_S, lo), arc(bottom, 360 - step * k),
                arc(bottom, 360 - step * (k + 1)))
        for k in range(half):       # and the two over the upper end
            tri(at(sc + VENT_HALF_S, hi), arc(top, step * k),
                arc(top, step * (k + 1)))
            tri(at(sc - VENT_HALF_S, hi), arc(top, 90 + step * k),
                arc(top, 90 + step * (k + 1)))
    return at


def tote():
    """`relay_crate`: 4 kg, carriable, thrown and refused. Dess: "a
    flimsy, open-sided plastic tote that wobbles when it lands".

    v2, later on 2026-10-08 (owner: v1 "still looks too much like a gray
    developer placeholder rather than a lightweight plastic container").
    A moulded container, not a cage:
    * thin walls with a slight draft (0.43 m at the floor, 0.47 m under
      the rim), rounded corners, and three ROUND-ENDED vents a side;
    * a thick rolled rim all round, the widest part, a shade lighter;
    * satin ivory plastic -- warm, not the station's cold grey, low
      roughness so it takes a soft highlight, never metallic;
    * dark moulded hand recesses on the two end walls, Batch 043's
      handling colour, where a hand takes it.
    The walls are single, double-sided surfaces: thin is the point.
    The box, origin and everything Prod tests are unchanged.
    """
    _rough("ir_tote", 0.40)
    _rough("ir_tote_rim", 0.36)
    _rough("ir_grip", 0.62)
    w, d, h = TOTE
    lo, hi = -h / 2.0, h / 2.0
    wall_top = hi - 0.03
    bottom = _outline(0.215, 0.04, lo)
    top = _outline(0.235, 0.05, wall_top)
    verts, faces = [], []
    # The floor, one moulded plate 1 cm up on the walls' foot: at the
    # box's own bottom it would be coplanar with whatever the tote rests
    # on (the plate's deck) and z-fight there.
    faces.append(tuple(range(len(verts), len(verts) + 12)))
    verts.extend(_outline(0.215, 0.04, lo + 0.01))
    # The rounded corners: two facets each, floor to rim.
    for c in range(4):
        for k in range(2):
            i, j = 3 * c + k, 3 * c + k + 1
            base = len(verts)
            verts.extend([bottom[i], bottom[j], top[j], top[i]])
            faces.append((base, base + 1, base + 2, base + 3))
    panels = []
    for c in range(4):
        i, j = 3 * c + 2, (3 * c + 3) % 12
        panels.append(_vent_panel(bottom[i], bottom[j], top[i], top[j],
                                  verts, faces))
    shell = _mesh("tote_shell", verts, faces, "ir_tote")
    # The rolled rim: up the inside, over the crown, down the outside to
    # a short lip. Its outer face is the box's 0.50 m.
    rings = [top, _outline(0.232, 0.047, hi - 0.008),
             _outline(0.242, 0.057, hi), _outline(0.25, 0.065, hi - 0.015),
             _outline(0.25, 0.065, hi - 0.042)]
    verts, faces = [], []
    for r in range(len(rings) - 1):
        for i in range(12):
            j = (i + 1) % 12
            base = len(verts)
            verts.extend([rings[r][i], rings[r][j], rings[r + 1][j],
                          rings[r + 1][i]])
            faces.append((base, base + 1, base + 2, base + 3))
    rim = _mesh("tote_rim", verts, faces, "ir_tote_rim")
    body = [shell, rim]
    kit._tile(body)
    # Hand recesses: a round-ended dark plate on each end wall's upper
    # band, 1.5 mm proud of the wall (inside the parts-touch tolerance).
    grips = []
    for i, c in enumerate((1, 3)):      # side 1 faces -X, side 3 faces +X
        at = panels[c]
        normal = (-1.0 if c == 1 else 1.0, 0.0, 0.0)
        pts = []
        for sc, a0 in ((0.5 + 0.14, -90), (0.5 - 0.14, 90)):
            for k in range(VENT_ARC + 1):
                a = math.radians(a0 + 180.0 * k / VENT_ARC)
                p = at(sc + 0.06 * math.cos(a), 0.85 + 0.17 * math.sin(a))
                pts.append(tuple(p[n] + normal[n] * 0.0015 for n in range(3)))
        g = _mesh("grip_hand_%d" % i, pts, [tuple(range(len(pts)))],
                  "ir_grip")
        g.name = "grip_hand_%d" % i
        grips.append(g)
    kit._tile(grips)
    return body, grips


TOTE_STATES = {
    "drive": "Prod's ManipulableBody: carried, released, thrown by the "
             "plate, and its own contacts",
    "rest": "as built",
    "carried": {"grip_hand_*": "may light while held (section 33.7, "
                               "'attach point available'); optional"},
    "lands": {"root": "WOBBLE -- Prod's code, not a pose: a damped rock "
                      "of the visual child about the floor's centre, "
                      "about 6 degrees, 3 swings in 0.4 s, on a landing "
                      "harder than a set-down. D-18 section 7 lists this "
                      "polish as cuttable"},
    "refused": "nothing on the tote: the shutter's flash and knock say it",
    "reads_without_colour": "a thin moulded container with round vents "
                            "and a thick rolled rim: you see the floor "
                            "through it, and it is the palest loose thing "
                            "in the room",
}


def weight():
    """`relay_weight`: 36 kg, carriable, MEDIUM. Dess: "dense steel, a
    squat block with a carry handle. Before it moves, it should look
    like it would hurt."

    Inside Prod's 0.45 x 0.60 x 0.45 m box, the handle takes the top
    0.14 m, so the block itself is squat: 0.42 wide and 0.46 tall on a
    full-width foot, under a strap and a narrower cap. Dark cast steel,
    with the cap and foot worn bright (the edges a heavy thing loses its
    paint from). Solid on every side, so nothing in it is air. The bail
    handle is the only grip: one handle, hand-scale, bare dark metal.
    Two `lightened_panel_*` nodes on the flanks, as on every Batch 043
    body, because D-18 v2 names `lightened` on this object.
    """
    _rough("ir_grip", 0.62)
    w, d, h = WEIGHT
    lo, hi = -h / 2.0, h / 2.0
    foot_h, cap_h = 0.04, 0.06
    block_w = 0.42
    block_top = hi - 0.14 - cap_h
    body = [b("weight_foot", (w, d, foot_h), (0.0, 0.0, lo + foot_h / 2.0),
              "ir_machined"),
            b("weight_block", (block_w, block_w, block_top - lo - foot_h),
              (0.0, 0.0, (lo + foot_h + block_top) / 2.0), "ir_cast"),
            b("weight_strap", (w, d, 0.07), (0.0, 0.0, lo + 0.18),
              "ir_cast"),
            b("weight_cap", (0.34, 0.34, cap_h),
              (0.0, 0.0, block_top + cap_h / 2.0), "ir_machined")]
    kit._tile(body)
    top = block_top + cap_h
    posts = [brushkit.block("grip_post", (0.05, 0.05, hi - top - 0.02),
                            (x, 0.0, top + (hi - top - 0.02) / 2.0))
             for x in (-0.12, 0.12)]
    bar = brushkit.block("grip_bar", (0.30, 0.06, 0.04), (0.0, 0.0, hi - 0.02))
    handle = common.join(posts + [bar], "grip_handle")
    common.assign(handle, kit._material("ir_grip"))
    handle.name = "grip_handle"
    panels = []
    for i, sx in enumerate((-1.0, 1.0)):
        p = b("lightened_panel_%d" % i, (0.01, 0.22, 0.10),
              (sx * (block_w / 2.0 + 0.005), 0.0, lo + 0.29), "ir_lightened")
        p.name = "lightened_panel_%d" % i
        panels.append(p)
    kit._tile([handle] + panels)
    return body, [handle] + panels


WEIGHT_STATES = {
    "drive": "Prod's ManipulableBody: carried, set down on the plate, "
             "thrown, recovered to its stand",
    "rest": "as built",
    "carried": {"grip_handle": "may light while held (section 33.7); "
                               "optional"},
    "lightened": {"lightened_panel_*": "override the one slot "
                                       "`ir_lightened` while the status "
                                       "holds, as Batch 043 does"},
    "reads_without_colour": "a solid squat block on a foot, a strap and a "
                            "handle: nothing in it is air",
}


def _body_entry(entry, box, kg, mass_class, prod_name, placeholders,
                states):
    entry.update({
        "fits": "Production's `%s` (impact_relay_room.gd, a3b59c46): "
                "exactly its %.2f x %.2f x %.2f m box (x, y, z), %g kg"
                % (prod_name, box[0], box[2], box[1], kg),
        "size_runtime": [box[0], box[2], box[1]],
        "mass_kg": kg, "mass_class": mass_class, "carriable": True,
        "origin": "the box centre -- ManipulableBody.create's own origin, "
                  "where its BoxShape3D is centred",
        "mount": "child of the ManipulableBody at identity; hide Prod's "
                 "%s" % placeholders,
        "collision": "none in the GLB: ManipulableBody.create's BoxShape3D "
                     "from the size above, unchanged. Mass, size, damping "
                     "and every tested number stay as they are",
        "family_rule": "Batch 043: bare dark metal (%s) only where a hand "
                       "takes hold" % HANDLING,
        "states": states,
        "library_check": _LIBRARY_CHECK,
    })
    return entry


def build(name):
    common.reset_scene()
    kit._IMAGES.clear()
    kit._MATERIALS.clear()
    if name == "ir_object_launcher":
        structure, decoration, parts, hinges = launcher()
        entry = ca._export(name, structure + decoration, parts, hinges,
                           structure, "interactable")
        entry["fits"] = ("Production's ObjectPlate (impact_lab_parts.gd): "
                         "its 2.0 x 0.25 x 2.0 m collider is kept exactly -- "
                         "the deck's top is at 0.25 m. Everything else sits "
                         "round it inside D-18's 2.4 m")
        entry["mount"] = ("child of the ObjectPlate at identity, yawed as "
                          "the plate yaws its own deck (Godot -Z along the "
                          "throw). Hide the plate's code boxes (Slab, "
                          "Chevron, Lip, PowerLamp); keep its Sensor")
        entry["collision"] = ("Prod's plate box, unchanged. Convex twins on "
                              "the side lips and the rear housing: they "
                              "funnel a weight dropped near an edge, which "
                              "is a physics change -- Prod's and Dess's call "
                              "whether to keep them")
        entry["states"] = LAUNCHER_STATES
        entry["power_exit"] = {"at_runtime": _to_runtime((-0.90, -1.26,
                                                          kit.PIPE_Z)),
                               "note": "the inlet's rear face at the green "
                                       "raceway's pipe height; mirror x for "
                                       "a feed from the east"}
        entry["state_nodes"] = {"move_rail_*, move_chevron_*": {
                                    "idle": IR_MOVE_IDLE, "live": ca.MOVE},
                                "move_fin_*, move_lip": {"constant": ca.MOVE},
                                "power_*": kit.POWER_STATE}
    elif name == "ir_impact_seal":
        body, parts, hinges = seal()
        entry = ca._export(name, body, parts, hinges, (), "interactable")
        entry["fits"] = ("Production's ImpactShutter: inside its 3.0 x 3.0 "
                         "x 0.4 m box, origin at the box centre, hall face "
                         "Godot +Z (the shutter's `normal`)")
        entry["mount"] = ("child of the ImpactShutter at identity; hide its "
                          "Casing, Band and Seam boxes; drive `_seams` "
                          "through the collar material")
        entry["collision"] = "none in the GLB: the shutter's own box"
        entry["states"] = SEAL_STATES
    elif name == "ir_teaching_tote":
        body, grips = tote()
        entry = _body_entry(ca._export(name, body, grips, [], (), "prop"),
                            TOTE, 4.0, "LIGHT", "relay_crate",
                            "Base, Side and End boxes", TOTE_STATES)
    elif name == "ir_relay_weight":
        body, parts = weight()
        entry = _body_entry(ca._export(name, body, parts, [], (), "prop"),
                            WEIGHT, 36.0, "MEDIUM", "relay_weight",
                            "Look, Band, HandlePost and Handle boxes",
                            WEIGHT_STATES)
    else:
        body = jamb()
        entry = ca._export(name, body, [], [], (), "prop")
        entry["mount"] = ("on the wall, NOT under the shutter: same origin "
                          "as the shutter (the opening's centre), frame on "
                          "the hall face. It stays when the seal breaks")
    return entry


ASSETS = ["ir_object_launcher", "ir_impact_seal", "ir_seal_jamb",
          "ir_teaching_tote", "ir_relay_weight"]


def main():
    made = {}
    for name in ASSETS:
        entry = build(name)
        made[name] = entry
        print("[ir] %-20s %4d tris, %d part(s), %d collider(s)"
              % (name, entry["triangles"], len(entry.get("parts", [])),
                 len(entry.get("colliders", []))))
    shared = {
        "batch": "065", "kind": "impact_relay_g1",
        "status": "CANDIDATE -- for Impact Relay G1 (D-18 Concept A on "
                  "Prod's G0 mechanism); not in the content pack; not "
                  "integrated",
        "contracts": {"ObjectPlate.SIZE": [2.0, 0.25, 2.0],
                      "ImpactShutter.size": [3.0, 3.0, 0.4],
                      "read_at": "review/impact-lab-g0 3337769d",
                      "rechecked_at": "review/impact-relay-g1 a3b59c46: "
                                      "plate and shutter unchanged; "
                                      "CRATE_SIZE [0.5, 0.36, 0.5] 4 kg "
                                      "and WEIGHT_SIZE [0.45, 0.6, 0.45] "
                                      "36 kg read there"},
        "reuses": ["Batch 064 materials and helpers",
                   "Batch 063 power state and hinges"],
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
