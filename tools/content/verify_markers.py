"""Do the shipped `.tscn` Marker3Ds still say what the manifest says?

    python3 tools/content/verify_markers.py

WHY THIS EXISTS. `shell_hall_transit` was repaired at `3b7bb02` and the
manifest, the mesh and the collision all agreed -- but the scene was not
regenerated, because `export_content_pack.py` writes the manifest and
`export_content_pack.sh` is what also runs `wrap_content.gd` to write the
`.tscn`. Only the first was run. Production found it at `94d562d`: four
traversal declarations differed between the new manifest and the stale
scene markers, eight endpoints in all.

`ShellValidator._check_segment` measures a segment from its MARKERS, not
from the manifest, so a stale scene does not fail loudly -- it quietly
certifies the room that used to exist. Nothing in the art lane compared
the two, and the two-command export made forgetting the second one a
one-keystroke mistake.

This is the comparison, and it is cheap: parse the marker transforms out
of the generated scene and hold them against the manifest that ought to
have produced them.

NOT A PHYSICS CHECK. It says the scene and the manifest agree, nothing
more. Whether the endpoints are standable is `traversallaw` at build
time and `RoomAudit` in the engine.
"""

from __future__ import annotations

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))
CONTENT = os.path.join(ROOT, "godot", "content")
REGISTRY = os.path.join(CONTENT, "registry", "authored_art.json")

#: Godot writes a Marker3D's placement as
#: `transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, x, y, z)`; the
#: last three of the twelve are the origin.
_NODE = re.compile(r'\[node name="([^"]+)" type="Marker3D"[^\]]*\]'
                   r'(.*?)(?=\n\[node |\Z)', re.S)
_XFORM = re.compile(r"transform\s*=\s*Transform3D\(([^)]*)\)")

#: How far a marker may sit from its declared endpoint. Tight on purpose:
#: this is a generated-file consistency check, not a tolerance for
#: geometry, and the numbers come from the same JSON on both sides.
TOLERANCE = 1e-3


def markers(scene_path):
    with open(scene_path, encoding="utf-8") as handle:
        text = handle.read()
    out = {}
    for name, body in _NODE.findall(text):
        hit = _XFORM.search(body)
        if hit is None:
            out[name] = None
            continue
        nums = [float(v) for v in hit.group(1).split(",")]
        out[name] = tuple(nums[-3:])
    return out


def main(argv):
    with open(REGISTRY, encoding="utf-8") as handle:
        entries = json.load(handle)["entries"]
    problems, checked, scenes = [], 0, 0
    for entry in sorted(entries, key=lambda e: e["id"]):
        if entry.get("category") != "room_shell":
            continue
        scene = os.path.join(CONTENT, entry["scene"].replace("res://content/", ""))
        if not os.path.exists(scene):
            problems.append("%s: names scene '%s', which does not exist"
                            % (entry["id"], entry["scene"]))
            continue
        scenes += 1
        found = markers(scene)
        want = {}
        for seg in entry.get("traversal", []):
            want["%s_start" % seg["name"]] = tuple(seg["start"])
            want["%s_end" % seg["name"]] = tuple(seg["end"])
        for key, position in sorted(want.items()):
            checked += 1
            if key not in found:
                problems.append("%s: the manifest declares '%s' and the "
                                "scene has no such marker" % (entry["id"], key))
                continue
            at = found[key]
            if at is None:
                problems.append("%s: marker '%s' carries no transform"
                                % (entry["id"], key))
                continue
            drift = max(abs(a - b) for a, b in zip(at, position))
            if drift > TOLERANCE:
                problems.append(
                    "%s: '%s' is declared at %s and the scene puts it at "
                    "%s (%.3f m out) -- the scene is stale, or the manifest "
                    "is" % (entry["id"], key,
                            tuple(round(v, 3) for v in position),
                            tuple(round(v, 3) for v in at), drift))
        extra = sorted(k for k in found
                       if k.endswith(("_start", "_end")) and k not in want)
        for key in extra:
            problems.append("%s: the scene carries marker '%s' that the "
                            "manifest no longer declares" % (entry["id"], key))

    for line in problems:
        print("[markers]   %s" % line)
    print("[markers] %d marker(s) across %d scene(s), %d disagreement(s)"
          % (checked, scenes, len(problems)))
    if problems:
        print("[markers] FAIL -- regenerate with tools/export_content_pack.sh, "
              "which wraps the scenes; export_content_pack.py alone writes "
              "only the manifest")
        return 1
    print("[markers] PASS -- every scene marker matches its manifest "
          "declaration")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
