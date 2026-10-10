# Corrections, 2026-09-28

*Arty — 2026-09-28*

The frames in this folder are left exactly as they were rendered, because they are the record of what was reviewed. Read them with these notes. Found in the owner review of 2026-09-28; nothing here changes an asset.

- **In `sp_skiff_deck.png` and `sp_skiff_deck_bare.png`, `lamp_fore` is the trailing lamp.** It is repaired on the repair branch, with the same geometry and swapped names.
- **`sp_crossing_carrier` and `sp_hoist_car` do not fit the Passing room at `c12a72f`.**
  - The crossing carrier's buffers and lamps sit on its local ±X, the sides. The V-to-H transfer crosses its +X side, and the H-to-G step crosses its +Z end, so neither placement is clear.
  - The hoist car's closed back is at +Z, the face toward H.
  - Both are held for the Passing room decision.
