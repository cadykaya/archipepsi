#!/usr/bin/env python3
"""Tier 1, landed -- do the shipped enemy sets carry the ruling?

    python3 tools/content/check_enemy_bands.py

RULED 2026-09-26: two value bands, *"a value treatment, not six unrelated
palettes"* -- same enemies, same markings, only the body's value moves
with the room. `build_enemy_roles.py` writes both sets and a generated
band map; this checks the ARTIFACTS against the claims, reading the GLBs
themselves and the project palette, never the builder's constants:

1. **The map is whole.** Every room in the palette has exactly one band,
   and every band's folder holds all ten roles.
2. **Same enemies.** For each role, both bands' GLBs have identical
   node trees, meshes, accessors and materials, and every geometry
   buffer is byte-identical. Only the images may differ.
3. **Same markings.** In every texture, the pixels that are exactly the
   marking colour (the palette's `dead` step 1, or `hazard` step 1 on the
   warn part) are the SAME pixels in both bands, and there are some.
4. **The value moved the right way.** In every texture the deep band's
   non-marking pixels average clearly darker than the standard band's
   (mean CIE L* ratio under DARKER_THAN) -- which catches the two bands
   swapped, or one not applied.

   *Not* the exact factor, and on purpose. A first draft asserted that
   ratio equals the ratio of the declared lightnesses (0.25). It measured
   0.29-0.33 in every texture, including far from the marking. The ramp
   colours themselves land on the factor (0.246-0.267, checked in
   Blender), but pixels that are blended, drifted and quantised to 8 bits
   near black do not scale the way one number does. The exact factor is
   held by check 5 instead, which is stronger: it ties the in-engine
   acceptance to the sha256 of these exact files, so any change to the
   paint makes the evidence stale until it is measured again.
5. **The evidence is of these models, and meets the ruling.** The
   committed `contrast_current/contrast.json` must name each room's own
   band and the sha256 of every committed GLB; and it must clear the
   ruled minimum on every accepted case except the accepted exceptions.
   Evidence measured on other models is stale, and says so.

   **Aggregate and per-role are two different numbers, and are labelled
   as such (RULED 2026-09-26).** The ruling grades the AGGREGATE: all ten
   roles' body pixels pooled against the background. The harness also
   records each role on its own, and a pooled cell can clear while single
   roles in it do not -- `void_glitch` floor pools to 0.100 with the
   diver at 0.088. So per-role shortfalls are REPORTED beside the grade,
   never folded into it and never read as a reason to retire an
   exception. Retiring one is the owner's call, not this script's.
"""

import hashlib
import io
import json
import os
import struct
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))
MODELS = os.path.join(ROOT, "assets", "models")
BAND_MAP = os.path.join(MODELS, "batch030", "enemy_value_bands.json")
PALETTE = os.path.join(ROOT, "assets", "art_palette.json")
EVIDENCE = os.path.join(ROOT, "docs", "art", "review", "enemies_2026-09-25",
                        "contrast_current", "contrast.json")
ROLES = ["artillery", "beacon", "brute", "bulwark", "charger", "diver",
         "drifter", "melee", "ranged", "scuttler"]
#: The deep band must average under this fraction of the standard band's
#: body L*, in every texture. Measured 0.29-0.33 for declared 0.10/0.40;
#: equal paint gives 1.0, and swapped bands give about 3.2.
DARKER_THAN = 0.5


def glb(path):
    """(json, bin) of a GLB."""
    with open(path, "rb") as fh:
        data = fh.read()
    magic, _, length = struct.unpack_from("<III", data, 0)
    if magic != 0x46546C67:
        raise ValueError("%s is not a GLB" % path)
    off, doc, blob = 12, None, b""
    while off < length:
        size, kind = struct.unpack_from("<II", data, off)
        chunk = data[off + 8: off + 8 + size]
        if kind == 0x4E4F534A:
            doc = json.loads(chunk)
        elif kind == 0x004E4942:
            blob = chunk
        off += 8 + size
    return doc, blob


def view_bytes(doc, blob, index):
    v = doc["bufferViews"][index]
    start = v.get("byteOffset", 0)
    return blob[start: start + v["byteLength"]]


def image_views(doc):
    return {img["bufferView"] for img in doc.get("images", [])
            if "bufferView" in img}


def structure(doc):
    """Everything but the image bytes and buffer layout."""
    keep = {}
    for key in ("nodes", "meshes", "accessors", "scenes", "scene"):
        keep[key] = doc.get(key)
    keep["materials"] = doc.get("materials")
    keep["textures"] = doc.get("textures")
    keep["images"] = [{k: v for k, v in img.items() if k != "bufferView"}
                      for img in doc.get("images", [])]
    return json.dumps(keep, sort_keys=True)


def lstar(rgb):
    def lin(c):
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    y = 0.2126 * lin(rgb[0]) + 0.7152 * lin(rgb[1]) + 0.0722 * lin(rgb[2])
    return (116 * y ** (1 / 3) - 16) / 100 if y > 0.008856 else 9.033 * y


def hex_rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i: i + 2], 16) for i in (0, 2, 4))


def textures(doc, blob):
    """{material name: RGB image} for every textured material."""
    out = {}
    for mat in doc.get("materials", []):
        tex = mat.get("pbrMetallicRoughness", {}).get("baseColorTexture")
        if tex is None:
            continue
        image = doc["images"][doc["textures"][tex["index"]]["source"]]
        raw = view_bytes(doc, blob, image["bufferView"])
        out[mat["name"]] = Image.open(io.BytesIO(raw)).convert("RGB")
    return out


def main():
    problems = []
    notes = []
    bands = json.load(open(BAND_MAP, encoding="utf-8"))
    palette = json.load(open(PALETTE, encoding="utf-8"))

    # 1. the map is whole ----------------------------------------------
    rooms = sorted(palette["themes"])
    room_band = bands["room_band"]
    if sorted(room_band) != rooms:
        problems.append("the band map covers %s; the palette's rooms are %s"
                        % (sorted(room_band), rooms))
    for band, spec in bands["bands"].items():
        listed = sorted(spec["rooms"])
        mapped = sorted(r for r, b in room_band.items() if b == band)
        if listed != mapped:
            problems.append("band %s lists %s but the room map gives it %s"
                            % (band, listed, mapped))
        for role in ROLES:
            if not os.path.exists(os.path.join(
                    MODELS, spec["models"], "enemy_role_%s.glb" % role)):
                problems.append("band %s has no enemy_role_%s.glb in %s"
                                % (band, role, spec["models"]))
    if problems:
        return report(problems, notes)

    names = sorted(bands["bands"], key=lambda b: -bands["bands"][b]
                   ["body_lightness"])
    if len(names) != 2:
        problems.append("expected two bands, found %s" % names)
        return report(problems, notes)
    light, dark = names
    marks = {"dead": hex_rgb(palette["universal"]["dead"]["ramp"][1]),
             "hazard": hex_rgb(palette["universal"]["hazard"]["ramp"][1])}

    # 2-4. per role ----------------------------------------------------
    ratios = []
    for role in ROLES:
        a_doc, a_bin = glb(os.path.join(
            MODELS, bands["bands"][light]["models"],
            "enemy_role_%s.glb" % role))
        b_doc, b_bin = glb(os.path.join(
            MODELS, bands["bands"][dark]["models"],
            "enemy_role_%s.glb" % role))
        if structure(a_doc) != structure(b_doc):
            problems.append("%s: the two bands differ in nodes, meshes, "
                            "accessors or materials -- they are not the same "
                            "enemy repainted" % role)
            continue
        a_img, b_img = image_views(a_doc), image_views(b_doc)
        geometry = 0
        for i in range(len(a_doc["bufferViews"])):
            if i in a_img:
                continue
            if view_bytes(a_doc, a_bin, i) != view_bytes(b_doc, b_bin, i):
                problems.append("%s: geometry buffer %d differs between "
                                "bands" % (role, i))
            geometry += 1
        if geometry == 0:
            problems.append("%s: no geometry buffers compared" % role)
        a_tex, b_tex = textures(a_doc, a_bin), textures(b_doc, b_bin)
        for mat, a_px in a_tex.items():
            b_px = b_tex[mat]
            if a_px.tobytes() == b_px.tobytes():
                problems.append("%s: %s is the same image in both bands"
                                % (role, mat))
                continue
            mark = marks["hazard" if mat.endswith("_warn") else "dead"]
            a_data = list(a_px.get_flattened_data()) \
                if hasattr(a_px, "get_flattened_data") else list(a_px.getdata())
            b_data = list(b_px.get_flattened_data()) \
                if hasattr(b_px, "get_flattened_data") else list(b_px.getdata())
            a_mark = {i for i, p in enumerate(a_data) if p == mark}
            b_mark = {i for i, p in enumerate(b_data) if p == mark}
            if not a_mark:
                problems.append("%s: %s shows no marking pixel at all"
                                % (role, mat))
            elif a_mark != b_mark:
                problems.append("%s: %s's marking covers %d pixels in the "
                                "%s band and %d in the %s band -- the marking "
                                "moved" % (role, mat, len(a_mark), light,
                                           len(b_mark), dark))
            rest = [i for i in range(len(a_data)) if i not in a_mark]
            la = sum(lstar(a_data[i]) for i in rest) / len(rest)
            lb = sum(lstar(b_data[i]) for i in rest) / len(rest)
            ratios.append(lb / la)
            if lb / la >= DARKER_THAN:
                problems.append("%s: %s averages %.3f of the %s band's body "
                                "L* in the %s band -- not clearly darker"
                                % (role, mat, lb / la, light, dark))
    if ratios:
        notes.append("body L* %s/%s: %.3f to %.3f over %d textures"
                     % (dark, light, min(ratios), max(ratios), len(ratios)))

    # 5. the evidence ---------------------------------------------------
    if not os.path.exists(EVIDENCE):
        problems.append("no measurement of the landed treatment at %s"
                        % os.path.relpath(EVIDENCE, ROOT))
        return report(problems, notes)
    ev = json.load(open(EVIDENCE, encoding="utf-8"))
    acc = bands["acceptance"]
    if abs(float(ev["_meta"]["distance_m"])
           - float(bands["review_distance_m"])) > 1e-6:
        problems.append("the evidence was measured at %s m, the ruling is "
                        "at %s m" % (ev["_meta"]["distance_m"],
                                     bands["review_distance_m"]))
    # The harness's own `clears_value` flag is computed on the UNROUNDED
    # separation; the stored number is rounded to 0.001, and 0.0999 stored
    # as 0.100 would pass a cell the harness itself called short. So the
    # flag is used -- and it is only meaningful if the harness measured
    # against the ruled threshold.
    if abs(float(ev["_meta"]["min_value_separation"])
           - float(acc["min_separation"])) > 1e-9:
        problems.append("the evidence was graded against %s; the ruled "
                        "minimum is %s" % (ev["_meta"]["min_value_separation"],
                                           acc["min_separation"]))
    exceptions = {(e["room"], e["case"]) for e in acc["exceptions"]}
    floor_line = float(acc["min_separation"])
    per_role_short = []
    stale = []
    for room in rooms:
        row = ev.get(room)
        if row is None:
            problems.append("the evidence has no %s" % room)
            continue
        want = os.path.join("assets", "models",
                            bands["bands"][room_band[room]]["models"])
        if not os.path.normpath(row["models"]).endswith(want):
            problems.append("the evidence measured %s with %s, not its own "
                            "band (%s)" % (room, row["models"], want))
        for role in ROLES:
            path = os.path.join(MODELS, bands["bands"][room_band[room]]
                                ["models"], "enemy_role_%s.glb" % role)
            if not os.path.exists(path):
                problems.append("no committed %s to compare the evidence "
                                "against" % os.path.relpath(path, ROOT))
                continue
            sha = hashlib.sha256(open(path, "rb").read()).hexdigest()
            if row.get("models_sha256", {}).get(role) != sha:
                stale.append("%s/%s" % (room, role))
        for case in acc["cases"]:
            cell = row[case]
            sep = float(cell["separation"])
            ok = bool(cell["clears_value"]) and \
                not cell["body_above_background"]
            low = sorted((float(v["separation"]), r) for r, v in
                         cell.get("per_role", {}).items()
                         if float(v["separation"]) < floor_line)
            if (room, case) in exceptions:
                notes.append(
                    "%s %s -- an accepted exception, not retired: aggregate "
                    "%.3f (%s); per role, %s" % (
                        room, case, sep,
                        "clears" if ok else "short",
                        "%d of %d below %.2f, lowest %s %.3f" % (
                            len(low), len(cell.get("per_role", {})),
                            floor_line, low[0][1], low[0][0])
                        if low else "every role clears"))
                continue
            if low:
                per_role_short.append("%s %s (aggregate %.3f): %s" % (
                    room, case, sep, ", ".join(
                        "%s %.3f" % (r, v) for v, r in low)))
            if not ok:
                problems.append("%s %s: %.3f against a ruled minimum of "
                                "%.2f, and it is not an accepted exception"
                                % (room, case, sep, acc["min_separation"]))
    for line in per_role_short:
        notes.append("per role, reported and not graded -- %s" % line)
    if stale:
        problems.append("the evidence was measured on other models (%d of "
                        "%d files differ, e.g. %s). Re-run "
                        "tools/content/run_enemy_contrast.sh"
                        % (len(stale), len(rooms) * len(ROLES), stale[0]))
    return report(problems, notes)


def report(problems, notes):
    for n in notes:
        print("enemy-bands: %s" % n)
    if problems:
        print("enemy-bands: FAIL -- %d problem(s):" % len(problems))
        for p in problems:
            print("  - %s" % p)
        return 1
    print("enemy-bands: PASS -- two bands, one set of enemies, the markings "
          "unmoved, and the landed treatment measured against the ruling")
    return 0


if __name__ == "__main__":
    sys.exit(main())
