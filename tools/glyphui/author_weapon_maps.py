#!/usr/bin/env python3
"""A developed weapon's material maps, held and exported by Glyph.
(Arty, 2026-10-13.) Same workflow as the approved Foundry study.

    GLYPH_ROOT=/home/user/glyph-trial \
        python3 tools/glyphui/author_weapon_maps.py OUT WEAPON

Reads OUT/paint/ (from `tools/blender/weapon_paint.py`) and writes
OUT/maps/ -- what the model wears -- plus OUT/maps/maps.json. Exactly the
Foundry study's route (`author_foundry_study_maps.py`, whose helpers this
uses unchanged): one Glyph asset, one variant per map, each declaring its
role; the colour map reduced to a 256-entry palette and written in patches
of at most 90 symbols; the normal map derived by Glyph itself
(`x-glyph.normal_from_height`); `x-glyph.check_material` clean before
anything is exported; every map leaves through Glyph's own export.
"""

from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import author_foundry_study_maps as fsm  # noqa: E402
import glyphrun  # noqa: E402

# Glyph's batch runner reads a string that starts with "$" and a digit as a
# citation of an earlier result ("$1.preset"), so a patch row that happens
# to begin with the symbol "$" followed by "2" was taken for one and the
# batch refused (found on the Switchback, 2026-10-13). "$" leaves the patch
# alphabet; the exported pixels do not change. (The Foundry study's own run
# never drew a row like that; its maps are untouched.)
fsm.ALPHABET = [c for c in fsm.ALPHABET if c != "$"]


def main():
    out = os.path.abspath(sys.argv[1])
    weapon = sys.argv[2]
    paint_dir = os.path.join(out, "paint")
    maps_dir = os.path.join(out, "maps")
    os.makedirs(maps_dir, exist_ok=True)
    root = os.environ.get("GLYPH_ROOT", "/home/user/glyph-trial")
    work = tempfile.mkdtemp(prefix="glyphwm_")
    ses = glyphrun.Session(root, work, "archipepsi_%s_dev.glyph" % weapon,
                           fsm.OWNER, fsm.ARTIST)
    ses.create("the art lane paints the %s's maps" % weapon)
    asset = ses.txn({"creates": ["asset"]}, [
        ("asset.create", {"name": "%s_dev" % weapon})],
        "the %s's material" % weapon)[0]["asset"]["id"]
    record, variants = {}, {}
    w = h = 0
    for name, rep, how in fsm.MAPS:
        rgba = fsm._rgba(os.path.join(paint_dir, name + ".png"), how)
        h, w = rgba.shape[:2]
        vid, cel = fsm._variant(ses, asset, name, rep, w, h)
        n = fsm._write(ses, cel, rgba, name)
        variants[name] = vid
        record[name] = {"representation": rep, "size": [w, h],
                        "colours": int(len(np.unique(
                            rgba.reshape(-1, 4), axis=0))),
                        "patches": n}
        print("[wmaps] %s %-9s %-14s %d colour(s), %d patch(es)"
              % (weapon, name, rep, record[name]["colours"], n))
    strength = fsm.foundry_paint.NORMAL_STRENGTH
    derived = ses.run("x-glyph.normal_from_height", {
        "variant": variants["height"], "strength": strength,
        "handedness": "opengl", "wrap": False})
    res = derived.get("result", derived)
    px = np.asarray(res["pixels"], dtype=np.uint32).reshape(h, w)
    nrgba = np.stack([(px >> 24) & 255, (px >> 16) & 255, (px >> 8) & 255,
                      px & 255], -1).astype(np.uint8)
    vid, cel = fsm._variant(ses, asset, "normal", "normal_map", w, h)
    n = fsm._write(ses, cel, nrgba, "normal")
    variants["normal"] = vid
    record["normal"] = {"representation": "normal_map", "size": [w, h],
                        "derived": "x-glyph.normal_from_height",
                        "strength": strength, "handedness": "opengl",
                        "kernel": res.get("kernel", "sobel"),
                        "patches": n}
    print("[wmaps] %s normal derived by Glyph, %d patch(es)" % (weapon, n))
    check = ses.run("x-glyph.check_material", {
        "asset": asset, "colour_representation": "world_texture",
        "expect": ["normal_map", "height_map", "roughness_map",
                   "metallic_map", "emission_map"]})
    cres = check.get("result", check)
    faults = cres.get("faults", [])
    if faults:
        raise SystemExit("[wmaps] check_material refused:\n  "
                         + "\n  ".join(json.dumps(f) for f in faults))
    print("[wmaps] %s check_material: clean" % weapon)
    for name in list(variants):
        fsm._export(ses, variants[name], name, w, h,
                    os.path.join(maps_dir, name + ".png"))
    record["_kit"] = {
        "status": "DEVELOPMENT MODEL (Arty, 2026-10-13)",
        "glyph": "ECMS Glyph CLI, revision %s" % fsm._revision(root),
        "check_material": "clean",
        "note": "Albedo palette: 256 colours, median cut, no dither. The "
                "normal map is Glyph's own (x-glyph.normal_from_height).",
    }
    with open(os.path.join(maps_dir, "maps.json"), "w") as fh:
        json.dump(record, fh, indent=1, sort_keys=True)
        fh.write("\n")
    print("[wmaps] %s: %d map(s) + maps.json -> %s"
          % (weapon, len(variants), maps_dir))
    if not os.environ.get("GLYPH_KEEP_WORK"):
        shutil.rmtree(work)


if __name__ == "__main__":
    main()
