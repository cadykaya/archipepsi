# Enemy readability — decisions, in the order you set

*Arty*

**Nothing in this file has been applied.** Owner ruling, 2026-09-25:
*"Do not silently apply the four proposed enemy art changes. Package
them as a compact owner review set."* The priority order below is yours,
not mine.

Every number comes from `README.md` in this folder and regenerates with
`tools/content/run_enemy_silhouettes.sh` +
`tools/content/enemy_readability.py`.

---

## Tier 1 — family-wide value separation

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

> **Decision:** 1A / 1B / 1C / not now →

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

> **Decision:** 2A and 2B / one of them / neither →

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

> **Decision:** 3A / 3B / defer both →

---

## What none of this measures

**Motion.** All of the above is ten static poses at three yaws. A pair
that shares an outline may be unmistakable the moment it moves. That is
a reason for the next pass to be animated, not a reason to leave it —
but it does mean Tier 2 could be smaller than it looks, and Tier 1
could not.
