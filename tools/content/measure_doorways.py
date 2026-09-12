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

  1. **ON THE ROOM.** The socket lies within the shell's own envelope,
     **grown by the same slack Production allows** --
     `ChamberBuilders.WALL_THICKNESS + SPAN_TOLERANCE`, 0.405 m -- on all
     three axes, mirroring `ContentInstantiator.doorways_outside_envelope`.

     An earlier version of this file used a zero tolerance and reported
     `shell_yard_gantry` as a fourth instance of Production's defect. That
     was wrong twice over: their check reads all three axes, not depth
     only, and the yard's 0.40 m is INSIDE the slack. Being outside a
     zero-tolerance envelope is not by itself a defect and is not a reason
     to move an authored socket. What matters is whether the assembled
     crossing has a gap or an obstruction, which is what 2 and 3 measure.

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

## The slack Production's own envelope check allows, mirrored rather than
## invented: `ChamberBuilders.WALL_THICKNESS` (0.4) + `SPAN_TOLERANCE`
## (0.005), grown on all three axes. Keeping the two numbers the same is
## the point -- a stricter art-side envelope reports defects Production
## does not have, and a looser one misses the ones it does.
ENVELOPE_SLACK = 0.405

## What kind of thing went wrong. `KNOWN` matches on the PAIR of doorway
## and kind, so a doorway excused for a support gap is still checked for
## an obstruction and for its coordinate -- see KNOWN.
ENVELOPE = "envelope"
OBSTRUCTION = "obstruction"
SUPPORT = "support"
REACH = 1.0                # m back into the room that must hold a player
SAMPLES = 9                # across a door's width, and along the reach


## KNOWN, REPORTED, NOT YET AUTHORIZED.
##
## Keyed by `"<shell>/<doorway>:<kind>"`, and the kind is the part that
## matters. Keying on the doorway alone -- which this file did first --
## exempts that doorway's whole identity: a doorway excused for a support
## gap would go on silently passing if somebody later moved its socket 2 m
## into the air or built a wall across its opening, which is precisely the
## class of defect the file exists to catch. One known defect buys an
## exception for itself and for nothing else.
##
## Enforced in BOTH directions, the way Production's own test is: an entry
## that no longer measures as a defect FAILS, so a repair has to retire
## its exception rather than leave a skip behind for the next three to
## slip through.
KNOWN = {
    # Both corners: the floor stops 0.40 m short of the socket, which is
    # true geometry and NOT a demonstrated gap -- a player crosses both,
    # at the origin and placed and yawed, in `crossing_test.gd`. Reported
    # and left alone on the 2026-09-12 ruling: repair what the assembled
    # crossing demonstrates, not what a zero-tolerance rule dislikes.
    "shell_corner_left/exit:support":
        "cl_floor stops at x 3.00 and the socket is on the wall's outer "
        "face at 3.40 -- 0.40 m, and the crossing carries it",
    "shell_corner_right/exit:support":
        "cr_floor stops at x -3.00 and the socket is on the wall's outer "
        "face at -3.40 -- 0.40 m, and the crossing carries it",
    # The yard, after the 2026-09-12 threshold repair. Its floor used to
    # stop 1.60 m short and a player fell at 1.22 m, measured. The
    # threshold carries the first 1.20 m -- the inset and the wall -- and
    # the remaining 0.40 m is the socket standing proud of the wall, which
    # the crossing carries at 0.029 m and 0.053 m of dip. Building out to
    # the socket would have grown the shell from 85.20 m to 86.00 m, and a
    # doorway repair is not a reason to resize a room.
    "shell_yard_gantry/entry:support":
        "the socket stands 0.40 m proud of the wall face the threshold "
        "reaches -- crossed at 0.029 m of dip",
    "shell_yard_gantry/exit:support":
        "the socket stands 0.40 m proud of the wall face the threshold "
        "reaches -- crossed at 0.053 m of dip",
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


def doorway_problems(shell, size, sockets, parts):
    """Every defect in one shell's doorways, as (label, kind, message).

    Takes PARTS rather than a path so the self-test beside this file can
    hand it synthetic geometry -- an open control and a blocked one, in
    all four wall orientations -- instead of hoping the shipped shells
    happen to contain the case that would catch a bug.
    """
    width, depth, height = size
    problems = []

    for socket in sockets:
        if socket.get("kind") != "doorway":
            continue
        name = socket["name"]
        sx, sy, sz = socket["position"]
        dw, dh = socket.get("width", 2.4), socket.get("height", 3.2)
        ix, iz = inward(socket.get("yaw", 0.0))
        axis = 2 if iz else 0
        label = "%s/%s" % (shell, name)

        # --- 1. on the room, by Production's own slack -----------------
        # Their envelope is AABB((-w/2, 0, 0), (w, h, d)) grown by
        # WALL_THICKNESS + SPAN_TOLERANCE, tested on all three axes.
        lo = (-width / 2.0 - ENVELOPE_SLACK, -ENVELOPE_SLACK,
              -ENVELOPE_SLACK)
        hi = (width / 2.0 + ENVELOPE_SLACK, height + ENVELOPE_SLACK,
              depth + ENVELOPE_SLACK)
        at = (sx, sy, sz)
        worst = max(max(lo[k] - at[k], at[k] - hi[k]) for k in range(3))
        if worst > 0.0:
            problems.append((label, ENVELOPE,
                "%s: the doorway is %.2f m outside its own envelope even "
                "with Production's %.3f m of slack, so ZoneBuilder joins "
                "the corridor over nothing." % (label, worst, ENVELOPE_SLACK)))

        # --- 2. a clear opening, where there is a wall to cut ----------
        cross_axis = 0 if axis == 2 else 2
        cross_at = sx if axis == 2 else sz
        wall = [(nm, blo, bhi) for nm, blo, bhi in parts
                if blo[axis] - 1e-6 <= at[axis] <= bhi[axis] + 1e-6
                and bhi[1] > sy + 0.05
                and blo[cross_axis] - 1e-6 <= cross_at <= bhi[cross_axis] + 1e-6]
        if wall:
            # INWARD by half the wall's thickness, into the middle of it.
            #
            # This read `along - (iz or ix) * thickness / 2` and stepped
            # the other way -- out past the face, into open air, where
            # nothing is solid and every doorway passed however completely
            # a wall filled it. `inward()` returns the direction the ROOM
            # is in, so reaching the wall's middle is a step ALONG it.
            thickness = min(bhi[axis] - blo[axis] for _, blo, bhi in wall)
            probe = at[axis] + (iz or ix) * thickness / 2.0
            blocked = set()
            for i in range(SAMPLES):
                across = cross_at + dw * (i / (SAMPLES - 1.0) - 0.5) * 0.98
                for j in range(SAMPLES):
                    up = sy + 0.05 + (dh - 0.1) * j / (SAMPLES - 1.0)
                    point = ((across, up, probe) if axis == 2
                             else (probe, up, across))
                    blocked.update(solid_at(parts, *point))
            if blocked:
                problems.append((label, OBSTRUCTION,
                    "%s: the declared %.1f x %.1f m opening is blocked by "
                    "%s. A doorway nobody fits through is not a doorway."
                    % (label, dw, dh, ", ".join(sorted(blocked)))))

        # --- 3. supported at the threshold -----------------------------
        gap = None
        for j in range(SAMPLES):
            step = REACH * j / (SAMPLES - 1.0)
            if not standing_on(parts, sx + ix * step, sz + iz * step, sy):
                gap = step
                break
        if gap is not None:
            problems.append((label, SUPPORT,
                "%s: nothing to stand on %.2f m in from the doorway, at "
                "height %.2f. The floor stops before the threshold does."
                % (label, gap, sy)))

    return problems


def check(shell, entry, glb_path, verbose=False):
    parts = boxes(read_glb(glb_path))
    problems = doorway_problems(shell, entry["size"],
                                entry.get("sockets", []), parts)
    if verbose:
        hit = {}
        for label, kind, _ in problems:
            hit.setdefault(label, []).append(kind)
        for socket in entry.get("sockets", []):
            if socket.get("kind") != "doorway":
                continue
            label = "%s/%s" % (shell, socket["name"])
            kinds = hit.get(label, [])
            print("  %-34s at [%.1f, %.1f, %.1f]  %s"
                  % (label, socket["position"][0], socket["position"][1],
                     socket["position"][2],
                     "ok" if not kinds else ", ".join(sorted(kinds)).upper()))
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
                problems.append((shell, "missing",
                             "%s: no .glb at %s" % (shell, glb)))
                continue
            seen += 1
            problems.extend(check(shell, entry, glb, verbose))

    if not seen:
        print("measure-doorways: FAIL -- no shell was measured at all, so "
              "this proved nothing.", file=sys.stderr)
        return 1

    fresh, matched = [], set()
    for label, kind, message in problems:
        key = "%s:%s" % (label, kind)
        if key in KNOWN:
            matched.add(key)
            continue
        fresh.append(message)

    for message in fresh:
        print("measure-doorways: FAIL -- %s" % message, file=sys.stderr)
    stale = sorted(set(KNOWN) - matched)
    for key in stale:
        print("measure-doorways: FAIL -- %s is listed as a known open "
              "finding and no longer measures as one. If it was repaired, "
              "delete its line from KNOWN in this file; a skip list nobody "
              "prunes is how the next three get through." % key,
              file=sys.stderr)
    if fresh or stale:
        return 1

    print("measure-doorways: %d shell(s), every doorway inside Production's "
          "envelope slack, through a clear opening, and supported %.1f m "
          "back -- except %d reported and unauthorized (see KNOWN)."
          % (seen, REACH, len(KNOWN)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
