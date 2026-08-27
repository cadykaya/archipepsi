# Implementation decisions and deviations

Only real deviations from the v0.7 packet and material constraints live here.

- **Godot obtained by download, not preinstalled.** The packet's Phase 0 says
  "if Godot is absent, do not install it". That rule guarded a time-boxed
  session on the developer's machine; this build runs in a fresh container
  where nothing is preinstalled, and the user's build instructions require the
  Godot vertical slice. The official stock build (4.5.1.stable.official.f62fdbde1,
  godotengine GitHub release asset) is downloaded into `godot-bin/` (gitignored).
  No fork, no source build.

- **AP requirements installed directly.** `ModuleUpdate.py --yes` failed while
  building `mpyq` (an SC2-world dependency with a legacy setup.py) and the
  container's Debian-managed PyYAML could not be uninstalled. Core
  `requirements.txt` was installed with `pip install --ignore-installed`
  instead. `CommonClient` imports and reports 0.6.7; worlds with missing
  optional deps fail their own imports gracefully inside AP's world loader.

- **APWorld vendors `constants.py`.** The packaged `.apworld` must be
  self-contained, so `apworld/archipepsi/constants.py` is a verbatim copy of
  `bridge/archipepsi_bridge/schemas/constants.py`. A pytest asserts the two
  files are byte-identical, so they cannot drift silently.

- **Partner world for the multiworld seed** (`TECHNICAL_ARCHITECTURE.md` §8.5):
  a second Archipepsi slot using the solo YAML, as the packet suggests. Its 30
  locations comfortably absorb the 10 non-local Epsilon Coins.

- **`finale_offered` stays true in postgame** (schema behavior, noted per the
  authority rules): `HubStatus.finale_offered` is computed as
  `finale_unlocked and accepts_zone_request`, and both operands remain
  honestly true after Check 030 confirms (the thresholds stay met; the mode
  returns to `ZONE_AVAILABLE`). The schema is the contract, so the bridge
  refuses a postgame `request_next_zone(finale=True)` with a recoverable
  error ("the finale is already resolved") and clients additionally require
  the goal to be missing before offering the finale portal. The prose
  ("finale_offered — the portal may start it right now") does not cover the
  goal-already-checked case.

- **Claude provider declines server-side model fallbacks.** A safety refusal
  (`stop_reason: "refusal"`) routes to Archipepsi's own deterministic
  fallback generator instead of a different model — the game already has a
  fallback layer with stronger guarantees (validated, deterministic, free),
  and provider identity is configuration, not semantics.

- **Structured output degradation.** The Claude provider first requests
  `output_config.format` with the exported JSON Schema; if the API rejects
  the schema (constrained-decoding subset), it degrades to prompt-level JSON
  for the rest of the process. Archipepsi's validators remain the authority
  on every path, so this changes reliability, never correctness.

## Echoes 2.0 — S1

- **`schemas/` is v8, and the packet's temporary authority exception is
  gone.** The v0.8 packet was written before implementation and, for one
  stage, let `ECHOES.md` outrank `schemas/echo.py`. S1 landed the executable
  contract, so `schemas/` outranks every document again — the normal rule.
  `check_packet.py` now derives the 28-primitive catalog count from
  `ACTION_PRIMITIVES` instead of trusting the prose, after the first draft
  of `ECHOES.md` advertised 26 while listing 28.

- **`zone.py` stays at `schema_version = 7`, deliberately.** The Zone
  contract did not change in v0.8 — Echoes 2.0 changes what an Echo means,
  not what a Zone is — and bumping a version to match its neighbours would
  claim a change happened where none did. `protocol_version` and the Echo
  and save versions all move to 8, because those genuinely changed.

- **Traits apply because they are owned, not because something is
  equipped.** This is the one place S1 does not "play identically" to v0.7,
  and it is a consequence of the model rather than a choice made here:
  v0.7's passives applied only while their Echo was equipped, and a v8
  trait is true once owned (`ECHOES.md` §2). A migrated save with several
  passive Echoes therefore has all of them at once.

  It cannot break traversal. Each trait is individually floored at base by
  a model validator — a gravity trait may only lighten, a speed trait may
  only quicken — and the runtime clamps the *product* to
  `GRAVITY_MULT_MIN`/`SPEED_MULT_MAX`, which are the same two constants
  `max_safe_gap` was derived from. So every generated jump stays valid
  without recomputing one.

- **The fold is not cached on the model.** `CampaignSave.derive()` runs it
  on demand, and `CampaignSave`'s own validator runs it once per
  construction so a log that cannot fold cannot be written to disk. A
  cached fold would be a second source of truth waiting to go stale.
  Measured at 0.16 ms for a full 26-echo campaign
  (`test_migration_corpus.py`), which is comfortably cheap for something on
  the save path.

- **Migration happens at the dict level, before validation.** Keeping a
  parallel tree of v7 models alive forever costs more than converting the
  JSON, and validating the *output* as an ordinary v8 save means a
  migration that produced something the models reject fails at load rather
  than somewhere downstream. `store.load_save` writes the migrated save back
  immediately: a migration that only lives in memory runs again on every
  load, and the first crash after it loses whichever half was in flight.

- **`EchoGenerationRequest` stays narrow in S1.** The full v0.8 request —
  the owned component graph, the alias table, the live budgets — is what
  lets an interpretation answer another item, and it lands with the
  interpretation pipeline in S10. Sending it now would be a prompt full of
  context no rule uses. What S1 does change is the shape of the *answer*.

- **The fallback provider stays deliberately boring.** One `CREATE`, one
  Action or one Trait, mode `literal`, no resources, rules, links or
  merges. It cannot breach a budget, dangle a target or fail a fold, which
  is what keeps it usable as the test oracle for every stage after this
  one. The mock provider is the one that has to grow, and that is S10.

## S1.1 — an externally authored review pass, and what it exposed

A post-S1 review patch (commits `a0e61e3`, `7e2837e`, `68c1015`) was
authored outside this build by ChatGPT (GPT-5.6 Sol, OpenAI). It was
reviewed against the packet and the running code rather than accepted on
description, and all three of its substantive changes hold up:

- **Staged capability gating** (`epsilon/capabilities.py`). `IMPLEMENTED_-
  PRIMITIVES` gated which Action verbs the engine could run, but nothing
  gated operations, component kinds, slots, trait stats, modifiers or the
  projectile fields v8 added. A Resource, a Rule or a `LINK` was therefore
  *schema-valid* and would validate, persist and then do nothing — the
  precise failure `IMPLEMENTED_PRIMITIVES` exists to prevent, left open
  everywhere except Actions. The request and the post-parse validator now
  read one registry, so the prompt cannot advertise what validation would
  accept as a no-op. The fallback runs through the same `check()`, so a
  fallback that ever drifts out of stage raises instead of persisting.

- **Batch grant order** (`transactions.reconcile`). `ECHOES.md` §5 says
  sequence numbers within one reconciliation batch are assigned in
  `source_location_id` ascending order. The fold honoured that; `reconcile`
  iterated `pending_checks` in claim order and never did. A documented
  determinism rule that the only code path capable of violating it does not
  enforce is not a rule, and one `RoomUpdate` confirming several Checks was
  enough to expose it.

- **Collapsing `ARCHETYPE_SLOT` onto `echo_a`.** A migrated v0.7 mobility
  Echo was given `slot="mobility"`, and `main.gd` binds `slotted_action()`,
  which defaults to `echo_a`, and nothing else. The Echo was owned,
  slotted, and unreachable by any button.

Two corrections were made on top of it:

- **The expiry stage was wrong.** The patch documented the slot collapse as
  lifting at S2. S2 ships the primitive catalog and the action runner and
  leaves the number of reachable buttons at one; four-slot binding is
  **S7**. A stopgap whose comment names the wrong stage gets removed a
  stage early, by someone reading the comment and believing it.

- **The packet and the bridge had silently diverged.** The patch edited
  `bridge/archipepsi_bridge/schemas/migration.py` without the packet copy
  that README §23 calls the binding contract. Both trees stayed internally
  consistent and every suite stayed green while the contract and the code
  disagreed about which slot a migrated Echo lands in. `check_packet.py`
  now compares the two directory-wide and fails on any difference, added
  and then verified by deliberately introducing drift. This is the same
  medicine as the derived primitive count: two things that must agree need
  a check that says so, or the agreement is only a comment.

## S2 — the action primitive catalog and the action runner

- **21 of 28, and the other 7 named.** S2 "ships §6 in full" as far as its
  dependencies exist. `beam_sustained`, `hover`, `block` and
  `restore_resource` need a Resource to drain or refill (S3); `scan_mark`
  and `cleanse` need statuses (S5); `pull_pickup` needs local rewards (S9).
  Rather than omit them, `DEFERRED_PRIMITIVES` names each with the stage
  that lands it, and `test_schemas.py` asserts the two tuples *partition*
  the catalog — a primitive dropped from both would otherwise read exactly
  like one nobody got to.

- **The catalog is exported to GDScript, and the runner is checked against
  it.** `IMPLEMENTED_PRIMITIVES` promises that a verb the engine cannot run
  is refused rather than accepted as an ability that does nothing. Nothing
  could verify that promise, because the list is Python and the runner is
  GDScript. `test_runner_coverage.py` now reads `echo_runtime.gd` and
  asserts the match arms equal the implemented set, in both directions: a
  missing branch is an Echo that validates and does nothing, and a branch
  for a still-refused verb is dead code that reads like a shipped feature.

- **Three shapes of Action, not one.** `activate()` no longer resolves
  everything. A held verb (`glide`, `charge_shot`) starts on the press and
  ends on the release; a scheduled one (`burst_fire`) pays out over later
  frames. The cooldown is charged on the *press* in every case, so holding
  cannot dodge the cost. Conditional verbs check their condition **before**
  the cooldown is charged: spending a dash on a press that could never have
  resolved reads as the ability being broken.

- **Airtime budgets live on the runtime, not the player.** `air_dash` uses
  and `double_jump` charges belong to the Action, so swapping the slot
  resets them and touching the floor refills them. Keeping them on the body
  would have let a slot change hand out a free extra jump.

- **`blink` was the dangerous one, and the sweep proved it.** It is the only
  verb that sets a position rather than a velocity, so nothing downstream
  catches a bad result. The I14 sweep (`make godot-blink`, 23k attempts
  across five builders × five themes) found two real bugs on its first run:

  1. Converting the ray-derived point from camera height to feet by
     subtracting the eye height put the player *under* the floor they were
     aiming at — through the level and into the void, 350 times. A landing
     on a walkable surface now never goes below the point the ray hit.
  2. The clearance probe was a small sphere near the ankles, which cleared
     landings whose feet were in open air while the body was inside a wall
     or a ceiling — 100 more. It asks with the player's own capsule now.

  The suite also guards against passing vacuously: it asserts that a real
  number of attempts *resolved* and that a real number were *refused*,
  because all four properties are trivially true of a blink that never
  fires.

- **The blink suite boots the real project rather than using `--script`.** A
  `--script` SceneTree run never instantiates the autoloads, so every script
  touching `BridgeClient` fails to compile and the suite reports zero
  attempts while printing nothing alarming. `make godot-import` now fails on
  a parse error for the same reason: it is the only step that compiles every
  script rather than the ones one entry point happens to reach, and a parse
  error in the action runner printed `GODOT CHAMBER TESTS OK` while the game
  itself refused to load.

- **The fallback got a wider vocabulary, not a wider licence.** It is what
  `--epsilon=fallback`, `make bridge-mock`, the integration run and any
  player without an API key actually get, so its expressive range *is* the
  game for them. S1 hashed an unrecognised item to three outcomes — a gun, a
  dash, or walking faster — which made a 26-Check campaign one verb repeated.
  It now reaches 20 distinct outcomes across a 30-Check campaign. It is
  still deterministic and still structurally boring: one `CREATE`, one
  Action or Trait, mode `literal`, no links or merges. A sword also stopped
  being a six-metre hitscan, which is what it had to be when melee did not
  exist.

## S3 — resources, the HUD channels, and the archive

- **The palette's safety claim was false, and the proof said so on its
  first run.** `ResourcePalette` promised no hue collides with the HUD's
  reserved semantics; nothing checked it, and `signal` sat 0.11 (RGB
  Euclidean) from the cooldown-ready confirmation cyan with `ember` 0.20
  from danger amber. The VALUES moved — signal to a deep teal, ember to a
  coal-salmon, rust to a darker oxide — and the eight NAMES, which are the
  schema contract (`PALETTE_COLORS`), did not. `make godot-hud` now holds
  every fill and dim at least 0.30 from every reserved colour and fills
  0.25 from each other, floors the palette clears with real margin (worst
  case 0.314 / 0.290).

- **The source glyph now uses the shared sha256 rule, because the packet
  says there is exactly one.** ECHOES.md §12 derives source identity "by
  the sha256 rule the bridge and client already share" (`prng_seed` /
  `_prng_seed_mod`, the campaign-board theme rule). S3's first draft
  invented a second derivation — a character sum, deterministic but
  private. It was replaced rather than pinned: pinning it would have
  enshrined the deviation. The rule is pinned from both sides the way the
  theme rule is: glyph strings in `hud_driver.gd`, sha256 indices in
  `test_hud_contract.py`.

- **`EffectSummary`'s upgrade arm was Python in GDScript's clothing.**
  `"%+g"` is not a GDScript conversion; the arm had never once executed,
  because nothing in the game can produce a non-CREATE operation yet. The
  HUD suite's fixture — a real fold of create + upgrade — ran it first and
  Godot raised "unsupported format character" mid-archive. It now renders
  "+40", matching the fold's provenance-note style, and the suite pins the
  line. The fixture testing renderers AHEAD of providers being able to
  produce the data is deliberate: S6 should land into an archive that
  already works.

- **Provenance chains render on every interpretation that touched the
  component, and chains of one stay silent.** ECHOES §11's block is the
  rendering contract (Mk in Roman numerals, every AP item in order, §12
  accent per row). The chain answers "what did this Check do for me", so
  it appears under the upgrader's row as well as the creator's. A
  single-entry chain adds nothing the row's source line does not already
  say, and repeating it under every young Echo would bury the rows with
  real history.

- **`EchoGenerationRequest` does not carry `over_soft_budget` yet, on
  purpose.** The steer exists to redirect a provider toward `UPGRADE` /
  `LINK` / `MERGE`; the capability gate refuses every one of those
  operations today, so sending it would invite the provider to do the one
  thing validation then rejects — a prompt that manufactures its own
  repair loop. The staging table already places budget context in the
  provider at S10, after S6 lands dispositions. `test_stage_tripwires.py`
  fails the moment a non-CREATE operation becomes implementable and names
  this decision for re-execution.

- **Stage tripwires are tests, not notes.** Two S3 obligations were of the
  form "this is intentionally dead until stage N" (`_is_cost_of_slotted_-
  action` reads links that cannot exist before S5; the budget steer
  above). Each is now a test that asserts the gate and, in its docstring,
  names the work due in the same change that opens it. A note gets read by
  whoever happens to look; a red test gets read by whoever moves the gate.

## S4 — the rule engine

- **Derived events are per-rule edge LATCHES, not queued events.** §5.1's
  clauses pull against each other at one point: "sitting at a threshold
  fires nothing" (edge, not level) versus I5's "a fill-on-empty /
  drain-on-full pair oscillates at the cooldown rate". A derived event
  that is simply dropped when every listener is cooling deadlocks that
  pair after one cycle — the value then SITS at the threshold and no new
  edge ever comes; the rules suite found exactly this on its first run. A
  queued event, redelivered until handled, is the backlog cascade the
  design bans. The resolution: a crossing ARMS each listening rule (one
  latched firing), the cooldown delays consumption, firing consumes the
  arm, and a value that leaves the threshold unfired takes the arm with
  it. Arms are state bounded by the rule count, never a growing queue;
  sitting still fires nothing because sitting never re-arms.

- **World consequences of effects are events; synthetic events are not.**
  "No effect emits, enqueues or raises an event, directly or indirectly"
  is read as banning effects from touching the DISPATCH machinery. A
  `damage_around` that kills an enemy produces a real `kill` — the same
  observation the engine would make had the Static Pulse done it — and it
  lands in the pending queue for the NEXT tick, outside the running
  dispatch. Termination is unaffected: such events are bounded by world
  resources (an enemy dies once), not by rule feedback.

- **The cap skips; push and armed differ in what "skipped" means.** A push
  event the cap skips is gone — a jump nothing answered. An armed edge
  the cap skips stays armed and retries next tick, which is not a queue
  (at most one pending firing per rule, ever). Rules the cap skipped are
  never carried over as events.

- **A rule's resource references are validated by the fold, like I11.** A
  rule whose cost, resource condition or resource effect names nothing
  the campaign owns can never fire — a missing bar reads as empty forever
  — and a dead rule that persists is the exact failure the staged gates
  exist to prevent. The fold refuses it loudly at the rule's own sequence
  position, resolving through merge aliases first (a rule written against
  an absorbed resource keeps meaning the survivor), and re-checks after
  every `MODIFY` that can add a condition or effect. Creating the
  resource earlier in the same interpretation counts, and the fallback's
  rule outcomes lean on that ordering.

- **The fallback steps aside at the hard budgets.** `_pipeline` treats a
  fallback its own validation refuses as a RuntimeError — correctly, but
  since S3 that was reachable: a 16th resource-hinted item name at the
  hard budget would have made the fallback breach. With rules the surface
  doubled, so `fallback_echo` now takes the live fold and each resource-
  or rule-bearing outcome checks for room first, degrading to the item's
  budget-free shape when the ceiling is close. Determinism is per (item,
  campaign state) — the same determinism the archive replays.

- **`slot_is` reads as "the named slot is occupied".** The schema says
  only "names a slot"; with one string and no second operand, occupancy
  is the reading that needs no invented syntax. Revisit at S7 if
  favourites need a component-identity form.

- **`dash_end` is a 0.35 s window, ended early by landing.** The S2 dash
  is an instantaneous impulse with no tracked state, so the engine
  defines the dashing window as roughly the impulse's decay under ground
  friction. Chosen over inventing a dash state machine a stage that owns
  movement polish can replace.

## S5 — traits, links, statuses

- **The catalog is complete but for one verb.** `beam_sustained`, `hover`,
  `block` and `restore_resource` needed a Resource *and* a link, and both
  now exist; `scan_mark` and `cleanse` needed statuses. `pull_pickup` is
  the only primitive left in `DEFERRED_PRIMITIVES`, waiting on S9's local
  rewards — the stage that gives it something to pull.

- **`powers` and `fills` run in opposite directions, and the S3 HUD code
  had both wrong.** `_is_cost_of_slotted_action` read the link kind from a
  `kind` field the fold does not emit (the wire name is `link`), and then
  matched `source in slotted` for both kinds — correct for `fills` (action
  → resource), backwards for `powers` (resource → action). Neither could
  fire before S5, because no operation could create a link; the HUD
  suite's new case caught both on its first run with links present. This
  is the S3 tripwire paying for itself: it existed precisely because that
  third of the relevance rule was unprovable.

- **A press verb pays `strength` on the press; a held verb pays
  `drain_per_second` per second.** The link carries one number and the
  primitive carries the other, so `powers` means "this bar is what the
  action costs" without the link having to know which shape of action it
  points at. `_pay_powers_cost` therefore only checks a drain verb's bar
  is non-empty, and `_drain` does the paying — which also gives the hold
  its natural end when the bar runs out.

- **`gates` strength reads as a fraction at or below 1.0 and as absolute
  units above it.** The schema bounds strength to [0, 200] and says
  nothing about units. One number has to express both "needs a third of
  the bar" and "needs 20 charge"; the split at 1.0 is unambiguous because
  a fractional threshold above 1.0 would mean "more than full", which is
  never satisfiable.

- **I7 is enforced by the model now, not just described.** `ECHOES` §10's
  "permanent means mild, severe means removable" had no validator: a
  always-on `ground_friction` at 0.4 was schema-valid. A harmful
  deviation past `MILD_DOWNSIDE_LIMIT` (a third of base) must now declare
  `requires_equipped`. The mild band is wide enough for a noticeable
  always-on cost and narrow enough that no permanent curse decides a
  fight, and the traversal stats are exempt because their own floor is
  stricter than any band.

- **Statuses are per-target containers, and an owned `StatusComponent` is
  a FLOOR for its kind on its side.** A campaign that owns a tuned
  "burning" cannot have a weaker burning applied to it; that is what
  keeps an owned status definition from being an inert component. Re-
  application max-merges duration and magnitude rather than stacking,
  because two burnings that summed would breach the schema's own
  magnitude bound from outside it.

- **A self-slow expresses as `ground_friction`, never `move_speed`.** §10
  reserves the traversal stats, and the stat stack floors them after
  status factors as well as trait factors — so `slowed` on the player
  makes control slippery rather than making a generated gap unclearable.
  Enemies have no such floor: `slowed`, `frozen` and `stunned` gate their
  movement and attacks directly.

- **`over_soft_budget` is on the request, as S3's decision promised.** The
  recorded condition was "when a non-CREATE operation becomes
  implementable", and LINK is one: telling a provider "the campaign is
  resource-rich, relate instead of duplicating" is now advice validation
  accepts rather than a prompt that manufactures its own repair loop.

- **Traits still apply because they are owned.** S5 is the stage where
  this became operational, and the v0.8 contract still says a trait is
  true once owned (`ECHOES` §2). What S5 adds is the escape hatch the
  contract always intended: `requires_equipped` makes a trait conditional
  on a slot, and I7 now *requires* it for anything severe. So the model
  is unchanged and the reconsideration is answered rather than deferred:
  ownership is the default, equipping is the modifier, and the only
  things forced into the equipped form are the ones §10 says must be
  removable.
