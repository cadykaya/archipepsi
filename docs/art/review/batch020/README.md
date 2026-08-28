# Batch 020 — architecture Pri-B, the structural half

**Open `K_bay_in_situ.png` first.** Two wall bays, two ceiling bays and the
trim beam, assembled. A kit part is only right if it is right next to
another one, and that is the only frame here that tests it.

Tier 3 has 29 modules; Batches 001 and 007 built the 15 Pri-A ones. These
are the seven Pri-B modules that are *what a chamber is made of*. Batch 021
will take the services and openings.

Full write-up: [`ART_REVIEW.md`](../../ART_REVIEW.md) § *Batch 020*.

| Module | Tris | For |
| --- | --- | --- |
| `arch_wall_variant_a` | 72 | a service band at 2.20 m — above eye height, below standing reach |
| `arch_wall_variant_b` | 60 | a 1.60 × 2.60 recessed bay; 2.60 is `tallest_actor` |
| `arch_ceiling_plain` | 60 | the flat bay the coffered one is a change from |
| `arch_trim_ceiling` | 48 | the ceiling beam **with the rib feet that carry it** |
| `arch_floor_grate` | 204 | real bars over a 0.30 m void |
| `arch_column` | 60 | on `_greeble_room`'s own 0.50 m buttress footprint |
| `arch_beam_span` | 76 | a beam across a bay that has no ceiling |

## Two things worth knowing

**Nothing here is invented.** Every module replaces geometry
`chamber_builders` already builds — the rib at 0.22 × 0.35, the ceiling
beam at 0.25 × 0.35, the buttress at 0.50 — so the numbers came from the
engine, not from taste. The one editorial move is `arch_trim_ceiling`
drawing the beam *and* its rib feet as one part, because in the engine's own
layout they are one structural bay and the procedural version leaves the
beam floating.

**The triangle budget did its job.** The grate first came in at 264 against
a 250 ceiling, and the rule is delete geometry rather than raise the
ceiling. The bar pitch went 0.24 → 0.32 m and three bearers became one:
204, and a truer grating for it.

## Blocked, deliberately

`arch_signage_mount` and `arch_objective_socket` are Pri B but stay blocked
with the navigation language. A socket's size and shape prejudge what plugs
into it, so building them now would decide that language sideways.

Status: **PENDING**. Not self-marked.
