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
- *(Corrected 2026-09-12.)* This entry claimed `_has_noticed` was a latch
  that never clears and that an enemy therefore **follows forever**. That
  is a misreading. `_has_noticed` guards only `_say("aggro")` — the
  notification — and the pursuit itself sits inside `if distance <=
  aggro`, so it is distance-conditioned and stops when the player is out
  of range. What remains true is the radius: **18 m with no line-of-sight
  test**, which is wider than the rooms. Pursuit leaking into the
  previous room follows from the radius reaching through a shared wall
  (S-5), not from a latch.
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

- **Activity completion is built, and was not perceived.** *Corrected
  2026-09-12: the two claims that stood here — "no activity timer exists
  anywhere" and "no completion feedback" — are false against the played
  source.* `activity_runtime.gd` carries `time_limit` (92), sets it as a
  live clock (`_clock = time_limit`, 256 and 363), appends `"   %.0fs"`
  to the prompt the HUD shows (178), says `DONE` on completion (332),
  sends a `grant_local_reward` intent keyed `activity_<id>` (339) and
  emits `completed` (345). **The finding is the gap, not the absence:**
  the player ran four activities to completion and perceived no clock and
  no completion. Something between that code and the screen does not
  arrive, and it is still unexplained — the mechanism existing is not
  evidence that it reaches the player. Open, and needing its own
  investigation.
- **`timed_run` clocks are derived at the most forgiving legal value.**
  Unchanged, and separate from the above.
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
- **Cosmetic, confirmed:** a Check pedestal reading as floating;
  repeating-texture moiré on long walls; rooms darker than intended;
  ceiling lights blown out. *"Walls not meeting the floor" is removed from
  this list: it was a real defect, not a cosmetic one — a recess is lined
  on the faces where it met another lining and left open where it met a
  room wall, because `_perimeter` builds walls from y = 0 upward and a
  recess goes down. Fixed; see §6.*
- **The checkpoint is not pre-art.** *Corrected 2026-09-12.* An earlier
  framing of this report described the build as untextured primitives.
  `godot/content/shells/` holds **12 authored shell scenes and 44
  textures**, and the played Zone instantiated seven of those shells. The
  images in the handoff package are test-harness renders from
  2026-08-30 and are **not** screenshots of the played session.
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

- **ask** Make the Hub's multiworld board a destination map you can shoot
  for information and travel through. Three builds, and the third needs an
  owner ruling:
  1. The cells have **no collider** — `hub.gd:455` builds each as
     `b._box(root, ..., null, false)` and `_box`'s last parameter is
     `collide := true`. A hitscan passes through the panel.
  2. **A cell is not a world.** `hub.gd:594`: *"One cell per BUCKET of
     Checks."* At 450 locations over ~30 cells one square is 15 of the
     player's own Checks, tinted by state, labelled with whichever game
     owns the first location in the bucket. It is titled THE MULTIWORLD
     and looks exactly like a departure board, so it is read as a map of
     places — a legibility defect on its own terms, whatever is decided
     about travel.
  3. **Nothing in the protocol carries a destination.**
     `handle_request_next_zone(finale: bool)` takes one boolean;
     `_select_zone_locations` (`campaign.py:360`) walks `save.track_order`
     from `save.track_cursor` and takes the first track with anything
     eligible. Round-robin, player never consulted. Replacing that scan
     with a player choice is small; keeping Archipelago's guarantee that
     progression stays obtainable while the player picks the order is the
     part that is a campaign-structure decision, not an implementation
     one. Related: this is the constructive form of the one-way-Zone
     finding — a board that picks destinations is what lets a deferred
     Check be returned to.

- **ask, major** Rooms with more than one entrance and one exit:
  T-connectors, several exits from a large room, branches that rejoin, and
  progression-locked entry points. Owner's words: *"its a major change but
  I think its deserved."* What assumes exactly two doors:
  - **The chamber contract.** Every builder returns one `exit_offset` and
    reads one `entry_offset`, and all **twelve** authored shells declare
    exactly two doorway sockets named `entry` and `exit`.
  - **The Zone schema has no edges.** `Zone` carries `chambers` as a list
    and the list order *is* the topology. A graph needs edges as data:
    schema bump, save migration, baseline regeneration.
  - **`ZoneBuilder`'s safety depends on being a chain.** Its header: *"turns
    alternate direction (no U-shapes by construction)"*. Reconnection is
    exactly what that rule forbids. `_all_but_last` — the exemption
    letting a room touch the connector it joins — stops being correct once
    a room legitimately joins two pieces. A cursor walk becomes a frontier
    of open doorways plus a solver that can branch, fail and backtrack,
    and the current generator already needs a 96-connector escape hatch to
    chain large rooms in a line.
  - **Every audit probes two doors.** `_openings_are_holes` tests "the
    entry" and "the exit". N doors need N probes, plus a rule for which
    branch is mandatory and whether an optional branch may dead-end.

  **Two versions of the gating, very different cost.** `SOLUTIONS_CATALOGUE.md`
  §2 **Zone-local keys** are not items — no location id, never scouted,
  never sent, do not survive the Zone; *"a lock state on generated
  geometry, exactly like `objective: kill_all`"* — validated by three
  rules (a key reachable without passing its own lock, an acyclic key
  graph, every gate declared in the AP logic), and the packet's verdict is
  that it *"does not touch Archipelago at all ... it buys metroidvania
  structure inside a Zone with zero multiworld risk."* **Unimplemented:
  `zone.py` has no key field.** The other version, §0-bis Echo-capability
  gates across Zones, is permitted but carries the AP-logic obligation.

  **Recommended sequence: topology first, then local keys as the proving
  layer, and the capability gates last.** Open question for the owner,
  needed before a solver is written rather than after: **must a branch
  rejoin, or may it dead-end?** Rejoining gives BRC-style freedom and is a
  much stronger constraint; dead-ends give Zelda side-rooms and are far
  easier to solve.

### Owner rulings, 2026-09-11, on the multi-door change

Given in answer to the four questions above. Recorded as decisions, not
proposals.

1. **A branch may dead-end, but every dead-end carries a return.** A
   catalogue of authored "dead-end plugs" — a non-euclidean door, a
   disintegrate/rematerialise pad, a tube that fades to black — and
   **Epsilon picks which.** Destination is the Zone start **or the last
   big room**, also Epsilon's choice. Both are *declared anchors*, not
   coordinates, so the composer still names no world position and the
   authored-alphabet boundary holds without special pleading.
2. **Checks are not all mandatory**, and Epsilon should compose against
   the distinction: a Check at the end of a branch, behind a plug; a
   branch that leads to content the player must return for later.
   **Correction applied to the ask:** the trap/filler/progression
   classification is Archipelago's truth and Epsilon must never *choose*
   it. It already *reads* it — `constants.py:707` defines
   `FLAG_PROGRESSION` / `FLAG_USEFUL` / `FLAG_TRAP`, and both
   `RequestLocation` (`epsilon/requests.py:121`) and `EchoSource` (`:219`)
   already carry `item_flags`. So the ask is composition against a flag
   that is already delivered, not a new authority.
3. **Plug destination is Epsilon's**, per 1.
4. **The shell declares doorway capacity; the composer declares usage.** A
   five-door shell may be used as a three-door room by walling two off, or
   by locking one behind a key. Same shape as `adopt` / `offered_for` from
   3A/3B, and it removes the need to author a 2-, 3- and 4-door variant of
   every room.

**Also asked for:** warp stations at the entrance, the exit and large
rooms — save, return to Hub, and warp between stations already reached in
the same Zone; optionally starting broken and repaired by completing one
of the existing activities, which is the first real consequence anything
has proposed for `switch_sequence` / `pressure_routing` /
`target_challenge`.

**How much of that exists.** `handle_leave_zone` is already
*"Pause-menu Return to Hub. No persistent change; Godot resets transient
state itself."* Mid-Zone Hub return is therefore already non-destructive —
claimed Checks survive; the destructive intent is `handle_abandon_zone`,
which returns unclaimed Checks to the pool. The only missing piece is the
**resume point**: Godot discards the player's position. A station is a
persisted set of stations reached plus a spawn anchor, not a new
subsystem.

**One thing to get right when this is built.** `_openings_are_holes`
reports a blocked doorway as a defect. For a **declared-walled** door it
must invert and confirm the door *is* sealed — the same measurement with
the opposite expected answer, and the difference must come from the
declaration. The tempting shortcut is to skip the opening check for walled
doors, which would be a fourth instance of §5's recurring shape. It has to
be checked harder, not skipped.

**Open, and it sets the first build's scope:** is the locked door's key a
Zone-local key (zero Archipelago risk, fully specified in
`SOLUTIONS_CATALOGUE.md` §2) or an Echo capability (§0-bis, every gate
mirrored in AP location logic)?

**New defect found while checking the above.** `Epsilon Static` is
declared `ItemClassification.filler` (`apworld/archipepsi/__init__.py:53`)
while functionally being a trap — it permanently corrupts the Hub. AP
offers `ItemClassification.trap` and Archipepsi uses it nowhere, so other
players' hint and trap-filtering logic reads Archipepsi's Static as
harmless filler.

---

## 6. Repairs landed, 2026-09-12

Bounded to escape. No graph work, no enemy changes, no Amalgam.

### Fixed, with the played Zone's own chambers as the regression input

`_test_the_played_zone_rooms_can_be_left_on_foot` builds `c015` and `c005`
from the chamber dictionaries the generator produced on 2026-09-11 and
floods the standable surface with **walking only** — no jump, no offer, no
Teleport — so anything it reaches is reachable by the base kit alone.

| | before | after |
|---|---|---|
| `c015` entry → exit | no route | **reached, 526 cells** |
| `c005` entry → exit | reached (around the pit) | reached, 728 cells |
| `c005` **pit floor** → exit | no route | **reached, 728 cells** |

Four defects, all in `_elevation_band` / `band_rect`, and all invisible
for one reason: **no fixture in the suite ever built a `back` band.**
`room_contract_driver.gd:743` rolls `["left","right","back"][i % 3]`
inside `if i % 3 == 0`, so `i % 3` is always 0 and two entries of that
array are unreachable.

1. **A `back` band sat on the room's own exit.** `band_rect` takes a width
   and a depth and no door position, and "back" is the wall the exit is
   cut into. A gallery laid its deck over the doorway; a pit took the
   floor away in front of it. Both now leave a `BAND_DOOR_MARGIN` walkway
   at the exit wall, at room level.
2. **A `back` band spanned the full width**, so it was a wall across the
   room whichever kind it was — a deck you had to climb, or a moat you
   fell into and could not leave on the far side, a band having exactly
   one ramp which returns you to the side you came from. `back` bands now
   leave a lane, as `left` and `right` always have.
3. **A pit's ramp was built outside the recess it serves.** Only the
   FACING was flipped for a pit; the position stayed on the gallery's
   side of the band edge, which put the only way out beyond the pit's own
   wall. This is the `c005` softlock.
4. **A `back` band's ramp climbed away from its own deck.** The quarter
   turn was `-PI/2` where the deck is at `+Z` of the ramp, so the ramp
   rose to a 1.86 m step at its foot and descended into nothing at its
   head.

Two smaller repairs fell out of the above and are load-bearing for the
escape:

- **The deck's trim lip ran across the top of the ramp.** It is 0.35 m of
  solid trim along the deck's inner edge, and the ramp arrives at that
  same edge. There is **no step-up anywhere in `player.gd`** —
  `move_and_slide` does not climb, and `MAX_VERTICAL_STEP` is a constant
  validation reasons with rather than one the body implements — so a
  0.35 m kerb stops a walking player dead. The lip now has a gap where
  the ramp lands. The same gap is cut in a pit's lining, for the same
  reason.
- **A recess was open to the void** on any face where it met a room wall
  rather than another lining, because `_perimeter` builds from y = 0
  upward and a recess goes down. All four faces are lined now. This is
  the "missing wall" from the playtest.

Each repair was reverted individually and the suite confirmed to go red
on that revert alone, so none of them is decoration.

### One defect in the prober, recorded because it is the same shape

The first version of the escape flood dropped its rays from **above the
room**, hit the ceiling first, read every column as one flat surface, and
**passed both rooms it was written to catch.** The second version tested
`abs(Δheight) <= MAX_VERTICAL_STEP`, which forbids walking *off* a ledge
and made every raised deck a one-way trap in the measurement and nowhere
else. Climbing is limited; descending is free. Both are fixed, and both
are the finding of §5 committed by the repair for it.

### Not fixed here: the Span stairs — an Art repair request

`shell_span_basin`, routes `basin_south_to_deck` and `basin_north_to_deck`
(`kind: walk`, `mandatory: false`). Measured against the built scene by
dropping rays along the declared line at x = 11.9:

- Both stairs run **uniform 0.875 m risers** on ~0.9 m treads, from 0.88 m
  up to **11.37 m** (south) and **11.38 m** (north).
- The deck is at **14.00 m**.
- **The final step is 2.63 m** — at z ≈ 14.62 south, z ≈ 75.40 north. It
  exceeds `MAX_VERTICAL_STEP` (1.0) and also the base-kit jump apex
  (1.333 m), so it cannot be climbed at all without an Echo.

The collider is the authored shell's own merged mesh, not anything the
composer placed, so this is **Art's to repair, not this task's**. The
request is in `docs/art-requests/2026-09-12-span-basin-stairs.md`.

Note the earlier report said the stairs were unverified because the routes
are `mandatory: false`. That is exactly right and now has a line number:
`shell_validator.gd:110` is `if not mandatory: return out`, which returns
after the endpoint-drift check and before the step where `TraversalLaw`
proves a declared `walk` has ground along its whole length.
`room_audit.gd:455` skips non-mandatory segments too. **Promoting that
check is deliberately NOT done in this task**: it would land a red suite
on an Art defect this lane may not fix. It should follow the stair repair.

### Still open from the playtest

- Activity completion is built and was not perceived (§S-9, corrected).
- The 0.875 m risers are within the declared walkable step and still
  require a jump each, because the controller has no step-up. That is a
  movement question, not a geometry one, and is untouched here.
- Everything in §2 and §3 that is not an escape repair.

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
