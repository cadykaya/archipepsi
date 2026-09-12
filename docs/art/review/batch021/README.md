# Batch 021 — the services and openings

**Open `S_bore_inside.png` first** — three bore sections chained, from
inside, which is the only frame that tests whether the section tiles.

Batch 020 took the seven modules a chamber is made *of*. These are the six
it is fitted *out* with, and they finish every Tier 3 row that has an
engine contract to build against.

Full write-up: [`ART_REVIEW.md`](../../ART_REVIEW.md) § *Batch 021*.

| Module | Pri | Tris |
| --- | --- | --- |
| `arch_vent` | B | 116 |
| `arch_duct` | B | 96 |
| `arch_catwalk` | B | 220 |
| `arch_tunnel_bore` | B | 156 |
| `arch_secret_alcove` | B | 68 |
| `arch_window` | C | 108 |

## Three decisions worth your eye

**The bore is a horseshoe, not a pipe.** A round tunnel would be a
different construction language from the facility and would have no floor.
Flat invert, springing to 1.20, twelve-segment crown.

**The catwalk is 1.60 wide, deliberately not `brute_lane` 2.60** — two body
widths, and something a brute cannot follow you onto. Its deck is at 2.60,
which is the height Batch 015's gallery and Batch 016's balcony already
use, so it lands level in either.

**The alcove is `_secret_alcove` to the letter** — slab top at the lip, the
non-colliding rail inset 0.06 from the inward edge, underside at 3.90
against a 2.75 minimum. `DESIGN` §19 permits *a plaque and nothing else* up
there, so a plaque is modelled and nothing else is.

## Still not built, and why

`arch_signage_mount` and `arch_objective_socket` stay **blocked** with the
navigation language. `arch_affordance_socket` is **deferred, not blocked** —
the seven affordances it mounts are approved, so it has a contract and just
was not in scope here. `arch_vista_socket` has no contract at all.

Status: **PENDING**. Not self-marked.
