# Archipepsi autonomous frontier

This file is the cheap wake-up state. Keep it short and current. Use `NEXT_STEPS.md` for the detailed project/history handoff and the v0.8 packet for authoritative contract details.

## THE ACTIVE FRONTIER: v0.9 — production and the authored-content transition

**`docs/design-packet-v0.9/IMPLEMENTATION_PLAN.md` is what wake-ups
execute.** S1–S10 (Echoes 2.0) are complete and are history below; the
plan is NOT exhausted.

The governing rule, from `docs/design-packet-v0.8/AUTHORED_CONTENT.md`
(normative, outranks the v0.9 plan): **humans make the alphabet, Godot
enforces the grammar, Epsilon writes sentences.** Epsilon is a composer,
never an asset generator. Do not manufacture "final art" procedurally to
claim a stage. Existing primitive geometry and materials are valid
TESTABLE placeholders and stay. Graybox `.tscn` scenes are legitimate
deliverables and must say in-file that they are not final art.

Dependency order (S21/S22 are independent of the asset pipeline, and are
the work that continues if an art gate blocks the rest):

```
S11  CI                        ── independent, first
S12  registry + asset contract ── the foundation S13-S19 consume
 ├── S13 instantiation pipeline
 │     ├── S14 Hub + Echo Lab migration
 │     ├── S15 room shells + connectors ── S16 encounter/traversal vocabulary
 │     ├── S17 interactable/presentation contracts
 │     └── S18 enemy/player/affordance visual interfaces
 └── S19 material/VFX/audio/lighting registries
S20  campaign spine (human-decision gates)
S21  settings/input/a11y       ── INDEPENDENT
S22  packaging/first-run       ── mostly independent
S23  release hardening         ── last
```

**Stage status:**

| Stage | State |
|---|---|
| S11 CI | **done** — three tiers green on real runners; `docs/CI.md` |
| S12 registry + asset contract | **done** — `schemas/content.py`, `content_registry.gd`, `docs/ART_ASSET_SPEC.md`, `make godot-content` |
| S13 instantiation pipeline | **done** — `content_instantiator.gd`, routed from `ZoneBuilder` |
| S14 Hub + Echo Lab migration | **done** — `hub_anchors.gd`, Lab gap pinned |
| S15 room shells + connectors | **grammar done; shells BLOCKED on Q1** |
| S16 encounter/traversal vocabulary | **done** — tower ascent bounded, gap bound exported |
| S17 interactable/presentation contracts | **done** — `interactable_contract.gd` |
| S18 enemy/player/affordance visual interfaces | **done** — `visual_interface.gd` |
| S19 material/VFX/audio/lighting vocabularies | **done** — `test_epsilon_vocabulary.py` |
| S21 settings/input/a11y | **done** — `player_settings.gd` |
| S20 campaign spine | **next** (expect human-decision gates) |
| S22–S23 | not started |

S21 holds two rules: a preference is never campaign truth (asserted
against `CampaignSnapshot` and `CampaignSave` by reading the preference
names out of the GDScript, so the two cannot drift), and rebinding can
never leave a base-kit action unbound — a player who unbinds `jump` has
made their own seed unfinishable, in a menu, three rooms from the gap.
A hand-edited config is repaired rather than obeyed.

S19 enforces "Epsilon is a composer, never an asset generator"
STRUCTURALLY rather than by review: every string field of every model
Epsilon authors must be a closed vocabulary, a charset that cannot spell
a path, or allowlisted prose with a stated reason. A new free-text field
fails the test until someone says what it is for — which is the moment
to notice it is a filename. `concepts`, `tags`, `subject` and
`scaled_by` gained charset patterns; `res://x.tscn` is twelve characters
and fitted comfortably inside a 24-character free string.

S18 proved a visual swap cannot move a hitbox: every archetype built
under all six themes must produce byte-identical collision, and the
archetypes must differ from each other so that check cannot pass by
everything being one box. Two different rules, because procedural and
authored geometry fail differently — `_box` derives mesh and collider
from one `size` (so they must AGREE), while an authored scene has a
person on each side (so art must not carry collision at all).

S17's "do not leak hidden scouting information" was ALREADY enforced
where it matters: the bridge does not send item identity for an
unrevealed location (`ScoutedLocation._unrevealed_withholds_identity`),
tested in Python since the v0.4 review. S17 added the client-side half —
the client legitimately knows some item names (a shop-stocked location
is revealed), so a pedestal reading `scout.item_name` without checking
state would spoil exactly the Checks the player paid to learn about —
plus a readability rule: no two AP states may share both their words and
their colour.

S16 found and fixed a real I3/I4 inconsistency: the tower's spiral asked
for a 2.4 m mandatory jump at a 1.0 m rise, where the safe bound is 2.0 m
— the same bound the schema enforces on Epsilon's `platform_path`. The
engine was breaking a rule it imposes. `max_safe_gap` is now EXPORTED to
GDScript as a function, so a builder placing a raised platform can ask
instead of typing a number, and the tower's spacing is derived from it.
The tower suite now measures the built ascent rather than inferring it.

**Open question Q1 (`docs/design-packet-v0.9/OPEN_QUESTIONS.md`) blocks
graybox archetype shells.** Every chamber archetype carries continuous
generator-chosen dimensions and a `.tscn` is a fixed size; for
`platform_path` the schema's `gap_size <= SAFE_BASE_JUMP_GAP` bound is
how I3/I4 are enforced today, and a baked gap escapes it. The connector
grammar half of S15 is done and shipped. Do NOT author archetype shells
before Q1 is answered — doing so silently picks option C.

S14 put a named anchor contract between the Hub's logic and its
geometry: logic asks for `main_portal` or `shop`, `HubAnchors` decides
where that is, from the procedural defaults or from an authored scene's
markers. Adoption is per-anchor, so a graybox Hub can replace the room
one marker at a time. The Echo Lab's gap width is now a documented
constant pinned between `SAFE_BASE_JUMP_GAP` and `JUMP_FLAT_REACH` --
both bounds are silent failures if they break.

S13 routed every chamber through the registry, and every route still
ends at `ChamberBuilders` because every entry is still a declared
placeholder. That is the design: the generator is now the documented last
resort rather than the only path, so an authored shell can replace one at
a time without a flag day. A test pins the placeholder route to produce
exactly what calling the builder directly produces.

S12 landed the alphabet's shape, not the alphabet: everything in
`godot/content/registry/legacy_procedural.json` is `procedural_fallback:
true`, which is the registry stating honestly that it is generated
geometry. That is the correct state — the game is READY TO RECEIVE
authored content, and has none yet.

Conventions fixed by the spec but not yet wired (each marked "Not wired
yet" in `ART_ASSET_SPEC.md`, and each is a later stage's job, not debt):
material slot names → themed materials (S19), animation clip names →
interactable contracts (S17), manifest `cost` → a placement budget.

**Heartbeat behaviour:** while v0.9 has unfinished INDEPENDENT stages,
continue the next real frontier item. Once everything left is blocked on
human-authored assets or design decisions, record the exact remaining
gates here and make wake-ups no-ops until the user provides feedback or
assets.

---

## Completed: v0.8 Echoes 2.0 (S1–S10) and the pre-playtest pass

## Open decision, deliberately not guessed
`challenge_marker` (§14.2) and its `challenge_timer` readout (§14.1) have a complete bridge half — grantable, recorded, `best_seconds` improves — and no world half, because neither section says where a run starts, what ends it, or what counts as one. `test_stage_tripwires.py::test_the_challenge_marker_still_has_no_challenge` names the decision and comes due when it is made.

## Stage dependency trap
A live one: a chamber carrying an affordance feature must be at least `MIN_FEATURE_CHAMBER_WIDTH` (5.2 m) wide, and only a corridor can carry one at all — every other chamber type has a Check or a gating objective. A generator that hangs a feature on a default-width connector gets its Zone refused. The fallback widens its own connectors; anything else must too.

Retired at S9: every verb in the catalog runs, and `DEFERRED_PRIMITIVES` is empty (deliberately, so the partition test in `test_schemas.py` stays true rather than vacuous). The rule it encoded still applies to whatever is deferred next — name the LAST required stage, not the first.

## Standing tripwires (deliberate, will fire on stage advance)
- `test_stage_tripwires.py` is now all receipts: the S3 pair fired at S5,
  the S9 pair fired at S9, and each is recorded as discharged. Nothing is
  gated, so `test_the_registry_still_runs_even_though_it_gates_nothing`
  is what keeps the mechanism from being refactored away — it narrows the
  registry by hand and watches it refuse. The same trick keeps the
  primitive gate visible in `test_schemas.py` and `test_s1_review_fixes.py`
  (both pass a narrowed `implemented_primitives` through the seam the
  signature already provides).
- Cross-language pins: glyph indices, palette names, channel count
  (`test_hud_contract.py` ↔ `hud_driver.gd`), theme rule
  (`test_theme_agreement.py` ↔ `integration_driver.gd`), runner arms
  (`test_runner_coverage.py`).

## Resolved at S5 (was the standing unresolved decision)
Traits apply because they are OWNED — unchanged, and now deliberate
rather than inherited. S5 added the escape hatch the contract always
intended: `requires_equipped` makes a trait conditional on a slot, and
I7 now *requires* it for any severe downside (enforced by the trait
model, not merely described). Ownership is the default; equipping is the
modifier. Recorded in `docs/IMPLEMENTATION_DECISIONS.md` (S5).

## Last full green verification
At the pre-playtest checkpoint (this commit):
- `make test`: **487 passed** (schemas + bridge + apworld together)
- `check_packet.py`: green, **11 documents**
- `make dual-real-soak`: 3/3 freshly generated two-Archipepsi multiworlds
- `make smoke`: SMOKE OK
- (was 343 at S9 completion, 362 after the S1–S5 review)
- `check_packet.py`: green, 10 docs
- `make godot-test`: GODOT CHAMBER TESTS OK
- `make godot-blink`: 5125 resolved / 17825 refused; GODOT BLINK TESTS OK
- `make godot-hud`: GODOT HUD TESTS OK
- `make godot-rules`: GODOT RULES TESTS OK
- `make godot-stats`: GODOT STATS TESTS OK (I3 sweep, links, S7 slots)
- `make godot-lab`: GODOT LAB TESTS OK (fixtures, and no campaign mutation)
- `make godot-affordance`: GODOT AFFORDANCE TESTS OK (I4 lane sweep, the
  seven built, volumes that cannot trap, readouts that only read)
- `make godot-verbs`: GODOT VERBS TESTS OK (press/release/cancel/death,
  the complete refund, hover claims across four slots, parry vs. DoT,
  shield timers, and rule effects following the highlighted slot)
- `make godot-integration`: GODOT INTEGRATION OK, full 12-zone campaign;
  every interpretation credited in some provenance chain, components at
  Mk II+, Actions reaching several slots, the Hub's Lab present and inert,
  affordance features offered and built, a local reward earned and
  recorded without touching a single AP location, and all 26
  interpretations reading their item in four different modes

Do not assume these counts remain current after new commits; update this section only after the corresponding suites actually run green.

## Core invariants
AP integrity > save integrity > deterministic campaign state > playable integration > polish.

Archipelago owns randomized truth. Python owns campaign/allocation/save/fold truth. Epsilon owns presentation/creative structured interpretation only. Godot renders/simulates and sends player intents. Persistent state changes go through transitions. Mechanics are derived from the interpretation log and never persisted as a second truth. Preserve base-kit solvability.

<!-- Compact frontier format authored by ChatGPT / GPT-5.6 Sol, OpenAI. -->

### v0.8 stage log
- Branch: `claude/archipepsi-build-inzshp`
- v0.7 POC: complete
- Echoes 2.0 S1 + S1.1 + S2 + S3: complete
- S4: complete — the ECHOES §5 rule interpreter (`rule_runtime.gd`,
  `make godot-rules`, I5 proven: edge latches, deferral, cooldown-bounded
  oscillation, per-tick cap, cost atomicity, alias resolution); fold
  validates rule resource references (I11 treatment); capability gate
  opened `rule` with per-piece §5 allowlist gates; game-event wiring
  (incl. new chamber tracking); fallback grants a FLASK (low_health
  auto-heal rule) and a kill-fed CELL (self-discharging shield rule); I8
  proven and the fallback is budget-aware; integration asserts the
  campaign ends owning folded resources AND rules.
- S5: complete — the nine-stat derived stack with I3's floors
  (`stat_stack.gd`, `make godot-stats`), per-target statuses
  (`status_effects.gd`), all four link kinds walking in the runner, the
  last six verbs (`beam_sustained`/`hover`/`block`/`restore_resource`/
  `scan_mark`/`cleanse`), I7 enforced by the trait model, and the
  §5 status rule vocabulary. Both S3 tripwires discharged.
- S6: complete — the operation vocabulary is whole. The capability
  gate admits `upgrade`/`modify`/`merge`; `target_errors` checks a
  disposition can land at GENERATION (repair loop) as well as at fold
  (I11); the request carries the owned component graph with per-field
  upgrade headroom; the fallback evolves families (ECHOES §11's own
  Hookshot→Longshot→Clawshot example is reachable from
  `--epsilon=fallback`); I10 alias soundness proven; §12 identity
  packages complete (sound family, particle style) and pinned from both
  sides.
- S7: complete — four slots, four runtimes, four keys (RMB / MMB+F /
  Shift / C). `IMPLEMENTED_ACTION_SLOTS` is the whole contract;
  `SLOT_NAMES` shared through `constants.py`; the S1.1 `ARCHETYPE_SLOT`
  collapse retired (migrated mobility Echoes go back to Shift); the HUD
  shows all four slots with Mk levels; the archive names the key each
  button lands on, compares against what it would replace, and marks
  favourites (client preference, `user://loadout.cfg`, never campaign
  state); the wheel cycles favourites within the highlighted slot.
- S8: **complete** — the Echo Lab, a walk-in Hub annexe (never a Zone,
  never a Check): dummy that cannot die or farm `kill` events, tall wall
  with height bands, measured runway, gap with a safe return, armed
  hazard through the production damage path, deterministic moving target,
  reset pad that clears transient state only. `make godot-lab` proves it
  and proves the negative: a full session sends no intent and moves no
  campaign truth. ChatGPT/GPT-5.6 Sol's build brief is cherry-picked at
  `docs/proposals/S8_ECHO_LAB_BUILD_BRIEF.md`.
- S9: **complete** — the seven world affordances build as real geometry
  (`affordance_features.gd`, `affordance_nodes.gd`), each paid for by an
  owned capability (I12, `owned_affordance_tags` over OWNED mechanics);
  features never touch the mandatory path (I4 — the schema keeps them out
  of reward chambers and gating objectives, the builder keeps them out of
  the walking lane, and a room too narrow to have a "beside the path" gets
  none); every feature holds a `LocalRewardPickup` and never an AP reward
  (I13); movement volumes write into a player environment layer that
  cannot trap you (`MIN_VOLUME_SPEED_SCALE`, upward-only lift); the ten
  §14.1 readouts draw from the fold in `readouts.gd`, observing only —
  proven by a frozen-world frame that moves nothing and sends no intent.
  `pull_pickup` is implemented, so **nothing is gated any more**:
  `DEFERRED_PRIMITIVES` is empty and every registry equals its contract.
  `make godot-affordance` is the suite.
- S10: **complete** — §15's chain (`item -> concepts -> supported systems
  -> validated recipe`) is real. `epsilon/concepts.py` is the
  deterministic reader; it reproduces §15's own three worked examples
  (*Water Tunic*, *BLJ*, *Master Sword*) and a test asserts the prose
  still uses them. The fallback reads every item and labels itself with a
  mode **derived from what its operations did**, so the archive cannot
  misdescribe an Echo; mock Epsilon says the reading out loud. The mode is
  a fact, never a preference — creativity steers via `preferred_modes` in
  the request rather than capping the label. `reading_errors` refuses an
  empty reading and one sharing no vocabulary with the item, and nothing
  else: taste is the provider's job. §16 is now counted in the units the
  prose states (affordances in **distinct tags**), the request carries
  `budget_headroom` and `relevance_hint`, and the Claude prompt states the
  pipeline, the four modes and the budgets instead of leaving them to be
  inferred. The archive shows the mode.
- **Adversarial review of S6–S10: done, all findings fixed.** Two passes
  (client and bridge). The deepest: the affordance geometry was designed
  and tested in an 18×20 arena, which the schema refuses for features —
  **a corridor is the only chamber that can ever host one**, and four of
  seven rewards sat above its 3.6 m ceiling. Reworked around per-tag
  footprints, extent-based lane clearance, and corridors built to the
  height their features declare. Also: an advertised upgrade bound the
  model would not honour (a `FoldError` no retry could pass, the one
  save-integrity bug), a `Damageable` concept that was missing so the
  breakable wall could not be hit by anything, a concept validator wrong
  in both directions, a mode that called self-contained Echoes "systemic",
  a tag dropped from every Zone forever, and claimed rewards respawning.
  All sabotage-proven. See `docs/IMPLEMENTATION_DECISIONS.md`.
- **Secrets reach the vertical chambers.** `platform_path` and `tower`
  grow them now, over the highest FLAT GROUND in each (the end ledge at
  `rise`, the top deck at the summit) — `_secret_alcove` takes a `floor_y`,
  because measuring from absolute zero put the alcove *below* the player
  in both. A tower that grows one is built 1.5 m taller; five metres over
  the summit left it 0.15 m short of standing room and the builder
  declined silently. Epsilon also speaks in the Hub now.
- **Adversarial review of S1–S5: done, all 19 findings fixed.** Three
  passes (the fold/save half, then the runtime engines). Two were
  campaign-destroying and neither was reachable from any existing test:
  - **A legal v7 save destroyed the campaign it migrated.** v7 let a
    passive make you slower (`SPEED_MULT_MIN` 0.9); v8's I3 floor forbids
    it, and the migration copied the multiplier across, so the models
    refused the result. `load_save` caught, tried the `.bak` (the same v7
    file), returned None — and the engine reads None as "no campaign",
    built an empty one, and the next write moved the real save into the
    backup slot. Migration clamps now; "unreadable" and "absent" are no
    longer spelled the same way; the backup is copied rather than renamed
    (a crash between two renames left NO primary); a non-primary recovery
    heals the primary immediately.
  - **A merge left every link pointing at the component it deleted.** The
    fold rewrote aliases, components, provenance, Mk and order — not
    `links` — while `echo_runtime.gd` states in as many words that the ids
    it receives are canonical. A `powers` source merged away reads 0 of 0,
    so the spend always refuses: the Echo stops working for the rest of
    the campaign, silently, because aliases are permanent. Edges are
    rewritten at merge time now, and `powers`/`scales` are enforced
    at-most-one-per-target, which is what both clients already assumed.
  - `target_errors` waved through five refusals the fold then raised on
    (MODIFY had only an existence check; MERGE never asked where
    `max_value` landed, and `capacity` **defaults** to `"sum"`). A
    `FoldError` in `append_interpretation` is a crash, not a rejection,
    and it repeated on every retry, so the Check could never be granted.
  - Ten in the press/release lifecycle and the pool: a `charge_shot` fired
    from a key-up with no press; a refused press kept its cost, paid its
    `fills` link and emitted `action_used`, which made refused presses net
    resource GENERATION; death ended no hold; a slot swap stranded a hover
    (an I3 bypass — `hover_gravity_scale` is applied after `clamp_stat`);
    a failed multi-cost re-armed `regen_delay` sixty times a second and
    stopped regeneration dead.
  - Six more in statuses, latches, parries and shields: a magnitude could
    outlive the duration it came with; `cleanse` stripped the player's own
    `low_profile` stealth; `apply` had no vocabulary guard; an arm was
    kept alive by an unrelated channel and survived Zone entry; a burn
    tick spent the parry window; an absorbed shield froze its timer and
    inflated the next grant.
  - And the per-tick firing cap starved the same rules forever, because
    `_rules` order is fixed.
  New: `make godot-verbs` (a real player over a real floor, driving the
  four real runtimes), and both GDScript fixtures now have generators in
  the tree (`make rules-fixture`, `make verbs-fixture`) with a bridge test
  that regenerates in memory and compares — the rule snapshot claimed to
  be a real fold and was, but its generator had not survived.
- **Adversarial pass over `ap_client.py`** — the top of the correctness
  order, and it had never had a dedicated one. One finding: `on_ap_ready`
  runs on every completed sync, RECONNECTS included, and resumes a Zone in
  `PENDING_GENERATION` — so a socket blip during a provider call built the
  same Zone twice (a second billed Epsilon request) and the loser died of
  `ValueError: Zone is GENERATED, not pending` inside a bare task, where
  nothing surfaces it. Guarded at both ends: no second run for a zone id
  already in flight, and `_run_generation` re-checks the record state after
  its await. The rest of the file came back clean — every `_apply` site
  either has no await before it or re-reads `self.save` after one, the
  race-mode `Get` is sent by `CommonContext.send_connect` (so the scout
  gate cannot hang), and the goal is re-sent on reconnect from
  `on_ap_ready` when `goal_sent` is already persisted.
- **The whole disposition vocabulary now reaches players.** S6 completed
  `UPGRADE`/`MODIFY`/`LINK`/`MERGE` in the validators and the fold, and
  then nothing emitted half of it: no provider in the tree produced a
  MODIFY or a MERGE, so §3's own two examples were shapes a unit test
  could build and a player could never receive — and a bug in either was
  invisible to every integration run (the merge-link bug fixed this
  morning is exactly that). The fallback now tries the most specific
  claim first: a **sequel** (UPGRADE) when it owns the verb, an
  **enhancement** (MODIFY) when the item READS as an element and
  something owned can be hit with, and a **confluence** (CREATE + MERGE)
  when the resource budget is spent, which is §16's rule written down.
  Each returns nothing when it cannot land, so the ordinary CREATE
  survives. `modifiers` joins `upgradable` on the owned-component
  summary, because a MODIFY that cannot see the target's existing two is
  guessing at exactly what it will be refused for. Five words the concept
  lexicon should always have had (`ember`, `ash`, `venom`, `poison`,
  `spark`) mean MODIFY now happens in ordinary mock play.
- **`test_campaign_soak.py`: 25 full campaigns, 25 different seeds.** The
  integration run plays once, always on `"MockSeed"` — and the seed is the
  only input to the track order, the shop draw and the allocator's
  shuffle. Twenty-five playthroughs cost 23 s without Godot, each
  asserting what must hold of EVERY campaign: the goal reached and
  reported once, no location in two live Zones, no Check claimed twice, no
  location yielding two Echoes, the allocator never starving (§11.5), the
  save validating after every transition, and the fold publishing no edge
  that names a component it deleted.
- **Mock Epsilon does S10's other half now.** EPSILON_SPEC §12.2 named it
  and scheduled it: `--epsilon=mock` must exercise resources, rules, links,
  merges and the wider action catalog "or the headless integration run
  stops proving anything about the systems S2–S6 add." It never grew — mock
  delegated its whole echo to `fallback_echo` and added narration. Measured
  across ten campaigns that cost **8 of 28 primitives, 1 of 4 link kinds,
  and no Info readout**: `make godot-blink` fired 23k attempts at a verb
  nothing granted, the hover/beam/block holds in `make godot-verbs` covered
  presses no player could perform, and all ten §14.1 readouts stayed dark
  because only an `info` component turns one on and nothing emitted one.
  Mock now picks a shape from the §15 READING (`beam` → a beam and the
  charge it burns; `revelation` → a radar) and falls through to the
  fallback for an item it cannot read. Every shape is self-contained, so a
  link cannot dangle and the three `POWERED_PRIMITIVES` are expressible at
  last. The roster was the real limit — ten names over 21 fill slots —
  widened to 21, every one a name the reader already understood.
  A mock campaign now reaches **all four link kinds, real readouts, 16 of
  28 primitives**. `test_mock_catalog.py` holds both levels: every row of
  the table folds, and a real campaign reaches the systems.
  Follow-up, from measuring the campaign the growth produced: mock was
  **accumulating where it should evolve**. The disposition chain was not
  run on mock's own catalog shapes — justified as "a table shape is a
  fresh CREATE by construction", which is true about validity and wrong
  about the game — so ten Zones ended with seventeen unrelated Actions
  against a soft budget of twelve. `as_disposition` is shared now, with
  one flag (`enhancement=False`) for a caller that has already made a
  specific reading: "Ice Beam" reads as both `cold` and `beam`, and the
  generic enhancement was swallowing the specific shape. Upgrades 8 → 17,
  merges 1 → 14, resources pinned at exactly the soft budget of six, Mk III
  chains. **The whole disposition vocabulary now reaches a real campaign**,
  merge included, rather than only a crafted request.
- **Dual Archipepsi is proven and supported.** `make dual-real` /
  `make dual-real-soak`: a real MultiServer on a real generated two-slot
  seed, two bridges connected at once, two saves in ONE shared directory
  (the realistic same-machine case), each checking the other's locations.
  Ten properties across three freshly generated multiworlds. Four
  sabotages caught (shared scout cache, shared received list, a campaign
  key dropping the slot, a save path dropping both). The bridge port is
  configurable (`--port`, `BridgeServer(port=...)`), defaulting to the
  generated constant. Two findings, neither a bug: an echo id is unique
  only WITHIN a campaign (both worlds number locations 89100001–89100030,
  so `echo_89100001` exists in both and means different items — the
  correct property is that the other player's state does not MOVE), and a
  Track is a GAME not a slot (`track_key` is `recipient_game`, so a
  location whose item goes to the other Archipepsi player shares the
  "Archipepsi" Track with one that comes back to you; asserted so a change
  would be deliberate).
- **`AUTHORED_CONTENT.md` is in the packet and authoritative.** Humans
  make the alphabet, Godot enforces the grammar, Epsilon writes sentences.
  Reading position 10, authority position 6 (above EPSILON_SPEC on the art
  boundary, silent elsewhere). Epsilon may not author anything whose value
  depends on consistency, readability, identity, repeated exposure or
  exact mechanical dimensions. Five authoring levels, props → set pieces.
  §6 records the debt: **zero imported assets exist and every visual is a
  procedural placeholder**, with seven named file-level conflicts. Not to
  be ripped out — the placeholders are load-bearing for every suite.
  `test_authored_boundary.py` guards the vocabulary (no schema field may
  name a mesh/material/texture; `theme` and `palette_color` must stay
  closed Literals).
- **Playtest ready.** The bridge announces port, AP mode, provider and the
  RESOLVED save path at startup (the save dir is cwd-relative, which is
  the footgun). `test_startup.py` is the launch-shaped suite: bind,
  handshake, mock campaign plays a Zone, save lands where announced, and
  each likely first-run misconfiguration names its own fix.
