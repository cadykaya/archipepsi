# Enemy readability — decisions, in the order you set

*Arty*

**RULED 2026-09-25. The decisions are recorded inline below.**

The sheet was written under *"Do not silently apply the four proposed
enemy art changes. Package them as a compact owner review set."* It is
kept as the record of what was asked and what came back.

Silhouette numbers regenerate with `tools/content/run_enemy_silhouettes.sh`
+ `tools/content/enemy_readability.py`. Value numbers regenerate with
`tools/content/run_enemy_contrast.sh` (today) and
`tools/content/run_enemy_value_sweep.sh` (the sweep and the candidate).

---

## Tier 1, re-measured — READ THIS FIRST

> **RULED 2026-09-25 (on the section "measured in all six families"
> below):** *"Use the smallest practical set of theme-dependent VALUE
> BANDS ... dark-wall band for `void_glitch` ... around or below 0.15;
> middle band for `rusted_industrial`, around or below 0.20; normal band
> for `gothic_stone`, `concrete_facility`, `temple_ruin`, and
> `neon_transit`, around or below 0.27. Those are measured target
> ceilings, not source constants to copy blindly ... validate the
> candidate bands not only against the six wall lineups but also against
> representative floor backgrounds and deliberately dim room lighting."*

**Nothing has landed, and this goes back to you — because the numbers
that ruling stands on were wrong, and I made both errors.**

### What was wrong: the instrument, twice

1. **Wrong light.** The old harness lit all six rooms with
   `concrete_facility`'s lamp, rendered through the review bench's
   filmic tonemapper with no fog, and never created an environment, so
   its ambient settings did nothing. The game uses each room's own lamp,
   ambient 0.35 in the room's light colour, fog at 0.012 in the room's
   void colour, and Godot's default (linear) tonemapper.
2. **Wrong L\*.** It computed L\* by summing the viewport's
   sRGB-*encoded* channels as if they were linear light. That reads
   `#777777` as **0.740** instead of 0.500, lifts near-black to about
   0.29, and compresses every separation in the range the enemies live
   in.

So every *value* number in this folder before today is on a wrong
scale: Track B's **0.067**, the per-role list under it, the six-wall
table further down, the ≤ 0.152 / ≥ 0.681 gap, and therefore the three
ceilings you ruled on. The *silhouette* numbers (overlap, pixel sizes,
the brute's 6.7 cm overflow) do not use L\* and regenerate
byte-identical; they stand.

**Corrected, like for like:** in `concrete_facility` at 18 m the family
sits **0.131** L\* from the wall, not 0.067 — `diver` 0.099 weakest and
`artillery` 0.146 strongest, the same two ends as before; `beacon` moves
from ninth to fourth.

The instrument now checks itself before it measures anything: three
unshaded grey cards go through the same viewport and must read back at
their CIE L\* (computed offline, not by the harness) within 0.01, or the
run stops. With the old conversion put back, it refuses — it reads
0.552 / 0.740 / 0.882 for 0.249 / 0.500 / 0.752. The runner also refuses
if Production's fog, ambient, background, void colour, theme lights or
tonemapper stop matching what the harness copies.

### The corrected picture

Separation = background L\* − body L\*: **positive means the body is
the darker**. ✓ clears the palette's 0.10 value rule, ✓✓ its 0.18
interactable rule, ✗ neither. Four cases per room, each room under its
own light and fog, at 18 m:

* **wall** — level view, the room's own wall behind the row;
* **floor** — from 45° above, the row against the room's own floor;
* **dim** — the wall view with lamp and ambient at 35%;
* **opening** — *new*: the wall view with no wall, the row against what
  an exit, a drop or a window shows — the room's fogged void. Added
  because it is the one backdrop that can be darker than a dark enemy,
  which is exactly your *"disappear into ... shadows"*.

Today's skin (`contrast_current/`):

| room | wall | floor | dim | opening |
| --- | --- | --- | --- | --- |
| `concrete_facility` | +0.131 ✓ *(bg 0.355)* | +0.066 ✗ *(bg 0.292)* | +0.099 ✗ *(bg 0.232)* | -0.044 ✗ *(bg 0.180)* |
| `rusted_industrial` | +0.023 ✗ *(bg 0.216)* | +0.001 ✗ *(bg 0.195)* | +0.031 ✗ *(bg 0.144)* | -0.022 ✗ *(bg 0.171)* |
| `neon_transit` | +0.140 ✓ *(bg 0.354)* | +0.016 ✗ *(bg 0.231)* | +0.104 ✓ *(bg 0.225)* | -0.071 ✗ *(bg 0.143)* |
| `gothic_stone` | +0.075 ✗ *(bg 0.235)* | +0.065 ✗ *(bg 0.226)* | +0.060 ✗ *(bg 0.149)* | -0.012 ✗ *(bg 0.148)* |
| `temple_ruin` | +0.145 ✓ *(bg 0.375)* | +0.139 ✓ *(bg 0.370)* | +0.108 ✓ *(bg 0.260)* | +0.029 ✗ *(bg 0.259)* |
| `void_glitch` | +0.059 ✗ *(bg 0.370)* | -0.002 ✗ *(bg 0.311)* | +0.074 ✗ *(bg 0.315)* | +0.125 ✓ *(bg 0.436)* |

Three things follow.

**The rooms are much darker than the wrong scale said** — walls
0.216–0.375, floors 0.195–0.370, dim 0.144–0.315.

**On walls, floors and in dim light the body is below its background
in every room, so darker is better in all three.** There is no floor
or shadow trade-off in those cases: a darker body separates more from
floors and in dim light too, measured, not assumed. The weak cells
today are `rusted_industrial` (the room is dark and low-contrast: 0.001
on its floor) and `void_glitch` (its bright cyan fog lifts the body
onto its own floor).

**Openings are different.** In four rooms the fogged void (0.143–0.180)
is *darker* than the walls, and today's body sits just above it.
Darkening the body passes **through** the void's value on the way down:
at a mid-dark band the enemy vanishes against an opening (`neon_transit`
at k 0.55: 0.009; `concrete_facility` at k 0.70: 0.010). Your concern,
measured — in a case you did not name.

**And fog sets a hard floor.** At 18 m the fog replaces about a fifth of
whatever the body is with fog colour, so even a pure-black, fully matte
body renders at the fog's own value:

| room | fog floor L* | wall | floor | dim | opening |
| --- | --- | --- | --- | --- | --- |
| `concrete_facility` | 0.043 | +0.312 ✓✓ | +0.249 ✓✓ | +0.189 ✓✓ | +0.137 ✓ |
| `rusted_industrial` | 0.040 | +0.176 ✓ | +0.155 ✓ | +0.104 ✓ | +0.131 ✓ |
| `neon_transit` | 0.031 | +0.323 ✓✓ | +0.200 ✓✓ | +0.194 ✓✓ | +0.112 ✓ |
| `gothic_stone` | 0.032 | +0.203 ✓✓ | +0.194 ✓✓ | +0.117 ✓ | +0.116 ✓ |
| `temple_ruin` | 0.082 | +0.293 ✓✓ | +0.288 ✓✓ | +0.178 ✓ | +0.177 ✓ |
| `void_glitch` | 0.188 | +0.182 ✓✓ | +0.123 ✓ | +0.127 ✓ | +0.248 ✓✓ |


### What value can do — the sweep

`tools/content/run_enemy_value_sweep.sh` builds the ten enemies at seven
body lightnesses — the ramp's L\* scaled by k with a\* and b\* held, so
hue and chroma survive; the markings untouched; geometry untouched — and
measures each in all 24 cells. `CHART_separation_by_lightness.png` is
the whole result in one picture; `value_bands/derivation.txt` is the
arithmetic.

* **Lightest step clearing 0.10 on wall + floor + dim:**
  `temple_ruin` k 1.00 (today's skin already does), `concrete_facility`
  k 0.70, `neon_transit` k 0.40, `gothic_stone` k 0.40.
  `rusted_industrial` and `void_glitch`: **no paint step** — only the
  black-matte limit clears them.
* **0.18 on wall + floor + dim: no step, in no room.** Even pure black
  matte misses 0.18 in every `rusted_industrial` case (0.176 / 0.155 /
  0.104), in dim light in `gothic_stone` and `temple_ruin`, and on
  `void_glitch`'s floor and in its dim light.

### The candidate: TWO bands — not landed

| band | k | rooms |
| --- | --- | --- |
| standard | 0.40 | `concrete_facility`, `neon_transit`, `gothic_stone`, `temple_ruin` |
| deep | 0.10 | `rusted_industrial`, `void_glitch` |

Measured as one run (`value_bands/candidate_two_bands/`):

| room | band | wall | floor | dim | opening |
| --- | --- | --- | --- | --- | --- |
| `concrete_facility` | k0.40 | +0.233 ✓✓ | +0.171 ✓ | +0.157 ✓ | +0.058 ✗ |
| `rusted_industrial` | k0.10 | +0.147 ✓ | +0.127 ✓ | +0.093 ✗ | +0.102 ✓ |
| `neon_transit` | k0.40 | +0.243 ✓✓ | +0.121 ✓ | +0.163 ✓ | +0.032 ✗ |
| `gothic_stone` | k0.40 | +0.156 ✓ | +0.148 ✓ | +0.100 ✓ | +0.069 ✗ |
| `temple_ruin` | k0.40 | +0.233 ✓✓ | +0.228 ✓✓ | +0.153 ✓ | +0.117 ✓ |
| `void_glitch` | k0.10 | +0.158 ✓ | +0.100 ✗ | +0.118 ✓ | +0.224 ✓✓ |

* **Walls, floors, dim light: clears 0.10 in all six rooms but two
  cells** — `rusted_industrial` dim 0.093, which no paint clears (black
  matte: 0.104), and `void_glitch` floor at 0.0999, on the threshold
  with its fog floor at 0.123.
* **Clears 0.18 on the wall** in three rooms (was: none).
* **Openings:** clears 0.10 in `rusted_industrial`, `temple_ruin`,
  `void_glitch`; **short in three** — `concrete_facility` 0.058,
  `neon_transit` 0.032, `gothic_stone` 0.069. Today those three are
  short too, on the other side (the body slightly *lighter* than the
  void); the band trades a small lighter-than-void gap for a small
  darker-than-void one, and `neon_transit`'s gets smaller (0.071 → 0.032).

**Why two and not three.** Three bands would leave `temple_ruin` on
today's skin — it already clears walls, floors and dim — but its opening
would stay at 0.029; in the standard band its opening clears (0.117).
The script picks the grouping that darkens least in total and breaks
ties on the worst opening; for three bands that is `temple_ruin` k 1.00
plus the two above. One band (all six at k 0.10) scores at least as
high in every cell and costs identity in all six rooms.

**Identity.** Bands scale the body ramp's L\* only: same silhouettes,
same shared ramp, hue and chroma held where the gamut allows, markings
unchanged, no per-room palette, no `signal`. The cost is real at the
deep band: at k 0.10 the body is near-black and its hue survives mostly
in the plating lines. Measured with the default-theme skin in all six
rooms; per-room skins differ only in those plating lines and bolts
(the room's darkest base step), and would be re-measured at landing.

### Decisions needed

1. **The threshold.** 0.18 across walls, floors and dim light is out
   of reach of paint in every room, and pure black matte misses it in
   seven of the eighteen cells.
   *Recommend:* the palette's own 0.10 value rule is the enemy standard;
   0.18 is reported where it is met.
2. **The bands.** *Recommend:* the two above. Alternatives, all
   measured: three (`temple_ruin` unchanged — worse openings); one
   (everything deep — better numbers, identity gone everywhere).
3. **Openings.** Value cannot clear them in `concrete_facility`,
   `neon_transit` and `gothic_stone` without going to pure black, matte,
   markings included — the only treatment that clears 0.10 in all 24
   cells, and it is a silhouette with no identity left. Options:
   (a) accept openings as a known limit of a value-only fix;
   (b) a value-independent tell — 1C — which needs a colour you have not
   assigned (`signal` is closed);
   (c) the void and fog colours, which are Production's.
   *Recommend:* (a) now, and (b) as a study after the motion review,
   since movement may carry the read against a void on its own.
4. **The two cells short even with the bands** (`rusted_industrial`
   dim, `void_glitch` floor): accept, or send `rusted_industrial`'s room
   lighting to Production as the root cause.

> **RULED 2026-09-26.**
>
> 1. *"Approve 0.10 as the practical enemy-vs-environment art acceptance
>    threshold at 18 m."* 0.18 stays a strong/aspirational reference,
>    not a hard enemy-paint gate.
> 2. *"Approve the measured two-band candidate"* — standard 40% for
>    `concrete_facility`, `neon_transit`, `gothic_stone`, `temple_ruin`;
>    deep 10% for `rusted_industrial`, `void_glitch`. *"Keep the shared
>    enemy hue/material identity and semantic markings; this is a value
>    treatment, not six unrelated palettes. ... Do not claim it is active
>    in the shipping game until Production actually loads the art-lane
>    enemy models."* And flag to Production that its shipping builders
>    violate L-08 on their own.
> 3. Openings: *"a documented Tier-1 limitation for now."* No global
>    void-colour change, no new semantic enemy colour. Land Tier 1,
>    complete Tier 2, run the motion review; only then, with integrated
>    evidence, a non-value cue proposal if one is still needed.
> 4. Both short cells accepted as explicit measured exceptions; a still-
>    unreadable `rusted_industrial` in the integrated build is Production's
>    room-lighting/runtime issue.
>
> **LANDED 2026-09-26.** Both sets ship: `assets/models/batch030/enemies/`
> (standard) and `.../enemies_deep/` (deep), byte-identical to the
> candidate measured above. The map is generated data,
> `assets/models/batch030/enemy_value_bands.json`.
> `tools/content/check_enemy_bands.py` holds the ruling in the suite:
> - same geometry and markings in both sets;
> - the deep set darker;
> - `contrast_current/` tied by sha256 to the shipped files and meeting
>   0.10 everywhere but the two accepted cells.
>
> Production's flag: `docs/art-requests/2026-09-26-enemy-value-bands-and-L08.md`.

### What landing would change — and what it would not

Landing would rebuild the ten enemies per room (`ART_THEME` and the
band's `ENEMY_LIGHTNESS`), re-measure per-room skins, and deliver the
band map as data (`value_bands.json` → `partitions["2"]["by_theme"]`).

**It would not change what the game shows today.** Production's
shipping enemies are built in code (`enemy.gd`, `_build_melee` /
`_ranged` / `_flyer` / `_brute`) and painted with
`ThemeMaterials.accent_mat` / `trim_mat` — the room's own accent and
trim, which is exactly what L-08 forbids — and nothing in Production
loads the art lane's `enemy_role_*` models (verified at Production's
head, `d82a36e`). The bands take effect when the models are integrated,
not before.

---

## Tier 1 — family-wide value separation

> **SUPERSEDED — wrong light and wrong L\* scale; see "Tier 1,
> re-measured" above.** Kept as the record of what you ruled on.

**The problem, measured.** At 18 m in a lit room the family sits
**0.067 L\*** from the wall behind it. The palette asks for 0.10
between any two values and **0.18** for anything interactable. The
family fails both. Per role, distance from the wall:

```
diver 0.014  drifter 0.034  charger 0.041  bulwark 0.049  brute 0.067
melee 0.072  ranged 0.080  scuttler 0.088  beacon 0.097  artillery 0.111
```

`diver` is, in value terms, the wall. Only `artillery` clears even the
ordinary rule, and nothing clears the interactable one.

**This outranks every outline fix below**, because it affects all ten at
once and no silhouette work moves it.

### 1A — lift the family's value *(recommended)*

Raise the enemy body ramp until the family clears 0.18 against a
mid-value wall. Touches only enemy materials.

* **Changes:** every enemy's albedo. Ten models rebuild.
* **Does not change:** geometry, colliders, envelopes, anchors, or any
  number the game runs on.
* **Risk:** enemies get lighter than the walls in a *pale* theme, which
  trades one collision for another. Wants checking in all six families
  rather than just `concrete_facility`.

### 1B — darken the walls instead

Move the theme wall ramps down instead of the enemies up.

* **Changes:** the look of every room in the game.
* **Risk:** high. It is a palette-level decision with consequences far
  outside this track, and it would put every approved theme back in
  review. I would not start here.

### 1C — give enemies a value-independent tell

A rim, an emissive seam, or a contact shadow — something that does not
rely on body value at all.

* **Changes:** enemy materials, and possibly a shader Production owns.
* **Note:** `signal` is the only colour an interactable may be, and per
  your ruling stays reserved for that meaning. A rim in `signal` would
  say *"you can use this"* about something that wants to hurt you, so
  this option needs its own colour decision before it can be costed.

> **RULED: 1A**, with a condition — *"Develop a raised enemy-body value
> ramp, but do not land it from the concrete-room result alone. Render
> and measure the candidate against all six theme families first and
> make sure it does not simply move the collision into a pale
> environment."*
>
> **And a standing prohibition:** *"Do not use `signal` as an enemy
> rim/readability colour."* That closes 1C's colour question in the
> only direction it could have gone — `signal` means "you can use
> this", and an enemy is not that.

### Tier 1, measured in all six families — and the condition bites

> **SUPERSEDED — every number in this section is on the wrong scale;
> see "Tier 1, re-measured" above.** Kept because the band ruling was
> made on it.

The six-theme measurement was the condition on landing 1A. It came back
with a result that decides the direction rather than confirming it, so
**nothing has been changed and this goes back to you.**

| theme | wall L\* | separation from the body at 0.420 |
| --- | --- | --- |
| `void_glitch` | 0.332 | 0.088 — the body is **above** this wall |
| `rusted_industrial` | 0.384 | 0.036 — **above** this one too |
| `gothic_stone` | 0.451 | 0.031 |
| `concrete_facility` | 0.488 | 0.068 |
| `temple_ruin` | 0.495 | 0.075 |
| `neon_transit` | 0.501 | 0.081 |

Two things fall out of that table.

**First, a premise in the code was false.** `propkit.enemy_skin`'s
docstring claimed the skin *"sits below every theme's wall in value"*.
It sits above two of the six. Corrected in place, with the measurement.

**Second, the walls span 0.169 — less than twice the 0.18 threshold —
so no single body value between them can clear it anywhere.** One value
works only:

* **at or below L\* 0.152**, darker than every wall; or
* **at or above L\* 0.681**, paler than every wall.

The current 0.420 sits in the middle of that gap, which is the worst
place available. (Even the ordinary 0.10 rule needs ≤ 0.232 or ≥ 0.601.)

So *"raise the enemy-body value ramp"* has a specific cost: to work
everywhere it must go to **0.681**, which makes an enemy paler than
every wall in the game and the brightest thing in most rooms. That is
not only the pale-environment collision you asked me to watch for — it
also runs into the game's own language, where bright *is* light and
signal. I do not think that is what you meant by "raised", so I have
not built it.

**What I would do instead, and why.** Go the other way, to **≤ 0.152**.
It clears 0.18 in all six, it is monotonic (there is no theme where
darker is worse), and it is the direction `enemy_skin` was already
reaching for — *"something that came out of the building's underside"*.
The cost is that enemies become genuinely dark, which wants checking
against low-light areas rather than assumed.

**A third option the code is already shaped for.** `enemy_skin` takes
the theme, so the body value *could* differ per room — darker than
0.308 in `concrete_facility`, darker than 0.204 in `rusted_industrial`,
and so on. That is not "wearing the room's colours" (L-08's rule); it
is deliberately contrasting with them. The cost is cross-room
recognition: the same brute would not be the same value in two rooms.

> **Decision needed:** down to ≤ 0.152 / up to ≥ 0.681 / per-theme /
> relax the threshold for enemies →
>
> **RULED: per-theme value bands, as few as the evidence permits** —
> quoted in full at "Tier 1, re-measured" above, which is where it was
> carried out and where it came back.

The `LINEUP_<theme>_at_18m.png` frames this section cited were rendered
under the wrong light and have been removed; `contrast_current/` holds
their replacements.

---

## Tier 2 — the two genuinely confused pairs

Measured same-angle outline overlap, worst angle, scale-normalised:

| pair | overlap | where it fails |
| --- | --- | --- |
| `melee` / `ranged` | **0.856** | every angle; worst at 45° |
| `brute` / `bulwark` | **0.825** | head-on only — in profile the bulwark is unmistakable |

### 2A — give `ranged` a tell that is not width

Today `ranged` is a slightly narrower `melee`, and a different width is
not a different silhouette. A raised weapon arm, or a shoulder mount,
breaks the outline at 48 px where a narrower body does not.

* **Changes:** `ranged`'s geometry in `build_enemy_roles.py`.
* **Does not change:** its envelope, anchors or footprint — the tell
  goes inside the volume it already declares.
* **Why it matters:** one closes with you and one shoots you, and at
  the distance where you choose how to respond they are the same shape.

### 2B — give `bulwark` a head-on tell

Its shield is its whole identity and currently only exists in profile.
Head-on it is a brute at 82% overlap.

* **Changes:** `bulwark`'s geometry.
* **Options:** widen the shield plate past the body, notch its top
  edge, or set it forward so it reads as a separate plane.

> **RULED: both 2A and 2B**, *after* the Tier-1 candidate is settled,
> and *"keep these within their existing declared envelopes where
> possible."* **Directed 2026-09-26**, Tier 1 settled: *"ranged gets a
> non-width silhouette tell; bulwark gets a clear head-on shield tell;
> keep existing envelopes where practical."*

### Tier 2 — built and measured, for your review (2026-09-26)

**Not approved — yours to rule on.** Both re-cuts are in the art lane's
models, both bands. Nothing in Production loads those models, so this is
not active in the shipping game. The shapes before it are at `fa16cfe`.

**`ranged` — a braced gunner.** The emitter is now LONG and carried
DIAGONALLY across the body, from the back of one hip to past the opposite
shoulder, and its muzzle is the highest point on the figure. The legs
stand APART with daylight between them, where `melee` stands on one
block. Neither tell is a width.

**`bulwark` — a mantlet.** Head-on its outline is drawn as the brute's
NEGATIVE at both ends. Where the brute has its small head, the shield has
a sighting NOTCH between two ears at its top corners. Where the brute
stands on one block of legs, the shield stands on two RUNNERS at its own
edges, with floor showing between them. The body and legs behind are kept
out of both gaps. The face is still one uninterrupted plate, as 037-R
approved it.

Scaled outline overlap, the confusability measure, with the bar at 0.80,
before → after:

| pair | yaw 0 | yaw 45 | yaw 90 |
| --- | --- | --- | --- |
| `melee` / `ranged` | 0.788 → **0.496** | 0.856 → **0.605** | 0.825 → **0.563** |
| `brute` / `bulwark` | 0.825 → **0.677** | 0.710 → **0.701** | 0.523 → **0.553** |

Track B quoted each pair at its worst angle only. That hid that
`melee`/`ranged` also failed at 90° (0.825). It no longer fails at any
angle. `tier2/SHEET_tier2_before_after.png` shows both pairs laid over
each other on the metric's own canvas, so the tell is the coloured area.

* **The family:** 0 of 45 pairs at 0.80 or above. The highest is now
  `charger`/`drifter` at 0.776, which is 3A: deferred and untouched. Two
  pairs rose, and both stay clear of the bar: `artillery`/`bulwark` 0.637 →
  0.697 (yaw 45) and `beacon`/`ranged` 0.444 → 0.532 (yaw 90).
* **Held:**
  * Both envelopes. `ranged` is built 0.62 wide × 0.55 deep × 1.36 m
    high, inside 0.70 × 0.70 × 1.40. `bulwark` is 1.45 × 0.82 × 1.97
    inside 1.45 × 0.85 × 2.05.
  * The readiness gate: fit, facing, and every anchor inside a part.
  * No anchor pixel at any yaw.
* **Anchors moved with the shapes; their names did not change:**
  * `ranged` `anchor_muzzle`: 0.88 m → 1.29 m up, at the emitter's tip.
  * `ranged` `anchor_warn`: 1.27 → 1.22 m, with the lower head.
  * `bulwark` `anchor_warn`: 1.81 → 1.71 m, centred in the shield under
    the notch. Left at its old height it would have been in the notch's
    air, and the embed rule walked it sideways onto an ear.
* **Tier 1 re-measured on the re-cut:** no family cell moved more than
  0.001, and no pass/fail flipped. `check_enemy_bands` passes.
  `gothic_stone` dim now reads 0.100 (was 0.101) and still clears on the
  unrounded flag.

**Your call:** accept both re-cuts, either one, or neither. A rejected
re-cut goes back to its `fa16cfe` shape in the builder.

---

## Tier 3 — lower-priority polish

### 3A — `charger` / `drifter`

0.774 **raw** overlap — the highest of any pair before normalisation,
so they genuinely look alike as drawn. But they read apart once
normalised, which means the difference *is* size, and here size is
honest: they are different-sized things. Lowest priority; possibly
nothing to do.

### 3B — `brute`'s visible body vs its collider

0.067 m wider than its envelope head-on. Sent to Production as
`docs/art-requests/2026-09-25-brute-visible-body-vs-collider.md`. If
they rule that the visible body moves, it is a small change on my side.

> **RULED: 3A deferred.** 3B stays with Production — the 6.7 cm
> measurement is accepted as evidence, and which contract moves is
> theirs to decide.

---

## Motion review — 2026-09-26, for your review

> **Directed 2026-09-26:** *"Then perform the motion-readability
> review."* After this checkpoint the lane holds.

The art lane's enemies are rigid meshes. Every motion they will have is
a transform that Production gives them, so this review covers those
transforms. They are read from Production's own source at `27363fe` and
applied to the Tier-2 models (`tools/content/enemy_motion_review.py`).
The evidence is in `motion/`.

### 1. The turn — the outline at every yaw

`Enemy._face` snaps every role except the bulwark to face the player, and
a patrolling enemy faces the way it walks. So a player sees an enemy at
every yaw, not at three. This pass re-measures every pair at every 15°.
*Across yaws* sets role A at any yaw against role B at any other. That is
the stricter test, because a player seeing one enemy once is asking
exactly that.

| pair | Track B's 3 yaws | full turn, worst | across yaws, worst |
| --- | --- | --- | --- |
| `melee` / `ranged` | 0.605 | 0.669 (150°) | 0.785 |
| `brute` / `bulwark` | 0.701 | 0.734 (120°) | 0.766 |
| `diver` / `scuttler` | 0.718 | 0.767 (30°) | 0.794 |
| `charger` / `drifter` | 0.776 | **0.803** (15°) | **0.828** |
| `charger` / `diver` | 0.618 | 0.670 (150°) | **0.847** |

* **Tier 2 holds through the turn.** Neither re-cut pair reaches the bar
  at any yaw, whether measured at the same yaw or across yaws.
* **Three results reach the bar, and each is a floor role against a
  flyer.** The `charger` stands 0–1.05 m tall. The `diver` hovers at
  1.65–2.15 m and the `drifter` at 2.07–3.03 m. The outline metric crops
  every silhouette to itself, so it cannot see that, at rest on one
  floor, these never share a row of the frame. `charger`/`drifter` is 3A,
  which you deferred. `charger`/`diver` is new but the same kind of
  result. Nothing is proposed for either.

### 2. What moves — Production's motion already separates both Tier-2 pairs

| role | speed | stops at | turn | windup | job |
| --- | --- | --- | --- | --- | --- |
| `melee` | 4.0 m/s | 1.6 m | snaps | — | patrol |
| `ranged` | **0** | — | snaps | aim 0.45 s | watch |
| `brute` | 2.2 m/s | 2.0 m | snaps | slam 0.50 s | watch |
| `bulwark` | 1.6 m/s | 1.9 m | **90°/s, none while committed** | — | watch |
| `charger` | 3.0 m/s | 11.2 m, then rushes | snaps | charge 0.70 s | patrol |
| `artillery` | **0** | — | snaps | shell 0.80 s | watch |
| `beacon` | 1.2 m/s | 1.6 m | snaps | — | tend |
| `scuttler` | 6.5 m/s | 1.4 m | snaps | — | patrol |
| `diver` | 7.0 m/s, hovers 1.9 m | 5.5 m, then dives | snaps | dive 0.35 s | drift |
| `drifter` | 2.4 m/s, hovers 2.55 m | 17.6 m | snaps | aim 0.45 s | drift |

* **`melee` / `ranged`:** motion separates this pair more than any outline
  could. The `melee` closes at 4 m/s. The `ranged` has speed 0 and never
  walks; it plants and aims. One comes at you and the other never moves.
* **`brute` / `bulwark`:** motion separates this pair only weakly. Both
  close slowly. The bulwark's lagging turn shows only when the player
  moves round it. The brute swells before it hits, and the bulwark gives
  no windup.
* **The other close outline pairs** are separated by movement or by height:
  * the `artillery` never moves, while the `bulwark` and `brute` walk;
  * the `charger` stops at 11 m and rushes, while the `drifter` hangs
    2.55 m up and holds off near 18 m;
  * the `diver` flies and dives, while the `scuttler` runs on the floor.

**All ten roles are placeable at `27363fe`,** because `ENEMY_ARCHETYPES`
lists all ten there. The art lane's own frames still print "not
spawnable", because they read the art branch's older copy of the
constants. So requirement 31 reads as resolved in Production. This is
recorded only; nothing was changed.

### 3. The windup and the flinch — on the art models, at 18 m

Production's fallback telegraph scales `Visual` by 1 + 0.12 sin(…) over
the windup: one full swell and shrink. A hit punches the scale to 0.88,
and it springs back over 0.1 s. `SHEET_telegraph_swell.png` shows the
effect on the art models at the review distance:

| role | windup | top of the outline moves | pixels changed at the peak |
| --- | --- | --- | --- |
| `brute` | 0.50 s | 8.9 px | 947 |
| `artillery` | 0.80 s | 5.5 px | 325 |
| `ranged` | 0.45 s | 4.9 px | 171 |
| `charger` | 0.70 s | 3.1 px | 173 |
| `drifter` | 0.45 s | 1.4 px, about its middle | 189 |
| `diver` | 0.35 s | 0.7 px, about its middle | 61 |

For the two flyers and the charger, the swell moves the outline by 3 px
or less.

**The eye — a decision is needed.** Today's code-built enemies carry an
emissive `Eye` in hard-coded red and orange, and it is the only emissive
part of their bodies. Production drives it in three states:
* dim while the enemy is idle;
* brighter once it has noticed you;
* **flaring at every windup** (`_begin_telegraph` → `EYE_FLARE`, 2.6×).

The art models have no eye, and one built into the model would not work
as things stand. `_set_eye` only reaches a `material_override`, and a
glTF import does not set one. This is the same gap as the damage-tint
blocker (A10 §1). So integrating the art models as they stand would
remove the flare, which is the one windup cue made of light rather than
shape, and would leave only the swell. It would also remove the only
emissive thing on today's enemies, which matters for the openings below.

An eye needs a colour, and you ruled out a new semantic enemy colour for
now, so nothing is built. As the art lane sees it, the options are:
* **Production keeps its eye.** It builds today's `Eye` onto the art
  model at integration, in today's colours, so the art lane adds no
  colour. Where the eye seats is Production's call. The art models have
  no eye anchor yet; adding one would be a small art change, made on your
  word.
* **The art lane authors an eye** in a colour you approve. Production
  would reach it through an override.
* **Drop the eye,** and rely on the swell and on sound.

### 4. The openings — motion cannot add value

When a body moves, each pixel it enters or leaves changes by exactly
body-minus-background, which is the static separation. Motion adds no
value contrast; it only changes how fast pixels change.

The case that matters is also the slowest: an enemy walking straight at
you. From 18 m its outline grows by at most 0.17 px per frame (the
`melee` at 60 fps). Crossing your view at the same speed, it would move
2 px per frame. So the three rooms that fall below 0.10 at an opening
stay below it in motion:
* `neon_transit`: 0.033
* `concrete_facility`: 0.059
* `gothic_stone`: 0.070

Per your ruling, the documented limitation stands and no cue is
proposed. Two things matter for the integrated check you asked for:
* Test an approach through an opening in `neon_transit` first. It is the
  weakest cell.
* Test it with the art models. Today's build carries the emissive eye,
  and the art models would not.

### What this review cannot see

* **No player, and no integrated build.** Production does not load the
  art models. This is those models under Production's motion rules,
  reconstructed from its source.
* **Outlines, not light.** The swell and flinch are drawn from outlines,
  not rendered, and 60 fps is assumed.
* **The eye is read from code.** It is taken from Production's source,
  not rendered.
* **One distance, and no pitch.**

**Your call:** the eye, above. Everything else in this section is
information. The checkpoint is reached, and the lane holds.

---

## What none of this measures

**Motion.** All of the above is ten static poses at three yaws. A pair
that shares an outline may be unmistakable the moment it moves. That is
a reason for the next pass to be animated, not a reason to leave it —
but it does mean Tier 2 could be smaller than it looks, and Tier 1
could not.

> **Reviewed 2026-09-26** as far as the art lane can reach, which is the
> transforms Production gives rigid models. See "Motion review" above.
