# Track B — the ten-role family, measured at the distance it is read

*Arty*

**Branch `claude/archipepsi-art`, PR #5.** Measurement only. No enemy
was changed.

Track B was given a failure to fix:

> artillery is currently a wider version of another robot. A different
> width is not a different silhouette.

I built the measurement before touching anything, and **the named
failure does not reproduce**. Two other pairs fail the same test, one of
them for exactly the reason PT-10 gives, and a third finding turned out
to matter more than any of them.

---

## 1. The test, and whose numbers it uses

Everything is read out of `assets/art_budgets.json` rather than chosen:

```
enemy_review_distance_m  18.0   the aggro radius
camera_fov_deg           90
enemy_aggro_px_1080p     48.0   the melee role's height at that distance
```

Forty-eight pixels. That is the entire budget, so the harness renders at
native size and measures there — rendering large and trusting it would
have survived shrinking is how a studio silhouette row at 500 px proves
a design that nobody plays at.

The camera is checked against the budget rather than assumed: melee
measures **46 px** against a derived 48. Every other role is then
compared to **its own** declared envelope.

Two passes per role, at yaws 0 / 45 / 90. A **silhouette** pass — flat
black, unlit, transparent — which is the measurement, with hue and
material taken away so they cannot do the work shape is supposed to do.
And a **lit** pass in a room under one lamp at the theme's own colour
and energy, no rig, which is the evidence.

---

## 2. Artillery is fine; melee and ranged are not

Pairwise intersection-over-union, same yaw, worst (most similar) angle:

| Pair | scaled | raw | |
| --- | --- | --- | --- |
| melee / ranged | **0.856** | 0.692 | two small humanoids |
| brute / bulwark | **0.825** | 0.667 | two broad blocks, head-on |
| charger / drifter | 0.776 | **0.774** | highest raw overlap of any pair |
| artillery / brute | 0.682 | 0.416 | artillery's nearest neighbour |

**melee / ranged is PT-10's complaint, on a different pair.** Ranged is
a slightly narrower melee. One closes with you and one shoots you, and
at the distance where you have to decide which, they are the same
shape.

**brute / bulwark** fails head-on and only head-on: in profile the
bulwark is a slab and unmistakable. Head-on is where you meet it.

Artillery, meanwhile, is one of the more distinctive outlines in the
family — a braced base under an elevated barrel. Whatever prompted the
note, it is not visible in the outline at 18 m.

---

## 3. The finding that outranks all of that

The silhouette test is the kindest test a shape will ever get: black on
nothing. In the room, against the wall they stand in front of:

```
the family reads at L* 0.453, the wall at L* 0.618 -- 0.165 apart
  min_value_separation        0.10   clears
  min_interactable_separation 0.18   SHORT by 0.015
```

The family clears the ordinary value rule and falls short of the
**interactable** one, and an enemy is the most interactable thing in a
room. It is a near miss rather than a catastrophe — but it is on the
wrong side of the right rule, it affects all ten at once, and no amount
of outline work on two pairs will move it.

Reported, not refused. This measures art already in the tree against a
threshold the palette sets for a related question, and turning it into a
gate would be this lane quietly imposing a rule nobody agreed to.

---

## 4. One envelope overflow

`brute`'s visible body is **0.067 m wider** than its declared envelope
head-on: a part you can see, outside the volume that can be hit. That is
the PT-12 seam. The damage volume is Production's; aligning the visible
body is mine, and it is small — but it is a change to art already in the
tree, so the measurement goes to the owner rather than the change going
in.

Nothing else overflows, and the first version of this check said six did.
It compared the widest of three yaws against the envelope's **width**,
and an axis-aligned box at 45° presents its diagonal: `sqrt(w²+d²)` is
wider than `w` for every body that is not a cylinder. Comparing a
diagonal against a side finds an overflow in anything with corners. The
bound is per yaw now.

---

## 5. A metric that lied, and what fixed it

The first analyser normalised every outline into a common square and
reported **seven** pairs as "the same shape; only the size tells them
apart" — including `bulwark / diver` at 0.888. A flat disc is not the
same shape as a tall box. Squashed into one square almost any two solid
outlines overlap, and the label on that column was making a claim the
number could not support.

It only stretch-compares pairs whose aspect ratios are within 2× now,
and says how many pairs it refused to compare and why. Seven findings
became two, and the two agree with my own eye on
`SHEET_silhouettes.png`, which is the check I wanted on the metric.

---

## 6. What this cannot see, said before anyone asks

* **Motion.** PT-10 asks for shape *and motion*; these are ten static
  poses. A pair that shares an outline may be unmistakable the moment it
  moves — which is a reason for the next pass to be animated, not a
  reason to leave it.
* **Three yaws, no pitch.**
* **One theme** — the room is `concrete_facility`, and the contrast
  number would move elsewhere.
* **No player, nothing else happening**, which is the only condition
  that actually matters.

---

## 7. What I would do next, and am not doing unasked

1. **Give `ranged` a silhouette tell that is not width** — a raised
   weapon arm reads at 48 px where a narrower body does not.
2. **Give `bulwark` a head-on tell** — its shield is its whole identity
   and currently only exists in profile.
3. **Lift the family's value** until it clears 0.18 against a mid wall,
   or darken the wall. That is a palette-level decision and it is the
   owner's, not mine.
4. **Then re-measure**, with motion.

All four are changes to art already in the tree. The measurement is the
deliverable; the changes want a ruling first.
