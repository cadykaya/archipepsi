# Tier 1 re-measured, and the rest of Track A

*Arty*

**Branch `claude/archipepsi-art`, PR #5.** Two deliveries. Tier 1 comes
back to you **without landing**, because the numbers you ruled on were
wrong, and I made both errors. Track A's remainder is authored and
gated, as candidates.

In this archive, `review/` is `docs/art/review/enemies_2026-09-25/` and
`interface/` is `docs/art/review/interface_2026-09-24/`.

---

## 1. The instrument was wrong, twice

The band ceilings you ruled on (~0.15 / ~0.20 / ~0.27) came from the
enemy-value harness, and it was wrong in two independent ways.

* **Wrong light.** It lit all six rooms with `concrete_facility`'s lamp,
  through the review bench's filmic tonemapper, with no fog, and never
  created an environment, so its ambient did nothing. The game uses each
  room's own lamp, ambient 0.35 in the room's light, fog at 0.012 in the
  room's void colour, and Godot's default (linear) tonemapper.
* **Wrong L\*.** It summed the viewport image's **sRGB-encoded**
  channels as if they were linear light. `#777777` is L\* 0.500 by
  definition, and it read as **0.740**. Near-black read as about 0.29.
  Every separation in the dark range the enemies live in came out
  compressed. The error is monotonic, so on its own it never changed
  which role ranked where, and a plausible ranking is exactly what made
  a wrong scale look trustworthy.

**What it invalidates:** every enemy *value* number before today. That
covers Track B's **0.067**, the per-role list, the six-wall table, the
≤ 0.152 / ≥ 0.681 gap, and so the three ceilings. **What it does not
touch:** the silhouette numbers (overlap, pixel sizes, the brute's
6.7 cm overflow). They don't use L\*, and they regenerate byte-identical.

**Like for like, corrected:** in `concrete_facility` at 18 m the family
sits **0.131** from the wall, not 0.067. `diver` is weakest at 0.099 and
`artillery` strongest at 0.146, the same two ends as before; `beacon`
moves from ninth to fourth under the game's own environment.

**How it was found.** No check caught it. A diagnostic painted every
enemy pure black and fully matte, which should leave only fog. The
harness said the black body was L\* 0.29, in a room whose fog colour
computes to about 0.18, and a mix of black and fog cannot be brighter
than the fog. The saved frame showed the body pixels were `(14, 15, 16)`.

**How it is guarded now.**
- Before every run, the harness renders three unshaded grey cards and
  refuses to measure unless they read back at their CIE L\* within 0.01.
  The reference values are computed offline, not by the harness.
- With the old conversion put back, it refuses: it reads 0.552 / 0.740 /
  0.882 for 0.249 / 0.500 / 0.752.
- The runner also refuses if any value it copies from Production drifts:
  the fog, ambient, background, void colour, the six theme lights and
  trims, or the tonemapper. That covers `zone_builder.gd`,
  `ThemeMaterials.void_color` and `THEME_MATERIALS`.
- The anchor check was itself sabotaged with a doctored palette, and
  caught both changes.

## 2. The corrected picture

Four cases per room, each under its own light and fog, at 18 m:

- **wall**
- **floor**, seen from 45° above
- **dim**, with lamp and ambient at 35%
- **opening**, which is new: the row against an exit, a drop or a window,
  i.e. the room's fogged void.

I added the opening case because it is the one backdrop that can be
*darker* than a dark enemy, which is your "disappear into shadows".

![Separation as the body darkens, per room](review/value_bands/CHART_separation_by_lightness.png)

**On walls, floors and in dim light, the body is below its background in
every room, so darker is better in all three.** That is measured. There
is no floor or shadow trade-off in those cases.

Today the weak spots are:

- `rusted_industrial` barely separates anywhere: 0.001 on its floor.
- `void_glitch`'s bright cyan fog lifts the body onto its own floor.

**Openings are where it bites.** In four rooms the fogged void (L\*
0.143–0.180) is darker than the walls, and today's body sits just
above it. Darkening passes **through** the void's value on the way down.
At a mid-dark band an enemy vanishes against an opening:
`neon_transit` at k 0.55 reads 0.009, and `concrete_facility` at
k 0.70 reads 0.010.

**Fog sets a hard floor.** At 18 m, fog replaces about a fifth of the
body's colour with fog colour. Even a pure-black, fully matte enemy
renders at the fog's own value, from **0.031** in `neon_transit` to
**0.188** in `void_glitch`. No paint goes below it.

## 3. The candidate: two bands — not landed

`run_enemy_value_sweep.sh` builds the ten enemies at seven body
lightnesses:
- the ramp's L\* is scaled by k, with a\* and b\* held, so hue and chroma
  survive;
- markings and geometry are untouched;
- the builds go to a gitignored scratch folder, never over the shipped
  models.

Each lightness is measured in all 24 cells. `enemy_value_bands.py` then
picks the fewest bands, darkening as little as possible in total, and
breaks ties on the worst opening.

| band | k | rooms |
| --- | --- | --- |
| standard | 0.40 | `concrete_facility`, `neon_transit`, `gothic_stone`, `temple_ruin` |
| deep | 0.10 | `rusted_industrial`, `void_glitch` |

Measured as one run. Separation is background minus body, so positive
means the body is darker. ✓ is the 0.10 value rule, ✓✓ the 0.18
interactable rule, ✗ neither.

| room | band | wall | floor | dim | opening |
| --- | --- | --- | --- | --- | --- |
| `concrete_facility` | k0.40 | +0.233 ✓✓ | +0.171 ✓ | +0.157 ✓ | +0.058 ✗ |
| `rusted_industrial` | k0.10 | +0.147 ✓ | +0.127 ✓ | +0.093 ✗ | +0.102 ✓ |
| `neon_transit` | k0.40 | +0.243 ✓✓ | +0.121 ✓ | +0.163 ✓ | +0.032 ✗ |
| `gothic_stone` | k0.40 | +0.156 ✓ | +0.148 ✓ | +0.100 ✓ | +0.069 ✗ |
| `temple_ruin` | k0.40 | +0.233 ✓✓ | +0.228 ✓✓ | +0.153 ✓ | +0.117 ✓ |
| `void_glitch` | k0.10 | +0.158 ✓ | +0.100 ✗ | +0.118 ✓ | +0.224 ✓✓ |

![Today against the two-band candidate, 24 cells](review/value_bands/SHEET_today_vs_two_bands.png)

**Walls, floors and dim light:** it clears 0.10 in all six rooms except
two cells.
- `rusted_industrial` dim reads 0.093. No paint clears it; pure black
  matte reaches 0.104.
- `void_glitch` floor reads 0.0999, right on the threshold.

It clears 0.18 on the wall in three rooms; today it clears 0.18 in none.

**0.18 across walls, floors and dim is out of reach of paint in every
room.** Pure black matte misses it in 7 of those 18 cells.

**Openings:** it clears in three rooms. It is short in `concrete_facility`
(0.058), `neon_transit` (0.032) and `gothic_stone` (0.069); those were
short today too, from the lighter side. The one treatment that clears
0.10 in all 24 cells is pure black, fully matte, markings included:

![An opening in neon_transit with the candidate: 0.032](review/value_bands/candidate_two_bands/CONTRAST_neon_transit_opening.png)

That is a silhouette with no identity left, so I have not proposed it.

**Why two, not three.** With three bands, `temple_ruin` would keep
today's skin, since it already clears walls, floors and dim, but its
opening would stay at 0.029. With two, it clears (0.117). One band, with
everything at k 0.10, scores at least as high in every cell and costs
identity in all six rooms.

**Identity.** Same silhouettes, same shared ramp, hue and chroma held
where the gamut allows, markings unchanged, no per-room palette, no
`signal`. At k 0.10 the body is near-black, and its hue survives mostly
in the plating lines. I measured the default-theme skin in all six
rooms. The per-room skins differ only in those plating lines and bolts,
and I would re-measure them at landing.

## 4. Decisions that are yours

1. **The threshold.** 0.18 across walls, floors and dim light cannot be
   reached with paint. *Recommend:* the palette's own 0.10 value rule as
   the enemy standard, with 0.18 reported where it is met.
2. **The bands.** *Recommend:* the two above. The alternatives are
   measured: three bands leaves `temple_ruin` unchanged with worse
   openings; one band makes everything deep and gives up identity
   everywhere.
3. **Openings.** Value alone can't clear three rooms without pure black.
   The options:
   - **(a)** accept openings as a known limit;
   - **(b)** a value-independent tell (1C), which needs a colour you have
     not assigned, since `signal` is closed;
   - **(c)** change the void or fog colour, which are Production's.

   *Recommend:* (a) now, and (b) as a study after the motion review,
   since movement may carry the read on its own.
4. **The two short cells.** Accept them, or send `rusted_industrial`'s
   room lighting to Production as the root cause.

## 5. What landing would change — and what it would not

Landing would:
- rebuild the ten enemies per room at their band;
- re-measure the per-room skins;
- deliver the band map as data (`review/value_bands/value_bands.json`,
  `partitions["2"]["by_theme"]`).

**It would not change what the game shows today.** Production's
shipping enemies are built in code (`enemy.gd`: `_build_melee`,
`_ranged`, `_flyer`, `_brute`) and painted in the room's own accent and
trim, which is exactly what L-08 forbids. Nothing in Production loads
the art lane's `enemy_role_*` models. I verified this at Production's
head, `d82a36e`.

## 6. Track A: keycaps, symbols, page arrows

![Keycaps, page arrows and the symbols, composed](interface/PROMPTS_keycaps_and_symbols.png)

- **Body text and headings.** This is `ui_text`, as accepted, with
  headings at its exact 2×.
- **Keycap.** It is `panel_keycap.png`, a fourth nine-slice:
  - 12×12, corners cut, with a two-pixel front lip, because a key is
    pressed *down*;
  - `dead` chrome, because the key is not the thing you operate;
  - **unequal insets** (left 2, top 2, right 1, bottom 3).

  The nine-slice gate now:
  - carries four margins;
  - has its own knowledge of where each ring sits, rather than reading
    positions from the contract it grades;
  - keeps transparency through the render.

  Its new sabotage draws the keycap with the lip treated as stretchable.
  The centre check catches it; the corner check alone could not,
  because nearest-neighbour stretching hands back the very lip row it
  expects.
- **Symbols and arrows.**
  - `circuit`, `control`, `exit` and `blocked`, plus one arrow; the other
    three arrows are that one mirrored or turned.
  - 12 px, one ink. The tint per state is *recorded* in `icons.json`,
    not painted in; the sheet's bottom row shows that intent.
  - `exit` and `blocked` share a frame on purpose, since they are one
    place in two states.
- **New gate, `run_ui_icons.sh`.** It checks:
  - lossless import;
  - one ink;
  - a clear 1 px margin;
  - the arrows, re-derived from the imported pixels with Godot's own
    flip and rotate;
  - that every tint name exists in the palette.

  A staged wrong down-arrow fails it (40 px differ), and doctored copies
  prove the shape check can fail.

Three findings from building it:
- **Four symbols ran to the cell edge.** The docstring promised a 1 px
  margin, and four of the eight first drawings broke it. I redrew them,
  and `author_icons.py` now reads every exported page back and refuses
  ink on the outer ring.
- **Tinting by modulate darkens colours.** The ink is the text face's
  off-white (`#e8eef6`), so modulating gives each colour family 3–9%
  darker per channel than the palette's value. This is for Production:
  tint by replacement, or ask for white ink.
- **The face harness applied the left inset to all four sides.** Fixed.
  The earlier face sheets re-render byte-identical.

## 7. Scope of the evidence, exactly

- **Distance and camera.** 18 m, FOV 90, 1920×1080.
- **Lighting.** Each room's own light, ambient and fog, as
  `zone_builder.gd` sets them at Production `d82a36e`.
- **Dim case.** Lamp and ambient at 35%. That fraction is my judgement.
- **Poses.** Static poses of the default-theme skin.
- **Metric.** The mean L\* of all ten bodies against the measured
  backdrop. A mean is conservative: the candidate's crops show plating
  detail still reading where the mean is short.
- **Not measured:**
  - other distances; nearer, fog lifts less and every separation grows;
  - motion;
  - per-room skins;
  - a player under pressure.

**Suite.** `tools/check_art_current.sh`, first run: every gate, the
interface rebuild, every Blender rebuild (byte-identical, the enemy
roles included) and the exported content passed, except ONE:
`statusready`. That was Production's own refactor at `d82a36e`, which
moved the "designed but unimplemented" guard into a member. The rule is
the same, so the gate is re-pinned as three required parts. It passes,
and it fails on both the pre-`d82a36e` source and the current source
with the refusal line removed. A clean rerun of the whole suite: *see
below.*

## 8. Next

- **Tier 1** waits on the four decisions above.
- **Tier 2** (2A, 2B) waits on Tier 1 being settled, then the motion
  review.
- **Track C** stays blocked on the revised machinery/puzzle bounds.
- **Track E** stays reserve.
- **Item and state art** still waits on Production's slot vocabulary.
- **Watchers, subscriptions and scheduled work** stay off.
