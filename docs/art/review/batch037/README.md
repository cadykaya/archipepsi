# Batch 037 (030-R) — enemy surface role identity

**Status: PENDING.** The ten silhouettes and every envelope are **unchanged**.
No attack, AI, health or mechanic is invented.

## The problem, from 030's own review

> *"All ten wear the same skin. Surface treatment does no work to separate
> roles — at distance the family reads as ten brown panelled masses of
> different shapes."*

That was stated in the 030 notes rather than discovered later, and this is
the fix.

## The rule, and it is one rule rather than ten decorations

> **Armour goes where the role takes or deals impact.**
> **Mechanism shows where it does not.**

That is functional, which is exactly what keeps ten roles reading as one
ecosystem: every member is the same machine underneath, plated differently
because it does a different job. A brute is armoured everywhere because
everything hits it. A scuttler is barely armoured because its answer to being
hit is not to be there. A bulwark's front is one uninterrupted plate and its
back is all drive.

**Explicitly not ten colours.** Three treatments carry it:

| treatment | what it is | how it is told apart |
|---|---|---|
| `plate` | armour — clean, thick, unbroken | matte |
| `mech` | exposed working: drives, linkages, feed | **oily** — lower roughness |
| `body` | the shared chassis every role is built on | matte |

`plate` and `mech` both keep `enemy_skin`, so **neither shifts with the
room** — L-08's rule that an enemy never wears its room's colours applies to
the working parts too. The difference between armour and mechanism is a
**material property**, not a hue.

## What each role's plating says

| role | tris | the surface story |
|---|---|---|
| melee | 184 | bracers only — speed is its answer to being hit |
| ranged | 176 | the barrel and the eye are housed; the feed is open |
| brute | 184 | plated everywhere, nothing exposed — mass is the argument |
| charger | 240 | armour on the **front third**, open drive behind it |
| bulwark | 208 | one uninterrupted face plate; all mechanism behind |
| scuttler | 236 | a carapace cap and four exposed hip drives |
| artillery | 212 | heavy apron low, open breech high — a served weapon |
| beacon | 268 | **no armour at all**; service conduit and junctions |
| diver | 132 | solid nose cap, open tail |
| drifter | 264 | plated crown, entirely mechanical skirt |

`hazard` remains on the beacon's band alone, and telegraph orange stays
reserved for actual danger. Every model is still inside its published
`ENEMY_ENVELOPES` box, asserted at build time, and every triangle count is
well inside the 700 `enemy` tier.

## Requirement 31 is unchanged and is engineering truth

`ENEMY_ARCHETYPES` is still `("melee", "ranged", "brute")`. Seven of the ten
now have an agreed body, an agreed collider, a telegraph seat **and** a
role-specific surface — and no way to be spawned. **Art has not worked around
that and should not.**
