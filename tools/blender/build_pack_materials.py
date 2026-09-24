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

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import materials  # noqa: E402
import packmaterials  # noqa: E402


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


if __name__ == "__main__":
    main()
