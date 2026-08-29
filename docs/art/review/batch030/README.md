# Batch 030 / 037-R — the ten approved enemy roles, and their surfaces

**Status: PENDING.** Visual treatment only — no attack, AI, health, status
effect, boss behaviour or telegraph timing is invented.

Batch 030 established the ten bodies at their published envelopes. **Batch
037-R is the revision the owner asked for**, and it addresses exactly one
finding of 030's own: the surface did no work. The bodies and silhouettes are
unchanged — the owner ruled explicitly *"do NOT redesign the bodies or
silhouettes"* — and everything below is surface, construction and evidence.

## The rule, in one line

> **Armour goes where the role takes or deals impact. Mechanism shows where
> it does not.**

One rule, applied ten times. Not ten decorations, and — the owner's
constraint — **not ten colours**. Every role keeps `propkit.enemy_skin`, so
none of them shifts with the room it stands in.

| role | where the armour is | where the working shows |
|---|---|---|
| melee | bracers, where the blow is delivered | shoulders and back |
| ranged | a housing round the emitter and the eye | the feed under it |
| brute | everywhere — everything hits a brute | the gaps between plates |
| charger | the whole leading face | the open rear |
| bulwark | one uninterrupted face, never broken | the drive behind it |
| scuttler | a carapace cap, and nothing else | four exposed hip drives |
| artillery | a heavy apron low | the open breech, worked on, up high |
| beacon | **none** — it is a fixture that took sides | conduit and junctions up the mast |
| diver | a solid nose cap | the open tail |
| drifter | a plated crown over the working | the entire skirt |

## What 037-R changed, and why

**First attempt: material only.** Armour was told from mechanism by
*roughness* — matte plate against an oilier mechanism. At mid range that reads
as **shadow**, not as a different kind of thing, and the owner's verdict on
the lineup was exact: *"the same brown-panel family with different
silhouettes."*

**The fix is construction, not colour.** Roughness is kept, but the difference
is now carried by how the two are BUILT:

- **plate** → a slab seated *proud of a recess*: the face shrinks to 88% and
  the backing keeps the declared extent, so armour reads as something bolted
  **on** rather than as more body.
- **mech** → **ribbed and rodded**: three slats across the longest horizontal
  axis with a rod through them, so mechanism reads as machinery rather than
  as a dark box.

The first version of the plate grew a *lip* outward instead of shrinking the
face, which pushed the brute's pauldrons 6 cm outside `ENEMY_ENVELOPES`. The
build assertion caught it, which is what it is for.

**Two roles were mislabelled and are now retagged.** `_scuttler`'s carapace
and `_beacon`'s head were tagged `plate` in their body builds — the single
largest mass on the two roles captioned *"barely armoured at all"* and *"no
armour at all"*. Both are now `body`. Materially this is a no-op (`body` and
`plate` share a material; the distinction is carried entirely by
construction), but the label should not contradict the rule the sheet exists
to prove.

## Sheet C is the evidence, and it took three passes to become valid

`C_enemy_surfaces.png` shows the five role pairs at **4.0 m** plus one
maximum-size detail. The owner asked for mid/close evidence with grouped
comparisons and the **same lighting and camera**. Getting there:

1. **Fixed 3.4 m standoff** — the drifter, hovering at 2.55 m, was simply
   above the frame. Framing on envelope height ignores hover; a flyer's crown
   is `hover + height/2`.
2. **Standoff scaled with the crown** — fixed the clipping and broke the
   sheet. A surface comparison shot from five different distances is not a
   comparison, because distance *is* the variable a surface test measures.
3. **One camera, distance set by the widest pair** — one lens, one azimuth,
   level, and only the height it is set at changes. The first version of this
   sized the distance on envelope *width* alone and the brute ran off its own
   left edge: at a three-quarter azimuth a body's **depth is turned partly
   sideways** and counts toward how much of the frame it eats. A 1.8 × 1.8 m
   brute is 2.24 m wide on screen.

## What sheet C shows, honestly

**It reads in four of the five pairs and in the detail.** Bulwark's
uninterrupted plated face against artillery's open breech; the beacon's bare
ribbed mast against the ranged role's housed instrument; the drifter's plated
crown over a mechanical skirt; the charger's plated leading face against its
open rear. The DETAIL cell carries it most clearly — proud slabs against a
recessed ribbed frame, on one body, in one skin.

**The weak pair is brute / scuttler.** The caption claims "barely armoured at
all" and the scuttler still reads as a fairly solid dome. The retag above is
the honest half of the fix; the other half would be a body change, which is
out of scope by instruction. Recorded, not worked around.

**The rest of 030's finding is now retired.** "All ten wear the same skin" is
still true of the *palette* — deliberately, since an enemy never wears its
room's colours — but it is no longer true that surface does no work.

## The audit that corrected the art lane's own frontier (from 030)

Read-only against `claude/archipepsi-echoes-continuation-b1adno`.

**Interface requirement 7 is RESOLVED.** `schemas/constants.py` publishes
`ENEMY_ENVELOPES` for all ten, with the reason in its own comment: *"the
envelope is the box the art lane declared for the role, so a model and a
collider cannot be built to different numbers."*

**Interface requirement 14 is RESOLVED too.** `enemy.gd` carries
`telegraph_started(kind, duration)`, `telegraph_finished(kind, completed)`,
`telegraph_progress()` → 0..1, and a named attachment point —
`telegraph_origin: Marker3D` at the collider centre, deliberately *outside*
the `visual` container so a flinch cannot drag it around.

**What is still missing is narrow: requirement 31.** `ENEMY_ARCHETYPES` — the
set a Zone may actually place — is still `("melee", "ranged", "brute")`.
Seven of the ten have an agreed body, an agreed collider, a telegraph seat
**and now a role-specific surface**, and no way to be spawned. That is
engineering truth for a Production slice; Art has deliberately not routed
around it.

## Variety from inside a fixed box

The envelope is a contract, so silhouette variety comes from *proportion*,
not size.

| role | envelope (m) | reads as | placeable today |
|---|---|---|---|
| melee | 0.80 × 1.60 × 0.80 | upright, forward-weighted; the arms are the threat | **yes** |
| ranged | 0.70 × 1.40 × 0.70 | recessed body, one carried emitter — read the muzzle | **yes** |
| brute | 1.80 × 2.60 × 1.80 | mass over reach: a slab of shoulders, a small head | **yes** |
| charger | 0.90 × 1.05 × 1.90 | a battering ram — the long axis *is* the attack | no — req 31 |
| bulwark | 1.45 × 2.05 × 0.85 | a wall that walks: broad face, almost no depth | no — req 31 |
| scuttler | 1.30 × 0.62 × 1.20 | flat and splayed, legs out, body low | no — req 31 |
| artillery | 1.25 × 1.55 × 1.25 | a seated mortar: braced base, elevated barrel | no — req 31 |
| beacon | 0.62 × 2.20 × 0.62 | a mast, not a creature — a fixture that took sides | no — req 31 |
| diver | 0.70 × 0.50 × 1.20, hover 1.90 | nose down; committed to a direction even at rest | no — req 31 |
| drifter | 1.35 × 0.95 × 1.35, hover 2.55 | a hanging bell — deliberately gives away no facing | no — req 31 |

Threat legibility without inventing behaviour: **the threat end is the heavy
end**, every role carries a **telegraph seat** at `centre_y` matching
`telegraph_origin` — reserved geometry, not a telegraph, and it does not
animate — and **flyers do not stand**: both hover roles are modelled around
their collider centre at the published `hover_height`.

## Metrics

Triangle counts rose across the board in 037-R — that is the construction
change, and every role is still far inside the 700-triangle `enemy` tier.

| asset | tris | built size (m) | envelope (m) |
|---|---|---|---|
| `enemy_role_melee` | 316 | 0.784 × 0.688 × 1.552 | 0.80 × 1.60 × 0.80 |
| `enemy_role_ranged` | 236 | 0.574 × 0.663 × 1.372 | 0.70 × 1.40 × 0.70 |
| `enemy_role_brute` | 232 | 1.800 × 1.656 × 2.405 | 1.80 × 2.60 × 1.80 |
| `enemy_role_charger` | 348 | 0.900 × 1.881 × 0.840 | 0.90 × 1.05 × 1.90 |
| `enemy_role_bulwark` | 328 | 1.450 × 0.816 × 1.988 | 1.45 × 2.05 × 0.85 |
| `enemy_role_scuttler` | 392 | 1.237 × 1.163 × 0.341 | 1.30 × 0.62 × 1.20 |
| `enemy_role_artillery` | 296 | 1.175 × 1.250 × 1.502 | 1.25 × 1.55 × 1.25 |
| `enemy_role_beacon` | 376 | 0.550 × 0.550 × 2.200 | 0.62 × 2.20 × 0.62 |
| `enemy_role_diver` | 180 | 0.700 × 1.130 × 0.400 | 0.70 × 0.50 × 1.20 |
| `enemy_role_drifter` | 420 | 1.247 × 1.247 × 0.817 | 1.35 × 0.95 × 1.35 |

(Built size is reported in Blender's X/Y/Z; the envelope is Production's
width/height/depth. Every model is inside its box on every axis, asserted at
build time.)

## Palette

Enemies wear `propkit.enemy_skin`, the approved family treatment. `hazard`
appears **only** on the beacon — the one role whose envelope is a fixture
rather than a body — and even there as a marked band, never a wash. No enemy
takes `signal`, `identity` or `send`: a thing that hurts you is not a thing
you can use, is not Epsilon, and does not leave for the multiworld.

## Sheets

| | |
|---|---|
| `A_enemy_lineup.png` | all ten at player eye height, 1.8 m rod, flyers at their published hover — 11 m, where surface can do no work |
| `B_enemy_envelopes.png` | each model inside its declared collider, drawn |
| `C_enemy_surfaces.png` | **037-R.** five role pairs at 4.0 m on one camera, plus a maximum-size plate-vs-mechanism detail |

---

## History — what Batch 030 said before 037-R

030's own closing section is kept here rather than deleted, because the
revision above is the answer to it:

> **All ten wear the same skin.** Surface treatment does no work at all to
> separate roles — at distance the family reads as ten brown panelled masses
> of different shapes. Silhouette and envelope compliance are done; **role
> identity in the surface is not**, and that is the obvious next revision.

030's triangle counts, before the construction change: melee 124, ranged 140,
brute 136, charger 180, bulwark 160, scuttler 176, artillery 176, beacon 232,
diver 108, drifter 204.
