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
    "names": "Prod's ObjectPlate states, with Dess's D-18 names beside them",
    "dark":     {"prod": "unpowered", "dess": "DARK",
                 "move_rail_*": "idle", "move_chevron_*": "idle",
                 "power_*": "idle", "deck_hinge": 0.0},
    "cocked":   {"prod": "powered idle", "dess": "COCKED",
                 "move_rail_*": "live, steady", "move_chevron_*": "idle",
                 "power_*": "live", "deck_hinge": 0.0},
    "arming":   {"prod": "arming (0.6 s ramp)", "dess": "WIND-UP",
                 "move_chevron_1..3": "light one by one, back to front, "
                                      "as the ramp passes 1/3, 2/3, 3/3",
                 "move_rail_*": "pulse, faster as it fills",
                 "power_*": "live"},
    "fired":    {"prod": "throw flash", "dess": "FIRED",
                 "deck_hinge": "kick to 10 deg in 0.06 s, back in 0.25 s, "
                               "on ObjectPlate.fired only",
                 "move_*": "flash to live x2.5 for 0.12 s"},
    "rearm":    {"prod": "REARM_SECONDS (1.0)", "dess": "RE-ARM (2 s)",
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
    else:
        body = jamb()
        entry = ca._export(name, body, [], [], (), "prop")
        entry["mount"] = ("on the wall, NOT under the shutter: same origin "
                          "as the shutter (the opening's centre), frame on "
                          "the hall face. It stays when the seal breaks")
    return entry


ASSETS = ["ir_object_launcher", "ir_impact_seal", "ir_seal_jamb"]


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
                      "read_at": "review/impact-lab-g0 3337769d"},
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
