# Optional bosses / minibosses — AUDIT ONLY

**Status: ACCEPTED — BUILD NOTHING** (owner, 2026-08-29). The finding stands
as a recorded dependency: **the missing piece is a telegraph vocabulary, not
a body.**

**No boss roster built. No boss designed.** The brief is explicit that this
is an audit and that no boss work happens until Production defines the
gameplay contract. This records whether the pieces that exist could plausibly
host one, and what would be missing.

## Can the existing arenas host an elite encounter?

**Yes, and the numbers say so rather than an opinion.**

`ZONE_MAX_CHAMBERS = 40` with `ROOMS_PER_BUDGET_POINT = 15/1000`, and the
engine comment is direct about the old six-room cap: *"it stopped a 1000-point
Zone from existing at all."* So a large Zone is now allowed to be a level.

The Batch 015–019 room shells are `PASS` and include arena, tower and
platform-path families. An arena that can hold the approved encounter
vocabulary can hold a harder version of it — **an elite encounter is a
difficulty and composition problem before it is an art problem.**

## Can the landmarks host one?

**Better than the arenas can, and that was not designed for.** Batch 023's
six places were built as *places* — a hero structure plus the architecture
that makes it somewhere you were: a ground route, a route above it, something
to look down from, something visible you cannot reach.

That is, incidentally, the exact anatomy of an arena for a large encounter.
`lm_drop_test_hall` (loop around a central void), `lm_process_tower` (spiral
up a leaning mass) and `lm_bell_breach` (three levels, one event) each already
provide multi-level engagement with sightlines between the levels.

**They are PENDING, so this is a note and not a plan.**

## Can the ten enemy roles host one?

**Partly, and the honest answer is the interesting one.**

- **Scale.** `brute` at 1.8 × 2.6 × 1.8 m is the largest approved envelope.
  `EnemyEnvelope.__post_init__` clamps every dimension to **0.1–6.0 m**, so
  the schema already permits something considerably larger than a brute
  without any contract change. An elite at 4 m would validate today.
- **Composition.** With Batch 037's surface rule, an elite could read as *an
  existing role, up-armoured* rather than a new species — which is the
  cheapest possible way to add an elite tier and the most legible.
- **The blocker is not art.** `ENEMY_ARCHETYPES` exposes three roles
  (requirement 31). A boss tier built on top of a roster that cannot spawn
  seven of its ten members would be building the second floor first.

## Does the visual scale language support it?

**Yes.** `art_budgets.json` runs `enemy` 700 → `hero` 1200 → `landmark` 2500,
so a tier above `enemy` already exists in the budget table. The ten roles use
132–268 triangles, which is **under 40% of the `enemy` tier** — an elite has
substantial headroom without touching any ceiling.

## The dependency, recorded

> **If an elite / miniboss tier is wanted, the missing piece is a
> TELEGRAPH VOCABULARY, not a body.**

`enemy.gd` already publishes `telegraph_started(kind, duration)`,
`telegraph_finished(kind, completed)` and `telegraph_progress()`, and Batch
030 gave every role a reserved telegraph seat at its collider centre. What
does not exist is any **authored telegraph** — nothing is drawn for any
`kind`, and no `kind` vocabulary is defined.

An ordinary enemy can be fought without one. An elite that is *"reachable now
but extremely difficult with the current build"* — the brief's own framing —
cannot: an encounter you are meant to lose to and come back for has to be
losable *fairly*, and fairness at that difficulty is carried almost entirely
by telegraphs.

So the dependency chain is:

```
telegraph KINDS defined (Production)
    -> authored telegraph vocabulary (art, and it is a real batch)
        -> elite / miniboss visual tier
```

**Recorded as a dependency, not started.** Art is not defining telegraph
kinds, and no boss work should begin before Production has.
