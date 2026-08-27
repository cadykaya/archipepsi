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

**Then: S5** — traits, links, statuses: the derived stat stack with
clamps, the four link kinds (which un-gate `beam_sustained`, `hover`,
`block`, `restore_resource` and fire both stage tripwires), and player
and enemy statuses.



## Next useful work
1. **Play-feel pass on real hardware** — the manual checks in
   ACCEPTANCE_TESTS §7 (gap feel, reveal timing, Conference Call comedy)
   need human eyes. Cannot be done in this container.
2. **Live-fire the Claude provider** once `ANTHROPIC_API_KEY` exists
   (`EPSILON_PROVIDER=claude make bridge`); offline stub tests cover the
   mechanics, but a real generation archive would be the interesting thing
   — then `make replay` reports its first-try acceptance rate.
3. Secrets in the tower and platform_path chambers — both have the
   vertical room for it; only arenas grow them today.
4. Epsilon's voice in the Hub between Zones (it currently only speaks
   inside a Zone, plus the existing generating-screen lines).

## Known blockers / bugs
None known. One recorded schema corner: `finale_offered` stays true in
postgame, so clients also require the goal to be missing
(`docs/IMPLEMENTATION_DECISIONS.md`).

## Commands
    make test                  # 263 pytest (125 schema)
    make godot-test            # chamber geometry
    make godot-blink           # invariant I14, every builder
    make godot-hud             # S3: palette, glyphs, pressure valve, archive
    make godot-rules           # S4: invariant I5, the ECHOES 5 interpreter
    make godot-integration     # the whole game, headlessly
    make replay ARCHIVE=<dir>  # re-validate a generation archive
    make seed-multi && make host && make bridge   # real server play
    godot-bin/godot --path godot                  # the game

Collect an archive while playing:
    cd bridge && python3 -m archipepsi_bridge --ap=mock --epsilon=mock \
      --archive-dir ../generation_archive
