#!/usr/bin/env python3
"""Refuse to design against stale numbers.

    python3 tools/graybox/verify_dims.py <path to a checkout carrying assets/art_budgets.json>

Compares every key `engine_dims.json` shares with that repo's
`art_budgets.json["dimensions"]` and exits 1 on any drift.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
pinned = json.load(open(os.path.join(HERE, "engine_dims.json")))
root = sys.argv[1] if len(sys.argv) > 1 else "."
live = json.load(open(os.path.join(root, "assets", "art_budgets.json")))["dimensions"]
drift = []
for k, v in pinned.items():
    if k in live and isinstance(v, (int, float)) and abs(float(live[k]) - float(v)) > 1e-6:
        drift.append("%s: pinned %s, live %s" % (k, v, live[k]))
for k in ("jump_apex", "safe_base_jump_gap", "max_vertical_step", "player_height", "player_radius", "wall_thickness"):
    if k not in live:
        drift.append("%s: missing from the live dimensions" % k)
if drift:
    print("engine_dims: DRIFT\n  " + "\n  ".join(drift))
    raise SystemExit(1)
print("engine_dims: every shared number matches %s" % root)
