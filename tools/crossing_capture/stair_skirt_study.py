"""The dead-end stair's skirt: a visual-only noise study. REVIEW ONLY.
(Arty, 2026-10-08.)

    python3 tools/crossing_capture/stair_skirt_study.py QUIET_DIR OUT_DIR

Writes three `dcap.gd` specs -- A (as played), T2 (the targeted quiet
ceiling and stair) and C2 (T2 plus a skirt) -- with the same three
cameras, so the three can be photographed in one review checkout of
`review/crossing-d-readability`. QUIET_DIR holds `study_station_quiet.py`'s
output (`quiet_ceiling.png`, `quiet_floor.png`).

WHY A SKIRT. Crossing D's `_stair()` builds the yard stair from 36
full-height boxes, one per 0.25 m rise, so its open side (z = -9.5, the
side the hall sees) is a 12 x 9 m sawtooth of stacked box faces. A
material change quiets the texture but not the geometry. C2 adds one
closed stringer on that side: a thin extruded profile whose top runs
`ABOVE` over the line through the step nosings, so every step's
side-face corner is hidden behind one calm plane. It is a
`CSGPolygon3D` with collision OFF, outside the 2.5 m walk width; no box,
collider or traversal number changes. Its material is the stair's own,
after T2 (the quiet floor role), so the flight reads as one concrete
mass with its treads showing along the top.

The numbers are Crossing D's (crossing_d_room.gd, bb683ce0): STAIR_FOOT_X,
STAIR_TOP_X, YARD_FLOOR, STAIR_RISE and STAIR_Z.
"""

import json
import math
import os
import sys

FOOT_X, TOP_X = -2.4, 9.5
YARD_FLOOR, STAIR_RISE = 9.0, 0.25
OPEN_SIDE_Z = -9.5          # STAIR_Z.y: the side the hall sees
THICKNESS = 0.08
ABOVE = 0.05                # the stringer's cap over the nosing line

SHOTS = [
    {"name": "T1_hall_entry", "eye": [-7, 1.6, 11.0],
     "look": [-0.5, 6.5, -12]},
    {"name": "T2_hall_stair", "eye": [-1.0, 1.6, 3.0],
     "look": [4.5, 4.0, -11]},
    {"name": "T5_stair_foot", "eye": [-6.0, 1.6, -5.0],
     "look": [3.0, 3.2, -11.0]},
]


def skirt_profile():
    """(x, y) of the stringer: floor, top end, the flat over the last
    tread, then the nosing line back down to the foot."""
    steps = max(int(math.ceil(YARD_FLOOR / STAIR_RISE)), 1)
    tread = (TOP_X - FOOT_X) / steps
    last_nosing_x = FOOT_X + (steps - 1) * tread
    return [[FOOT_X, 0.0], [TOP_X, 0.0], [TOP_X, YARD_FLOOR + ABOVE],
            [round(last_nosing_x, 4), YARD_FLOOR + ABOVE],
            [FOOT_X, STAIR_RISE + ABOVE]]


def specs(quiet_dir):
    ceiling = os.path.join(quiet_dir, "quiet_ceiling.png")
    floor = os.path.join(quiet_dir, "quiet_floor.png")
    a = {"settle_frames": 90, "shots": SHOTS}
    t2 = dict(a, retexture=[{"match": "Ceiling", "png": ceiling},
                            {"match": "YardStair", "png": floor},
                            {"match": "StairLanding", "png": floor}])
    c2 = dict(t2, profiles=[{"name": "StudyStairSkirt",
                             "points": skirt_profile(),
                             "z": [OPEN_SIDE_Z, OPEN_SIDE_Z + THICKNESS],
                             "like": "YardStair"}])
    return {"A": a, "T2": t2, "C2": c2}


def main(quiet_dir, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    for name, spec in specs(quiet_dir).items():
        path = os.path.join(out_dir, "%s.json" % name)
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(spec, handle, indent=1)
        print("[stair] %s" % path)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
