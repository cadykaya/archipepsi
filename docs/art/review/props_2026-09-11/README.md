# Batch 043 / C — the physics-prop family

**Arty**

Six of Design 2 §10.1's twelve object classes, taken through to textured,
exported candidates, with all twelve mapped against the existing catalogue.
The six complete the family's mass ladder: 8, 40, 55, 95, 140, 320 kg,
straddling §10.3's 60 kg carry line.

**PROPOSAL.** No collider is derived or shipped; nothing here is traversal or
physics evidence; player physics, object mass rules, carry limits and package
schemas are untouched.

The map, the family rule and the four candidates' numbers are in
`CLASS_MAP.md`.

| frame | what it shows |
| --- | --- |
| `room/PROPS_lineup.png` | the mass ladder — five standing in ascending mass, with the 3.20 m girder across the front |
| `room/PROPS_manipulable_vs_decorative.png` | three candidates beside `prop_crate`, `prop_oil_drum` and `prop_debris` — the frame the family rule has to survive |
| `room/PROPS_close_*.png` | one per candidate, at the distance a player decides whether to pick something up |

Rebuild:

```
.tools/blender/blender -b --python tools/blender/build_physics_props.py
tools/content/run_props_preview.sh
```
