# Batch 027 — PROPOSAL: pickups, loot and resource readability

**Status: PENDING. Visual proposals only.** No resource mechanic and no
denomination is decided: not what health restores, not what a resource is
spent on, not how much of anything a pickup gives.

## The audit changed the shape of this batch

Read-only against `claude/archipepsi-echoes-continuation-b1adno`.

| requested | what exists in Production |
|---|---|
| Epsilon Coin | **REAL.** `ITEM_NAME_EPSILON_COIN`, `EPSILON_COIN_COUNT = 10` |
| special resource | **REAL.** `ITEM_NAME_EPSILON_STATIC`, `EPSILON_STATIC_COUNT = 18` |
| secret cache / container | **PARTLY** — see below |
| health | **NOTHING.** `LOW_HEALTH_FRACTION = 0.33` says the player *has* health. No item, no pickup, no entity |
| combat resource / ammo | **NOTHING.** No item, no constant, no entity, no mention anywhere |

And `local_reward.gd` carries a **closed** catalog:

```
const KINDS := ["epsilon_note", "challenge_marker", "cosmetic_grant",
        "hub_decoration", "lab_fixture", "flavor_log"]
```

with its reason stated in the file: *"the client must not be able to invent a
seventh kind, and a wire-level rejection after the pickup has already
vanished is a worse failure than never offering it."*

So a loot **container** is not a seventh kind art may add. None of the six is
one, and the only place that could hold it is explicitly sealed.

**Two of the five are a design question before they are an art question**, and
one is a schema question. Recorded as **interface requirement 28**. All five
are still built — the brief asked for five — and each records in its manifest
whether a real item backs it.

## Colour discipline: what is licensed

| family | used here? |
|---|---|
| `glitch` | **yes, for Epsilon Static only** — the family is literally defined as "Epsilon Static and the missing-world checker" |
| `identity` | **as a mark, not a material.** The coin carries Epsilon's stamp; it is not *made* of Epsilon green |
| `send` | **no.** It means a transmission beam and a destination ring. A coin is not a beam |
| `signal` | **no.** "The only colour an interactable *prompt*, rim or reveal face may be." A pickup is walked over, not operated |
| `hazard` | **no.** Never decorative, in any theme |

That leaves health and ammo with **no hue at all** — correct, not a
shortfall. Which is why sheet B is the load-bearing one.

## The shared grammar

Every pickup sits on the same hexagonal floor mat. Learned once it means
*you can take this*, so the object above it is free to be **only** about
which thing it is:

```
mat    = "you can take this"     (identical on all five)
object = "this is what it is"    (shares nothing between them)
```

## Why the Coin looks like that

Ten exist in an entire campaign and they fuel the Forge. It cannot look like
small change — and it cannot get there by being brighter, because brightness
is how the Check, Epsilon and hazard already speak. So it is the only object
in the game *presented* as valuable: a thick milled disc standing **on edge
in a cradle** rather than lying flat, at the scale of a hand, with a milled
rim carrying a highlight the whole way round. A specular story, not an
emissive one.

## Metrics

| asset | represents | tris | size (m) | backed by a real item |
|---|---|---|---|---|
| `pickup_coin` | Epsilon Coin | 212 | 0.59 × 0.59 × 0.48 | **yes** |
| `pickup_health` | health | 184 | 0.59 × 0.59 × 0.39 | no — req 28 |
| `pickup_resource` | combat resource / ammo | 176 | 0.59 × 0.59 × 0.22 | no — req 28 |
| `pickup_special` | Epsilon Static | 188 | 0.59 × 0.59 × 0.47 | **yes** |
| `pickup_cache` | secret cache / container | 160 | 0.66 × 0.59 × 0.55 | no — req 28 |

## Sheets

| | |
|---|---|
| `A_pickups.png` | five at hand distance, lit |
| `B_pickup_silhouettes.png` | at 12 m, and again flat black and unlit |

## What the silhouette sheet caught

It caught a real failure, which is what it is for. **`pickup_resource` and
`pickup_special` first read as the same object** — two blocks of similar
proportion on identical mats. That is doubly wrong, because the special is
the *corrupted* one and should be the only pickup in the set whose outline is
not orderly.

They are now separated on both axes: the resource is broader than it is tall,
the slug is the reverse, and the slug gained a third lobe at an unrelated
angle — two lobes still read as a taper, three read as something that grew
wrong.

A lit hero shot would never have found this. Neither would a triangle count.
