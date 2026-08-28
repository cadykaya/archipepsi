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

## S6 — dispositions

- **A disposition is checked twice, and the two checks answer different
  questions.** The fold has always refused a dangling target (I11), and
  that stays: it is what makes a corrupt log unrepresentable. But before
  S6 no provider could emit an operation that reached backward, so a bad
  target was not a shape a generation could take. Now it is the likeliest
  way one goes wrong, and a `FoldError` raised while building the save is
  the wrong failure: it skips the repair loop and answers a recoverable
  mistake with a refused campaign. `target_errors` runs at generation,
  next to `budget_errors`, and names the id — so the provider gets one
  chance to fix it. `test_dispositions.py` asserts the two agree, because
  an early check that passed something the fold rejects would be worse
  than no early check at all.

- **The request carries upgrade HEADROOM, not just field names.** The
  fold re-validates every upgrade against the target's declared bounds
  and refuses one that would walk a value out of range — deliberately, so
  a value cannot escape its range one small step at a time. A provider
  without the range can only guess at the one number it must not guess
  at, so `OwnedComponentSummary.upgradable` carries `(field, current,
  minimum, maximum)`, read out of the models themselves by
  `upgradable_field_info` rather than a hand-kept table. A schema that
  tightens a bound tightens the request in the same commit.

- **The owned component graph landed at S6, not S10.** S1 recorded that
  the full request — owned components, aliases, budgets — belongs with
  the interpretation pipeline, on the grounds that context no rule uses
  is just a longer prompt. That reasoning is intact; what changed is
  which rules use it. The budget steer landed at S5 and the graph lands
  here, each at the stage where an operation could finally obey it. A
  disposition that cannot see its target is not a disposition.

- **The fallback works from the request, like every other provider.** The
  first cut of `_as_sequel` read the live fold, which was wrong in a way
  the integration run caught immediately: `FallbackEpsilonProvider` is
  invoked through the provider protocol, which passes a request and
  nothing else, so the sequel path never fired in a real campaign. It
  reads `player_state.owned_components` now. That is not a workaround —
  it is the constraint every provider is under, and the fallback being
  under it too is what keeps it an honest oracle.

- **Evolution is semantic, never textual.** ECHOES §11 says ancestry is
  about verbs, not names, so the fallback's family key is the primitive
  for an action and the stat for a trait. *Hookshot* and *Longshot* are
  one grapple because both resolve to `grapple_to_surface`. Two names
  were added to the grapple bucket (`longshot`, `clawshot`) and the
  generic "claw" bucket now yields to the specific one — this maps names
  to verbs, and those names mean grapple. The shipped fallback therefore
  reproduces §11's own worked example, and the mock campaign ends with
  seven components at Mk II or better and a provenance chain four items
  long.

- **Identity packages are pinned but not unique.** §12 derives glyph,
  accent, sound family and particle style from the game name by the
  shared sha256 rule. With six sound families and six particle styles,
  two worlds can collide on both — Ocarina of Time and Dark Souls do —
  and nothing in §12 promises otherwise. What the suite holds is
  determinism per field and that the *package* still separates them,
  which it does on the glyph. Sound is a pitch shift of the shared
  procedural bank rather than a second sample, and particle style is
  tracer width and lifetime: no asset, no copyright, and both languages
  pinned to the same indices.

- **"A component per interpretation" stopped being true, on purpose.**
  The integration run asserted the fold produced at least one component
  per interpretation — reasonable when every interpretation created
  something, and false the moment one evolves instead. It now asserts
  what that check was reaching for and could not say before: every
  interpretation's sequence appears in some component's provenance.
  Nothing dropped, nothing double-counted, and it holds whether an
  interpretation creates, upgrades, links or merges.

## S7 — slots and loadout

- **One `EchoRuntime` per slot, built where the nodes are made.** Cooldown,
  held state and the airtime budgets belong to the Action, so four buttons
  need four runtimes: sharing one would let a dash and a grapple contend
  for a single cooldown, which is the exact bug four slots exist to make
  impossible. The first cut collected them with an `@onready` tree read
  and came back empty — a player with no working Echo buttons at all, in
  production, silently. `create()` fills the map as it makes each node
  now, and the S7 suite asserts one runtime per slot with none shared.

- **`SLOT_NAMES` moved to `constants.py`.** The client builds a runtime and
  binds a key per slot, so the count is a cross-language fact and belongs
  where the exporter can see it. `echo.py` re-exports it; the `SlotName`
  Literal still has to be spelled out because a type cannot be built from
  a runtime tuple, so a test asserts the two spellings agree.

- **The S1.1 slot collapse is retired, and the property it protected is
  now the gate's job.** `ARCHETYPE_SLOT` mapped every v7 archetype onto
  `echo_a` because one button was bound; its comment named S7 as the
  expiry, and this is S7. A migrated Hookshot goes back to `mobility`,
  where a v0.7 player would look for it. What the collapse was really
  protecting — nothing lands where no key reaches — is asserted directly:
  every value in `ARCHETYPE_SLOT` must be in `IMPLEMENTED_ACTION_SLOTS`.

- **`IMPLEMENTED_ACTION_SLOTS` is the whole contract now**, which cost the
  S1.1 vacuity guard its example. That test asserted the capability
  registry was a *proper* subset of the contract, using slots as the
  witness; slots stopped being one, so the guard rests on component kinds
  and the primitive catalog, both still genuinely narrower.

- **Favourites are a client preference, not campaign state.** They appear
  in the prose (§9, DESIGN §15.4) and nowhere in `schemas/`, which is the
  binding contract — and correctly so: a favourite changes nothing
  mechanical, no rule reads it, and losing the list costs a preference
  rather than a capability. So they live in `user://loadout.cfg` beside
  the keybinds, never touch the save, the interpretation log or the
  bridge, and are keyed by component id, which the fold keeps stable
  across an Action's whole evolution.

- **One favourite does not narrow the wheel.** Cycling a single-entry set
  lands back where it started, which reads as a broken wheel rather than
  an unconfigured one, so the narrowing needs at least two.

- **The viewmodel belongs to the highlighted slot.** Four runtimes and one
  viewmodel mesh: each runtime paints it only while its slot is
  highlighted, or they would fight over the same node every time any of
  them changed. Firing a slot highlights it, so the gun in your hands is
  always the one you last used.

- **Shields add across slots.** Two Echoes granting a shield each read as
  two, and a hit eats both before reaching hp. `total_shield()` is what
  the HUD reports; the single-runtime `shield_hp` it used to read would
  have shown whichever slot happened to be highlighted.

## S8 — the Echo Lab

The build brief for this stage (`docs/proposals/S8_ECHO_LAB_BUILD_BRIEF.md`)
was written in parallel by ChatGPT / GPT-5.6 Sol against the S6 tree and
cherry-picked here. It was read as a checklist against the live S7
interfaces rather than implemented from; its boundaries all hold, and two
of its traps turned out to be exactly right.

- **The Lab is a room, not a mode.** It is an annexe off the Hub's west
  wall, reached by walking through a doorway. That makes "base movement is
  always enough to leave the Lab" structural rather than a rule someone
  has to maintain: there is no transition to be stranded inside, no view
  to fail to exit, and no Zone state to consume. It also means the Lab
  cannot allocate, claim or fake a Check, because nothing about entering
  it goes near the bridge.

- **The dummy cannot die, and that is mechanical.** The brief flagged this
  and it is sharper than it first sounds: since S4 a rule may fire on
  `kill`, and the shipped fallback produces `kill → resource_add`. A dummy
  that died would let the player stand in the Hub farming the economy the
  Lab exists to inspect. It clamps at 1 hp, reports the damage, and never
  returns true from `take_damage`. The suite asserts all three, and that
  the damage still counts — a dummy that ignored damage would also never
  report a kill.

- **Fixtures are adapters, never copies.** The dummy answers `Enemy`'s own
  `take_damage` signature and wears a real `StatusEffects` on the enemy
  side; the hazard calls `player.take_damage`, the entry point enemies
  use. The suite proves the hazard went through it rather than writing hp
  — a shield absorbs a strike, and a `damage_taken` trait doubles one —
  because a hazard that touched hp directly would silently test nothing
  about shields, block, statuses or any low-health rule.

- **Reset is a workbench control, not a save operation.** It returns dummy
  health and statuses, the moving target's phase, the hazard's armed
  state and the player's HP and statuses to baseline. It does not touch
  the interpretation log, folded ownership, provenance, Mk levels, slots
  or favourites, and the suite fingerprints all of that either side of a
  full session to prove it.

- **`sent_intents` on the client, rather than a test-only hook.** The
  Lab's load-bearing property is a negative one — it must never talk to
  the bridge — and a negative is only worth asserting if the assertion
  can fail. A bounded log of what the client sent answers "did this
  subsystem talk to the bridge at all" for any subsystem, without a seam
  that exists only for tests. Proven by making the Lab send one.

- **A rotated room needs `global_transform * point`.** The Lab is placed a
  quarter turn round so its doorway faces the Hub corridor, which made
  `global_position + local_offset` land somewhere else entirely — the gap
  recovery put the player outside the room. Caught by the suite on its
  first run.

- **The "chamber updated" notice is session-local.** §17's joke is worth
  one line and not worth a new column in the save, so the announcement
  fires from owned vocabulary within a session and is not remembered
  across restarts. The fixture registry it drives is the seam S9's water
  volumes, rails and anchors attach to.

- **S9 was deliberately not pulled forward.** No affordance registry, no
  local rewards, no Info readouts, no `pull_pickup`. The Lab is finished
  when the vocabulary that exists has a safe deterministic place to be
  understood.

## S9 — affordances, local rewards, Info readouts

- **The generator names a fraction; the client owns the metres.** An
  `AffordanceFeature` carries `at: (u, v)`, both in 0..1, and nothing
  else about where it goes. `affordance_features.gd::resolve_position`
  turns that into a position, and pushes it clear of the walking lane
  whatever it was handed. This is the same division `ZoneBuilder` already
  makes for layout, and it is what makes §13.2 structural: a generator
  that could name a coordinate could name one in the exit lane, so it
  never gets to name one.

- **I4 is enforced in two places because it means two things.** The
  schema half — no feature in a chamber holding a Check, none on a gating
  objective — is a `Zone` model validator, so no provider can emit one
  and no caller has to remember to check. The metre half — no feature in
  the walking lane — only exists where metres do, so it lives in the
  builder and is pinned from Python by reading the GDScript
  (`test_affordances.py`), the same way the HUD palette is pinned.

- **A room too narrow for a feature gets none.** A corridor barely wider
  than its door is *entirely* walking lane; pushing a feature out of the
  lane would push it into the wall. `AffordanceFeatures.fits(width)`
  says so and `place_all` drops the features rather than building them
  somewhere wrong. Optional content is allowed to be absent; it is not
  allowed to be in the doorway. The suite's lane sweep found this — the
  first version happily placed a bounce pad 0.6 m outside a 4 m room.

- **A corridor carrying a feature has a minimum width, and it is
  validated.** The first version left the builder to drop what it could
  not place, and the integration run caught the consequence immediately:
  the fallback's plain chambers are corridors, corridors are the
  narrowest type, and every feature it offered was silently discarded —
  a Zone that read richer than it played. `MIN_FEATURE_CHAMBER_WIDTH`
  now refuses such a chamber at validation, where the repair loop can
  widen it, and the fallback widens its own connectors before hanging
  anything on them. The constant is `2 * (LANE_HALF_WIDTH +
  MIN_CLEARANCE)` and is pinned against the GDScript from both sides.

  Worth noting why the corridor is the only case: every other chamber
  type carries either a Check or a gating objective, so §13.2 already
  bars features from all of them.

- **An `AffordanceComponent` grants its tag outright.** §13.1's table
  names the derived capability that makes each tag interactable, and this
  component kind *is* that capability rather than a proxy for it. Before
  this, an Echo reading "you can grind rails now" owned a component that
  unlocked nothing. `owned_affordance_tags` now honours a direct grant,
  an owned primitive, or an owned stat — still over OWNED mechanics,
  never slotted ones, so a Zone does not change meaning when the player
  opens the loadout.

- **Movement volumes are a layer on the player, not writes into the stat
  stack.** `_refresh_derived_stats` rewrites every multiplier from the
  fold each physics frame, so a volume writing into those fields would be
  either erased or permanent depending on frame order. `enter_volume` /
  `exit_volume` keep an influence per overlapping volume and
  `environment_influence()` merges them after the stack, lasting exactly
  as long as the overlap. A volume freed while the player is inside it
  releases its own influence — otherwise a Zone teardown would leave the
  player permanently swimming.

- **No volume may trap you.** Lift is upward-only, drag is capped, and
  speed has a hard floor (`MIN_VOLUME_SPEED_SCALE`). §13.2 keeps features
  off the mandatory path, which is enough for geometry; it is not enough
  for a volume, because a volume you cannot leave would strand you
  wherever it was. The floor is what makes "the base kit is always
  enough" true of volumes too, and the suite presses on it from below
  with a volume asking for zero.

- **The breakable wall's threshold is per-hit, not cumulative.** §13.1
  pays for `breakable_wall` with an action that can deal impact damage
  *at or above a threshold*. A cumulative pool would let a long enough
  Static Pulse burst open it, and the capability that was supposed to pay
  for the affordance would never have mattered. `MIN_IMPACT` is defined
  against `STATIC_PULSE_DAMAGE` so the two cannot drift apart.

- **Info readouts observe; they are never told.** Damage numbers watch
  enemy hp fall rather than receiving a signal from `Enemy`. A signal
  would point the wrong way — §14.1 says an Info component never alters
  the world, and the cheapest way to keep that true is for the world not
  to know the readout exists. Watching also cannot miss a hit that some
  future damage path forgets to announce. `report_damage` remains for
  things that are not `Enemy`s.

- **`resource_forecast` asks the runtime instead of reimplementing it.**
  `EchoRuntime.can_activate()` answers exactly the questions `activate()`
  asks, spending nothing and charging nothing. A forecast that worked by
  attempting the press would be the one thing §14.1 forbids, and a
  forecast with its own copy of the cost rules would drift away from what
  pressing actually does.

- **`local_rewards` is on the snapshot, and never in the fold.** A local
  reward derives no mechanic, so it has no business in `Mechanics`. But a
  note you found stays found, and the client is what has to stop drawing
  a pickup already claimed — so the save's list is mirrored onto the
  snapshot. Both halves are asserted.

- **The chamber suite is booted now, not `--script`ed.** Chambers build
  affordance features, which reach the player, which reaches
  `BridgeClient`; none of that compiles in a run that never instantiates
  the autoloads. The symptom was exactly what the Makefile guard was
  written for: `GODOT CHAMBER TESTS OK` printed by a suite that had
  loaded nothing. The guard caught it; the fix was to boot the project
  like every other suite.

- **Nothing is gated any more.** `pull_pickup` was the last deferred
  verb and S9 implemented it, so `DEFERRED_PRIMITIVES` is empty and every
  capability registry equals its contract. That leaves the gate
  mechanism with nothing to refuse, which is one refactor from being
  deleted — so three tests now narrow a registry by hand and watch it
  refuse (`test_stage_tripwires.py`, `test_schemas.py`,
  `test_s1_review_fixes.py`). `validate_interpretation` already took
  `implemented_primitives` as a parameter; that seam is what they use.

## S10 — the interpretation pipeline

- **The mode is a fact, not a preference.** §15 says modes are
  "influenced by" the creativity setting, and the first draft read that as
  a ceiling: creativity 0 forbids `systemic`. That is wrong in a way worth
  recording, because the wrongness is not obvious. A ceiling has to do
  something when an interpretation exceeds it, and the only two options
  are to reject an otherwise-perfect Echo, or to relabel it — and
  relabelling makes the archive misdescribe the thing in the player's
  hands. The mode is shown as "how Epsilon read it", so it has to stay
  true. The influence therefore lives in the request as
  `preferred_modes`, exactly like `over_soft_budget`, and
  `mode_for_operations` takes no creativity argument at all.

- **Concepts are validated for attachment, never for taste.** There is no
  correct reading to check a provider against: "Master Sword reads as
  heroism" and "as obligation" are both defensible, and a validator with
  an opinion would make every provider a worse version of
  `read_concepts`. So `reading_errors` refuses exactly two things — an
  empty reading, which breaks §15's chain outright, and one sharing no
  vocabulary with the item or its game, which is not a reading of *this*
  item. That second case is the real failure mode: concepts pasted from
  another Echo.

- **The lexicon reproduces §15's own worked examples.** *Water Tunic*,
  *BLJ* and *Master Sword* are the only worked examples of the reading
  step anywhere in the contract, so the deterministic reader has to get
  them right or the documentation describes behaviour the code lacks. A
  companion test asserts those three items are still the ones the prose
  uses — `check_packet.py` compares identifiers, not worked examples.

- **The reading is stamped after the operations are settled.** The mode is
  derived *from* the operations, so choosing it up front would describe a
  draft rather than the finished Echo. `_read_and_label` runs last in
  `fallback_echo`, after `_as_sequel` has had its chance to turn a CREATE
  into an evolution — which is exactly the case where the mode changes.

- **Affordances are budgeted in distinct tags, and the budget is
  currently unreachable.** §16 says "Distinct affordance tags" and the
  unit is load-bearing: a tag is a capability, so two Echoes both
  granting `rail` add one vocabulary rather than two, and counting
  components would charge the player twice for a redundant grant. Only
  seven tags exist, so soft 8 / hard 12 cannot fire today. That is the
  right shape for a budget — better than a number that fires for the
  wrong reason — and a test states it, so a growing catalog reports in
  rather than silently going live.

  Both the steer (`budget_headroom`) and the refusal (`budget_errors`)
  count it, in two different functions, so both are proven. The refusal's
  half needed the budget narrowed by hand to be observable at all, the
  same seam-narrowing the primitive-gate tests use — without it the
  refusal could count components while the steer counted tags and every
  real-data test would still pass.

- **`budget_headroom` replaces guessing.** `over_soft_budget` says which
  kinds are crowded; a provider deciding whether one more resource is fine
  or is the sixteenth needs `[owned, soft, hard]`, and guessing wrong
  costs a repair round.

- **`relevance_hint` puts §15's rule in a sentence.** The owned graph has
  been in the request since S6, but a graph is a list; this is the line
  that says what to do with it ("already well supplied: hitscan_damage x3;
  prefer a new relationship..."). Empty on a fresh campaign, where there
  is nothing to relate to and steering toward a disposition would push a
  provider at an operation that cannot validate. The specific half leads,
  because `MAX_TEXT_LEN` is 160 and the generic sentence alone nearly
  fills it — the first draft truncated away the only part a provider
  could act on.

- **Mock Epsilon reads aloud; it does not invent.** It shares one
  validated vocabulary with the fallback — a mock that could express more
  would be testing a game nobody ships. What it adds is the reading: the
  concepts, the mode, and a description that states both. That is the half
  of §15 the fallback deliberately does not do.

- **The archive shows the mode.** It was worth nothing before S10, since
  every interpretation said "literal" because the fallback hardcoded it.
  Now it is derived, so the row reads "read systemic: tension / reach" and
  tells the player how far Epsilon travelled from the item.

## Adversarial review of S9/S10 — what it found and what changed

Two review passes over the S6–S10 code, one on the client and one on the
bridge. The findings that changed a design decision rather than a line:

- **The affordance geometry was designed for a room that cannot exist.**
  The single deepest finding. Every other chamber type carries a Check or
  a gating objective by construction, and §13.2 bars features from both —
  so **the only chamber that can ever host an affordance is a corridor**:
  5–10 m wide, with a 3.6 m ceiling. The first version was written and
  tested against an 18×20 arena with a 6 m ceiling. Four of the seven
  rewards sat above the corridor ceiling where nothing could reach them,
  the breakable wall's alcove was outside the room behind masonry that is
  never removed, and the whole suite passed because it built the arena
  too.

  The rework: per-tag footprints (`FOOTPRINT`), the lane rule applied to a
  feature's whole extent rather than its origin, per-tag width and depth
  requirements on both sides of the language boundary
  (`FEATURE_MIN_WIDTH`), and a corridor that is **built to the height its
  features declare** rather than clamping features to whatever fits. The
  suite now builds the narrowest legal corridor for each tag, which is the
  room the feature will actually be in.

  `required_width` counted the feature's reach once and needed to count it
  twice: the origin has to clear the lane by a reach *and* stay a reach
  inside the wall, so only a width covering both leaves anywhere to put
  it. That arithmetic slip let an anchor poke out through a wall.

- **"Damageable" was missing as a concept.** Every damage path tested
  `is_in_group("enemies")` before dealing damage, which was fine while
  enemies were the only thing that could be hurt. The S9 breakable wall —
  an affordance whose entire contract is that it opens to a hard enough
  hit — was in no such group, so nothing in the game could deliver a
  single point of damage to it and `BreakablePanel.take_damage` was
  unreachable code. `Damageable` now names the question the damage paths
  actually mean. Target *selection* still asks the narrower one:
  `scan_mark` marks enemies and `grapple_pull_target` pulls them, and
  neither should reach for a wall.

- **A validator that is wrong in both directions should be deleted, not
  tuned.** `plausible_concepts` refused a reading sharing no vocabulary
  with the item. It passed `art`/`row`/`here` for every item in every
  game (substring matching against an unconditional seed), and it refused
  "Master Sword reads as obligation" — the exact kind of reading §15
  argues *for*. Attachment is not decidable from an item name. The gate is
  gone; the function survives as a diagnostic the lexicon's own tests use.

- **An advertised bound must be one the model will honour.** See the S10
  section above and `test_upgrade_headroom.py`: the field said 4.0, the
  model said 1.0, the fallback believed the field, and the resulting
  `FoldError` could not be retried past.

- **A mode has to be earned.** A link whose two endpoints the same
  interpretation created adds a self-contained thing; calling it
  "systemic" made the archive describe an Echo that touched nothing the
  player owned. Every resource-bearing fallback outcome was affected.

- **`challenge_marker` is a decision, not missing code.** §14.2 calls it
  "an optional timed or scored challenge" and §14.1 gives it a readout,
  but neither says where a run starts, what ends it, or what counts as
  one. The bridge half is complete and tested — the kind is grantable,
  recorded, and `best_seconds` only improves. The world half is not built,
  because building it means inventing a mechanic the contract does not
  describe. `test_the_challenge_marker_still_has_no_challenge` names the
  decision and comes due when it is made.

- **A claimed reward has to stay claimed.** The save recorded local
  rewards from S9 and the snapshot mirrored them from S10, and nothing
  read the mirror — so a note picked up reappeared on every re-entry and
  the bridge silently discarded each re-report as a duplicate. A reward
  that looks repeatable and is not is worse than one that is simply gone.

- **`preload` over runtime `load` for the test drivers.** `--import`
  walks the dependency graph from scenes and autoloads; a driver reached
  only by a runtime `load()` is not in it, so a parse error in one
  survived a green import and surfaced four minutes into an integration
  run. Two other approaches were tried and rejected: `--check-only
  --script` reports an error for every driver whether or not one is real
  (no autoloads), and parsing each file's source into a detached
  `GDScript` gives false positives on any cross-file `class_name`
  reference.

## The S1–S5 adversarial review

Three passes over the parts the staged reviews never reached: the fold and
the save on the Python side, then the five runtime engines on the client.
Nineteen findings, all fixed, each sabotage-proven. The ones that changed a
rule rather than a line:

- **A migration must be total in the version it targets, not just in the
  version it reads.** v7 bounded each Echo alone and let a passive make you
  slower; v8 traits are always on and stack, so I3's floor forbids it. The
  migration copied the multiplier across and produced a save v8 refuses —
  which made the migration a partial function on legal input, and the whole
  point of calling it "pure and total" was that it is not. `traversal_multiplier`
  clamps into the floor and keeps the Echo rather than dropping it: the
  interpretation log is provenance, and a campaign that silently lost an
  Echo to a version bump would fold differently than it played.

- **"Unreadable" and "absent" must not be spelled the same way.** That is
  what turned a refused migration into a destroyed campaign: `load_save`
  returned None for both, the engine reads None as "no campaign here",
  and the next write moved the player's real save into the backup slot.
  `SaveUnreadable` separates them. The atomic-write path was wrong in the
  same direction — the backup was RENAMED aside before the install, so a
  crash between the two renames left no primary at all. It is copied now,
  and any non-primary recovery heals the primary immediately, or the next
  write promotes the wreck.

- **A merge rewrites stored edges; it does not resolve them later.** The
  alias table catches every later *mention* of an absorbed id, and a link
  written before the merge is not a mention — it is a stored edge, and it
  kept naming a component the fold had just deleted. Two ways out existed:
  teach four call sites in two languages to alias-resolve, or rewrite the
  edges once at the merge. The second is the only one that makes the
  client's own comment true, and `stat_stack.gd` could not have done the
  first anyway — it keys a dictionary by raw id.

- **Enforce what the clients already assume, or they will assume it
  wrongly.** `echo_runtime.gd::_powers_link` returns the first `powers`
  edge aimed at an Action and never looks again; `stat_stack.gd` keys
  `scales` by target. Both are at-most-one-per-target contracts that
  nothing enforced, so a second edge was discarded by fold order. The fold
  refuses it now, and `target_errors` refuses it a step earlier, so a
  provider gets a repair prompt rather than a crash. `fills` and `gates`
  stay many: both clients iterate, and the graph in ECHOES §4 is meant to
  express several actions feeding one bar.

- **Every operation kind needs a landing check, not just UPGRADE.**
  `_upgrade_lands` existed because a `FoldError` inside
  `append_interpretation` is a crash rather than a repairable rejection,
  and repeats on every retry so the Check can never be granted. MODIFY had
  only an existence check and MERGE never asked where `max_value` landed —
  five reproduced refusals, and `capacity` **defaults** to `"sum"`, which
  makes the merge case the likeliest rather than the rarest.

- **A refund gives back everything the attempt took, including time.**
  `spend` arms `regen_delay`; `refill` does not disarm it. So the rule
  engine's pay-then-refund cost path charged a regeneration window for
  every FAILED attempt — and an armed edge event dispatches every physics
  frame, so the window was re-armed sixty times a second and regeneration
  stopped dead on a rule that never fired. Checking the whole cost list
  before touching anything (`spend_all`) means a refusal leaves nothing to
  undo, which is better than undoing it well.

- **A press that did not resolve did not happen.** `_refund_press` gave
  back the cooldown and nothing else: the `powers` cost stayed spent, the
  `fills` link still paid out, and `action_used` still fired. A `fills`
  link therefore printed resource from refused presses with the cooldown
  handed back each time. The refund is complete now and the whole tail of
  `activate()` is skipped, because `action_used`'s own documentation calls
  it "a press that genuinely resolved".

- **Shared player state written by four slots has to be derived, not
  assigned.** `hover_gravity_scale` was written by whichever runtime spoke
  last, so one slot's key-up cancelled another's hover while that slot went
  on paying its drain. It is now the strongest claim among the slots that
  are actually hovering. This is also an I3 concern: `clamp_stat` floors
  `gravity_mult`, and `hover_gravity_scale` multiplies in afterwards where
  the stat stack never sees it, so a hover stranded by a slot swap was
  permanent zero gravity.

- **Merging two dimensions independently merges neither.** Status
  re-application takes the max of durations and the max of magnitudes; taken
  apart, a feeble long application inherited a brutal short one's magnitude
  for its whole life. The stronger application wins outright and keeps its
  own duration; a longer weaker one holds only the tail.

- **An edge latch belongs to the value that made it.** `crossed` and
  `holding` were per event KIND across every resource, so any full bar kept
  alive a latch armed by a different bar. And none of it reset on Zone
  entry, though I9 resets everything it is derived from.

- **A "skip" that always skips the same thing is a starve.** The per-tick
  firing cap is correct; scanning `_rules` from a fixed offset was not, so
  with more rules on one event than the cap allows, the ones behind the cap
  never fired once. The scan rotates now.

- **A closed vocabulary the client cannot see is not closed.**
  `StatusEffects.apply` accepted any string, and an unknown kind was inert
  yet still satisfied `status_active` conditions and `status_applied`
  edges — and could never be cleansed, being in no cleanse order. The
  schema's `STATUS_KINDS` is exported to `constants.gd` like the primitive
  catalog, and `apply` refuses what is not in it.

- **`cleanse` is aimed at a side, so its severity order is per side.** It
  is only ever cast on the player, and the order was written as if for an
  enemy: `stunned` and `marked` spent charges on statuses nothing on the
  player reads, while outranking `vulnerable`. Worse, `low_profile` was in
  it at all — `enemy.gd` reads that as the player's stealth.

- **A generated artifact needs its generator in the tree.** The rule
  suite's snapshot claimed to be "a REAL fold on the Python side" and was —
  but the generator was scratch tooling that did not survive, leaving a
  generated file with no source and nothing stopping the next hand-edit.
  `make rules-fixture` and `make verbs-fixture` build both, and a bridge
  test regenerates in memory and compares. The old fixture's every channel
  had `regen_per_second` 0, which is exactly why its all-or-nothing cost
  test could not see the refund bug.

One note from the review was **not** taken. `release_location` delegating
to `abandon_zone` on the last location was called a trap for the next
caller. It is deliberate, two tests pin it by name, and a Zone record
holding no locations is not a state this schema has — `holds_locations` is
what ACTIVE means — so the alternative is a refusal that wedges the one
caller it exists for. The docstring now says so, since the call site could
not.

## A vocabulary nothing speaks is not a vocabulary

S6 was called complete when `UPGRADE` / `MODIFY` / `LINK` / `MERGE` were
admitted by the capability registry, checked by `target_errors` and folded
by `derive_mechanics`. All three were true, and no provider in the tree
emitted a `MODIFY` or a `MERGE` — so half the vocabulary was reachable
only from a unit test.

The cost is not the missing feature. It is that **any bug in either path
was invisible to every integration run**, and the merge-link bug fixed the
same morning proves it: the fold published links naming a component it had
deleted, and no amount of playing the game could have found it, because
nothing in the game ever merged. A stage is not done when its validators
admit a shape; it is done when something a player uses produces one.

Three rules came out of the fix, and they generalise past this stage:

- **A disposition is derived from the reading, not matched on the name.**
  The enhancement's status comes from the §15 concept reader — `fire` →
  `burning`, `cold` → `slowed` — so the same machinery that decides how
  Epsilon *read* the item decides what the item *does*. Pattern-matching
  "Fire Flower" would have been shorter and would have made §15's chain
  decorative for the one provider that runs deterministically.

- **Whatever decides whether an operation can land has to be in the
  request.** `OwnedComponentSummary` carried `upgradable` because an
  UPGRADE needs its target's bounds; it did not carry `modifiers`, so a
  MODIFY could not tell whether the type it was adding was already there
  or would be a third. A provider is a provider: it sees the request and
  nothing else, and one that has to guess at the exact thing the fold will
  refuse it for is one that emits `FoldError`s. The confluence needs the
  survivor's `max_value` headroom for the same reason.

- **Each disposition returns nothing when it cannot land.** That is what
  keeps the ordinary CREATE as the floor, so adding a disposition can only
  make the fallback richer and never invalid — the rule `_as_sequel`
  established in S6, applied twice more.

The confluence appends its merge rather than replacing the interpretation,
which is what lets it work on the fallback's real resource shape (`create
action + create resource + link powers`). The link then names the bar the
merge absorbs, and the fold rewrites both endpoints onto the survivor —
the same `_relink` written that morning, exercised end to end by a path
that ships.

## A soak is the only way to test an ordering

`make godot-integration` plays a whole campaign, and always the same one:
`MockAPBackend` hard-coded `"MockSeed"`, and the seed is the only input to
the track order, the shop's stock draw and the allocator's shuffle. Every
property that run asserts held on exactly one arrangement of thirty
locations.

`test_campaign_soak.py` plays twenty-five, in 23 seconds, because the
campaign engine is the whole subject and Godot is not needed to drive it.
What it asserts is deliberately not "the campaign completes" — it is the
set of things that must be true of EVERY campaign: one live Zone may hold
a location, never two; a Check is claimed once; a location yields one
Echo, ever, because the log is append-only and a duplicate is permanent;
the allocator never starves while unallocated locations remain; the save
validates after every transition rather than only where a test looks; and
the fold publishes no edge naming a component it deleted.

