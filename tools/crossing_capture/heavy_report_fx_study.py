"""Heavy Report's effects, photographed in Prod's own range. REVIEW ONLY.
(Arty, 2026-10-10.)

    python3 tools/crossing_capture/heavy_report_fx_study.py FX_DIR OUT_DIR

FX_DIR holds `author_heavy_report_fx.py`'s sheets (assets/fx/heavy_report).
Writes one `dcap.gd` spec per moment -- f0..f3, the four frames of the
impact flipbooks with the muzzle and tracer at their own matching frame,
and `after`, the marks left once the flipbooks are gone -- for a
read-only checkout of `review/weapon-feel` (host `weapon_feel.gd`, flag
`--weapon-feel`). Each moment is shot from:

  FP     the player's own eye, the viewmodel visible: what firing looks like
  SIDE   beside the line of fire: the muzzle, the tracer and the metal hit
  CU_M, CU_S, CU_O   about 2.5 m from each surface

THE SURFACES. Prod's range is concrete, with the Echo Lab dummy 10 m down
range. Two stand-ins are placed beside it, visual only:
  * METAL: Batch 065's `ir_impact_seal` (steel armour), at 0.6 scale;
  * STONE: the range's own concrete floor, in front of the dummy;
  * ORGANIC: a labelled stand-in panel, a dark mottled hide written by
    this script (no organic surface in the library reads as one at this
    size: the forest temple's root mass renders gold, the dressing root
    hangs from a ceiling).

THE MUZZLE is where Prod's own bloom is: the viewmodel at camera-local
(0.34, -0.3, -0.62) plus `MUZZLE` (0, 0.02, -0.3), so (0.34, -0.28, -0.92),
at his 0.34 m. Frames are frozen, not played: a flipbook's timing is in
`fx.json`, and the runtime plays it.
"""

import json
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))
MODELS = os.path.join(REPO, "assets", "models")
MUZZLE_EYE = [0.34, -0.28, -0.92]

METAL_AT = (-3.6, 0.9, -10.0)
METAL_HIT = [-4.2, 1.35, -9.62]
STONE_HIT = [1.0, 0.0, -7.0]
ORGANIC_PANEL = (2.8, 0.1, 4.4, 1.7, -10.0, -9.8)   # x0, y0, x1, y1, z0, z1
ORGANIC_HIT = [3.2, 1.35, -9.62]


def organic_standin(out):
    """The stand-in's surface: a dark, warm, mottled hide, 32 px, so the
    organic impact is judged against something organic-coloured."""
    import random
    from PIL import Image
    rng = random.Random(7)
    img = Image.new("RGB", (32, 32))
    for x in range(32):
        for y in range(32):
            v = rng.randint(-10, 10)
            blot = 14 if (x // 6 + y // 5) % 3 == 0 else 0
            img.putpixel((x, y), (92 + v + blot, 66 + v + blot // 2, 58 + v))
    path = os.path.join(out, "organic_standin.png")
    img.save(path)
    return path


def _sprite(fx, name, frame, size, at=None, **extra):
    sheet = json.load(open(os.path.join(fx, "fx.json")))[name]
    item = {"png": os.path.join(fx, sheet["file"]),
            "hframes": sheet["frames"], "frame": frame, "size_m": size}
    if at is not None:
        item["at"] = at
    item.update(extra)
    return item


def spec(fx, moment, standin):
    sprites = []
    if moment == "after":
        sprites += [
            _sprite(fx, "fx_decal_chip", 0, 0.28, [STONE_HIT[0], 0.004,
                                                   STONE_HIT[2]],
                    normal=[0, 1, 0], blend="mix"),
            _sprite(fx, "fx_decal_sap", 0, 0.24, [ORGANIC_HIT[0],
                                                  ORGANIC_HIT[1],
                                                  ORGANIC_PANEL[5] + 0.004],
                    normal=[0, 0, 1], blend="mix"),
        ]
    else:
        k = int(moment[1])
        if k <= 2:
            sprites.append(_sprite(fx, "fx_heavy_muzzle", k, 0.34,
                                   at_eye=MUZZLE_EYE))
        if k <= 1:
            sprites.append(_sprite(fx, "fx_heavy_tracer", k, 0.08,
                                   at_eye=MUZZLE_EYE, beam_to=METAL_HIT,
                                   face=[5.0, 1.7, -4.0],
                                   modulate="#c0d8ffff"))
        sprites += [
            _sprite(fx, "fx_impact_metal", k, 0.6, METAL_HIT),
            _sprite(fx, "fx_impact_stone", k, 0.7,
                    [STONE_HIT[0], 0.25, STONE_HIT[2]], blend="mix"),
            _sprite(fx, "fx_impact_organic", k, 0.55, ORGANIC_HIT,
                    blend="mix"),
        ]
        if k in (1, 2):
            # A few frozen spark particles, where Prod's emitter throws them.
            for dx, dy, dz in ((0.25, 0.18, 0.2), (-0.2, 0.28, 0.25),
                               (0.32, -0.05, 0.3), (-0.3, -0.1, 0.18)):
                sprites.append(_sprite(
                    fx, "fx_spark_streak", 0, 0.09,
                    [METAL_HIT[0] + dx * k, METAL_HIT[1] + dy * k - 0.05 * k,
                     METAL_HIT[2] + dz * k]))
    eye = [0.0, 1.65, 0.05]
    return {
        "host": "res://scripts/content/weapon_feel.gd",
        "room_var": "_range", "show_player": True, "settle_frames": 60,
        "glbs": [
            {"path": os.path.join(MODELS, "batch065", "impact_relay",
                                  "ir_impact_seal.glb"),
             "origin": list(METAL_AT), "scale": 0.6},
        ],
        "profiles": [{"name": "StudyOrganicStandIn",
                      "points": [[ORGANIC_PANEL[0], ORGANIC_PANEL[1]],
                                 [ORGANIC_PANEL[2], ORGANIC_PANEL[1]],
                                 [ORGANIC_PANEL[2], ORGANIC_PANEL[3]],
                                 [ORGANIC_PANEL[0], ORGANIC_PANEL[3]]],
                      "z": [ORGANIC_PANEL[4], ORGANIC_PANEL[5]],
                      "png": standin}],
        "sprites": sprites,
        "shots": [
            {"name": "FP", "player_eye": True, "eye": eye,
             "look": [0, 1.6, -10], "gray": True},
            {"name": "SIDE", "eye": [4.5, 1.7, -2.5],
             "look": [-2.0, 1.3, -7.0], "gray": True},
            # Inspection views: a 38 degree lens at about 3 m, NOT the
            # game's 90 -- FP is the gameplay frame.
            {"name": "CU_M", "eye": [-3.0, 1.55, -6.6], "fov": 38,
             "look": METAL_HIT, "gray": True},
            {"name": "CU_S", "eye": [1.9, 1.5, -4.6], "fov": 38,
             "look": [STONE_HIT[0], 0.2, STONE_HIT[2]], "gray": True},
            {"name": "CU_O", "eye": [2.6, 1.55, -6.6], "fov": 38,
             "look": ORGANIC_HIT, "gray": True},
        ],
    }


def main(fx, out):
    os.makedirs(out, exist_ok=True)
    standin = organic_standin(os.path.abspath(out))
    for moment in ("f0", "f1", "f2", "f3", "after"):
        with open(os.path.join(out, "%s.json" % moment), "w",
                  encoding="utf-8") as handle:
            json.dump(spec(os.path.abspath(fx), moment, standin), handle,
                      indent=1)
    print("[fx] 5 specs in %s" % out)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
