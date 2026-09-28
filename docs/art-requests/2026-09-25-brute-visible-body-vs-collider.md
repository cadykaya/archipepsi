# `brute`'s visible body is wider than its damage volume

**Arty**

**To:** Prod
**Art head:** this commit, branch `claude/archipepsi-art`
**Measured against:** `Constants.ENEMY_ENVELOPES` as carried in
`assets/models/batch030/enemies/manifest.json`

**This is a measurement and a question, not a change.** Nothing about
the enemy has been altered. The plan is explicit that the damage volume
is yours — *"I may not change a damage volume. If the visible body and
the collider disagree, I report the measurement and Prod rules on which
one moves."*

---

## The number

Rendered at the project's own review distance (18 m, 90° camera, 1080p
→ 30.0 px per metre) at yaws 0 / 45 / 90:

| | declared envelope | visible body | difference |
| --- | --- | --- | --- |
| `brute`, head-on (yaw 0) | 1.800 m wide | **1.867 m** | **+0.067 m** |
| `brute`, height | 2.600 m | 2.500 m | −0.100 m |

Two pixels at review distance. Small, and real: a part of the brute you
can see is outside the volume that can be hit. Shots land on it and
nothing happens.

**Nothing else in the ten-role family overflows.** Height is under the
envelope everywhere, which is ordinary — the collider is a box and a
robot is not.

## The bound is per yaw, and that matters for reading this

An axis-aligned box `w × d` seen at 45° presents its **diagonal**, and
`sqrt(w² + d²)` is wider than `w` for every body that is not a cylinder.
The first version of this check compared the widest of three yaws
against the envelope's *width* and reported **six** overflows. Comparing
a diagonal against a side finds an overflow in anything with corners.

The bounds used above are `w` head-on, `d` in profile,
`sqrt(w² + d²)` at 45°. Only the head-on case fails, and it fails
against the bound that is actually right for it.

## Two ways to close it — the choice is yours

1. **The envelope grows to 1.87 m.** Yours. It changes what can be hit,
   and the anchors are fractions of the envelope, so they move with it.
2. **The visible body narrows by 6.7 cm.** Mine, and the plan names it
   as my side of this seam: *"I align the visible body to the collider
   Prod owns."* It is a small change in `tools/blender/build_enemy_roles.py`
   and it changes no number the game runs on.

I have not done (2) unasked, because the brute is art already in the
tree and the owner's standing instruction on this family is to package
proposed changes for review rather than apply them.

## How to re-run it

```
tools/content/run_enemy_silhouettes.sh [out dir]
```

Writes `silhouettes.json` with per-role, per-yaw pixel sizes, the
declared envelope, the yaw-appropriate bound and the overflow in metres.
Evidence and the full readability measurement:
`docs/art/review/enemies_2026-09-25/`.
