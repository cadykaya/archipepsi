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
