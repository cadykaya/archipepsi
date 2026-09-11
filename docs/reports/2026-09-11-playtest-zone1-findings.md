# Playtest findings — Zone 1, `none` movement package

**Played:** 2026-09-11, Skyah, start to portal, 15/15 Checks.
**Game code and assets:** `96c450e8ba91ec012fb1e2ce44d269a67a14bf53` (the
revision Vera audited). Nothing in this report changed the build that was
played; it is documentation only.
**Zone:** `zone_001`, id `a9e649315285bdf3`, 23 chambers, the ordinarily
generated offline-provider Zone described in `docs/PLAYTEST_3AB_HANDOFF.md`.
`shell_span_basin` at `c006` plus six authored corner shells.

Every claim below is measured against the source at that revision or
computed from the stored Zone, not inferred from the screenshots. Where a
finding is a design ask rather than a defect it is marked **ask**.

---

## 1. Blockers — a base-kit run ends here

### B-1. A `back` gallery buries the room's own exit doorway

`c015` is a 23.7 × 10.1 × 4.6 arena with
`elevation: {kind: gallery, rise: 1.86, coverage: 0.30, side: "back"}`.

`band_rect` (`chamber_builders.gd:123`) takes `band, width, depth` and **no
door position**. For `side: "back"` it returns a deck spanning the full room
width at z ∈ [7.07, 10.10] — flush against the back wall. The deck is a
0.4 m slab centred at `rise - 0.2`, so it occupies **y ∈ [1.46, 1.86]**.

The exit door is cut in that same wall, centred on x = 0, sill at y = 0:
the arena calls `_perimeter` (`chamber_builders.gd:1172`) with `exit_gap_y`
left at its `0.0` default. Only the tower ever raises a sill.

The player capsule is 1.8 m tall (`PLAYER_HEIGHT`), and there is no crouch.

| route | clearance | short by |
|---|---|---|
| under the deck | 1.46 m | 0.34 m |
| on the deck, under the lintel (3.2 − 1.86) | 1.34 m | 0.46 m |

The deck is 3.03 m deep, so it is a tunnel, not a lip to vault. **`c015`
has no walking exit.** The playtester left on Teleport.

Per `CLAUDE.md` and `SOLUTIONS_CATALOGUE.md` §0-bis this is a solvability
break, not a polish note: a physical gate that the matching AP location
logic does not declare.

**Why nothing caught it.** The audit that would is real and correct —
`_openings_are_holes` (`room_audit.gd:323`) sweeps the player's own capsule
through the exit plane and would fail this room. It was never handed the
shape:

- `room_contract_driver.gd:341` — gallery, `side: "left"`.
- `room_contract_driver.gd:346` — `side: "back"`, but a **pit**. A pit digs
  down; it does not put a slab across the doorway.
- `room_contract_driver.gd:743` — `"side": ["left", "right", "back"][i % 3]`,
  inside `if i % 3 == 0:`. **`i % 3` is always 0 there**, so all sixteen
  rooms get `"left"` and the other two entries are unreachable. That test
  also only checks the reward pedestal, not doorway passability.

`gallery` + `back` — the one combination that buries an exit — is built by
nothing in the suite.

### B-2. The pit softlock

Recorded during the run and unchanged from the earlier analysis:
`_elevation_band` builds a pit's access ramp at the same `ramp_at` as a
gallery's and only flips its facing (`turn += PI`), so the ramp sits
*outside* the recess it is supposed to serve, and the recess is built with
three walls rather than four. Nothing audits escape from a pit.

---

## 2. Structural findings

### S-1. Epsilon cannot place anything

The full field list of `ArenaChamber`:

```
activities, additional_reward_location_ids, depth, elevation, enemies,
features, flavor, id, intent, objective, reward_location_id,
shell_id, size_class, type, wall_height, width
```

No positions. `EnemyGroup` is `{archetype, count}`. An activity is
`{kind, element_count, time_limit, ordered, requires}`. `zone_builder.gd:4`
states the boundary outright: *"Epsilon never chooses world coordinates;
this file owns them."*

So Epsilon can say "four ranged enemies and three targets" and can never
say *where*, *near what*, or *in relation to which*. The playtester's
reaction — "the point of Epsilon is that he can intentionally place
things" — is a boundary finding, not an Epsilon failure. **Intentional
composition is not expressible in the schema.**

### S-2. Prop placement is a fixed lattice, identical in every arena

`chamber_builders.gd:1286-1299`:

| thing | position, for every arena |
|---|---|
| barrels (`reactive`) | exactly 2, at `(±0.32·w, 0, 0.28·d)` |
| cover | up to 4, at `(±0.32·w, 0, 0.52·d)` and `(±0.32·w, 0, 0.76·d)` |
| enemies | a ring: `(cos(2πi/8)·0.3w, 0.2, 0.5·d + sin(2πi/8)·0.3d)` |

Not random — **the same six points and one ring in every room, scaled by
the room's size.** This is the mechanism behind "everything feels randomly
placed": it is worse than random, it is uniform.

**The barrel and the enemy formulas never see each other.** Barrels are
pinned at depth fraction 0.28; the enemy ring is centred at 0.50. Nothing
checks proximity. Combined with the barrel's own falloff —
`DAMAGE * (1.0 - reach / RADIUS)`, `DAMAGE = 34.0`, `RADIUS = 4.5`, linear
to zero — a barrel one-shots a 24 hp melee only within **1.32 m**. In
`c018` the nearest an enemy can possibly be is ≈3.25 m, which is **9.4
damage**: less than two Static Pulse shots. Barrels cannot kill anything,
by construction, in every procedurally generated arena.

### S-3. There is no enemy perception

`enemy.gd:302-306` is the whole of awareness:

```gdscript
var aggro := Constants.ENEMY_AGGRO_RADIUS   # 18.0
        * (1.0 - 0.5 * player.statuses.magnitude_of("low_profile"))
if distance <= aggro:
    _has_noticed = true
    look_at(player)
```

- **Line of sight is not checked.** `_has_line_of_sight()` is used only at
  line 368, to gate *firing*. Walls, crates, cover and the gallery deck
  hide nothing.
- **`_has_noticed` is a latch that is never cleared.** No de-aggro, no
  memory decay, no leash. An enemy that has noticed you follows forever,
  including out of the room it was composed for.
- The only stealth surface that exists is a `low_profile` status halving
  the radius to 9 m.

18 m is larger than the rooms. Fraction of each arena's floor already
inside an enemy's notice radius, given where the ring puts them:

| room | size | enemies | floor watched |
|---|---|---|---|
| c002 | 13.8 × 15.8 | 5 | 100% |
| c005 | 19.3 × 17.0 | 2 | 100% |
| c009 | 15.6 × 20.4 | 1 | 100% |
| c011 | 12.4 × 21.5 | 5 | 100% |
| c014 | 26.0 × 24.0 | 8 | 100% |
| c015 | 23.7 × 10.1 | 2 | 99.9% |
| c018 | 17.9 × 14.7 | 4 | 100% |
| c020 | 18.2 × 20.4 | 4 | 100% |
| c023 | 18.4 × 18.3 | 3 | 100% |
| **c006** | 30.4 × 89.2 | 1 | **26.7%** |

Nine of ten arenas: **nowhere to stand unseen, before entry.** There is no
approach and no opening move. The one room with anywhere to hide is the
89 m authored shell — the room the playtester liked.

### S-4. Enemy power never scales; player power does

`enemy.gd:86` is `enemy.max_hp = float(block["hp"])`, a direct read of
`ENEMY_STATS`. Nothing multiplies it by zone index, progression or check
count. A melee enemy in Zone 1 and in Zone 40 are the same 24 hp.

| | damage | melee 24 hp | ranged 16 hp | brute 120 hp |
|---|---|---|---|---|
| Static Pulse | 6.0 | 4 shots | 3 | 20 |
| Echo (reference) | 12.0 | 2 | 2 | 10 |

Every `UPGRADE` raises the Echo. The reward for clearing the room the
playtester had just called too easy was Spear of Justice **Mk 4** — the
only thing that can happen, since nothing on the other side moves.

Two further points:

- **`mk` is an edit counter, not a power tier.** `mechanics.py:89`: *"Mk I
  on creation, +1 per upgrade or modify that touched it — and on a MERGE
  the survivor ADDS the absorbed component's Mk to its own."* The number
  that reads as a power level carries no power information.
- **Three of ten declared enemy roles exist.** `ENEMY_ROLES` lists ten;
  `ENEMY_STATS` has three. `charger, bulwark, scuttler, artillery, beacon,
  diver, drifter` have physical envelopes and no behaviour. Silhouettes are
  0.8 × 1.6, 0.7 × 1.4, 1.8 × 2.6 — two small boxes and one big box.

### S-5. Connectors are a collision spacer, not level grammar

`_search` (`zone_builder.gd:182`) returns `{"connectors": 0}` on its first
iteration. Connectors are emitted **only** to push a room clear of an
overlap. When a room fits straight ahead — the normal case — zero are
emitted and the two rooms butt directly.

An arena's `exit_offset` is `(0, 0, depth)` (`chamber_builders.gd:1325`)
and its entry offset is zero, so room B's origin lands on room A's back
wall plane. Room A's back wall is a 0.4 m box centred at `z = depth`;
room B's front wall is a 0.4 m box centred at `z = 0`. **Two boxes in one
box's space, coincident faces** — the z-fighting reported throughout the
run, worst in the 6 × 6 corner shells where it fills the view. Both carve
the same centred 2.4 × 3.2 doorway, so it remains walkable.

It also means an 18 m aggro sphere reaches through the shared wall into the
previous room: **a fight cannot be contained in the room it was composed
for.**

### S-6. Room height is rolled independently of floor area

`fallback.py:613`: `wall_height = round(rng.uniform(4.5, 7.0), 1)`, rolled
separately from width and depth. Player reach standing plus a full jump is
3.13 m (`PLAYER_HEIGHT` 1.8 + max jump 1.333).

| room | w × d | ceiling | span : height | clear above a full jump |
|---|---|---|---|---|
| c015 | 23.7 × 10.1 | 4.6 | **5.2 : 1** | 1.47 m |
| c009 | 15.6 × 20.4 | 4.6 | 4.4 : 1 | 1.47 m |
| c002 | 13.8 × 15.8 | 4.9 | 3.2 : 1 | 1.77 m |
| c014 | 26.0 × 24.0 | 7.0 | 3.7 : 1 | 3.87 m |
| c006 | 30.4 × 89.2 | 23.6 | 3.8 : 1 | 20.5 m |

Corridors are a flat 3.6 m with a 3.2 m door, so the ceiling never changes
walking room → corridor → room. Gallery decks rise 1.64–2.19 m under 4.6 m
ceilings: standing on the gallery you cannot jump. Reported as
claustrophobia; the cause is that **height is not a function of span**.

### S-7. The content budget is blind to a room growing

`c006` is `shell_span_basin` at 30.4 × 89.2 × 23.6 — **2712 m²** — holding
`kill_all` with **one melee enemy**, two `target_challenge` activities and
one Check. The shell declares five `enemy_high` stances (y ≈ 7.3 and 14.3)
and three `cover` sockets, all unused; the cover sits on the basin floor at
y = 0.3 while the five elevated stances stay empty, so the shell's cover is
laid out for a fight nobody staffed.

Cause: the content budget is per-Zone and was computed for the small arena
the generator proposed. Adoption changes the room's size and not its
contents, and `room_value`'s space term caps at `MAX_SPACE_VALUE = 12` and
is then clamped by content — structurally unable to notice the room grew.

The shell's two declared basin→deck routes (`basin_south_to_deck`,
`basin_north_to_deck`, a 14 m climb, `kind: walk`) are `mandatory: False`.
The only mandatory routes are flat walks along the deck, so **nothing ever
verifies the climb** — which is why the stairs are unwalkable and no test
minds.

### S-8. Activities are single-chamber, and the chamber can be a corner

`c016` is `shell_corner_right`, **6.0 × 6.0 m**, carrying a `timed_run`
with `element_count` 4. A START→GOAL race entirely inside a corner piece.
Three chambers in this Zone are wholly empty (`c010`, `c013`, `c019` — all
6 × 6 corner shells with no Check, activity, enemy or feature), and the
connectors between them are not chambers and can never hold anything, so a
run of them is guaranteed dead space.

### S-9 … S-15. Confirmed, lower severity

- **No activity timer exists anywhere**, and `timed_run` clocks are derived
  at the most forgiving legal value.
- **No completion feedback**: finishing a `switch_sequence` or
  `target_challenge` produces nothing the player can perceive.
- **The exit hard-locks on 100%.** `exit_portal.gd:3`: *"Locked until every
  assigned Check confirms."* A forgotten Check holds the Zone shut rather
  than costing a reward — which, with B-1, is what forced a Teleport
  backtrack through an impassable room.
- **The Echo archive is one flat list.** `inventory.gd` is 295 lines: one
  `ScrollContainer` → one `VBoxContainer` → one row per Echo in fold order.
  No tabs, filter, sort or search. `_add_provenance_rows` prints the entire
  Mk chain on every row, so each row grows taller as the fold grows and the
  scroll cost rises faster than the collection does.
- **Zones are strictly one-way** (`zone_index = record.generation_index + 1`),
  so nothing can be deferred and returned to.
- **There is no physics.** Zero `RigidBody3D` in the project. Every crate,
  prop and barrel is a `StaticBody`; `ReactiveBarrel` damages and never
  moves.
- **Cosmetic, confirmed:** walls not meeting the floor; a Check pedestal
  reading as floating; repeating-texture moiré on long walls; rooms darker
  than intended; ceiling lights blown out.
- **Not a bug:** the garbled Hub headline. `hub.gd:353` is
  `_garble(headline, static_units)` — corruption proportional to Static
  delivered, by design.

---

## 3. Asks (new work, recorded not scheduled)

- **ask** Enemy tiering: stats that scale with progression, more of the ten
  declared roles implemented, distinct silhouettes per tier.
- **ask** Enemy perception: line of sight, an alert state, memory that
  decays, a leash — explicitly *dumber than omniscient*.
- **ask** Stealth as a player option rather than a status effect.
- **ask** Physics props — pushable, throwable, destructible; barrels
  included. Half-Life / Portal grade. Nothing exists to build on.
- **ask** A carry / throw verb, programmed but off by default so Epsilon
  can enable it when the player earns it.
- **ask** Multi-room activities, so a START→GOAL is a route and not a
  straight line.
- **ask** Let a Zone close at the exit without 100%, and make reaching the
  exit a Check in its own right.
- **ask** Hidden Checks. The mechanism half-exists: `SECRET_GROUP :=
  "secret_alcove"`, Echo-gated, roughly one `platform_path` in three.
  `chamber_builders.gd:806` forbids a secret from holding *"a reward, an
  exit or an objective"* — correct for a **Godot-side** alcove, which
  Archipelago never hears about. But `SOLUTIONS_CATALOGUE.md` §0-bis
  (superseded by owner direction, 2026-08-29) permits a required Check, a
  local key or **the Zone exit itself** behind a hard Echo gate provided
  the AP logic declares the same prerequisite and the capability is
  provably obtainable. **Hidden Checks are already permitted; nothing
  currently emits a declared gated Check.** The missing piece is the
  declared path, not permission.

---

## 4. Corrections to earlier reports of mine

**"Content byte-identical" and "content unchanged" were offered as evidence
that shell adoption was correct. They are the opposite.** S-7 is exactly
that property observed from the other side: preserving a small room's
contents inside a 2712 m² room is the defect, not the proof. The relevant
lines are corrected in place in
`docs/reports/2026-09-10-playtest3b-authored-composition.md` §9 (A4) and
`docs/reports/2026-09-11-3ab-integration.md` §8.

Two miscalls made live during the run, recorded so they are not repeated:

- I called a white wall an untextured-material bug. It is a
  `switch_sequence` element. The real finding was the absence of completion
  feedback, not the material.
- I first framed scenery-versus-interactive as having no contrast. There
  **is** a rule — flat saturated colour is interactive, textured is
  scenery, and orange is reserved for things that genuinely hurt you
  (`reactive_barrel.gd:35`, per the 2026-08-28 ruling). The finding is that
  a real rule is not legible, which is a different fix.

---

## 5. The shape these share

Most of section 1 and 2 is one recurring defect, already named twice in
this repository and now a third time:

**A measurement exists, is correct, and is never handed the case that
fails it.**

`_openings_are_holes` would refuse `c015`; no fixture builds a `back`
gallery. The pit escape is never audited. The `mandatory: False` climb in
`c006` is never walked. `room_value` cannot see a room grow. The barrel
lattice and the enemy ring are each individually defensible and never
compared.

The companion shape, also third-time: **the builder knows physical facts
the composer does not** — and the composer is the one being asked to make
the room interesting.
