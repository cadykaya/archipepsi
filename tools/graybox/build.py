#!/usr/bin/env python3
"""Build one graybox room: .glb + manifest + plan/section SVGs + preflight.

    python3 tools/graybox/build.py tools/graybox/rooms/<id>.py [--out assets/graybox/large]

A room spec is a Python file exposing `build() -> gbkit.Room`.  Outputs go
to <out>/<cid>/: <cid>.glb, manifest.json, plan.svg, section_z.svg,
section_x.svg, preflight.json, README.md.  Exit status is 1 when the
preflight has errors, so a spec that cannot keep its promises fails here.
"""
from __future__ import annotations

import importlib.util
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gbkit  # noqa: E402

REPO = os.path.dirname(os.path.dirname(HERE))


def load_spec(path):
    spec = importlib.util.spec_from_file_location("room_spec", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.build()


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    out_root = os.path.join(REPO, "assets", "graybox", "large")
    if "--out" in argv:
        out_root = argv[argv.index("--out") + 1]
    status = 0
    for spec_path in [a for a in argv[1:] if a.endswith(".py")]:
        room = load_spec(spec_path)
        out = os.path.join(out_root, room.cid)
        os.makedirs(out, exist_ok=True)
        glb = os.path.join(out, room.cid + ".glb")
        size = gbkit.write_glb(room, glb)
        rel = os.path.relpath(glb, REPO)
        man = gbkit.manifest(room, rel)
        with open(os.path.join(out, "manifest.json"), "w", encoding="utf-8") as fh:
            json.dump(man, fh, indent=2, sort_keys=True)
        gbkit.write_plan_svg(room, os.path.join(out, "plan.svg"))
        gbkit.write_section_svg(room, os.path.join(out, "section_z.svg"), "z")
        gbkit.write_section_svg(room, os.path.join(out, "section_x.svg"), "x")
        report = gbkit.preflight(room)
        with open(os.path.join(out, "preflight.json"), "w", encoding="utf-8") as fh:
            json.dump(report, fh, indent=2, sort_keys=True)
        info = report["info"]
        lines = ["# %s (graybox)" % room.cid, ""]
        if room.thesis:
            lines += ["**Thesis.** " + room.thesis, ""]
        if room.first_read:
            lines += ["**First read.** " + room.first_read, ""]
        lines += ["| | |", "|---|---|",
                  "| interior W x H x D | %s m (%s m3) |" % (" x ".join("%g" % v for v in info["interior_m"]), info["interior_volume_m3"]),
                  "| outer size | %s m |" % " x ".join("%g" % v for v in info["outer_size_m"]),
                  "| parts / colliders | %d / %d |" % (info["counts"]["parts"], info["counts"]["colliders"]),
                  "| surfaces / traversal / offers / sockets | %d / %d / %d / %d (caps 32/32/32) |" % (
                      info["counts"]["surfaces"], info["counts"]["traversal"], info["counts"]["offers"], info["counts"]["sockets"]),
                  "| exit | y %g, yaw %g |" % (room.exit_y, room.exit_yaw),
                  "| lowest floor | y %s (nothing falls forever iff >= -1.0) |" % info["lowest_floor_y"],
                  "| glb bytes | %d |" % size, ""]
        for name, st in info.get("rails", {}).items():
            lines.append("- rail `%s`: %s m, worst baked pitch %s deg, height range %s m, %s control points" % (
                name, st.get("length_m"), st.get("worst_pitch_deg"), st.get("height_range_m"), st.get("control_points")))
        for name, st in info.get("launches", {}).items():
            lines.append("- launch `%s`: %s m span, %s s flight, apex y %s" % (name, st["span_m"], st["flight_s"], st["apex_y"]))
        for who, dist in info.get("sightlines", {}).items():
            lines.append("- sightline `%s`: clear across %s m" % (who, dist))
        if info.get("walks_unproven_at_import"):
            lines.append("- walks unproven under IMPORT (hull-box) evidence: %s" % ", ".join(info["walks_unproven_at_import"]))
        lines.append("")
        lines.append("## Preflight: %d error(s), %d warning(s)" % (len(report["errors"]), len(report["warnings"])))
        for e in report["errors"]:
            lines.append("- ERROR " + e)
        for w in report["warnings"]:
            lines.append("- warn  " + w)
        for n in room.notes:
            lines.append("- note  " + n)
        with open(os.path.join(out, "README.md"), "w", encoding="utf-8") as fh:
            fh.write("\n".join(lines) + "\n")
        print("[graybox] %-28s %2d err %2d warn  %s" % (room.cid, len(report["errors"]), len(report["warnings"]), rel))
        for e in report["errors"]:
            print("    ERROR", e)
        for w in report["warnings"]:
            print("    warn ", w)
        if report["errors"]:
            status = 1
    return status


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
