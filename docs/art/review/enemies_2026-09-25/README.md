# The ten-role family at 18 m

*Arty*

**PROPOSAL / MEASUREMENT. Nothing here is owner-approved, and nothing
here changes an enemy.**

`02` PT-10 asks for the lineup judged **without audio, captions,
collider overlays or studio lighting**, distinguishing shape rather than
width or hue. Every number below is the project's own:

| | |
| --- | --- |
| `enemy_review_distance_m` | **18.0 m** — the aggro radius. The distance at which an enemy notices you is the distance at which you must be able to name it. |
| `camera_fov_deg` | **90** |
| `enemy_aggro_px_1080p` | **48 px** — derived from the melee role's height at that distance. Melee measures 46 px here, which is how the camera was checked. |

| File | What it is |
| --- | --- |
| `contrast_current/` | **The landed Tier-1 treatment** (RULED 2026-09-26): all ten at review distance in all six rooms, each room's enemies in their own value band, four cases each (wall, floor, dim, opening), under each room's own light, ambient and fog — `CONTRAST_<room>_<case>.png` and `contrast.json`, which records the sha256 of every model it measured. Replaces the `LINEUP_*` frames, which were lit wrongly and are gone. The pre-band family is `value_bands/sweep/k1.00.json`. |
| `value_bands/` | Tier 1: the lightness sweep, the derived bands, the two-band candidate measured, `CHART_separation_by_lightness.png` and `SHEET_today_vs_two_bands.png`. A candidate; nothing landed. |
| `SHEET_silhouettes.png` | Every outline, black on white, at native size. Rows are roles; columns are yaw 0 / 45 / 90. |
| `MASK_<role>_y<yaw>.png` | The outlines themselves, native size — the measurement's input. |
| `silhouettes.json` | Per-role pixel size, fill, aspect, and the visible body against its declared envelope. |
| `readability.json` | Every pair, three ways. |

## The headline: the named failure does not reproduce

> "artillery is currently a wider version of another robot. A different
> width is not a different silhouette."

At this distance, by outline, **it is not**. Artillery's closest
neighbour is brute at 0.682, well under the 0.80 line, and it reads as
what it is — a broad braced base with an elevated barrel. Look at the
first row of `SHEET_silhouettes.png`.

**Two other pairs do fail that test**, and one of them is exactly the
failure PT-10 describes, applied to a different pair:

| Pair | Same outline | Raw | Why it matters |
| --- | --- | --- | --- |
| **melee / ranged** | **0.856** (yaw 45) | 0.692 | Two small humanoids. Ranged is a slightly narrower melee. One closes with you and one shoots you, and at 18 m you cannot tell which. |
| **brute / bulwark** | **0.825** (yaw 0) | 0.667 | Two broad blocks head-on. Bulwark is a slab and reads as one in profile — but not from the front, which is where you meet it. |

`charger / drifter` is worth a look too: at 0.774 raw it has the highest
overlap of any pair *before* any normalisation.

## The bigger finding is value, not outline

> **RE-MEASURED 2026-09-25.** The value numbers this section first
> carried (0.420 against 0.488, **0.067** apart, and a per-role list
> from `diver` 0.014 to `artillery` 0.111) came from a harness that lit
> the room with the wrong lamp, through the wrong tonemapper, with no
> fog, and computed L\* from sRGB-encoded pixels as if they were linear.
> They are withdrawn. The numbers below are from `contrast_current/`,
> which calibrates its L\* against known greys before it measures.

The silhouette test is the kindest test a shape will ever get — black on
nothing. In `concrete_facility`, under its own light and fog, against
the wall they stand in front of:

```
the family reads at L* 0.224, the wall at L* 0.355 -- 0.131 apart
  min_value_separation        0.10   clears
  min_interactable_separation 0.18   SHORT
```

Per role, worst first:

| role | body L\* | from the wall | clears 0.10 | clears 0.18 |
| --- | --- | --- | --- | --- |
| `diver` | 0.256 | **0.099** | no | no |
| `drifter` | 0.254 | 0.101 | yes | no |
| `charger` | 0.240 | 0.115 | yes | no |
| `beacon` | 0.232 | 0.123 | yes | no |
| `bulwark` | 0.227 | 0.128 | yes | no |
| `brute` | 0.220 | 0.135 | yes | no |
| `melee` | 0.218 | 0.137 | yes | no |
| `ranged` | 0.217 | 0.138 | yes | no |
| `scuttler` | 0.215 | 0.140 | yes | no |
| `artillery` | 0.209 | **0.146** | yes | no |

**Value is still the bigger finding — but because of the other rooms,
not this one.** On `concrete_facility`'s wall the family clears the
ordinary rule. On floors, in dim light and in the other five rooms it
does not: the weakest role sits **0.001** from the background on
`rusted_industrial`'s wall and floor, on `neon_transit`'s floor and on
`void_glitch`'s floor. That affects all ten at once, and no outline work
on two pairs will move it. The full 24-cell picture, and what a value
band can and cannot do about it, is Tier 1 in `DECISIONS_FOR_OWNER.md`.

> **Correction.** An earlier version of this README reported the family
> separation as 0.165 and said it cleared the value rule. That number
> came from a broken occupancy mask which counted three quarters of the
> frame as "enemy", so the wall was being sampled from the wrong
> pixels. The figures above are measured per role with one render each
> and were checked a second time by an independent script reading the
> PNGs. The harness now refuses any region covering more than 10% of
> the frame.

## One envelope overflow, reported not fixed

`brute`'s visible body is **0.067 m wider** than its declared envelope
at yaw 0 — a part you can see, outside the volume that can be hit. The
damage volume is Production's. Aligning the visible body instead is my
side of that seam and is a small change, but it is a change to art that
is already in the tree, so I am reporting the measurement rather than
making it.

Nothing else overflows. The check compares against the **yaw-appropriate
bound** — `w` head-on, `d` in profile, `sqrt(w²+d²)` at 45° — because an
axis-aligned box seen at 45° presents its diagonal, and comparing a
diagonal against a side finds an "overflow" in any object with corners.
Getting that wrong reported six.

## What this measurement cannot see

* **Motion.** PT-10 asks for shape *and motion*; this is ten static
  poses. A pair that shares an outline may still be unmistakable the
  moment it moves, and that is not an argument for leaving it — it is a
  reason the next pass should be animated.
* **Three angles only**, and no pitch.
* **One theme for the silhouettes.** Outlines do not depend on the
  room. Value does, and is now measured in all six rooms and four cases
  (`contrast_current/`).
* **One distance.** Everything is at 18 m. Nearer, the fog lifts a body
  less and every value separation grows.
* **No player.** Nothing here tests reading an enemy while something
  else is happening, which is the only condition that actually matters.
