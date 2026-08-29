# Batch 030 — the ten approved enemy roles, at their published envelopes

**Status: PENDING.** Visual treatment only — no attack, AI, health, status
effect, boss behaviour or telegraph timing is invented.

## The audit corrects the art lane's own frontier

Read-only against `claude/archipepsi-echoes-continuation-b1adno`.

**Interface requirement 7 is RESOLVED.** `ART_FRONTIER.md` still says seven of
the ten roles "wait on colliders". They do not. `schemas/constants.py`
publishes `ENEMY_ENVELOPES` for all ten, with the reason in its own comment:
*"the envelope is the box the art lane declared for the role, so a model and
a collider cannot be built to different numbers."*

**Interface requirement 14 is RESOLVED too.** `enemy.gd` carries
`telegraph_started(kind, duration)`, `telegraph_finished(kind, completed)`,
`telegraph_progress()` → 0..1, and a named attachment point —
`telegraph_origin: Marker3D` at the collider centre, deliberately *outside*
the `visual` container so a flinch cannot drag it around. That container has
its own hard-won rule attached: *"EVERY mesh hangs off this and nothing else
does… which is what `scale` on the body did, and it grew the brute's hitbox
12% for the half second it was winding up."*

**So this batch is not a proposal in the way 023–029 were.** It is authored to
numbers Production has already published, every model is built to its role's
exact envelope, and **the builder asserts the fit** — four roles' limbs had to
be pulled in during the build, which is the assertion doing its job.

**What is still missing is narrow: requirement 31.** `ENEMY_ARCHETYPES` — the
set a Zone may actually place — is still `("melee", "ranged", "brute")`.
Seven of the ten have an agreed body, an agreed collider and a telegraph seat,
and no way to be spawned.

## The discipline: variety from inside a fixed box

The envelope is a contract, so silhouette variety has to come from
*proportion*, not size. Each role is built around what its envelope already
implies:

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
end** (charger's mass forward, artillery's at the barrel, brute's in the
shoulders), every role carries a **telegraph seat** at `centre_y` matching
`telegraph_origin` — reserved geometry, not a telegraph, and it does not
animate — and **flyers do not stand**: both hover roles are modelled around
their collider centre at the published `hover_height`.

## Metrics

| asset | tris | built size (m) | envelope (m) |
|---|---|---|---|
| `enemy_role_melee` | 124 | 0.78 × 0.68 × 1.55 | 0.80 × 1.60 × 0.80 |
| `enemy_role_ranged` | 140 | 0.56 × 0.66 × 1.37 | 0.70 × 1.40 × 0.70 |
| `enemy_role_brute` | 136 | 1.80 × 1.60 × 2.40 | 1.80 × 2.60 × 1.80 |
| `enemy_role_charger` | 180 | 0.90 × 1.84 × 0.84 | 0.90 × 1.05 × 1.90 |
| `enemy_role_bulwark` | 160 | 1.45 × 0.82 × 1.99 | 1.45 × 2.05 × 0.85 |
| `enemy_role_scuttler` | 176 | 1.24 × 1.16 × 0.34 | 1.30 × 0.62 × 1.20 |
| `enemy_role_artillery` | 176 | 1.18 × 1.25 × 1.50 | 1.25 × 1.55 × 1.25 |
| `enemy_role_beacon` | 232 | 0.55 × 0.55 × 2.20 | 0.62 × 2.20 × 0.62 |
| `enemy_role_diver` | 108 | 0.70 × 1.13 × 0.40 | 0.70 × 0.50 × 1.20 |
| `enemy_role_drifter` | 204 | 1.25 × 1.25 × 0.78 | 1.35 × 0.95 × 1.35 |

(Built size is reported in Blender's X/Y/Z; the envelope is Production's
width/height/depth. Every model is inside its box on every axis, asserted at
build time.)

## Palette

Enemies wear `propkit.enemy_skin`, the approved family treatment. `hazard`
appears **only** on the beacon — the one role whose envelope is a fixture
rather than a body — and even there as a marked band, never a wash. No enemy
takes `signal`, `identity` or `send`: a thing that hurts you is not a thing
you can use, is not Epsilon, and does not leave for the multiworld.

## What this batch did NOT achieve, stated plainly

Sheet A proves the silhouettes are distinguishable and correctly scaled. It
also shows the honest limit of this pass:

> **All ten wear the same skin.** Surface treatment does no work at all to
> separate roles — at distance the family reads as ten brown panelled masses
> of different shapes. Silhouette and envelope compliance are done; **role
> identity in the surface is not**, and that is the obvious next revision.

The brief asked for "stronger production visual treatment". This delivers the
half that could be verified against a contract — every model provably inside
its published collider — and does not pretend the material half is finished.

## Sheets

| | |
|---|---|
| `A_enemy_lineup.png` | all ten at player eye height, 1.8 m rod, flyers at their published hover |
| `B_enemy_envelopes.png` | each model inside its declared collider, drawn |
