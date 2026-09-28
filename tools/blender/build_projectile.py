"""Batch 008 -- the three projectiles, and why they are three.

    .tools/blender/blender -b --python tools/blender/build_projectile.py

`ASSET_INVENTORY.md` section 4 lists `enemy_projectile` as **Pri A** and
unbuilt. It is the last Tier-4 row that is not blocked: seven of the ten
concepted enemy roles are waiting on colliders (interface requirement 7) and
the telegraph is waiting on an engineering decision (requirement 13 below),
but the projectile has a real node, real numbers and nothing in its way.

## What the engine already distinguishes, and what it does not

`echo_projectile.gd` describes three shapes as one primitive family:

| Kind | How the engine knows | What the player must do |
| --- | --- | --- |
| straight | `gravity_scale` 0 | step sideways |
| falling | `gravity_scale` > 0 | get out from under it |
| lobbed | `blast_radius` > 0 | get clear of where it lands |

Three different reactions. **One mesh**, today: a `SphereMesh` at radius
0.22, scaled 1.5x when it is a lob. So the one distinction the engine draws
visually is the least useful of the three -- size -- and the two that decide
whether the player steps sideways or runs are not drawn at all.

So this batch is three meshes, and the form carries what the tint cannot.

## Why the tint cannot carry it

`tint` is *the source world's colour* -- `EchoProjectile.tint` is set from
whichever multiworld game the Echo came from, and the engine paints the
visual with `glow_material(tint, 2.5)`. That is an OPEN set, exactly like
the Check's destination ring: it can be any colour at all, so nothing about
hue is available to say which kind of projectile this is.

Which means these must each be **one flat material** the engine overrides,
and every distinction has to live in the silhouette. Same conclusion as
`check_destination_ring`, reached from the same place.

## Why they are not oriented

`_ready` builds the visual and never rotates it; `_physics_process`
integrates a velocity. A dart shape would therefore fly sideways as often as
not. Each of these reads from any angle around the vertical -- the axis a
horizontally-travelling projectile does not spin about -- and the vertical
asymmetry is deliberate, because it is the one axis whose orientation the
engine does keep.

## Sizes are the engine's

`SphereShape3D` radius 0.25 is the collider; the visual is 0.44 across, or
0.66 for a lob at the engine's own 1.5x. Nothing here exceeds either.
"""

from __future__ import annotations

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import brushkit  # noqa: E402
import common  # noqa: E402
import palette as pal  # noqa: E402

OUT = "batch008/enemy"

#: echo_projectile.gd: SphereMesh radius 0.22, height 0.44, x1.5 for a lob.
BODY = 0.44
LOB = BODY * 1.5
#: SphereShape3D radius 0.25 -- the collider the visual sits inside.
COLLIDER = 0.50


def _fins(name, count, inner, outer, thickness, z):
    """A ring of blades around the body.

    Blades rather than a solid ring because a ring is a silhouette from the
    side and nothing from above, and a projectile is seen from every angle
    a player can stand at.
    """
    parts = []
    for i in range(count):
        angle = i * 2.0 * math.pi / count
        blade = brushkit.block(
            "%s_fin_%d" % (name, i), (outer - inner, thickness, thickness),
            ((inner + outer) / 2.0 * math.cos(angle),
             (inner + outer) / 2.0 * math.sin(angle), z),
            rotation_z=math.degrees(angle))
        parts.append(blade)
    return parts


def straight():
    """Flies flat. A tight spindle with a hard equatorial ring of blades.

    The read is HORIZONTAL: a flat, fast thing at eye level, and the four
    blades make its silhouette wider than it is tall so it does not read as
    something that will drop.
    """
    # `prism` tapers from `radius` at the BOTTOM to `top_radius` at the
    # top, so the lower half of a spindle runs small-to-large and the upper
    # half large-to-small. Written the other way round -- which is what the
    # first pass did for all three -- both halves narrow upward and the
    # result is a traffic cone with a notch in it.
    parts = [brushkit.prism("proj_s_lo", 0.05, BODY * 0.34, 8,
                            (0.0, 0.0, -BODY * 0.17), top_radius=0.14,
                            asset_name="enemy_projectile_straight"),
             brushkit.prism("proj_s_hi", 0.14, BODY * 0.34, 8,
                            (0.0, 0.0, BODY * 0.17), top_radius=0.05,
                            asset_name="enemy_projectile_straight")]
    parts += _fins("proj_s", 4, 0.11, BODY / 2.0, 0.05, 0.0)
    return parts, "enemy_projectile_straight"


def falling():
    """Arcs down. The same core, and the blades have become a skirt.

    Four blades swept below the equator, so the silhouette is a cone
    pointing down. It says *the ground under this is the problem* from any
    angle, and it says it without hue, which the tint has already spent.
    """
    # A POINT at the bottom and mass above it: the silhouette of something
    # arriving from overhead, whichever way round it is seen.
    parts = [brushkit.prism("proj_f_lo", 0.02, BODY * 0.40, 8,
                            (0.0, 0.0, -BODY * 0.20), top_radius=0.16,
                            asset_name="enemy_projectile_falling"),
             brushkit.prism("proj_f_hi", 0.16, BODY * 0.26, 8,
                            (0.0, 0.0, BODY * 0.13), top_radius=0.09,
                            asset_name="enemy_projectile_falling")]
    # The skirt: a ring of blades stepped downward and outward.
    for level, (inner, outer, z) in enumerate((
            (0.12, 0.22, 0.02), (0.08, 0.18, -0.05))):
        parts += _fins("proj_f%d" % level, 4, inner, outer, 0.045, z)
    return parts, "enemy_projectile_falling"


def lobbed():
    """Lands and bursts. Bulkier, segmented, with a fuse band round it.

    1.5x is the engine's own scale for a lob and this is built AT that size
    rather than relying on it, so the mesh is right whether or not the
    engine keeps the multiplier. The segmentation is what makes it read as
    something with an inside.
    """
    parts = [brushkit.prism("proj_l_lo", 0.10, LOB * 0.36, 8,
                            (0.0, 0.0, -LOB * 0.18), top_radius=0.21,
                            asset_name="enemy_projectile_lobbed"),
             brushkit.prism("proj_l_hi", 0.21, LOB * 0.36, 8,
                            (0.0, 0.0, LOB * 0.18), top_radius=0.10,
                            asset_name="enemy_projectile_lobbed")]
    # The fuse band: a proud collar on the seam, the widest thing on it.
    parts.append(brushkit.tube("proj_l_band", LOB / 2.0, 0.19, 0.07, 8,
                               (0.0, 0.0, 0.0),
                               asset_name="enemy_projectile_lobbed"))
    # Six studs on the band. A thing that is going to come apart has seams
    # and fixings; a thing that is going to hit you once does not.
    for i in range(6):
        angle = i * math.pi / 3.0
        parts.append(brushkit.block(
            "proj_l_stud_%d" % i, (0.07, 0.07, 0.11),
            (0.28 * math.cos(angle), 0.28 * math.sin(angle), 0.0),
            rotation_z=math.degrees(angle)))
    return parts, "enemy_projectile_lobbed"


KINDS = [("straight", straight, BODY), ("falling", falling, BODY),
         ("lobbed", lobbed, LOB)]


def main():
    common.reset_scene()
    report = {}
    for kind, builder, limit in KINDS:
        parts, name = builder()
        obj = common.join(parts, name)
        # ONE material, and a flat one. The engine overrides it with the
        # source world's colour, and an override replaces every surface.
        common.assign(obj, common.make_signal_material(
            name, pal.universal("hazard", 0), pal.universal("hazard", 2),
            saturation=0.85, roughness=0.35))
        common.set_origin(obj, "centre")
        common.assert_fits(obj, name, (limit, limit, limit),
                           "echo_projectile.gd sizes the visual at 0.44 m, "
                           "or 0.66 m for a lob at its own 1.5x scale.")
        report[name] = common.export_glb(obj, "%s/%s.glb" % (OUT, name),
                                         "prop", anchor="centre")
    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch008",
                       "enemy", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")


if __name__ == "__main__":
    main()
