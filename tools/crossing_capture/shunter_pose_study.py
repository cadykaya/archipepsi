"""The Shunter pose study's capture specs. DISPOSABLE CONCEPT, REVIEW ONLY.
(Arty, 2026-10-09.)

    python3 tools/crossing_capture/shunter_pose_study.py POSES_DIR OUT_DIR
    python3 tools/crossing_capture/shunter_pose_study.py --crops CAPTURES OUT

POSES_DIR holds `study_shunter_poses.py`'s 12 GLBs. Writes one `dcap.gd`
spec per variant and state (A = D-19 as written, B = the recommended
cues), each placing that one pose alone in Crossing D's empty yard
(`--crossing-d --empty-yard`), facing the player, and photographing it
from where the fight is actually seen:

  F20  front, 20 m, eye height: D-19's "readable from 20 m" (notice ~18 m)
  F14  front, 14 m: the rush reach, where BRACE has to be read
  S8   side, 8 m: the silhouette a flanking player sees
  R6   rear quarter, 6 m: where a sidestepped player stands after a MISS
  H12  from the front, 4.6 m up and ~13 m off: a ledge or ramp top
  C10  front-right quarter, 10 m, over a 1.1 m stand-in crate placed off
       the other cameras' lines: what still shows when the body is hidden
       (both moved 2026-10-09 from first placements a yard wall and the
       ramp structure blocked)

All in colour and grey. The yard floor is at y 9.0; the pose stands at
(-4, 9, -34), yawed to face +Z (MISS is yawed a further 20 degrees: it
has skidded past). The stand-in crate is a visual-only profile, no
collision.
"""

import json
import os
import sys

#: For `--crops`: per shot, the crop (w, h) round the frame's centre (the
#: pose is the look target) and the nearest-neighbour enlargement. The
#: game's default field of view is 90 degrees (player_settings.gd), the
#: same as dcap's, so these are the pixels a player gets: about 450 / d
#: px per metre at 1600 x 900, 32 at 14 m and 22 at 20 m.
CROPS = {"F20": (100, 64, 5), "F14": (140, 90, 4), "S8": (260, 166, 2),
         "R6": (360, 230, 1.5), "H12": (240, 154, 2), "C10": (260, 166, 2)}

AT = (-4.0, 9.0, -34.0)    # 4 m west of the yard Check (0, 9, -40), out of its line
EYE = 1.6
STATES = ("work", "notice", "brace", "charge", "miss", "recover")


def shots():
    x, y, z = AT
    look = [x, y + 0.5, z]
    e = y + EYE
    return [
        {"name": "F20", "eye": [x, e, z + 20.0], "look": look, "gray": True},
        {"name": "F14", "eye": [x, e, z + 14.0], "look": look, "gray": True},
        {"name": "S8", "eye": [x + 8.0, e, z], "look": look, "gray": True},
        {"name": "R6", "eye": [x - 3.5, e, z - 5.0], "look": [x, y + 0.4, z],
         "gray": True},
        {"name": "H12", "eye": [x, y + 4.6, z + 12.0], "look": look,
         "gray": True},
        {"name": "C10", "eye": [x + 7.0, e, z + 7.0],
         "look": [x, y + 0.6, z], "gray": True},
    ]


def spec(poses_dir, variant, state):
    yaw = 200.0 if state == "miss" else 180.0
    x, y, z = AT
    return {
        "settle_frames": 90,
        "hide_boxes_of": ["covers"],
        "glbs": [{"path": os.path.join(poses_dir, "shunter_%s_%s.glb"
                                       % (variant, state)),
                  "origin": [x, y, z], "yaw_deg": yaw}],
        "lights": [{"at": [x, y + 3.5, z + 4.0], "color": "#ffffff",
                    "energy": 0.6, "range": 12}],
        "profiles": [{"name": "StudyCrate",
                      "points": [[x + 0.9, y], [x + 3.1, y],
                                 [x + 3.1, y + 1.1], [x + 0.9, y + 1.1]],
                      "z": [z + 2.1, z + 2.5], "like": "YardWest"}],
        "shots": shots(),
    }


def main(poses_dir, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    for variant in ("A", "B"):
        for state in STATES:
            path = os.path.join(out_dir, "%s_%s.json" % (variant, state))
            with open(path, "w", encoding="utf-8") as handle:
                json.dump(spec(poses_dir, variant, state), handle, indent=1)
    print("[shunter] 12 specs in %s" % out_dir)


def crops(pout_dir, out_dir):
    """Cut every shot to its pose and enlarge it, nearest-neighbour, so
    no detail is invented: what is there is what a player gets."""
    from PIL import Image
    os.makedirs(out_dir, exist_ok=True)
    for run in sorted(os.listdir(pout_dir)):
        for shot, (w, h, k) in CROPS.items():
            for suffix in ("", "_gray"):
                src = os.path.join(pout_dir, run, shot + suffix + ".png")
                if not os.path.exists(src):
                    continue
                im = Image.open(src)
                cx, cy = im.width // 2, im.height // 2
                box = (cx - w // 2, cy - h // 2 - h // 8,
                       cx + w // 2, cy + h // 2 - h // 8)
                im.crop(box).resize((int(w * k), int(h * k)),
                                    Image.NEAREST).save(os.path.join(
                                        out_dir, "%s_%s%s.png"
                                        % (run, shot, suffix)))
    print("[shunter] crops in %s" % out_dir)


if __name__ == "__main__":
    if sys.argv[1] == "--crops":
        crops(sys.argv[2], sys.argv[3])
    else:
        main(sys.argv[1], sys.argv[2])
