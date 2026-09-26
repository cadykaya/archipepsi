"""Track D -- build the game packs' own textures and declare them.

    .tools/blender/blender --background --python \
        tools/blender/build_pack_materials.py

Writes one PNG per pack/theme/role into `assets/textures/theme/` under a
`pack_` prefix, plus `pack_manifest.json` beside the family's manifest.

## Why the pack textures sit in the family's directory

`tools/export_content_pack.py` copies every `.png` in
`assets/textures/theme/` to `godot/content/theme/`, and a descriptor row
names its texture as `theme/<file>.png`. Putting pack pixels anywhere
else would mean a second export path, a second import path and a second
place for them to go stale, in exchange for a tidier directory listing.
The `pack_` prefix cannot collide with a family file, because a family
file is `<one of six known theme names>_<role>.png`.

## What this does NOT do

It does not select, approve or name a pack anywhere the engine reads. It
writes pixels and a manifest. The rows reach the descriptor through
`verify_theme_set.py --write`, and they arrive at `candidate` status --
the ladder is candidate -> selectable -> approved, and only the owner
moves anything past the first rung.
"""

import json
import os
import sys

import numpy as np

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

import build_materials as bm  # noqa: E402
import common  # noqa: E402
import materials  # noqa: E402
import packmaterials  # noqa: E402
import palette as pal  # noqa: E402

#: Where the owner-facing comparison lands. A review sheet, like the
#: family's own `H_material_<theme>.png` -- a render, not build output.
SHEET = os.path.join("docs", "art", "review", "packs_2026-09-24",
                     "SHEET_tiles.png")
ZOOM = 3
GAP = 6


def _column(role):
    """One role across the family and both packs, left to right.

    The claim these rows exist to support is that the difference between
    the packs is HISTORY rather than hue -- and that claim is only
    checkable side by side, at the same zoom, on the same role.
    """
    theme = packmaterials.FAMILY
    cells = [("%s (family)" % theme, materials.paint(theme, role)[0])]
    for pack in packmaterials.packs():
        if role in packmaterials.roles_for(pack):
            cells.append((pack, packmaterials.paint(pack, role, theme)[0]))
    tiles = []
    for name, canvas in cells:
        zoomed = np.repeat(np.repeat(canvas.px, ZOOM, axis=0), ZOOM, axis=1)
        label = bm._label_strip(zoomed.shape[1], "%s %s" % (role, name),
                                pal.universal("signal", 3), pal.grime(0))
        tiles.append(np.concatenate([label, zoomed], axis=0))
    height = tiles[0].shape[0]
    width = sum(t.shape[1] for t in tiles) + GAP * (len(tiles) - 1)
    row = np.zeros((height, width, 3), dtype=np.float32)
    row[:, :] = pal.rgb(pal.grime(0))
    x = 0
    for t in tiles:
        row[:, x:x + t.shape[1]] = t
        x += t.shape[1] + GAP
    return row


def _sheet(roles):
    rows = [_column(role) for role in roles]
    width = max(r.shape[1] for r in rows)
    height = sum(r.shape[0] for r in rows) + GAP * (len(rows) - 1)
    sheet = np.zeros((height, width, 3), dtype=np.float32)
    sheet[:, :] = pal.rgb(pal.grime(0))
    y = 0
    for r in rows:
        sheet[y:y + r.shape[0], :r.shape[1]] = r
        y += r.shape[0] + GAP
    return sheet


def main():
    common.reset_scene()
    manifest = {}
    for pack in packmaterials.packs():
        for role in packmaterials.roles_for(pack):
            theme = packmaterials.FAMILY
            canvas, _ = packmaterials.paint(pack, role, theme)
            rel = "theme/pack_%s_%s_%s.png" % (pack, theme, role)
            image = canvas.to_blender("pack_%s_%s_%s" % (pack, theme, role))
            common.save_texture(image, rel)
            # Keyed the way D-11 keys a pack row. The key is built here,
            # once, so nothing downstream has to know how to spell it.
            manifest["%s/%s/%s" % (pack, theme, role)] = {
                "texture": rel,
                "size_px": materials.ARCH_SIZE,
                "covers_m": round(materials.ARCH_METRES, 3),
                "texels_per_metre": materials.ARCH_DENSITY,
            }
            common.log("pack   %-44s %dpx over %.2f m = %d texels/m"
                       % (os.path.basename(rel), materials.ARCH_SIZE,
                          materials.ARCH_METRES, materials.ARCH_DENSITY))

    out = os.path.join(common.REPO_ROOT, "assets", "textures", "theme",
                       "pack_manifest.json")
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2, sort_keys=True)
        handle.write("\n")
    common.log("pack   %d row(s) -> pack_manifest.json" % len(manifest))

    # The owner-facing comparison. Every role either pack ships, with
    # the family beside it at the same zoom.
    roles = []
    for pack in packmaterials.packs():
        for role in packmaterials.roles_for(pack):
            if role not in roles:
                roles.append(role)
    bm._save(_sheet(sorted(roles)),
             os.path.join(common.REPO_ROOT, SHEET))
    common.log("pack   sheet %s (%dx zoom)" % (SHEET, ZOOM))


if __name__ == "__main__":
    main()
