# ART REVIEW — the owner's ledger

**Every entry below is `PENDING`. Only the owner turns `PENDING` into
`PASS`.** The art lane may mark an objective failure; it may never mark an
aesthetic success, and it may not pick a winner among concepts.

| Status | Means |
| --- | --- |
| `PENDING` | Built, measured, evidence rendered. Awaiting the owner. |
| `PASS` | The owner has approved it. Only the owner writes this. |
| `REVISE` | Owner wants changes; the note says what. |
| `REJECT` | Not this. Kept in the repo until the owner says otherwise. |

**Where the images are:** [`docs/art/review/batch001/`](review/batch001/)

Commit: see `git log` on `claude/archipepsi-art`. Every asset rebuilds
byte-identical from its source; `tools/check_art_current.sh` passes.

---

## How to read a sheet

Eight shots, identical for every asset. Judge in this order and stop at the
first failure:

1. **silhouette** — flat black on a light field. Can you name it? If not,
   nothing else matters.
2. **clay** — untextured. Paint hides form.
3. **front / 34 / side / rear** — the front is the one view that lies,
   because the front is what everything gets tuned in.
4. **scale 1.8m** — beside a rod the height of the player, banded every
   0.5 m.
5. **play Nm** — the game's 90° lens at the game's 1.6 m eye height, at the
   distance this object is genuinely first seen from, with the **measured**
   screen height printed on it.

---

## A · Epsilon presence — 3 concepts, judged at 6 m

Sheets: `A_epsilon_a_lectern.png` · `A_epsilon_b_core.png` ·
`A_epsilon_c_aperture.png`

All three share the `identity` purple, one dominant aperture, and a height
inside `hub.gd`'s existing 2.0 × 3.0 × 0.8 m terminal envelope. What differs
is only the silhouette.

| ID | Tris | Size (m) | Measured @ 6 m | Concept | Status | Owner note |
| --- | --- | --- | --- | --- | --- | --- |
| `epsilon_a_lectern` | 140 | 1.18 × 0.86 × 2.62 | 244 px | Something you stand AT. Raked console under a tall slab, aperture at eye line. Most furniture-like, least strange. | PENDING | |
| `epsilon_b_core` | 136 | 1.25 × 0.98 × 2.55 | 237 px | Something hanging in a cradle. **A void in the middle** — the only silhouette in the kit with a hole in it, so identifiable in black at any size. | PENDING | |
| `epsilon_c_aperture` | 188 | 1.34 × 0.50 × 2.77 | 249 px | Part of the building. A heavy recessed slot with one lit band. Least clutter in the Hub; **risk: easy to walk past, and the Hub needs Epsilon findable.** | PENDING | |

**Open question for the owner:** whether Epsilon is furniture, an
installation, or architecture. That is the whole of what these three ask.

---

## B · Check object — 3 concepts, judged at 30 m

Sheets: `B_check_a_pedestal.png` · `B_check_b_vault.png` ·
`B_check_c_mast.png`
Also in context: `I_room_check_a_pedestal.png` and siblings — same room,
same camera, each concept in the same spot.

All three carry the same shell paint, the same `signal` interaction face and
the same `send` destination ring, so the review asks one question, not two.
All three fit `reward.gd`'s 1.4 × 2.6 × 1.4 m collision box.

| ID | Tris | Size (m) | @ 30 m | Concept | Status | Owner note |
| --- | --- | --- | --- | --- | --- | --- |
| `check_a_pedestal` | 248 | 1.22 × 1.22 × 2.23 | 39 px | Narrow waist under a wide head. Vertical emphasis nothing in the architecture kit makes. | PENDING | |
| `check_b_vault` | 232 | 1.38 × 1.37 × 2.16 | 41 px | Mass and a hole. Interaction face set INTO the object, so the shadowed recess reads before the lit face does. | PENDING | |
| `check_c_mast` | 268 | 1.11 × 1.14 × 2.22 | 41 px | Asymmetry and a diagonal. Nothing else in the room leans. Most legible at distance, least obviously approachable. | PENDING | |

Derived prediction was 47 px for a full-height 2.6 m object; these are
2.16–2.23 m, which scales to 39–40. **Bench and arithmetic agree.**

---

## C · Portal frame — 2 concepts, judged at 30 m

Sheets: `C_portal_a_blast.png` · `C_portal_b_collar.png`

| ID | Tris | Size (m) | @ 30 m | Concept | Status | Owner note |
| --- | --- | --- | --- | --- | --- | --- |
| `portal_a_blast` | 252 | 3.54 × 1.02 × 4.60 | 82 px | The exit is EQUIPMENT. Rams, lintel, hazard trim. Most legible at distance; says "installed here", which suits the authored/generated seam. | PENDING | |
| `portal_b_collar` | 308 | 3.50 × 1.25 × 4.36 | 80 px | The exit is a WOUND IN THE ARCHITECTURE. Ragged stepped jambs, machined collar over them. Less legible as equipment, more as a boundary; far more at home in `temple_ruin`. | PENDING | |

Both are under 3.6 m wide, which is the binding constraint: a wider portal
clips the wall of the narrowest corridor `zone.py` permits (4.0 m).

---

## D · Melee enemy — 3 concepts, judged at 18 m (`ENEMY_AGGRO_RADIUS`)

Sheets: `D_enemy_melee_a_stooped.png` · `D_enemy_melee_b_tripod.png` ·
`D_enemy_melee_c_squat.png`

**Forty-eight pixels is the design problem.** Every shot is at aggro range,
not a portrait distance.

| ID | Tris | Size (m) | @ 18 m | Silhouette bet | Family | Status | Owner note |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `enemy_melee_a_stooped` | 448 | 0.77 × 0.57 × 1.57 | 46 px | Forward commitment — the whole mass is ahead of the feet | nearly a machine | PENDING | |
| `enemy_melee_b_tripod` | 240 | 0.69 × 0.58 × 1.58 | 46 px | Terminal weight — almost nothing, then one very heavy arm | between | PENDING | |
| `enemy_melee_c_squat` | 396 | 0.79 × 0.71 × 1.29 | 41 px | A low wide stance — the FOOTPRINT reads, not the height | nearly a creature | PENDING | |

**Second question these ask, and it is the bigger one:** `ART_BIBLE.md` §4b
proposes a third geometry family — FABRICATED ORGANIC, built like machinery
that was told to be a creature — and does not settle it. A is nearly a
machine, C is nearly a creature, B sits between.

**Known and deliberate:** `enemy_melee_c_squat` is 1.29 m against a 1.6 m
collision box. The squat proportion is the concept; the consequence is that
shots at head height pass visually above it while still registering on
collision. Flagged rather than silently corrected, because correcting it
means abandoning the concept.

---

## E · Grapple anchor — 2 concepts, judged at 5 m

Sheets: `E_anchor_a_soffit.png` · `E_anchor_b_jib.png`

Mechanical dimensions are **entirely Godot's** —
`affordance_features.gd` sets footprint 1.4 × 1.4 m, clearance 5.6 m,
`CEILING_GAP` 0.5 m, `OUT_OF_JUMP_REACH` 2.1 m. Both anchor `ceiling`, so
the plate is at Z 0 and the ring hangs below it.

| ID | Tris | Size (m) | @ 5 m | Concept | Status | Owner note |
| --- | --- | --- | --- | --- | --- | --- |
| `anchor_a_soffit` | 160 | 1.10 × 1.10 × 1.00 | 111 px | Bolted plate flat to the ceiling, ring on a short shackle. Reads from directly underneath — where you are when you use it — and as part of the building, so six of them do not read as six pieces of equipment. **Risk: flat to the ceiling, may have no silhouette at distance.** | PENDING | |
| `anchor_b_jib` | 168 | 1.15 × 0.60 × 1.02 | 111 px | Braced arm projecting sideways, eye at the tip. Breaks the ceiling line, so reads across the room too. **Risk: an off-centre eye is harder to aim at.** | PENDING | |

---

## F · Common architecture mini-kit — judged at 4 m

Sheets: `F_arch_*.png`. Eight modules, enough to assemble one convincing
small late-90s room — which is what section I does.

| ID | Tris | Size (m) | Anchor | Status | Owner note |
| --- | --- | --- | --- | --- | --- |
| `arch_wall_panel` | 12 | 4.00 × 0.40 × 4.00 | floor | PENDING | |
| `arch_floor_slab` | 12 | 4.00 × 4.00 × 0.40 | floor | PENDING | |
| `arch_ceiling_beam` | 40 | 4.00 × 4.00 × 0.70 | ceiling | PENDING | |
| `arch_doorway` | 96 | 4.00 × 0.55 × 4.00 | floor | PENDING | |
| `arch_trim_rail` | 20 | 4.00 × 0.12 × 0.48 | floor | PENDING | |
| `arch_railing` | 96 | 4.00 × 0.11 × 1.05 | floor | PENDING | |
| `arch_pipe_run` | 172 | 4.00 × 0.40 × 0.62 | module_floor | PENDING | |
| `arch_light_fixture` | 144 | 1.50 × 0.39 × 0.26 | ceiling | PENDING | |

Every module measures exactly 4.00 m on its long axis and every one runs at
exactly 32.0 texels/m, so one module is one 128px texture tile and a wall of
them tiles without a seam.

---

## G · Universal prop mini-kit — judged at 3 m

Sheets: `G_prop_*.png`. All within `PROP_FOOTPRINT` (1.4 m), all at
64 texels/m.

| ID | Tris | Size (m) | Anchor | Status | Owner note |
| --- | --- | --- | --- | --- | --- |
| `prop_crate` | 72 | 1.04 × 1.04 × 1.01 | floor | PENDING | |
| `prop_utility_box` | 76 | 0.52 × 0.33 × 1.01 | floor | PENDING | |
| `prop_terminal` | 68 | 0.86 × 0.62 × 1.41 | floor | PENDING | |
| `prop_pipe_cluster` | 284 | 0.77 × 0.52 × 2.20 | floor | PENDING | |
| `prop_machinery_unit` | 180 | 1.30 × 0.99 × 1.90 | floor | PENDING | |
| `prop_debris` | 96 | 1.23 × 1.24 × 0.58 | floor | PENDING | |
| `prop_warning_sign` | 48 | 0.65 × 0.17 × 0.44 | wall | PENDING | |

The crate is **exactly** `MAX_VERTICAL_STEP` (1.0 m), so it is the largest
thing the player can step onto without jumping — a crate the level designer
can use.

**Worth the owner's attention:** props are painted from the theme's
**accent**, and `concrete_facility`'s accent is `#4f6f8f`, a steel blue
(engine truth — `THEME_MATERIALS`). So the whole prop kit reads blue in this
theme. That is a faithful consequence of the engine's palette, not an art
choice, but it is the most likely thing to feel wrong on sight.

---

## H · Texture and material style probes

Sheets: `H_material_concrete_facility.png` ·
`H_material_rusted_industrial.png` · `H_material_void_glitch.png`

Four roles per theme — wall, floor, trim, accent — at 128px covering exactly
4.0 m (32 texels/m). **Shown at 4× nearest-neighbour zoom**, labelled as
such: the sheet is for judging the *paint*; the in-engine shots are where
the density gets judged.

| Theme | Structure | Status | Owner note |
| --- | --- | --- | --- |
| `concrete_facility` | poured panels, courses at 1.2 m, vertical joints at 2.0 m, form ties at 0.5 m, water weeping from the ties | PENDING | |
| `rusted_industrial` | corrugation at 0.22 m, lapped sheets, chequer plate, oxide bleeding down from each fixing | PENDING | |
| `void_glitch` | the missing-texture checker at a real editor's 0.5 m cell — **carrying the same courses, joints and fixing pitch as every other theme**, plus scanline tearing | PENDING | |

**The commonality test:** `void_glitch` is the case that proves the six
themes are one game rather than six asset packs. If it reads as *this game's
broken room* rather than as a different game's texture, the split between
`paintkit` (shared grammar) and `materials` (per-theme structure) is right.

**Three themes only, deliberately.** `neon_transit`, `gothic_stone` and
`temple_ruin` are inventoried and not built: six is theme production and
theme production is behind this gate.

---

## I · Composed room — the shot that matters most

| Image | What it is | Status |
| --- | --- | --- |
| `I_room_wide.png` | 12 × 12 × 4 m room from the doorway. Game's 90° lens, 1.6 m eye height. | PENDING |
| `I_room_near.png` | The same room from inside it, at working distance. | PENDING |
| `I_room_greyscale.png` | The wide shot desaturated. **The quickest honest test of a palette there is.** | PENDING |
| `I_room_check_a_pedestal.png` | Same room, same camera, Check concept A. | PENDING |
| `I_room_check_b_vault.png` | …concept B. | PENDING |
| `I_room_check_c_mast.png` | …concept C. | PENDING |

**Authored triangles in the room: 2,888 against a 12,000 budget.** Built
from Batch 001 pieces only: 9 floor slabs, 12 wall modules, a doorway, 9
ceiling bays, kick rail throughout, 3 pipe runs, a railed platform with
crates as the way up, 2 light fixtures, and one dressing cluster per side.

**Honest observations, so the owner does not have to find them:**

- The room is **bright and clinical.** `concrete_facility` is a light theme
  by engine truth — base `#b9bcb6` at L\* 0.76, light energy 3.0 — so this is
  faithful rather than blown, but it is the thing most likely to read as
  wrong. `rusted_industrial` and `void_glitch` will land very differently
  and neither has a room shot yet.
- **Floor and wall are one ramp step apart** (ΔL\* ≈ 0.17, above the 0.10
  floor but not by much). In the greyscale test they separate — the trim
  rail and the slab joints do that work — but the two large surfaces are
  close.
- The greyscale test **passes**: props, trim, doorway and fixtures all
  separate from the walls with colour removed.
- The doorway opens onto nothing, because a kit shot has no next room. That
  is the shot's limit, not the module's.

---

## Objective state — verified, not claimed

| Check | Result |
| --- | --- |
| `python3 tools/blender/engine_truth.py` | PASS — every engineering number the art lane reads is live |
| `python3 tools/blender/palette.py` | PASS — anchors live, ramps separated, every signalling colour readable in every theme |
| `tools/sabotage_checks.sh` | PASS — 16/16 guards fire on their own bug |
| `tools/check_art_current.sh` | PASS — every asset rebuilds byte-identical from source |
| Triangle budgets | 28/28 assets under their category ceiling |
| Texel density | 28/28 within their tier band, measured off the real unwrap |
| Mechanical fit | 28/28 inside the collider the engine already has |
| Composed room | 2,888 / 12,000 triangles |

**None of this is an argument that the art is good.** It proves technical
validity, which is the floor, not the bar.

---

## What the owner is being asked

1. **Is this the right visual language for Archipepsi?** If not, say so now —
   the toolchain is cheap to redirect and fifty assets are not.
2. **A, B or C for Epsilon** — furniture, installation, or architecture?
3. **A, B or C for the Check?**
4. **A or B for the portal?**
5. **A, B or C for the melee enemy** — and with it, which geometry family
   enemies belong to?
6. **A or B for the grapple anchor?**
7. **Do the architecture and prop kits hold together as a place** (section
   I), or do they read as a showroom?
8. **Do the three material probes read as one game?**

A "REVISE" with one sentence about what is wrong is more useful than a
"PASS" — and **if it looks wrong, it is wrong.** No amount of implementation
effort behind a render is an argument for it.
