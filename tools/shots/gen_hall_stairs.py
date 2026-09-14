"""Close-ups of the three hall flights, which are what `67add07` changed.

    python3 tools/shots/gen_hall_stairs.py
    tools/shoot.sh tools/shots/hall_stairs.json docs/art/review/hall_67add07

WHY A SEPARATE LIST. The fourteen P3 views answer "is this the big open
room the direction asked for", and they answer it from far enough away
that a stair reads as a diagonal line. The repair at `67add07` is a
change to what that diagonal IS -- sloped wedges that sawtoothed
underfoot became flat treads -- and no P3 view is close enough to show
it. These four are.

A flight is not a declared object -- the manifest has surfaces and
traversal segments, not stairs -- so unlike every other camera in the
package these anchors come from the SHIPPED GEOMETRY: the tread boxes
themselves, parsed out of the `.glb` by `measure_flights`. Which way a
flight runs, which end is low, how wide it is and how high it reaches
are all read off the treads, so a camera cannot point at a staircase the
export did not produce. Only the standoff distance is chosen.

Every shot stands ON the flight and looks along it. That is the player's
own view of a climb, and it is the one view of a staircase that nothing
can block, because the camera is standing on the thing it is looking at.
An earlier version stood back from the landings and put a 30 m armature
column squarely through the middle of the first shot.

CAMERA FRAME is the P3 package's, unchanged: Godot point negated in x
and z, yaw theta looks along `(sin theta, 0, cos theta)`, `eye` adds an
eye height `look` does not. See L-52.
"""

import json
import math
import pathlib

EYE = 1.6
SHELL = "model:batch039/shells/shell_hall_transit.glb"
LIGHT = {"ambient": 0.30, "key_energy": 1.10}

MANIFEST = pathlib.Path("assets/models/batch039/shells/manifest.json")
M = json.loads(MANIFEST.read_text())["shell_hall_transit"]


def R(x, y, z):
    return [round(-x, 3) + 0.0, round(y, 3) + 0.0, round(-z, 3) + 0.0]


def aim(eye_r, at_r, lift=EYE):
    dx = at_r[0] - eye_r[0]
    dy = at_r[1] - (eye_r[1] + lift)
    dz = at_r[2] - eye_r[2]
    yaw = math.degrees(math.atan2(dx, dz)) % 360.0
    flat = math.hypot(dx, dz)
    return round(yaw, 1), round(math.degrees(math.atan2(dy, flat))
                                if flat > 1e-6 else 0.0, 1)


def shot(key, title, stand, look_at, note):
    """A camera standing at one Godot point, aimed at another."""
    eye_r, at_r = R(*stand), R(*look_at)
    yaw, pitch = aim(eye_r, at_r)
    return {"name": key, "scene": SHELL, "eye": eye_r, "yaw": yaw,
            "pitch": pitch, "light": LIGHT, "caption": [title, note]}


def treads(tag):
    """The flight's tread boxes, low to high, read from the SHIPPED glb.

    Not from the manifest -- a flight is not a declared object, it is
    geometry -- and not from `build_hall.py`, because a camera derived
    from the source rather than the artefact can point at a room the
    export did not produce. `measure_flights` already parses the
    collider meshes; this borrows that.
    """
    import sys
    sys.path.insert(0, "tools/content")
    import measure_flights as mf
    tris = mf.triangles("assets/models/batch039/shells/shell_hall_transit.glb")
    group = mf.flights(tris).get(tag)
    if group is None:
        raise SystemExit("no flight %r in the shipped shell" % tag)
    out = []
    for mesh in group:
        pts = [q for t in mesh for q in t]
        out.append({"x": (min(p[0] for p in pts), max(p[0] for p in pts)),
                    "z": (min(p[2] for p in pts), max(p[2] for p in pts)),
                    "top": max(p[1] for p in pts)})
    return out


def along(tag, back=5.0, look=0.55, reverse=False):
    """Stand at the foot of the flight and look up it -- or the reverse.

    The player's own view of the climb, and the one view of a staircase
    that cannot be blocked by anything, because the camera is standing
    on the thing it is looking at. Every number is derived from the
    tread boxes: which way the flight runs, which end is low, how wide
    it is and how high it reaches.
    """
    t = treads(tag)
    lo, hi = t[0], t[-1]
    run = "z" if (abs(hi["z"][0] - lo["z"][0])
                  > abs(hi["x"][0] - lo["x"][0])) else "x"
    cross = "x" if run == "z" else "z"
    mid = lambda b, k: (b[k][0] + b[k][1]) / 2.0
    if reverse:
        lo, hi = hi, lo
    # A unit step along the run, pointing from the standing end toward
    # the other one.
    sign = 1.0 if mid(hi, run) > mid(lo, run) else -1.0
    stand = {run: mid(lo, run) - sign * back, cross: mid(lo, cross)}
    at = {run: mid(hi, run), cross: mid(hi, cross)}
    y_stand = lo["top"]
    y_at = lo["top"] + (hi["top"] - lo["top"]) * look
    return ([stand["x"], y_stand, stand["z"]], [at["x"], y_at, at["z"]])


s1, l1 = along("hl_ramp1")
s2, l2 = along("hl_ramp2")
s3, l3 = along("hl_ramp3")
s4, l4 = along("hl_ramp1", back=3.0, look=0.65, reverse=True)

shots = [
    shot("S1_ramp1_basin_to_gallery",
         "RAMP 1  BASIN 0 -> WEST GALLERY 11", s1, l1,
         "13 flat treads, each 0.85 m above the one before it"),
    shot("S2_ramp2_gallery_to_landing",
         "RAMP 2  WEST GALLERY 11 -> NORTH LANDING 21", s2, l2,
         "12 treads at 0.83 m; this flight was never refused"),
    shot("S3_ramp3_gantry_to_exit",
         "RAMP 3  EAST GANTRY 21 -> EXIT PLATFORM 28", s3, l3,
         "8 treads at 0.88 m, the steepest in the room"),
    shot("S4_ramp1_from_the_gallery",
         "RAMP 1 LOOKING BACK DOWN, FROM THE WEST GALLERY", s4, l4,
         "the same 13 treads receding; this is the descent"),
]

main = {
    "_comment": [
        "HALL FLIGHT REPAIR -- shell_hall_transit at 67add07.",
        "GENERATED by tools/shots/gen_hall_stairs.py; edit that.",
        "",
        "Production's capsule audit refused basin_to_gallery and",
        "gantry_to_exit: the flights were chains of sloped wedges, and",
        "for a run along Godot z every wedge sloped against the",
        "direction its chain climbed. The surface fell 0.35-0.70 m",
        "between apparent treads and then demanded about 1.40 m.",
        "",
        "They are flat treads now. The shell still exports",
        "review: 'pending' and nothing here changes that.",
    ],
    "defaults": {"size": [1920, 1080], "backdrop": "none", "game_lens": True},
    "shots": shots,
}

out = pathlib.Path("tools/shots/hall_stairs.json")
out.write_text(json.dumps(main, indent=2) + "\n")
print("wrote", out, "with", len(shots), "shots")
