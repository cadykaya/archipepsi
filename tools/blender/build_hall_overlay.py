"""Review overlays for the hall — five diagrams, DERIVED from its manifest.

    .tools/blender/blender -b --python tools/blender/build_hall_overlay.py

These are NOT content. Nothing here is exported to the pack, registered,
or reviewed as art: they are figures for the P3 owner-review package,
composed over the real shell by the shot runner's `a.glb + b.glb@0,0,0`
syntax so they land in the shell's own space.

WHY THEY ARE BUILT INSTEAD OF DRAWN. A 2D annotation of a render is a
second authoring of the data: it can say the rail runs through the
armature while the shipped `rail_route` says something else, and nobody
would catch it. Every point here is READ FROM
`assets/models/batch039/shells/manifest.json`. If the shell changes and
the diagram is not rebuilt, the diagram is missing, not wrong.

WHAT IS DELIBERATELY NOT DRAWN.

  * NO LAUNCH ARC. `LaunchSolver` derives the trajectory from the two
    regions and gravity, and Art never authors velocity, direction or
    arc. Drawing a curve between the pads would be authoring one in a
    picture -- and the first time the solver disagreed, the picture
    would be the thing everybody remembered. The two regions are drawn
    at their declared radii and nothing joins them.
  * NO GRAPPLE OFFER. `OFFER_KINDS` is closed at rail_route,
    launch_source and launch_target; `grapple_anchor` is deliberately
    absent. The grapple figure marks the OVERHEAD STRUCTURE this room
    already has -- what an anchor would have to hang from -- and says so
    in its own name. It is a question for the owner, not a claim.
"""

from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

import brushkit  # noqa: E402
import common  # noqa: E402

MANIFEST = os.path.join(common.REPO_ROOT, "assets", "models", "batch039",
                        "shells", "manifest.json")
OUT = "batch039/overlays"

#: Diagram ink. Bright and EMISSIVE, because these are composed into a
#: lit room and a matte swatch in shadow reads as geometry rather than
#: annotation.
INK = {
    "route":   "#ffb020",   # the mandatory walking route
    "rail":    "#31d0ff",   # the rail_route offer
    "launch":  "#ff4f7a",   # the launch pair
    "region":  "#7de08a",   # a named stand surface
    "high":    "#c58cff",   # an enemy_high socket
    "struct":  "#ffe066",   # overhead structure (grapple question)
    "shaft":   "#66f0d8",   # the open vertical column
}


def _mat(key):
    # Emission 0.7, not 2.4. At 2.4 the bench's tone mapping clipped
    # every ink to white and the four figures became indistinguishable
    # -- a diagram whose whole job is "which line is which" cannot spend
    # its colour on being bright. Enough emission to sit forward of a
    # lit wall, not enough to blow out.
    return common.make_material("ov_%s" % key, INK[key], roughness=0.4,
                                emission_hex=INK[key], emission_strength=0.7)


def _blender(godot_xyz):
    """Godot (x, y, z) -> Blender (x, y, z). The inverse of
    `roomcontract.godot`, and the only conversion in this file."""
    gx, gy, gz = godot_xyz
    return (gx, -gz, gy)


def _add(parts, obj, key):
    common.assign(obj, _mat(key))
    parts.append(obj)
    return obj


def _plate(parts, name, centre_godot, extent, key, thick=0.30):
    """A slab lying on a surface, at the surface's own centre and size."""
    x, y, z = _blender(centre_godot)
    _add(parts, brushkit.block(name, (extent[0], extent[1], thick),
                               (x, y, z + thick / 2.0)), key)


def _post(parts, name, at_godot, height, key, radius=0.35):
    x, y, z = _blender(at_godot)
    _add(parts, brushkit.prism(name, radius, height, 8,
                               (x, y, z + height / 2.0)), key)


def _disc(parts, name, at_godot, radius, key, thick=0.25):
    x, y, z = _blender(at_godot)
    # 12 sides, not 24: `common.assert_segments` caps radial detail at
    # 12 above a 1.5 m radius, and a diagram is not a reason to raise a
    # cap. A 12-gon reads as a circle at these sizes anyway.
    _add(parts, brushkit.prism(name, radius, thick, 12,
                               (x, y, z + thick / 2.0)), key)


def _export(parts, stem):
    obj = common.join(parts, stem)
    out = os.path.join(common.MODEL_DIR, OUT, "%s.glb" % stem)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    # No `export_glb`: that runs the triangle budget, the texel-density
    # assertion and the manifest write, and every one of those is a rule
    # about SHIPPED ART. A diagram is not shipped art and passing it
    # through the art gate would either weaken the gate or fail honestly
    # for no reason.
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB",
                              use_selection=True, export_apply=True,
                              export_normals=True, export_materials="EXPORT")
    print("[art] overlay %s/%s.glb  %d tris"
          % (OUT, stem, common.triangle_count(obj)))


# --------------------------------------------------------------- figures

def fig_regions(m):
    """Every named stand surface, as a coloured plate at its own size.

    The owner's question is "several local gameplay spaces, or one big
    rectangle?" -- so this is just the surfaces, drawn where they are.
    """
    parts = []
    for s in m["surfaces"]:
        _plate(parts, "reg_%s" % s["name"], s["center"], s["extent"],
               "region")
    for k in m["sockets"]:
        if k["kind"] == "enemy_high":
            _post(parts, "hi_%s" % k["name"], k["position"], 2.0, "high")
    _export(parts, "hall_ov_regions")


def fig_route(m):
    """The MANDATORY walking route, end to end, with NO offer consumed.

    This is the figure that answers "is every layer reachable with no
    movement package installed" -- the condition the offers are allowed
    to exist under.

    THICK BARS ARE DECLARED SEGMENTS. THIN BARS ARE NOT. A traversal
    segment is declared edge to edge -- `bridge_n_to_ring_n` is 2 m long
    because that is the width of the seam it crosses -- so drawing only
    the declarations gives nine short bars scattered through a 60 m room
    and communicates nothing. The thin connectors are the crossings of
    the surfaces BETWEEN those seams, drawn so the route reads as one
    route. Art declares the seams; the connectors are this diagram's
    reading of what joins them, and they are drawn differently so the
    two are never mistaken for each other.
    """
    parts = []
    chain = [t for t in m["traversal"] if t.get("mandatory", True)]
    prev_end = None
    for t in chain:
        a, b = _blender(t["start"]), _blender(t["end"])
        if prev_end is not None and _far(prev_end, a):
            _add(parts, brushkit.sweep("rt_link_%s" % t["name"],
                                       [prev_end, a], 0.35, 0.35), "route")
        _add(parts, brushkit.sweep("rt_%s" % t["name"], [a, b], 1.10, 0.40),
             "route")
        prev_end = b
    for t in m["traversal"]:
        if t.get("mandatory", True):
            continue
        _add(parts, brushkit.sweep("rt_opt_%s" % t["name"],
                                   [_blender(t["start"]), _blender(t["end"])],
                                   0.45, 0.25), "route")
    _export(parts, "hall_ov_route")


def _far(a, b, eps=0.05):
    return (abs(a[0] - b[0]) > eps or abs(a[1] - b[1]) > eps
            or abs(a[2] - b[2]) > eps)


def fig_rail(m):
    """The `rail_route` offer, swept along its own control points.

    A rail is an ordered path, so this is the one figure where the shape
    matters as much as the place: it should read as a route that USES
    the room's whole height and goes around the landmark, not a handrail
    stuck to a wall.
    """
    parts = []
    offer = _offer(m, "rail_route")
    pts = [_blender(p) for p in offer["points"]]
    _add(parts, brushkit.sweep("rail", pts, 0.55, 0.55), "rail")
    for i, p in enumerate(pts):
        _add(parts, brushkit.prism("rail_pt_%d" % i, 0.55, 0.55, 8, p),
             "rail")
    _export(parts, "hall_ov_rail")


def fig_launch(m):
    """The launch PAIR: two regions at their declared radii, and no arc.

    See the module docstring for why nothing joins them. The two ends
    are told apart by FORM rather than by a second colour: the source is
    a filled DISC ("stand here") and the target an open RING ("land
    inside here"). One offer, one ink, two readable roles -- and neither
    shape says anything about the path between them.
    """
    parts = []
    src = _offer(m, "launch_source")
    dst = _offer(m, "launch_target")
    _disc(parts, "lp_%s" % src["name"], src["position"], src["radius"],
          "launch")
    x, y, z = _blender(dst["position"])
    _add(parts, brushkit.tube("lp_%s" % dst["name"], dst["radius"],
                              dst["radius"] - 0.5, 0.3, 12, (x, y, z + 0.15)),
         "launch")
    # Masts, so a pad is findable in a wide shot. The target's is taller
    # because it sits ON a deck 21 m up and is edge-on from the basin.
    _post(parts, "lp_%s_mast" % src["name"], src["position"], 2.0, "launch",
          radius=0.22)
    _post(parts, "lp_%s_mast" % dst["name"], dst["position"], 4.0, "launch",
          radius=0.22)
    _export(parts, "hall_ov_launch")


def fig_overhead(m):
    """OVERHEAD STRUCTURE -- the grapple question, not a grapple offer.

    `grapple_anchor` is not in `OFFER_KINDS`. What the room can honestly
    show is where solid structure already spans above open floor: the
    armature's three collar rings, and the underside of the two upper
    decks. If a grapple package ever arrives, these are the surfaces it
    would have to hang from, and the owner can say now whether that is
    the room they want.

    The rings are read from the `core` no_build volume, which is the
    armature's own declared footprint -- not retyped from the builder.
    """
    parts = []
    core = _volume(m, "core")
    cx, _, cz = core["center"]
    # `size` is the volume's full extent, so the ring's OUTER RADIUS is
    # half of it. Getting this wrong draws a collar twice the width of
    # the thing it describes -- exactly the class of error that deriving
    # from the manifest is supposed to remove.
    out = core["size"][0] / 2.0
    for i, top in enumerate(_ring_tops(m)):
        _add(parts, brushkit.tube("oh_ring_%d" % i, out, out - 3.0, 0.5, 12,
                                  _blender((cx, top, cz))), "struct")
    for name in ("west_gallery", "east_gantry", "north_landing"):
        s = _surface(m, name)
        x, y, z = _blender(s["center"])
        _add(parts, brushkit.block("oh_%s" % name,
                                   (s["extent"][0], s["extent"][1], 0.4),
                                   (x, y, z - 0.9)), "struct")
    _export(parts, "hall_ov_overhead")


def fig_shaft(m):
    """The VERTICAL MOVEMENT column: the open air the room is built round.

    Drawn as a stack of open rings through the middle of the armature,
    from the basin to the top of the core, so the reader can see that
    the vertical space is CONTINUOUS -- a wind column, a lift, a chain
    of moving platforms or a grapple climb all want the same thing, and
    the shell either has it or it does not.
    """
    parts = []
    core = _volume(m, "core")
    cx, _, cz = core["center"]
    # The armature's open shaft is 12 m across inside an 18 m collar,
    # so its RADIUS is 6 -- the core volume's half-extent less the 3 m
    # the collars occupy, which is how the builder laid them out.
    inner = core["size"][0] / 2.0 - 3.0
    top = core["center"][1] + core["size"][1] / 2.0
    step = 2.5
    n = int(top / step)
    for i in range(n + 1):
        _add(parts, brushkit.tube("sh_%d" % i, inner, inner - 0.8, 0.16, 12,
                                  _blender((cx, i * step, cz))), "shaft")
    _export(parts, "hall_ov_shaft")


# --------------------------------------------------------------- lookups

def _offer(m, kind):
    for o in m["offers"]:
        if o["kind"] == kind:
            return o
    raise AssertionError("the hall declares no '%s' offer" % kind)


def _surface(m, name):
    for s in m["surfaces"]:
        if s["name"] == name:
            return s
    raise AssertionError("the hall declares no surface '%s'" % name)


def _volume(m, name):
    for v in m["volumes"]:
        if v["name"] == name:
            return v
    raise AssertionError("the hall declares no volume '%s'" % name)


def _ring_tops(m):
    """The collar heights, read from the `ring_*` stand surfaces rather
    than from the builder's constants -- the rings the player walks on
    ARE the structure overhead of the basin, and one of the three has no
    surface because nobody stands on it. The third is the core's top."""
    tops = sorted({s["center"][1] for s in m["surfaces"]
                   if s["name"].startswith("ring_")})
    core = _volume(m, "core")
    tops.append(core["center"][1] + core["size"][1] / 2.0)
    return tops


def main():
    common.reset_scene()
    with open(MANIFEST, encoding="utf-8") as handle:
        m = json.load(handle)["shell_hall_transit"]
    for fig in (fig_regions, fig_route, fig_rail, fig_launch, fig_overhead,
                fig_shaft):
        common.reset_scene()
        fig(m)


if __name__ == "__main__":
    main()
