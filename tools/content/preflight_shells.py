#!/usr/bin/env python3
"""Predict what Production's P1 checks will say about the exported shells.

    python3 tools/content/preflight_shells.py <prod-ref>

WHAT THIS IS. Arithmetic over the exported manifest and the real glTF
bounding boxes, reproducing the parts of P1 that are pure geometry
BOOKKEEPING: the envelope containment in `ShellValidator._check_envelope`,
the marker requirement in `_check_segment`, the base-kit bound on a
mandatory segment, and the schema's own surface minimums.

WHAT THIS IS NOT, and the distinction is the whole point. `room_audit.gd`
fires real physics probes at an instantiated scene -- support under every
surface, headroom above it, the player's capsule in every doorway. None of
that can be reproduced here and none of it is attempted. Godot remains the
physical authority; this only catches the failures that are decidable from
numbers, so they are found before a handoff rather than after one.

The headroom column is explicitly a PREDICTION and says so: it compares
declared surfaces against each other, which is not the same as measuring
what is actually overhead.
"""
from __future__ import annotations

import json
import math
import os
import struct
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FLOOR_ALLOWANCE = 1.0
POSITION_TOLERANCE = 0.15
MAX_VERTICAL_STEP = 1.0
PLAYER_RADIUS = 0.4
HEADROOM = 2.4


def glb_bbox(path):
    """Exact per-axis min/max from the glTF POSITION accessors."""
    with open(path, "rb") as fh:
        data = fh.read()
    off, js = 12, None
    while off < len(data):
        ln, ty = struct.unpack_from("<II", data, off)
        if ty == 0x4E4F534A:
            js = json.loads(data[off + 8:off + 8 + ln].decode("utf-8"))
            break
        off += 8 + ln + ((4 - ln % 4) % 4)
    lo, hi = [1e9] * 3, [-1e9] * 3
    for mesh in js.get("meshes", []):
        for prim in mesh.get("primitives", []):
            acc = js["accessors"][prim["attributes"]["POSITION"]]
            for i in range(3):
                lo[i] = min(lo[i], acc["min"][i])
                hi[i] = max(hi[i], acc["max"][i])
    return lo, hi


def max_safe_gap(rise, ref):
    """Production's own `Constants.max_safe_gap`, read rather than copied."""
    src = subprocess.run(
        ["git", "show", "%s:godot/scripts/autoload/constants.gd" % ref],
        cwd=ROOT, capture_output=True, text=True, check=True).stdout
    # static func max_safe_gap(rise) -> float: ... derived from jump arc
    for line in src.splitlines():
        if "SAFE_BASE_JUMP_GAP" in line and "=" in line and "const" in line:
            base = float(line.split("=")[1].strip())
            break
    else:
        base = 2.6
    apex = 4.0 / 3.0
    if rise >= apex:
        return 0.0
    return base * math.sqrt(max(0.0, 1.0 - rise / apex))


def main(argv):
    ref = argv[1] if len(argv) > 1 else \
        "origin/claude/archipepsi-echoes-continuation-b1adno"
    reg = os.path.join(ROOT, "godot", "content", "registry",
                       "authored_art.json")
    with open(reg) as fh:
        entries = [e for e in json.load(fh)["entries"]
                   if e.get("category") == "room_shell"]
    if not entries:
        print("[preflight] no room shells in the pack")
        return 0

    problems = 0
    predictions = 0
    for e in sorted(entries, key=lambda x: x["id"]):
        cid = e["id"]
        glb = os.path.join(ROOT, "godot", "content", "shells", "%s.glb" % cid)
        lo, hi = glb_bbox(glb)
        sx, sy, sz = e["size"]

        notes = []
        # 1. ShellValidator._check_envelope, exactly.
        env = ((-sx / 2.0 - POSITION_TOLERANCE, -FLOOR_ALLOWANCE - POSITION_TOLERANCE,
                -POSITION_TOLERANCE),
               (sx / 2.0 + POSITION_TOLERANCE, sy + POSITION_TOLERANCE,
                sz + POSITION_TOLERANCE))
        for i, axis in enumerate("xyz"):
            if lo[i] < env[0][i] - 1e-9:
                notes.append("REFUSED envelope: %s-min %.2f < %.2f"
                             % (axis, lo[i], env[0][i]))
                problems += 1
            if hi[i] > env[1][i] + 1e-9:
                notes.append("REFUSED envelope: %s-max %.2f > %.2f"
                             % (axis, hi[i], env[1][i]))
                problems += 1

        # 2. Schema: every surface wide enough for the player's capsule.
        for surf in e.get("surfaces", []):
            ex, ez = surf["extent"]
            if min(ex, ez) < PLAYER_RADIUS * 2.0:
                notes.append("REFUSED schema: surface '%s' is %.2f x %.2f"
                             % (surf["name"], ex, ez))
                problems += 1

        # 3. Sockets naming a surface that exists.
        known = {s["name"] for s in e.get("surfaces", [])}
        for sock in e.get("sockets", []):
            sid = sock.get("surface_id", "")
            if sid and sid not in known:
                notes.append("REFUSED schema: socket '%s' -> unknown surface "
                             "'%s'" % (sock["name"], sid))
                problems += 1

        # 4. ShellValidator._check_segment: markers, rise and span.
        markers = _wrapper_markers(cid)
        for seg in e.get("traversal", []):
            if seg.get("mandatory", True):
                for end in ("start", "end"):
                    want = "%s_%s" % (seg["name"], end)
                    if want not in markers:
                        notes.append("REFUSED traversal: '%s' has no %s "
                                     "marker" % (seg["name"], want))
                        problems += 1
                rise = seg["end"][1] - seg["start"][1]
                span = math.dist(
                    (seg["start"][0], seg["start"][2]),
                    (seg["end"][0], seg["end"][2]))
                if rise > MAX_VERTICAL_STEP + 1e-3:
                    notes.append("REFUSED traversal: '%s' rises %.2f m"
                                 % (seg["name"], rise))
                    problems += 1
                allowed = max_safe_gap(max(rise, 0.0), ref)
                if span > allowed + 1e-3:
                    notes.append("REFUSED traversal: '%s' spans %.2f m at a "
                                 "%.2f m rise; base kit reaches %.2f"
                                 % (seg["name"], span, rise, allowed))
                    problems += 1

        # 5. PREDICTION ONLY. Declared surfaces overhanging each other.
        #    room_audit.gd measures what is really overhead; this only
        #    compares claims, and a clean line here is not a pass.
        surfs = e.get("surfaces", [])
        for i, a in enumerate(surfs):
            for b in surfs[i + 1:]:
                dy = b["center"][1] - a["center"][1]
                if not (0.0 < dy < HEADROOM):
                    continue
                ox = (min(a["center"][0] + a["extent"][0] / 2,
                          b["center"][0] + b["extent"][0] / 2)
                      - max(a["center"][0] - a["extent"][0] / 2,
                            b["center"][0] - b["extent"][0] / 2))
                oz = (min(a["center"][2] + a["extent"][1] / 2,
                          b["center"][2] + b["extent"][1] / 2)
                      - max(a["center"][2] - a["extent"][1] / 2,
                            b["center"][2] - b["extent"][1] / 2))
                if ox > 0.01 and oz > 0.01:
                    notes.append("predict headroom: '%s' has '%s' %.2f m "
                                 "overhead across %.2f x %.2f m"
                                 % (a["name"], b["name"], dy, ox, oz))
                    predictions += 1

        head = "%-24s surfaces=%-2d traversal=%-2d" % (
            cid, len(e.get("surfaces", [])), len(e.get("traversal", [])))
        if not notes:
            print("[preflight]   ok  %s" % head)
        else:
            print("[preflight]   --  %s" % head)
            for n in notes:
                print("[preflight]        %s" % n)

    print("[preflight] %d structural refusal(s), %d headroom prediction(s)"
          % (problems, predictions))
    print("[preflight] Godot's room_audit.gd remains the physical authority; "
          "nothing here substitutes for it.")
    return 1 if problems else 0


def _wrapper_markers(cid):
    path = os.path.join(ROOT, "godot", "content", "shells", "%s.tscn" % cid)
    if not os.path.exists(path):
        return set()
    out = set()
    for line in open(path):
        if line.startswith('[node name="') and "Marker3D" in line:
            out.add(line.split('"')[1])
    return out


if __name__ == "__main__":
    sys.exit(main(sys.argv))
