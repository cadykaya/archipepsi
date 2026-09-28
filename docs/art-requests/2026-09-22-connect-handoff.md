# Batch 049 — A09: cross-room machinery and branch identity

**Arty**

**To:** Prod (integration) and Dess (selection, where it applies)
**Art head:** this commit, branch `claude/archipepsi-art`
**Extends:** Batch 043's machinery kit, not replacing it

**Every asset here is a CANDIDATE.** Imported and fit-checked; **not**
runtime-bound and **not** owner-approved.

---

## What this is, and what it deliberately is not

A09's outcome is that a player can connect a source-room action with a
destination-room consequence. That is a visual **language** problem, and
A09.1 draws the line for me:

> "Do not build a gameplay signal bus; the model is a readable
> presentation of declared relationships."

So there is no signal here, no state machine, no script and **no
animation**. Fourteen assets and a vocabulary.

---

## 1 · It extends Batch 043 rather than replacing it

`mach_conduit_run` is 2.00 × 0.50 m, 0.14 deep, with a separate
`state_band` quad carrying the 64 × 16 state texture and a `fill_band`
that grows across it. **Every piece here keeps that face height and that
convention**, so a run, an elbow and a tee show the same state at the
same pitch.

`assert_band_face` refuses a piece whose band is not 0.50 m on the run's
face axis, and `connect_fit.gd` checks it again after import. **A corner
whose band is a different width from the run it turns is a different
system, not the same run continuing.**

`conn_run_tee` carries **two** declared bands — the through run and
`tee_branch_band` — because a fork whose halves cannot differ cannot
show which way a thing went.

---

## 2 · A09.2's real requirement: three commitments, three machines

> "Persistent configuration, a held input and a permanent repair must
> not share a misleading identical switch pose."

Colour does not survive a theme change, so the distinction has to be
**shape**:

| asset | commitment | its tell |
|---|---|---|
| `conn_set_dial` | persistent configuration | a **detent ring** — something that holds a position |
| `conn_hold_paddle` | held input | a **visible spring** and a stop — it wants to come back |
| `conn_repair_seal` | permanent repair | a lever behind a **frangible tab** — using it breaks a thing |

The third one is the interesting one. The only honest way to draw "this
cannot be undone" is a one-shot: `seal_tab_left` and `seal_tab_right`
are separate nodes so a runtime can show intact or broken.

**`assert_commitments_differ` refuses if any two are within 5 cm on
every axis**, at build time, and `connect_fit.gd` repeats the check
after import. A player who cannot tell them apart across a room has been
lied to, and a comment in a builder does not prevent that.

Each carries its kind in the manifest as `commitment`, so the
distinction is data a consumer can read rather than something a reviewer
has to remember.

---

## 3 · A09.3 — the same plaque at both ends, and no second nav language

`conn_id_plaque` is **one asset, mounted twice**. Its `plaque_id_field`
is a blank plate: the identifier is **runtime-populated**, because a
baked one would be Art asserting a relationship the runtime might not
have — and A09.3 warns specifically against relying on a popup the
player never sees.

**The blade is the approved navigation family's and this does not
rebuild it.** `nav_blade` (Batch 022, `PASS`, six themes) bolts to
`blade_seat`. Art is not making a second navigation language.

---

## 4 · A09.4 — acknowledgments that cannot lie

`conn_flag_ack`, `conn_breaker` and `conn_gauge`. A09.4's condition is
that art must not "animate success ahead of the authoritative result",
so every moving part is a **node with declared positions** and nothing
in the file animates. A node with two positions structurally cannot run
ahead of anything.

**`conn_gauge` has a needle, and here that is the right instrument.**
A08.2 was explicit that the semantic-class plate must not reuse the
accumulating-kilogram gauge — but A09.4 lists a gauge needle among the
local acknowledgments, and "how much of a deferred thing has happened"
genuinely is a continuous reading. The two rules are not in conflict;
they are about two different sensors, and both kits say which.

---

## 5 · A09.5 — nonblocking, and checked

`conn_relay_cabinet` is 0.9 m of floor and 2.1 m tall: a thing you walk
past, reused in the branch footprint rather than becoming a new hero
room. `conn_service_stack` is the generator end of the same
installation.

`assert_no_footholds` refuses any upward face 0.35 m square in the band
a player can actually reach.

### That rule was wrong, and the correction is worth reading

It had **no upper bound**, so it refused the *top* of the two-metre
relay cabinet — which a player cannot get onto, because a standing jump
tops out at 1.333 m and there is no mantle. **A rule that refuses
correct art is a rule that gets switched off**, and then it is worse
than nothing. It is bounded by the measured jump now, in this batch and
in Batch 048, which shares it. Re-verified (Batch 048 still passes) and
re-sabotaged with a waist-high ledge, which is still refused.

---

## 6 · A09.6 — the evidence strip, under one rig

Five frames: `a_source`, `b_route`, `c_destination`,
`d_destination_unpowered`, `e_reverse`. Plus fourteen solos.

A09.6's condition is the one that matters:

> "no private lighting or geometry change to make the connection look
> obvious"

So **there is only one lighting function in the file.** There is no
per-shot lighting argument, structurally. `d_destination_unpowered` is
the same geometry, the same rig and the **same camera** as
`c_destination`; the only difference is which nodes are tinted.

**The relationship ID is written by the caption, not by the asset.**
`plaque_id_field` and `label_field` are blank, and every frame says the
"R-14" is the harness talking.

**The band tint is a preview of addressability and every frame says so.**
`ContentInstantiator._from_authored_scene` calls `scene.instantiate()`
and performs no material replacement; these frames demonstrate that the
bands arrived as fetchable nodes, not that the game lights them.

### Three things the strip cost, honestly

The first strip showed conduit with **no state on it at all**: the run's
band sits at Blender y = −0.075, which the exporter maps to runtime +z,
so an unrotated run puts its band **into the wall behind it**. Five
frames of clamps. The second showed every band blown to flat white at
emission 2.2 — a light box, which is the opposite of showing that the
state registers with the channel. Both are fixed and both are recorded,
because "it looked wrong in the render" is the cheapest place to catch
an orientation error and the most expensive place to miss one.

---

## 7 · What I am NOT claiming

- **Not runtime-bound**, and there is no consumer for a relationship ID
  today. That is the integration question this kit raises and does not
  answer.
- **Not owner-approved.**
- **The strip's relationship is staged.** Source, route and destination
  are three separate scenes I built to the same ID; they are not one
  Zone. A09.6 asks for a three-view strip and this is one, but it is not
  evidence that a generated Zone would place them this way.
- **`conn_wall_pass` assumes a 0.6 m wall.** If your walls are a
  different thickness the sleeve wants a parameter, which is a rebuild
  and not a placement.
- **The reader's four states are four nodes in one place.** If you would
  rather have one node whose material changes, say so — that is a
  different asset, not a tweak, and I would rather build the one you
  will use.
