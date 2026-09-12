"""Every shell doorway, measured against the geometry it was exported from.

    python3 tools/content/measure_doorways.py [--verbose]

## Why this exists

Production found three shells declaring an `exit` doorway 2.0 m past their
own declared depth, and a playtester found it first:

    "oof the connecter isnt connected at all haha"

`ZoneBuilder` joins the next corridor AT THE SOCKET. The room's wall is at
its declared depth. So the room ended, the corridor began 2 m later, and
between them was nothing -- no floor, no wall, a hole.

Twelve shells passed every existing check with three of them holding a
doorway in mid-air, because every other shell rule is about a SPAN and this
one is about a POINT. Production added the engine-side measurement
(`ContentInstantiator.doorways_outside_envelope()`); this is the art-side
one, and it asks a harder question than "is the number inside the box":

  1. **ON THE ROOM.** The socket lies within the shell's own envelope.
     This is the defect Production reported.

  2. **THROUGH A CLEAR OPENING.** Where a wall stands at the doorway plane,
     the declared width and height must actually be clear through it.
     Nothing here requires a wall: the first version of this rule did, and
     it failed all three towers, whose exits are the open end of a bridge
     rather than a hole in anything. That was the checker being wrong about
     the shells, which is the failure mode a new check is likeliest to
     have, so it is written down rather than quietly relaxed.

  3. **SUPPORTED.** There is continuous floor at the socket's own height,
     from the doorway face one metre back into the room. This is the check
     that earns its keep: the plenum's exit was BOTH 2 m past its wall AND
     standing over a 0.6 m gap where its floor stopped at the wall's inner
     face and nothing carried it across the threshold. Repairing only the
     coordinate would have moved the doorway onto a hole.

Every number is read from the exported `.glb`, never from the builder, so
this measures what shipped.
"""
import json
import os
import re
import struct
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

FLOOR_TOLERANCE = 0.020    # m; a step this small is a seam, not a ledge
REACH = 1.0                # m back into the room that must hold a player
SAMPLES = 9                # across a door's width, and along the reach


## KNOWN, REPORTED, NOT YET AUTHORIZED.
##
## The 2026-09-12 brief authorized three shells: the hall's, the plenum's
## and the span's `exit`. Measuring all twelve turned up five more doorways
## with the same two defects, on shells the same brief says to preserve. A
## check that passed anyway would be a check that lies; one carrying a
## silent skip list would go stale the moment somebody fixed one. So they
## are named here with what is wrong, and this list is enforced in BOTH
## directions -- a finding that disappears fails just as loudly as a new
## one, the way Production's own test does, so the day one is repaired this
## says so instead of going quiet.
##
## None of these is a regression from the 2026-09-12 repair: every one was
## already true of the shipped art, and `shell_yard_gantry` is the one that
## matters most, because it is the same "doorway outside its own envelope"
## defect Production reported -- on the X axis, where a depth-only check
## cannot see it.
KNOWN = {
    "shell_corner_left/exit": "threshold: cl_floor stops at x 3.00 and the "
                              "socket is on the wall's outer face at 3.40",
    "shell_corner_right/exit": "threshold: cr_floor stops at x -3.00 and the "
                               "socket is on the wall's outer face at -3.40",
    "shell_plenum_helix/entry": "opens onto air: past the 0.6 m sill the "
                                "nearest floor at y 68 is pl_run_0_tread6, "
                                "4.57 m away in -x, and the drop is 68 m",
    "shell_yard_gantry/entry": "0.40 m outside the envelope on X, and no "
                               "floor at the socket -- the same defect "
                               "Production reported, on the other axis",
    "shell_yard_gantry/exit": "0.40 m outside the envelope on X, and no "
                              "floor at the socket",
}


def read_glb(path):
    with open(path, "rb") as handle:
        struct.unpack("<4sII", handle.read(12))
        gltf = None
        while True:
            header = handle.read(8)
            if len(header) < 8:
                break
            size, kind = struct.unpack("<I4s", header)
            payload = handle.read(size)
            if kind == b"JSON":
                gltf = json.loads(payload.decode("utf-8"))
    return gltf


def boxes(gltf):
    """Every mesh node as an axis-aligned box in runtime metres.

    Godot's import-hint suffixes are stripped so a part reads by the name
    its builder gave it. Rotations are refused rather than approximated --
    these shells export none, and guessing would defeat the point.
    """
    parents = {}
    for i, node in enumerate(gltf.get("nodes", [])):
        for child in node.get("children", []):
            parents[child] = i
    out = []
    for i, node in enumerate(gltf.get("nodes", [])):
        if node.get("mesh") is None:
            continue
        name = re.sub(r"-(conv|)col(only|)$", "", node.get("name", ""))
        offset, cursor = [0.0, 0.0, 0.0], i
        while cursor is not None:
            here = gltf["nodes"][cursor]
            for key in ("rotation", "scale", "matrix"):
                if key in here:
                    raise SystemExit(
                        "node `%s` carries a %s; this measures boxes and "
                        "would read a rotated one wrong."
                        % (here.get("name", cursor), key))
            t = here.get("translation", [0.0, 0.0, 0.0])
            offset = [offset[k] + t[k] for k in range(3)]
            cursor = parents.get(cursor)
        for prim in gltf["meshes"][node["mesh"]]["primitives"]:
            acc = gltf["accessors"][prim["attributes"]["POSITION"]]
            out.append((name,
                        [acc["min"][k] + offset[k] for k in range(3)],
                        [acc["max"][k] + offset[k] for k in range(3)]))
    return out


def inward(yaw):
    """The direction the room lies in, from a doorway facing `yaw`.

    A doorway's yaw points OUT of the room, so the room is behind it.
    """
    table = {0.0: (0.0, -1.0), 180.0: (0.0, 1.0),
             90.0: (-1.0, 0.0), 270.0: (1.0, 0.0)}
    key = round(float(yaw) % 360.0, 1)
    if key not in table:
        raise SystemExit("doorway yaw %s is not an axis; teach this the "
                         "diagonal case rather than rounding it." % yaw)
    return table[key]


def standing_on(parts, x, z, y):
    """The parts whose top face is at `y` under the point (x, z)."""
    return [nm for nm, lo, hi in parts
            if lo[0] - 1e-6 <= x <= hi[0] + 1e-6
            and lo[2] - 1e-6 <= z <= hi[2] + 1e-6
            and abs(hi[1] - y) <= FLOOR_TOLERANCE]


def solid_at(parts, x, y, z):
    """The parts strictly containing a point -- boundary contact excluded."""
    return [nm for nm, lo, hi in parts
            if lo[0] < x < hi[0] and lo[1] < y < hi[1] and lo[2] < z < hi[2]]


def check(shell, entry, glb_path, verbose=False):
    gltf = read_glb(glb_path)
    parts = boxes(gltf)
    width, depth, height = entry["size"]
    problems = []
    lines = []

    for socket in entry.get("sockets", []):
        if socket.get("kind") != "doorway":
            continue
        name = socket["name"]
        sx, sy, sz = socket["position"]
        dw, dh = socket.get("width", 2.4), socket.get("height", 3.2)
        ix, iz = inward(socket.get("yaw", 0.0))
        axis = 2 if iz else 0
        span = depth if axis == 2 else width
        along = sz if axis == 2 else sx
        label = "%s/%s" % (shell, name)

        # --- 1. on the room --------------------------------------------
        lo_bound = 0.0 if axis == 2 else -span / 2.0
        hi_bound = span if axis == 2 else span / 2.0
        if not (lo_bound - 1e-6 <= along <= hi_bound + 1e-6):
            problems.append(
                "%s: the doorway is at %.2f but the shell runs %.2f..%.2f "
                "on that axis -- it is %.2f m outside its own room, so "
                "ZoneBuilder joins the corridor over nothing."
                % (label, along, lo_bound, hi_bound,
                   max(lo_bound - along, along - hi_bound)))

        # --- 2. a clear opening, where there is a wall to cut ----------
        cross_axis = 0 if axis == 2 else 2
        cross_at = sx if axis == 2 else sz
        wall = [(nm, lo, hi) for nm, lo, hi in parts
                if lo[axis] - 1e-6 <= along <= hi[axis] + 1e-6
                and hi[1] > sy + 0.05
                and lo[cross_axis] - 1e-6 <= cross_at <= hi[cross_axis] + 1e-6]
        if wall:
            # Read at the wall's mid-thickness: at the face itself every
            # box merely touches the plane and nothing reads as solid.
            thickness = min(hi[axis] - lo[axis] for _, lo, hi in wall)
            probe = along - (iz or ix) * thickness / 2.0
            blocked = set()
            for i in range(SAMPLES):
                across = cross_at + dw * (i / (SAMPLES - 1.0) - 0.5) * 0.98
                for j in range(SAMPLES):
                    up = sy + 0.05 + (dh - 0.1) * j / (SAMPLES - 1.0)
                    point = ((across, up, probe) if axis == 2
                             else (probe, up, across))
                    blocked.update(solid_at(parts, *point))
            if blocked:
                problems.append(
                    "%s: the declared %.1f x %.1f m opening is blocked by "
                    "%s. A doorway nobody fits through is not a doorway."
                    % (label, dw, dh, ", ".join(sorted(blocked))))

        # --- 3. supported at the threshold -----------------------------
        gap = None
        for j in range(SAMPLES):
            step = REACH * j / (SAMPLES - 1.0)
            px = sx + ix * step
            pz = sz + iz * step
            if not standing_on(parts, px, pz, sy):
                gap = step
                break
        if gap is not None:
            problems.append(
                "%s: nothing to stand on %.2f m in from the doorway, at "
                "height %.2f. The floor stops before the threshold does."
                % (label, gap, sy))
        lines.append("  %-34s %-5s at [%.1f, %.1f, %.1f]  %s"
                     % (label, name, sx, sy, sz,
                        "supported" if gap is None else "UNSUPPORTED"))

    if verbose:
        for line in lines:
            print(line)
    return problems


def main():
    verbose = "--verbose" in sys.argv
    problems, seen = [], 0
    import glob
    for manifest in sorted(glob.glob(
            os.path.join(ROOT, "assets/models/*/shells/manifest.json"))):
        data = json.load(open(manifest))
        entries = data.get("assets", data)
        for shell, entry in sorted(entries.items()):
            if not isinstance(entry, dict) or "sockets" not in entry:
                continue
            glb = os.path.join(os.path.dirname(manifest), "%s.glb" % shell)
            if not os.path.exists(glb):
                problems.append("%s: no .glb at %s" % (shell, glb))
                continue
            seen += 1
            problems.extend(check(shell, entry, glb, verbose))

    if not seen:
        print("measure-doorways: FAIL -- no shell was measured at all, so "
              "this proved nothing.", file=sys.stderr)
        return 1

    fresh, matched = [], set()
    for problem in problems:
        door = problem.split(":", 1)[0]
        if door in KNOWN:
            matched.add(door)
            continue
        fresh.append(problem)

    for problem in fresh:
        print("measure-doorways: FAIL -- %s" % problem, file=sys.stderr)
    stale = sorted(set(KNOWN) - matched)
    for door in stale:
        print("measure-doorways: FAIL -- %s is listed as a known open "
              "finding and no longer measures as one. If it was repaired, "
              "delete its line from KNOWN in this file; a skip list nobody "
              "prunes is how the next three get through." % door,
              file=sys.stderr)
    if fresh or stale:
        return 1

    print("measure-doorways: %d shell(s), every doorway on its room, "
          "through a clear opening, and supported %.1f m back -- except %d "
          "reported and unauthorized (see KNOWN)."
          % (seen, REACH, len(KNOWN)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
