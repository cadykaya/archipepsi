# Archipepsi — build state

## Where this is
**The full v0.7 POC (Phases 0–7) is complete and green**, and the build has
moved on to making it good to actually play. Everything below "What works"
is post-POC.

Proof the loop is real:
- `make godot-integration` plays the **entire campaign** headlessly through
  the live WebSocket bridge: 12 zones, tier unlocks, shop purchases with
  the double-buy refused (Test O), leave/resume (Test I), the finale,
  postgame (Test N), `ALL_CHECKS_CLEARED`, 26 foreign checks → 26 Echoes,
  nothing lost or duplicated. It also builds the Hub and checks its board.
- `python3 -m archipepsi_bridge.smoke_real` proves the same core loop plus
  **Test L** (kill the bridge at the loading screen; the GENERATED zone
  revives with its committed allocation) against a **real Archipelago
  0.6.7 server**.
- 229 pytest (125 of them the packet's own schema suite) + the
  headless chamber-geometry and blink-invariant suites.

## What works
- APWorld: `make seed` / `seed-multi` / `host` / `apworld` (official build
  component, manifest validated).
- Bridge: `make bridge` (real AP) / `make bridge-mock`; providers
  claude/mock/fallback behind validate → repair-once → fallback, with the
  generation archive and `make replay` to re-validate it (EPSILON_SPEC §14).
- Game: menu, Hub (8 modes, campaign board, shop, Echo terminal, abandon
  console, Static corruption + screen fuzz), 5 chamber builders with
  bending layouts, 3 enemies with distinct silhouettes, 10 Echo effects,
  reveal cards, zone title cards, inventory, pause, F3 overlay,
  procedural textures/audio.

## Latest session: P2 prep — ready to accept the eight shells

Engineering and integration prep only. **No authored room landed.** Art's
`cab2512` is a source-side audit (`docs/art/P2_SHELL_PREP.md`); its
exporter has not run, so no `ContentEntry` manifest for the eight
candidates exists yet. P3 is not started.

### A. The Check/cover collision, fixed generically

P1 found it: `reward_position` was a fixed point on an arena's centre
line, the room's cover boxes were scattered independently, and
`ZoneController` places `RewardObject` at that anchor with no clearance
test. 2 of 4 arenas buried a Check.

Three changes, all in the direction ROOM GRAMMAR v0 and P1 established:

- **The room decides where its Checks go before it scatters anything**,
  and declares that space as a `reserved` region. Declaring rather than
  merely avoiding is what makes it true for the composer as well —
  nothing reads `reward_position`, so an activity element or a barrel
  could have stood on the pedestal and no rule anywhere would have
  objected.
- **The band is built first.** A `back` gallery at 0.41 coverage reaches
  z = 0.59..1.0 of the room and its access ramp reaches most of the
  rest, and the anchor sat in both. `_elevation_band` already DECLARES
  its deck and its ramp as `reserved`, so the anchor is chosen against
  what the band said rather than against a second derivation of where
  the band is — the first attempt re-derived `band_rect` and missed the
  ramp entirely, which is the mistake this project keeps paying for.
- **Props take the nearest free spot to the one they rolled.** Rolling
  alternates was the obvious fix and the wrong one: it moves the rng
  stream, so every prop in every unconflicted room would have shifted
  too. One roll then a deterministic sweep leaves those rooms
  byte-identical. Cover is not deleted near a Check; it is placed where
  a Check is not.

Two regression tests, both on the assembled path: 16 arenas of varying
size, half with bands, each measured where the pedestal will really
stand; and `make godot-zone-audit` now measures all 15 Check pedestals
of the real Zone, reading the same `reward_location_id` and
`REWARD_SPACING` the controller reads. Sabotage: disabling the prop
sweep gives 3 suite failures and 1 real-Zone failure; disabling the
anchor's band-avoidance gives 1 real-Zone failure.

Real-Zone effect: 15 of 15 Checks now clear (2 were buried), and one
activity element gained a blocked sightline where a prop moved — a NOTE,
not a failure, and a good trade for two unreachable Checks.

### B. `exit_yaw`

`ContentEntry.exit_yaw`, restricted to `{-90, 0, +90}` and refused
otherwise. `ZoneBuilder` walks a cursor and a yaw, and its overlap
guard, its connector grammar and its never-revisit proof are all written
for quarter turns; an arbitrary angle is the topology slice's problem,
not a corner shell's. 180 is absent on purpose — a room that exits back
the way it came walks the chain into its own previous arm.

Mirrored in `content_registry.gd` and `room_contract.gd`, emitted by
`_from_authored_scene`, consumed by `ZoneBuilder` **after** the room is
placed and overlap-guarded, so the room is still measured at the yaw it
was built for and the turn only steers what comes next. Absent or 0 is
straight through. Proven by building a two-room Zone through
`ZoneBuilder.build` and measuring the second room's yaw.

**The sign is Art's and was expensive.** `ZoneBuilder` rotates by
`Basis(Vector3.UP, yaw)` and ADDS the turn, so a shell leaving through
its +X wall turns the chain +90 and is the LEFT corner. An earlier
version of the art builders had the two names swapped and it was caught
by a render disagreeing with its own caption. It is written down in
`P2_SHELL_PREP.md` and must not be re-derived.

### C. `floors=4`

`ContentEntry.fits_floors` names the tower floor counts a shell was
BUILT for; empty means the shell does not depend on the parameter. A
shell that does not fit is not used, and the permanent procedural
builder makes the room. There is no arm anywhere that scales, retimes or
reinterprets a shell to make it fit — the only outcomes are "use it" and
"use the builder", and the fallback is the design rather than a
degradation.

`TOWER_MIN_FLOORS`/`TOWER_MAX_FLOORS` moved into `constants.py`, which
`TowerChamber`, the shell rule, the registry mirror and GDScript all
read. Art's tower sidecars already carry `floors`, so `fits_floors` is
mechanical for the exporter.

### D. Size and intent — one owner call remains

No thresholds were invented, and the study says not to invent them:
§4's own line is *"do not lock exact metre bands until the prototype's
playtest; the capacity column, not the metre column, is the contract."*

Production does not need thresholds to SELECT: `size_class` matches by
string between what Epsilon asks for and what a shell declares. What it
cannot do today is police the label — nothing checks that a 6 × 6 corner
calling itself `large` is capable of what `large` certifies.

A structural test now fences all three labels: `size_class` is read only
by the shell offer, `intent` is read by nothing, and `cost` never
reaches `room_value` (the engine recomputes a Zone's worth precisely so
a provider cannot declare it).

**THE OPEN CALL, and it is small:** which `size_class` do the three
families carry? Footprints are 6 × 6 (corners), 8 × 8 (treasure) and
12 × 12 (towers), and §4's bands are `small ≲ 10 m`, `medium ~10-20 m`,
`large ~20-28 m`. Reading the metre column gives corners and treasure
`small` and towers `medium`. Reading the CAPACITY column — which §4 says
is the contract — a corner hosts no encounter at all and a treasure room
hosts one reward moment, which is `small`; a 12 × 12 tower hosts a climb
and a couple of ranged stances, which is arguably either. **The one
thing Production cannot decide is whether `shell_tower_*` is `small` or
`medium`.** Everything else follows.

### E. Dead socket kinds

`spawn`, `objective`, `secret`, `vista` and `presentation` still have no
live room-contract consumer and `Volume` owns much of that space.
Untouched: none of the eight shells needs them. Recorded as deferred
cleanup for a slice that has a reason to open `content.py` anyway.

### What Art still owes before P2 can be declared complete

Their exporter has not run. `assets/models/batch018|019/shells/manifest.json`
are BUILD SIDECARS (`anchor`, `bounds`, `platform_anchors`, `stones`
inputs) — not `ContentEntry` manifests. No `surfaces`, no `sockets` in
the contract shape, no `review`, no `exit_yaw`, no `fits_floors`.

Everything those manifests need now exists on the Production side. The
remaining work is theirs, in `tools/blender/`, and their own §"what
becomes mechanical" lists it.

## Latest session: P1 — room contract parity + the geometric audit

The first slice of the adopted ROOM_ARCHITECTURE_STUDY hybrid (PR #7,
`a63220f`), approved P1-only. Contract and validator; **no content
conversion, no F3, no P2/P3.**

The asymmetry. `ChamberBuilders` and `_from_authored_scene` both answer
"build me this chamber", and until now the authored one answered with
strictly less truth: it returned **no `sockets` key at all**, so an
authored room had no cover points, no barrel points, no reserved
regions and no walkable surfaces, and `Activities` flat-solved against
its bounding box. That is exactly the defect `552469d` closed for
`platform_path`, sitting in the one path no Zone takes yet — and it
would have been found in a Zone the player was standing in.

**The contract** is not a new language; it is the dictionary both
producers already return, written down. `room_contract.gd` names the
required keys (`root`, `bounds`, `exit_offset`, `room_height`,
`enemy_spawns`, `reward_position`) and a CLOSED socket vocabulary —
`stand`, `reserved`, `cover`, `reactive`, `enemy_high`, `access` — each
tied to a consumer that runs today. Nothing speculative: a kind with no
consumer is a kind nobody can be held to. `traversal` is optional and
carries `TraversalSegment`'s own shape, so an authored jump and a
`platform_path` jump are measured by the same code against the same
`max_safe_gap`.

**The audit** (`room_audit.gd`) measures those claims with real probes:
support and headroom sampled across every declared surface; ground and
burial under every placement point; the player's capsule at every
arrival and in every doorway; endpoints, span and rise of every declared
traversal; and geometry that reaches outside the room's own bounds. It
REFUSES to report a clean sheet for a room outside the scene tree,
because a probe with nothing to hit comes back clean, and that is the
most dangerous possible pass.

Two probe designs were tried and dropped for stated reasons, both worth
carrying:

- A separate "reachable from above" ray, on the theory that the sealed
  pit was about lids. It was not: what makes a deck 1.66 m under a slab
  unwalkable is that a 1.8 m player does not fit. **The headroom ray IS
  the pit check**, and the extra one refused perfectly good mezzanines.
- `cast_motion` through a doorway, which quietly returns "travelled all
  of it" for a shape that starts clear and ends clear either side of a
  0.4 m jamb. Asking "does the player FIT here" has one answer.

And one real contract subtlety, found by a false positive: **`exit_offset`
is not the doorway.** It is where the next room's ORIGIN goes, which a
tower deliberately puts 2.2 m past its own back face. The audit probes
the room's +Z boundary instead. A tower's landing slab is also 0.5 m
thick and CENTRED on the height `exit_offset` names, so the probe finds
the floor by ray before standing on it.

**The suite** (`make godot-room-contract`, in CI) is ONE suite keyed to
the contract, run over seven procedural rooms and three authored
fixtures that carry the identical manifest — an honest room, one with a
slab over its declared balcony, one whose exit was modelled and never
cut. A per-producer suite proves that producer is self-consistent; this
project has watched that inherit-the-blind-spot failure three times.

**Schema**, mirrored into `content_registry.gd` in the same commit
because verifying one side of a two-sided contract is verifying nothing:
a `Surface` model and `ContentEntry.surfaces`; `Socket.kind` gains
`cover`/`reactive`/`enemy_high`, promoted from the runtime vocabulary
the builders already emit; `Socket.surface_id`. An authored room shell
declaring no surfaces is refused. A `procedural_fallback` entry is
exempt — it describes code that already knows where it laid the floor,
and the procedural route stays permanently legal.

`ShellValidator` also now keeps a promise `content.py` has made in prose
since S12 and nothing kept: measured mesh AABBs against the declared
`size` envelope. Rooms chain by butting declared envelopes together, so
a shell bigger than its manifest reaches into the next room — and the
overlap guard that would catch it is fed the very number being lied
about.

**Zero player-facing change, verified rather than asserted**:
`zone_digest 6e8d83d0f3ec088b` unchanged, the real-Zone audit unchanged
at 0 structural failures and 0 placement notes, and no committed
registry entry, Zone fixture or baseline touched.

**One defect the audit found and P1 does not fix.** An arena scatters
three "crude cover" boxes at random through the middle half of the room,
and `reward_position` is the fixed point `depth * 0.72` on the centre
line. Nothing has ever stopped one landing on the other, so a Check
pedestal can stand inside a crate — `zone_controller.gd:150` places
`RewardObject` at that anchor with no clearance test. Two of the four
arenas in the suite do it. Reported and PINNED so it cannot grow;
fixing it means moving props or the anchor, which is a player-facing
change and P1's acceptance forbids one.

## Latest session: ROOM GRAMMAR v0

The first approved slice of `docs/proposals/ROOM_FIRST_GAMEPLAY.md`. The
owner's finding after playing Zone 1 was not "the activity families are
weak" but "**the rooms are miserable**" — more stuff to do, none of it
doing anything. The measurement behind it: a room's entire shape was
three numbers (`width`, `depth`, `wall_height`), so 23 of 23 rooms were
rectangles and 28 of 41 ranged enemies had nowhere to be ranged from.
The flatness was the generator faithfully building everything the schema
could say.

What landed:

- **`ArenaChamber.elevation`** — an optional `ElevationBand`: `gallery`
  or `pit`, one per room, with bounded `rise` / `coverage` / `side` /
  `access`. A property an ORDINARY room may have, not a room type; the
  point is that verticality stops being the `platform_path` minigame.
  A schema validator refuses a gallery that leaves less than
  `HEADROOM` of clear air, and `HEADROOM` is public so the generator
  can ask before proposing rather than discovering it by failing.
- **The band as ordinary arena composition** — deck, lip, and a ramp
  whose run is three times its rise, so the angle is the same whatever
  the height and base movement always reaches the deck. That is NO
  REQUIREMENT BEFORE GUARANTEE applied to geometry.
- **Ranged enemies take the high ground.** Placement only; no AI change.
- **Two environmental objects with verbs.** `DestructibleCover` pays in
  SPACE, not loot — it removes itself, which is a real consequence that
  needs no economy and leaves the loot question open rather than
  answering it badly. `ReactiveBarrel` is hazard orange honestly spent
  and hurts the player too. Both reach `Damageable`, so every weapon
  including the permanent Static Pulse floor works on them, and a test
  reads their source to prove neither reaches for Archipelago truth.
- **The socket contract**, which is the load-bearing part: the builder
  emits points it VOUCHES for, and architecture that content must avoid
  is DECLARED as a `reserved` socket rather than inferred from size.

Everything that went wrong in the batch was one shape — the builder knew
a physical fact and nothing else did:

- The access ramp is 6.8 m long, past the threshold at which occupancy
  calls something architecture, so the way up became the one invisible
  obstacle in the room and two activity elements ended up inside it.
- Ground sockets were offered blind at six fixed points; three of six
  landed inside the room's own crates or inside a gallery's solid mass.
- **A pit was a sealed basement.** The recess was dug under an intact
  floor slab. The unit test passed — bounds dropped, sockets below zero,
  a ray from inside the recess found the deck — because nothing asked
  what a ray from ABOVE hits first. The test that missed it is called
  `_test_a_pit_is_a_hole_not_a_painted_floor`.

`ChamberBuilders.solid_boxes` is now the single derivation of "what is
solid in this room", called by the builder to vouch for its sockets and
by `ContentInstantiator` to place activities.

Measured on the deterministic seed and reported as found, not tuned: 5
of 23 chambers declare a band (4 galleries, 1 pit); `zone_digest` moved
`1bdf42f800c5637e` → `6e8d83d0f3ec088b`, 916 → 922 points. On the SAME
Zone, this batch's engine produces byte-identical audit results to the
pre-batch engine.

`ENVIRONMENT_OBJECT_VALUE` was written and then deleted. How many
objects a room can hold is a fact about its built geometry; Python
pricing it would be the same failure this batch spent its time fixing.

Deliberately NOT done, and still open: no loot economy (Coins are an
Archipelago item and cannot be minted locally), no side branches or
alcoves, no second band per room.

**Then one playtest-hygiene fix, on the same contract.** The
`platform_path` floating-element defect (`docs/ZONE_ACTIVITY_AUDIT.md`
§4) is closed rather than carried into the playtest. Root cause in one
sentence: the row solver reads a room's WIDTH and DEPTH, and a
`platform_path` has no floor across them — the space between its islands
is a kill pit and its bounds reach forty metres down, so 19 elements
across five rooms stood on nothing and 3 more were inside platform
geometry.

The fix reuses the socket contract rather than reconstructing platform
geometry anywhere: `platform_path` emits a `stand` socket for each
surface it builds — start ledge, each island, end ledge — with the
surface's top height and extent, and `Activities._row` places onto one
chosen surface per activity when a room offers them. One surface per
activity, because a routing circuit split across a jump course is a
circuit nobody can complete inside the hold window. Islands are excluded
by measurement, never by name: what is left beside an element on its
better axis must be at least `BRUTE_LANE`, and 2.5 m of mandatory route
over a kill pit cannot give that, so the day a builder makes a wide
island the wide island is usable.

Rooms offering no surfaces are untouched — the arena keeps the flat
solve. Proved rather than asserted: comparing recorded element positions
at `2699805` against after, all seven `platform_path` activities moved
and every one of the other twenty-two, including all five banded rooms,
is byte-identical. The audit is 0 structural failures and 0 placement
notes, and `no_ground_under` is now a structural failure rather than a
note — the point of writing a defect down is being able to promote its
check the day it closes.

## Post-POC work so far
- **Two adversarial review passes**, all findings fixed with regression
  tests. Notable: an externally-confirmed goal never set `goal_sent`;
  releasing a zone's last stuck location wedged reconcile; the tower's
  summit exit was sealed; the enemy sidestep tested post-slide velocity so
  it never fired.
- **Non-linear layouts**: 90° corners, alternating turns, exact rotated
  AABB overlap guards, forward-push clearance. 16-seed test across all
  themes including vertical chambers.
- **Mock Epsilon is a real designer** (six chamber shapes, boss rooms,
  authored notes). The fallback keeps its pinned §12.1 shape.
- **Readability**: objective waypoint (on-screen and edge-pinned with
  distance), zone progress, exit portal stating what holds it shut, damage
  direction wedge, Echo cooldown bar, campaign board showing all 30 Checks
  by tier tinted per recipient game.
- **Feel**: viewmodel with fire kick, hit punch, damage flash, footsteps,
  landing thump, room-tone hum, enemy damage tint, zone title cards.
- **Personality**: Epsilon graffiti, Static-garbled Hub board, Static-
  corrupted tracers, theme-signature props, designer notes surfaced.

## Latest session: playability pass (+ a third review)
- **Navigation**: objective waypoint (floats on target, pins to the screen
  edge as a chevron with distance), `CHECKS n/m CLAIMED`, exit portal
  stating what holds it shut. Zones bend now, so this is the readability
  the corner pieces owed.
- **Combat readability**: damage-direction wedge that tracks as you turn,
  Echo cooldown as a refilling bar, enemies that visibly cook toward
  death, distinct silhouettes per archetype (hunched charger / static
  tripod / heavy brute).
- **The multiworld, visible**: a campaign board on the Hub wall showing
  all 30 Checks in three rows of ten (the tier structure), each tinted by
  the game that receives its item — matching the bridge's sha256 theme
  rule exactly, pinned from both sides.
- **Presentation**: zone title cards with Epsilon's designer note and a
  featured-Echo credit, game-tinted reveal cards, muzzle flashes,
  footsteps, landing thumps, controls card, Epsilon narrating long
  generations.
- **Third adversarial review**, all findings fixed — several defeated the
  feature they were in (the title card printed "true"; the damage wedge
  never tracked; the waypoint chevron rendered off-screen; wounded
  enemies got dimmer; silhouettes clipped through doorways).

## Latest session: feel, voice, secrets — and a flaky-harness fix
- **Hit confirmation.** Everything on screen told you what the world was
  doing to you; nothing told you your own shot landed. A connect tints and
  punches the crosshair and ticks quietly; a kill stamps an X. All three
  attack paths report it, and `Enemy.take_damage` returns whether *this*
  hit was the fatal one, so shooting a sinking corpse never re-reports a
  kill.
- **Epsilon talks during play** — first kill, room genuinely cleared,
  portal unlock edge, low health, death, revival, and a long stretch with
  nothing claimed. Authored client-side like the graffiti: no line reads
  or reports any AP state. Throttled to one per six seconds, never
  repeating back to back, on its own row below the interact prompt.
- **Secrets** (DESIGN §19): about one arena in three grows a ledge whose
  lip is out of reach of the 1.33 m standing jump, holding one of
  Epsilon's private notes and nothing else. Reaching one earns a flourish
  and a line. The geometry test proves the exit, reward and enemy spawns
  are untouched, that no ledge overhangs a door lane, and that each has
  exactly one sensing (not blocking) trigger.
- **Harness fix — the integration run was not hermetic.** It started the
  bridge with no save-directory override, so every run resumed the one
  before it: the zone counter climbed past 50, "coins were genuinely
  spent" passed on an *earlier* run's coins, and the shop assertion failed
  at random. It now gets its own throwaway save dir. Also: an import pass
  before the headless runs (a `--script` run does not rescan for new
  `class_name` scripts), and a liveness check on the bridge (one left over
  from an earlier run holds the port, and the driver silently tests
  against the stale one).

## Echoes 2.0 — S1 landed
The Echo contract is v8. **No new mechanics**: v7 Echoes migrate and the
game plays the same campaign it did before.

- **`schemas/echo.py` v8.** An Echo is an *interpretation* carrying 1–4
  operations (`CREATE` / `UPGRADE` / `MODIFY` / `LINK` / `MERGE`) that
  contribute components: Action, Trait, Resource, Rule, Status, Affordance,
  Info. Only Actions occupy a slot. The 28-primitive catalog is closed;
  `IMPLEMENTED_PRIMITIVES` gates what the engine can honour today, so an
  Action it cannot run is rejected rather than accepted as an ability that
  silently does nothing. S2 widens that one tuple.
- **`schemas/mechanics.py` — the fold.** Live mechanics are a pure fold over
  the log in `interpretation_seq` order and are never persisted. Aliases
  resolve with path compression, a dangling target *raises* rather than
  being skipped, every upgrade revalidates the component it touched, and a
  `beam_sustained`/`hover`/`block` without a `powers` link is refused.
- **`schemas/migration.py`.** v7 → v8 at the dict level, before validation.
  Sequence follows the v7 save's own echo order, which is grant order.
- **`CampaignSave` folds in its validator**, so a corrupt log is
  unrepresentable rather than merely detected: a save that cannot fold
  cannot be written to disk.
- **The store migrates on load and writes back immediately** — a migration
  that only lives in memory runs again every load.
- **Proof:** a seven-shape v7 corpus that loads, folds, writes back and
  reloads identically (including grant-order-unlike-location-order); `make
  replay` accepting both archive versions; the fold benchmarked at
  **0.16 ms** on a full 26-echo campaign.

One behaviour change comes with the model rather than from a choice:
**traits are on because they are owned**, not because something is
equipped. A migrated save with several passive Echoes now has all of them
at once. The stack is clamped to the same two constants `max_safe_gap` was
derived from, which is what keeps every generated jump valid without
recomputing one.

## Echoes 2.0 — S1.1 and S2 landed

**S1.1** was an externally authored review patch (ChatGPT, GPT-5.6 Sol),
reviewed here against the packet and the running code. All three of its
changes hold up, and two closed holes S1 shipped: nothing gated operations,
component kinds, slots or modifiers (so a schema-valid Resource would
validate, persist and do nothing), and `reconcile()` iterated pending Checks
in claim order despite `ECHOES.md` §5 requiring location-id ascending. Two
corrections on top: the slot stopgap expires at **S7**, not S2, and the
packet copy of `migration.py` had silently diverged from the bridge copy —
`check_packet.py` now compares the schema directories and fails on any
difference.

**S2** opened the catalog from six verbs to **21 of 28**.

- **The other seven are staged, not forgotten.** `DEFERRED_PRIMITIVES` names
  each with the stage that lands it (S3 resources, S5 statuses, S9 local
  rewards), and the schema suite asserts the two tuples partition the
  catalog so a verb cannot vanish from both.
- **Three shapes of Action.** Press, held (`glide`, `charge_shot`), and
  scheduled (`burst_fire`). Cooldown is charged on the press either way;
  conditional verbs check their condition first, so an air dash on the
  ground costs nothing.
- **`blink` got its own suite** (`make godot-blink`, invariant I14): ~23k
  attempts across five builders × five themes. It found two real bugs
  immediately — landings a full body-length *under* the floor (350), and an
  ankle-height clearance probe that cleared bodies inside walls (100). Both
  fixed; it now reports 5125 resolved and 17825 refused with no violations.
- **The runner is checked against the schema across the language boundary.**
  `test_runner_coverage.py` reads `echo_runtime.gd` and asserts its match
  arms equal `IMPLEMENTED_PRIMITIVES` in both directions.
- **The fallback reaches 20 distinct outcomes** across a 30-Check campaign,
  up from about five — and a sword is a sword now rather than a six-metre
  hitscan. Still deterministic, still one `CREATE` per operation.
- **`make godot-import` fails on a parse error.** It is the only step that
  compiles every script, and a broken action runner printed `GODOT CHAMBER
  TESTS OK` while the game refused to load.

## Echoes 2.0 — S3 in progress (resources and the HUD channels)

**Landed and green** (241 pytest, chamber, blink, full integration):

- **A correction to S2.** `DEFERRED_PRIMITIVES` said `beam_sustained`,
  `hover`, `block` and `restore_resource` un-gate at S3. They do not: none
  of them names the resource it uses, `powers`/`fills` are LINK kinds, and
  links are S5. **S3 un-gates no verb on its own.** Fixed in the schema and
  the packet.
- **Channel assignment lives in the fold.** `Mechanics.channel_of()` and a
  serialized `channel_order` computed field, ordered by `interpretation_seq`
  and nothing else. Godot reads the order rather than re-deriving it.
- **Contextual budgets (§16).** `budget_errors()` counts campaign totals at
  grant time — the one rule that cannot be enforced per-interpretation. The
  hard resource budget and `HUD_CHANNELS` are the *same constant*, because a
  sixteenth resource would have nowhere to render. `over_soft_budget()`
  steers the request toward `UPGRADE`/`LINK`/`MERGE` first.
- **The fifteen pre-laid channels.** `ResourceMeters` builds all fifteen rows
  once and never reflows; `ResourcePalette` holds the safe light/dark pairs
  and the deterministic source glyph; `ResourcePool` holds current values,
  ticks regen/decay, and resets on Zone entry only (§22 — never saved).
- **The fallback makes real channels** (`magic`/`mana`, `stamina`/`vigor`),
  so the grant → fold → channel → snapshot → HUD path is exercised by the
  integration run rather than only by unit tests.

**S3 closed** (247 pytest, chamber, blink, hud, full integration). The six
remaining obligations all landed, and three of them found real bugs:

1. **`make godot-hud`** — a fourth Godot suite that boots the project the
   way blink does (the meters, pool and archive read the autoloads) and
   drives them off-tree at a fixed 1/60 step against a fold-derived
   fixture: create ← Ocarina, create ← Dark Souls, upgrade ← Dark Souls,
   so a two-entry provenance chain and a Mk II exist before any provider
   can produce one.
2. **The §7 pressure valve is proven**: a new channel opens expanded, a
   full untouched one collapses to the idle strip, spending expands it and
   not its neighbour, a refilled one stays open 2.5 s and closes, a
   partly-empty one never closes.
3. **The palette claim was FALSE and is now enforced**: `signal` sat 0.11
   from the confirmation cyan, `ember` 0.20 from danger amber. Values
   retuned (names are the contract and never moved); the suite floors
   every fill/dim at 0.30 from every reserved colour, fills 0.25 apart.
4. **The glyph rule was a packet deviation and is now ECHOES §12's**: the
   character sum was a second derivation where the packet says the sha256
   `prng_seed` rule is shared; replaced and pinned from both sides
   (`hud_driver.gd` glyphs, `test_hud_contract.py` indices).
5. **Provenance is in the archive**: concepts line, ECHOES §11 chains
   (Roman Mk, every AP item in order, §12 accent per row) on every
   interpretation that touched the component; chains of one stay silent.
   Rendering the fixture's upgrade exposed a `%+g` in `EffectSummary` that
   GDScript does not have — the arm had never run before.
6. **`over_soft_budget` stays off the request, recorded**: steering toward
   operations the capability gate refuses would manufacture repair loops;
   it joins the request when non-CREATE ops become implementable
   (`test_stage_tripwires.py` fails at that exact moment and says so).
   The same tripwire pattern covers `_is_cost_of_slotted_action`, dead by
   design until S5 links.

Cross-language contracts got their own net (`test_hud_contract.py`):
palette names ↔ `PALETTE_COLORS`, `ResourceMeters.CHANNELS` ↔
`HUD_CHANNELS`, glyph indices ↔ client pins.

## Echoes 2.0 — S4 landed (the rule engine)

The ECHOES §5 interpreter: EVENT → CONDITIONS → COST → EFFECTS, with the
§5.1 termination properties structural rather than aspirational. **The
first stage where a Resource gets spent.**

- **`rule_runtime.gd`**, driven by `make godot-rules` at a fixed 1/60
  against a fold-derived fixture (two resources, twenty rules — at the
  hard budget — and a merge whose alias a rule cost still references).
  I5 proven: an effect that fills a bar does not dispatch `resource_full`
  in the tick that filled it; next tick, once, edge not level; the
  fill-on-empty/drain-on-full pair oscillates at the cooldown rate; the
  per-tick cap skips rather than queues; costs are all-or-nothing with
  refund; conditions conjoin; aliases resolve to the survivor.
- **Derived events are per-rule edge latches.** The naive
  drop-if-cooling reading deadlocks the I5 oscillator after one cycle
  (the suite found it immediately); a queue would be the banned backlog.
  A crossing arms, cooldown delays, firing consumes, leaving the
  threshold unfired disarms. Recorded in IMPLEMENTATION_DECISIONS.
- **The fold validates rule references like I11**: a cost/condition/
  effect naming an unowned resource fails loudly at the rule's own
  sequence position, through merge aliases, re-checked after MODIFY.
- **Wired into play**: jump/land/dash_end/kill/damage/action/parry/
  check_claimed/zone_enter/chamber_enter (new chamber tracking with
  1 m hysteresis in ZoneController), plus tick_1hz and the three
  derived edges. Effects reach the pool, the player, the shield, the
  enemies group and the projectile layer.
- **The fallback grants real rules**: heal-hint items became a
  three-charge FLASK whose rule drinks one on the low_health edge;
  star/orb items became a kill-fed CELL that discharges itself into a
  shield at full — both deterministic foreign checks in the mock seed,
  so `make godot-integration` now asserts the campaign ends owning at
  least one folded resource AND one folded rule.
- **I8 proven**: a 16th-resource CREATE at the hard budget is rejected,
  the repair prompt carries the reason, a repaired answer is accepted;
  and the fallback itself now steps aside at the hard budgets (it takes
  the live fold), because a fallback that validation refuses is a
  RuntimeError by design.
- **Capability gates opened one kind**: `rule` joined
  IMPLEMENTED_COMPONENT_KINDS with per-piece gates for the §5 allowlists
  (statuses S5, trait_pulse S5, grant_local_reward S9), pinned against
  the interpreter's actual match arms both ways
  (`test_rules_contract.py`).

## Echoes 2.0 — S5 landed (traits, links, statuses)

The stage that makes a build a *graph*. `make godot-stats` is its suite.

- **The derived stat stack.** All nine trait stats compose, re-evaluated
  every physics frame because the inputs move: `scaled_by` (a resource,
  `hp_fraction`, or `hp_inverse` — Berserker with no special case), the
  `scales` link, `requires_equipped`, `trait_pulse`, and status factors.
  **I3** is a 300-round seeded sweep of random legal stacks: no
  combination leaves a traversal stat under base or any stat outside its
  envelope, with a vacuity guard that the sweep genuinely reached the
  floor.
- **The four links walk.** `powers` costs (strength on a press,
  `drain_per_second` while held), `fills` refills, `gates` withholds
  below a threshold (fractional at/below 1.0, absolute units above),
  `scales` interpolates a trait.
- **The last six verbs.** `beam_sustained`, `hover`, `block`,
  `restore_resource`, `scan_mark`, `cleanse`. Only `pull_pickup` is still
  deferred, waiting on S9's local rewards.
- **Statuses**, per target: max-merging containers, owned definitions as
  floors for their kind, worst-first cleanse. On the player they drive
  damage/knockback/aggro; on enemies they gate movement and attacks, and
  a marked target glows over its wounds.
- **I7 is enforced now**: an always-on trait whose harmful deviation
  exceeds a third of base must declare `requires_equipped`.
- **Two real bugs surfaced the instant links existed** — the S3 HUD
  relevance code read the link kind from a field the fold does not emit,
  and matched the `powers` direction backwards. That leg was unprovable
  before, which is exactly why it had a tripwire.

## Echoes 2.0 — S6 landed (dispositions)

The stage where items answer each other. `test_dispositions.py` is its
proof; the integration run is where you can see it.

- **The operation vocabulary is whole.** The gate admits `upgrade`,
  `modify` and `merge`. The fold has folded them since S1 — what was
  missing was permission, and a way for a wrong guess to be survivable.
- **`target_errors` at generation.** A disposition naming an unowned
  component is a validation error carrying the id, so the repair loop
  gets a chance; the fold's own refusal (I11) stays, because that is
  what makes a corrupt log unrepresentable. A test asserts they agree.
- **The request carries the owned graph**, including per-field upgrade
  headroom `(field, current, min, max)` read out of the models. The fold
  refuses an upgrade that leaves a declared range, so a provider without
  the range is guessing at the one number it must not guess at.
- **The fallback evolves.** Ancestry is semantic (§11): the family key is
  the verb for an action, the stat for a trait. *Hookshot → Longshot →
  Clawshot* is one grapple at Mk III, from the shipped fallback. The mock
  campaign ends with **7 components at Mk II or better** and a provenance
  chain **4 items long**.
- **I10 proven**: self-merge rejected, no reachable alias cycle, an
  absorbed id resolving straight through three merges, provenance unioned
  in sequence order, only resources merging.
- **§12 identity packages complete**: sound family (a pitch shift of the
  shared procedural bank — an Echo sounds like the world it came from)
  and particle style (tracer width and lifetime). Pinned from both sides;
  two worlds may share a family, and the test says so rather than
  claiming a uniqueness §12 never promises.

## Echoes 2.0 — S7 landed (slots and loadout)

Three of the four buttons were invisible before this. `make godot-stats`
covers it alongside I3.

- **Four slots, four runtimes, four keys** (RMB / MMB+F / Shift / C, per
  ECHOES §9). Cooldown, held state and airtime budgets belong to the
  Action, so each slot owns a runtime; a shared one would let a dash and
  a grapple contend for a single cooldown. The suite proves cooldowns,
  equipment and shields are per-slot and none is shared.
- **The S1.1 collapse is retired.** `ARCHETYPE_SLOT` put every migrated
  Echo on `echo_a` because one button was bound; its comment named S7 as
  the expiry. A migrated Hookshot goes back to Shift now, and the
  property the collapse protected is asserted directly: every archetype
  slot must be one a key reaches.
- **The HUD shows the whole loadout** — four rows, keycap, name, Mk
  level, the highlighted one marked — and the cooldown bar follows
  whichever slot you last fired.
- **The archive slots, compares and favourites.** Buttons name the key
  they land on (`TO SHIFT`, `REPLACE RMB`), show what you would be giving
  up right where the decision is made, and carry a star. Favourites are a
  **client preference**, not campaign state: the schema has no field for
  them because a favourite changes nothing mechanical, so they live in
  `user://loadout.cfg` beside the keybinds.
- **The wheel cycles favourites within the highlighted slot**, falling
  back to everything when fewer than two are marked — a wheel that cycles
  a single entry reads as broken rather than as unconfigured.
- **A caught bug worth naming**: the first runtime map used an `@onready`
  tree read and came back empty, which in production is a player with no
  working Echo buttons at all. The suite's per-slot check found it
  immediately; `create()` fills the map where it makes the nodes now.

## Echoes 2.0 — S8 landed (the Echo Lab)

A permanent Hub annexe where a new mechanic can be understood by touching
it (ECHOES §17). `make godot-lab` is its suite.

- **A room, not a mode.** You walk in through a doorway in the Hub's west
  wall and walk out the same way, which makes "base movement can always
  leave the Lab" structural — there is no transition to be stranded in,
  and nothing about entering goes near the bridge.
- **Six fixtures**: a dummy, a tall wall with height bands, a runway with
  distance ticks, a gap with a safe return, an armed hazard, a
  deterministic moving target — plus a reset pad.
- **The dummy cannot die**, and that is mechanical rather than
  convenient: since S4 a rule may fire on `kill`, and the fallback ships
  `kill → resource_add`, so a dying dummy would let you farm the economy
  in the Hub. It clamps, reports the damage, and never returns a kill.
- **Fixtures adapt, never copy.** The dummy answers `Enemy.take_damage`;
  the hazard calls `player.take_damage`. The suite proves the hazard used
  the real path by showing a shield absorbing it and a `damage_taken`
  trait doubling it.
- **The load-bearing property is a negative**: a full session of use
  sends no intent and leaves the interpretation log, fold, slots, Mk
  levels and checked locations byte-identical. Proven by fingerprinting
  both sides, and proven able to fail by making the Lab send one intent.

ChatGPT/GPT-5.6 Sol wrote the build brief for this stage in parallel; it
is cherry-picked at `docs/proposals/S8_ECHO_LAB_BUILD_BRIEF.md` and its
two sharpest traps (kill-farming, and the hazard bypassing the real
damage path) are both now assertions.

**Then: S9** — affordances and local rewards: the capability registry,
the generator grammar, the never-mandatory validator, the local-reward
catalog, Info readouts.

## Echoes 2.0 — S9 landed (affordances, local rewards, readouts)

The seven §13 tags are real geometry now, and the last deferred verb is
gone: `DEFERRED_PRIMITIVES` is empty, and every capability registry
equals its contract.

**The seven, and who pays for them.** `affordance_features.gd` builds a
grapple anchor with a reachable ledge, a breakable panel with a nook
behind it, a shallow pool, a grind rail, an updraft with a perch, a
bounce pad and a moving platform. `affordance_nodes.gd` holds the four
that do something: a `Volume` that hands the player an influence, a
`BreakablePanel` on `Enemy`'s own damage signature, a `BouncePad` and a
`MovingPlatform`. Each tag is paid for by an owned capability
(`owned_affordance_tags`), which now also honours a direct
`AffordanceComponent` grant — before this an Echo saying "you can grind
rails now" unlocked nothing.

**I4, twice.** The schema keeps features out of chambers holding a Check
and off gating objectives (a `Zone` model validator, so no provider can
emit one). The builder keeps them out of the walking lane, and refuses a
room too narrow to have a "beside the path" at all. The lane rule is
pinned from Python by reading the GDScript, the way the HUD palette is.

**I13.** Every feature hangs a `LocalRewardPickup`, never a
`RewardObject`. Collecting one sends `grant_local_reward` — an intent
with no field that could name AP truth — the bridge stamps the Zone and
records it idempotently, and the snapshot mirrors `local_rewards` back so
the client stops drawing what it already has.

**§14.1.** `readouts.gd` draws the ten readouts, each on only when the
fold says it is owned. It observes and never writes: damage numbers watch
enemy hp fall rather than taking a signal, and `resource_forecast` asks
`EchoRuntime.can_activate()` rather than attempting a press. The suite
freezes the world for twenty frames and asserts nothing moved and no
intent was sent — then hurts an enemy to prove the overlay was awake.

**Movement volumes.** A layer on the player applied after the stat stack,
not writes into it: `_refresh_derived_stats` rewrites every multiplier
each frame from the fold, so a volume writing there would be erased or
permanent by frame order. Nothing can trap you — upward-only lift,
capped drag, a hard speed floor.

**`make godot-affordance`** is the suite: a 2900-case sweep of the lane
rule, all seven built and checked for local rewards, the volumes,
the panel threshold, the platform's loop, pickup idempotence, and the
readouts' read-only promise. `make godot-test` had to become a booted run
in the same change — chambers now reach the player, which reaches
`BridgeClient`, and a `--script` run has no autoloads.

## Echoes 2.0 — S10 landed (the interpretation pipeline)

§15's chain is real now: `item -> concepts -> supported systems ->
validated recipe`.

**The reading.** `epsilon/concepts.py` is the deterministic reader — a
whole-word lexicon plus qualifiers, reproducing §15's own three worked
examples (*Water Tunic* → water/buoyancy/pressure/protection, *BLJ* →
backwards/momentum/acceleration/exploit, *Master Sword* →
blade/heroism/anti-evil/energy). A companion test asserts the prose still
uses those three items, because `check_packet.py` compares identifiers
rather than worked examples. The fallback reads every item; mock Epsilon
says the reading out loud in its description. Before this, both shipped an
empty concept tuple, so §15 was unexercised by every deterministic run
including the integration one.

**The mode is a fact, not a preference.** It is derived from what the
operations actually did and shown in the archive as "how Epsilon read it",
so it cannot be talked out of the truth: `mode_for_operations` takes no
creativity argument at all. §15's "influenced by Epsilon's creativity
setting" lives in the request as `preferred_modes`, steering like
`over_soft_budget`. The first draft made it a ceiling, and the reason that
is wrong is worth knowing: a ceiling has to either reject a good Echo or
relabel it, and relabelling makes the archive misdescribe the thing in the
player's hands.

**Validation has no taste.** `reading_errors` refuses exactly two things —
an empty reading, and one sharing no vocabulary with the item or its game
(concepts pasted from another Echo). Whether a reading is *good* is the
provider's job; a validator with an opinion would make every provider a
worse `read_concepts`.

**Budgets.** §16 is now counted in the units the prose states — which
matters for affordances, measured in **distinct tags**, because a tag is a
capability and two Echoes granting `rail` add one vocabulary rather than
two. Only seven tags exist, so that budget cannot fire today; a test says
so, and reports in if the catalog grows. The request carries
`budget_headroom` (`[owned, soft, hard]` per kind) and `relevance_hint`
(§15's "don't make it gun four", phrased against this campaign), and the
Claude prompt states the pipeline, the four modes and the budgets rather
than leaving them to be inferred.

The integration run ends with all 26 interpretations having read their
item, in four different modes.

## Adversarial review pass over S6–S10

Two passes, one on the client and one on the bridge. Everything below was
found, verified by running it, fixed, and sabotage-proven.

**The affordance geometry was built for a room that cannot exist.** Every
chamber type except a corridor carries a Check or a gating objective by
construction, and §13.2 bars features from both — so a corridor is the
only host there is: 5–10 m wide, 3.6 m to the ceiling. The first version
was written and tested against an 18×20 arena with a 6 m ceiling. Four of
the seven rewards sat above the corridor ceiling, the breakable wall's
alcove was outside the room behind masonry that is never removed, and the
suite passed because it built the arena too.

Reworked around per-tag footprints: the lane rule now applies to a
feature's whole extent rather than its origin (a pad whose centre cleared
the lane still put half its trigger inside it), width and depth
requirements are per tag on both sides of the language boundary, and a
corridor is **built to the height its features declare** instead of
features being clamped to whatever fits.

**An advertised upgrade bound the model would not honour.** The one
save-integrity bug: `TraitComponent.multiplier` is `ge=0.1, le=4.0` but a
gravity trait is capped at 1.0 by a model validator, so the request
invited the fallback to raise a trait at 0.9 by 0.15. Every validator
passed it and it failed inside `append_interpretation`, deterministically,
so the Check could never be granted and reconciliation aborted every time.
`upgradable_field_info` probes the model now; `target_errors` checks where
an upgrade lands.

**"Damageable" was a missing concept.** Every damage path tested
`is_in_group("enemies")`, so nothing in the game could deliver a point of
damage to the breakable wall and its `take_damage` was unreachable code.
The suite passed because it called `take_damage` directly; it fires the
real weapon now.

**Smaller, each real:** a concept validator that was wrong in both
directions (it passed `art`/`row`/`here` for every item, and refused the
readings §15 argues for) — deleted rather than tuned; a mode that called
self-contained Echoes "systemic", so the archive described an Echo that
touched nothing you owned; one affordance tag dropped from every Zone
forever, because the round-robin never rotated; the relevance hint missing
§15's own three-guns example, because it keyed on exact primitives;
claimed rewards respawning, because nothing read the snapshot's
`local_rewards`; and `pull_pickup` yanking a reward to the player without
taking it.

**One decision is deliberately not made.** `challenge_marker` and its
`challenge_timer` readout have a complete bridge half and no world half,
because §14 never says where a run starts or what ends it. A tripwire
names the decision.

**And the import guard now covers the test drivers** — `preload` rather
than runtime `load`, so `--import` walks them.

## Adversarial review pass over S1–S5

The staged reviews had covered S6–S10; these three passes covered the
parts that had never had one — the fold and the save on the Python side,
then the five client runtime engines (`rule_runtime.gd`, `stat_stack.gd`,
`status_effects.gd`, `echo_runtime.gd`, `resource_pool.gd`). Nineteen
findings, all fixed and all sabotage-proven, in four commits. The
reasoning behind each is in `docs/IMPLEMENTATION_DECISIONS.md`; this is
what changed.

**Two were campaign-destroying, and neither was reachable from any
existing test.**

*A legal v7 save destroyed the campaign it migrated.* v7 allowed a passive
that made you slower (`SPEED_MULT_MIN` 0.9); v8 traits are always on and
stack, so `_traversal_stats_may_only_help` forbids `move_speed` below 1.0
outright. The migration copied the multiplier straight across, so a save
holding one legal v7 Echo — anything that read as "heavy" — produced a v8
save the models refuse. The refusal was not the damage: `load_save` caught
it, tried the `.bak` (the same v7 file, failing identically), and returned
None; the engine reads None as "no campaign here", built a fresh empty one,
and the next write moved the player's real save into the `.bak` slot.
Fixed in three places — `traversal_multiplier` clamps into v8's floor
while keeping the Echo, `SaveUnreadable` stops "unreadable" being spelled
the same way as "absent", and the write path now COPIES the backup rather
than renaming it aside (a crash between the two renames left no primary at
all) while healing the primary after any non-primary recovery.
`test_save_survival.py`.

*A merge left every link pointing at the component it deleted.* The fold
rewrites aliases, components, provenance, Mk and channel order on a MERGE —
and never touched `links`. `echo_runtime.gd::_powers_link` says in as many
words that the ids it receives are canonical, and `_pay_powers_cost`,
`_apply_fills`, `_gates_open` and `stat_stack`'s `scales` dictionary all
take that at face value. A bar that no longer exists reads as 0 of 0, so
the spend always refuses, the gate never opens, the fill writes into
nothing and the scale pins at zero: the Echo stops working for the rest of
the campaign, silently, because aliases are permanent. `_relink` rewrites
both endpoints at merge time. That exposed a second contract nothing
enforced — `powers` and `scales` are read as at-most-one-per-target by
both clients, so a second edge was not combined but discarded by fold
order; `_require_singular_links` makes it unrepresentable, and
`target_errors` catches it a step earlier so a provider gets a repair
prompt rather than a crash. `test_merge_links.py`.

**`target_errors` waved through five refusals the fold then raised on.**
MODIFY had only an existence check; MERGE never asked where `max_value`
landed, and `capacity` **defaults** to `"sum"`, which makes that the
likeliest of the five rather than the rarest. A `FoldError` inside
`append_interpretation` is a crash, not a rejection — no `reconcile()`
call site has a handler — and it repeated on every retry, so the Check
could never be granted. `modify_is_legal` and `merge_capacity_is_legal`
apply the real operation to a copy and report, the way `upgrade_is_legal`
already did. `test_target_landing.py`.

**Ten in the press/release lifecycle and the pool.** `release()` fired a
`charge_shot` from a key-up with no press behind it (no cooldown, no gate,
no cost — one bolt per tap while cooling). `_refund_press` gave back only
the cooldown, so a refused press kept its `powers` cost, still paid its
`fills` link and still emitted `action_used`, which made refused presses
net resource GENERATION. Death ended no hold — `_cancel_held_state`'s
docstring said "on a slot change and on death" and had exactly one caller.
A slot swap stranded a hover, which is an I3 bypass, because
`hover_gravity_scale` multiplies in after `clamp_stat` where the stat
stack never sees it and `Hover.gravity_multiplier` goes to 0.0. And the
rule engine's pay-then-refund cost path re-armed `regen_delay` on every
failed attempt, sixty times a second on an armed edge event, stopping
regeneration dead on a rule that never fired once. New suite:
`make godot-verbs`.

**Six in statuses, latches, parries and shields.** A magnitude could
outlive the duration it came with (the two dimensions were maxed
independently). `cleanse` was ranked as if aimed at an enemy and could
strip the player's own `low_profile` stealth. `apply` had no vocabulary
guard, so a typo produced a status that was inert, uncleansable, and still
satisfied `status_active` and `status_applied`. Edge latches were computed
per event KIND across every resource, so an unrelated full bar kept one
alive — and none of it reset on Zone entry, though I9 resets everything it
is derived from. A burn tick spent the parry window and emitted `parried`,
which `main.gd` turns into a free `parry_success` event. An absorbed
shield froze its timer, and `grant_shield` takes the max, so a rule's
one-second shield lasted thirty.

**And the per-tick firing cap starved the same rules forever**, because
`_rules` is in a fixed fold order: with ten rules on one event and a cap of
eight, the last two never fired once. The scan rotates now.

Two pieces of infrastructure came out of it. `make godot-verbs` boots a
real player over a real floor and drives the four real runtimes. And both
GDScript fixtures now have generators in the tree (`make rules-fixture`,
`make verbs-fixture`) with a bridge test that regenerates in memory and
compares — the rule snapshot claimed to be "a REAL fold on the Python
side" and was, but its generator was scratch tooling that had not survived,
leaving a generated artifact with no source. Its every channel had
`regen_per_second` 0, which is exactly why its all-or-nothing cost test
could not see the refund bug.

## The disposition vocabulary, and the campaign soak

Two findings that came out of building the soak rather than out of a
review, and one is the more interesting kind of gap.

**Two of the four dispositions were unreachable in play.** S6 completed
`UPGRADE` / `MODIFY` / `LINK` / `MERGE` in the capability registry, in
`target_errors` and in the fold — and then nothing emitted half of them.
No provider in the tree produced a `MODIFY` or a `MERGE`, so ECHOES §3's
own two examples (*Fire Flower* making the gun's hits apply `burning`,
*Blue Estus* folded into the `mp` economy) were shapes a unit test could
construct and a player could never receive. That is worse than a missing
feature: a bug anywhere in either path was invisible to every integration
run, and the merge-link bug fixed the same morning is precisely that —
no amount of playing could have found it.

The fallback now answers all four, trying the most specific claim first:

- **sequel** (`UPGRADE`) — the campaign already owns the item's verb. Was
  already there, from S6.
- **enhancement** (`MODIFY`) — the item READS as an element and something
  owned can be hit with. The status comes from the §15 concept reader
  (`fire` → `burning`, `cold` → `slowed`, `electricity` → `shocked`,
  `decay` → `poisoned`), so the disposition is derived from the reading
  rather than pattern-matched on the item name.
- **confluence** (`CREATE` + `MERGE`) — the resource budget is spent,
  which is §16's "over soft budget, ask for MERGE" written down. The new
  economy is folded into an existing one, so the item is credited in its
  provenance and the fifteen HUD channels do not fill with flasks.

Each returns `None` when it cannot land, so the ordinary `CREATE` survives
and none of them can emit an interpretation the fold refuses. What "cannot
land" means has to be visible in the REQUEST, which is why
`OwnedComponentSummary` gained `modifiers` alongside `upgradable`: a
`MODIFY` adding a modifier must not duplicate a type and must not be the
third one, and a provider that cannot see the target's existing two is
guessing at exactly the thing it will be refused for. The confluence
checks the survivor's `max_value` headroom for the same reason (capacity
`"sum"` re-validates rather than clamping), and checks there is room under
§2's four-operation ceiling, since the merge is appended.

That append is what makes it work on a multi-op shape, and it is a nice
demonstration of the morning's fix: the fallback's resource outcome is
`create action + create resource + link powers`, so the link names the bar
the merge is about to absorb, and the fold rewrites both endpoints onto
the survivor. Before `_relink` it would have named a deleted component and
the Action could never have been activated again.

Five words the concept lexicon should always have had — `ember`, `ash`,
`venom`, `poison`, `spark`. *Ember* is a real item in a real game and it
read as an inert "artifact"; with it, `MODIFY` occurs in ordinary mock
play rather than only under a crafted request.

**`test_campaign_soak.py` — 25 whole campaigns, 25 different seeds.**
`make godot-integration` plays the campaign once, and always with the same
seed, because `MockAPBackend` hard-coded `"MockSeed"`. The seed is the only
input to three different orderings — the track order the Hub offers, the
shop's stock draw, and the allocator's shuffle — so one seed exercised one
path through all three. Nothing here needs Godot, so twenty-five full
playthroughs cost 23 seconds, and each asserts what must hold of EVERY
campaign rather than of a lucky one: the goal is reached and reported
exactly once, no location is held by two live Zones, no Check is claimed
twice, no location yields two Echoes, the allocator never starves (§11.5),
the save validates after every single transition, and the fold publishes
no edge naming a component it deleted. One test asserts the vocabulary
above is not theoretical.

## Mock Epsilon, and the other half of S10

`EPSILON_SPEC` §12.2 ends with an obligation that was scheduled and never
discharged: *"The **mock** provider is the one that must grow:
`--epsilon=mock` has to exercise resources, rules, links, merges and the
wider action catalog, or the headless integration run stops proving
anything about the systems S2–S6 add. That growth is scheduled as part of
S10."*

Mock did not grow. It delegated its whole echo to `fallback_echo` and added
narration — its own docstring said so: *"Mock Epsilon does not invent
mechanics the fallback cannot."*

Measured across ten full campaigns, the shipped providers reached **8 of
the 28 action primitives, one of the four link kinds, and no Info readout
at all**. Which means:

- `make godot-blink` fires ~23,000 attempts at `blink`, a verb no campaign
  grants.
- The hover, beam and block holds proved by `make godot-verbs` cover
  presses no player can perform.
- All ten §14.1 readouts are drawn and tested, and every one is turned on
  by an `info` component that nothing in the tree emitted.
- `gates` and `scales` handling in `echo_runtime.gd` and `stat_stack.gd` is
  dead code in play.

Mock now selects a shape from the **§15 reading** rather than from the item
name — `beam` gives a beam and the charge it burns, `revelation` gives a
radar, `momentum` gives a trait that rides a bar, `authority` gives a burst
behind a `gates` threshold — and falls through to the fallback for an item
it has no shape for. The fallback stays the floor deliberately: everything
it does is proved by its own tests, and falling through is what keeps an
item mock cannot read from being an item mock gets wrong.

Each shape is self-contained: it creates every component it names, so a
link can never dangle, and the three `POWERED_PRIMITIVES` are finally
expressible — the fold REFUSES a beam, hover or block with no `powers`
link, so only a multi-operation shape can carry one, which is exactly what
the fallback's pinned shape could not do. The `scales` shape emits the
LINK rather than the trait's `scaled_by` field: `stat_stack.gd` reads both
and only the field had a producer.

The concept reader was never the limit — **the item roster was**. Ten
names cycled across twenty-one fill slots, so a campaign saw ten distinct
readings. Widened to exactly twenty-one, every name one the reader already
understood; none was chosen and then taught to the lexicon, which would be
bending §15's reader to fit a fixture (the mistake the S6–S10 review caught
in the concept-attachment validator). *Metal Cap* and *Fresh Rep* stay
where they are: `integration_driver.gd` counts on their collisions with the
fixture's *Wing Cap* and *REP* to force evolutions.

A mock campaign now reaches **all four link kinds, real Info readouts, and
16 of the 28 primitives**. `test_mock_catalog.py` holds two levels,
because they fail differently: every ROW of the shape table must
individually fold (a row that cannot is a row that silently never fires,
and the pipeline would repair or fall back and the campaign would look
fine), and a real CAMPAIGN must reach the systems (a table nothing selects
from is the same gap in a new place).

**The contract prose was stale in two directions.** §12.2 still claimed the
fallback keeps a pinned one-`CREATE` shape with no resources, rules, links
or merges. That stopped being true at S4 and was superseded three more
times — S6's `UPGRADE`, S10's derived mode, and the disposition pass's
`MODIFY`/`MERGE` — each deliberately, and each on the same recorded
argument: the fallback is what `--epsilon=fallback`, the integration run
and every player without an API key actually get, so its expressive range
*is* the game for them. Both §12.2 and the S1 decision entry now say what
is true, and both keep the sentence that always was: the fallback can never
breach a budget, dangle a target, or be the reason a fold fails.

### The follow-up: a wider catalog that accumulated

Measuring the campaign mock's growth actually produced caught a shortcut
taken and justified in the same change. The disposition chain was not run
on mock's own catalog shapes, on the grounds that "a table shape is a fresh
`CREATE` by construction, so there is nothing for a disposition to attach
to". True about validity, wrong about the game: ten Zones ended with
**seventeen unrelated Actions against a soft budget of twelve**, and eight
upgrades where the fallback alone produced thirty-one. A wider catalog made
the accumulation problem worse rather than better, because every shape was
a new thing rather than a deeper one — which is exactly what `_as_sequel`
was written for at S6.

`as_disposition` is lifted out of `fallback_echo` and shared. One flag,
`enhancement=False`, for a caller that has already made a specific reading
of the item: "Ice Beam" reads as both `cold` and `beam`, and letting the
generic enhancement (cold → chill an owned weapon) outrank the specific
shape (a beam and the charge it burns) swallowed every elemental item and
put `beam_sustained` back out of reach. Sequel still applies — owning the
same verb is a fact about identity, not a rival reading — and so does
confluence, which is about capacity.

Measured across ten campaigns, before → after: upgrades 8 → 17, merges
1 → 14, resources pinned at **exactly the soft budget of six** in every
seed (the confluence folding each one past it into an existing bar, which
is §16 working as designed), and evolution chains reaching Mk III.

The campaign test asserts all of it: the whole disposition vocabulary
reaching play (`create`, `upgrade`, `modify`, `link` **and** `merge`, in a
real campaign rather than a crafted request), resources under the hard
ceiling now that most shapes carry a bar, and fourteen components across
six campaigns past Mk I. That threshold sits between the two measurements
— 18 with the chain, 9 without — because the failure it guards is silent:
a mock that skips the chain still produces a working campaign, just one
that never gets deeper.

## The pre-playtest pass

Three finite pieces, then stop.

### 1. Two Archipepsi players in one real multiworld — proven

The APWorld's demo seed has always GENERATED two Archipepsi worlds
(`Skyiah` and `Partner`) and nothing ever exercised them at runtime.
`make dual-real` does: a real `MultiServer.py` on a real generated seed,
two bridges connected simultaneously, two saves, each checking the
other's locations. `make dual-real-soak` repeats it across freshly
generated multiworlds.

It has to be a real server. Every hazard here lives in the seam between a
slot and the multiworld, and `MockAPBackend` IS one slot by construction:
both Archipepsi worlds number their locations 89100001–89100030, the same
thirty integers, and the only thing making A's 89100001 a different
location from B's is the slot context the server keeps.

Ten properties, all holding: both connect and scout their own thirty; the
same numeric ids resolve to different items per slot (22–27 of 30 differ
per seed); A checks a location holding B's item and AP delivers to B
exactly once while A gets exactly one Echo and B's campaign does not move;
the symmetric case; native items land only where owed (checked against
external ground truth — what the two worlds' checked locations OWE each
slot, not against each player's own bookkeeping); both generate and claim
Zones concurrently, interleaved on one event loop, with overlapping
numeric allocations; no duplicate Zone record or generation; saves
independent and both reload; one disconnects and returns unchanged while
the other never notices; both report goal; nothing claimed or granted
twice.

The players share **one save directory**, deliberately: `ARCHIPEPSI_SAVE_DIR`
defaults to a single `bridge/saves/`, so two bridges on one machine write
into one folder, and giving each its own would prove isolation the
deployment does not have.

**Two assertions had to be written twice, and neither was a bug.** "B has
no `echo_89100001`" and "89100001 is not in B's checked set" both failed,
because B legitimately owns a location numbered 89100001 and an Echo for
it, meaning a different item entirely. **An echo id is unique within a
campaign, which is the only scope it needs.** The correct property is that
the other player's state did not MOVE — strictly stronger than an absence
test, and what the file now asserts.

Sabotage: a module-level scout cache (0 of 30 locations differ), a shared
received list (a delivery counted twice), a campaign key dropping the slot
(both hash the same), a save path dropping both (one file, two
campaigns). A fifth — dropping only the slot NAME — correctly did *not*
fail, because the key still carries the slot id.

**Bridge port is configurable**: `--port`, and `BridgeServer(port=...)`,
defaulting to the generated constant so nothing that does not ask changes.
Proven by connecting a client to each of two bridges, and by reverting the
parameter to watch the second bind fail with `EADDRINUSE`.

**One behaviour pinned rather than changed.** A Track is a GAME, not a
slot: `track_key` is `recipient_game`, so a location whose item goes to
the other Archipepsi player carries the same "Archipepsi" Track as one
coming back to you — 19 and 11 of thirty in a typical seed. They stay
distinguishable (`recipient_is_self` separates them, and the reveal, the
Echo grant and the archive all read it); they share one Hub rotation.
Coherent, and now asserted so a change would be deliberate.

### 2. The authored-asset / Epsilon boundary — codified

`docs/design-packet-v0.8/AUTHORED_CONTENT.md`, normative, reading position
10 and authority position 6. **Humans make the alphabet, Godot enforces
the grammar, Epsilon writes sentences.** Epsilon may not author anything
whose value depends on consistency, readability, identity, repeated
exposure or exact mechanical dimensions. Five authoring levels from props
to set pieces.

§6 is the honest part: **there are zero imported assets in `godot/` and
every visual is a procedural placeholder**, with seven named file-level
conflicts (chamber builders composing room shells from primitives, the Hub
and Lab built in code, enemy silhouettes as primitives, the material
vocabulary generated at 64×64). Recorded as debt rather than removed — the
placeholders are load-bearing for every suite in the frontier. And the
note for later: replacing a placeholder moves work from Godot to a *human*,
never to Epsilon.

`test_authored_boundary.py` keeps a document from being the only defence.
It is a VOCABULARY test, because the erosion would be someone adding a
schema field that names a mesh or a material while every validator keeps
passing. It also proves `theme` and `palette_color` are still closed
`Literal`s — a selector is only selection while its values are a fixed
list — and that the debt table names files that still exist.

### 3. Playtest readiness

The bridge printed one line and now prints four: port, AP mode, provider,
and the **resolved absolute save path**. That last is the footgun —
`DEFAULT_SAVE_DIR` is `Path.cwd()/"saves"`, so `make bridge` (from
`bridge/`) and the same command from the repo root are different
campaigns. `resolve_provider_name` is its own function because asking for
`claude` without a key is the likeliest first-run mistake.

`bridge/tests/test_startup.py` is the launch-shaped suite: bind,
handshake at the version the client checks, MOCK CAMPAIGN playing a whole
Zone with no server and no seed, the save landing where announced, and
each likely misconfiguration naming its own fix.

## Next useful work
1. **Play-feel pass on real hardware** — the manual checks in
   ACCEPTANCE_TESTS §7 (gap feel, reveal timing, Conference Call comedy)
   need human eyes. Cannot be done in this container.
2. **Live-fire the Claude provider** once `ANTHROPIC_API_KEY` exists
   (`EPSILON_PROVIDER=claude make bridge`); offline stub tests cover the
   mechanics, but a real generation archive would be the interesting thing
   — then `make replay` reports its first-try acceptance rate.
3. ~~Secrets in the tower and platform_path chambers~~ — **done.** Both
   put theirs over the highest FLAT GROUND in the chamber (the
   platform_path's end ledge at `rise`, the tower's top deck at its
   summit), which is the same argument the arena makes applied to a floor
   that is not at zero — `_secret_alcove` takes a `floor_y` now. A tower
   that grows one is built 1.5 m taller, because five metres over the
   summit left the alcove 0.15 m short of standing room and the builder
   declined to place it *silently*, which is the worst of both.
4. ~~Epsilon's voice in the Hub between Zones~~ — **done.**
5. ~~Adversarial review of S1–S5~~ — **done**, 19 findings fixed.
6. ~~Adversarial pass over `ap_client.py`~~ — **done**, one finding (a
   reconnect during generation built the same Zone twice).
7. ~~The whole disposition vocabulary, and a multi-seed soak~~ — **done.**
8. ~~Mock Epsilon's S10 growth (§12.2's unmet obligation)~~ — **done.**
9. ~~Dual-Archipepsi proof, authored-asset boundary, playtest readiness~~ — **done.**

## Known blockers / bugs
None known. One recorded schema corner: `finale_offered` stays true in
postgame, so clients also require the goal to be missing
(`docs/IMPLEMENTATION_DECISIONS.md`).

## Commands
    make test                  # 487 pytest (schemas + bridge + apworld)
    make godot-test            # chamber geometry
    make godot-blink           # invariant I14, every builder
    make godot-hud             # S3: palette, glyphs, pressure valve, archive
    make godot-rules           # S4: invariant I5, the ECHOES 5 interpreter
    make godot-stats           # S5/S7: invariant I3, links, slots
    make godot-lab             # S8: the Echo Lab, and what it must not do
    make godot-affordance      # S9: I4/I12/I13, volumes, local rewards, readouts
    make godot-verbs           # the press/release lifecycle, over a real floor
    make dual-real             # TWO Archipepsi slots, one real MultiServer
    make dual-real-soak        # the same, across freshly generated seeds
    #                            (the 25-seed campaign soak runs inside `make test`)
    make rules-fixture         # regenerate the rule suite's folded snapshot
    make verbs-fixture         # regenerate the verb suite's folded snapshot
    make godot-integration     # the whole game, headlessly
    make replay ARCHIVE=<dir>  # re-validate a generation archive
    make seed-multi && make host && make bridge   # real server play
    godot-bin/godot --path godot                  # the game

Collect an archive while playing:
    cd bridge && python3 -m archipepsi_bridge --ap=mock --epsilon=mock \
      --archive-dir ../generation_archive
