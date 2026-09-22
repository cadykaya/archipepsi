"""What every theme-pack builder does the same way.

    painter = packkit.Painter("neon_transit", "br")
    packkit.build(ASSETS, OUT, painter, DISTINCT, SHARED)

## Why a module

Eighteen packs in the first wave and sixty-three behind them. Two
builders had already grown identical copies of the same forty lines --
the image cache, the material cache, the block helper, and a main loop
that gates, UV-projects, checks connectivity, exports and writes a
manifest. Eighty-one copies of that is eighty-one places for the next
correction to miss, and this lane has already had to make three
corrections to one gate.

**The gates live in `packgates`; the geometry lives in the pack.** This
module is only the plumbing between them.

## What a pack still decides for itself

Its subtheme, its shapes, its dressing, what makes each piece ITS rather
than the house family's, and which family it paints in. None of that is
here, because none of it is plumbing.
"""

from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import brushkit  # noqa: E402
import common  # noqa: E402
import materials  # noqa: E402
import packgates  # noqa: E402
import palette as pal  # noqa: E402
import roomcollision  # noqa: E402

SIZE = materials.ARCH_SIZE
DENSITY = materials.ARCH_DENSITY


class Painter:
    """One theme's images and materials, cached per asset.

    `tag` prefixes the Blender datablock names so two packs in one
    session cannot collide. The caches are cleared between assets by
    `build()`, because `common.reset_scene()` invalidates them and a
    stale image reference is the kind of bug that exports silently.
    """

    def __init__(self, theme, tag):
        self.theme = theme
        self.tag = tag
        self._images = {}
        self._materials = {}

    def reset(self):
        self._images.clear()
        self._materials.clear()

    def image(self, role):
        if role not in self._images:
            canvas, _ = materials.paint(self.theme, role)
            self._images[role] = canvas.to_blender(
                "%s_%s_%s" % (self.tag, self.theme, role))
        return self._images[role]

    def paint(self, obj, role, collide=None):
        """Assign the role's material and declare its collide class.

        `roomcollision.paint_role` knows four classes -- ceiling, floor,
        trim, wall -- so a role outside that set (`accent`,
        `trim_plain`, `wall_ribbed`) MUST be given one explicitly. A
        pack that forgets gets an exception here rather than a silently
        unclassified surface downstream.
        """
        if role not in self._materials:
            self._materials[role] = common.make_textured_material(
                role, self.image(role), roughness=pal.roughness(self.theme))
        common.assign(obj, self._materials[role])
        return roomcollision.paint_role(obj, collide or role)

    def block(self, tag, size, at, role="wall", collide=None,
              rotation_z=0.0):
        """A box, painted. `rotation_z` is DEGREES -- `brushkit.block`
        calls `math.radians()` on it, and handing it radians has already
        cost this lane one debugging round (a 54-degree fork that came
        out at 0.95 and made `assert_parts_touch` report a float)."""
        return self.paint(
            brushkit.block(tag, size, at, rotation_z=rotation_z),
            role, collide)

    def wheel(self, tag, across, thick, at, role="trim", collide=None,
              upright=False, hub=False, sides=8):
        """A disc, as 1998 drew one: an N-sided prism.

        `upright` stands it up so its face points OUT OF A WALL, via
        `brushkit.spin`, which turns geometry about its own bbox centre
        -- the one safe way to rotate a part that is already positioned.
        This argument exists because the first gear helper used
        `rotation_z`, the only rotation `brushkit.block` offers, and
        produced a wheel lying FLAT: right on a vertical shaft and wrong
        on a wall, where it poked 0.44 m straight through the plate it
        was mounted on.

        `hub` adds a raised boss at the centre. Without one, an octagon
        face is a plate; the room showed exactly that before the boss
        existed.
        """
        obj = brushkit.prism(tag, across / 2.0, thick, sides, at)
        if upright:
            brushkit.spin(obj, "x", 90.0)
        made = [self.paint(obj, role, collide)]
        if hub:
            boss = brushkit.prism("%s_hub" % tag, across * 0.11,
                                  thick * 2.0, sides, at)
            if upright:
                brushkit.spin(boss, "x", 90.0)
            made.append(self.paint(boss, "wall", collide))
        return made


def build(assets, out, painter, distinct, shared, log="pack"):
    """Gate, project, connect, export and manifest one pack.

    `assets` is a list of `(name, builder, checks)` where `checks` names
    which of `packgates`' three apply. **A pack that declares no checks
    for a piece gets none** -- which is a real choice a builder makes
    out loud, and `tp_ft_root_mass` shipped once with an empty list
    before anyone noticed the floor piece was the least checked thing
    in the set.
    """
    made = {}
    for name, builder, checks in assets:
        common.reset_scene()
        painter.reset()
        body, parts = builder()
        objects = [body] + parts
        if "opening" in checks:
            packgates.assert_opening_clear(objects, name)
        if "emitters" in checks:
            packgates.assert_no_emitters(objects, name)
        if "route" in checks:
            packgates.assert_no_footholds(objects, name)
        for obj in objects:
            common.uv_project_world(obj, DENSITY, SIZE)
        common.assert_parts_touch(body, parts, name)
        entry = common.export_glb(body, "%s/%s.glb" % (out, name), "prop",
                                  tier="architecture", texture_size=SIZE,
                                  anchor="floor", parts=parts)
        entry["parts"] = [p.name for p in parts]
        entry["distinct"] = distinct[name]
        made[name] = entry
        print("[%s] %-24s %4d tris, %d part(s)"
              % (log, name, entry["triangles"], len(parts)))

    path = os.path.join(common.MODEL_DIR, out, "manifest.json")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    # The asset's own measurements win over the pack's boilerplate. The
    # other order would let a shared key silently overwrite a measured
    # one, which is the direction that loses information.
    rows = {k: dict(shared, texels_per_metre=DENSITY, **v)
            for k, v in made.items()}
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(rows, handle, indent=2, sort_keys=True)
    print("[%s] manifest %s" % (log, os.path.relpath(path,
                                                     common.REPO_ROOT)))
    return rows
