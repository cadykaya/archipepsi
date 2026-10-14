"""The approved Foundry as an integration geometry GLB. (Arty, 2026-10-14.)

    .tools/blender/blender -b --python tools/blender/foundry_geometry.py -- OUT

The Foundry study (`build_foundry_study.py`, approved, unchanged) exports
one GLB with its four maps embedded as RGBA8. For integration the model is
wanted without them, so the lean maps (`lean_maps.py`, made from the
study's own Glyph exports) are the only copies that reach the GPU. This
builds the same objects through the study's own functions, unwraps them
with the study's own unwrap, and REFUSES unless the UVs reproduce the
fingerprint the approved maps were baked on: the geometry and the maps
then belong together texel for texel. Then it exports the model with one
empty, named material slot, the hammer at rest (identity), the carousel
pivot and the muzzle, as the study's GLB has them.
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

import build_foundry_study as fs  # noqa: E402
import common  # noqa: E402

#: the approved study's bake (scratch run4, the maps committed in
#: docs/art/review/foundry_study_2026-10-13/model/maps)
APPROVED_UV = "7c6f8b373880cd1f"


def main():
    out = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
    os.makedirs(out, exist_ok=True)
    common.reset_scene()
    body, hammer, carousel, muzzle = fs.assemble_objects()
    objs = [body, hammer, carousel]
    fs.unwrap(objs)
    fp = fs.uv_fingerprint(objs)
    if fp != APPROVED_UV:
        raise SystemExit("Foundry UVs %s differ from the approved maps' %s"
                         % (fp, APPROVED_UV))
    fs.triangulate(objs)
    mat = bpy.data.materials.new("foundry_dev")
    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(mat)
    root = bpy.data.objects.new("FoundryStudy", None)
    bpy.context.scene.collection.objects.link(root)
    for o in objs + [muzzle]:
        o.parent = root
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs + [muzzle, root]:
        o.select_set(True)
    bpy.context.view_layer.objects.active = root
    path = os.path.join(out, "foundry_geo.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB",
                              use_selection=True, export_apply=False,
                              export_texcoords=True, export_normals=True,
                              export_tangents=True,
                              export_materials="PLACEHOLDER",
                              export_yup=True)
    common.log("foundry geometry: uv %s (approved), %d tris -> %s"
               % (fp, fs.triangles(objs), path))


if __name__ == "__main__":
    main()
