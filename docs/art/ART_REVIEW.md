# ART REVIEW — the owner's ledger

**Only the owner turns `PENDING` into `PASS`.** The art lane may mark an
objective failure; it may never mark an aesthetic success, and it may not
pick a winner among concepts.

| Status | Means |
| --- | --- |
| `PENDING` | Built, measured, evidence rendered. Awaiting the owner. |
| `PASS` | The owner has approved it. Only the owner writes this. |
| `REVISE` | Owner wants changes; the note says what. |
| `SELECTED` | Owner chose this concept as the direction; the asset itself is still `PENDING`. |
| `KEPT` | Not selected, not discarded. Preserved for later use. |

**Where the images are:** [`review/batch001/`](review/batch001/) · [`review/batch002/`](review/batch002/)

---

## Batch 001 — the owner's verdict, recorded

**Overall: STYLE LANGUAGE = PASS WITH REVISIONS. Do not begin mass
production. Do one Style Lock revision batch first.**

### The art direction this settled

> The facility and Epsilon are **two different civilisations**, and the
> contrast between them is what the game leans on.

| | |
| --- | --- |
| **Human / facility** | Abandoned research facility. Cold grey concrete, white and pale-blue painted walls, yellow utility lighting, corridors, vents, pipes, rails, catwalks. Old, human, institutional, mechanical. *Already working.* |
| **Epsilon** | Truly alien technology **embedded into** that old facility. Not another machine — an intrusion. Big-ass computer energy. **Neon green** dominant. Hostile, uncanny, glowing, humming, invasive. Not designed by the same civilisation as the building. |

> **Epsilon is not part of the building style. Epsilon is a foreign
> intelligence inhabiting, infecting and embedding itself into old
> infrastructure.**

Applied to: Epsilon's presence, the portal, Epsilon-owned devices, the glow
and light language, and any visual state showing Epsilon influence or
corruption. Recorded in `ART_BIBLE.md` §1a.

### Selections

| | Owner's decision | Status |
| --- | --- | --- |
| **Epsilon** | **B — suspended core.** An installation/presence, not furniture (A) or a wall console (C). Revise toward alien intrusion. | `SELECTED` |
| **Check** | **A — pedestal.** Decisively strongest at room distance; B disappears into architecture, C reads as another terminal. Revise lightly. | `SELECTED` |
| **Portal** | **B — collar**, as *direction*. Neither is final. | `SELECTED` |
| **Enemies** | **All three kept and reinterpreted as the three archetypes.** A→melee, B→ranged, C→brute. | `SELECTED` |
| **Anchor** | **A — soffit** primary. B kept as a possible wall/side-mounted variant. | `SELECTED` / `KEPT` |
| Epsilon A, C · Check B, C · Portal A | Not selected. Not deleted. | `KEPT` |

---

## Batch 001-R — the revision. Everything below is PENDING.

### A · Epsilon B — the intrusion

`A_epsilon_b_core.png`

| | |
| --- | --- |
| Asked for | Large alien computer, visibly embedded into facility infrastructure, more uncanny and invasive, neon green dominant, **less lamp/cone energy** in the core, slight asymmetry welcome, machine-shrine energy — without losing the distance silhouette. |
| Kept | The open frame with a void through it — the only silhouette in the kit with a hole in it. Still 249 px at 6 m. |
| Changed | **Three materials, and the split is the concept.** The bottom third is ordinary bolted facility grey; the alien mass bursts out of it and takes nothing from the theme at all. The core is now four hard-edged shards at unrelated angles, not a tapered prism. Arms are different lengths at different angles. Conduits leave the base into the floor. Green comes out of the *seams*, from inside. |
| Metrics | 284 tris · 1.40 × 1.28 × 2.63 m · 249 px at 6 m |
| Status | **PENDING** |

The palette change is repo-wide: `identity` moved from violet `#b45cff` to
neon green `#57ff1f`, leaning yellow deliberately so it can never be
confused with `void_glitch` cyan or `signal` teal. A hue-separation check now
enforces 45° between those three, and is sabotage-proved.

### B · Check A — signal mast

`B_check_a_pedestal.png` · in context: `I_room_check_a_pedestal.png`

| | |
| --- | --- |
| Asked for | Slightly more industrial / signal-device, slightly less magical-pedestal. Keep the beacon top and across-room readability. |
| Changed | The lathe-turned octagonal plinth and four radiating crown arms — the "magical" part — are gone. Bolted box base, a conduit running out into the floor, stay bars, and a caged emitter head. Same silhouette family, built by a contractor. |
| Metrics | 300 tris · 0.96 × 1.04 × 2.22 m · 41 px at 30 m |
| Status | **PENDING** |

### C · Portal B — the breach

`C_portal_b_collar.png`

| | |
| --- | --- |
| Asked for | Push toward *"something has happened to / opened through the architecture"* rather than *"special doorway frame"*. Inherit the facility-vs-Epsilon contrast. Keep a distinctive dead silhouette without relying on future VFX. |
| Changed | Three materials: cold facility jambs (now staggered left against right, with rubble at the foot — material came *out* of this wall), an irregular alien collar gripping the aperture with anchor spikes driven into the stone, and green only where the two meet. |
| Dead state | The ragged breach, the asymmetric collar and the spikes are all geometry. Every emissive surface can be off and the silhouette still reads. |
| Metrics | 412 tris · 3.50 × 1.26 × 4.36 m · 80 px at 30 m |
| Status | **PENDING** |

### D · The three archetypes

`D_enemy_lineup_18m.png` · `_silhouette.png` · `_clay.png` — **all three in
one frame at aggro range**, plus individual sheets.

Each is now built to **its own archetype's collision box**, which is what
changed the models rather than the labels:

| | Box (m) | Tris | At 18 m | The read |
| --- | --- | --- | --- | --- |
| `enemy_melee_stooped` | 0.8 × 1.6 × 0.8 | 460 | 46 px | Forward mass ahead of the feet, working arms, terminal weight in the fists |
| `enemy_ranged_tripod` | 0.7 × 1.4 × 0.7 | 368 | 41 px | Three planted legs, a mast, all mass in one asymmetric weapon housing. `speed 0.0` — it never closes, and the silhouette says so |
| `enemy_brute_squat` | 1.8 × 2.6 × 1.8 | 424 | 77 px | More than double the melee on every axis. Chest wider than tall and low, short thick legs, head sunk in |

**Shared family cues, deliberately few:** the same dark `grime` plating that
sits below every theme's wall in value, and **a green optic** — green is
Epsilon's colour, so a green eye says *this belongs to the thing in the
Hub*.

**Hazard orange is absent, and that is a rule.** Green says *whose this is*;
orange says *what is about to happen*. Reserving orange for telegraphs means
a windup is the only orange an enemy ever shows.

A new build guard refuses any enemy filling under 80 % of its collision
height — it caught the brute at 78 % on the first build.

Status: **PENDING** (all three)

### E · Anchor

`E_anchor_a_soffit.png` (primary) · `E_anchor_b_jib.png` (kept)

| | |
| --- | --- |
| `anchor_a_soffit` | Owner's primary. 160 tris · 111 px at 5 m. **PENDING** |
| `anchor_b_jib` | Kept as a candidate wall/side-mounted directional variant. Unchanged. **KEPT** |

### F · Architecture — revised for hierarchy

`F_arch_*.png`. One new module, one deepened.

| | |
| --- | --- |
| `arch_wall_ribbed` **(new)** | Four pilasters standing 0.22 m proud. The room read as *"every surface exposes the same exact 4 m panel rhythm"*; the answer is a second rhythm, not less structure — and it is geometry rather than paint, because a painted rib casts nothing. 108 tris. |
| `arch_ceiling_beam` | Downstand deepened 0.45 → 0.60 m so it throws a real shadow band. 3.4 m headroom remains. |
| Everything else | Unchanged. |

### G · Props — the accent problem

`G_prop_*.png`

Asked for: stop crates, machinery, pipes, rails and utility objects all
inheriting the theme accent; use accent selectively.

Every painted prop now declares a **tone** taken from the theme's *base*
ramp — the cold institutional greys the facility is actually built from —
and the accent survives only as a band on the minority that earn one. In
`concrete_facility` the kit is now a row of different greys with a teal
terminal screen and an orange warning sign among them, instead of eight blue
objects.

Status: **PENDING**

### H · Materials, and two in-engine probes

| | |
| --- | --- |
| `H_material_concrete_facility.png` | Now six roles. See the room notes below. **PENDING** |
| `H_probe_void_glitch_room.png` + `_greyscale` | **The probe you asked for.** **PENDING** |
| `H_probe_rusted_industrial_room.png` + `_greyscale` | Not requested — added because it costs one command and de-risks the next batch. **PENDING** |
| `H_material_rusted_industrial.png` | Unchanged, as instructed. **PENDING** |

Both probes are the *same room, same modules, same meshes* with only the
theme material swapped — which incidentally proves the runtime model the
asset registry will need: one authored mesh, six theme materials, selected
by Godot.

**My honest read on void_glitch:** the floor works — a dark checker with a
cyan editor grid reads as a missing world you can still fight on. The walls
and ceiling at full-saturation magenta are, to my eye, past usable for a
room you spend time in. If you want it kept, the cheapest fix is to drop the
magenta to the ramp's dark step on large surfaces and keep full saturation
for accents and the floor grid. Your call.

### I · The composed room

`I_room_wide.png` · `I_room_greyscale.png` · `I_room_near.png` ·
`I_room_warmlight_proposal.png` · `I_room_check_*.png`

Asked for: stronger separation between floor / walls / ceiling / trim, more
structural depth and local shadow, less uniform 4 m rhythm, accent
supporting hierarchy rather than turning everything blue — while preserving
the 1998 brush language and **not** solving it with modern detail or greeble.

**The value hierarchy was measurable, not a matter of taste.** Floor sat at
L\* 0.59, wall at 0.76, and the ceiling *borrowed the wall texture* — so the
three surfaces filling most of the frame spanned 0.17 between them. The
palette check passed the whole time, because 0.17 clears the 0.10 floor.

Now four separated values spanning 0.56:

| | L\* | |
| --- | --- | --- |
| trim | 0.20 | structural, darkest thing in the room |
| floor | 0.42 | walked on, dirtiest, no longer the mid value |
| ceiling | 0.59 | its own role, ribbed one way — never a wall lying down |
| wall | 0.76 | pale institutional paint, with a dark base course along the bottom 0.85 m |

Plus: alternating plain and ribbed wall bays, a deeper downstand, and the
kick rail's accent cut from a third of its cycle to a thin stripe.

**Two things I did not change, because they are not mine to change:**

- **Yellow utility lighting.** `THEME_MATERIALS` gives `concrete_facility`
  `light_color: #eaf2ff`, a cool white. That is engineering's anchor.
  `I_room_warmlight_proposal.png` is the same room relit warm and labelled
  as *not engine truth* — if you like it, it is a one-line ask to
  engineering, not an art change.
- **Shadows.** `chamber_builders._light` sets `shadow_enabled = false`. A
  bench that switched them on would be showing depth the game does not
  render. The added depth here comes from geometry that shades *itself*.

Room: 3,272 / 12,000 triangles.

Status: **PENDING**

---

## Objective state — verified, not claimed

| Check | Result |
| --- | --- |
| `engine_truth.py` | PASS |
| `palette.py` | PASS — including the new 45° hue separation between `signal`, `identity` and `glitch` |
| `check_docs_metrics.py` | PASS — every figure above matches the build |
| `sabotage_checks.sh` | PASS — every guard fires on its own bug |
| `check_art_current.sh` | PASS — byte-identical rebuilds |
| Budgets / density / mechanical fit | every asset |

**None of this is an argument that the art is good.**

---

## What I am asking for on 001-R

1. Does the revised room read as an **abandoned research facility** now?
2. Does Epsilon B read as an **alien intrusion** into it, or still as
   another machine?
3. Do the three archetypes read as **one ecosystem, three threats** at 18 m?
4. Is the neon green right, and is the green-optic / orange-telegraph split
   the right division?
5. void_glitch: usable as-is, or does the magenta need dropping on large
   surfaces?
6. The warm-light proposal: worth asking engineering for?

Statuses stay `PENDING` until you say otherwise, and there is no mass
production after this batch either — the gate holds until you lift it.

---

## Batch 002 — the second revision. Everything below is PENDING.

**Where the images are:** [`review/batch002/`](review/batch002/)

The 001-R verdict locked the facility, kept both anchors, approved Check A
and preserved the three enemy silhouettes, and asked for six things. Each is
answered below with what it is and what to look at.

### A · Epsilon — a room-scale computer installation

> a BIG OLD COMPUTER INSTALLATION with an ALIEN CORE / INTRUSION embedded in
> or erupting through it.

`epsilon_installation` — **1396 triangles, 8.80 × 2.61 × 3.55 m**, floor
anchored. Seven bays of abandoned facility mainframe on a 1.2 m module,
2.9 m tall, with two bays destroyed and an alien mass erupting through the
gap, past the cornice and out along the neighbouring cabinet fronts.

This **replaces the 1.4 × 1.4 × 2.8 m envelope** the 001 concepts were built
to. It is now the largest authored object in the project, `hub.gd` has no
contract for it, and that is an interface item, not an oversight.

What changed beyond scale:

* **The bank is dark.** It was painted from the theme's base ramp and
  rendered as the palest thing in frame. It comes from the trim and grime
  ramps now, and nothing on the human half is allowed above `trim[2]`.
* **Nothing on the human half glows.** Every monitor is dead glass in a
  geometric bezel. The intrusion is the only lit thing.
* **The veins step.** A straight emissive bar across a cabinet front read as
  a highlighter stroke; they run along seams and turn at them now.
* **The green is green again.** It was rendering as clipped yellow-white.
  See `ART_LESSONS.md` L-29 and L-30 — this was a real colour bug and it
  affected every emissive surface in the project.

Look at: `A_epsilon_installation.png` (wide, silhouette, clay, 1.8 m scale
rod, 8 m play distance), `_medium.png` at 4 m, `_close.png` at 2 m, and
`A_epsilon_in_room.png` / `_oblique.png` for it standing in a room.

Status: **PENDING**

### B · Facility lighting — cold room, local warm pools

> Do NOT turn the whole room warm. Warm yellow light should appear as
> localized utility pools / fixtures within a still-cold environment.

The ceiling lamps stay on the engine's own `#eaf2ff` at energy 3.0 and set
the room's temperature. The warmth arrives as three small wall fixtures at
2.1 m on a **2.6 m range** — short enough that the falloff lands inside the
room — running **dimmer** than the ceiling, so the hierarchy is not
inverted. `arch_utility_lamp`, **96 triangles, 0.34 × 0.44 × 0.28 m**,
wall anchored, with a `send`-amber lens: `hazard` orange is the telegraph,
`signal` teal is interactables and `identity` green is Epsilon, so none of
them may be spent on a lamp.

Look at: `I_room_utility_pools.png`, its greyscale, `I_room_utility_pool_near.png`,
and `I_room_warmlight_rejected.png` — the 001-R globally-warm version, kept
and labelled rather than deleted.

Status: **PENDING**

### C · Portal — the human/alien split pushed

`portal_b2_wound` — **512 triangles, 3.59 × 1.29 × 4.45 m**. B-R showed a
hole with jambs; this shows the **wall it was made in**: panels, a base
course, a bolted architrave and a concrete lintel. The alien mass is no
longer polite about it — lopsided, piled up on one side, across the lintel,
spilling onto the floor and occluding part of the opening.

The values are deliberately inverted against the installation: that is a
dark machine with a green intrusion, this is a **pale wall** with a dark
green-black one. The intrusion never matches; what it fails to match
changes.

B and B-R are both kept.

Look at: `C_portal_b2_wound.png`.

Status: **PENDING**

### D · The enemy family — seven proposed roles

> Do NOT copy official Doom / Doom II / Doom 64 / Half-Life 1 enemy designs
> directly. But DO study the ROLE COVERAGE and roster logic.

Every one of these starts from a sentence about what it does **to the
player**; the silhouette is derived from that sentence afterwards. Nothing
is drawn from a remembered picture.

| ID | Role | Tris | Size |
| --- | --- | --- | --- |
| `enemy_scuttler` | SCUTTLER — costs attention | 212 | 1.19 × 0.59 × 0.54 m |
| `enemy_charger` | CHARGER — one telegraphed rush | 176 | 0.86 × 1.62 × 1.03 m |
| `enemy_bulwark` | BULWARK — cannot be fought frontally | 280 | 1.45 × 0.83 × 1.92 m |
| `enemy_artillery` | ARTILLERY — indirect, denies ground | 144 | 0.63 × 0.75 × 1.52 m |
| `enemy_beacon` | BEACON — makes everything near it worse | 152 | 0.57 × 0.61 × 2.12 m |
| `enemy_drifter` | DRIFTER (flyer) — owns the ceiling | 208 | 1.25 × 1.24 × 0.84 m |
| `enemy_diver` | DIVER (flyer) — contests the grapple arc | 84 | 0.61 × 1.05 × 0.35 m |

The three approved archetypes are untouched. Ten roles is a lot to tell
apart in the 48 px a 1.6 m enemy occupies at `ENEMY_AGGRO_RADIUS`, so no two
share a governing shape: upright / tripod / squat-enormous / wide-and-low /
long-and-low / flat slab / tube-up / thin mast / horizontal disc / forward
dart. **Six of the ten do not meet the ground plane the same way**, which
does more for separation than any amount of surface detail.

**Their collision boxes are a PROPOSAL.** `enemy.gd` defines exactly three
sizes; everything past the trio has no engine counterpart, and every
manifest entry says `"engine_box": false`.

Look at: `D_enemy_family_18m.png` and `D_enemy_family_silhouette.png` — two
ranks of five, both at 18 m, true 1080p scale then 2×.

Status: **PENDING**

### E · Grapple anchors — what each one is FOR

Both kept, as instructed. A soffit is the ceiling case and is unchanged. B
was ceiling-anchored, which left "wall variant" existing only as a sentence,
so `anchor_b_wall_jib` — **168 triangles, 0.62 × 1.25 × 0.72 m**, wall
anchored — is the same arm turned onto a wall plate with the brace doing the
job it was always drawn for.

The difference is mechanical: a ceiling anchor is reached from below and
swings any direction; a wall jib puts the eye out from the wall at a chosen
height, so its swing has a **direction**. Its 2.6 m plate height is an art
proposal — `affordance_features.gd` has no wall-mounted anchor.

Look at: `E_anchor_a_use.png` and `E_anchor_b_use.png`. Both carry the 1.8 m
rod at the jump's 4.67 m flat reach and an orange bar at the 1.33 m jump
apex, because an anchor that does not beat a jump is decoration.

Status: **PENDING**

### F · The family board (optional item)

One row of facility objects and one row of Epsilon objects, on one floor,
under one light, from one camera — the only honest way to test a claim about
two visual languages. Then the same frame in greyscale, because a split that
exists only in hue will not survive a dark corridor.

Look at: `F_style_board.png` and `F_style_board_greyscale.png`.

Status: **PENDING**

---

## Objective state for 002 — verified, not claimed

| Check | Result |
| --- | --- |
| `engine_truth.py` | PASS — now also reading the engine's lighting energies |
| `palette.py` | PASS |
| `check_docs_metrics.py` | PASS — 40 of 40 built assets quoted and verified |
| `sabotage_checks.sh` | see the commit; every guard still fires on its own bug |
| `check_art_current.sh` | byte-identical rebuilds |
| Budgets / density / mechanical fit | every asset, including the seven proposals |

**None of this is an argument that the art is good.**

---

## What I am asking for on 002

1. Does the installation read as **a big old computer with something
   erupting through it**, or still as a sculpture?
2. Is the cold-room-with-warm-pools lighting the split you meant?
3. Is the portal's human/alien contrast far enough now?
4. Of the seven proposed roles: which are in, which are out, which need
   rethinking? Are the two flyers the flyers you wanted?
5. Is the wall jib worth keeping as a second anchor, or does A cover it?
6. Anything in the family board that does **not** belong to the language it
   is filed under?

No mass production. Statuses stay `PENDING` until you say otherwise.
