#!/usr/bin/env python3
"""The Foundry fidelity study's material maps, held and exported by Glyph.
(Arty, 2026-10-13.) NON-PRODUCTION STUDY.

    GLYPH_ROOT=/home/user/glyph-trial python3 tools/glyphui/author_foundry_study_maps.py OUT

Reads the painter's maps (OUT/paint/, from `tools/blender/foundry_paint.py`)
and writes OUT/maps/ -- what the model wears -- plus OUT/maps/maps.json.

WHAT GLYPH DOES HERE, AND WHY IT IS GLYPH. The owner asked for
Glyph-authored textures through the existing material workflow
(2026-10-13). So, as with the weapon effects (`author_weapon_fx.py`):
Python paints, and Glyph holds the result:

  * one asset, one variant per map, each DECLARING its role
    (`representation`: world_texture, height_map, roughness_map,
    metallic_map, emission_map, normal_map) -- the pairing is declared,
    never inferred from a file name;
  * the colour map is reduced to a 256-entry palette first, as a GoldSrc
    skin was, and written in patches of at most 90 symbols (the patch
    format's limit, not the palette's);
  * the NORMAL MAP IS GLYPH'S: `x-glyph.normal_from_height` derives it from
    the height variant (Sobel, OpenGL-handed, the strength stated), and
    the pixels it returns are written into the normal_map variant;
  * `x-glyph.check_material` must pass (sizes agree, single-value maps
    carry no colour, normals are unit length) before anything is exported;
  * every map leaves through Glyph's own export.

The art bible (§5) says albedo only. The owner asked for roughness and
normal detail for this study; the bible is unchanged and the report says so.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))), "blender"))

import glyphrun  # noqa: E402
import foundry_paint  # noqa: E402

OWNER = "skyiah"
ARTIST = "arty"
ALPHABET = [chr(c) for c in range(0x21, 0x7f) if chr(c) not in '.-"\\ ']
TILE = 512
#: (map, representation, how the painter's PNG becomes RGBA)
MAPS = [
    ("albedo", "world_texture", "palette"),
    ("height", "height_map", "grey"),
    ("roughness", "roughness_map", "grey"),
    ("metallic", "metallic_map", "grey"),
    ("emission", "emission_map", "rgb"),
]
COLOURS = 256


def _rgba(path, how):
    img = Image.open(path)
    if how == "palette":
        # the colour map's palette: median cut, no dither (a GoldSrc skin)
        img = img.convert("RGB").quantize(colors=COLOURS,
                                          method=Image.Quantize.MEDIANCUT,
                                          dither=Image.Dither.NONE)
        img = img.convert("RGB")
    elif how == "grey":
        g = np.asarray(img.convert("L"))
        img = Image.fromarray(np.stack([g, g, g], -1))
    a = np.asarray(img.convert("RGB"), dtype=np.uint8)
    return np.concatenate([a, np.full(a.shape[:2] + (1,), 255, np.uint8)],
                          -1)


def _patches(rgba):
    """Dense patches, one tile and at most 90 colours at a time, every
    other cell left alone ('.' = NO_CHANGE)."""
    h, w = rgba.shape[:2]
    words = (rgba[..., 0].astype(np.uint32) << 24 | rgba[..., 1].astype(
        np.uint32) << 16 | rgba[..., 2].astype(np.uint32) << 8
             | rgba[..., 3].astype(np.uint32))
    out = []
    for y0 in range(0, h, TILE):
        for x0 in range(0, w, TILE):
            tile = words[y0:y0 + TILE, x0:x0 + TILE]
            th, tw = tile.shape
            colours = np.unique(tile)
            for c0 in range(0, len(colours), len(ALPHABET)):
                chunk = colours[c0:c0 + len(ALPHABET)]
                idx = np.searchsorted(chunk, tile)
                idx = np.clip(idx, 0, len(chunk) - 1)
                inside = chunk[idx] == tile
                if not inside.any():
                    continue
                sym = np.array(ALPHABET[:len(chunk)] + ["."])
                grid = np.where(inside, idx, len(chunk))
                rows = ["".join(sym[r]) for r in grid]
                symbols = {ALPHABET[i]: {"rgba": [int(c >> 24 & 255),
                                                  int(c >> 16 & 255),
                                                  int(c >> 8 & 255),
                                                  int(c & 255)]}
                           for i, c in enumerate(chunk)}
                # declare only symbols the rows use (a patch may not
                # declare an unused one)
                used = set(np.unique(grid[inside]).tolist())
                symbols = {ALPHABET[i]: symbols[ALPHABET[i]] for i in used}
                out.append({"form": "dense", "origin": [x0, y0],
                            "size": [tw, th], "symbols": symbols,
                            "rows": rows})
    return out


def _revision(root):
    out = subprocess.run(["git", "-C", root, "rev-parse", "--short=7",
                          "HEAD"], capture_output=True, text=True)
    return out.stdout.strip() or "unknown"


def _variant(ses, asset, name, rep, w, h):
    made = ses.txn({"creates": ["variant"]}, [
        ("variant.create", {"name": name, "width": w, "height": h,
                            "color_mode": "rgba", "asset": asset,
                            "representation": rep})], "the %s map" % name)
    v = made[0]["variant"]
    return v["id"], v["cels"][0]


def _write(ses, cel, rgba, label):
    patches = _patches(rgba)
    # a few patches per transaction keeps each batch file a sane size
    for i in range(0, len(patches), 6):
        ses.txn({"cels": [cel]}, [("pixels.apply_patch",
                                   {"cel": cel, "patch": p})
                                  for p in patches[i:i + 6]],
                "%s, painted (%d/%d)" % (label, min(i + 6, len(patches)),
                                         len(patches)))
    return len(patches)


def _export(ses, variant, name, w, h, dest):
    results = ses.batch([
        {"command": "export.define_preset",
         "input": ses.sheet_preset("fs_%s" % name, [variant], w, h)},
        {"command": "export.run",
         "input": {"preset": "$1.preset", "destination": ses.work}},
    ], label=name)
    before = set(f for f in os.listdir(ses.work) if f.endswith(".png"))
    ses.write_export(results[1]["record"], label=name)
    fresh = sorted(set(f for f in os.listdir(ses.work)
                       if f.endswith(".png")) - before)
    if len(fresh) != 1:
        raise SystemExit("%s exported %d page(s)" % (name, len(fresh)))
    shutil.move(os.path.join(ses.work, fresh[0]), dest)


def main():
    out = os.path.abspath(sys.argv[1])
    paint_dir = os.path.join(out, "paint")
    maps_dir = os.path.join(out, "maps")
    os.makedirs(maps_dir, exist_ok=True)
    root = os.environ.get("GLYPH_ROOT", "/home/user/glyph-trial")
    work = tempfile.mkdtemp(prefix="glyphfs_")
    ses = glyphrun.Session(root, work, "archipepsi_foundry_study.glyph",
                           OWNER, ARTIST)
    ses.create("the art lane paints the Foundry fidelity study's maps")
    asset = ses.txn({"creates": ["asset"]}, [
        ("asset.create", {"name": "foundry_study"})],
        "the Foundry study's material")[0]["asset"]["id"]

    record, variants = {}, {}
    for name, rep, how in MAPS:
        rgba = _rgba(os.path.join(paint_dir, name + ".png"), how)
        h, w = rgba.shape[:2]
        vid, cel = _variant(ses, asset, name, rep, w, h)
        n = _write(ses, cel, rgba, name)
        variants[name] = vid
        record[name] = {"representation": rep, "size": [w, h],
                        "colours": int(len(np.unique(
                            rgba.reshape(-1, 4), axis=0))),
                        "patches": n}
        print("[fsmaps] %-9s %-14s %d colour(s), %d patch(es)"
              % (name, rep, record[name]["colours"], n))

    # the normal map: Glyph derives it from the height variant
    strength = foundry_paint.NORMAL_STRENGTH
    derived = ses.run("x-glyph.normal_from_height", {
        "variant": variants["height"], "strength": strength,
        "handedness": "opengl", "wrap": False})
    res = derived.get("result", derived)
    px = np.asarray(res["pixels"], dtype=np.uint32).reshape(h, w)
    nrgba = np.stack([(px >> 24) & 255, (px >> 16) & 255, (px >> 8) & 255,
                      px & 255], -1).astype(np.uint8)
    vid, cel = _variant(ses, asset, "normal", "normal_map", w, h)
    n = _write(ses, cel, nrgba, "normal")
    variants["normal"] = vid
    record["normal"] = {"representation": "normal_map", "size": [w, h],
                        "derived": "x-glyph.normal_from_height",
                        "strength": strength, "handedness": "opengl",
                        "kernel": res.get("kernel", "sobel"),
                        "colours": int(len(np.unique(nrgba.reshape(-1, 4),
                                                     axis=0))),
                        "patches": n}
    print("[fsmaps] normal    normal_map     derived by Glyph (strength %s),"
          " %d patch(es)" % (strength, n))

    check = ses.run("x-glyph.check_material", {
        "asset": asset, "colour_representation": "world_texture",
        "expect": ["normal_map", "height_map", "roughness_map",
                   "metallic_map", "emission_map"]})
    cres = check.get("result", check)
    faults = cres.get("faults", [])
    if faults:
        raise SystemExit("[fsmaps] check_material refused:\n  "
                         + "\n  ".join(json.dumps(f) for f in faults))
    print("[fsmaps] check_material: clean")

    for name in list(variants):
        _export(ses, variants[name], name, w, h,
                os.path.join(maps_dir, name + ".png"))
    record["_kit"] = {
        "status": "NON-PRODUCTION FIDELITY STUDY (Arty, 2026-10-13)",
        "glyph": "ECMS Glyph CLI, revision %s" % _revision(root),
        "check_material": "clean",
        "note": "Albedo palette: 256 colours, median cut, no dither. The "
                "normal map is Glyph's own (x-glyph.normal_from_height).",
    }
    with open(os.path.join(maps_dir, "maps.json"), "w") as fh:
        json.dump(record, fh, indent=1, sort_keys=True)
        fh.write("\n")
    print("[fsmaps] %d map(s) + maps.json -> %s" % (len(variants), maps_dir))
    if not os.environ.get("GLYPH_KEEP_WORK"):
        shutil.rmtree(work)


if __name__ == "__main__":
    main()
