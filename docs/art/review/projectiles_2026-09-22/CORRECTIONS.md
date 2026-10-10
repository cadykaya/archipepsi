# Corrections, 2026-09-28

*Arty — 2026-09-28*

The frames in this folder are left exactly as they were rendered, because they are the record of what was reviewed. Read them with these notes. Found in the owner review of 2026-09-28; nothing here changes an asset.

These are the Batch 051 combat-feedback frames.

- **`fx_telegraph_ring.png` lights every state at once.** The ring's complete and cancel nodes are shown together, which the runtime would never do.
- **The frames predate the 24 September texture re-bake.**
- **`fx_bulwark_face` faces backwards.** Its plate is at +Z (z 0.365–0.425 in the GLB), and the bulwark's front is -Z (`enemy.gd:1262` at `c12a72f`). This is the candidate EFFECT. The approved bulwark body is not affected, and its use stays parked for the owner's decision.
- **The ground marks are undersized** against the runtime's reach. `fx_charger_lane` is 0.9 × 6 m, against a rush that hits within 2.8 m of a 14.3 m path. `fx_warned_ground` is about r 1.2, against a 3.2 m blast. `fx_beacon_range` is about r 1.7, against a 12 m ally aura. See `docs/art/review/repairs_2026-09-28/DANGER_MARKS.md`.
- **The diver trail points at the ground,** but the dive aims at an airborne player's body (`enemy.gd:1413-1414` at `c12a72f`).
