# Enemy readability — decisions, in the order you set

*Arty*

**RULED 2026-09-25. The decisions are recorded inline below.**

The sheet was written under *"Do not silently apply the four proposed
enemy art changes. Package them as a compact owner review set."* It is
kept as the record of what was asked and what came back.

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

Reproduce with `tools/content/run_enemy_silhouettes.sh` (six
`LINEUP_<theme>_at_18m.png` frames) then
`tools/content/enemy_value_bands.py`.

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
> possible."* Not started: Tier 1 comes first by the owner's ordering.

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

## What none of this measures

**Motion.** All of the above is ten static poses at three yaws. A pair
that shares an outline may be unmistakable the moment it moves. That is
a reason for the next pass to be animated, not a reason to leave it —
but it does mean Tier 2 could be smaller than it looks, and Tier 1
could not.
