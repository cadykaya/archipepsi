# Batch 047 — the skiff's fitted parts: shield, guard, traction

**Arty**

**To:** Prod (integration)
**Art head:** this commit, branch `claude/archipepsi-art`
**Fitted against:** Production `claude/archipepsi-0-4-blindside` @ `f404410`

**Every asset here is a CANDIDATE.** Imported, fit-checked and swept;
**not** runtime-bound and **not** owner-approved.

---

## What this is

A03.2 and A03.3. Batch 045 gave the skiff a hull; this gives it the
parts that are fitted **to** that hull and have to survive being looked
at from a rider's eye rather than from outside the vehicle.

| id | metrics | parts | for |
|---|---|---|---|
| `sp_skiff_shield` | 120 tris · 0.64 × 4.00 × 1.25 m · 32 texels/m | 9 | A03.2 — your cover box, given a face |
| `sp_skiff_rail` | 84 tris · 3.70 × 0.24 × 1.05 m · 32 texels/m | 6 | A03.2 — the end guard as a fitted part |
| `sp_skiff_bogie` | 140 tris · 0.33 × 1.60 × 0.43 m · 32 texels/m | 8 | A03.3 — the traction truck |
| `sp_skiff_deck_bare` | 180 tris · 4.00 × 4.16 × 1.29 m · 32 texels/m | 14 | the hull with no end guards |

Source: `tools/blender/build_skiffkit.py` (and `build_setpieces.py` for
the bare hull — one source, two exports). Exports:
`assets/models/batch047/skiffkit/`. Evidence:
`docs/art/review/skiffkit_2026-09-22/`.

---

## 1 · Why there is a bare hull now

`sp_skiff_deck` bakes its end guards into the mesh. A03.2 asks for the
railings **as fitted parts with their own attachment points**, and a
guard baked into the hull is not that — but a hull with nothing on its
ends is not a finished vehicle either.

So both exist, from one source, and **you pick**: the one-piece
`sp_skiff_deck`, or `sp_skiff_deck_bare` with `sp_skiff_rail` bolted on.
**Stacking them doubles the rail**, which is exactly what the first
loaded frame of this batch showed, and why the variant exists.

The lamps are state nodes rather than guard, so `lamp_fore` and
`lamp_aft` survive on the bare hull at deck level.

---

## 2 · The cover height is not Art's to change

`_shield()` builds a 0.3 × 1.25 × 4.0 `CollisionShape3D` on an
`AnimatableBody3D`, centred at local (−1.85, 0.825, 0). That cover is
**real and standable**, and its top at 1.25 above the deck is a gameplay
number.

So `sp_skiff_shield` is authored around exactly that box, and
`assert_cover_intact()` refuses any visual whose top rises above it. The
capping rail and the kick plate **eat into** the 1.25 rather than adding
to it; a coping that adds 6 cm adds 6 cm to what a rider has to shoot
over.

The ribs are on the **inboard** face — what a rider standing behind it
sees. The outboard face is plain, because that is the one being shot at.
The panel stays flush with the hull line at x = −2.00; the first cut's
coping overhung by 3 cm and `assert_clear_of_docks` refused it, which is
3 cm of something to catch on a dock the carrier passes.

### The eye-level evidence, which A03.2 asks for by name

`rider_eye_over_shield.png` — standing, from behind the cover, with
three 1.8 m markers out in the yard. **Clear by 0.35 m**, measured, and
it holds in every pose because the shield rotates with the deck.

`rider_eye_crouched.png` — the same markers at a 1.00 m crouch: the
panel, its ribs and sky. Cover that only works standing is not cover.

`rider_eye_boarding.png` — from the dock side at eye height, showing the
boarding face stays open.

---

## 3 · The bogie cannot go under the deck, and that is a finding

`_track()` lays pieces 0.5 × 0.35 centred on the rail at 0.6, so the
visible track spans world **0.425 to 0.775**. The deck spans **0.600 to
1.000**.

**The beam is already 0.175 m inside the bottom of the deck.** There is
no space beneath it for a truck, because the rail is in there.

So the traction assembly hangs **beside** the beam: the beam is 0.5 m
wide (±0.25 of the rail centre) and the trucks stand at **±0.45**, with
contact shoes reaching in to its sides. Outside-frame trucks on a centre
beam — a real arrangement, and the only one this geometry allows.
`assert_clear_of_beam()` checks both placements, the second mirrored,
because checking an asset at its authoring origin answers the wrong
question.

**The rollers are nodes, not motion.** `roller_0` and `roller_1` are
separate objects whose local origin is their own axle, so a runtime that
wants them to turn with travel can rotate them without touching the
parent. Nothing here is animated and no root motion is authored. They
are named 0 and 1 rather than fore and aft because the pair is mirrored
and "fore" on one truck would be "aft" on the other.

`loaded_outside.png` shows your beam in grey, coming up into the deck.

---

## 4 · A03.5 — the swept envelope, over the whole route

`tools/content/run_skiff_sweep.sh` → `.../skiffkit_2026-09-22/sweep.json`

A still render answers nothing about a vehicle that turns.
`RailCarrier.pose()` takes its basis from the rail's tangent, so on this
route **the deck yaws through the corner**, and a fitting that clears a
dock at S1 may not clear one at S2. The harness poses the loaded carrier
at every half metre of rail with `pose()`'s own arithmetic — not a
paraphrase of it — and checks the fittings' real boxes against all three
pads.

```
[sweep] PASS -- the loaded skiff sweeps the whole route without
        entering a dock pad; envelope 29.09 x 2.00 x 30.14 m
```

* **No pad intrusion**, at any offset.
* **Swept envelope 29.09 × 2.00 × 30.14 m** — one number to hold a
  budget against. The 2.00 in height is the bogie's underside at world
  0.25 to the shield's top at 2.25.
* **Sight over the shield: 0.35 m**, in every pose.

**A graze is not an intrusion**, and the first cut of this said it was:
the guard's panel sits with its foot exactly on the deck top, which is
exactly the pad's top, so a corner lands on the shared plane and
floating point puts it 1e-7 inside. Two of those were reported as
failures at "0.000 m", which is a gate crying wolf on a tangency the
geometry is supposed to have. The threshold is 2 mm now.

---

## 5 · A03.6 — the state strip, with a warning attached

Five frames, `state_accepted` through `state_interrupted`, showing
`lamp_fore`, `lamp_aft`, `beacon_hold` and `console_readout` lit.

**THEY ARE A PREVIEW TINT AND NOTHING ELSE.**
`ContentInstantiator._from_authored_scene` calls `scene.instantiate()`
and performs no material replacement, so an authored asset keeps the
materials it was exported with. These frames are **not** a claim about
what the game does. They demonstrate that each state region arrived as a
**node a script can fetch by name** — which is the only thing Art can
deliver here, because what lights a lamp and when is yours.

Said this loudly because a preview that forcibly swapped materials has
been mistaken for engine behaviour in this lane before, and that frame
became the evidence for a repair request that should never have been
made.

---

## 6 · What I am NOT claiming

- **Not runtime-bound.** The presentation-seam ask from the Batch 045
  handoff still stands and covers these equally.
- **Not owner-approved.** Candidates.
- **The bogie is invisible in every outside view**, because it is under
  a 4 m deck. It is there for the moment the camera is low or the
  carrier is seen from a dock, and for nothing else. If that is not
  worth 140 triangles, say so and it goes.
- **The sweep does not model the shield's own collision.** It sweeps
  the VISUAL boxes. Your `CollisionShape3D` is unchanged and this batch
  adds none.
- **`sp_skiff_rail` at the aft end is the fore asset turned 180°.** One
  mesh, two placements. If you want distinguishable ends, that is a
  second asset and I would rather be told than guess.
