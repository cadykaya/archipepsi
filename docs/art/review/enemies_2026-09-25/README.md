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
| `LINEUP_at_18m.png` | All ten at review distance, in a room, under **one** lamp at the theme's own colour and energy. No rig. |
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

The silhouette test is the kindest test a shape will ever get — black on
nothing. In the room, against the wall they stand in front of:

```
the family reads at L* 0.453, the wall at L* 0.618 -- 0.165 apart
  min_value_separation        0.10   clears
  min_interactable_separation 0.18   SHORT
```

The family clears the ordinary value rule and **falls 0.015 short of the
interactable one** — and an enemy is the most interactable thing in the
room. It is a near miss, not a catastrophe, but it is on the wrong side
of the right rule, and it affects all ten at once. Outline work on two
pairs will not touch it.

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
* **One theme.** The lineup room is `concrete_facility`. The contrast
  number would move in `void_glitch` or `rusted_industrial`.
* **No player.** Nothing here tests reading an enemy while something
  else is happening, which is the only condition that actually matters.
