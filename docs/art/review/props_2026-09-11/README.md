# Batch 043 / C — the physics-prop family

**Arty**

**All twelve** of Design 2 §10.1's object classes, taken through to textured,
exported candidates. The map, the family rule, the coordinate contract and
the two verifiers are in `CLASS_MAP.md`.

**PROPOSAL.** No collider is derived or shipped; nothing here is traversal or
physics evidence; player physics, object mass rules, carry limits and package
schemas are untouched. `prop_crate` and `prop_oil_drum` are unchanged.

| frame | what it shows |
| --- | --- |
| `room/PROPS_lineup_bright.png` · `_dark.png` | all twelve, in three rows split at §10.3's 60 kg carry line, under bright concrete and dark derelict |
| `room/PROPS_candidate_vs_decorative_*.png` | `prop_crate` beside `phys_generic`, `prop_oil_drum` beside `phys_drum` — the decoration/candidate split, settled |
| `room/PROPS_fixed_vs_movable_*.png` | `ANCHOR_BLOCK` (`FIXED`, one tether eye) beside `BALLAST` (four attach pads) |
| `room/PROPS_close_*.png` | one per candidate, at the distance a player decides whether to pick something up |

Every object in the line-up is placed by its **measured** width and every
label is **projected from the object's own position**, so a caption cannot
drift onto the wrong object.

Rebuild:

```
.tools/blender/blender -b --python tools/blender/build_physics_props.py
python3 tools/content/verify_attach_points.py
tools/content/run_props_preview.sh
```
