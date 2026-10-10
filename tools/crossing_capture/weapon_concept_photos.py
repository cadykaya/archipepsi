"""Photograph the weapon-family concept maquettes from the player's eye.
EXPLORATION ONLY. (Arty, 2026-10-10.)

    python3 tools/crossing_capture/weapon_concept_photos.py CONCEPTS_DIR SPECS_DIR

CONCEPTS_DIR is `study_weapon_concepts.py`'s output (the GLBs and
`concepts.json`). Writes one `dcap.gd` spec per family and state for a
read-only checkout of Prod's range (`review/hand-cannon`, host
`weapon_feel.gd`, flag `--weapon-feel`). The player's own device is
hidden and the maquette is placed where Prod's five-weapon `RangeRig`
holds a gun: camera-local (0.30, -0.27, -0.55), rotated (0, 6, -3).

A firing state shows:
- the kick 33 ms in (Batch 068's springs, Prod's integrator);
- Batch 068's own muzzle sheet at the concept's muzzle (the layered
  effects are kept and simply move to the new muzzle);
- a muzzle light.

Mass Driver's charge states lean the gun (roll) and creep it forward:
the gyro read. Shots:
- FP from the eye, plus grey;
- INSPECT, a side elevation from the right, for the hold and the
  action states.
"""

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import five_weapon_study as fws  # noqa: E402

RIG = ([0.30, -0.27, -0.55], [0.0, 6.0, -3.0])     # Prod's RangeRig rest
LIGHT = {"foundry": ("#ffb86b", 6.0), "sightline": ("#dfe8ff", 2.5),
         "switchback": ("#ffb86b", 2.5), "bulkhead": ("#ffb86b", 7.0),
         "massdriver": ("#e4e0ff", 3.0)}


def pose(fam, extra):
    pos, rot = list(RIG[0]), list(RIG[1])
    if extra.get("kick"):
        springs = fws.GUNS[fam]["recoil"]
        s = {k: fws.spring_at(v["spring"], 0.033) for k, v in springs.items()}
        pos[1] += s["lift"]
        pos[2] += s["back"]
        rot[0] += s["pitch"]
        rot[2] -= s["roll"]
    lean = extra.get("lean", 0.0)
    if lean:
        rot[2] += 7.0 * lean          # the gyro leans the gun outward
        pos[2] -= 0.02 * lean         # and it creeps forward
    return pos, rot


def spec(fam, state, item):
    pos, rot = pose(fam, item)
    muzzle = fws.to_eye(pos, rot, item["muzzle"])
    sprites, lights = [], []
    for name in item.get("fx", []):
        sprites.append(fws.sprite(name, 0, at_eye=muzzle))
    if item.get("fx"):
        colour, energy = LIGHT[fam]
        lights.append({"at_eye": muzzle, "color": colour, "energy": energy,
                       "range": 12.0, "shadows": True})
    shots = [{"name": "FP", "player_eye": True, "gray": True}]
    if state in ("hold", "fire", "runup", "sustained", "charge", "full",
                 "vent"):
        # A side elevation: square-on from the right, a long lens, to
        # compare with the 2D sheets.
        shots.append({"name": "INSPECT", "eye_local": [2.2, -0.2, -0.72],
                      "look_local": [0.3, -0.2, -0.72], "fov": 22,
                      "gray": True})
    return {"host": "res://scripts/content/weapon_feel.gd",
            "room_var": "_range", "show_player": True,
            "hide_viewmodel": True, "settle_frames": 60,
            "glbs": [{"path": item["glb"], "eye": pos, "eye_rot_deg": rot}],
            "sprites": sprites, "lights": lights, "shots": shots}


def main(concepts, out):
    os.makedirs(out, exist_ok=True)
    meta = json.load(open(os.path.join(concepts, "concepts.json")))
    n = 0
    for fam, states in meta.items():
        for state, item in states.items():
            with open(os.path.join(out, "%s_%s.json" % (fam, state)), "w",
                      encoding="utf-8") as handle:
                json.dump(spec(fam, state, item), handle, indent=1)
            n += 1
    print("[concept photos] %d specs in %s" % (n, out))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
