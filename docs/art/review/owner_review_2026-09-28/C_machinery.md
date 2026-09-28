# C · The 0.4 moving machinery and room kits (045–048)

*Arty — 2026-09-28*

**What this covers.**
- The Blindside yard and its skiff.
- The kits for Passing Platforms, Counterfire Arcade and Unweighted Switch.

The 22 September fits were measured against Production `f404410`.
Tonight I re-checked them against the pinned `c12a72f`. The "today" frames
are Production's own:
- its railway shot driver, for the yard;
- `tools/owner_review_2026_09_28/capture_scenario.gd`, run on a scratch
  copy, for the three rooms. It loads Production's main scene with the
  room's own flag and changes nothing.

## Look at

1. [`sheets/C1_blindside_yard_and_skiff.jpg`](sheets/C1_blindside_yard_and_skiff.jpg):
   today's yard and skiff (Production's frames), beside the yard kit,
   the span's states and the skiff from a rider's eye.
2. [`sheets/C2_three_rooms.jpg`](sheets/C2_three_rooms.jpg): each room today,
   at the player's eye and from a review camera, beside its kit.

## Decide

1. **The Blindside kit** (045's skiff and dock stand, all of 046, 047).
   - Judge it on the owner-reviewed dev yard now, and re-fit only when a
     Zone declares rails. *Recommend:* yes.
   - *Cost:* 19 pieces reach no player until then.
2. **The skiff.** One-piece deck, or bare hull plus shield and rail?
   - *Recommend:* the kit. The bogie is optional, since it can't be seen
     from outside.
3. **The binding approach**, as the vehicle for H-MACHINE-ART, which is
   planned but not dispatched: an optional authored mesh replaces the
   BoxMesh, with the BoxMesh as fallback.
   - *Recommend:* yes, meshes only.
   - *Cost:* each binding must re-pass Production's claim, V-10 and
     foothold suites.
4. **The three room kits.** Hold them until the rooms are accepted, then
   re-brief them to the repaired rooms before judging the pieces.
   - *Recommend:* yes, hold.
   - You have already ruled on these rooms (Production's ledger at the pin,
     `docs/ledgers/post_playtest_v1.0/05_INHERITED_0_4_QUEUE.md:132-136`):
     - Passing and Unweighted: **"OWNER REJECTS CURRENT ROOM EXPERIENCE"**.
     - Counterfire: **"OWNER RECHECK / IDENTITY UNCERTAIN"**.

## What changed in Production since the 22 September fit

| Room | Change at c12a72f | Effect on the kit |
|---|---|---|
| Unweighted | The plate is a **2.4 × 0.12 × 4.5 m weighbridge** (was 2.4 × 2.4). The crate became a **guided service carriage** with shoes on the rails (PT-05). The guide rails dropped **1.4 → 0.45 m**. Drive speed rose 1.1 → 2.3. | `sp_weight_plate`, `sp_ballast_crate`, `uw_plate_frame` and `uw_drive_housing` need a re-brief. |
| Passing | A **glass gallery G**, and a gate open only while the shuttle is docked there. 13 labelled controls. | A06.5 (the glass gate) can now be delivered; the gate state exists. |
| Counterfire | A shutter readout (SHUT / OPEN · Ns / CLOSING / HELD OPEN), and a lever that locks thrown. The Check has moved. | Decide whether the art's pips and bolt are still needed. |
| Yard (dev) | Unchanged sources. New points hardware exists, but no Zone uses it. | Still fits. The Zone railways (deck 3.4 × 0.35 × 5.0, gantry 2.9 / 6.2 m) were never fitted. |

## Status, kept apart

- **Visual approval:** none.
  - 045 PENDING (`docs/art/ART_REVIEW.md:4064`).
  - 046 PENDING (`:4108`).
  - 048 PENDING (`:4152`).
  - 047 PENDING (`:4609`).
- **Technical compatibility:** the yard still fits. The room kits no longer
  match (see the table).
- **Runtime binding:** none. `rail_carrier.gd` and `shuttle_deck.gd` build a
  BoxMesh. The only hook is `ServiceShutter.panel_material`.
- **Normal gameplay:** none.
  - `--railway` is operator-only scaffolding.
  - The three rooms are hosted only by the opt-in candidate profile.

## Assets

- `assets/models/batch045/setpieces/`: `sp_*`, including `sp_skiff_deck_bare`.
- `assets/models/batch046/yardkit/`: `yk_*`, and `yard_fit.json`.
- `assets/models/batch047/skiffkit/`: `sp_skiff_{shield,rail,bogie}`.
- `assets/models/batch048/roomkits/`: `pp_*`, `cf_*`, `uw_*`.

The handoffs are
`docs/art-requests/2026-09-22-{setpiece-visual,yardkit,skiffkit,roomkits}-handoff.md`.
They are not in Production's tree.

## Found tonight (nothing repaired; smallest repair given)

| Asset | Defect (measured on the GLB) | Smallest repair |
|---|---|---|
| `sp_skiff_deck`, `sp_skiff_deck_bare` | `lamp_fore` at z −2.08..−1.92 is the TRAILING lamp (runtime forward is +Z, `rail_carrier.gd:420`) | swap the fore/aft names (`tools/blender/build_setpieces.py:220`) |
| `sp_crossing_carrier` | buffers and lamps on local ±X, the sides, not the ends | rotate them 90° to the ends |
| `sp_hoist_car` | its back is on the transfer face | move it to the closed face |
| `uw_plate_frame` | a closed four-sided recess whose wall crosses the drive corridor | drop the approach wall; resize to 2.4 × 4.5 |
| `uw_drive_housing` | case x 1.25–1.95 and rail x 1.14–1.30 overlap the guide rails and shoes | move it outboard; drop the drive rail |
| `cf_shutter_track` | `track_head` at y 1.30–1.56 sits inside the leaf's 2.6 m rise | lengthen the rails; lift the head above the rise |
| `cf_lane_mark` | grows outward, under the wall segments | mirror it inward |
| `sp_lane_screen` | 3.0 × 1.37 against 1.6 × 1.7 wall segments | resize per segment |
| `yk_gantry_anchor` | a ceiling mount in an open-sky yard | re-mount it on the column |
| Evidence frames | `pp_rendezvous` puts the transfer edges across the gap; `cf_lane` draws continuous walls; `uw_switch` leaves the drive housing unrotated; `rider_eye_crouched` shows a crouch the game does not have | re-shoot in Production-built rooms, and record the SHA in the fit outputs |
