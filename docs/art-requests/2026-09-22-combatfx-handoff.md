# Batch 051 — A12: telegraphs, role reads and impacts

**Arty**

**To:** Prod (integration) and the owner (one decision, §1)
**Art head:** this commit, branch `claude/archipepsi-art`
**Checked against:** Production `claude/archipepsi-0-4-blindside` @ `f404410`

**Every asset here is a CANDIDATE.** Imported and fit-checked; **not**
runtime-bound and **not** owner-approved. **No timing is encoded in any
of it** — `TELEGRAPH_SECONDS` is yours and A12.6 says to keep it there.

---

## 1 · A DECISION FOR THE OWNER: whose legibility rule governs?

A12.1 says to inspect the approved projectiles' current envelopes, and
the inspection produced this batch's biggest result — which is not a
mesh.

`ProjectileSilhouette` publishes a legibility contract and the means to
check it:

```
LEGIBLE_RATIO    1.8    one is this many times more needle-like
LEGIBLE_BALANCE  0.15   or its widest point sits this much further
                        along the travel axis
reads_apart(a, b)       either measure is enough, checked pairwise
```

Its own comment says the rule is "checked pairwise across all of it, so
a fourth member cannot be added without being made distinguishable from
the other three."

**Nothing had ever run it against Art's meshes.**
`tools/content/run_projectile_legibility.sh` does, through your own
`profile()`:

| | length | cross | elongation | balance | parts |
|---|---|---|---|---|---|
| `straight` | 0.440 | 0.440 | **1.000** | 0.500 | 1 |
| `falling` | 0.440 | 0.440 | **1.000** | 0.500 | 1 |
| `lobbed` | 0.610 | 0.630 | **0.968** | 0.500 | 1 |

**All three pairs fail.** Elongation ratios 1.000, 1.033, 1.033 against
a threshold of 1.80; balance gaps 0.000 against 0.15.

### And the balance half cannot fire at all

`profile()` measures balance **per part** — its own comment explains
why: "a bounding box cannot say where along a single cone the wide end
is, but it can say which of several parts is the wide one." All three
of Art's projectiles export as **one joined mesh**. So `parts` is 1,
the widest part is the whole thing, and balance is **0.5 by
construction** for every one of them, whatever their shape.

That half of `reads_apart` is structurally dead for these assets.

### Why this is reported and not refused

Batch 008 was authored and approved under a **different rule**. It
reads by silhouette KIND — an equatorial blade ring, a downward skirt,
a segmented ball with a fuse band — and `straight()`'s own docstring
says its blades make it *"wider than it is tall so it does not read as
something that will drop"*. It is deliberately not elongated.

**Two defensible rules, and they cannot both govern.** That is the
owner's call, not a defect for Art to patch by reshaping approved work
or for Production to patch by loosening a threshold. Treating a
diagnostic as a refusal is exactly the mistake the Yard doorways taught
this lane, so `run_projectile_legibility.sh` **reports and exits 0**.

The three options, as I see them:

1. **Production's rule governs.** Batch 008's three are reshaped to
   elongate, and the family's "reads from any angle without hue"
   property is spent to buy it.
2. **Art's rule governs.** `reads_apart` is retired or rewritten to
   measure silhouette kind, and `ProjectileSilhouette`'s placeholders
   stop being the reference.
3. **Both, on different axes.** The rule becomes "elongation OR balance
   OR a declared silhouette family", and Art's three declare theirs.

I have a preference — (3), because the existing shapes work and the
rule's intent survives — but it is a preference, not a recommendation I
would act on unasked.

**Either way, one fix is Art's regardless:** exporting the projectiles
with their parts separate would make `balance` measurable. It would not
make them pass (all three are widest at the equator, by design), but a
measure that cannot fire is worse than one that fires and disagrees.

---

## 2 · A12.2 — cancel must not look like completed

`enemy.gd` emits `telegraph_finished(kind, completed)`: **one signal, a
boolean, and two outcomes that mean opposite things.** If they share a
visual the player learns nothing from either.

So `fx_telegraph_ring` carries both endings as separate geometry:

* `ring_complete_0..3` — the ring **CLOSED**: four bars meeting at the
  diagonals.
* `ring_cancel_0..1` — the ring **BROKEN**: a cross through it.

`ring_tick_0..11` are twelve marks a runtime can light in turn for
`telegraph_progress()`. **They are not a clock.** What lights how many,
and how fast, comes from `TELEGRAPH_SECONDS`.

The builder refuses the asset if either ending is missing, because
"distinguishable" needs two pieces of geometry and not one.

### And the ring is OPEN, which is A12.5

> "Foreground effects must not cover the player's weapon aim, target
> face or landing edge."

A telegraph that covers the face it announces is worse than none.
`assert_ring_is_open` measures the hole against the outer diameter and
refuses anything under 60%, so at **any** scale the body inside stays
visible. Authored at radius 1.0 about your `TelegraphOrigin` — which
sits at `ENEMY_ENVELOPES[role].centre_y`, outside `Visual`, so a flinch
does not drag it — for a runtime to scale by `lane_width`.

It fired on its own author twice, and the second time was instructive:
I shortened the cancel cross, and the hole did not move, because the
real limiter was the four **closing** bars at the diagonals, where an
axis-aligned box reaches toward the axis on x and y at once. Measuring
is for exactly that.

---

## 3 · A12.4 — refused and damaging are opposite news

> "Avoid identical response for a refused effect and a damaging hit."

* `fx_hit_shield` — **REFUSED**. A dome: convex, facing the shooter,
  with the impact sliding around it. Nothing about it reads as
  penetration.
* `fx_hit_body` — **DAMAGING**. A narrow spike going IN, everything
  pointing inward. Long and thin where the shield is wide and shallow.

`assert_pairs_differ` checks them against each other — and checks
`fx_hit_miss` and `fx_hit_interrupt` against the body hit too, because
a miss that looks like a hit and an interrupted attack that looks like
a landed one are the same failure one level along. **A shield that
sparks exactly like a wound teaches a player that armour does
nothing.**

`fx_hit_interrupt` deliberately shares `ring_cancel`'s **broken**
language and nothing else's: an interrupted attack and a cancelled
telegraph are the same news.

---

## 4 · A12.3 — legible without inventing collider coverage

`assert_within_envelope` holds every body-attached read to the role's
**published** envelope: `fx_bulwark_face` to 1.45 × 0.85,
`fx_diver_trail` to 0.70 × 1.20. A read wider than the body claims
space the collider does not have.

Ground markings are exempt and checked for **flatness** instead — under
the measured 0.12 m walk-up — because a flat mark cannot be mistaken
for coverage.

`fx_charger_lane` is a **lane, not an arrow**: the charger's rush is
unsteerable and that is its entire brief, so the read says where it
will go *and that it cannot turn*. `fx_warned_ground` is **open** in
the middle for the same reason the telegraph ring is: a filled disc
under a player's feet hides the landing edge.

---

## 5 · A12.5 — a test, not three pictures

`backdrop_pale`, `backdrop_dark`, `backdrop_busy`: the ring, all three
projectiles, and the refused/damaging pair, under the **same rig and
the same camera**, with the backdrop as the only variable.

The busy one is **panelled rather than noisy**, because what breaks a
read is competing structure, and a pack whose walls are panelled is the
realistic hard case.

---

## 6 · What is NOT here

- **No particle systems, no animation, no timing.** A12.6 keeps warning
  timing with its owner and that is you.
- **No audio.** A12.6 says missing audio is a handoff, not a reason to
  invent a second combat system. This is the handoff.
- **No new projectile meshes.** A12.1 says build only missing
  compatible role presentations "after the role contract is known", and
  §1 is exactly that contract being unsettled. A diver approach trail
  and an artillery warned ground are here because those are
  presentations of roles whose behaviour is already implemented; a
  fourth projectile is not.
- **Node counts are in the manifest**; A12.6 asks for them and every
  asset carries `triangles` and `parts`.
- **`fx_hit_miss` is the one I am least sure of.** A miss should
  probably be nothing at all, and I have built the smallest thing I
  could rather than nothing, on the grounds that "the shot went past
  you" is information. If you would rather have no asset, deleting it
  costs nothing.
