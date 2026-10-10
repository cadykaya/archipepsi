# Owner review: the existing candidates and the room library

*Arty — 2026-09-28*

**The package** is `docs/art/review/owner_review_2026-09-28/`. Start at
`START_HERE.md`.

**What it is:** the art lane's half of the art catch-up. Production
integrates the approved work. This package turns the unreviewed work into
visual decisions, and shows the ordinary-room vocabulary we already own.

## What it covers

**About 170 candidate models, in roughly 30 decisions**, each grouped by
the shared design choice. For every group:
- the four statuses, kept apart;
- the exact decision, with a recommendation and its cost;
- the engineering that remains afterwards;
- asset paths;
- tonight's findings.

**The groups:**
- A: controls and machinery feedback (028, 043, 049).
- B: manipulation objects (043, 053).
- C: the 0.4 machinery and room kits (045–048).
- D: status, job and combat feedback (050–052).
- E: the source-game packs (054–061, and the T01/T05 textures).
- An appendix: the late-August candidates, the held projectiles, the
  proof-only work, and corrections.

**The room library:** six existing rooms, three alternates and the poor
fits. Each has an eye-height view and a roof-off plan drawn from the model
itself, set against today's ordinary rooms and the fallback's rules.

## How it was made

- **Existing images first.** An older render of a shape is reused only
  where its geometry is unchanged (checked by
  `tools/owner_review_2026_09_28/glb_geometry_diff.py`).
- **Re-rendered where the old evidence was stale or missed the question:**
  - the connect views (textures re-baked);
  - the cross junction (its geometry moved);
  - the seven prop packs, under one fixed light;
  - the older 028 switch and plate (their images predated 035-R).
- **"Today" frames are Production's own**, from the pinned revision
  `c12a72fbc62500f4815d683d66a97f47fe514b06`, on a scratch copy:
  - its railway, candidate and zone shot drivers;
  - `capture_scenario.gd`, for the three minor rooms.
- **The 22 Sept fits were re-checked** against the pin.
- **Isolated:** every helper is in `tools/owner_review_2026_09_28/`. No
  source asset, shared builder, shipping export, registry or approval flag
  changed.

## Correction

My audit's T05 line said T05's textures were accepted as candidates. The
25 Sept ruling accepted T05's accent and calmed its floor, but gave it no
candidate status. The line now carries a dated correction.

## Stopping point

The package is complete, and I have stopped for your decisions.
- Nothing was promoted, integrated or repaired.
- The defects are reported with their smallest repairs.
- There are no watchers, subscriptions or check-ins.
