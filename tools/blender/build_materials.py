"""Batch 001 H -- texture and material style probes.

    .tools/blender/blender -b --python tools/blender/build_materials.py

Writes one PNG per theme/role into `assets/textures/theme/`, plus a contact
sheet per theme into `docs/art/review/batch001/` at 4x nearest-neighbour so
the texels are judgeable on a screen rather than guessed at.

**The 4x is a review convenience and it is labelled as one.** A sheet that
silently upscaled would be a bench that answers a question nobody asked --
the texture is 128px and is seen at 32 texels/m, and the in-engine shots are
where that gets judged. This sheet is for judging the PAINT.
"""

from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import numpy as np

import common  # noqa: E402
import materials  # noqa: E402
import paintkit  # noqa: E402
import palette as pal  # noqa: E402

REVIEW_DIR = os.path.join(common.REPO_ROOT, "docs", "art", "review", "batch001")
ZOOM = 4
LABEL_H = 8


def _label_strip(width, message, fg, bg):
    strip = np.zeros((LABEL_H, width, 3), dtype=np.float32)
    strip[:, :] = pal.rgb(bg)
    canvas = paintkit.Canvas(max(width, LABEL_H), bg)
    surface = paintkit.Surface(max(width, LABEL_H), 1.0, "panel")
    paintkit.text(canvas, surface, 2, 1, message, fg)
    strip[:, :] = canvas.px[:LABEL_H, :width]
    return strip


def _sheet(theme, canvases):
    """A row of role tiles, zoomed, each labelled."""
    size = materials.ARCH_SIZE
    tiles = []
    for role, canvas in canvases:
        zoomed = np.repeat(np.repeat(canvas.px, ZOOM, axis=0), ZOOM, axis=1)
        label = _label_strip(size * ZOOM, role,
                             pal.universal("signal", 3), pal.grime(0))
        tiles.append(np.concatenate([label, zoomed], axis=0))
    gap = 6
    height = tiles[0].shape[0]
    total_w = sum(t.shape[1] for t in tiles) + gap * (len(tiles) - 1)
    sheet = np.zeros((height + LABEL_H + gap, total_w, 3), dtype=np.float32)
    sheet[:, :] = pal.rgb(pal.grime(0))
    title = _label_strip(total_w, theme.replace("_", " "),
                         pal.universal("send", 3), pal.grime(0))
    sheet[:LABEL_H, :] = title
    x = 0
    for tile in tiles:
        sheet[LABEL_H + gap:LABEL_H + gap + height, x:x + tile.shape[1]] = tile
        x += tile.shape[1] + gap
    return sheet


def _save(array, path):
    import bpy
    height, width = array.shape[:2]
    image = bpy.data.images.new(os.path.basename(path), width, height,
                                alpha=False)
    rgba = np.ones((height, width, 4), dtype=np.float32)
    rgba[:, :, :3] = np.flipud(array)
    image.pixels.foreach_set(rgba.ravel())
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.filepath_raw = path
    image.file_format = "PNG"
    image.save()


def main():
    common.reset_scene()
    manifest = {}
    for theme in materials.built_themes():
        canvases = []
        for role in materials.roles_for(theme):
            canvas, surface = materials.paint(theme, role)
            rel = "theme/%s_%s.png" % (theme, role)
            image = canvas.to_blender("%s_%s" % (theme, role))
            common.save_texture(image, rel)
            canvases.append((role, canvas))
            manifest["%s/%s" % (theme, role)] = {
                "texture": rel,
                "size_px": materials.ARCH_SIZE,
                "covers_m": round(materials.ARCH_METRES, 3),
                "texels_per_metre": materials.ARCH_DENSITY,
            }
            common.log("theme/%-34s %dpx over %.2f m = %d texels/m"
                       % ("%s_%s.png" % (theme, role), materials.ARCH_SIZE,
                          materials.ARCH_METRES, materials.ARCH_DENSITY))
        _save(_sheet(theme, canvases),
              os.path.join(REVIEW_DIR, "H_material_%s.png" % theme))
        common.log("sheet  docs/art/review/batch001/H_material_%s.png (%dx zoom)"
                   % (theme, ZOOM))

    out = os.path.join(common.REPO_ROOT, "assets", "textures", "theme",
                       "manifest.json")
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2, sort_keys=True)
        handle.write("\n")


if __name__ == "__main__":
    main()
