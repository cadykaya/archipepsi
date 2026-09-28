# Owner review: the existing candidates, and the rooms we already own

*Arty — 2026-09-28*

> *Later on 2026-09-28:* the dated corrections since `a1584c8` are in
> [CORRECTIONS_2026-09-28.md](CORRECTIONS_2026-09-28.md), and the
> authorised repairs are in `docs/art/review/repairs_2026-09-28/`.

The unreviewed candidates (about 170 models) are grouped into roughly 30
decisions, one per shared design choice rather than one per file. The
existing ordinary-room library is shown beside today's rooms. Nothing is
promoted, integrated or bound.

**Baselines:**
- Art source: `32df699` (the audit), reused as committed.
- Production: read only at **`c12a72fbc62500f4815d683d66a97f47fe514b06`**,
  pinned, as a scratch copy. Prod's branches, worktree and session were not
  touched.
- Prod's menu WIP has moved to `bd61e39`; it is not used here.

**Every image carries a tag:**
- **current game placeholder** (Production's own frame);
- **posed reference** (not a live test);
- **art render** (a review scene);
- **plan**;
- **new review render**.

Four statuses are always kept apart: visual approval, technical
compatibility, runtime binding, and whether it's in normal gameplay.

## Decide these first

These are the decisions that unlock existing work first.

1. **A permanent control** ([A1](sheets/A1_controls_commitments.jpg)).
   Your 24 Sept D-07 ruling asks for "a visibly different permanent
   control". Approve a lever that visibly locks (or the 049 seal) as the
   permanent silhouette?
   - Also: recaption the 049 paddle as momentary, and keep "held" for
     plates.
2. **Pickup at a glance** ([B1](sheets/B1_manipulation_classes.jpg)).
   Give the four carriables an object-scale tell, such as 035-R's bail
   arch?
   - The class stays the object's flag and kilograms.
3. **Rooms we already own** ([R1](sheets/R1_room_reuse_a.jpg),
   [R2](sheets/R2_room_reuse_b.jpg)). Put the bays, gallery, pillars,
   balcony and triad into the small / standard / large discussion before
   commissioning anything new?
   - Ask Prod to re-rule req 35, now that his `adopt()` exists.
4. **Danger marks at the runtime's size**
   ([D2](sheets/D2_ground_marks_to_scale.jpg)), and **the telegraph
   grammar** ([D1](sheets/D1_telegraph_ring.jpg)).
   - The rush is 14.3 m, the blast 3.2 m, the beacon range 12 m; the art is
     smaller.
   - Approve the ring's grammar, and hold its flat orientation.
5. **Status markers** ([D4](sheets/D4_status_markers.jpg)). Rule on
   empowered's family and frozen's family, and name who owns the HUD tier.
6. **The Blindside kit** ([C1](sheets/C1_blindside_yard_and_skiff.jpg)).
   - Judge it on the dev yard.
   - Build the skiff as a kit.
   - Approve the optional-mesh binding as the vehicle for H-MACHINE-ART.
7. **The three room kits** ([C2](sheets/C2_three_rooms.jpg)). **Hold** them
   until you accept the rooms themselves. You have already rejected
   Passing and Unweighted and asked for a recheck of Counterfire, and all
   three rooms have changed since 22 Sept.
8. **Source-game packs** ([E2](sheets/E2_seven_prop_packs_one_light.jpg),
   [E1](sheets/E1_T01_T05_textures_same_room.jpg)).
   - Rule the identity principle once, then give each pack a yes or no.
     Their status stays candidate.
   - For T01 and T05: choose the id a Zone names, and rule temple_ruin's
     course treatment first.
9. **Machine state** ([A2](sheets/A2_machine_state_language.jpg)). Treat
   the conduit band as one family, and settle H-CIRCUITS before any world
   plaque.
10. **Late-August leftovers** ([appendix](APPENDIX.md)).
    - Questionable Goods fits the Hub's existing shop anchor.
    - The coin and Static pickups are the only ones backed by real items.
    - The rest are parked.

## The group pages

Each page lists its decisions, the four statuses, what engineering remains
afterwards, the asset paths, and what was found tonight.

| Group | Page | Sheets |
|---|---|---|
| A · Controls and machinery feedback (028, 043, 049) | [A_controls.md](A_controls.md) | A1, A2 |
| B · Manipulation objects (043, 053) | [B_manipulation.md](B_manipulation.md) | B1, B2 |
| C · 0.4 machinery and room kits (045–048) | [C_machinery.md](C_machinery.md) | C1, C2 |
| D · Status, jobs and combat feedback (050–052, 043) | [D_feedback.md](D_feedback.md) | D1–D5 |
| E · Source-game packs (054–061, T01/T05 textures) | [E_packs.md](E_packs.md) | E1–E3 |
| R · The ordinary-room library (015–019, 044) | [R_rooms.md](R_rooms.md) | R0–R3 |
| Everything else, held work, corrections | [APPENDIX.md](APPENDIX.md) | `evidence/appendix/` |

The loose images are in `sheets/`, plus `evidence/`, split by group:
- `E/`: tonight's fixed-light pack frames;
- `A/`: the re-rendered connect views;
- `D/`: the to-scale plan;
- `rooms/`: eye views and plans;
- `prod_c12a72f/`: Production's own frames;
- `appendix/`.

## Found tonight, and not repaired

I measured about twenty art defects, each with the smallest repair listed
on its group page. The ones that matter most before any binding:
- the bulwark face sits on the enemy's **back**;
- the skiff's fore and aft lamps are **swapped**;
- the three ground marks are **undersized**;
- the 049 moving parts have **no pivots**;
- the Unweighted kit no longer fits the **repaired room**;
- the lightened panels use the **grip material**.

## For Prod, later

**Accepted pieces will come as a separate owner message.** He shouldn't wait
for this package to integrate work that is already approved. Every group
page has an **Assets** section with repository paths. The handoffs are in
`docs/art-requests/`; the ones from 22 September onward are on the art
branch only.

**Rebuild tonight's sheets from source:**

    python3 tools/owner_review_2026_09_28/build_{A,B,C,D,E,R}.py
