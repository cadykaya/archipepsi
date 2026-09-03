# The two launch pads

**Arty** · art lane · branch `claude/archipepsi-art` · 2026-09-03

| | |
| --- | --- |
| Art head before | `d5f7e17` |
| Rooms touched | `shell_hall_transit`, `shell_span_basin` |
| What moved | two `launch_source` positions, and nothing else |
| Review states | all four Wave 1 rooms remain `review: "pending"` |

**The ruling:** *keep the hall and span launches, but move their pads just
enough to eliminate the little 8 cm collision.* Both launches are intact
— same targets, same landings, same radii, same routes. Both pads moved.

---

## First, a correction to my own number

I described these as an **8 cm** clip, and that is the depth at the point
where the body **first** touches. It is not the worst of it. Measured
across the whole flight, swept as a capsule:

| room | first contact | deepest |
| --- | --- | --- |
| hall | 0.08 m into `hl_east_gantry` | **0.643 m** |
| span | 0.08 m into `sp_deck` | **0.806 m** |

So the flights did not graze those platforms — they went **through**
them, and 8 cm was only where they entered. The repair is the same one
either way, and the ruling stands unchanged; the number in the previous
report was just the wrong one to quote.

---

## Why neither could be fixed by a smaller move

`LaunchSolver` puts the apex 3.5 m over the higher end, so **an arc's
shape is fixed by its two heights alone.** The plan positions decide
where the arc *is* at a given moment, never *when* it is there. That
single fact rules out most of the cheap answers:

* the body straddles the hall's gantry slab between **37 % and 45 %** of
  the flight, and the span's deck slab between **27 % and 38 %**,
  wherever the pads sit;
* so the pad cannot dodge either platform by sliding along the axis it
  is already travelling.

**Hall.** The pad sat at x = 12, one metre off the east gantry's west
edge (x 13–19) and inside its z range, aimed at the gantry's top. Going
south instead would mean z ≤ 3.7 — a **14 m** move, because the gantry
runs z 16–38. West is 2.20 m. West wins.

**Span.** The pad sat at x = 0, **directly beneath a 7 m deck**, aimed at
the top of that same deck. The deck runs the full 90 m, so no z helps at
all; the only fix is to come out from under it. At 38 % of the flight the
arc is 62 % of the way in from the pad, which puts the least |x| that
clears the deck edge plus a body radius at **6.5 m**. It goes west,
because east is where `cover_1` is — the 3 × 5 m block at (8, 44) starts
at x 6.5, and a body does not fit between it and the deck.

## How far "just enough" actually is

Two numbers per room, and they are not the same number:

| | stops touching | clears by a rail's margin |
| --- | --- | --- |
| hall | x = 9.8 — moved **2.20 m**, +0.010 m | x = 9.0 — moved **3.00 m**, **+0.363 m** |
| span | x = −6.5 — moved **6.52 m**, +0.108 m | x = −7.0 — moved **7.02 m**, **+0.329 m** |

I took the second column. **A 1 cm margin is the same coin toss in a
different place** — it is the kind of number that flips on a rebuild, and
"eliminate the collision" should mean eliminated. 0.325 m is what a rail
beam is already required to keep in this pack (half its thickness plus
`RAIL_MARGIN`), and both of these are the nearest **round metre** that
holds a flying body to the same standard. The extra cost over the bare
minimum is 0.80 m in the hall and 0.50 m in the span.

| | was | now | moved | in-flight clearance |
| --- | --- | --- | --- | --- |
| `shell_hall_transit` / `launch_basin` | `12.0, 0.0, 18.0` | **`9.0, 0.0, 18.0`** | 3.00 m | **+0.363 m** |
| `shell_span_basin` / `launch_basin` | `0.0, 0.5, 45.0` | **`−7.0, 0.0, 45.0`** | 7.02 m | **+0.329 m** |

The span's pad also came **down to y = 0**. It was floating half a metre
over the basin — neither a stance nor a surface, and the same untruth the
plenum's pad had before this week. A launch source is a foot-contact
point like the landing it aims at. The hall's pad has always been on its
basin's face and the plenum's is now, so all three agree.

Launch spans: hall 24.53 → **25.18 m**, span 23.29 → **23.85 m**. Both
well inside `MAX_RANGE`.

## What this does to the two rooms

Better, I think, in both cases — which is worth saying because it was not
the goal.

The hall's launch now leaves from open basin rather than from underneath
the walkway it is aiming for, so the gantry reads as a thing you are
thrown **over** instead of a ceiling you are somehow going to get on top
of. The span's leaves from beside the bridge rather than under it, which
is the only version of that jump that a player could look at and believe.

Nothing else in either room changed: no geometry, no traversal, no
surfaces, no sockets, no rails, no grapples, no `.glb`, no `.tscn`.

---

## The ledger is empty again

`measure_offers.RAISED` carried these two for one day. Both are repaired,
so both lines are gone — **a ledger nobody empties is a list of things
nobody is going to fix.**

The mechanism stays, and stays tested. Its five negative controls used to
run against the two standing findings; they now run against one the suite
**synthesises**, by putting the span's old pad back in memory:

```
sabotage-offers: the raised ledger, against a real finding
  the shipped ledger is empty                            clean
  an unlisted finding is refused                         caught
  the same finding, listed exactly, is excused           clean
  a ledger entry blaming the wrong collider              caught
  a ledger entry for an offer that is fine               caught
  a ledger entry whose offer no longer exists            caught
```

Both directions are proved now, which they were not before: a listed
finding **is** excused, and an unlisted one is **not**. Nothing is
written to the tree — the manifest is patched in memory, because a script
that `git checkout`s a generated manifest can eat an export somebody has
not committed.

---

## Verification

```
[offer] shell_hall_transit   71 colliders, 0 non-convex
    rail_helix       ok       launch_basin  ok  apex 24.5 m, flight 1.97 s
[offer] shell_span_basin     54 colliders, 0 non-convex
    rail_underdeck   ok       launch_basin  ok  apex 17.5 m, flight 1.75 s
[offer] 24 offer(s) measured against real collision, 0 refused, 0 raised
```

| check | result |
| --- | --- |
| `tools/check_art_current.sh` | **PASS** — every generated asset rebuilds byte-identical |
| `check_docs_metrics.py` | **PASS — 245 / 245** |
| `verify_manifest.py` (Production's `ContentManifest`) | **PASS** — declared handoff, no other drift |
| `content_registry.gd` (Production's) | **PASS** |
| `verify_collision.gd` | 12 shells, **0 needing attention** |
| Scene / manifest marker parity | **PASS** — 160 markers, 12 scenes, 0 disagreements |
| Flight surfaces, 0.10 m grid | 19 flights, **0 refused** |
| `measure_offers.py` | **PASS** — 24 offers, 0 refused, **0 raised** |
| `replay_audited.py` | **PASS** — 12 audited findings all still found |
| `sabotage_offers.py` | **PASS** — 17 of 17 negative controls behaved |
| `preflight_shells.py` | **0 structural refusals** |
| `diff_shell_glb.py` vs `d5f7e17` | **all 23 shells byte-identical** |

An offer is a declaration, so no mesh moved: every shell `.glb` in the
pack is byte-identical to yesterday's, this time including the plenum's.

---

## One thing raised, and it is a question rather than a finding

A `launch_source` carries `radius: 3.0`, and I do not know what
Production does with it. If the solver runs from the **declared point**,
both pads are correct as measured. If it runs from **wherever inside that
disc the player actually stands**, then no pad in either room is fully
safe without a much larger move: the hall would need its centre at
x ≤ 6.8 (5.2 m) and the span at x = −9.5 (9.5 m) for the whole disc to
fly clean.

I have not paid that on a guess. It is a question about what the field
means, and the answer belongs to Production; if the disc is what matters,
say so and both pads move again in one line each.

---

## Standing state

* All four Wave 1 rooms remain `review: "pending"`. Art does not write `pass`.
* The approved P2 catalogue, the played Zone and the digest are unchanged.
* **Wave 2 has not started.**
* Previous report: `docs/art/reports/2026-09-03-physical-truth-repair.md`,
  whose "raised and not repaired" section this supersedes.
