"""Review-only views for Batch 063 (`build_crossing_kit.py -- <dir>`).

Not a builder and not assets. It builds two scenes from the kit's own
piece functions and writes them as .glb files into the directory it is
given, for `tools/shoot.sh` to photograph in the engine:

* `lever_off.glb`, `lever_on.glb` -- the lever at its two declared
  positions, the pilot turned and lit for ON;
* `route_off.glb`, `route_on.glb` -- one power line from the lever to a
  shutter's terminal: along the floor, into the wall, up it, a turn,
  along it. Every fitting is a kit piece at its authored size.

LIVE is shown by giving the state nodes the live material. The shipped
files carry idle and no emission; lighting a state is the runtime's.
"""

from __future__ import annotations

import math
import os

import bpy
import mathutils


def _matrix(x_to, y_to, z_to, at):
    """A placement from where the authored axes go, and where to."""
    m = mathutils.Matrix.Identity(4)
    for col, v in enumerate((x_to, y_to, z_to)):
        for row in range(3):
            m[row][col] = v[row]
    m.translation = mathutils.Vector(at)
    # Proper rotations only: a mirrored piece would flip its own UVs and
    # its winding, and look right in a viewport that culls nothing.
    assert abs(m.to_3x3().determinant() - 1.0) < 1e-6, (x_to, y_to, z_to)
    return m


def _place(objects, m):
    # `matrix_basis`, not `matrix_world`: a pose set through
    # `rotation_euler` reaches `matrix_world` only on the next depsgraph
    # update, so composing with `matrix_world` here would silently drop
    # the lever's pose. Every object placed here is top-level.
    for obj in objects:
        assert obj.parent is None, obj.name
        obj.matrix_basis = m @ obj.matrix_basis


def _live(kit, parts):
    live = kit._material("ck_power_live")
    for obj in parts:
        if obj.type == "MESH" and obj.name.startswith(("power_", "pilot_bar")):
            obj.data.materials.clear()
            obj.data.materials.append(live)


def _lever(kit, state, m):
    structure, decoration, parts, hinges = kit.floor_lever()
    body = kit.common.join(structure + decoration, "lever_" + state)
    empties = []
    for spec in hinges:
        empty = kit._hinge(spec["node"], spec["moving"], spec["pivot"])
        # Runtime +Z (toward the player) is authoring -Y, so a runtime
        # angle about +Z is the negative angle about authoring +Y.
        degrees = spec["positions_degrees"][state]
        empty.rotation_euler = (0.0, math.radians(-degrees), 0.0)
        empties.append(empty)
    if state == "on":
        _live(kit, parts)
    _place([body] + empties, m)
    return [body] + empties + parts


def _piece(kit, build, m, live):
    blocks, parts = build()
    body = kit.common.join(blocks, build.__name__)
    if live:
        _live(kit, parts)
    _place([body] + parts, m)
    return [body] + parts


def _export(objects, path):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB",
                              use_selection=True, export_apply=True,
                              export_texcoords=True, export_normals=True,
                              export_materials="EXPORT",
                              export_image_format="AUTO", export_yup=True)
    print("[kit-review] %s" % path)


# Axis shorthands, authoring frame (Z up). The back wall's face is the
# plane y = WALL_Y, facing -Y, toward the player.
X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)
NX, NY, NZ = (-1, 0, 0), (0, -1, 0), (0, 0, -1)
WALL_Y = 1.5
LEVER_X = -1.4


def _route(kit, live):
    kit.common.reset_scene()
    kit._IMAGES.clear()
    kit._MATERIALS.clear()
    objs = []
    # The room: a floor and the wall the line climbs, in the theme.
    objs.append(kit._b("floor", (5.0, 4.6, 0.2), (0.0, -0.8, -0.1), "floor"))
    objs.append(kit._b("wall", (5.0, 0.2, 3.2), (0.0, WALL_Y + 0.1, 1.6),
                       "wall"))
    # The thing it powers: a plain shutter, recessed.
    objs.append(kit._b("shutter", (1.2, 0.06, 2.3), (1.45, WALL_Y - 0.01,
                                                     1.15), "trim"))
    kit._tile(objs)
    state = "on" if live else "off"
    # The lever, its gland's rear face at y = 0, so one 1 m run reaches
    # the inside corner's 0.5 m floor leg exactly at the wall.
    objs += _lever(kit, state, _matrix(X, Y, Z, (LEVER_X, -0.36, 0.0)))
    # Along the floor toward the wall (authored +X turned to +Y).
    objs += _piece(kit, kit.raceway_run, _matrix(Y, NX, Z, (LEVER_X, 0.5,
                                                           0.0)), live)
    # Into the wall: the floor leg points back at the lever (-Y), and the
    # wall it climbs faces -Y.
    objs += _piece(kit, kit.raceway_inside, _matrix(NY, X, Z, (LEVER_X,
                                                              WALL_Y, 0.0)),
                   live)
    # Up the wall, 0.5 .. 1.5 m.
    objs += _piece(kit, kit.raceway_run, _matrix(Z, NX, NY, (LEVER_X, WALL_Y,
                                                            1.0)), live)
    # The turn at 2.0 m: one leg down to meet the climb, one along +X.
    objs += _piece(kit, kit.raceway_turn, _matrix(NZ, X, NY, (LEVER_X,
                                                             WALL_Y, 2.0)),
                   live)
    # Along the wall to the shutter's terminal.
    objs += _piece(kit, kit.raceway_run, _matrix(X, Z, NY, (LEVER_X + 1.0,
                                                           WALL_Y, 2.0)),
                   live)
    objs += _piece(kit, kit.raceway_terminal, _matrix(X, Z, NY,
                                                      (LEVER_X + 1.74,
                                                       WALL_Y, 2.0)), live)
    return objs


def write(out_dir, kit):
    os.makedirs(out_dir, exist_ok=True)
    for state in ("off", "on"):
        kit.common.reset_scene()
        kit._IMAGES.clear()
        kit._MATERIALS.clear()
        _export(_lever(kit, state, _matrix(X, Y, Z, (0.0, 0.0, 0.0))),
                os.path.join(out_dir, "lever_%s.glb" % state))
    for live in (False, True):
        _export(_route(kit, live),
                os.path.join(out_dir, "route_%s.glb"
                             % ("on" if live else "off")))
