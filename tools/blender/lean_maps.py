#!/usr/bin/env python3
"""The integration set of a weapon's maps: the same texels, fewer bytes.
(Arty, 2026-10-14.)

    python3 tools/blender/lean_maps.py OUT [WEAPON]

Reads OUT/maps/ (what Glyph exported: every map four-channel RGBA) and
writes OUT/lean/ plus OUT/lean/lean.json. A channel repack, not a new
painting: every map keeps its size and its texels, and the check below
refuses to write if a single texel would change meaning.

  albedo.png     RGB   the colour map; its alpha was 255 everywhere (the
                       GPU pads RGB to RGBA: 4 bytes a texel there)
  normal.png     RGB   tangent normals; alpha unused. Load it as RG8
                       (`Image.convert(FORMAT_RG8)`): Godot's shader reads
                       X and Y and rebuilds Z, so it is pixel-identical
                       (measured in Prod's range, 2026-10-14), and a
                       Lossless import would keep RGB8, padded to RGBA8
  roughness.png  L     grey (Glyph wrote it as R = G = B)
  metallic.png   L     grey
  emission.png   L     the lamp's intensity. Its colour (one colour,
                       everywhere it is lit, checked to an 8-bit step)
                       goes on the material as the emission colour

Why: the owner asked for the 96 MB of the 2048 maps to be cut where it
is unnecessary, without losing detail (2026-10-14). Four channels for a
grey map, an alpha nobody reads, a normal's third channel the shader
rebuilds anyway and a full-colour map that is 99.9% black were the
unnecessary part. Godot keeps a grey PNG grey (L8, one byte a texel)
when imported Lossless, and its StandardMaterial3D reads roughness and
metallic from any one channel. On the GPU: colour 4 + normal 2 + three
grey maps 1 each = 9 bytes a texel, against 16.
"""

from __future__ import annotations

import json
import os
import sys

import numpy as np
from PIL import Image


def _rgba(path):
    return np.asarray(Image.open(path).convert("RGBA"))


def main():
    out = os.path.abspath(sys.argv[1])
    weapon = sys.argv[2] if len(sys.argv) > 2 else os.path.basename(out)
    src = os.path.join(out, "maps")
    dst = os.path.join(out, "lean")
    os.makedirs(dst, exist_ok=True)
    rec = {"weapon": weapon, "maps": {}}

    albedo = _rgba(os.path.join(src, "albedo.png"))
    if not (albedo[..., 3] == 255).all():
        raise SystemExit("albedo has transparency: keep its alpha")
    Image.fromarray(albedo[..., :3], "RGB").save(
        os.path.join(dst, "albedo.png"), optimize=True)

    normal = _rgba(os.path.join(src, "normal.png"))
    Image.fromarray(normal[..., :3], "RGB").save(
        os.path.join(dst, "normal.png"), optimize=True)

    for name in ("roughness", "metallic"):
        m = _rgba(os.path.join(src, name + ".png"))
        if not ((m[..., 0] == m[..., 1]) & (m[..., 1] == m[..., 2])).all():
            raise SystemExit("%s is not grey: keep it in colour" % name)
        Image.fromarray(m[..., 0], "L").save(
            os.path.join(dst, name + ".png"), optimize=True)

    # the lamp is one colour; the gutters' dilation leaves fainter copies
    # of it at island edges. Every lit texel must be that colour times an
    # intensity (to within one 8-bit step), which an L8 map holds exactly
    em = _rgba(os.path.join(src, "emission.png"))[..., :3].astype(float)
    lit = em.sum(-1) > 0
    if lit.any():
        base = em[lit][np.argmax(em[lit].sum(-1))]
        k = em.sum(-1) / base.sum()
        back = np.rint(np.rint(k * 255)[..., None] / 255.0 * base)
        err = np.abs(back - em)[lit].max()
        if err > 1.0:
            raise SystemExit("emission is not one colour at varying "
                             "intensity (error %.0f): keep it in colour"
                             % err)
        colour = base.astype(int).tolist()
        mask = np.clip(np.rint(k * 255), 0, 255).astype(np.uint8)
    else:
        colour, mask = [0, 0, 0], np.zeros(lit.shape, np.uint8)
    Image.fromarray(mask, "L").save(os.path.join(dst, "emission.png"),
                                    optimize=True)

    h, w = albedo.shape[:2]
    per_texel = 4 + 2 + 1 + 1 + 1     # on the GPU: RGBA8, RG8, 3 x L8
    rec["size"] = [w, h]
    rec["emission_colour_srgb"] = [c / 255.0 for c in colour]
    rec["emission_lit_share"] = round(float(lit.mean()), 6)
    rec["bytes_with_mips"] = {
        "glb_rgba8_x4": int(4 * 4 * w * h * 4 / 3),
        "lean": int(per_texel * w * h * 4 / 3),
    }
    rec["godot_material"] = {
        "shading": "per-pixel, cull back",
        "texture_filter": "NEAREST_WITH_MIPMAPS (the art bible)",
        "albedo_texture": "albedo.png",
        "normal_enabled": True,
        "normal_texture": "normal.png, loaded as RG8 "
                          "(Image.convert(Image.FORMAT_RG8)): the shader "
                          "rebuilds Z; pixel-identical, 2 bytes not 4",
        "roughness": 1.0, "roughness_texture": "roughness.png",
        "roughness_texture_channel": "GRAYSCALE",
        "metallic": 1.0, "metallic_texture": "metallic.png",
        "metallic_texture_channel": "GRAYSCALE",
        "emission_enabled": True, "emission_texture": "emission.png",
        "emission_operator": "MULTIPLY (the default, ADD, lights the "
                             "whole model in the lamp's colour)",
        "emission_colour_srgb": rec["emission_colour_srgb"],
        "emission_energy_multiplier": 1.0,
        "import": "Compress Mode: Lossless, Mipmaps: on (Godot keeps L8 "
                  "as it is; RGB8 is padded to RGBA8 on the GPU)",
    }
    with open(os.path.join(dst, "lean.json"), "w") as fh:
        json.dump(rec, fh, indent=1, sort_keys=True)
        fh.write("\n")
    print("[lean] %s %dx%d: %.1f MB -> %.1f MB with mipmaps"
          % (weapon, w, h, rec["bytes_with_mips"]["glb_rgba8_x4"] / 2 ** 20,
             rec["bytes_with_mips"]["lean"] / 2 ** 20))


if __name__ == "__main__":
    main()
