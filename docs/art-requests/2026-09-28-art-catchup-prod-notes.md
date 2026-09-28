# ART-CATCHUP: Production's notes back to the art lane

*Prod — 2026-09-28. Frozen art source: `a1584c8` (pack-free theme
descriptor from `3e73a2ca`). Branch `wip/0.4-art-catchup`.*

Narrow dependencies found while loading approved art. None of these asks
for new art; each says what Production now relies on, or what blocked a
wire-up. Nothing here is a visual approval.

## 1. `tools/verify_content_pack.sh` damages Production's tree

Running it on a Production checkout deletes
`godot/content/registry/legacy_procedural.json` (tracked) and every
untracked file under `godot/` (including scratch harnesses). The Godot
content suite then fails until the file is restored with
`git checkout`. Production does not run it any more; if it is meant to be
run against a Production tree, it needs to leave tracked files and
untracked files outside what it generates alone.

## 2. Enemies (batch 030): the contracts Production now reads

- **Eyes.** The attack-warning eye stays Production's. It is seated on
  the model by casting in from outside along the role's facing (−Z; down
  for the drifter) and sitting 1.5 cm proud of the first surface hit. The
  `anchor_warn` marker, where present, sets where the cast is aimed
  (otherwise 80% of the body's height on the centre line). A body whose front is recessed further than its silhouette will
  seat the eye on the outer surface, not in the recess.
- **Anchors** are read as the marker mesh's AABB centre (the marker
  nodes' origins are all 0). If markers are ever re-exported with real
  node origins, both readings agree; if the marker mesh is removed, the
  anchor is lost.
- **Floor origin, −Z facing.** Flyers are authored on the floor and lifted
  by the runtime to their hover height.
- **Value bands** come from `enemy_value_bands.json` as shipped; the tint
  (damage flash, status) is applied through per-surface override
  materials, so a model whose colour moved into vertex colours or an
  unlit material would stop flashing.
- **Brute:** the body is 6.7 cm taller than its collider. Collision is
  unchanged (gameplay truth); the visual overhang is small and left as is.
- **`fx_bulwark_face` (batch 051)** is a candidate overlay and is not
  loaded. The approved bulwark body is loaded without it, so the "face on
  the back" defect does not reach play.

## 3. The Hub (batches 002 and 003)

- **Epsilon's installation** measures 9.02 × 3.55 × 3.48 m (runtime
  axes), not the 8.80 × 3.55 × 2.61 of the original requirement. The Hub's
  reserved bay now takes the model's measured size, and the lab test
  measures the shipped model rather than a number. It faces +Z into the
  room.
- **The two boards** back the existing live boards; the live labels stay
  on their faces.
- **The shop counter, archive terminal and abandon station are not
  wired.** They are 2.45 m (shop, archive) and 1.27 m (abandon) tall
  cabinets; the game's interactive stations are 1.1 m counters whose
  interaction volumes, placards and labels players already use. Swapping
  them is a fit decision (does the counter grow, or does the model gain a
  counter-height version?), not a texture swap, so they wait for that
  decision.
- `hub_lab_doorway.glb` was refreshed as source only; it is not placed.
