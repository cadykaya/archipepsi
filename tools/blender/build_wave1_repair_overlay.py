"""Where the eight repaired points were, and where they are now.

    .tools/blender/blender -b --python tools/blender/build_wave1_repair_overlay.py

WHY A DIAGRAM AND NOT A PHOTOGRAPH. The Wave 1 repair moved seven `cover`
sockets and one `reward` volume and touched no geometry at all -- the
three shells export the same triangles and the same colliders they did
before. A matched before/after render would therefore be two identical
pictures. What changed is a set of DECLARED POINTS, and the only honest
way to show a point moving is to draw it.

BOTH POSITIONS ARE DERIVED, neither is typed in. The old position of
every one of these was the CENTRE of the thing it named -- that was the
defect -- so `before` is the block centre or the collar axis read from
the builder's own tables, and `after` is what `roomkit.cover_stance` and
`build_plenum._reward_spot` compute from those same tables. A figure that
hardcoded either end could show a repair that did not happen.

RED IS WHERE IT WAS. GREEN IS WHERE IT IS. The grey blocks are the cover
the sockets belong to, drawn at their real size, and the grey ring is the
plenum's collar. Nothing else is drawn: the shell itself is composed
behind every figure and already has the machine, the floor and the walls
in it.
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

import brushkit  # noqa: E402
import common  # noqa: E402
import roomkit  # noqa: E402

import build_plenum  # noqa: E402
import build_span  # noqa: E402
import build_yard  # noqa: E402

OUT = "batch040/overlays"

INK = {
    "was":   "#ff3b30",     # the buried position Production measured
    "now":   "#4ade5b",     # the repaired position
    "solid": "#8a8f98",     # the block or ring the point belongs to
}


def _mat(key):
    return common.make_material("w1_%s" % key, INK[key], roughness=0.4,
                                emission_hex=INK[key], emission_strength=0.7)


def _add(parts, obj, key):
    common.assign(obj, _mat(key))
    parts.append(obj)
    return obj


def _pin(parts, name, x, z, y, key):
    """A marker standing at a declared point, at the socket's own height."""
    _add(parts, brushkit.prism(name, 0.45, 1.8, 8,
                               (x, roomkit.y(z), y + 0.9)), key)


def _export(parts, stem):
    obj = common.join(parts, stem)
    out = os.path.join(common.MODEL_DIR, OUT, "%s.glb" % stem)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    # Not `export_glb`: that runs the shipped-art gates, and a review
    # figure is not shipped art.
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB",
                              use_selection=True, export_apply=True,
                              export_normals=True, export_materials="EXPORT")
    print("[art] overlay %s/%s.glb  %d tris"
          % (OUT, stem, common.triangle_count(obj)))


def cover_figure(stem, table, axis, away_from):
    """Every cover cluster in a room: the block, the old point, the new."""
    parts = []
    for j, (cx, cz, sx, sz) in enumerate(table):
        _add(parts, brushkit.block("blk_%d" % j, (sx, sz, 1.9),
                                   (cx, roomkit.y(cz), 0.95)), "solid")
        # WHERE IT WAS: the block's own centre, which is what the socket
        # carried and why the audit found it inside solid geometry.
        _pin(parts, "was_%d" % j, cx, cz, 0.3, "was")
        nx, nz = roomkit.cover_stance(cx, cz, sx, sz, axis, away_from)
        _pin(parts, "now_%d" % j, nx, nz, 0.3, "now")
    _export(parts, stem)


def reward_figure():
    """The plenum's middle collar, the machine through it, and the move."""
    parts = []
    top = build_plenum.TOP - (build_plenum.TOP / build_plenum.RUNS) * 7
    half = build_plenum.D / 2.0
    _add(parts, brushkit.tube(
        "collar", build_plenum.COLLAR_OUT, build_plenum.MACH / 2.0,
        build_plenum.COLLAR_T, 12,
        (0.0, roomkit.y(half), top - build_plenum.COLLAR_T / 2.0)), "solid")
    # THE MACHINE IS NOT DRAWN. An earlier version drew a slab of it so
    # the "was" pin would have something to be inside of, and it hid the
    # pin completely while reading as an unexplained grey block. The
    # shell behind this figure already has the real machine, 56 m of it,
    # and the red pin being swallowed by it is not a flaw in the picture
    # -- it is the finding, and the caption says so.
    _pin(parts, "was", 0.0, half, top + 1.0, "was")
    spot = build_plenum._reward_spot(top, build_plenum._corner(7))
    _pin(parts, "now", spot[0], -spot[1], spot[2], "now")
    _export(parts, "wave1_reward")


def main():
    common.reset_scene()
    cover_figure("wave1_cover_yard", build_yard.COVER, "z",
                 build_yard.D / 2.0)
    common.reset_scene()
    cover_figure("wave1_cover_span", build_span.COVER, "x", 0.0)
    common.reset_scene()
    reward_figure()


main()
