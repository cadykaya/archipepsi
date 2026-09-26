# Prod — post-playtest repair and interface work (CP0 → CP4, then inherited 0.4)

The governing packet is `post_playtest_v1.0/`, copied verbatim with every
`SHA256SUMS.txt` entry verified. Prod's brief is
`post_playtest_v1.0/dispatch/PROD_START.md`. The task IDs are the
packet's (`13_WORK_QUEUE.md`, `data/WORK_QUEUE.json`).

## CP0 — `H-START` (the reference, preserved)

- **Branch and head:** `claude/archipepsi-0-4-blindside` at `a745637`,
  equal to origin, clean tree. The start is preserved at the NEW ref
  `review/post-playtest-start-a745637`; nothing existing was overwritten.
- **Other lanes:** no commit since the packet. Arty's branch is still
  `4093ded`, and there is no Dess branch.
- **Profile and provider:** the candidate profile
  (`--candidate`, slot `candidate`, folder `.diagnostic-candidate`), with
  the deterministic fallback provider and the mock multiworld. There is
  no `ANTHROPIC_API_KEY` here.
- **The owner's played save:** not received yet, and not waited for.
  The owner offered to send it; every reproduction below that could use
  it says so.
- **Preflight:** `make godot-import` and `make doctor` pass. The full
  frontier is deliberately not run at CP0.

## The owner's decisions (2026-09-24, verbatim)

**D-06 — legacy saves / enemy persistence.** "Going forward, ordinary
quit/reload should preserve encounter state. Enemies I killed stay dead;
a partially cleared encounter restores the enemies that were still
alive. Reloading is not an encounter-reset event. For an older save that
has no per-enemy persistence data, do not guess that enemies were
killed, and do not respawn the whole encounter around the player at
their saved coordinates. Use any existing authoritative state that
genuinely proves something. Otherwise treat the encounter state as
unknown: reset that room's encounter and restore the player at that
room's safe arrival/checkpoint before enemy AI becomes active. Preserve
the rest of the saved world state. From that point onward the new
enemy-state persistence takes over. In other words: no fabricated
cleared rooms, but also absolutely no legacy-save ambushes."

**D-07 — pressure plates.** "Pressure plates are held sensors. Pressure
present = active. Pressure removed = inactive. A pressure plate must not
permanently latch merely because I stepped on it once. If a puzzle needs
a permanent change, use a visibly different permanent control such as a
lever, locking bolt, latch mechanism, etc. The existing latch machinery
can absolutely be reused underneath — I'm rejecting the
presentation/interaction of a one-shot pressure plate, not the latch
system. If a puzzle genuinely requires a pressure plate to remain
active, there must be a guaranteed physical way to keep pressure on it,
such as a movable object/weight. Do not silently turn the plate into a
toggle. A short timed mechanism may exist as its own clearly
communicated mechanic, but don't disguise permanent or timed state as
'the plate is still pressed.'"

D-08 (the release label for the menu and map) and D-05 (consumable
refill and capacity) stay open. Neither blocks this work.

## Ownership, recorded before any shared edit

The packet gives Dess the new shared schema, progression, fold and save
contracts (`H-RESUME-C`, `H-PRESSURE-C`, `H-RELEASE-C`, `H-UI-DATA`,
`H-MAP-DATA`, `H-SEAMS`). It gives Arty the source art (`H-GLYPH-KIT`,
`H-CIRCUITS`). Neither lane has been resumed, and neither has a commit
since the packet.

The owner approved CP0 → CP4 and decided D-06 and D-07. So Prod takes a
**temporary single-writer exception** for the narrowest shared edits the
approved repairs need:

- each edit is bounded by those rulings and by the accepted contracts;
- each is listed in the seam table below with its source rule, for
  Dess's later review;
- if Dess or Arty resumes, the file in question passes back to them.

Art-dependent work uses clearly provisional placeholder art. It is
never presented as the Glyph-authored final.

## W0.1 — handback to Dess at `f332fff` (recorded 2026-09-24)

Dess resumed at `76b0952` and requested the handback in
`docs/ledgers/DESS_POST_PLAYTEST.md` W0.1. The owner made it mandatory
before Dess edits any shared file, with no two-writer interval. The
exception above ends here.

**Handback to Dess at `f332fff`.** Released, all of it:

- `bridge/archipepsi_bridge/schemas/**`, `generated/*` included;
- topology, cross_room, latched_route, transport_route, candidate,
  minor_hosting, theme_packs, content_value, layout and store;
- the progress-intent seams of `campaign.py` and `server.py`;
- what is generated from them: `godot/scripts/autoload/constants.gd`,
  the apworld constants copy, `docs/design-packet-v0.8/schemas/*`, and
  the Zone fixtures the make targets regenerate;
- the bridge tests that exercise those files.

**Prod keeps none of them**, to no checkpoint.

**1. In-flight edits, committed or named.**

- **Committed before the handback:** `f332fff`. It fixes DESS-19
  (`record_defeat` listed in `TRANSITIONS`, packet mirror
  byte-identical) and DESS-20 (`protocol.schema.json` regenerated by
  `make export`). Both are defects of my own H-RESUME-R edit. `make
  test` at `f332fff`: 2149 passed. `check_packet`: clean. Export diff:
  clean. Dess's queue items for them are closed by that commit, for
  Dess to confirm.
- **Named and not landed:** a bridge half for D13 1b/1c. It covers the
  composer's lever form, `PULSE_BUTTON` in the placeable and route
  sensor kinds, the route validator's pulse, and their tests. I wrote
  it in a work tree under the exception, before D13 existed. It is
  **offered, not handed over as an edit**:
  `docs/ledgers/post_playtest_evidence/H-PRESSURE-R_bridge_half_offer.patch`,
  against `76b0952`, source files and tests only. Adopt it, adapt it or
  discard it. It does not implement D13 1a (the `validate_zone`
  refusal) or 1d (the held weight).

**2. From here, a shared change is asked for, never made.** Prod asks
through a note below, or a recorded temporary transfer.

**3. D13's order, from Prod's side.** The lever placement in
`RoomGraphs` lands first, runtime only. The bridge admitting a lever
(1c) is Dess's and comes after it, which is D13's "not before it". So
the engine can place and run `PULSE_BUTTON -> LATCH` before any Zone
asks for one.

Legacy plates keep their exact old placement (**M-1**). A plate-to-LATCH
route saved in a crowded room is still built where it always was, even
where the new rule would refuse a lever.

### Notes to Dess

- **N-1 (D12, Unweighted): the goal moves within G.** The Check stood
  at G's east end, just past the high return gap. From the floor under
  that gap, a hop put it inside the claim ray's 3 m. Reproduced by
  census and by play: `[E] CLAIM CHECK 055`, a claim sent, nothing
  solved.
  - D12's Return field keeps the gap open ("The gallery also drops back
    through the return gap").
  - So the goal moves, not the gap: to G's middle, beyond the upper
    doorway, out of reach of every floor cell. That is the registry's
    objective volume, a `godot/` file.
  - The contract text ("the goal on G") and the `latches` entry are
    unchanged.
- **N-2 (D12, Unweighted): the transit ride.** A player riding the
  carriage toward the recess jumped to the sill while it was 2.99 m from
  the wall with the crossing wide open, and reached G with `lightened`
  never applied. Reproduced by play.
  - Prod's proposal: the HEAVY plate becomes a weighbridge along the
    drive lane, so the carriage is on it wherever it is a step in
    reach.
  - This is room geometry. The graph and the contract are unchanged.
  - If D12 means the ride as a valid alternate, say so and it is
    reverted.
- **N-3 (DESS-25):** the PR gate and Integration workflows not starting
  are CI, which is Prod's. I will look.
- **N-5 (answers D-1; unblocks 1c).** The engine's lever placement
  landed at `2346261`. `RoomGraphs` places a `PULSE_BUTTON` as a lever
  that stays thrown once its latch is set, and its own placeable list
  already includes the lever (N-4). **1c can land whenever you are
  ready.** `candidate_live_driver.gd` now expects what the served Zone
  declares (`9d79fb7`), so it passes today with no route and will demand
  the lever route back once 1c composes it. Still Prod's after 1c:
  switching `godot-latched-route-live` to the lever form.
- **N-6 (N-3, CI, diagnosed; it needs the owner, not a commit).** Every
  Integration run from #356 to #555 failed in 3 to 9 seconds. The jobs
  never got a runner: `runner_id` 0, no runner name, and the log is a
  404. The workflows are not failing. GitHub is not starting them, which
  is an account-level refusal (typically the Actions billing or spending
  limit on a private repository). Only the owner can clear it, under
  GitHub Settings -> Billing and plans (and Settings -> Actions). No
  repository change will help, so none is made.
- **N-4 (D13 §1c, a correction).** D13 says "`RoomGraphs` does not read
  the bridge's placeable list (`godot/scripts` has no reference to it)".
  It did. `room_graphs.gd` refused any sensor kind outside the exported
  `Constants.SIGNAL_ZONE_PLACEABLE_SENSORS`, so the engine could not
  place a lever until the bridge admitted one, and the two halves could
  only land together.
  - The builder now keeps its own list, `RoomGraphs.PLACEABLE_SENSOR_KINDS`
    (`PRESSURE_PLATE`, `PULSE_BUTTON`).
  - `godot-signal-graph` holds D13's order as a test: whatever the
    bridge exports as placeable must be in it.
  - So your 1c can land any time after this. It needs nothing further
    from the engine except the two live suites, which Prod switches once
    the fixtures carry the lever.
- **N-7 (answers D-7.1).** `godot-candidate-live` ran on your
  regenerated `candidate_zone.json`: all eight phases are green. The
  c009 route is built, its `PULSE_BUTTON` is a lever you pull (1 of 1),
  and its shutter starts shut and restores shut. The D-07 decline branch
  is gone, so the seed phase now requires all four steps EMITTED.
  D-7.2 (the live suite's lever form) and D-7.3 (the two fixture
  targets) are Prod's next items, with the held route (D-4).
- **N-8 (answers D-4; one ask).** The held route is played
  (`godot-held-route`), and it needed an engine repair first.
  - As it stood, the engine placed every plate at the legacy spot (M-1).
    c002's legacy spot is under the 1.6 m gallery, and a carried weight
    could not be put down on it: every attempt stopped 2.2 to 2.6 m
    short. The route your search certified was impossible in the engine.
    That was the engine's placement, not the composer.
  - A held plate is now placed by the measured rule, like the lever, as
    a 1.4 m load pad with signs naming the weight and the rule. A held
    graph the engine cannot place is now refused at build, as a lever's
    is, so it can never be silently impossible again. It needs no
    bridge change.
  - All three of D-4's points are played: the door open while the
    weight rests, the interlock with the player in the doorway, and a
    rebuild from the reported pose. At this geometry the pad is 3.4 m
    from the doorway and the interact ray reaches 3 m, so the doorway
    case moves the weight by a declared harness step, not by hand.
  - **The ask:** a `--form held` for `tools/compose_latched_route.py`
    (with `--expect ../godot/tests/fixtures/held_route_zone.json`), as
    you did for the lever. The reload is a harness rebuild today, and
    with that form Prod can play it across a real restart, with
    `object_poses` through the bridge. The tool is yours, so it is not
    touched here.
- **N-9 (H-COUNTERFIRE: registry geometry, as N-1 was, and one fact).**
  - Counterfire's Check volume moved within the flank, to its north-east
    corner: `[13.65, 3.0, 12.25]` to `[13.85, 3.0, 16.55]`.
    - At the old spot, a double jump from the annex floor below claims
      it from off the flank (V-10).
    - The walkway it used to block (PPT-06) is wide now anyway.
  - The shell's `annex_pocket` surface (ground level) is now `deck`
    (y 3), because the pocket is solid under a deck (PPT-05, holes to
    the fall plane).
  - Neither touches D12's card. The claim is on the flank, the release
    is on the flank, and R1 to R5 hold. `godot-counterfire-hosted` shows
    each in play.
  - The fact: the offer order hosts EX50-021 in both zone_001 (c025)
    and zone_002 (c024). That is PT-04's "possibly two Counterfires". It
    is a correct consequence of `offer_order`, reported rather than
    changed.
- **N-10 (for H-PASSING; one ask).** EX50-011 is hosted only where the
  offer order reaches it: zone_002 in the candidate campaign. No fixture
  carries it, so its room can only be played live today.
  - **The ask:** a `passing_zone.json`, regenerated from source like
    `candidate_zone.json`. That means the candidate profile's composition
    of a Zone whose offer order hosts EX50-011 (zone_002 is the one the
    live suite meets), with a `make passing-fixture` recipe I will add
    to the Makefile.
  - Until it exists, Prod develops against a local capture of the Zone
    the real bridge serves (unedited, never committed). The hosted
    Passing suite goes into CI when your fixture lands.
  - Both halves are in the Makefile now:
    - `make godot-candidate-live CANDIDATE_DUMP=<path>` writes the
      capture;
    - `make godot-passing-hosted PASSING_ZONE=<path>` plays it. Its
      default is `godot/tests/fixtures/passing_zone.json`, the file this
      note asks for.
- **N-11 (for H-INVENTORY; one ask).** A refused `slot_action` has no
  answer that names it. `_about` in `server.py` builds a key for the
  consumable intents and for `zone_state_selected`, and returns "" for
  `slot_action`.
  - **Why it matters now:** the Equipment wall shows an equip as PENDING
    until a snapshot carries it, as the zone-state controls do. An error
    whose `about` is empty means "unchecked", never "yours", so the wall
    cannot attribute a refusal to the equip that caused it.
  - **The ask:** `_about` returns `slot_action:<slot>:<component_id>`
    for a `slot_action`, with nothing after the last colon for "clear
    this key". That is the same domain-key shape as
    `zone_state_selected:<zone>:<variable>:<state>`, and
    `handle_slot_action` already raises `IntentError`, so the server's
    existing `exc.about or _about(message)` path would carry it.
  - **The client half is in and tested** (`EquipRequests.key`, matched
    exactly and on nothing else). `godot-equipment-face` delivers that
    key in a synthetic `error` frame and shows it resolving. Until the
    bridge sends it, a refusal is shown as the bridge's latest,
    unattributed, and the request waits until the link drops or the
    player picks again.
  - **How often it can happen:** the wall only offers the keys the view
    says an item fits, so a refusal needs a race, such as an item merged
    away between the snapshot and the press.

- **N-12 (D14 §7, D-01): one setup step moved in your pinned test.**
  `test_a_legacy_campaign_mints_nothing_for_its_own_item` claimed the
  Check, and then removed the policy field to make the save legacy.
  - That was a legacy confirmation only while creation left the policy
    off. With creation setting it (D14 §3), the claim ran under the
    policy and minted the Echo before the conversion, so the test failed
    on the integration.
  - It now converts before the claim. Every assertion is as it was, and
    "at confirmation" is now actually exercised. The sabotage "the
    policy ignored" (D01-3) fails it.
  - D14 §7 gives Prod "the combined tests above", and this edit is the
    only one made to your file. If you want it phrased differently, say
    so and it is yours to rewrite.
  - Two more assertions encoded historical B-1, and they changed for the
    same reason: `test_campaign_soak.py` ("an Echo from an unconfirmed
    location" meant foreign) and `integration_driver.gd` ("N foreign
    checks -> N interpretations").
- **N-13 (D-5, for `featured.py`; one question).**
  `fallback_interpretation` builds an Echo with no concepts.
  - The pipeline's semantic step refuses an Echo without them
    (`reading_errors`). It validates its own fallback the same way, and
    treats a refusal as a generator bug: it raises. Unlabelled, the one
    fallback that must always hold would have crashed the grant.
  - Prod's pipeline now stamps the §15 reading on it, as on every
    deterministic Echo (`_read_and_label`). What the Echo does is
    unchanged, and `test_featured_grant.py` asserts both.
  - **The question:** should `fallback_interpretation` carry concepts
    itself, so it validates on its own? If it does, the test tells us to
    drop the label ("the requirement's Echo now carries concepts").
- **N-14 (answers D-6): confirmed, with one room constraint.**
  - **The field:** `RailSpan.control_placement: Literal["ground",
    "gantry"] = "ground"`, confirmed. `RailNetworks` reads it:
    - `ground` is today's lever, at the control room's arrival plus
      `CONTROL_OFFSET`;
    - `gantry` is the development scenario's build.
  - **The geometry, as measured in `railway_scenario.gd`:**
    - a 4.0 x 0.4 x 4.0 m deck whose centre is 3.1 m above the floor
      the player grapples from. A standing jump tops out at 1.33 m, and
      there is no mantle;
    - the plate the hookshot bites is 7.2 m above that floor, over the
      deck's near lip (2 m from its centre, toward the approach);
    - the lever stands on the deck, facing the approach, on a support
      post. No stairs: that is the owner's rule, not a placeholder;
    - it is reached by the proven requirement (`grapple_to_surface`,
      range at least 20, pull at least 14). A 14 m/s pull tops out
      4.45 m above where it started.
  - **The constraint the composer must meet:** rooms have ceilings at
    `wall_height`, and procedural arenas top out at 8.0 m
    (`PROCEDURAL_ARENA_MAX_HEIGHT`). A 7.2 m plate therefore needs a
    control room at the top of that range.
    - Proposal: a gantry control demands `wall_height >= 8.0` and clear
      floor for the deck plus its approach.
    - My build will refuse a room that is shorter, reported in
      `refused` like any other network it cannot build. It will not
      lower the measured numbers to fit.
    - If you would rather have the search size the room, the number to
      carry is the same.
  - **Sequence, as you proposed:** your 1 and 2 as search-only rules;
    then my 3, the gantry placement; then your 4, the composer.
- **N-15 (H-GRAPHS; two asks and one question).**
  - **AND, DIRECT and SEQUENCE have no consumer.** No room in the design
    library and nothing the composer emits uses them.
    - `05_INHERITED`: they "require useful real consumers", and O05-07
      says "do not emit an unused catalogue". So Prod builds none of
      them until a room names one.
    - **Ask:** is one planned? A SEQUENCE needs §19.2's exact reset
      rule, and I would build it against that room.
  - **The five signal verbs reach a player only through an Echo, and no
    primitive exists** (`schemas/echo.py` has none).
    - Prod lands the runtime first, runtime-only, as O05-08's
      manipulation verbs did: §19.7's overrides at step 1, §14.3's
      legality, expiry after `magnitude` seconds, BRIDGE refused when it
      would make a cycle, and nothing touching a macro setter. It will be
      exercised on graphs that real rooms already run.
    - **Ask:** a `signal_verb` primitive (the verb, `magnitude` seconds,
      `range` metres), when you choose to add one.
  - **Question: is a recorded LATCH a macro setter?** Here a LATCH the
    bridge records (`record_latch`) is persistent progression. The Zone
    map and the journal read it as "open now".
    - §14.4 says no verb may drive a macro setter. My proposal: yes, it
      is one. A verb's override is never seen by a recorded LATCH's set
      input, because latches read the unoverridden values.
    - So a verb can hold a door open "long enough to slip through"; it
      can never set a latch.
    - The runtime lands with that rule, because it is the reading of
      §14.4 that can never create progression. If you rule otherwise,
      the change is one function.
- **N-16 (D-9 landed: one correction, and three things for your step 4).**
  - **Correction to N-14's numbers.** N-14 gave the scenario's figures
    as if they were relative to the floor the player grapples from: "a
    deck whose centre is 3.1 m above" it, "the plate ... 7.2 m above
    that floor".
    - In fact they are measured from the scenario's ground. The player
      grapples from the S2 platform, which is 1.0 m up.
    - Relative to that floor, which is what a room build has to carry,
      the deck's top is 2.9 m up and the plate 6.2 m. `godot-rail-gantry`
      plays the pull at those numbers: from the floor onto the deck at
      2.90 m, peaking at 3.98 m.
    - The build needs 6.8 m of height, so `GANTRY_MIN_WALL_HEIGHT = 8.0`
      holds.
    - The comments in `zone.py` and `featured.py` that say "3.1 m up, its
      hookshot plate 7.2 m up" describe the scenario's ground, not a
      room's floor.
    - **Proposal:** "2.9 m and 6.2 m above the floor it is grappled
      from". The wording is yours.
  - **The base kit's jump as played peaks at 1.40 m, not
    `JUMP_APEX_HEIGHT` (1.33).**
    - `player.gd` integrates explicitly at 60 Hz, which peaks half a step
      above v²/2g. The suite measures a standing jump at 1.40 m.
    - The gantry's reach field uses 1.40 m.
    - Any rule of yours that must keep something out of the base kit's
      reach, and is derived from the continuous figure, has 7 cm less
      margin than it states. Rules about what the base kit can do lose
      nothing.
  - **For the composer: a gantry needs room.** The engine searches the
    control room for a position with:
    - the footprint inside;
    - the carrier's half-width plus a rider's radius clear of every
      track;
    - floor under the approach and the post;
    - the pull's column and the space over the deck clear;
    - and nothing the base kit reaches within a jump of the deck.

    In the suite's Zone, where the track crosses the control room
    diagonally, a 16 m arena with its usual props has no position:
    - 900 were tried;
    - 324 were on the track;
    - 3 were within a chain of crates and cover of the deck.

    A 24 m arena has one. The refusal counts each test and names the
    nearest reach, so a composed Zone that misses says why. **Proposal:**
    prefer the largest arenas for a gantry. I can measure the sizes and
    layouts you intend to compose.
  - **One build order to know.** `RoomGraphs` is built after the
    railways, and its plate search reads only the room's own solids, so a
    signal graph in a gantry's room could put a device in the gantry's
    footprint. No Zone has both yet. **Proposal:** for now, a gantry's
    room carries no signal graph.
  - **No schema change is asked.** The gantry's lever is worked only
    from its deck (`AlignmentControl.worked_from`, D09-F1), so the AP
    logic's `grapple` is what the room holds.
- **N-17 (H-STATUS slice 2; one ask).**
  - **The runtime is in; please declare it.** `anchored` on `object` and
    `self`, and `lightened` on `self` and `enemy`, now have their Design 5
    §15.2 effects in the engine, played in `godot-status-kinetic`:
    - the anchored player is held against every impulse. It cannot walk
      or jump, its movement Echoes refuse unpaid, it reads `FIXED`, and
      everything else is permitted;
    - the anchored object is frozen in place, reads `FIXED`, and is
      refused by the verbs, the push and the hands;
    - a lightened player reads `LIGHT` and takes a knock at ×2;
    - a lightened enemy takes a knock at ×2;
    - applying either removes the other.
  - **Ask:** add the four targets to `SUPPORTED_STATUS_TARGETS`, per the
    table's own rule ("declared in the change that lands those
    effects").
    - `schemas/echo.py`'s comment for `anchored` says "a body fixed in
      place, and a player whose jump is blocked, are two other runtimes,
      and neither exists yet". Both exist now.
  - **Four things move with it** (Prod's tests; I will update them on
    your word):
    - `stats_driver.gd:589` pins `lightened == ["object"]`;
    - `mass_class_driver.gd:397-413` expects `lightened` on the player
      to be refused;
    - `unweighted_driver.gd:485-492` uses `anchored` on an object as the
      refused example;
    - `bridge/tests/test_status_guarantee.py` pins the table on your
      side.

    `godot-status-kinetic` needs nothing: it reads the table and follows
    the gate.
  - **Two readings for you to confirm or overrule:**
    - an anchored player still falls, as an anchored enemy does:
      "fixed in place" where it stands, not hung in the air. An anchored
      object does hang, because it is frozen;
    - a player's own `anchored` or `lightened` changes the class a
      counting plate reads. The route validator reads the player
      unstatused (D-10 §6), so this is a transient the player chose, and
      it lasts as long as the Status does.
- **N-18 (answers D-10; one finding, and a proposal).**
  - **The census** (`godot-gantry-census`; the D-10 ledger entry has the
    table). It builds the three-dock S1–S2–S3 layout at `wall_height`
    8.0, 168 layouts per size: 24 arena chamber ids (the props) × the 7
    shapes the chain can take at the arena (a corner before it, after
    it, both, or neither).
    - **The procedural maximum, 28 × 28, and the 24 m arena take the
      gantry in all 168**, including the track on the arrival axis.
    - **So does every measured arena at least 24 m wide and 22 m deep.**
      That is the landmark's range as the fallback rolls it (width
      24–28 m, depth 22–26 m), measured at every 2 m point and two
      points off the grid.
    - **The smallest square that takes it everywhere is 24 × 24.**
      22 × 22 refuses 2 of 168: room c064 on a chain turned before the
      arena, where a surface puts the deck within a jump. 22 × 24 and
      24 × 22 take all 168. A 20 m span refuses somewhere, except at
      28 × 20.
  - **The rule for the composer: width at least 24 m, depth at least
    22 m.** So the landmark as it is rolled today can hold the gantry.
    - The census holds that rule as a CI gate (`GANTRY_ROOM_MIN_WIDTH`,
      `_DEPTH`), so an engine change that breaks it fails there first.
      If you choose another rule, the two constants follow it.
    - It is a sample and a grid: the fallback rolls to 0.1 m, and sizes
      between the measured points are not measured.
    - `--census-sizes=` measures any sizes you intend to compose.
  - **One fact about the layout, in case the composer relies on it.**
    The engine never reads the Zone's `seed` field. The chain's turns are
    seeded by `zone_id|theme` (`zone_builder.gd`), so two Zones with the
    same id and theme lay the same chain whatever their `seed`. My first
    census varied `seed`, measured a third of what it claimed, and gave
    a wrong rule (D10-F2).
  - **The finding (D10-F1): a refused gantry never reaches you.**
    - The engine keeps rail refusals on the controller, and the
      `layout_result` does not carry them.
    - That was safe under D-4, because the only refusal was one your
      schema already makes unreachable.
    - A gantry refusal is reachable from a valid Zone. That Zone would be
      accepted without its railway, and every Check past a mandatory span
      would be out of reach.
    - The rule makes it rare in the sample, not impossible.
  - **Proposal:** a network refused with a mandatory span should fail
    the layout, so the Zone is recomposed and not played. There are two
    shapes, and the choice is yours, since the protocol is:
    - (a) `LayoutResult` carries the refusals, and acceptance refuses on
      a mandatory one;
    - (b) the engine sends `build_failed` for it (the NO-LAYOUT path).
      This only works if a retry does not recompose the same room, or it
      fails the same way.

    The engine half is mine either way.
- **N-19 (H-RAIL-BREADTH: the engine half of DESS-01 items 1–2 has
  landed; items 3–5 are yours, and here is what the engine reads).**
  - **What it builds** (`RailNetworkCarrier`, `RailPoints`,
    `godot-rail-network`; the H-RAIL-BREADTH ledger entry has the
    measurements):
    - one tree of docks and spans;
    - a switch at the dock where track divides:
      `{switch_id, dock_id, legs: [dock_id, ...], leg}`. `legs` are the
      neighbours reached through the points and `leg` is the initial
      one. The dock's one other neighbour, if it has one, is the heel.
  - **What it refuses, by name:**
    - a loop or a detached dock;
    - track dividing at a dock with no switch;
    - a switch with one leg;
    - a heel arriving from beyond the legs;
    - **any dock within 10 m (`RAIL_SWITCH_CLEARANCE_M`) of the
      points.**

    The points stand 11 m beyond the fork dock, toward the legs. The
    first four refusals need no geometry, so your validator can make
    them. The last two are measured, like the gantry's: kept as engine
    refusals, unless you want a census for a composer rule.
  - **Item 5.** `_a_span_joins_docks_the_route_visits_in_turn` can accept
    the spans from a declared switch dock to its legs and its heel. A
    network with no switch lays out exactly as the ordered route: same
    path, same dock offsets, same frames. The suite compares the two
    carriers.
  - **Item 3, the setting as Zone state. Your choice, two questions.**
    - Is it a reversible `ZoneStateVariable` whose values are the leg
      docks, set by the POINTS lever in the fork dock's room, or a field
      of its own? `macro_state` holds 4 variables per Zone.
    - Either way the engine restores a setting without reporting it
      (`restore_points`) and reports a throw on `branch_changed`. I wire
      both once the field exists.
  - **Item 4.** A leg is operable wherever its points can be thrown from
    a reachable place: the POINTS lever at the fork dock, base kit. Any
    dock's CALL lever sets the points itself.
  - **The carrier's rest (P17.4).** The engine rests it only at docks,
    and today's policy restores it at the declared home. A saved dock
    would need a row like the minors' `carrier_states`. Tell me whether
    you want one.
  - **RB-F4, which is both of ours.** A declared railway (D-4) builds
    nothing a player can command: no receiver and no call lever.
    - Nothing composes one into a played Zone today.
    - The first composed one could not be ridden.
    - My slice 2 builds CALL levers for every declared railway. The
      network builder already does.

## Evidence rules (PROD_START)

- **Every repair has:**
  - a failing reproduction;
  - the changed behaviour;
  - a focused regression and a control;
  - its revision and scope.
- **Combat** uses cumulative events and deaths, and ordinary visible
  aiming.
- **Rooms** are tested hosted in a real candidate, with baseline and
  movement-assisted access, and the return.
- **Resume** kills and relaunches both processes.
- **The menu pause** covers incoming authorizations and input leakage.

## Shared-seam table (Prod's temporary exceptions, for Dess's review)

**Closed at the handback, `f332fff`.** No new rows after it.

| edit | source rule | behaviour kept | commit |
|---|---|---|---|
| `ZoneProgress.defeated: tuple[str, ...] \| None`, with `with_defeated`, the `EnemyDefeated` intent, `transitions.record_defeat` and `_declared_members`, and `SAVE_FIELD_CATEGORY["defeated"] = "ROOM_PERSISTENT"`. Protocol and transitions mirrored to the design packet; `check_packet.py` passes | Owner ruling D-06 (verbatim above). The packet's `H-RESUME-C` minimum (09 §resume): distinguish quit/reload from a reset, keep defeated membership, check identities for consistency, handle old absence explicitly. The contract is Dess's; this is the narrowest form that ruling needs | Every existing field and intent unchanged. `None` (absent in an old save) means unknown, never "nobody". `bridge/tests/test_encounter_resume.py` | H-RESUME-R |
| `DIVER_TRIGGER_HEIGHT` 1.6 → `round(0.6 * JUMP_APEX_HEIGHT, 2)` = 0.8 m, in `schemas/constants.py`. Mirrored to `docs/design-packet-v0.8/schemas/`; `constants.gd` and the apworld copy regenerated by `make export`; `check_packet.py` passes | The diver's approved brief, "ignores a grounded player and commits when they leave the ground" (EPSILON_SPEC diver row). OV04 P06.4: "Do not assume it must require the player to grapple". The 1.6 m value was Prod's provisional tuning (`a25383f`), not a Dess contract | A grounded player (floor, gantry, a step down a stair or kerb) still draws no dive. `bridge/tests/test_diver_trigger.py` holds both ends and the derivation | H-FLYER-AI |
| `record_defeat` added to `TRANSITIONS`; `protocol.schema.json` regenerated by `make export`. Packet mirror byte-identical | DESS-19 and DESS-20, found by the CP1 frontier and by Dess's H-SEAMS review. Both are defects of the H-RESUME-R row above | Nothing else changes. `make test` 2149 passed; `check_packet` clean; export diff clean | `f332fff` |

## CP1 — `H-ARTILLERY` (PT-11): no shell through walls, roofs or cover — repaired

- **Reproduced first,** on the unmodified runtime with ordinary AI
  targeting and cumulative counts
  (`post_playtest_evidence/H-ARTILLERY_repro_on_d92b637.log`):
  - **A**, the next room behind an intact wall: 3 shells committed, 3
    hits, 48 hp in 10 s.
  - **B**, under a roof but seen through its open side: 48 hp.
  - **C**, a blast 2.4 m away behind a 6 m wall: 16 hp.
  - **D**, a wall raised across a shell's path in flight: 16 hp.

  The source matched all three leads: it committed a shell on distance
  alone; the flight was set point by point with no collision; and the
  blast was `distance_to(target) <= blast`.
- **The repair (`enemy.gd`), physics only, no room-ID force field:**
  - **Knowledge:** the artillery commits only at a player in its own
    line of sight.
  - **Path:** the shell's own arc (`ArtilleryShell.point`, the one
    formula for flight and check) is sampled in 16 segments before it is
    fired. Arriving within 0.6 m of the target, or at the player there,
    counts as arriving.
  - **Flight:** each tick is a ray from the last position, and the shell
    detonates at whatever it meets.
  - **Cover:** a blast reaches a player only if the chest or the knees
    can be seen from the burst.
  - Actors (the enemies) are ignored by path and blast. Walls, floors,
    roofs and physical objects stop both.
- **Evidence:** `make godot-combat-fairness` (new), 7 checks.
  - A: 0 committed, 0 hits.
  - B: 0 committed.
  - **F** (new): hidden behind a 2.5 m wall the arc would clear, 0
    committed. This is the sight rule on its own.
  - C: 0 hits. Control C2: the same blast in the open lands 1 hit.
  - D: 0 hits.
  - **E**, the positive control: over 0.6 m cover, 3 shells and 48 hp.
    Artillery is not silenced.
- **Sabotages (each restored, each failing by name):**
  - SA1, no sight check: F fails (3 hits).
  - SA2, no arc check: B fails (3 committed). Its first version was
    written wrong (it skipped firing whenever the arc was clear, which
    also failed E); it was corrected and re-run.
  - SA3, no flight collision: D fails.
  - SA4, no blast cover: C fails.
- **A setup lesson, applied twice:**
  - A gun placed in the same frame as its wall asked about a world
    without the wall: one shell went through on the first run of A. The
    suite now settles the stage before the gun; a real Zone builds its
    geometry long before any enemy acts.
  - `roster_driver`'s artillery case made the gun and its target in the
    same frame. The gun was lifted onto the target and rode it at 1.8 m,
    and the case passed only because the gun fired in its first frame.
    The target is now made first and settled. `godot-roster` 52.
- **Neighbours:** `godot-encounter` 51, including "indirect fire reaches
  a player who stands still".

## CP1 — `H-FLYER-HIT` (PT-12): a flyer is hit where it is seen — repaired

- **Reproduced first,** on the unmodified runtime at `6ebbc90`
  (`post_playtest_evidence/H-FLYER-HIT_repro_on_6ebbc90.log`: 17 failures
  in 29 checks). The player aims its camera at the middle of the
  RENDERED meshes, never at an internal centre, and fires through the
  real `fire_pulse` binding; hits are counted cumulatively.
  - **Seen versus hittable:**
    - the drifter's visible body was centred at 4.78 m and its hittable
      box at 6.72 m (1.95 m apart);
    - the diver's was 4.50 m against 6.07 m (1.57 m apart).
  - **Aimed at the middle of the visible body** at 4, 9 and 18 m: 0 hits,
    both roles.
  - **The deliberate miss,** aimed 0.45 m ABOVE the visible body: 2 hits
    each. That is where the hidden collider was.
  - **A real explosive Echo shot** at the visible body did no damage.
  - The diver's shots started outside its visible body.
- **The cause, in the source:**
  - The envelope contract (`schemas/constants.py`, `EnemyEnvelope`) says
    `hover_height` is the collider's CENTRE above the FLOOR, and
    `create()` hangs the collider exactly that far above the pivot.
  - `_hold_station` then lifted the pivot a further `FLYER_HOVER_Y`
    (4.2 m), so the hover height was counted twice.
  - Meanwhile the flyers got the walker fallback visual, built upward
    from the pivot. The body was drawn near the pivot and hit 1.6–2 m
    above it.
- **The repair (runtime only; no shared file edited):**
  - **The station is the floor.** The flyer's pivot rests on the floor
    under it, so its body sits at exactly the envelope's hover height:
    the diver at 1.65–2.15 m, the drifter at 2.08–3.03 m.
    `_floor_beneath` casts from the body; with nothing under it, the
    flyer holds where it is.
  - **Drawn where it is hit.** A flyer's `Visual` sits at the collider's
    centre. Provisional engine silhouettes are built inside the
    collider's box on every axis: a dart for the diver, with the eye on
    the nose it faces with; a canopy, emitter and vanes for the drifter.
    A flinch now scales about the body's middle rather than the floor.
    Arty's models later replace the look against the same box
    (`H-ENEMY-ART`), never the box.
  - **Shots, sight and the dive come from the body.** `muzzle()` and
    line of sight start at a flyer's body (a walker's are unchanged). The
    dive is aimed from body to body, and lands body to body.
  - **Area effects measure to the body.** There are three new accessors:
    `body_centre()`, `nearest_body_point()` and `overhead()`.
    - An explosive Echo shot measures to the nearest point of the body,
      not to the pivot. Otherwise a direct hit on something hovering
      2.5 m up would be a blast 2.5 m away.
    - The damage bar sits above the collider's top. `pivot + 2.1` put it
      inside a diver and under a drifter.
- **Evidence:** `make godot-combat-fairness`, 29 checks: the 7 artillery
  checks, plus 11 per flyer.
  - Seen versus hittable centres: 0.02 m (drifter) and 0.00 m (diver).
    Each also passes a same-box check: each box encloses the other with
    0.05 m of slack (the hittable box shrunk by 0.2 m inside the seen
    one).
  - Each body sits at the envelope's hover height (2.55 m and 1.90 m).
  - The muzzle is inside the visible body, and the flyer faces the
    player (0° off).
  - Aimed at the visible body at 4, 9 and 18 m: 3, 2 and 3 hits for
    each role.
  - The deliberate misses, 0.45 m above and 0.45 m below: 0 hits.
  - The explosive Echo shot: drifter 44 → 34.8 hp, diver 20 → 10.7 hp.
- **Sabotages (each restored byte for byte, each failing by name):**
  - **SF1,** the station lifted by `FLYER_HOVER_Y` again: both "holds at
    the envelope's hover height" checks fail (6.07 m and 6.72 m). So
    does the drifter's miss above: from 9 m, a steep ray 0.45 m over the
    body's top grazes the box's near edge.
  - **SF2,** the flyer's `Visual` left at the pivot: 14 fail. These are
    the centres 1.90 m and 2.53 m apart, every near/mid/far shot, the
    same-box check, the muzzle check and the explosive shot.
  - **SF3,** the blast measured to the pivot again: both explosive-shot
    checks fail (0 damage).
  - **SF4,** a flyer's muzzle back at `pivot + 1.2`: both muzzle checks
    fail.
  - **SF5,** the walker silhouette on a flyer (at the right height): 10
    fail. These are the centres 0.33 m and 0.60 m apart, the same-box
    check, and shots at the visible middle that miss. The drifter's
    snout reaches below the collider, so aiming under it hits.
- **Tests that measured the old geometry, corrected (not weakened):**
  - `roster_driver`'s drifter case compared the PIVOT with the 4.2 m
    constant. It now asks whether the BODY holds at the envelope's hover
    height and clears a standing player's head. `godot-roster` 52.
  - `status_family_driver`'s "a rooted drifter neither drifts nor falls"
    read the pivot's height. It now reads the body's (3.12 m).
    `godot-status-family` 15.
- **Other neighbours, green:** `godot-encounter` 51, `godot-content`,
  `godot-hud`, `godot-verbs`, `godot-legible`, `godot-affordance`,
  `godot-test`, `godot-transport` 106, `godot-lab`, `godot-stats`,
  `godot-counterfire` 59.
- **What the owner will notice:** flyers hover lower than in the
  candidate that was played. They now sit at the heights the shared
  contract declares, with the diver at head height and the drifter just
  above it, instead of about 4.5 m up. If they should hang higher, that
  is one number per role in the contract (`hover_height`, Dess's), and
  the runtime follows it with no code change.
- **For Dess (no edit made):** the runtime no longer reads
  `FLYER_HOVER_Y` in `schemas/constants.py`. It is superseded by
  `EnemyEnvelope.hover_height`, and is left in place because the shared
  constants are Dess's to retire.
- **Art review:** pending. Arty's lane has not resumed, and `H-ENEMY-ART`
  depends on this task.

## CP1 — `H-FLYER-AI` (PT-13): what each flyer waits for, and what it does — diagnosed and repaired

Prod's findings in this packet are numbered `PPT-nn`.

- **Which flyers the owner met.** The played Zone (`candidate_zone.json`)
  has no drifters. Its only flyers are the five divers in `c011`: an
  arena with a 1.64 m gallery and a kill_all objective.
- **Reproduced first,** on the unmodified runtime at `41d7a9a`, with every
  number counted from an event as it happened:
  - `post_playtest_evidence/H-FLYER-AI_repro_on_41d7a9a.log`: 6 failures
    in 44 checks.
  - `H-FLYER-AI_c011_on_41d7a9a_runtime.log`: the played room.

  Health is never read at the end; that is how an earlier diagnosis
  reported "zero damage".
  - **The diver was not broken. Its trigger was out of reach.**
    - Standing or strafing, it noticed the player and correctly waited.
    - Jumping, 310 frames off the floor, drew 0 dives. The trigger was
      1.6 m, which the engine read as 1.8 m of clearance under the feet,
      and an ordinary jump peaks at 1.33 m. Outside a grapple arc,
      "commits when they leave the ground" never happened.
    - In `c011`, jumping drew 0 dives. The only damage came from a
      bulwark.
  - **Its dives could not arrive.** It committed from its 18 m notice
    radius, but a dive carries only 6.3 m (7 m/s for 0.9 s). It waited
    8.1 m away.
  - **It dived at players it could not see:** 2 dives committed through
    a wall.
  - **The drifter was never silent.** Against a stationary player it
    fired 3 shots, with 3 hits and 21 damage. But no shot was telegraphed:
    the F-14 defect the ranged role once had.
  - **A waiting diver looked no different from an idle one.**
- **The repair:**
  - **The trigger follows the jump.** This is a shared edit, recorded in
    the seam table. `DIVER_TRIGGER_HEIGHT` is now 0.8 m, three fifths of
    the jump's apex. The engine reads it as written; the extra 0.2 m is
    gone. An ordinary jump is above it for 0.42 s; a step down a stair or
    a kerb is not.
  - **A dive that can arrive, at a player it can see.**
    - The diver commits only within its dive reach (carry plus 1.6 m
      contact: 7.9 m), measured body to body, with line of sight.
    - It waits within striking distance (70% of that reach), not at the
      edge of what it can see.
    - `reach` stays its notice radius.
  - **A dive lands only on a body it has reached and can see:** contact
    within 1.6 m, with nothing solid between.
  - **The drifter's shot is committed, then fired,** after a 0.45 s
    "aim" windup, as the ranged role's is. Sight is checked when the shot
    is committed.
  - **States you can read, in the eye.**
    - Every role's eye flares while it telegraphs.
    - A flyer's eye is low while idle and burns steady once it has
      noticed the player. A waiting diver is watching, and now looks it.
    - The body is deliberately not pitched toward its target. A first cut
      did that, and it pushed the drawn diver outside its hitbox: the
      H-FLYER-HIT same-box check caught it.
- **Evidence:** `make godot-combat-fairness`, 50 checks.
  - **Drifter:**
    - stationary player: 3 telegraphed, 3 launched, 2 impacts, 14 damage;
    - strafing: 3 launched, 0 impacts (the windup makes it dodgeable);
    - jumping: 3 launched;
    - behind a wall: 0; at 30 m: 0;
    - its eye flares while it aims.
  - **Diver:**
    - standing or strafing: it notices the player every frame and waits
      (0 dives), within its dive reach;
    - its eye burns at the watching level, against the idle level with no
      one there;
    - ordinary jumps: 3 telegraphs, 2 dives, 2 impacts, 24 damage;
    - jumping while strafing: 2 dives, 1 landed. It is not a homing hit
      (P06.4);
    - held where a grapple arc puts the player: 2 dives, 2 impacts;
    - behind a wall: 0;
    - **a wall raised across a committed dive:** 0 impacts, though its
      body ends 1.50 m from the player's (contact is 1.6 m);
    - **a player already in the air 14 m off:** it closes first. Its
      farthest commit is 7.9 m, its dive reach; 2 dives, 2 landed;
    - at 30 m: 0.
  - **In the room the owner played:** `make godot-flyer-room`, new, 7
    checks, in CI.
    - The player is placed at `c011`'s own arrival, a declared harness
      step (see `PPT-01`). Everything after that is played.
    - Standing for 5 s: 0 dives, and 5 of 5 divers are watching.
    - Jumping for 6 s: 5 dives, 4 diver impacts, 48 damage. A bulwark
      from the uncleared `c009` followed the player in and landed 4 more;
      those are attributed by name and not counted as the divers'.
    - Cleared with the Static Pulse aimed at their bodies: 5 of 5 dead in
      7.0 s, counted from `enemy_died`, and kill_all is satisfied.
    - The same driver on the old runtime: 0 of 5 watching, 0 dives from
      jumping.
- **Sabotages (each restored byte for byte, each failing by name):**
  - **SA-A,** the trigger back at 1.6 m: 5 fail. Ordinary jumps draw no
    dive; nothing lands; the evading case gets no dive to evade; the
    raised-wall case never commits; the eye never flares.
  - **SA-B,** a dive committed without sight: "airborne player behind a
    wall" fails (2 dives).
  - **SA-C1,** the diver waiting at the ordinary stand-off: 6 fail. Its
    dives cannot arrive, and it waits 8.1 m away.
  - **SA-C2,** a dive committed from its whole notice radius: "in the air
    14 m off" fails, with the farthest commit at 14.3 m.
    - This check was twice wrong before it had teeth.
    - At first the probe let the player fall during the settle, so the
      diver had already closed in.
    - Then it counted commits only inside the window, and the sabotaged
      diver's 14 m commit came during the settle.
    - Each was corrected in the probe, never in the rule, and SA-C2 was
      re-run each time.
  - **SA-D,** the drifter firing with nothing to see first: 3 fail (no
    telegraph, and no eye flare).
  - **SA-E,** a dive landing by distance alone: the raised-wall case fails
    (1 impact through the wall).
  - **SA-F,** no eye states: "waiting reads as watching" fails (2.40
    against 2.40).
- **A test that measured the old trigger, corrected (not weakened):**
  `roster_driver`'s diver case placed its "standing" player a metre up,
  in the same frame as the diver. It spent its first frames dropping
  that metre, which is in the air by the new rule. It now lands before
  the diver exists, and the check also asks that it is on the floor.
  `godot-roster` 52.
- **Other neighbours, green:** `godot-status-family` 15,
  `godot-encounter` 51, `godot-content`, `godot-counterfire` 59,
  `godot-hud`, `godot-legible`, `test-schemas` 131, `test-bridge` 1936,
  and `check_packet.py`.
- **What the owner will notice:**
  - Jumping near divers now draws them.
  - They wait within striking distance with their eyes lit. When they
    commit, the eye flares and the body swells for 0.35 s, then they dive
    at where the player was. Moving after landing avoids it.
  - A drifter takes a visible 0.45 s aim before each shot.
- **`PPT-01` (noted, not fixed; a harness limit, not a proven game
  defect):** on `candidate_zone.json`, the suites' spine walker
  (`transport_driver._advance_to` with clearing) stalls in `c003`'s
  platform course after clearing `c002`.
- **Placement purpose (for Dess, recorded, not changed):**
  - With jumps counting, a diver contests the air anywhere a player
    jumps, and `c011`'s gallery gives its five a purpose.
  - A generator rule that places divers where the layout asks the player
    to leave the ground (gaps, anchors, galleries) is a composition
    question for Dess's lane.

## CP1 — `H-RESUME-R` (PT-16, D-06): an encounter resumes as it was left — repaired

- **Reproduced first, through two real processes,** on the unmodified
  runtime at `499cec8`
  (`post_playtest_evidence/H-RESUME-R_repro_on_499cec8.log`).
  - The room is `c005`, the power-cell room of the candidate the owner
    played: two bulwarks, and a warp station that comes online when the
    room's puzzle is solved.
  - One bulwark was killed. Both processes were killed and relaunched.
  - **The killed bulwark was back (2 of 2),** and the player was restored
    AT THE STATION, 3.0 m from a live bulwark.
  - This is PT-16's mechanism. Every room of 260 m² or more gets a
    station near its middle, arenas included, and the first bulwark's
    post lands almost on it. A resume put the player there and rebuilt
    every enemy from the Zone data.
- **No existing authoritative state proves a defeat.** The saved Zone
  progress holds keys, locks, stations, latches, the macro state, object
  rooms, poses and consumers, and carrier rests. Nothing in it is about
  an enemy. The packet rules out inferring kills from a claimed Check. So
  an older save's encounter state is genuinely unknown.
- **The contract** is a shared edit (seam table), the narrowest D-06
  needs:
  - **Identity:** `room/archetype#n`, the n-th spawn of that archetype in
    that room's declared `enemies`, in declaration order. That is the
    order every room builder lays them out in, so the engine and the
    bridge derive the same identity from the same declaration.
    - It is not an engine node path.
    - No health, timer or position is saved.
  - **Record:** `ZoneProgress.defeated` is monotone and idempotent.
    Ordinary quit and reload are not resets.
  - **`None` is not "nobody"; it means unknown:** a save written before
    the record existed. The first defeat after such an entry starts the
    record, and that entry had built every member. This is D-06's "from
    that point onward".
  - **Consistency, not trust:** `record_defeat` refuses a room the Zone
    does not have, an archetype that room does not declare, and an
    ordinal past the declared count.
- **The runtime:**
  - Each spawned enemy carries its declared identity.
  - A member the save records as defeated is **never built.** It is
    skipped in `setup`, before the first physics step, so it is absent
    before anything can perceive or attack.
  - A death is reported once under its identity. The in-flight half is
    remembered for a Hub return, like keys.
  - **The resumed player is never put among the living.**
    - If the room the resume point stands in holds any living member of
      its encounter (survivors of a partial clear, or everyone in an
      unknown save), the player is restored at THAT room's arrival: the
      doorway its encounter was composed to be entered from.
    - The player is told why: "1 LEFT IN C005 -- YOU START AT ITS
      ENTRANCE." For an unknown save: "NO RECORD OF WHICH ENEMIES FELL IN
      THIS SAVE -- C005'S ENCOUNTER IS BACK. YOU START AT ITS ENTRANCE."
    - The rest of the save is untouched.
    - It all happens inside `setup`. Enemies already ignore a player held
      for the layout verdict (`Enemy._find_player`), so nothing strikes
      during the build.
- **Evidence:**
  - **`make godot-resume-live`** (new, in CI) runs five phases. Each is a
    new client beside a new bridge (`--candidate=all`), and only the save
    crosses.
    - **partial:** `c005/bulwark#0` killed; the bridge holds exactly that.
    - **partial_restore:** 1 bulwark at control, the killed one absent.
      The player is at `c005`'s arrival, 10.9 m from the survivor. 0
      strikes during the build and 0 in the next 5 s. Then the survivor
      is killed.
    - **clear_restore:** no bulwark and kill_all satisfied. With nobody
      left, the player is back AT the station. 0 strikes.
    - **legacy:** a COPY made after `partial`, with the record stripped
      by `tools/strip_encounter_record.py`. That tool refuses any
      directory but a resume-test copy, and it deletes the `.bak`, which
      would still hold the record.
      - Both bulwarks are back: nothing is invented.
      - The player is at the arrival, 6.9 m from the nearest, and TOLD
        why. 0 strikes during the build.
      - The next kill starts the record: `["c005/bulwark#0"]`.
  - **`make godot-resume`** (new, in CI): 12 checks on the real
    `ZoneController`, read before the first physics step.
    - a partial clear, a full clear, no record, and a first entry
      (unchanged: the Zone's own arrival, nothing said);
    - one death gives one `enemy_defeated`, under its identity;
    - another room's encounter is untouched.
  - **`bridge/tests/test_encounter_resume.py`,** 15 tests:
    - unknown is not "nobody";
    - monotone and idempotent;
    - an older save's JSON loads as unknown;
    - the §5.1 category;
    - six malformed identities never parse;
    - an undeclared room, archetype or ordinal is refused;
    - every declared member, and not one more, can be recorded;
    - the record survives a bridge restart.
- **Sabotages (each restored byte for byte, each failing by name):**
  - **SR1,** the defeated built anyway: 4 fail offline. The defeated
    bulwark is back, the cleared room is not satisfied, and a cleared
    room still moves the player off its station.
  - **SR2,** the player left where the resume put them: 4 fail, "at
    the station among the living", and nothing is said.
  - **SR5,** a death not reported: "one death, one report" fails (0
    sent).
  - **SR6,** moved but not told: the unknown-save notice check fails.
  - **SR3,** an identity trusted from the client: "an undeclared member
    never becomes save data" fails.
  - **SR4,** an unknown record that never starts: 6 fail.
  - **SR1L, the packet's own named control** ("omit saved-defeat
    restoration and the reload case fails"), run through two real
    processes: `godot-resume-live` fails in `partial_restore`, with the
    killed bulwark back ("2 alive in c005").
- **Refinement, before the checkpoint:** the protection applies only to a
  RESUME, meaning a player restored at a station. An ordinary entry
  already starts at the Zone's own arrival, the doorway the Zone was
  composed to be entered from, so it is neither moved nor narrated. The
  offline suite's first-entry case holds it (12 of 12).
- **`PPT-02` (observed, not investigated):** in `partial_restore`, the
  bridge also recorded `c006/melee#0`. `c006` is the 40 × 59 m transit
  hall. Its melee chased the player toward `c005`, walked off the hall's
  drop, and died by the existing fall-kill rule (`ENEMY_FALL_KILL_Y`,
  "counts as dead: kill_all stays satisfiable"). The defeat was recorded
  like any other, which is consistent with that rule. Whether a melee
  should be composed where it can walk off that drop is a placement
  question, not this one.
- **What the owner will notice:**
  - Quitting and reloading keeps every kill.
  - A room left half-cleared starts you at its entrance, with the
    survivors at their posts and a line saying how many are left.
  - A cleared room starts you at its station.
  - The first time an older save (like the played one) is loaded, any
    room you resume in starts you at its entrance, with its encounter
    back and a line saying why. From then on, kills are kept.

## CP1 checkpoint — closed (the full frontier, twice)

- **On `76b0952` (before the handback):** 66 of 68 steps passed
  (`CP1_frontier_on_76b0952.tsv`). The two failures were DESS-19 and
  DESS-20, both from H-RESUME-R's shared edit, fixed at `f332fff` (the
  seam table's last row).
- **On `5f348ab` (the handback head, with Dess's eight commits):** 67 of
  68 passed (`CP1_frontier_on_5f348ab.tsv`). The one failure was this
  lane's own test over-asserting, not the game
  (`CP1_resume_live_legacy_overassertion_on_5f348ab.log`):
  - `godot-resume-live`'s legacy phase required the bridge's record to
    be exactly the bulwark it killed. It also held `c006/melee#0`: that
    melee chased the player off the transit hall's drop and died by the
    fall rule (PPT-02). Whether it happens is timing; on `76b0952` it
    did not.
  - Fixed at `72392d8`, stricter rather than looser: every
    `enemy_died` the engine emits is collected by declared identity,
    and the record must equal exactly that set and hold the kill. It
    fails if the bridge invents a death or misses one. Three
    consecutive two-process runs pass.
- **CP1 is closed.** The frontier was not re-run in full for a
  test-only change; the next full run is CP2's checkpoint.

## CP2 — `H-PRESSURE-R` (D-07), the engine's half — landed

The contract is Dess's D13 (H-PRESSURE-C). Its bridge half, 1a to 1c,
is Dess's after the W0.1 handback. This is the engine's half, which D13
orders first: "the bridge must not admit a Zone lever before
`RoomGraphs` can place one".

- **Reproduction, on `76b0952`** (`H-PRESSURE-R_repro_step_once_on_76b0952.log`,
  the CP1 frontier's own raw log of `godot-latched-route`). One step on
  the plate, then fully off it: the plate reads empty (`"satisfied":
  false`), "the latch still holds", and "the way opens fully with nobody
  on the plate (openness 1.00)". That is exactly the step-once plate D-07
  rejects.
- **What changed:**
  - A declared `PULSE_BUTTON` is built as a **lever** labelled "THROW
    BOLT -- OPENS THE SHUTTER".
  - Once the LATCH it feeds is set, live or restored from the save, the
    lever **stays thrown**, its prompt reads "BOLT THROWN -- THE WAY IS
    OPEN", and a second pull does nothing (`SignalGraph.lock_permanent_levers`).
  - A call control, and a minor's own lever, names no latch and is never
    locked.
  - The builder keeps **its own placeable list** (N-4).
  - **Levers are placed by a measured rule.** A spot is refused while
    anything solid the room built stands over the lever's footprint, up
    to a standing player's height, or crowds all four of its
    body-width approach sides. When the authored spots all fail, the
    rest of the floor on the room's side of the doorway is searched,
    nearest the door first.
  - **Legacy plates are placed exactly as before (M-1).**
- **`PPT-04`, found by the lever's own test.** The route spot in the
  latch fixture's `c002` is inside a 1.13 m cover block, under a gallery
  whose underside is 1.61 m off the floor.
  - A plate there could still be stepped on. The old played acceptance
    passed, and a saved Zone keeps playing it (M-1).
  - A lever there cannot be aimed at: the interact ray stopped on the
    block.
  - The measured rule puts the lever 2.4 m in from the doorway and
    3.2 m to its side, clear.
- **Regression** (`H-PRESSURE-R_after.log`):
  - `godot-latched-route`, 73 checks. It plays both forms whatever the
    fixture declares:
    - the Zone as composed, today the legacy plate, played as saved;
    - the lever, by explicit substitution of the route's one sensor,
      with the same room, doorway, LATCH and shutter;
    - V-08's control: an ordinary plate on the same shutter, with no
      latch, shuts again when stepped off.
  - `godot-signal-graph`, 61 checks, including the placeable-list order.
  - `godot-graphs`, `godot-zone-state` (60) and `godot-reversible` (32)
    are unchanged and green.
- **Sabotages** (`H-PRESSURE-R_sabotages.log`), each restored
  byte-for-byte:
  - SP-1: a latched lever springs back. "the lever STAYS THROWN" and
    "pulling it again does nothing" fail.
  - SP-2: the builder cannot place a lever. "the builder can place a
    lever" fails.
  - SP-4: legacy plates are placed by the measured rule. The saved
    route's graph is refused in `c002`, which is the M-1 regression the
    split exists to prevent.
  - **SP-3, as first written, was not caught.** It placed levers by the
    old rule, but with the lever's own smaller footprint the old list
    happens to pick a clear spot. So it was not the defect.
  - SP-3′ reproduces the defect itself: the lever at the plate's old
    spot. The interact ray misses and the THROW fails, with 8 failures.
- **Scope, stated:** offline.
  - The live suites (`godot-latched-route-live`, `godot-candidate-live`)
    play the committed fixtures. Those still declare the legacy plate
    until Dess's 1b regenerates them, so they are unchanged here.
  - Switching them to the lever is Prod's, after that.
- **What the owner will notice:** nothing yet in the played candidate,
  whose saved Zones keep their step-once plates (M-1). Once Dess's
  composer writes the lever, a new route shows a bolt lever that stays
  thrown and says the way is open. A plate is only ever a held sensor.

## CP2 — `H-UNWEIGHTED` (PT-05, D12's card) — repaired

PT-05: "saw an indestructible crate moved very slowly by a lever, did
not understand the goal, and walked to the Check." D12 (Dess's
H-RELEASE-C) is the contract. It says what must be true, and the
physical proposal is Prod's. Both proposals below were agreed by Dess
(N-1, N-2), and N-2 is flagged to the owner.

- **Reproductions, on the room as it stood** (unchanged from `76b0952`):
  - **The Check claimed from the floor**
    (`H-UNWEIGHTED_repro_census.log`).
    - The new census found 7 floor cells under the north wall's high
      return gap from which a hop puts the Check inside the claim ray's
      3 m.
    - Played: the real player walked from the arrival to one of them
      and hopped, the prompt read "[E] CLAIM CHECK 055", and a claim
      went out with nothing solved.
  - **The gallery reached from the carriage in transit.**
    - Ridden toward the recess, the carriage was a step within a
      running jump of the sill before its weight reached the plate.
    - A single ride-and-jump landed on G with `lightened` never applied.
    - The sweep that now guards it reproduces this on the old plate: 7
      of 14 jump points reach G, from 3.4 m to 1.6 m from the wall.
- **The room card, as built:**

| Field | Now |
|---|---|
| Arrival read | Upper doorway with "SERVICE CROSSING", the sill too high, the carriage in its bay. The weighbridge reads "A HEAVY LOAD ON IT SHUTS THE CROSSING" |
| Visible objective | The Check on G's middle, straight through the upper doorway: where the scenario's own goal plate always stood |
| Obstruction | The sill (1.9 m), and the weighbridge that holds the crossing shut while the HEAVY carriage is anywhere it is a step within reach |
| Controls | The service drive (2.3 m/s, was 1.1); the LIGHTENER, whose sign says what it does; the HOLD-OPEN BOLT on G, whose sign says it keeps the crossing open and lowers the return stair |
| State | Carriage placed: shut. Placed and `lightened`: open, with the step still there. The carriage's own readout says what it reads, and for how long |
| Valid alternates | Blink, double jump and grapple reach G (V-10: 24, 9 and 7 arrivals); a lighter object in the recess; standing in the closing shutter (interlock). None is nerfed |
| Refused bypasses | Any claim from outside G, by walk, hop, rail, carriage, blink, double jump or grapple. The carriage ridden in transit |
| Reward | The claim on G. Not gated on the bolt (D12 R1) |
| Return | Back down through the return gap after any arrival; the bolt's stair after it is pulled. The bolt stays thrown and says so |
| Reset/reload | Unchanged: the bolt persistent, `lightened` ephemeral, the carriage package-local |

- **What changed:**
  - The Check's objective volume moved within G. In the room's own
    frame it was at x 6.0, z 9.5, beside the return gap; it is now at
    x 0.0, z 10.2, beyond the upper doorway, 3.35 m from the nearest
    floor cell. In the registry's frame (entry at z 0) that is
    `[6.0, 1.9, 16.75]` to `[0.0, 1.9, 17.45]`: registry geometry (N-1,
    agreed).
  - The HEAVY plate runs back along the drive lane as a **weighbridge**
    to z 2.3, so the carriage is on it wherever it is a step within
    reach of the sill. Parked, it is clear of it, so §4's opening state
    is unchanged: the crossing starts open (N-2, agreed).
  - The drive runs at 2.3 m/s, where it was 1.1.
  - There are signs for the crossing, the weighbridge, the lightener and
    the bolt. They say what each thing does, never the order to do it
    in.
  - The carriage has a live readout ("READS HEAVY", "LIGHTENED: READS
    MEDIUM 6 s").
  - The carriage is dressed as guided service hardware: frame, deck,
    buffers, hazard banding, and guide shoes on the rails. It is meshes
    only and provisional, for Arty's H-MACHINE-ART; the collider is the
    same 2 x 1 x 2 m box.
  - The bolt now stays thrown once its latch is set, restored saves
    included: "BOLT HELD -- CROSSING OPEN, RETURN STAIR DOWN" (D-07's
    permanence, `CallLever.done_label`).
- **`godot-minor-claim`**, new and in CI, has 17 checks on the played
  candidate:
  - every declared minor is built as itself;
  - a claim census of each hosted room, with a played witness when it
    finds anything;
  - G unreached from the arrival as built;
  - V-10 at the schema maxima: 8,680 blinks, plus double-jump and
    grapple flights, with zero claims off G;
  - the ride sweep of 14 jump points;
  - the return after an alternate arrival, and again after the bolt.
- **Sabotages** (`H-UNWEIGHTED_sabotages.log`), each restored
  byte-for-byte: the Check back at its old spot (SU-1), the old plate
  and drive (SU-2), the bolt springing back (SU-3), the return gap
  walled up (SU-4) and the Unweighted shell refused (SU-5). Each fails
  by name.
  - Two of them first exposed holes in this suite, fixed before it was
    trusted.
  - The ride sweep counted a landing on the sill as a miss, so on the
    old plate it passed. It now counts the crossing, and fails there.
  - A refused shell made the census measure one room fewer and pass.
    The suite now requires every declared minor.
- **`godot-unweighted`'s crate-top walk.** The walker counted 1.4 m from
  the carriage's centre as arrived. That is also its south edge, where a
  body perches off the floor. The room as it was passed. The repaired
  room perched, with each change (weighbridge, drive speed, skin,
  readout) reverted in turn. The walk now goes into the top's footprint
  and waits to land. The assertion is unchanged, and 70 checks are
  green.
- **What the owner will notice:**
  - The Check is visible through the upper doorway and can only be
    taken on the gallery.
  - The carriage drives twice as fast, looks like a guided machine, and
    says what it weighs.
  - Standing on it while it drives no longer gets you up. The lightener
    is the way, or a movement power.
  - The bolt stays thrown once pulled.

## CP2 — `H-PRESSURE-R`: the lever route played live (Dess's D-7.2, D-7.3)

Dess's 1c (`462bf42`) composes `lever -> LATCH -> shutter`, and
`lever_route_zone.json` is that composer's output on the played Zone:
the lever in c002, the shutter across `e:c002:c003`.

- **`godot-latched-route-live` takes a form** (`LATCH_FORM`, default
  `legacy`).
  - The seed tool gets `--form` and the matching `--expect` fixture.
  - The driver gets `--latched-form=`. It checks that the served Zone
    declares that form's control (a `PRESSURE_PLATE` for legacy, a
    `PULSE_BUTTON` for the lever) and that the control is built as
    one, before it plays anything.
  - The legacy form is unchanged apart from that check: M-1's replay
    still steps on and off the plate (play 19, restore 13).
- **`godot-lever-route-live`** (new, in CI) runs the lever form in its
  own save directory (`H-PRESSURE-R_lever_live.log`):
  - seed: the real path generates zone_001 with no graph; the tool
    composes the lever route, identical to the fixture;
  - play (20 checks): the arena cleared with the base kit; the bolt
    pulled once with the real interact; one real `latch_fired`,
    accepted, in the snapshot and in the save file on disk; the forged
    latches refused; the bolt stays thrown and says so ("BOLT THROWN --
    THE WAY IS OPEN"); the way open with nobody at the lever; through
    into c003;
  - restore (14 checks), both processes new: the latch handed back
    before the first evaluation, the way open at once, nothing
    announced, **the bolt restored thrown** and never pulled in this
    process, and the doorway walked through.
- **Sabotages** (`H-PRESSURE-R_lever_live_sabotages.log`), each
  restored byte for byte:
  - SL-1, a restored latch no longer locks its lever (only a fresh throw
    does): the restore fails by name, "the bolt is restored THROWN"
    reading `[E] THROW BOLT -- OPENS THE SHUTTER`.
  - SL-2, the play phase told `legacy` on a lever seed: it fails at the
    form check before playing.
- **The fixture targets (D-7.3):** `lever-route-fixture` and
  `held-route-fixture` are added with Dess's recipes, and
  `latched-route-fixture`'s comment now calls its fixture M-1's legacy
  input. All three regenerate byte-identical to the committed fixtures.
- **What the owner will notice:** nothing new in the played candidate
  (M-1). A newly composed route shows the bolt, which is covered here
  across a real restart.

## CP2 — `H-PRESSURE-R`: the held route played (Dess's D-4) — repaired

D13 1d is D-07's held sensor with D-07's guarantee: "Pressure present =
active. Pressure removed = inactive. [...] there must be a guaranteed
physical way to keep pressure on it, such as a movable object/weight."
Dess's `held_route_zone.json` is the played Zone with an object-only
MEDIUM plate in c002, `held_by` a 40 kg `counterweight` homed in c002
(volume c001 and c002), driving the shutter across `e:c002:c003`
directly, with no LATCH.

- **The reproduction, on the fixture as it stood**
  (`H-PRESSURE-R_held_repro.log`). The new `godot-held-route` played it
  with the real player: 14 of 28 checks failed.
  - The engine placed the held plate at the legacy spot, because it
    placed every plate there (M-1). In c002 that spot is entirely under
    the low gallery (under 2 m of headroom), beside its support post.
    The survey in the log maps it.
  - A player cannot stand under it, and a carried weight rides at about
    1.4 m, so the carry sweep met the gallery and held the weight back:
    every attempt stopped 2.2 to 2.6 m from the plate's centre.
  - **The declared weight could not be put on the plate at all**, so
    the door could never be held open. The route the bridge certified
    was physically impossible in the engine.
- **The repair (engine only, `room_graphs.gd`):**
  - **A held plate is placed by the measured rule, as a lever is.** No
    saved Zone ever held one, so M-1 does not pin it to the legacy spot.
    Legacy step-once plates are placed exactly as before.
  - **It is a load pad, 1.4 m square** (`HELD_PLATE_SIZE`). It takes one
    carried 0.34 m weight, not a crate or a person. At the full 2.4 m
    the measured rule found no clear floor in c002 and refused the graph
    (SH-2 below).
  - **It says what holds it:** "LOAD PLATE -- HOLDS THE SHUTTER OPEN /
    WHILE THE COUNTERWEIGHT RESTS ON IT". **The weight says what it is
    for:** "COUNTERWEIGHT · 40 kg / FOR THE LOAD PLATE". Both are
    presentation, read from `held_by`; the weight's identity, mass and
    rules stay the declaration's.
- **Played after the repair** (`godot-held-route`, new, in CI; 33
  checks; `H-PRESSURE-R_held_after.log`):
  - build: nothing refused; an object-only MEDIUM plate; one 40 kg MEDIUM
    weight at home; the doorway shut; both signs present and naming each
    other. The pad stands
    3.4 m from its doorway, and the weight's home is 8.3 m from it;
  - played:
    - the rooms cleared with the base kit;
    - the player standing on the pad reads nothing, and the doorway
      stays shut (object-only);
    - the weight picked up with the interact ray, carried on, and put
      down 0.09 m from the pad's centre; the pad reads MEDIUM, and one
      `object_settled` is reported;
    - the doorway opens, and stays open for 5 s with nobody near;
    - through into c003 and back the same way;
    - lifted, it shuts, and nothing latched; put back, it opens again;
      the reported pose is exactly where the weight lies;
  - reloaded: a rebuild from that pose alone, with no latch and no plate
    state, puts one weight back where it was left, and the doorway opens;
  - the interlock: with the player standing in the open doorway, the
    weight is moved off the pad. The panel is refused its closure 3
    times, never comes below fully open, costs no health and moves the
    player 0 m. Stepping out, it shuts.
- **Declared harness steps:**
  - releasing the layout hold with no bridge;
  - the rebuild from the reported pose, standing in for the bridge's
    `object_poses` across a reload;
  - the interlock's move of the weight. A hand cannot lift it from the
    doorway here: the pad is 3.4 m away and the interact ray reaches
    3 m. So the move stands in for anything else that shifts the weight
    while somebody is under the panel.
- **Sabotages** (`H-PRESSURE-R_held_sabotages.log`), each restored byte
  for byte:

| # | Rule removed | Caught by |
|---|---|---|
| SH-1 | a held plate placed by the legacy rule again | 14 failures: the reproduction returns. The carry stops short, the weight is never put down, and the doorway never opens |
| SH-2 | a held plate at the full 2.4 m | the build refuses the graph: "no clear floor for sensor 'weight_plate'" |
| SH-3 | the declared weight never named | "the weight says what it is for: '(no label)'" |
| SH-4 | the held plate counts the player | "an object-only MEDIUM plate", and standing on it reads MEDIUM |
| SH-5 | the panel stays open once opened (a latch in disguise) | "LIFTED ... the doorway SHUTS (1.00 open)", and both interlock checks |
| SH-6 | the interlock does not watch the player | "(occupied false)", and the panel comes down fully on the player, moving them 0.54 m |

- **What stays open:**
  - The reload here is a harness rebuild. A real restart through the
    bridge needs the seed tool to compose this route onto a live Zone,
    and `tools/compose_latched_route.py` is Dess's; note N-8 asks for a
    `--form held`.
  - D-4's "lifting the weight while the player is in the doorway" cannot
    be done by hand at this geometry, as above. The interlock is shown
    with the declared move.
- **What the owner will notice:** nothing in the played candidate, which
  has no held route. A composed held route now puts a labelled load pad
  on open floor, with a labelled weight, and the door is open exactly
  while the weight rests on it.

## CP2 — `H-COUNTERFIRE` (PT-04, D12's card, V-11) — identified, played, repaired

PT-04: "Possibly two Counterfires; shot a target, emergency door opened,
took Check." The packet asks, in this order:
- identify the owner's instance;
- keep legitimate alternates;
- make gunner, receiver, shutter and reward read as one relationship
  without printing the answer;
- make sure a dead gunner never strands the reward.

- **Identification.**
  - **There really are two.** The minors' offer order turns with the
    Zone's ordinal (`minor_hosting.offer_order`). So the candidate hosts
    EX50-021 in zone_001 (c025) and again in zone_002 (c024), as the
    candidate-live logs show.
  - **The "emergency" target is the room's own receiver.** Its sign read
    "EMERGENCY IMPACT TRIP / SERVICE SHUTTER", and a hit on its face
    opens the shutter for 8 s. That is the designed relationship
    (EX50-021 §3), not an unrelated control.
  - **The owner's route is legitimate, so nothing is removed.** A shot on
    the receiver's face from the lane side is the designed conservative
    route (§6; D12's "baseline shot at the receiver's face").
  - **Which occurrence the owner played is not in anything we hold.**
    Their save would show it once the game sends `room_entered` (Dess's
    D-2), which lands with the CP4 map work.
- **Played on the hosted room as it stood** (`godot-counterfire-hosted`,
  new; `H-COUNTERFIRE_repro.log`): 10 of 23 checks failed.
  - **The owner's route works.** The Zone's gunner was killed with the
    base kit (4.2 s, 8 hp), the receiver shot on its face from the lane,
    the shutter passed with 5.1 s left, the flank climbed and the Check
    claimed. A dead gunner strands nothing.
  - **The hood holds:** 0 of 97 shots from the arrival side trip it, and
    130 of 393 from the lane side do.
  - **Legibility failed, as reported:**
    - the trip read "EMERGENCY";
    - nothing between the receiver and the shutter changed while the
      window ran;
    - the shutter had no readout;
    - the release sprang back.
  - **PPT-05, found by the new void census: two places dropped a player
    out of the world** (the survey is in the log).
    - The top of the 2.6 m low wall is a 0.4 m step down from the
      flank's reach, and it led onto a strip with nothing under it for
      44 m.
    - Under the flank, north of the annex floor, there was no ground.
  - **PPT-06, found by the return case: the flank could not be walked
    past the Check.**
    - The Check's 1.4 m collider stood on a 1.7 m flank, leaving 0.1 m
      and 0.2 m either side.
    - Stepping round it put the walker off the edge and into PPT-05's
      hole under the flank.
    - So the stair the release lowers, and the reach over the low wall,
      could not be walked to from where the flank is reached. The return
      that did work was through the held-open shutter.
    - I also blamed the 0.8 m slot over the low wall (the hosted
      pocket's north wall against the arcade's east wall, exactly the
      player's width). SC-7 shows a centred walk passes it, so that was
      not established.
- **The repair:**
  - **The trip says what it does:** "IMPACT TRIP / A HIT ON ITS FACE
    OPENS / THE SERVICE SHUTTER FOR 8 s". Nothing names the gunner, the
    bait or the dodge (D12: "without printing the answer on entry").
  - **The conduit from the receiver to the shutter glows** while the
    window runs, and for good once the release is thrown.
  - **The shutter has a live readout:** "SHUT", "OPEN · 6 s",
    "CLOSING", "HELD OPEN BY THE RELEASE".
  - **The release stays thrown and says so**, after a real restart too:
    "RELEASE THROWN -- SHUTTER HELD OPEN, STAIR DOWN" (`locks_with`,
    D-07).
  - **North of the annex is one solid mass, decked at the flank's
    height.**
    - The upper level is now 5.5 m wide, which on its own makes the flank
      walkable round the Check (SC-8, quick).
    - The north-east corner is solid.
    - The hosted pocket's north wall is gone, now that the solid corner
      closes the north. The way over the low wall is 1.2 m: margin for a
      player who is not walking dead centre, not a repair (SC-7).
  - **The Check moved within the flank**, to its north-east corner. Its
    registry volume went from `[13.65, 3.0, 12.25]` to
    `[13.85, 3.0, 16.55]`.
    - At its old spot, above the annex and near the stair, a double jump
      from the annex floor claims it from off the flank. SC-8 on the
      whole suite shows this: V-10 fails there.
  - **The shell's declared surfaces follow the geometry.** `annex_pocket`
    (at ground level) becomes `deck` (y 3), so the shell audit still
    accepts the room.
- **V-10 caught my first repair.** Flooring the pocket fixed PPT-05's
  second hole, but it made the pocket somewhere to double-jump or
  grapple from and claim the Check over the flank's edge (4 off-flank
  claims). The solid deck is what replaced it.
- **Played after the repair** (25 checks, `H-COUNTERFIRE_after.log`):
  - what the room says, as built and while the window runs;
  - no step off any of 7,906 reached cells lands on nothing;
  - the owner's route, with the gunner dead;
  - back from the flank with nothing pulled, off the reach onto the
    gallery;
  - the hood census;
  - V-10 at the schema maxima: 17,444 blinks and 18 flights, 16 legal
    arrivals on the flank, and no claim from anywhere else;
  - the release thrown for good, down its stair, and back to the arrival.
- **The gunner-driven route** (the bait) is played live through the real
  bridge by `godot-candidate-live`: the gunner baited, the release
  accepted, and Check 89100025 claimed. After a real restart the release
  is restored thrown (a new check there).
- **Declared harness steps:**
  - the census places the player on each sampled cell before firing;
  - `_mobility` places them for each blink and flight, and each case
    returns them to the room's arrival;
  - `ap_connected` is set so a claim can go out with no bridge;
  - the player's health is raised for the V-10 sweep only.
- **Sabotages** (`H-COUNTERFIRE_sabotages.log`), each restored byte for
  byte, on the suite without the V-10 sweep:

| # | Rule removed | Caught by |
|---|---|---|
| SC-1 | the trip says "EMERGENCY IMPACT TRIP" again | "the trip names what it does" |
| SC-2 | the conduit never lights | "the conduit ... LIGHTS while the window runs (0 glowing, 0 before)" |
| SC-3 | the shutter readout never changes | "the shutter says how long it has: 'SERVICE SHUTTER / SHUT'" |
| SC-4 | the release springs back like a call lever | "the release STAYS THROWN": `[E] SERVICE RELEASE ...` |
| SC-5 | the north-east corner open again (PPT-05) | the void census, at the reach's north edge |
| SC-6 | no deck: the pocket floorless under an open flank edge | the void census, under the flank |
| SC-7 | the pocket's north wall back (the 0.8 m slot) | **passes**: a centred walk goes through, so the slot was not a defect, and its removal is margin |
| SC-8 | the Check back at its old spot | **passes the quick suite** (the deck makes the flank walkable). On the whole suite, V-10 fails with a double-jump claim from the annex floor, which is why it moved |
| SC-9 | no hood: the receiver answers either side | the hood census: 59 of 98 arrival-side shots trip it |

- **What the owner will notice:**
  - The target over the lane says it opens the service shutter for 8 s.
  - A hit lights the line from the target to the shutter, and the
    shutter counts down.
  - The release stays thrown, and its stair can now be walked to.
  - The upper level is a proper deck, with nothing to fall off into.
  - The Check stands in the far corner of the deck.

## CP2 — `H-PASSING` (PT-06, PT-07, D12's card): reproduced, and the proposal stated before rebuilding

Delivery plan §4 and D12's card ask that the proposal ("a visible
machinery-locked cabinet or a destination mechanism") be stated before
the room is rebuilt. It is stated here, and the rebuild follows in its
own commit.

- **Played on the hosted room as it stands** (zone_002/c025; the Zone
  captured unedited from the real bridge by `godot-candidate-live`'s
  next phase, never committed; N-10 asks Dess for the fixture;
  `H-PASSING_repro.log`).
  - **PT-06 reproduced.** 233 cells reached from the arrival claim the
    Check with no transfer made. They all stand on the recovery floor
    just west of G, where a hop lifts the eye to 3.9 m, 0.1 m under G's
    floor, and the claim ray skims over G's west lip. Played: the real
    player walked there, hopped, read "[E] CLAIM CHECK 047", and a claim
    went out.
  - **Moving the Check cannot fix it.** The Check was moved over 45
    spots on G and the census re-taken at each: every spot is still
    claimed from that floor, 10 cells at the least. G is 2.95 m wide,
    the claim reaches 3 m, and the lip stands 0.1 m above a hopping
    eye. Unweighted's and Counterfire's repair does not work here.
  - **PT-07 reproduced.** Of four arrivals spread over G, three did not
    release the service stair; only an arrival near the 1.5 m goal plate
    does. A blink or a grapple to G's far side leaves a player 4 m up
    with no way down, which is the owner's "no recognizable return
    except random teleport".
  - **G is not reached from the arrival with the base kit**, and once
    released, the stair walks back down to A.
  - **The census's own error, fixed on the way.** A hop was placed
    without headroom, so under a low ceiling (G's slab over the
    recovery floor) the eye sat inside the slab and saw through it. The
    hop is now capped at the headroom (`ClaimCensus.rises_at`). The fix
    can only ever report fewer claims, so the earlier rooms' passes
    stand.
- **The proposal:**
  - **A destination, opened by the machine: not a cabinet.**
    - The Check stays on G. Reaching G is the objective, and the
      carriers are how you get there.
    - A cabinet whose lock is a machine state would either refuse a
      legal arrival (R1) or impose an input order the owner ruled out.
  - **G's west edge becomes a glass screen, with a gate at the shuttle's
    dock.**
    - The gate opens only while H stands docked at G. That is PT-06's
      "real machinery-operated release condition": the shuttle opens the
      gallery.
    - Nothing on the floor below sees through the glass or reaches over
      it. While H is docked its deck covers the floor under the lip,
      so nothing below reaches over it then either.
    - The screen stays glass, so G and its Check are seen from the
      arrival (the card's "arrival read").
  - **The stair is released by an arrival anywhere on G**: a volume
    over all of G replaces the 1.5 m plate, for every arrival R3 names.
  - **Controls labelled by what they do, and grouped as boards.** Their
    identities are unchanged: "CALL SHUTTLE EAST -- TO THE GALLERY",
    "HOLD SHUTTLE", "RESET BOTH CARRIERS", and so on.
    - The shelf says it is the lift's top.
    - The gate says it opens while the shuttle is docked.
    - Nothing prints the order of operations.
  - **What stays:** V's pause at the transfer plane, H's schedule,
    STOP-and-transfer, RESET, the recovery floor and its stair, the
    service stair and the carriers' persistence.
    - Blink or grapple to H stays the qualified alternate, as the card
      lists it.
    - V-10 will say what the screen does to any other movement arrival.

## CP2 — `H-PASSING` (PT-06, PT-07, D12's card) — repaired: G a glass gallery the shuttle opens

The proposal above, built. Two of its details were changed by what the
runs found; both changes are measured below.

- **What was built** (`passing_platforms_room.gd`):
  - **G is glass on its three open sides**, from under its slab to the
    tops of the walls. It stays in view from the arrival and is out of
    reach from everywhere else. The proposal named the west edge only.
    Both extents were measured:
    - with the west edge glazed, the census still found 34 cells north
      of G claiming the Check over its 1.1 m railing. The Check's
      collider stands 2.6 m tall, and a hop there sees its top (SP-2);
    - with glass only door-high, V-10 found double jumps claiming from
      the air west of G, and 163 blinks landing on G over it (SP-9).
  - **Its one door is a glass gate at the shuttle's dock.**
    - It opens only while H stands docked at G, and shuts when H leaves.
    - It is a `ServiceShutter`, so it never shuts on a body (§21.2).
    - The glass over it reaches 0.3 m below its top edge. Meeting that
      edge edge-to-edge, in the next plane, left a seam that a descending
      ray threaded; V-10 found it from the air west of the gate (SP-8).
    - A save with H docked at G restores the gate already open, in the
      same frame, rather than sliding open in front of the player.
  - **Any arrival on G releases the stair** (PT-07, R3). A volume over
    the whole gallery, from the glass's inner face, does it. Before, only
    the 1.4 m goal plate did; the plate itself is unchanged.
  - **The way back says where it goes:** "STAIR DOWN TO ARRIVAL" at its
    head.
    - The south glass has the stair's cut, removed with the railing's
      when the stair is released.
    - The cut is full height. A first version left glass above it, and
      the player's step, which wants a metre of headroom, would not
      climb the stair's head past the lever there
      (`godot-passing-platforms` caught it).
  - **Every control says what it does, not when to use it.** Their
    identities (the `levers` keys and node names) are unchanged. The 13
    read, for example:
    - "CALL SHUTTLE EAST -- TO THE GALLERY"
    - "HOLD SHUTTLE WHERE IT IS"
    - "RESET BOTH CARRIERS -- LIFT DOWN, SHUTTLE WEST"
    - "LIFT UP TO THE SHELF -- PAUSES AT THE SHUTTLE'S LEVEL"
  - **Three new signs:**
    - "CARRIER CONTROLS" names A's board;
    - "UPPER SHELF -- THE LIFT'S TOP";
    - "GALLERY GATE / OPEN WHILE THE SHUTTLE IS DOCKED".
  - **Supporting changes:**
    - `ServiceShutter.panel_material` (a glass gate is still a shutter);
    - `ThemeMaterials.glass_material()`.
- **Played after the repair** (`godot-passing-hosted`, new, 24 checks;
  `H-PASSING_after.log`), on zone_002/c025, as captured by the new
  `CANDIDATE_DUMP` recipe:
  - **the census:**
    - 0 of 5,814 cells reached from the arrival claim the Check (233
      before);
    - with H docked at G and its gate open, 0 of 5,817;
  - **what the room says:**
    - each of the 13 controls reads as what it does;
    - none of 22 signs and labels prints an order of operations;
    - the gate says what opens it;
    - the Check is in sight from the arrival through nothing but the
      gate's glass;
  - **as built,** G is not reached from the arrival with the base kit;
  - **the gate, played with the real levers at A's board:**
    - "CALL SHUTTLE EAST": H crossed to G in 14.4 s, and the gate stayed
      shut all the way (never above 0.00 open);
    - it opened 1.6 s after H docked;
    - after "CALL SHUTTLE WEST", it shut 1.6 s after H left;
  - **arrivals (R3):** the first arrival on G releases the stair. It was
    placed at G's far south-east corner, 2.6 m from the old plate's
    centre, where the plate alone does not reach (SP-6). The stair,
    signed at its head, is walked back down to A;
  - **the interlock:**
    - the player stood in the open gate and pulled "SEND SHUTTLE WEST"
      on G;
    - H left, and the gate was refused its closure 4 times;
    - it never came below fully open, cost 0 health and moved the player
      0 m;
    - once the player stepped out onto G, it shut;
  - **restore:** with H restored docked at G, the gate is open in the
    same frame; with H restored at the west berth, it is shut;
  - **V-10** at the schema maxima, on a fresh build of the same Zone:
    - 27,132 blinks and 18 flights;
    - no claim from anywhere but G;
    - 2 grapples (3 in a run on the first capture) arrive on G over the
      glass's top. Those are legal arrivals (R1), and the first of them
      released the stair (R3).
- **The baseline route through the real bridge.** `godot-candidate-live`,
  on this tree, is green in all eight phases, and its `next` phases play
  this same hosted room (`H-PASSING_candidate_live.log`):
  - LAUNCH on the lift, then a step across onto the restored held
    shuttle, then H ON EAST to the east berth;
  - walked off through the gate onto G. The stair was released and
    ACCEPTED as `minor_c025/stair`, and Check 89100005 was CONFIRMED;
  - after a real restart, the shuttle is restored at EAST, "and G's
    glass gate stands open, its shuttle docked there (1.00 open)" (a
    new check). The stair is then walked up from A onto G.
- **The standalone scenario** (`godot-passing-platforms`,
  `H-PASSING_standalone.log`): 70 of 70.
  - The continuous run, the patient route and the counterpart pass
    through the gate unchanged.
  - Its walker, coming up the stair, steps onto G over the 0.35 m plinth
    of the "SEND SHUTTLE WEST" lever at the stair's head, as it did
    before this change. Its feet end in exactly the same place.
- **Declared harness steps:**
  - the player is placed on each arrival point on G, and back at the
    arrival between cases;
  - `_mobility` places them for each blink and flight;
  - health is raised for the two censuses and the V-10 sweep;
  - the restore case calls the room's own `restore_carrier`, as the
    hosted room does before the player arrives.
  - Every lever is pulled by the player: aimed at, interact pressed.
- **Sabotages** (`H-PASSING_sabotages.log`), each restored byte for byte;
  the quick suite without V-10, except where the row says V-10:

| # | Rule removed | Caught by |
|---|---|---|
| SP-1 | no glass on G's west edge | the census (54 cells over the west lip), the glass check, and the docked census |
| SP-2 | no glass on G's north edge | the census (34 cells over the north railing), the glass check, and the docked census |
| SP-3 | the gate always open | the census (25 cells) and its **played witness**: the real player hopped at the lip, read "[E] CLAIM CHECK 005", and a claim went out. Also "shut as built", "stayed shut all the way", "shut behind it", and the interlock |
| SP-4 | the gate never opens | "docked at G, the gate opens", and the interlock case (no open gate to stand in) |
| SP-5 | the gate opens with H at either dock | the census and its played claim (as SP-3), "shut as built", "stayed shut all the way", and the restore at the west berth |
| SP-6 | only the goal plate releases the stair (PT-07) | "the first arrival on G releases the service stair": the far corner did not |
| SP-7 | the controls read as codes again | "each of its 13 controls reads as what it does": all 13 wrong |
| SP-8 | the glass over the gate meets its top edge to edge (V-10) | V-10: a double jump claims through the seam from the air west of the gate |
| SP-9 | the glass only door-high, as the proposal had it (V-10) | V-10: double jumps claim from the air west of G, and 163 blinks land on G over it |
| SP-10 | a restored shuttle does not bring its gate back | "restored docked at G, the gate is open in the same frame" |
| SP-11 | the stair released, its glass left uncut | the walk back down stops at the glass, and the interlock case cannot climb to G |

- **What stays open:**
  - **N-10:** the hosted suite needs Dess's `passing_zone.json`. Until
    then it runs on a local capture, and it is not in CI.
    - `make godot-candidate-live CANDIDATE_DUMP=<path>` writes the
      capture.
    - `make godot-passing-hosted PASSING_ZONE=<path>` plays it.
    - Two captures differed only in c025's Check id (89100047 and
      89100005); the room is the same.
  - **Which occurrence the owner played is not in anything we hold.**
    PT-06's "directly reachable" matches the 233 lip cells, but the save
    that would show it needs `room_entered` (D-2, with CP4's map work).
- **What the owner will notice:**
  - G, the goal gallery, is behind glass on three sides. You can see the
    Check from the arrival, and you can't reach it from the floor.
  - Where the shuttle docks, the glass is a gate. It slides up while the
    shuttle stands there and down when it leaves.
  - Every lever says what it does when you aim at it.
  - Getting onto G anywhere opens the stair back down, and the stair's
    head says where it goes.

## CP2 checkpoint — closed (the full frontier)

- **On `6e1c60b` (H-PASSING's head):** 73 of 74 steps passed, 06:24 to
  07:45 UTC (`CP2_frontier_on_6e1c60b.tsv`).
  - The steps are CP1's 68 and this checkpoint's six:
    - the four suites CP2 added to CI: `godot-counterfire-hosted`,
      `godot-held-route`, `godot-minor-claim` and
      `godot-lever-route-live`;
    - `godot-passing-hosted`, on the capture (not in CI; N-10);
    - the three route fixtures regenerated from source: byte-identical,
      and restored.
  - **The one failure was `make test`,** 1 of 2,221
    (`CP2_make_test_on_6e1c60b.log`). `test_ci_coverage` found
    `godot-passing-hosted` neither run by CI nor listed in
    `NOT_A_SUITE`. It was a real finding, and this lane's own: the target
    was added without saying why CI does not run it.
  - **Fixed at `22f59c1`.** The target is listed in `NOT_A_SUITE` with
    its reason (no fixture carries a Zone that hosts EX50-011; N-10), the
    way `godot-return-journey` is. `make test` on `22f59c1`: 2,221 passed
    (`CP2_make_test_on_22f59c1.log`).
  - The tree at the end differed only in `captures.json`'s provenance
    stamp, which `godot-zone-audit` writes. It was restored.
- **CP2 is closed.** As at CP1, the frontier was not re-run in full for
  a change to a test's list. These are local results; remote CI was not
  polled.

## CP3 — `H-3D-SHELL` (V-18): the pause interface in real 3D — landed

`04_3D_MENU_MAP_AND_GLYPH.md` §1 and §3: four inward-facing pages in
actual 3D space, the owner's inside of a box. Turning left proceeds
Settings, Equipment, Map, Journal and back to Settings; right reverses
it. Not a picture on a rectangle, not a cube seen from outside, and not
a flat tab strip squeezed to nothing.

- **Before:** Escape opened a flat pause panel, and Tab a separate flat
  inventory. Both were `CanvasLayer`s over the game, with nothing 3D.
- **What was built** (`godot/scripts/ui/menu_shell.gd`, new):
  - **A box in its own `World3D`** (a SubViewport with `own_world_3d`).
    It has four walls, a floor, a ceiling and corner pillars. The camera
    stands at the centre. Nothing of the dungeon is in it: walls,
    lights, physics or field of view.
  - **A turn is the camera turning,** a quarter turn eased over 0.42 s.
    At rest the front wall faces the camera squarely and fills 86% of
    the view's height. With `motion_intensity` at 0 (the existing
    motion-sickness option) a turn is a cut instead, through the same
    walls in the same order.
  - **Live pages.** Each wall shows its own SubViewport's texture, with
    an ordinary Control tree in it.
  - **The pointer is carried by geometry.** The ray from the camera
    through the pointer, met with the front wall's plane, gives the page
    pixel the event is pushed to. There is no physics query: H-PAUSE
    must not need the physics server to make a menu clickable.
    - Clicks during a turn are dropped.
    - A focused text field keeps its letters: Q and E type there and do
      not turn.
  - **Input:**
    - Q and E, or the gamepad bumpers (`menu_page_left` /
      `menu_page_right`, new actions), turn the box;
    - large on-screen arrows turn it too;
    - Escape closes it from any wall;
    - Tab turns to Equipment, and closes from there.
  - **The two walls not built yet say so:** "The map is not built yet
    (H-3D-MAP). This wall holds its place." Likewise the journal.
  - **In the game** (`main.gd`), the pause menu and the inventory are its
    first two walls, unchanged in what they say and send. Escape opens
    it on Settings and Tab on Equipment. RESUME, RETURN TO HUB and
    ABANDON each close it; the named `modal` hold still applies.
- **Played** (`godot-menu-shell`, new, in CI, 18 checks;
  `H-3D-SHELL_after.log`). Every click and key there is an `InputEvent`
  parsed into the engine.
  - **The box:**
    - its own World3D;
    - four walls, each 1.0 m from the camera at the centre and facing it
      squarely.
  - **The order:** left, right and by the on-screen arrows.
  - **A turn is a turn:**
    - the camera's yaw runs monotonically from 0 to 90 degrees;
    - no wall moves, turns or scales;
    - halfway round, two walls are in view.
  - **At rest:** the front wall is square and fills 0.86 of the height.
  - **The pointer:**
    - a click where the Settings button is drawn presses it;
    - the same point, with Equipment in front, presses Equipment's
      button and not Settings';
    - mid-turn, a click where the arriving wall's button is drawn at that
      moment presses nothing, and the same button is pressed once the
      turn is at rest.
  - **The keys:** a clicked text field types "qe"; Tab and Escape
    behave as above.
  - **Reduced motion:** a cut, in order.
- **In the real game, through the real bridge** (`godot-candidate-live`,
  whose `next` phase abandons a Zone from the pause menu;
  `H-3D-SHELL_candidate_live.log`). Real Escape and Tab actions go
  through the input pipeline. Three new checks:
  - Escape opens the interface on its Settings wall with the pause menu
    drawn there, and the player is held;
  - Tab turns it to the Equipment wall, with the inventory drawn there;
  - after ABANDON ZONE and CONFIRM ABANDON, it closes behind the abandon
    and the player is released.
  All eight phases are green.
- **What it draws** (`make menu-shell-shots`, xvfb and OpenGL at 1280 by
  720; `H-3D-SHELL_shots/`):
  - the four walls at rest, and the frame halfway from Settings to
    Equipment;
  - each is at least 93% page or box, not background.
  - The pages read unmirrored, and the turn shows both walls in
    perspective from inside the box.
- **Found and fixed on the way:**
  - A headless window is 64 by 64 whatever `project.godot` says. At that
    size the left arrow covered the centre of the page, so the driver
    sizes its window to 1280 by 720.
  - In Godot 4, `position` is from the parent's corner, not from the
    anchor, and it put both arrows above the screen. They are now placed
    by offsets from their anchors.
  - Each wall is narrower than the box's side, so the thin corner posts
    left a gap that showed mid-turn. The corners are now pillars that
    meet both walls' edges.
- **Sabotages** (`H-3D-SHELL_sabotages.log`), each restored byte for
  byte. The sabotage run came before the pillars' colour changed, which
  is the only change since.

| # | Rule removed | Caught by |
|---|---|---|
| MS-1 | the pointer always reaches the first wall | "the same point, with Equipment in front, presses Equipment's button", and three more |
| MS-2 | a turn is a cut, not a turn | "the camera's yaw runs monotonically ... over 1 frame" and "halfway round, both in view" |
| MS-3 | a focused text field loses Q and E | "a clicked text field keeps Q and E" |
| MS-4 | the order reversed (left turns right) | "turning LEFT visits ...", the reduced-motion order, and the pointer checks that depend on it |
| MS-5 | clicks reach the page mid-turn | "a click in the middle of a turn ... presses nothing", **after** the check was strengthened (below) |
| MS-6 | the box in the dungeon's world | "the box renders in its own World3D" |
| MS-7 | Escape does not close it | "Escape closes it from any wall" |
| MS-8 | the walls face out of the box | "four walls ... facing it squarely", and the square-at-rest check |

- **A check that passed for the wrong reason:** MS-5 first **passed**.
  The mid-turn click landed where the arriving wall had no button, so
  "presses nothing" held with or without the guard. The check now puts
  a button on the arriving wall and clicks where it is drawn 70% of the
  way through the turn. MS-5 fails it, and the unsabotaged shell passes
  it.
- **What it is not yet:**
  - The world behind it does not pause: that is `H-PAUSE`, next.
  - The pages are the old flat UIs drawn on the walls, in the engine's
    default theme. The equipment face on Glyph assets is `H-INVENTORY`,
    which waits on Arty's `H-GLYPH-KIT`; the arrows and panels are
    Glyph's to supply.
  - The map and journal walls are placeholders that say so.
  - The owner has not seen it in-engine; usability and visual approval
    stay open.

## CP3 — `H-PAUSE` (V-16, V-17): the world stops behind the interface — landed

§4: "Pause is a world boundary, not an input hold." The policy is the
packet's own proposal:
- the dungeon, AI, projectiles, physics machinery, cooldowns and the
  lifetimes of temporary effects stop advancing;
- the interface keeps animating;
- the external AP world is not paused.

- **Before:** opening the pause menu or the inventory only held the
  player's input (the named `modal` hold). Everything else went on
  behind it: enemies, machinery, timers, and the effects of the bridge's
  answers.
- **What changed:**
  - **`PauseClaims`** (new) makes `SceneTree.paused` a set of named
    claims, like the player's input holds. The world runs again only
    when nobody holds one.
    - The shell holds "menu" while it is open, and releases only its own
      claim.
    - Freed while open, it lets its claim go.
  - **`BridgeClient` runs through a pause** (`PROCESS_MODE_ALWAYS`): the
    connection, snapshots, notifications and refusals stay live.
  - **Five SceneTree timers now pause with the world.** They ran through
    a pause by default: the respawn delay, a tracer's life, an echo
    marker's life, a HUD toast and a reveal's hold.
  - **The race §4 names:** a consumable asked for, then a pause before
    the answer. The policy is proposed here; D-9's accounting is
    unchanged:
    - an answer that lands while paused is kept;
    - the charge is paid, and it is not refunded;
    - nothing goes into the stopped world, since an instant effect would
      change it while it is stopped;
    - the effect fires once, on the first step the world takes again.
    - If the slot changed during the pause, the existing slot-change rule
      applies: the authorisation is released and nothing fires.
  - **The audit found nothing else.** No other gameplay code used a
    SceneTree timer or the wall clock for game state. One cosmetic idle
    orbit reads the clock; it simply resumes where it is.
- **Played:**
  - **`godot-menu-shell`** (23 checks, all with the world paused while
    the shell is open; `H-PAUSE_menu_shell.log`):
    - open for 0.7 s, a pausable node gets no frames, a rigid body does
      not fall, and a 0.3 s timer does not fire;
    - the bridge client runs, and the interface still turns;
    - another owner's claim survives the shell's close;
    - once nobody holds a claim, the world runs on: 102 frames, the body
      falls 2.40 m, and the timer fires.
  - **`godot-consumable-live`**, through a real bridge
    (`H-PAUSE_consumable_live.log`):
    - the race: answered while paused (1 authorised), and a second later
      nothing has gone into the stopped world;
    - the charge is spent, not refunded (2 of 3);
    - closed, the effect fires once, and the save authorised exactly
      the effects that ran (3 and 3);
    - a death behind the interface: dead, then paused 2.5 s, past the
      1.5 s respawn delay, and still dead. Closed, the respawn follows.
  - **`godot-candidate-live`**, through a real bridge, in a real Zone,
    with real Escape and Tab (`H-PAUSE_candidate_live.log`):
    - the world is paused behind the interface, by the menu's claim
      alone, and the bridge is still connected;
    - **one real equip with the world paused:** "TO Shift" pressed on
      the Equipment wall. The bridge answered (mobility: none ->
      `act_l89100055`), the world stayed paused, and the wall was
      repainted from the answer. The loadout was then put back, as a
      declared harness step;
    - after the abandon, the world runs again and the player is
      released.
  - Also green: `godot-consumable-restart`, `godot-boot`, `godot-hud`,
    `godot-archive`.
  - The live consumable seeding is now 5 charges (it was 4), so that the
    drain case still drains one.
- **Sabotages** (`H-PAUSE_sabotages.log`), each restored byte for byte,
  each against the suite that should catch it:

| # | Rule removed | Caught by |
|---|---|---|
| MP-1 | the interface does not pause the world | shell: "open for 0.7 s: the world is paused" |
| MP-2 | the bridge client pauses with the world | consumable: the answer never arrives while paused ("timed out waiting for the engine's answer, with the world paused") |
| MP-3 | an answer during the pause fires into the stopped world | consumable: "nothing went into the stopped world ... (1 effect(s))" |
| MP-4 | the respawn timer runs through the pause again | consumable: "still dead, because the respawn waits for the world" |
| MP-5 | closing releases every claim, not only its own | shell: "another owner's pause holds ([])" |
| MP-6 | a held answer is never let go | consumable: ten failures, from "the effect fires once (2)" to "42 run of 5" |

- **What stays open:**
  - **A disconnect during the pause is not played.** D-9's dropped-link
    rule (`_abandon_awaiting`) applies unchanged, because the client
    keeps running; the outage case plays it unpaused.
  - Audio players pause with the tree, which is Godot's own behaviour;
    that is not separately tested.
- **What the owner will notice:**
  - Escape stops the game. Enemies, shots and machines freeze behind the
    menu, and carry on from where they were when it closes.
  - Items and answers from the multiworld still arrive while the menu is
    open.
  - A consumable used just before opening the menu goes off when you
    close it, once, for one charge.

## CP3 — `H-INVENTORY` (§5): the Equipment wall, three regions on the inventory view — landed, on provisional art

§5 asks for three regions on the Equipment wall: the equipped build, a
grid of owned items, and the selected item's detail and comparison. They
must fit the data that exists, and every equip must follow the
authority. The wall is built on Dess's `CampaignSnapshot.inventory`
(H-UI-DATA). Its look is provisional until Arty's Glyph kit
(H-GLYPH-KIT) arrives; the wall says so in its footer.

- **Reproduced first**, on cb8dbd6 (`H-INVENTORY_before.log`). The wall
  then held the Echo archive (`InventoryLayer`). A scratch driver asked
  it §5's questions on the same real snapshots the new suite uses. Its
  source is `H-INVENTORY_repro_driver.gd.txt`; it is evidence, not a
  suite. **9 of 9 requirements fail:**
  - **R1:** one Action is offered for equipping by 2 separate rows: its
    creating Echo's, and the upgrade-only Leather Grip's.
  - **R2:** the wall is one scrolling list of 12 rows under a loadout
    bar. There is no grid and no selected-item detail.
  - **R3:** an equip pressed with no link changes none of the wall's 100
    texts.
  - **R4:** an equip that was sent changes nothing until a snapshot
    arrives. There is no pending state.
  - **R5:** a refusal naming that exact equip changes nothing, and no
    text on the wall carries the bridge's reason.
  - **R6:** the consumable key reads "—" when you own none and when you
    own two.
  - **R7:** offline and online, it reads the same "2 / 3".
  - **R8:** with a use awaiting the bridge, it shows a smaller number and
    no word saying why.
  - **R9:** after Glow Seed arrives, no text says NEW.
- **What changed:**
  - **`EquipmentFace`** (new, `godot/scripts/ui/equipment_face.gd`) is
    the wall's content, mounted where `Main` mounted the archive. It has
    three regions:
    - **EQUIPPED:** the five keys the game has (`Constants.SLOT_NAMES`).
      Each shows what is on it, its real binding (`SlotKeycaps`), a way
      to clear it, and the latest request's answer. The consumable key
      says which of its states it is in, in words, with its count.
    - **OWNED:** a grid with one tile per owned item and never one per
      Echo. Each tile has a provisional icon (a tinted square and a
      word), the name, Mk, uses left, the key it is on, and NEW. Search
      and sort are above the grid. A key filter shows what goes on that
      key, says the always-on items are hidden, and puts SHOW ALL beside
      that.
    - **DETAIL:** what the item does, how it is used (activation and
      every restriction), what it costs, and how it differs from what is
      on its key (now → this). Then why EQUIP is not offered, if it is
      not; the other items from the same Echo; and HISTORY, folded after
      the summary: the whole provenance chain and what Epsilon read.
  - **`EquipmentQuery`** (new) holds every answer with a right or wrong
    to it, with no Control involved. An item is an entry of the view,
    joined to `mechanics.owned` by component id, so upgrades are
    history on the item. Which key an item goes on is the view's
    `compatible_slots`, never derived again.
  - **`EquipRequests`** (new): an equip is a request, and it has five
    answers:
    - PENDING;
    - ACCEPTED, when a snapshot carries the key holding it;
    - REFUSED, on an exact `about` key only;
    - NOT SENT;
    - LOST, when the link drops mid-request.

    One request per key, and the newest wins. It follows the pattern
    `zone_state_selected` already uses.
  - **`EquipmentSeen`** (new): the NEW marker. It is kept per campaign,
    like `Favourites`, and never touches the save.
    - The first time a campaign is met, what it already owns counts as
      seen.
    - A new item stays NEW until it is inspected, not merely until the
      menu opens.
  - **`EffectSummary`** now covers all 28 Action primitives (six had a
    line) and the status-on-hit modifier. The reveal card reads it too.
  - **`BridgeClient`** gains three accessors:
    - `inventory_view()`;
    - `can_send()`, which is `send_intent`'s own test;
    - `awaiting_authorization()`, D-9's pending uses.
  - **`SlotKeycaps.of_action`** lets the wall's hints name the real
    bindings.
  - **Removed:** `InventoryLayer` (the archive). Its tests moved to the
    item face; the table below maps each one.
  - **The fixture is real:** `make equipment-fixture` builds seven
    variants as `CampaignSnapshot`s from the bridge's own model, so the
    `inventory` in them is the projection itself.
    `bridge/tests/test_equipment_fixture.py` keeps the JSON equal to
    its generator. It also checks that every log could have been granted
    and that each variant holds the state it is named for.
- **Two findings from the first runs, both repaired:**
  - **EI-F1: a controller could move but never press.** Godot's default
    `ui_accept` in 4.5.1 is Enter, keypad Enter and Space. It has no
    pad button, so the d-pad moved focus around the wall and A did
    nothing. `pause` and `inventory` had no pad binding either.
    - `project.godot` now binds pad A to `ui_accept` (Godot's three
      keys kept), Start to `pause`, and Back to `inventory`.
    - The first run's "A chooses: act_bolt" (it stayed on the previous
      item) is in the raw `H-INVENTORY_first_run.log.gz`. EI-14 re-breaks
      it.
  - **EI-F2: EQUIP scrolled out of reach.** A long comparison pushed
    the button below the detail's fold, and a click through the box at
    its position hit nothing ("a click on REPLACE sends it: []").
    - The decision controls, the reason and the request's answer now
      sit in a fixed footer under the scrolled detail.
    - Both scrolls follow keyboard focus.
    - EI-15 re-breaks it.
- **Played:**
  - **`godot-equipment-face`** (new, 107 checks;
    `H-INVENTORY_after.log`). It runs on the real 3D shell, with real
    snapshots delivered through `BridgeClient._handle`. The same 9
    requirements, measured the same way, all hold:
    - **R1:** one tile per inventory item (9 of 9). Leather Grip is not
      a tile. Pressing every equip control on the wall offers Braided
      Lash once. Its Mk II line (+4 damage ← Longshot) is in its
      history.
    - **R2:** the three regions sit side by side inside the 1280×720
      page, under the wall's title, on the Equipment wall's own page
      viewport. There is a row for each of the 5 keys.
    - **R3:** offline, EQUIP is not offered and says why, the
      non-drag equip sends nothing, and the EQUIPPED column says the
      link is down. A send that fails (stub sender) reads NOT SENT on
      its key.
    - **R4:** "REPLACE BRAIDED LASH ON RMB" sends one `slot_action`.
      - The key still shows Braided Lash and says the request is
        waiting.
      - A second press is not offered while it waits.
      - An unrelated snapshot answers nothing.
      - The snapshot that carries it moves the key and reads ACCEPTED.
      - TAKE OFF is a request too.
    - **R5:** an `error` with no `about` resolves nothing and is shown
      as the bridge's, unattributed. So does one naming another request.
      The exact key reads REFUSED, with the bridge's reason; the key
      never showed Arc Bolt; and EQUIP is offered again. A lost link
      reads LOST.
    - **R6–R8:** the consumable key reads six different ways: none
      owned, owned and not equipped, equipped at 0 / 3 with what refills
      it, ready at 2 / 3, disconnected (count kept), and "1 use waiting
      for the bridge's answer" beside the HUD's 1 / 3. With nothing in
      flight, the client's count equals the view's in every variant.
    - **R9:** a campaign met for the first time marks nothing NEW. Glow
      Seed arrives NEW, and only it. OWNED counts it. Inspecting it
      clears it. A campaign met already holding it does not call it
      new.
    - **The detail:**
      - Cinder Charge reads "Thrown: bursts for 30 damage within 3.0 m
        after 1.5 s", "Hits leave burning for 3.0 s", its key, and that
        the status lands on enemies.
      - It shows "2 of 3 uses left", its cooldown, and "3 uses per
        supply. Entering a Zone refills it".
      - Warding Loop says it does nothing while Arc Bolt is off its key,
        and that it is on once Arc Bolt is.
    - **Input:**
      - Q, C and E typed into search go into the box. The box does not
        turn, no intent leaves, and no key event gets past the shell.
      - Arriving on the wall, the selected tile holds focus.
      - Arrows and the d-pad move focus; Enter and A choose; A on EQUIP
        sends it.
      - A click carried through the 3D stage chooses a tile, presses
        REPLACE and filters by key.
      - Turning to the journal and back keeps the item, the request and
        focus.
      - Escape closes the menu; an answer that lands while it is closed
        is there on reopening.
  - **`godot-candidate-live`**, through the real bridge, in a real Zone,
    with the world paused (`H-INVENTORY_candidate_live_next.log`, all 9
    phases green). "EQUIP ON RMB" on the Equipment wall was PENDING at
    the press. The bridge answered (echo_a: none → `act_l89100025`) and
    the request read ACCEPTED from that snapshot, the world still
    paused. The loadout was put back as a declared harness step.
    - **The first live run failed this check, on the check's own race.**
      A local bridge answers inside one frame. Read one frame after the
      press, the request had already been answered
      (`H-INVENTORY_candidate_live_first.log`). It is now read at the
      press, before the client's next poll can answer it. The re-run is
      green.
  - Also green (`H-INVENTORY_suites.log`):
    - `godot-hud`, `godot-boot`, `godot-archive`;
    - `godot-consumable` (87 checks), `godot-menu-shell` (23),
      `godot-consumable-restart`;
    - `godot-test`, `godot-lab`, `godot-stats`, `godot-legible`,
      `godot-reload` and `godot-integration`;
    - `test_equipment_fixture.py` (3) and `test_ci_coverage.py`.
- **Screenshots** (`H-INVENTORY_shots/`, under xvfb, opengl3), each at
  1280×720 and 1920×1080: the comparison, the history, and the
  consumable key filtered. Plus the exhausted key and the offline wall
  at 1280×720. Looking at them found two legibility
  defects, both repaired:
  - **The comparison was noisy.** It listed every field only one kind
    of attack has ("Pellets: — → 1", "Spread: — → 0°", "Flight time:
    1.5 s → —"). One-sided fields now appear only if they decide
    something: damage, range, radius, amount, duration, cooldown, uses.
  - **Units wrapped away from their numbers** ("after 1.5" on one line,
    "s" on the next). The wall now draws a no-break space there.
  - EI-23 and EI-24 re-break each one.
- **Declared harness steps:**
  - `assume_sent` stands the link up or down;
  - refusals arrive as `error` frames carrying the key the bridge does
    not attach yet (N-11);
  - one NOT SENT comes from a stub sender;
  - the controller case focuses EQUIP directly before pressing A. Tab is
    the shell's own key, so there is no focus-next to walk there with;
  - between cases, outstanding requests are cleared. A request is real
    state that survives a close.
- **The archive's tests, moved with the thing they are about:**

| Was (on `InventoryLayer`) | Now (on the item face, real snapshots) |
|---|---|
| hud `_archive_provenance`: the chain, the reads | face `_history_and_reads`: the chain in order, once; both reads |
| hud `_archive_provenance`: "Upgrades res_magic (+40 max_value)" | hud `_the_upgrade_line`, on `EffectSummary` directly (the reveal reads it) |
| hud `_the_split_on_the_real_panel`: mixed and upgrade-only Echoes, the key filter | face `_the_split_and_the_filter` and `_one_item_one_tile` |
| hud `_the_search_box_keeps_its_place` | face `_the_search_box_keeps_its_place`, on the real shell's page viewport |
| consumable `_the_menu_shows_an_exhausted_supply_and_what_refills_it` | face `_the_consumable_key` (0 / 3 on the key, what refills it) and `_an_empty_spare_is_not_offered` |
| boot: the archive opens in the middle | face `_three_regions`: inside the page, under the title, on the wall's own viewport |

- **Sabotages** (`H-INVENTORY_sabotages.log`), each restored byte for
  byte (sha256), each against the case that should catch it:

| # | Rule removed | Caught by |
|---|---|---|
| EI-1 | an equip is resolved by ANY snapshot (optimistic) | `_pending_then_accepted`: "an unrelated snapshot answers nothing" |
| EI-2 | a refusal resolves the first request, whatever it names | `_refusals_and_a_lost_link`: "a refusal naming another request resolves nothing" (+1) |
| EI-3 | an error with no `about` counts as a refusal | `_refusals_and_a_lost_link`: 4 failures, from "a refusal naming another request resolves nothing" |
| EI-4 | the key paints the pending pick as held (optimistic) | `_pending_then_accepted`: "the key still shows what the bridge confirmed: 'Arc Bolt'" |
| EI-5 | an upgrade becomes an item of its own (a tile per history link) | `_one_item_one_tile`: "one tile per inventory item, 11 of 9" (act_lash and res_magic twice) |
| EI-6 | a key filter keeps the always-on half | `_the_split_and_the_filter`: "the RMB key shows what goes on it" lists the three always-on items (+3). **Not caught on the first run**; see below |
| EI-7 | owning no consumable reads as owning one off the key | `_the_consumable_key`: "none owned says so" (it read "You own 0 consumables: pick one") |
| EI-8 | the consumable key ignores the link | `_the_consumable_key`: "disconnected says so, count kept" |
| EI-9 | the consumable key ignores a use awaiting the bridge | `_the_consumable_key`: "a use awaiting the bridge says so" (a bare "1 / 3") |
| EI-10 | a campaign met for the first time is all NEW | `_a_new_item_is_marked`: 5 failures, from "marks nothing new" |
| EI-11 | inspecting an item does not clear NEW | `_a_new_item_is_marked`: "inspecting it is noticing it: the marker goes" |
| EI-12 | a repaint takes focus from the search box | `_the_search_box_keeps_its_place`: "a snapshot mid-search keeps focus, caret 2 and text 'lash'" (+1) |
| EI-13 | the shell forgets a text field has the keys | `_typing_is_not_playing`: "the letters go into the box ('')" |
| EI-14 | the pad's A is not `ui_accept` (Godot's default map; EI-F1) | `_keyboard_and_controller`: "A chooses: act_bolt", "A on EQUIP sends it: []" |
| EI-15 | the equip controls scroll with the detail (the first layout; EI-F2) | `_the_mouse`: "a click on REPLACE sends it: []" |
| EI-16 | a spent spare is offered | `_an_empty_spare_is_not_offered`: "a spent spare is not offered, and says a Zone refills it" |
| EI-17 | a second press is offered while the first waits | `_pending_then_accepted`: "a second press is not offered while it waits" |
| EI-18 | the comparison runs this → now | `_pending_then_accepted`: "the comparison is against what is on the key, now → this" |
| EI-19 | history drops the upgrades | `_history_and_reads`: "the whole chain, in order, once" (the Mk I line alone) |
| EI-20 | arriving at the wall, nothing takes focus | `_keyboard_and_controller`: "an arrow key moves focus to another control on the wall: nothing" (+1) |
| EI-21 | a link lost mid-request stays pending | `_refusals_and_a_lost_link`: "a link lost mid-request is LOST, not pending forever" |
| EI-22 | the fixture hand-edited (Cinder Charge 3 left, not 2) | `test_equipment_fixture.py::test_the_committed_fixture_matches_its_generator` |
| EI-23 | a field only one side has is listed as a difference again | `_pending_then_accepted`: "a field only one kind of attack has is not listed as a difference" |
| EI-24 | units may wrap away from their numbers again | `_the_detail_answers`: "a number keeps its unit on its line" |

- **The sabotage runs:**
  - **The first run: 21 of 22** (`H-INVENTORY_sabotages_first.log`).
    **EI-6 passed.** The rule "a key filter hides the always-on half"
    lived twice: in `EquipmentQuery.grid` and again as a guard in the
    face. Breaking the query's copy was masked by the face's guard.
  - **The fix:** the face now draws what the query returns, and a
    direct check asks the query itself. EI-6 alone was re-run
    (`H-INVENTORY_sabotage_EI-6_rerun.log`): caught, 4 failures.
  - **The final run, on the final code: 24 of 24.** EI-23 and EI-24
    were added with the two legibility repairs above.

- **What stays open:**
  - **The Glyph-authored final look.** The icons, fonts and panels are
    placeholders. They do not satisfy §9 or CP3's "one Glyph equipment
    face", which waits on Arty's H-GLYPH-KIT.
  - **N-11:** a refused `slot_action` has no `about` from the bridge.
    Until it does, a refusal shows as the bridge's, unattributed, and
    the request waits until the link drops or the player picks again.
    The wall only offers the keys the view says an item fits, so a
    refusal needs a race, such as an item merged away between the
    snapshot and the press.
  - **Drag and drop is not offered.** §5 allows it but does not require
    it. Without it, there is no drag to dangle across a turn or a close.
  - `ArchiveQuery`'s Echo-level split and sort are now used by no
    screen. `matches` is still used, by the item search. The rest stays
    tested (`godot-archive`) until it is retired on purpose.
  - A new item is marked on the wall only. The HUD's pickup
    announcement is unchanged.
  - Owner usability and visual approval is a separate result.
- **What the owner will notice:**
  - Tab opens Equipment as three columns:
    - your five keys on the left;
    - everything you own as tiles in the middle;
    - the one you picked on the right, with what it does and how it
      compares with what is on its key now.
  - An upgrade is part of the item it upgraded, not a second copy of it.
  - Pressing EQUIP shows "waiting for the bridge" on the key until the
    game confirms it. If the game refuses, the key says why.
  - The Q key says which state it is in: none owned, one to pick, empty
    until a Zone refills it, waiting, or offline.
  - A new item is marked NEW until you look at it.
  - A controller works on every wall now: the d-pad moves, A presses,
    Start closes and Back opens Equipment.

## CP3 checkpoint — closed (the full frontier)

- **On `33af28d` (H-INVENTORY's head):** 76 of 77 steps passed, 09:35
  to 10:59 UTC (`CP3_frontier_on_33af28d.tsv`).
  - The steps are CP2's 74 and this checkpoint's three:
    - the two suites CP3 added to CI, `godot-menu-shell` and
      `godot-equipment-face`;
    - `equipment_snapshot.json` regenerated from source: byte-identical,
      and restored.
  - **The one failure was `make test`,** 2 of 2,224
    (`CP3_make_test_on_33af28d.log`). Both were real findings, and this
    lane's own:
    - **`test_every_bundled_binary_is_first_party_or_licensed`:** the
      evidence screenshots were tracked binaries with no licence record.
      They were H-3D-SHELL's (since `f7876d0`) and H-INVENTORY's. No
      step between checkpoints runs `make test`, so the first commit to
      add one went unnoticed until this run.
    - **`test_no_consumer_reads_the_raw_field_behind_the_accessor`:**
      `equipment_query.gd` read the Echo log off the snapshot. The log
      can be elided on the wire, and only
      `BridgeClient.interpretations()` puts it back.
  - **Fixed at `5f44b5c`:**
    - The evidence folder is listed as first-party in
      `assets/LICENSES.json`, as `docs/evidence/` already is. Its images
      are renders of this game, made by its own make targets.
    - The query takes the log from the accessor.
  - **Verified on `5f44b5c`**, for the code the fix touched:
    - `make test`: 2,224 passed (`CP3_make_test_on_5f44b5c.log`);
    - `godot-equipment-face`: 107 checks
      (`CP3_equipment_face_on_5f44b5c.log`);
    - `godot-candidate-live`: all 9 phases, with the paused equip PENDING
      then ACCEPTED (`CP3_candidate_live_on_5f44b5c.log`).
  - The tree at the end differed only in the placement fixtures
    `godot-zone-audit` rewrites. They were restored.
- **CP3 is closed, on provisional art.** The packet's CP3 names "one
  Glyph equipment face". The face is built and working, but its art is a
  placeholder; the Glyph-authored look waits on Arty's H-GLYPH-KIT and is
  not claimed. As at CP1 and CP2, the frontier was not re-run in full for
  a fix this size. These are local results; remote CI was not polled.

## CP4 — `H-MINIMAP` (V-20, `04` §6–§7): the map that stays on screen — landed, on provisional art

§7 asks for a map that stays on screen while you explore and fight. It
shows where you are and which way you face, the connectors near you as
they actually run, useful known markers, and a floor convention that
can't be misread. §6 sets the rules it shares with the 3D map:

- shape comes from the built level, never from the overview graph;
- state comes from the authority, and a colour is never a permission;
- nothing undiscovered is drawn;
- a blocker carries its circuit's colour and a symbol for its reason.

The state is Dess's `CampaignSnapshot.zone_map` (H-MAP-DATA). The room
name follows M-3.

- **Reproduced first**, on `5f44b5c`, with a scratch driver
  (`H-MINIMAP_repro_driver.gd.txt`; evidence, not a suite). **2 of 2
  requirements fail** (`H-MINIMAP_before.log`):
  - **M1:** in a Zone, Main's HUD has 129 controls and none of them is
    a map. The only map in the game is the F5 review schematic
    (`NavSchematic`), which is off by default.
  - **M2:** the player walked c002, c003 and c004 (4 rooms entered,
    counting the arrival), and `room_entered` was sent for none of
    them. The bridge's map could not learn a room by walking it (Dess's
    D-2).
  - **The control, on the new code: 0 of 2 fail**
    (`H-MINIMAP_control.log`). The HUD has a `Minimap` among 132
    controls, and `room_entered` went for c002, c003 and c004. M1's
    message ends with the same fixed sentence about the F5 schematic in
    both runs. In the control it is stale text, not a measurement.
- **What changed:**
  - **`Minimap`** (new, `godot/scripts/ui/minimap.gd`) sits at the
    bottom right of the HUD in a Zone and is hidden in the Hub. It is
    236 px square, north-up and centred on the player, at 3.2 px a metre
    (about 74 m across). Above it is the name of the room you are in. It
    draws:
    - each room you have found as its built envelope, with your own room
      brighter;
    - rooms a floor above or below as outlines, with a small triangle
      pointing up or down;
    - each connector the bridge lists, along its built path: socket,
      each piece's entry and exit, socket;
    - each blocked connector in its circuit's colour, with a diamond
      halfway along it carrying the reason: K key, P power or setting,
      M mechanism, E an Echo to equip, and `?` when the state is
      unknown;
    - each return plug the bridge lists as a ring where the device
      stands;
    - you, as an arrow pointing the way you face.
  - **`MinimapModel`** (new) holds the rules, with no Control: which
    rooms and connectors, each path and its midpoint, the reason letter,
    the circuit colours and the floors.
  - **`ZoneController`:**
    - keeps the builder's joins (`room_joins`), as it already keeps
      `room_routes`, and each plug's position (`plug_positions`);
    - sends `room_entered` the first time the player stands in a room in
      a session (D-2);
    - on every snapshot, sends it again for any room this session walked
      that the bridge's map doesn't show as discovered
      (`resend_undiscovered`). The record is monotone and the bridge
      answers a repeat with nothing, so a send lost to a dropped link
      heals on the next snapshot, and the resending stops by itself. It
      only ever names rooms the Zone declares: the builder's exit room
      is not a chamber, so the bridge's refusal of an undeclared room
      can't turn into a resend on every snapshot.
  - **`BridgeClient.zone_map()`**, and **`Main`** binds the minimap to
    each Zone and unbinds it in the Hub.
  - **Dess's notes:** this answers D-2 (send `room_entered`) and the
    minimap's part of D-3 (read `zone_map`). The 3D map and the journal
    read it next.
  - **The fixture is real:** `make map-fixture` writes
    `godot/tests/fixtures/map_snapshot.json`. It holds Dess's
    `map_view` of the candidate Zone after real transitions
    (`record_room_entered`, `record_key`, `record_object_transported`,
    `record_object_consumed`, `record_zone_state`), in seven variants.
    `bridge/tests/test_map_fixture.py` keeps the JSON equal to its
    generator and checks that each variant holds the state it is named
    for.
  - **The candidate phases now fail on a runtime error.** Each phase
    of `godot-candidate-live` now fails on "SCRIPT ERROR" or "String
    formatting error" in its Godot log, as every other Godot suite
    already did. See the first live run below.
- **Findings while building it, all repaired before this commit:**
  - **MM-F1: a pit read as a storey.** The first draft took a room's
    floor from its envelope's bottom, so a room with a pit sat 70.6 m
    below the rest. A room's floor is now its arrival height
    (`room_places`), where a body stands. MM-10 re-breaks it.
  - **MM-F2: two circuits, one colour.** The first draft coloured a
    circuit by a hash of its id. In the candidate Zone the span's
    circuit and the power circuit came out the same colour, which §6
    forbids ("two unrelated circuits in one place need distinct
    identity"). Colours are now dealt:
    - a key circuit keeps its key's colour;
    - every other circuit takes the next colour from a palette that
      contains no key colour, in the Zone's declaration order.

    So the power circuit can't read as the green key's door, and a
    colour never changes as more of the map is found. MM-8 re-breaks it.
  - **MM-F3: the floor marks would have been blanks.** The first draft
    typed ▲ and ▼, and Godot's default font has neither (nor ◆ or ↩;
    checked with `Font.has_char`). §9: "unsupported characters must
    have a visible fallback rather than blanks". The marks are now
    drawn triangles. The suite asks what the plate actually drew: every
    character it typed must be in the font it typed it in. MM-12
    re-breaks it.
  - **MM-F4: the return plugs were listed but not drawn.** The model's
    comment said a plug "is drawn as a marker", but the plate skipped
    anything without a path, and the suite's "every connector drawn"
    counted the model's list, not the plate. A plug is now a ring where
    its device stands, and the suite counts the rings drawn. The bridge
    lists a plug only once its own room is found: with five rooms found,
    none of the Zone's eight is drawn. MM-13 and MM-14 re-break it.
  - **MM-F5: the evidence images lied about colour.** The screenshots
    were first palette-reduced whole. That merged the red key's blocker
    and the route shutter's magenta one into a single pink, and in
    places turned the magenta blocker and the yellow player arrow cyan
    (29 merged pixels in the c009 frame). The renders were right; the
    copies were not. The evidence is now made by
    `H-MINIMAP_shots_evidence.py.txt`:
    - the full frames are reduced to 256 colours without dithering;
    - the crops of the map are lossless;
    - every output is checked against its raw render, and fails if two
      clearly different colours come out as one.
  - **Two of the suite's own checks were wrong at first:**
    - The turning-connector check first assumed a turning corridor is
      at least 1.2× as long as the line between its ends. That doesn't
      hold in this Zone. It now measures how far the drawn path strays
      from that line.
    - The repro's first M1 looked for the HUD before `Main.boot()` had
      built it, so it would have failed on any code. It now boots Main
      first; the before and control runs above are the fixed driver.
- **Played:**
  - **`godot-minimap`** (new, 30 checks; `H-MINIMAP_after.log`)
    runs on the candidate Zone, built for real by `ZoneController`. Each
    of the fixture's maps is put in the client's snapshot as the
    bridge's `zone_map`:
    - **The shapes are the built level.** Every room is drawn as its
      built envelope (25 of 25). The connector that turns most,
      e:c004:c005, strays 4.6 m from the line between its ends. It is
      drawn through 11 points, each the built chain's, in order.
    - **Entering a room reports it:**
      - c002 is on the map the moment the player stands in it;
      - `room_entered` goes once, and walking back in doesn't send it
        again;
      - a snapshot whose map lacks c002 resends it, and once the map
        shows it, nothing is resent.
    - **The room is named by the bridge** ("Arena 1" for c002), never
      by the save's id (M-3).
    - **Nothing undiscovered is drawn:** only rooms found or walked,
      and only connectors the bridge lists.
    - **The green circuit:**
      - carrying the cell, the power door is a P blocker in
        `state:cell_power`, marked on the connector through the door;
      - its colour is one no other circuit in the Zone shares: not the
        green key's, not the span's;
      - installed, the bridge's map opens it and the map follows;
      - five declared circuits get the palette's five colours, in
        order.
    - **A reversible closure comes back:** the span reads open lowered
      and blocked when put back.
    - **You are the centre,** north-up, at 3.2 px a metre.
    - **Floors:**
      - c001, c009 and c021 sit at their arrival heights (c009 at
        31.6 m);
      - a 1 m step is the same floor, and 3 m up or down is another;
      - from c001, 14 rooms are on other floors, and exactly that
        many triangles are drawn.
    - **Every character on the map is in its font.**
    - **The ways back:** each of the 8 plugs the bridge lists is a
      ring at its device, and none is drawn before it is listed.
  - **`godot-candidate-live`**, through the real bridge in a real Zone
    (`H-MINIMAP_candidate_live.log`, all 9 phases green):
    - carrying the cell, the bridge's map has e:c005:c006 blocked ("set
      by a control in Arena 2"), and the minimap draws a P blocker
      there;
    - installed, the bridge's map opens it and the minimap follows;
    - every room walked is discovered in the bridge's map: c001 to
      c006. This is D-2 end to end;
    - after the restart, the bridge's map still has c005 and c006
      discovered, and the minimap draws them;
    - after the restart, the power door is still open on the bridge's
      map and on the minimap. §6: "an accepted permanent opening
      survives re-entry".
    - **The first live run was green, but printed its restore message
      unformatted** ("%s", "%d"; `H-MINIMAP_candidate_live_first.log`).
      This was my format-string bug in the new check. Godot logged it
      twice as "String formatting error"
      (`H-MINIMAP_candidate_live_first_restore_godot.log`), and no
      candidate phase gated on that. The message is fixed, and the
      phases now gate on it. Applied to that first restore log, the new
      gate's condition fails it.
    - **After the live run,** one null guard went into
      `Main._clear_world` (the minimap is unbound only if `boot()` built
      it). `godot-boot`, `godot-hud` and `godot-minimap` were re-run on
      it, green.
  - **The suites that assert exact intents are still green.**
    `room_entered` is a new intent sent from ordinary walking. Four
    suites assert exact or empty intent lists: rail junction, affordance,
    activity and lab. They ran with 17 other Zone-heavy suites, one at a
    time, and all 21 pass (`H-MINIMAP_suites.log`; raw logs in
    `H-MINIMAP_suites_raw.log.gz`).
    - `room_entered` and its resend were in place for all 21.
    - MM-F3 and MM-F4 landed while the batch ran. The first 10 suites
      ran before those repairs, latched route straddled them, and
      transport onward ran the final code. The repairs touch no intent,
      and the CP4 frontier re-runs every suite on one frozen revision.
- **Screenshots** (`H-MINIMAP_shots/`, under xvfb with opengl3, at
  1280×720, each with a lossless 2× crop of the map):
  - the span blocked in c002;
  - the power door blocked (carrying) and open (installed) in c005;
  - every room found, seen from c009.
- **Sabotages** (`H-MINIMAP_sabotages.log`), each restored byte for
  byte (sha256):

| # | Rule removed | Caught by |
|---|---|---|
| MM-1 | a connector is drawn socket to socket (a straight line) | `_the_shapes_are_the_built_level`: "turns: its drawn path strays 0.0 m ... through 0 points" |
| MM-2 | every built room is drawn, found or not | `_nothing_undiscovered_is_drawn`: "26 of 26 rooms drawn ... none beyond: [c006 ... exit]" (+1) |
| MM-3 | every built join is drawn, listed by the bridge or not | `_nothing_undiscovered_is_drawn`: "every connector drawn is one the bridge lists (7)" |
| MM-4 | entering a room reports nothing (the old behaviour) | `_entering_a_room_reports_it`: "`room_entered` for c002 went once: []" (+2) |
| MM-5 | a lost report is never resent | `_entering_a_room_reports_it`: "a snapshot whose map lacks it resends it: []" |
| MM-6 | reports are resent whatever the bridge's map says | `_entering_a_room_reports_it`: "once the bridge's map shows it, nothing is resent: [c001, c002]" |
| MM-7 | the room is named by its save id | `_names_come_from_the_bridge`: "the label reads the bridge's name for c002: 'c002'" (+1) |
| MM-8 | a circuit's colour is a hash of its id (the first draft; MM-F2) | `_the_green_circuit`: "five circuits get the palette's five colours, in declared order". **Not caught on the first run**; see below |
| MM-9 | the map decides a gate itself (everything open) | `_the_green_circuit`: "carrying the cell: the door is a P blocker ...: open" (+2) |
| MM-10 | a room's floor is its envelope's bottom (the first draft; MM-F1) | `_floors`: 3 failures, from "c001's floor is its arrival height" |
| MM-11 | the fixture hand-edited (the power door open while carried) | `test_map_fixture.py::test_the_committed_fixture_matches_its_generator` |
| MM-12 | the floor marks typed as the font's ▲ and ▼ (the first draft; MM-F3) | `_what_the_plate_draws`: "every character on the map is in the font ...; missing: ▲" (14 of them) |
| MM-13 | a way back is never marked (MM-F4) | `_the_ways_back`: "8 listed, 0 placed, 0 drawn" |
| MM-14 | every plug the build has is marked, listed by the bridge or not | `_the_ways_back`: "none is drawn before the bridge lists it: 8 of the Zone's 8" (+1) |

- **The sabotage runs:**
  - **The first run: 10 of 11** (`H-MINIMAP_sabotages_first.log`).
    **MM-8 passed.** A hash of the id happened to give this Zone's
    three non-key circuits three different colours, so the check that
    they differ held by luck. A check now deals five declared circuits
    and asks for the palette's five colours in declared order. MM-8
    alone was re-run (`H-MINIMAP_sabotage_MM-8_rerun.log`) and was
    caught.
  - **The second run: 11 of 11** (`H-MINIMAP_sabotages_second.log`).
  - **The final run, on the final code: 14 of 14**, with MM-12 to MM-14
    added for MM-F3 and MM-F4.
- **What stays open:**
  - **The Glyph-authored final look.** The plate, the shapes and the
    font are placeholders (H-GLYPH-KIT), and the circuit colours are
    provisional until Arty's circuit family (H-CIRCUITS).
  - **A room name the font can't draw.** The suite checks the names
    this Zone shows. An authored name with a character Godot's default
    font lacks would still come out blank until Glyph's font family
    carries a fallback.
  - **D-3's live "transitioning" overlay is not drawn.** A passage in
    motion shows the bridge's record. That record is conservative in the
    direction §6 cares about: closing a reversible passage records it
    blocked at once, so "a jammed, closing or unknown passage is not
    silently labelled open" holds, and unknown reads `?`. An opening
    passage reads open for the second or so it is still moving. The
    overlay would read each connector's shutter, which is more than this
    item needed.
  - **Details wait for the 3D map.** The minimap shows the reason as a
    letter; the reason's words ("set by a control in Arena 2") are for
    the map wall (§7: "full names/details can appear on focus or the
    large map").
  - **The earlier evidence folders** (H-3D-SHELL, H-INVENTORY) were
    reduced the same way as MM-F5. They show layout and text rather
    than circuit colours, and were not re-checked.
  - Owner usability and visual approval is a separate result.
- **What the owner will notice:**
  - A map in the bottom-right corner in every Zone, with the room
    you're in named above it.
  - Rooms look like the rooms, and a corridor that turns is drawn
    turning.
  - Only what you have found is on it.
  - A blocked door is a coloured diamond on its corridor, with a letter
    saying why: K a key, P power, M a mechanism. The power door stays
    blocked while you carry the cell and opens on the map when the cell
    is installed.
  - Rooms on other floors are outlines with a little up or down
    triangle.
  - A ring marks a way back.

## CP4 — `H-3D-MAP` (V-21, `04` §6–§7): the Map wall, a miniature you can turn — landed, on provisional art

§7 asks the Map wall for a miniature you can rotate, zoom and pan. It
must offer cutaway roofs or one floor at a time so stacked rooms stay
readable, recentre on you, and tell your floor from the others. It must
keep what you were inspecting through page changes, and its controls
must not compete with the page-turn arrows. It must be **render-only**:
"never duplicate live scripts, collision, enemies, reward nodes, sounds
or state setters". Opening it must not send a Check, and it must be
cached and measured on a representative built Zone. §6's green circuit
has the 3D map draw "a small pulsing green indicator" on the passage.
§10 asks that a real named blocked door match both maps and change when
its circuit operates.

- **Reproduced first**, on `8a4d5ed` (H-MINIMAP's head), with a scratch
  driver on the real `Main` (`H-3D-MAP_repro_driver.gd.txt`; evidence,
  not a suite). **4 of 4 requirements fail** (`H-3D-MAP_before.log`):
  - **R1:** the map wall has no 3D view and no mesh. It says "The map is
    not built yet (H-3D-MAP). This wall holds its place."
  - **R2:** after Right, =, W and PgUp, nothing on the map page changes.
  - **R3:** carrying the cell (the bridge's map has the power door
    blocked), the wall has no blocker indicator.
  - **R4:** none of the 5 rooms found is named on the wall.
  - **The control, on the new code: 0 of 4 fail**
    (`H-3D-MAP_control.log`): one 3D view, the power door among 3
    indicators, and all 5 places named.
- **What changed:**
  - **`MapFace`** (new, `godot/scripts/ui/map_face.gd`) is the Map
    wall's content. `Main` mounts it on the shell's map page, as it
    mounts the Equipment wall, and binds it to each Zone. It has two
    parts.
  - **The miniature** is a `SubViewport` with its own `World3D`:
    - each room found is its built envelope, cut away: a floor and a
      2.4 m wall, never a roof;
    - each connector is a beam along its built chain, in 3D;
    - each blocked or unknown connector has a pulsing sphere in its
      circuit's colour, with the reason's letter over it;
    - each way back is a ring where its device stands;
    - you are a yellow cone pointing the way you face, drawn over
      everything;
    - the room you are in, and a place you pick, carry their names.
  - **The column beside it** says where you are and which floors are
    shown. It lists the places you know; picking one centres the view on
    it and lists each way on with its state and the bridge's reason. It
    counts the ways back and lists the controls.
  - **One projection, two views.** The wall asks `MinimapModel` exactly
    what the minimap asks (rooms, connectors, circuit colours, floors),
    of the same sources. It decides no gate, name or colour.
  - **Render-only:** meshes and labels only, no scripts, in a world of
    their own. Building it sends nothing, and the Zone is not touched.
  - **Cached:** it builds when first shown, and then only when what it
    shows has changed. On the candidate Zone with every room found (25
    rooms, 32 connectors), a build takes 7.6 ms headless. That time is
    the scene building; uploading to a GPU is not in it.
  - **Controls that leave the page turns alone.** The shell takes Q, E,
    the shoulders, Tab and Escape before the wall sees them. The map
    takes:
    - drag, the arrows or the right stick to turn and tilt;
    - the wheel, + and -, or the triggers to zoom;
    - right-drag, WASD or the left stick to pan;
    - C, Home or pad Y to recentre on you;
    - PgUp and PgDn, or the d-pad's up and down, for one floor at a
      time (your own first, then up or down, then every floor again);
    - [ and ], or the d-pad's left and right, for the next place you
      know.
  - **Floors:** with every floor shown, yours is solid and the others
    are ghosts.
  - **What you were looking at stays:** the view, the floor and the
    picked place survive page turns and closes. Only another Zone resets
    them. In the Hub the wall says there is no map there.
  - **`MenuShell`:** the Map wall no longer carries its "not built yet"
    note; the Journal's stays.
  - **`BridgeClient.sent_total`** counts every intent sent. The live
    suite uses it to see what went while the map was open, because
    `sent_intents` is capped.
- **Findings from the first runs and renders, all repaired:**
  - **MF-F1: a node named by its edge id could not be found.** Godot
    rewrites the `:` in `Blocker_e:c005:c006`, so a lookup by that name
    returned nothing. The pulse check read nothing, and the repro's R3
    probe would have been blind on the new code. Each node now carries
    its edge id as metadata. The repro reads that, and its before run
    was repeated with the fixed probe.
  - **MF-F2: the column ran under the shell's ">" arrow.** One label
    did not wrap, so the column grew to its longest line. Every label
    now wraps at the column's width, and the column stops short of the
    arrow.
  - **MF-F3: the column had no height limit.** A long detail or a long
    list of ways back would push it off the page. The detail scrolls in
    a fixed height, and the ways back are a count; each place's own
    detail names its way back.
  - **MF-F4: you were hard to find.** Your marker was small, pale and
    under the room's name. It is larger, brighter and drawn over
    everything, and the name stands higher.
  - **MF-F5: the Hub rule lived twice.** Both `bind()` and `refresh()`
    cleared the miniature, so a sabotage of either would be masked by
    the other (as EI-6 was). It now lives in `refresh()` alone, and
    MF-16 re-breaks it.
- **Played:**
  - **`godot-map-face`** (new, in CI, 52 checks; `H-3D-MAP_after.log`)
    runs on the real `MenuShell` and the candidate Zone built for real.
    Keys, pad and pointer go in as device events, through the shell:
    - **The wall is filled:** the map, and no "not built yet" note.
    - **The shapes are the built level:** 25 of 25 rooms stand on their
      built envelopes at their arrival heights, and none has a roof.
      e:c004:c005 is built point for point along its chain.
    - **One projection:** in four variants, both maps show the same
      rooms, the same names, and the same blockers in the same colours
      with the same letters.
    - **Render-only:** 98 nodes (1 `Node3D`, 65 `MeshInstance3D`, 32
      `Label3D`), none with a script. A real build inside the check
      sent nothing, and the Zone's 5,382 nodes are untouched.
    - **The cache:** the same map is not built again, and a changed map
      is built once. Nothing is built while the menu is closed; the
      build happens on opening.
    - **The green circuit:** carrying the cell, a P indicator in the
      power circuit's colour stands on the connector through the door,
      and it pulses (8 sizes in 0.9 s). Once the cell is installed, it
      is gone.
    - **The span:** no indicator while lowered, and a P again once put
      back.
    - **Floors:** 4 floors are known.
      - Standing on floor 1, your 11 rooms are solid and the 14 others
        are ghosts.
      - PgUp shows your floor alone, then the one above, and past the
        top every floor again.
    - **The keys:**
      - Right, Up, = and - turn, tilt and zoom, and zoom stops at 260 m;
      - W and D pan, and C comes back to you;
      - none of the 16 map keys turns the page, and Q still does.
    - **The pad:**
      - the d-pad shows one floor and picks a place;
      - the right stick turns the map while held and stops when let go;
      - Y comes back to you;
      - a stick still held when the page turns away turns nothing.
    - **The pointer, through the 3D stage:** a drag turns the map, a
      right-drag pans it, the wheel zooms, and a click picks a place.
    - **What you were looking at stays:** the view, the floor and the
      place survive a turn to the journal and back, and a close and
      reopen.
    - **Places:**
      - the list is exactly the rooms found or walked;
      - picking Arena 1 names it and each way on, with the bridge's
        reasons, and shows no save id;
      - all 8 ways back are rings.
    - **The Hub:** the wall says there is no map there, and draws
      nothing.
  - **`godot-candidate-live`**, through the real bridge in a real Zone
    (`H-3D-MAP_candidate_live.log`, all 9 phases). The map wall is
    opened as a player opens it: Escape, then Q twice, with the world
    paused.
    - **Carrying the cell:** the power door is a P indicator on the wall,
      in the colour the minimap uses, and nothing was sent but the
      Zone's own `room_entered` resends.
    - **Installed:** the indicator is gone. The circuit operated, and
      both maps changed (§10).
    - **After the restart:** no indicator on it.
  - **Also green** on this code: `godot-menu-shell`, `godot-boot`,
    `godot-hud`, `godot-equipment-face` and `godot-minimap`
    (`H-3D-MAP_suites.log`).
- **Screenshots** (`H-3D-MAP_shots/`, under xvfb with opengl3, at
  1280×720, the wall on the real shell):
  - every floor, from c009;
  - your floor alone, from c001;
  - the power door blocked, then open, from c005, with Arena 2 picked.
  - Looking at them found MF-F2, MF-F3 and MF-F4 above.
- **Sabotages** (`H-3D-MAP_sabotages.log`), each restored byte for byte
  (sha256):

| # | Rule removed | Caught by |
|---|---|---|
| MF-1 | a room gets a roof (no cutaway) | `_the_shapes_are_the_built_level`: "and none has a roof" |
| MF-2 | a connector built end to end (a straight line) | `_the_shapes_are_the_built_level`: "e:c004:c005 is built along its chain, point for point" |
| MF-3 | the wall colours circuits itself (a hash of the id) | `_one_projection_two_views`: "the same blockers in the same colours", in all 4 variants |
| MF-4 | every connector gets an indicator, open or not | `_one_projection_two_views` ("the same 32 blockers") and `_the_green_circuit`: "installed: ... the indicator is gone" (7 in all) |
| MF-5 | every built room is shown, found or not | `_one_projection_two_views` ("the same 26 rooms") and `_places_and_ways_back`: "nothing beyond them" (5 in all) |
| MF-6 | the miniature carries collision (a body per room) | `_render_only`: "148 nodes of ... StaticBody3D: 25, CollisionShape3D: 25 ... nothing else: [StaticBody3D, CollisionShape3D]" |
| MF-7 | no cache: the same map is built again | `_the_cache`: "the same map asked for again is not built again" (+1) |
| MF-8 | the wall builds while the menu is closed | `_the_cache`: "and nothing is built while the menu is closed" |
| MF-9 | the indicator does not pulse | `_the_green_circuit`: "and it pulses" |
| MF-10 | the arrow keys do not turn the map | `_keys_turn_the_map_not_the_page`: "Right turns the map" |
| MF-11 | one floor at a time shows every floor | `_floors_and_cutaway`: "PgUp shows your floor alone" |
| MF-12 | every floor is solid (no ghosts) | `_floors_and_cutaway`: "yours solid (25 rooms), the others ghosts (0)" (+1) |
| MF-13 | a stick held across a page turn keeps turning the map | `_the_pad`: "a stick still held when the page turned away turns nothing" (+2, among them the journal-and-back view) |
| MF-14 | the view resets whenever the wall is not shown | `_what_you_were_looking_at_stays`: "and so do a close and a reopen" |
| MF-15 | a way on to an unfound room is named by its save id | `_places_and_ways_back`: "and no save id" |
| MF-16 | the Hub keeps the last Zone's miniature (MF-F5's one home) | `_the_hub`: "... and draws nothing" |
| MF-17 | building the wall sends a state-setting intent | `_render_only`: "opening it and building it (1 build) sent nothing: [station_reached]". **Not caught on the first run**; see below |

- **The sabotage runs:**
  - **The first run: 16 of 17** (`H-3D-MAP_sabotages_first.log`).
    **MF-17 passed.** The "opening it and building it sent nothing"
    check came right after a case that had built the same map. The
    cache answered, nothing was built inside the check, and a map that
    sent an intent on every build passed it.
  - **The fix:** the case now builds another map first, so the build
    it measures is real, and it asserts that a build happened inside
    the window. MF-17 alone was re-run
    (`H-3D-MAP_sabotage_MF-17_rerun.log`) and was caught.
  - **The final run, on the final code: 17 of 17**
    (`H-3D-MAP_sabotages.log`).
- **What stays open:**
  - **The Glyph-authored final look.** The miniature's materials, the
    column's fonts and the markers are placeholders (H-GLYPH-KIT), and
    the circuit colours are provisional (H-CIRCUITS).
  - **D-3's live "transitioning" overlay** is not drawn here either;
    see H-MINIMAP.
  - **Measured headless.** Building the scene is timed; GPU upload and
    frame cost on the owner's machine are not. The miniature is about
    100 nodes and is drawn only while the menu is open.
  - **A place is a room.** Keys, terminals and objectives are not
    listed: the bridge's map carries circuits by room, and naming a
    control's place is the bridge's reason text, shown on a picked
    place.
  - Owner usability and visual approval is a separate result.
- **What the owner will notice:**
  - Escape, then Q twice (or Tab then Q) brings up the map: the Zone as
    a small model you can turn with the mouse, the arrows or a stick.
  - Rooms are open-topped, so you can see into rooms below, and PgUp
    shows one floor at a time.
  - A blocked door is a small pulsing ball in its circuit's colour with
    a letter. The power door's disappears once the cell is in.
  - Pick a place on the right to see its name and each way out,
    including why a blocked one is blocked.
  - The map stays where you left it when you turn away or close the
    menu.

## CP4 — `H-JOURNAL` (`04` §8): the Journal wall, and the campaign and options on Settings — landed, on provisional art

§8: "Journal initially lists real active objectives, completed
consequences, discovered named places and appropriately earned notes.
... the near-term delivery must not invent a finished campaign or spoil
unvisited rewards. A control's recorded discovery can remind the player
which door it affects; it should not reveal an undiscovered solution."
And: "Settings includes resume, current campaign/profile information and
supported options. Separate return to Hub, abandon current Zone, quit,
and new campaign wherever those existing actions are offered.
Destructive actions need their existing confirmation and accurate
consequences. Do not change the all-Checks/abandon policy through a
prettier button label."

- **Reproduced first**, on `c5db77a` (H-3D-MAP's head), with a scratch
  driver on the real `Main` (`H-JOURNAL_repro_driver.gd.txt`). It
  delivered a real snapshot through `BridgeClient._handle` and read the
  walls. **6 of 6 requirements fail** (`H-JOURNAL_before.log`):
  - **J1–J4:** the Journal wall says only "The journal is not built yet
    (H-JOURNAL). This wall holds its place." It shows no objective, no
    record of what was done, none of the 5 places found, and no note.
  - **J5:** the Settings wall shows the pause menu and nothing of the
    campaign: no seed, no count of Checks.
  - **J6:** no option can be changed in the game: 0 sliders and 0
    toggles. `PlayerSettings` (S21) stores six preferences, and nothing
    offers them.
  - **The control, on the new code: 0 of 6 fail**
    (`H-JOURNAL_control.log`).
- **What changed:**
  - **`JournalQuery`** (new) holds every rule, with no Control. Every
    line is read from the snapshot:
    - **Objectives** are the Hub's own headline and detail in the Hub.
      In a Zone they are the Zone and its Checks (its allocated
      locations against the campaign's confirmed ones), then the
      finale's count.
    - **What you did here** is the Zone's record
      (`active_zone.progress`): keys picked up, doors unlocked, objects
      installed, settings changed, latches held. Each line names the
      room it happened in and what it opened ("Open now: Arena 1 to
      Platform Path 1"). A setting back at its declared start is not
      listed.
    - **Still shut** is every gate the bridge's map lists as blocked or
      unknown, with the bridge's own reason ("set by a control in
      Arena 1"; "locked -- blue key; you hold it"). That is the
      reminder §8 allows.
    - **Places found** are the rooms the bridge's map names.
    - **Notes** are each Echo's read, newest first, with where it came
      from. An Echo is in the log only once a Check has delivered it,
      so every note is earned.
    - **Names come only from the bridge's map.** A room it does not
      name is "a way not yet walked", never a save id and never a name
      taken from the whole Zone.
  - **`JournalFace`** (new) is the Journal wall: those five sections in
    two scrolling columns. It refills on every snapshot. Up/Down,
    PgUp/PgDn and the d-pad scroll it, and the page turns stay the
    shell's.
  - **`SettingsFace`** (new) sits on the Settings wall beside the pause
    menu, which is unchanged.
    - **CAMPAIGN** shows the seed, the player, Archipelago's mode and
      connection, Epsilon's provider, the Checks confirmed, the Zones
      completed, and the link.
    - **OPTIONS** offers only what the game applies: mouse sensitivity,
      invert look, field of view (applied to the camera in use at once,
      and to every camera made after), motion (view bob and the menu's
      turn), and master volume. Master volume is now applied to the
      Master bus, at boot and on each change. Each option is written to
      `user://settings.cfg` straight away.
    - **Not offered:** `PlayerSettings` also stores "captions", which
      nothing reads, so a switch for it would change nothing.
  - **The fixture is the model's own:** `make journal-fixture` writes six
    variants. Each is a `CampaignSnapshot` built by the model over a save
    moved by real transitions on the candidate Zone (keys, a lock, the
    span, the cell, the c009 latch). `bridge/tests/test_journal_fixture.py`
    keeps the JSON equal to its generator and each variant true to its
    name.
  - **`MenuShell`:** no wall carries a "not built yet" note now.
- **Findings from the first runs, repaired:**
  - **JR-F1: one check tested nothing.** The first "still shut" check
    used a variant where nothing is shut: the span was lowered, the cell
    installed and the blue door unlocked. It compared zero gates against
    the "nothing shut" line and failed for that reason, not the wall's.
    A `walked` variant (rooms found and keys held, nothing operated) now
    carries three shut gates with the bridge's reasons. The empty case
    is checked on its own.
  - **JR-F2: a rule with no case.** "A setting back at its start is not
    listed" had no variant that put one back. A `stowed` variant (the
    span lowered, then put back) now covers it, and JR-5 re-breaks it.
- **Played:**
  - **`godot-journal-face`** (new, in CI, 36 checks;
    `H-JOURNAL_after.log`) runs on the real `MenuShell`, mounted as
    `Main` mounts it, with the candidate Zone built for real. Each check
    works out what it expects from the snapshot itself, never by asking
    `JournalQuery`:
    - **Objectives:** in the Hub, the Hub's headline and detail word for
      word, and the finale's 8 of 24. In a Zone: its name and "2 of 15
      confirmed", counted from the snapshot, and not the Hub's "step
      back through the portal".
    - **What you did here:**
      - arrived: "Nothing yet.";
      - progressed: six lines for six things done (two keys, the blue
        door in Arena 2, the cell installed in Arena 2, the span and the
        power), each naming what it opened;
      - with the span put back: five lines;
      - latched: the latch in Arena 4; once Arena 3 is found, the power
        line names it.
    - **Nothing unfound is named.** In all four states, no room the map
      has not named appears, by name or by save id.
    - **Still shut:** the three gates the map lists as shut, each with
      the bridge's reason. Once they open: "Nothing you have found is
      shut."
    - **Places:** the five found, by the bridge's names. In the Hub:
      "Places are listed inside a Zone."
    - **Notes:** 10, newest first, each with Epsilon's read word for
      word.
    - **It follows the snapshot:** a new one refills the wall.
    - **Settings:**
      - the campaign from the snapshot (seed, player, "mock, connected",
        fallback, 8 of 21 Checks, 2 Zones, the link down);
      - the pause menu's actions are exactly RESUME, RETURN TO HUB,
        ABANDON ZONE… and QUIT GAME;
      - ABANDON still asks first, with the same consequences, word for
        word.
    - **Options:**
      - field of view 100 is set, applied to the player's camera at
        once, and saved;
      - volume 50% puts the Master bus at -6.0 dB;
      - motion "off" and inverted look are set;
      - captions is not offered;
      - the settings file is put back byte for byte.
    - **Keys:** Down scrolls the journal, and Q still turns the page.
  - **`godot-candidate-live`**, through the real bridge
    (`H-JOURNAL_candidate_live.log`, all 9 phases):
    - after the install, the journal, opened with Escape then E, says
      "Installed the power cell in ...";
    - the Settings wall names this campaign's seed, with the link up;
    - after the restart, the journal still says it, from the bridge's
      record.
  - **Also green** on this code (`H-JOURNAL_suites.log`):
    `godot-menu-shell`, `godot-boot`, `godot-hud`,
    `godot-equipment-face` and `godot-map-face`.
- **Screenshots** (`H-JOURNAL_shots/`, lossless, under xvfb with
  opengl3 at 1280×720):
  - the journal after the latch;
  - the journal in the Hub;
  - the Settings wall in a Zone.
- **Sabotages** (`H-JOURNAL_sabotages.log`), each restored byte for byte
  (sha256):

| # | Rule removed | Caught by |
|---|---|---|
| JR-1 | the Zone's Checks counted as all confirmed | `_objectives`: "its name and its Checks, 2 of 15 confirmed" (it read 15 of 15) |
| JR-2 | the Hub's objective in the journal's own words | `_objectives`: "the Hub's own headline and detail, word for word" (it read "Find every Check.") |
| JR-3 | the Hub's "step back through the portal" shown in a Zone | `_objectives`: "and not the Hub's 'step back through the portal' while in it" (+1) |
| JR-4 | a way to an unfound room named by its save id | `_nothing_unfound_is_named`: "latched: ... no save id" ("Arena 4 to c010"), in 4 states |
| JR-5 | a setting back at its start listed as done | `_what_you_did_here`: "the span put back ... is not listed (6 lines)" |
| JR-6 | notes oldest first | `_notes_are_earned`: "one note per Echo in the log, newest first" |
| JR-7 | a shut gate without the bridge's reason | `_still_shut`: "each with the bridge's reason" (it read "shut") |
| JR-8 | every room listed as a place, found or not | `_places`: "the places found, by the bridge's names" |
| JR-9 | the campaign's Checks counted from this Zone alone | `_the_settings_wall`: "missing ['Checks confirmed: 8 of 21']" |
| JR-10 | the journal does not follow the snapshot | `_it_follows_the_snapshot`: "a snapshot refills it" (18 in all: nothing on the wall changes) |
| JR-11 | Down does not scroll the journal | `_keys`: "Down scrolls the journal (0 px)" |
| JR-12 | an option set but not saved | `_the_options_do_what_they_say`: "field of view 100: set, on the player's camera now, and saved" |
| JR-13 | field of view only for the next camera | the same check: the camera in use still at the old value |
| JR-14 | the volume slider changes nothing you hear | `_the_options_do_what_they_say`: "master volume 50%: the Master bus at 0.0 dB" |
| JR-15 | captions offered, though nothing reads them | `_the_options_do_what_they_say`: "captions, which nothing reads, is not offered" |
| JR-16 | a prettier label on the abandon action ("LEAVE THIS ZONE") | `_the_settings_wall`: "the pause menu's actions, one button each and as they were" (+1) |
| JR-17 | the fixture hand-edited (the blue door not opened) | `test_journal_fixture.py::test_the_committed_fixture_matches_its_generator` |

- **The sabotage run:** 17 of 17 on the first run, on the final code.
- **What stays open:**
  - **The Glyph-authored final look** (H-GLYPH-KIT) for both walls.
  - **Rebinding.** `PlayerSettings` can rebind actions and refuses to
    unbind a mandatory one, but no screen offers rebinding yet.
  - **"New campaign" is not offered in the game.** §8 asks that it be
    kept separate "wherever those existing actions are offered"; it is
    offered nowhere in the menus.
  - **The journal is this Zone's.** Places and consequences are the
    active Zone's record; completed Zones are counted, not described.
    The snapshot carries no history of earlier Zones' rooms.
  - **Captions** are stored and never read. Either a caption toggle
    needs something to switch, or the preference should go.
  - Owner usability and visual approval is a separate result.
- **What the owner will notice:**
  - The Journal wall lists what you are doing, what you have done here
    and what it opened, what is still shut and why, the places you have
    found, and each Echo's note, newest first.
  - Nothing names a room you have not been to.
  - The Settings wall shows your campaign on the left and options on the
    right: sensitivity, invert look, field of view, motion, volume. They
    take effect at once and are remembered.
  - The pause menu's own buttons are exactly as they were.

## CP4 checkpoint — closed (the full frontier)

- **On `a2115b6` (H-JOURNAL's head): 82 of 82 steps passed,** 13:07 to
  14:35 UTC (`CP4_frontier_on_a2115b6.tsv`).
  - The steps are CP3's 77 and this checkpoint's five:
    - the three suites CP4 added to CI: `godot-minimap` (30 checks),
      `godot-map-face` (52) and `godot-journal-face` (36);
    - `map_snapshot.json` and `journal_snapshot.json` regenerated from
      source: byte-identical, and restored.
  - `make test`: 2,228 passed (`CP4_make_test_on_a2115b6.log`). Every
    live suite passed too, among them `godot-candidate-live` (all 9
    phases), both integrations and the return journey.
  - The tree was clean at the start. At the end it differed only in the
    placement fixtures `godot-zone-audit` rewrites, which were restored.
- **Resizing** (CP4's proof names it). The minimap, the Map wall, and
  the Journal and Settings walls were each shot at 1280x720 and at
  1920x1080, by the suites' own shot modes (`--shots-size`, new;
  `CP4_resize_shots.log`):
  - the minimap stays anchored to the window's bottom-right corner, with
    the room's name above it, at both sizes;
  - the walls are pages rendered to a texture on the shell's 3D walls,
    so they scale as a whole. At 1920x1080 nothing is clipped, nothing
    overlaps, and every line is readable;
  - the 1920x1080 set is in `CP4_resize/`. The minimap's full frames
    are at 256 colours, with lossless crops of the plate, and checked
    against the raw render: no colour merged. The walls are lossless.
    The 1280x720 frames are the ones each item already committed.
- **CP4 is closed, on provisional art.** The packet's CP4 proof is
  "Actual names/gates/current data, rotation/zoom/drag/input tests,
  reload, resizing and owner usability".
  - The first five are in the three items' suites and live runs, and
    resizing is above.
  - Owner usability is the owner's to judge. The Glyph-authored look
    waits on Arty (H-GLYPH-KIT).
  - These are local results. Remote CI does not run (N-6).

## 0.4 — D-01 (D14 §7, Prod's half): a local Echo from your own original — landed (`9844ba5`)

D14 §1: "In a campaign under this policy, Epsilon also makes a local
Echo from that original, **whoever the recipient is, the player
included.**" §3: "A new campaign is created with `True`." §7 gives Prod,
in one commit: "creation sets `True`; the `grant_echo` and
`echo_backlog_sweep` filter; the confirmation text; the reveal; the
combined tests above."

- **Reproduced first**, on `a2115b6` (the CP4 head), by a scratch test
  on the real engine and mock AP (`D-01_repro_test.py.txt`). **6 of 6
  requirements fail** (`D-01_before.log`):
  - **D1:** a new campaign is created with the policy off, in memory
    and on disk;
  - **D2:** an own Check confirmed (`MockSeed-3`'s Epsilon Coin,
    89100006) mints nothing: "echo_89100006 minted 0 times";
  - **D3:** its card reads only `('Epsilon Coin', 'Delivered to you.')`;
  - **D4:** after a crash before the append, the reload mints nothing;
  - **D5:** so no Echo is written, and there is nothing to keep;
  - **D6:** with a failing provider, there is no Echo, fallback or
    otherwise.
  - **Controls, green before and after:** C1, the original is counted
    once; C2, a foreign Check is unchanged; C3, a legacy campaign mints
    nothing for its own item.
  - **After the change: 9 of 9** (`D-01_after.log`).
- **Two findings in my own tests, fixed before landing:**
  - **D01-F1: a control that measured the wrong thing.** C1 counted
    every received item, and failed on the unchanged code (0 → 2). On
    each confirmation the mock also has another player find one of
    yours. The test now counts this Check's original only (sent by this
    slot, with this item id), and checks that keys and coins are counted
    from ReceivedItems alone.
  - **D01-F2: a check that could not fail.** D5 compared the Echo
    before and after the reload. The fallback provider is deterministic,
    so a regenerated Echo would compare equal. The committed test counts
    the requests the provider receives instead (`CountingProvider`).
- **What changed:**
  - **`campaign.py`:**
    - creation sets `self_addressed_echoes=True`. This is the only
      creation path; every other construction copies an existing save;
    - **`yields_echo(location_id)`** holds the whole rule: a foreign
      original always yields an Echo, and your own only in a campaign
      created under the policy. `grant_echo` and `echo_backlog_sweep`
      both ask it, so the rule has one place;
    - the rest of the grant is as it was: one at a time, the same
      request, validated generation with the deterministic fallback, the
      append, and the same budget (interacted Checks now, others at most
      3 per load).
  - **`transactions.finalize`:** one card per confirmed Check.
    - Your own item: "CHECK CONFIRMED", the item, "Delivered to you.".
      Under D-01 the Echo half follows the blank line: "EPSILON ECHO
      ACQUIRED", the Echo's name and its description. The card carries
      the Echo's id.
    - A foreign item's card is unchanged. So is a legacy campaign's own
      card: `grant_echo` answers None.
  - **The reveal:** `RevealLayer` already splits a card on its first
    blank line and, given an Echo id, adds that Echo's effects in the
    inventory's words. So your own item's card now shows two halves, as
    a foreign one does. `RevealLayer.shown()` (new) reads the card back
    for the suites.
- **Tests:**
  - **`bridge/tests/test_self_echo_integration.py`** (new, 9 tests), one
    per D14 §6 line:
    - the policy is on at creation, and still on after a reload;
    - an own Check gives one Echo, and its original is counted once, by
      AP alone. That still holds after a second grant, a sweep, a
      duplicate append and a reload;
    - the card;
    - a foreign Check is unchanged;
    - the legacy card;
    - a failing provider falls back under the same id, and is not asked
      again;
    - a crash before the append is granted once on reload, and
      announced;
    - a written Echo is never asked for again (provider requests
      counted);
    - your own Checks confirmed elsewhere wait in the foreign queue: 3
      this load, the rest on the next.
    - **On the unchanged code, 7 fail and the 2 controls pass**
      (`D-01_tests_on_unchanged.log`).
  - **`test_full_loop.py`:** "ONE ECHO PER FOREIGN CHECK, AND NOT ONE PER
    CHECK" becomes one Echo per Check for a new campaign and one per
    foreign Check for a legacy one, as D14 §6 asks.
    - The default seed's first Zone holds none of your own items, so on
      it both counts are the same number and prove nothing.
    - The loop now runs three ways: the default seed; `MockSeed-3`,
      whose first Zone holds one of yours; and `MockSeed-3` as a legacy
      campaign.
    - On the unchanged code only the own-item loop fails: "2 Checks
      should interpret (1 own, legacy=False) but 1 interpretations"
      (`D-01_full_loop_on_unchanged.log`).
  - **`test_campaign_soak.py` encoded the same B-1,** and the first full
    run found it: "an Echo from an unconfirmed location: {89100027,
    89100020, 89100013, 89100006}", four of your own Checks.
    - Its "confirmed" meant "foreign and confirmed". It now means
      confirmed.
    - It also asserts what its header always said and never checked:
      every Check played and confirmed produced its Echo. 25 seeds.
  - **Dess's pinned `test_self_echo_boundaries.py`: one setup step
    moved** (note N-12). The legacy test converted the save to legacy
    after the claim. That was a legacy confirmation only while creation
    left the policy off. It now converts before the claim, and every
    assertion is as it was.
  - **`integration_driver.gd`** (`godot-integration`, a whole campaign,
    live):
    - "N foreign checks -> N interpretations" becomes "30 Checks (k
      your own) -> 30 interpretations, one each";
    - each of your own items' cards, as the live bridge sent it, reads
      "Delivered to you." then its Echo;
    - the real card shows both halves, with the Echo's effects.
  - **`dual_real.py`** (two Archipepsi slots on a real server):
    - its "an Echo for its OWN item" check now applies to a legacy
      campaign only;
    - it also checks that every Echo names a location its campaign
      confirmed.
    - **Not exercised (D01-F3).** `make dual-real` cannot reach it. On
      a fresh two-slot seed, its first claim is refused: "Zone
      'zone_001' has not had its layout accepted (layout_state
      UNCERTIFIED)". The harness claims without certifying a layout,
      which the certification guard refuses. It fails identically on
      the checkpoint without D-01 (`D-01_dual_real_on_6b57326.log`).
      This is the same rot `test_full_loop.py`'s docstring records for
      `smoke.py`. It is open, below.
- **Played live** on `dc66f2f` (D-01 rebased onto the CP4 checkpoint,
  with D-5 on top; `D-01_live.tsv`). The frontier's 14 live suites all
  passed, 14:43 to 15:06 UTC:
  - **`godot-integration`,** a whole campaign to ALL_CHECKS_CLEARED:
    - "30 Checks (4 your own) -> 30 interpretations, one each";
    - "each own item's card: 'Delivered to you.', then EPSILON ECHO
      ACQUIRED with its Echo (4 cards; wrong: [])";
    - "the real card shows both halves: 'Epsilon Coin / Delivered to
      you.' above the rule; the Echo, and its 3 effect line(s), below
      it".

    `godot-integration-quiet` says the same.
  - **The other twelve:** the variant, the candidate (all 9 phases),
    both consumable runs, the latched, lever, transport and reversible
    routes, resume, ordinary, reload and the zone audit.
  - `make test` on the same head: 2,249 passed
    (`D-01_D-5_make_test_on_dc66f2f.log`).
- **Sabotages** (`D-01_sabotages.log`), each restored byte for byte
  (sha256):

| # | Rule removed | Caught by |
|---|---|---|
| D01-1 | a new campaign created with the policy off | `test_a_new_campaign_is_created_with_the_policy_on` (+7) |
| D01-2 | the old filter back: your own item never yields an Echo | `test_an_own_check_yields_one_echo_and_its_original_once`, the own-item full loop and all 25 soak seeds (32 in all) |
| D01-3 | the policy ignored: a legacy campaign's own item yields one | Dess's `test_a_legacy_campaign_mints_nothing_for_its_own_item`, the legacy card and the legacy full loop |
| D01-4 | the sweep keeps the old filter, so a lost own grant never resumes | `test_a_crash_before_the_append_is_granted_once_on_reload` (+1) |
| D01-5 | your own Checks confirmed elsewhere skip the lazy budget | `test_own_checks_confirmed_elsewhere_wait_in_the_foreign_queue` |
| D01-6 | your own card without its Echo half | `test_the_card_says_delivered_to_you_then_the_echo` (+1) |
| D01-7 | your own card without the Echo's id, so the reveal cannot show its effects | the same test (+1) |
| D01-8 | your own card as a reveal "SENT TO" you | the same test (+1) |
| D01-9 | a written Echo asked for again (the grant not idempotent) | `test_a_failing_provider_falls_back_under_the_same_id` |
| D01-G1 | the card shows an Echo's effects only on a foreign reveal (`reveal.gd`) | `godot-integration`: "the real card shows both halves" |
| D01-G2 | the old filter back, played live | `godot-integration`: "30 Checks (4 your own) -> 26 interpretations ... none missing [89100006, 89100013, 89100020, 89100027]", and both card checks |

- **The sabotage run: 11 of 11, each on its first run.** The nine
  bridge rows ran on `2c4d721`: D-01 before its rebase, byte-identical
  in what it changes. The two live rows ran on `dc66f2f`.
  - The live rows' first log also counted "2 script errors". That was
    the make recipe's own `grep "SCRIPT ERROR"` text. The runner now
    counts only Godot's error lines and was rerun: 0.

- **What stays open:**
  - **D01-F3: `make dual-real` has not been able to claim since the
    certification guard.** It is not in the frontier or CI, so nothing
    noticed. Repairing it means certifying a layout the way
    `conftest.enter_zone` does, with the evidence labelled synthetic as
    `test_full_loop.py`'s is. That is its own change.
  - **The prompt:** the provider still calls every item "foreign" (D14
    §2). That wording is the Epsilon lane's.
  - **D14 §5 is unchanged:** B-2/D-02 (qualification) and B-3/D-03
    (pre-seed representation).
  - **A legacy campaign cannot opt in.** D14 §3: turning the policy on
    would be "a visible act the owner asks for", and it is not part of
    this contract.
- **What the owner will notice:**
  - In a new campaign, a Check holding one of your own items (a Signal
    Key, a coin) now also gives you an Echo. It appears on the card
    under "Delivered to you.", with what it does.
  - The item itself still arrives once, through Archipelago.
  - Campaigns you have already saved behave as before.

## 0.4 — D-5 (Dess's note): H-QUALIFY at the grant — the featured Echo supplies its function — landed (`dc66f2f`)

Dess's note D-5, "the pipeline's half": at grant, the requirement for the
Zone record whose `featured_acquisition` names the location; the request
carries `req.describe()`; `featured.check` joins the semantic step; after
the one repair fails, `featured.fallback_interpretation` replaces the
generic fallback. Combined tests: "a provider returning an enemy pull
yields the qualifying fallback; a good provider's Echo is kept; the same
holds for self-addressed and foreign originals."

- **Reproduced first**, on `2c4d721` (D-01), with the committed tests
  (`D-5_before.log`). **7 of 10 fail:**
  - the provider is never told the function: the request has no field
    for it;
  - an enemy pull is accepted for the featured Check, own and foreign:
    "the featured Echo does not supply the requirement";
  - with the fallback provider, own and foreign, the item's heuristics
    hand over no grapple ("the featured Echo must supply
    grapple_to_surface");
  - the requirement's own Echo has no labelled form;
  - an Echo that does not fold crashes the grant (D05-F2, below).
  - **Controls, green before and after:** a provider's Echo that
    supplies the function is kept, own and foreign; the same enemy pull
    on a Check no Zone features is accepted. That last one is what makes
    every refusal above the featured check's, and not another rule's.
  - **After the change: 10 of 10** (`D-5_after.log`).
- **Two findings, both repaired here:**
  - **D05-F1: the one fallback that must always hold would raise.**
    `featured.fallback_interpretation` builds an Echo with no concepts,
    and the pipeline's semantic step refuses an Echo without them
    (`reading_errors`). It also validates its own fallback, and treats a
    refusal as "a bug in our own generator": it raises. Found before
    wiring, by calling the two together. The pipeline now stamps the §15
    reading on the requirement's Echo, as it does on every deterministic
    Echo (`_read_and_label`). The function is unchanged, and the test
    asserts it. Note N-13 asks Dess whether the concepts belong in
    `featured.py` itself.
  - **D05-F2: an Echo that does not fold crashed the grant.** No
    semantic check asked whether an Echo folds onto this campaign's log.
    An Echo that CREATEs an id the campaign already owns passed them all,
    and the append then raised mid-grant: "component 'act_hook' already
    exists". That left a confirmed Check with no Echo and no card, and
    the same failure at every later sweep. This predates D-5. The
    featured check folds the candidate too, so it met the crash first.
    `fold_errors` now refuses such an Echo in the semantic step: it is
    repaired like any other invalid Echo, then replaced by the fallback.
- **What changed:**
  - **`epsilon/requests.py`:** `EchoGenerationRequest.required_function`,
    None for every Check but a featured one. It is bounded at 400
    characters, not `MAX_TEXT_LEN`: the grapple's statement alone is 185.
  - **`campaign.py`:**
    - `featured_requirement(location_id)` reads the requirement off the
      Zone whose `featured_acquisition` names the location, never off the
      recipient;
    - `grant_echo` passes it, its statement, the log and the next
      sequence to the pipeline.
  - **`epsilon/base.py`:**
    - the semantic step runs as before. Only an Echo that passes it is
      folded: first `fold_errors`, then, for a featured Check,
      `featured.check`;
    - a featured Check's fallback is `featured_fallback`.
  - **`epsilon/fallback.py`:** `featured_fallback` is Dess's
    `fallback_interpretation`, labelled.
- **Tests:** `bridge/tests/test_featured_grant.py` (new, 10). The Zone is
  built through the real transitions and the Check claimed through the
  real transaction:
  - the provider is told the function, and only for the featured Check;
  - an enemy pull is refused, repaired once (the repair names the
    missing function), and replaced by the requirement's own Echo. It
    supplies the function, carries concepts, and is announced. Own and
    foreign;
  - an Echo that supplies it is kept as written, asked once, own and
    foreign;
  - the same enemy pull elsewhere is accepted (the control);
  - the fallback provider still hands over a working grapple, own and
    foreign;
  - the requirement's Echo reads as its item, and labelling changes
    nothing it does;
  - an Echo that would not fold is repaired and never appended.
- **Sabotages** (`D-5_sabotages.log`), each restored byte for byte
  (sha256):

| # | Rule removed | Caught by |
|---|---|---|
| D05-1 | the provider is never told the function | `test_the_provider_is_told_the_function_and_only_for_that_check` |
| D05-2 | the featured check not applied | `test_an_enemy_pull_is_replaced_by_the_requirements_own_echo`, own and foreign (4 in all) |
| D05-3 | the generic fallback in place of the requirement's own | `test_the_fallback_provider_still_hands_over_a_working_grapple`, own and foreign (4 in all) |
| D05-4 | the requirement's Echo left unlabelled | `test_the_requirements_echo_reads_as_its_item`, and four grants that raise "fallback echo generator produced invalid output: concepts must not be empty" (D05-F1, reproduced) |
| D05-5 | the requirement read off the recipient (own Checks exempt) | `test_an_enemy_pull_is_replaced_by_the_requirements_own_echo[own]` (+1) |
| D05-6 | an Echo that would not fold is not refused | `test_an_echo_that_would_not_fold_is_repaired_never_appended` |
| D05-7 | every Check held to the featured requirement | `test_the_same_enemy_pull_elsewhere_is_accepted` (+2) |
| D05-8 | the absent requirement serialised as null in every request | the "told" test, and the pre-art baseline's two guards |

- **The sabotage run: 8 of 8, each on its first run.**
- **Found by the first full run, repaired:** the new field, null on
  every request, changed the pre-art baseline (`make baseline`). That
  baseline is retaken only deliberately, in its own commit. The field
  is now absent unless it is set, so every other request serialises
  exactly as before: the baseline, the archive, and the provider's
  input. D05-8 re-breaks it.
- **Played:** the same 14 live suites as D-01, on the same head
  (`dc66f2f`). No composed Zone features a Check yet, so they exercise
  the fold check (D05-F2) on every grant and the featured path on none.

- **What stays open:**
  - **No composed Zone features a Check yet.** The composer's half is
    Dess's D-6, which waits on Prod's confirmation of the gantry
    interface. Until then this runs wherever a Zone declares a featured
    acquisition, and no production Zone does.
  - **The prompt:** the request carries the statement, and the system
    prompt does not mention the field. The statement explains itself,
    but the wording belongs to the Epsilon lane.
- **What the owner will notice:** nothing yet, until a composed Zone
  features a Check (D-6). After that, the Echo from that Check always
  works where the room needs it. Epsilon names it and gives it its look.

## 0.4 — H-GRAPHS, slice 1: the five signal verbs on the graphs real rooms run — landed, runtime-only

Design 3 §14 and §19.7. `05_INHERITED` O05-07.4: "Five signal verbs and
temporary override expiry not started." The evidence H-GRAPHS asks for:
"Actual input→consequence, override expiry, persistence and refusal."

- **Reproduced first:** `godot-signal-verbs` (new) against the
  unchanged runtime of `7166b35` (`H-GRAPHS_before.log`). **26 of 32
  checks fail**, which is every verb. The six that pass are controls:
  the rooms' starting states, the real lever throwing its bolt, and "a
  rebuilt room carries no verb".
- **What changed, `signal_graph.gd`:**
  - **`apply_verb(verb, target, magnitude, destination)`:** PROBE,
    BRIDGE, INVERT, HOLD_SIGNAL and CUT, each for `magnitude` seconds.
    - §19.7: INVERT, HOLD_SIGNAL and CUT override a node's output at
      evaluation step 1, and BRIDGE ORs its source into the
      destination's input.
    - A verb can target a sensor, a logic node, or an actuator's input.
  - **§14.3's legality**, by what the target is, for the kinds this
    runtime evaluates. A refusal says why and changes nothing.
  - **BRIDGE** is refused when it would close a cycle (§19.7). While one
    stands, each node is evaluated after everything it reads.
  - **Expiry:** a verb runs down on the graph's own clock, and its
    expiry re-evaluates the machine, as a TIMER's does.
  - **N-15's conservative rule.** While a verb stands, the machine runs
    on two tracks:
    - the verified track, with no verb, sets the recorded LATCHes and
      keeps the verified TIMERs;
    - the live track drives the actuators.

    So a verb can hold a door open but can never set a latch. CUT on a
    set latch reports it OFF for the duration and leaves the record
    alone.
  - **PROBE** reveals the value, the verified value, the inputs and the
    predicate, and changes nothing.
  - **Nothing a verb does is saved:** overrides and bridges are runtime
    state, and a rebuilt room has none.
- **Two findings in my own work, repaired:**
  - **HG-F1, caught by the existing suites.** The first version always
    ran two tracks. `godot-signal-graph` drives a node by writing
    `values`, and `godot-counterfire` fast-forwards its window by
    writing `timers`. Both are documented idioms, and the second track
    read neither: a latch never set, and a window never closed (8
    checks, `H-GRAPHS_first_runtime.log`).
    - Now, with no verb standing, there is one track, exactly as
      before. The first verb splits the machine from where it stands,
      TIMERs included, and the last one's expiry merges it back.
    - Both suites pass again (61 and 59).
  - **HG-F2, caught by the reproduction.** Nine checks passed on the
    unchanged runtime for the wrong reason:
    - seven "...when it expires" checks held because nothing had been
      applied;
    - two refusal checks held because the old runtime refused
      everything.

    Each expiry check now requires the verb to have been standing, and
    each refusal check requires its own reason. On the old runtime the
    passes fell from 15 to the 6 controls.
  - **Scope, trimmed before landing:** §14.3 has rows for DIRECT, AND,
    SEQUENCE, COUNTER, SELECTOR, THRESHOLD and DELAY, and none of them
    is evaluated here. Their rows were dropped (O05-07: "do not emit an
    unused catalogue"). A kind with no row takes no verb.
- **Played:** `godot-signal-verbs` (new, in CI, 32 checks;
  `H-GRAPHS_after.log`), on four graphs the game builds for real:
  - **the held route** (D-07's plate to shutter,
    `held_route_zone.json` through the real `ZoneController`):
    - HOLD_SIGNAL on the empty plate opens the shutter while the plate
      itself still reads empty (verified OFF);
    - the shutter shuts when the verb expires;
    - INVERT on the shutter's input does the same;
  - **the latched route** (plate to LATCH to shutter):
    - HOLD_SIGNAL on the plate never sets the latch;
    - HOLD_SIGNAL on the shutter's input holds the way open, and it
      shuts on expiry with nothing recorded;
    - HOLD_SIGNAL and INVERT on the LATCH are refused (§14.3);
    - a rebuilt Zone carries no verb and no latch;
  - **EX50-033**, with its real crate on its drive:
    - INVERT on the NOT turns the shutter over;
    - a BRIDGE from the plate into the OR makes the crate that holds the
      shutter shut hold it open, for 3 s;
    - a BRIDGE from the OR back into the NOT is refused as a cycle;
    - bad BRIDGE ends are refused (§14.3);
    - HOLD_SIGNAL on the bolt lever never throws the bolt, and the real
      lever still throws it, once;
    - CUT on the thrown bolt shuts the way for its duration with the
      record untouched, and the way reopens after;
  - **EX50-021:**
    - INVERT on the TIMER is refused;
    - HOLD_SIGNAL on the TIMER holds the window open past its 8 s, and
      then it shuts;
    - PROBE on the release LATCH reveals it and changes nothing;
    - an unknown verb, a zero duration and an unknown node are each
      refused with their own reason.
  - **Also green on the final runtime** (`H-GRAPHS_suites.log`):
    `godot-signal-graph` (61), `godot-counterfire` (59),
    `godot-unweighted` (70), `godot-counterfire-hosted` (25),
    `godot-latched-route` (73), `godot-held-route` (33).
- **Sabotages** (`H-GRAPHS_sabotages.log`), each restored byte for byte
  (sha256):

| # | Rule removed | Caught by |
|---|---|---|
| HG-1 | a recorded LATCH set from the live track | "HOLD_SIGNAL on the plate never sets the recorded LATCH (N-15)", and the bolt's (3 in all) |
| HG-2 | §14.3 ignored: a TIMER takes INVERT | "a TIMER cannot take INVERT (§14.3)" |
| HG-3 | a BRIDGE that closes a cycle is not refused | "would close a cycle, and is refused with nothing changed" (+1) |
| HG-4 | a verb never expires | every expiry check (16 in all) |
| HG-5 | a BRIDGE carries nothing into its destination | "BRIDGE from the plate into the OR" |
| HG-6 | CUT on a latch clears the record | "and the record is untouched" (+1) |
| HG-7 | the verified track reads the verbs too | "its verified value is OFF", and the latch checks (4 in all) |
| HG-8 | PROBE changes the machine | "PROBE ... changes nothing" (+1) |
| HG-9 | §14.3 ignored: a LATCH takes HOLD_SIGNAL | "a LATCH cannot take HOLD_SIGNAL (§14.3)" (+1) |

- **The sabotage run:** 9 of 9 on the first run. After the table trim
  and one refinement (the merge back to one track runs only after a real
  split, not on every ordinary TIMER lapse), all nine were run again on
  the final runtime: 9 of 9.
- **What stays open:**
  - **No Echo delivers a verb, and none will until a room consumes one.**
    That is Dess's reply to N-15, under the owner's D-04 principle. §14.2's
    targeting belongs to that delivery:
    - seen nodes only, within range and line of sight;
    - BRIDGE's two activations within 10 s.

    This slice takes node ids.
  - **DIRECT, AND and SEQUENCE are not built.** None is planned in 0.4,
    and no room names one (Dess's reply to N-15).
  - **N-15's question is answered:** a recorded LATCH is a macro setter
    (Dess). That is the rule this slice implements.
  - **No presentation:** PROBE's reveal, and a node standing under a
    verb, have no visual yet.
- **What the owner will notice:** nothing yet, because no Echo carries a
  verb. Underneath, the rooms' machines now answer Design 3's five
  verbs, and none of them can open a way for good.

## 0.4 — D-9 (Dess's note; D-6 step 3): a span's control on a gantry — landed

Dess's note D-9: "`RailSpan.control_placement` is in the schema ... Your
step 3, the gantry placement in `RailNetworks`, comes next. My step 4,
the composer, follows it." `CONTROL_PLACEMENT_CAPABILITY["gantry"]` is
`grapple`, so the AP logic declares that the control needs the proven
anchor grapple. This makes the room hold exactly that gate: not less,
which would be a loop a player skips, and not more, which would be a
gate the logic does not declare.

- **Reproduced first:** `godot-rail-gantry` (new) against the unchanged
  engine of `41fd8cd` (`D-9_before.log`). **10 of 16 checks fail:**
  - `RailNetworks` never read the field, so a gantry span got the ground
    lever at the arrival;
  - the base kit walked up to that lever and pulled it: "the base kit
    cannot operate the control from the floor" fails, and that is the
    defect. The logic says grapple, and the room asked for nothing;
  - no room was refused, whatever its height or size.
  - **Controls, green before and after:** a span declared `ground`, and
    one that declares nothing, keep the lever at the arrival and build no
    gantry.
- **What changed:**
  - **`rail_networks.gd`, the gantry.** The development scenario's
    measured arrangement, carried relative to the floor the player
    grapples from, which is what was proven there:
    - a 4 × 0.4 × 4 m deck, top 2.9 m up. A standing jump peaks at
      1.40 m and there is no mantle;
    - the plate the hookshot bites is 6.2 m up, over the deck's near lip,
      1.5 m beyond where the player stands. It has a glowing ring, as the
      scenario's does;
    - the lever stands on the deck, facing the approach, on a post;
    - **no stairs,** by the owner's rule.
  - **The placement is searched, nearest the arrival first.** The
    scenario's order is the design's: the gantry is seen on arriving, and
    opened later. The search tries an approach mark every metre, along
    each of the room's four axes, ordered by the deck's distance from the
    arrival (a total order, so a room gives the same gantry on every
    build). A candidate passes when:
    - its footprint, with 0.5 m to spare, is inside the room;
    - no track passes within the carrier's half-width plus a rider's
      radius. A control room is usually a dock room, and a deck across
      the track is a carrier that cannot pass;
    - the approach and the post stand on floor at the arrival's height,
      which the measured pull is relative to;
    - the column the pull climbs, the space over the deck and the post
      hold no collider. The floor under the deck is not a path, so a
      crate there is a crate under a gantry;
    - and the base kit cannot reach the deck (below).
  - **The base kit's reach, measured per room (`reach_field`).** "A
    standing jump tops out below the deck" is true of the floor under it,
    and says nothing about a gallery beside it. The field works as
    follows:
    - it samples the room's standable surfaces, one ray down per 0.5 m
      cell and up to four deep;
    - it fills them from the floor with the base kit's played jump
      (D09-F2), climbing to neighbouring cells and then jumping across
      gaps;
    - it refuses a deck within a jump of anything reached.
    - **It errs one way.** Walls are not in the field, a jump is not
      blocked by what stands between, and a cell counts as far as it
      reaches. Each of these can only add reach, never hide it.
  - **A refusal is by name and builds nothing for that network, and the
    Zone still builds.** The cases are:
    - too low for the plate;
    - no position passes. The refusal counts which test each candidate
      failed, and for the nearest candidate it says where the base kit
      jumps from;
    - two gantries in one room.
  - **`alignment_control.gd`: `worked_from`** (D09-F1). A gantry's lever
    is pulled only by a player standing on its deck. Elsewhere, the
    prompt says "REACHED FROM THE GANTRY" instead of offering an action
    that does nothing. Every ground lever has no `worked_from` and is
    unchanged.
  - **`zone_controller.gd`** passes the rooms' bounds to the railways.
- **Findings, all repaired here:**
  - **D09-F1: the lever on the measured deck answered the interact probe
    from below.**
    - At the top of a standing jump beside the lip, the eye is at 3.00 m,
      over a 2.9 m lip. The lever stands 2 m in, inside the 3 m probe, so
      a timed press pulled it with no grapple.
    - A passing carrier's deck puts the eye higher still.
    - The deck cannot be raised without re-measuring the pull, and a
      floor lever is one you stand at anyway. Hence `worked_from`.
    - Sabotage D09-5 reproduces the exposure on the final geometry: the
      probe finds the lever on 13 frames of the jump, and without the
      rule it moves.
  - **D09-F2: the base kit's jump peaks at 1.40 m, not the continuous
    1.33 m of `JUMP_APEX_HEIGHT`.**
    - `player.gd` integrates explicitly at 60 Hz, which peaks half a step
      higher.
    - The suite measures a standing jump at 1.40 m, and the field uses
      that figure (`stepped_apex`).
    - A tie at the apex counts as reached. A capsule can catch the edge
      of a ledge at exactly its apex, and the 0.02 m tolerance means the
      tie is decided by the rule, not by float noise in a ray's hit
      height.
    - Sabotage D09-10 shows the difference: with the continuous figure, a
      1.38 m step reads as unclimbable.
  - **D09-F3: three fixed positions were not a placement.** The first
    build tried the centre and 4.7 m either side (`D-9_first_placement.log`):
    - in the suite's first room, the track passed 2.2 m and 2.1 m from
      two of the positions;
    - a prop stood in the third.
    - The first search then kept the whole block over the deck clear
      (`D-9_whole_block_volume.log`), and none of 900 candidates passed.
    - That is why the placement is searched, and why only what the player
      uses must be clear.
  - **D09-F4 (my test): a control that was not one.** The first control
    was "the same gallery with no way up to it"
    (`D-9_first_green_but_one.log`).
    - The fill reached the gallery anyway, from a 1.12 m crate 2.2 m
      away, as a player could. The measurement was right and the test
      was wrong.
    - The control is now the same block 1.3 m up. It is reached, and a
      jump from it tops out at 2.70 m.
  - **D09-F5 (my test): two lip attempts that never jumped.**
    - They started 4 m behind the approach, which in that room was
      beyond the wall. The player fell, never jumped, and the check still
      passed (`D-9_runups_vacuous.log`).
    - The per-attempt notes showed it.
    - The run-up now stays on the room's floor, and each attempt must
      leave the floor where it meant to and rise.
  - **D09-F6 (my tests): four checks were decided by the arena, not by
    the rule they were for.** The first sabotage run caught 12 of 16
    (`D-9_sabotages_first.log`). Each of the four misses sat in a real
    arena whose clutter settled it first:
    - ignoring the track changed nothing, because the nearest position
      was already 3.08 m off it;
    - the continuous apex changed nothing, because a crate beside the
      stair reached the gallery whatever the step's height;
    - dropping the floor rule changed nothing, because the nearest
      position already avoided the gap;
    - a lowered deck was refused by the reach measurement before its
      height was read. That refusal is right, so it keeps a row of its
      own (D09-2b), and a raised deck tests the height (D09-2).

    Each of the first three now has a case on a bare floor, where it
    alone decides.
- **The suite, `godot-rail-gantry`** (new, 41 checks; `D-9_after.log`).
  The Zone cases run through the real `ZoneController`, with the real
  `Player` driven by `Input`:
  - **Built as measured:** the deck is 2.90 m up and the plate 6.20 m.
    The plate hangs over the near lip, the lever stands on the deck, and
    all of it is in the room that declared it. The track passes 3.08 m
    from the deck, and a jump from the carrier tops out at 2.35 m.
  - **The base kit, played:**
    - a standing jump peaks at 1.40 m;
    - three attempts at the lip: two hit the deck's underside, and one
      takes off 2.45 m short, peaks at 1.40 m against the deck's side,
      and falls;
    - the lever at the top of a jump beside the lip is found by the
      probe and does not move, and says why;
    - the lever from the floor does nothing.
  - **The grapple, played:** `set_equipped` with the scenario's own
    component. Aimed at the plate, fired through the mobility key and
    held forward, the pull lands the player on the deck (from 0.00 to
    2.90 m, peak 3.98 m). The lever is offered there, it starts the
    span, and the span commissions under its declared latch.
  - **The controls:** a `ground` span and an undeclared one are
    unchanged.
  - **The refusals:** a 5 m arena, an 8 × 8 arena, and two gantries in
    one room are each refused by name. In each, nothing is built and the
    Zone still builds.
  - **The measurement on its own:**
    - a gallery the base kit climbs to, a metre past the deck, is
      refused, and the placement moves elsewhere;
    - the same block at 1.3 m is not refused;
    - a crate in the column the pull climbs moves the gantry.
  - **The rules on a bare floor**, in rooms of their own with nothing
    the case did not put there:
    - across a gap in the floor, with the arrival over it, neither the
      approach nor the post stands over the gap. That holds to the
      field's resolution: floor is known per 0.5 m cell, and a body
      0.25 m past an edge still stands on it;
    - a track laid through the chosen deck moves it 2.50 m off (the
      carrier needs 2.10 m);
    - a gallery up a 1.38 m step, a metre past the deck, is within
      reach. That step is one the played jump makes and v²/2g says it
      cannot;
    - the same gallery at 1.3 m is not within reach (the control).
- **Also green on the final engine** (`D-9_suites.log`):
  `godot-rail-zone` (25), `godot-rail-junction` (140) and
  `godot-rail-carrier` (73); `test_ci_coverage.py`. `make
  godot-rail-gantry` is in the Makefile and CI after `godot-rail-zone`.
- **Sabotages** (`D-9_sabotages.log`), each restored byte for byte
  (sha256):

| # | Rule removed | Caught by |
|---|---|---|
| D09-1 | a gantry span gets the ground lever (the old build) | "a gantry was built for span s0" (6 in all) |
| D09-2 | the deck raised to 3.3 m | "the deck's top stands ... (measured: 2.9)" (+1) |
| D09-2b | the deck lowered to 2.6 m | the reach refuses every position before the height is read: "the network was not refused" (6 in all) |
| D09-3 | the plate over the deck's middle, not its near lip | "the plate hangs over the deck's near lip" (10 in all) |
| D09-4 | the track ignored | "a track through the chosen deck moves it off" |
| D09-5 | the gantry's lever worked from anywhere | "at the top of a jump beside the lip ... it does not move" (3 in all) |
| D09-6 | standing on the deck not asked | the same (3 in all) |
| D09-7 | the lever offered to a player off the deck | "and what it says there is why" |
| D09-8 | the placement does not ask the base kit's reach | "and the room does not put its gantry there" (3 in all) |
| D09-9 | a jump onto the deck never counted | "a gallery the base kit climbs to" (3 in all) |
| D09-10 | the continuous apex (1.33 m), not the played one | "on a bare floor, a gallery up a 1.38 m step" |
| D09-11 | the flight volumes not measured | "a crate in the column the pull climbs" |
| D09-12 | no floor asked for under the approach and the post | "across a gap in the floor" |
| D09-13 | the room's height not asked | "a 5 m arena" |
| D09-14 | two gantries to a room | "two gantries in c002" |
| D09-15 | the Zone does not pass its rooms' bounds | "the network was not refused" (7 in all) |
| D09-16 | a refused gantry quietly becomes a ground lever | "a 5 m arena" (+1) |

- **The sabotage runs:** 12 of 16 on the first run
  (`D-9_sabotages_first.log`, D09-F6). After each of the four misses got
  its own case, all 17 were run on the final suite, and 17 of 17 were
  caught (`D-9_sabotages.log`).

- **What stays open:**
  - **The development scenario's own gantry** has D09-F1's exposure. It
    is the arrangement the owner reviewed, and `railway_shot_driver`
    pulls its lever by script, so it is left as reviewed. The fix is one
    line there (`worked_from`) and a scripted pull in the shots.
  - **Room space (N-16).** In the suite's 16 m arena, with the track
    across it and a dozen props, no position passes
    (`D-9_stepped_apex_16m.log`):
    - 900 were tried: 526 were outside the room, 324 on the track, 47
      not clear, and 3 within the base kit's reach through a chain of
      crates and cover;
    - a 24 m arena takes a gantry.
    - That is for Dess's step 4, the composer.
  - **Build order.** `RoomGraphs` is built after the railways, and its
    plate search reads only the room's own solids, so it does not see a
    gantry. No Zone has both.
  - **Not in the field:** objects a player moves, which could be carried
    and stacked, and anything built after the railways.
  - **No sign.** The ring is the affordance, as in the scenario, and the
    lever explains itself when probed from below.
- **What the owner will notice:** nothing yet, since no composer emits
  a gantry until Dess's step 4. When one does, a span's lever may stand
  on a gantry in its room, out of the base kit's reach, and the anchor
  grapple the Zone's featured Check supplies is what gets you onto it.

## 0.4 — H-STATUS, slice 2: the KINETIC pair on every target the runtime models — landed, runtime-only

`05_INHERITED` O05-09.1's remainder: "anchored object/player; lightened
enemy/player". H-STATUS's evidence is "behavior in world; no legacy
corruption or actor damage substitute".

Design 5 §15.2's exact effects:
- **`anchored`:** `mass_class` becomes `FIXED`, and the body is immune
  to all impulse, wind, conveyor and Physics. On an actor, movement is
  0.0 and attacks continue. On the player, movement is 0.0, jump is
  blocked, and all other actions are permitted.
- **`lightened`:** `mass_class` drops one step, incoming impulse is
  ×2.0, and wind and conveyors now affect it.
- **Design 1 item 72:** the two never coexist. "Applying either removes
  the other."

- **The gate is Dess's.** `StatusEffects` applies a kind to a target
  only once `SUPPORTED_STATUS_TARGETS` (`schemas/echo.py`) declares that
  the runtime implements it there, and none of these four is declared.
  - So the runtime lands first. Each container now holds its table as a
    field (`supported`), which defaults to the generated one, and
    nothing in the game sets it.
  - The suite hands the table over as it will be declared, and applies
    through the real path.
  - Its first case asserts that the production gate agrees with the
    production table, whichever way Dess has declared it by then.
  - Note N-17 asks for the declaration.
- **Reproduced first:** `godot-status-kinetic` (new), on the unchanged
  runtime of `82068a9` (`H-STATUS-2_before.log`). **21 of 35 checks
  fail.** On that runtime the Status is written where an application
  would have put it, so what fails is that nothing reads it:
  - the anchored player walks 7 m, jumps 1.40 m, and is thrown by a
    knock;
  - the anchored dash fires;
  - its class stays MEDIUM;
  - a lightened player and enemy take a knock at ×1.0;
  - the pair coexist;
  - the anchored crate slides under a push, is shoved 4.4 m when walked
    into, and falls from where it was anchored;
  - the hands say "CAN'T CARRY THAT";
  - a carried one is kept.
  - **Controls, green before and after:**
    - the gate agrees with the table;
    - a shield, and a lever in reach, both work while anchored;
    - an anchored player 3 m up still comes down;
    - a lightened player walks and jumps as a plain one does;
    - the verbs still call an enemy's mass unmodelled;
    - a bolted crate stays frozen.
- **What changed:**
  - **The player (`player.gd`).** Anchored:
    - the walk's speed is 0, so there is no walk intent, and therefore
      no step climbed and no crate shoved;
    - the jump does not happen, so no `jumped` fires for a rule to
      answer;
    - last in the step, the body is held: nothing moves it across the
      floor or lifts it, whichever source asks (a knock, a rule's
      impulse, a pad, an updraft, a swing, its own Echo). Gravity still
      brings it down, as it does an anchored enemy;
    - a grind rail lets go, and none catches it;
    - a launch pad does not fire it;
    - `mass_class()` reads `FIXED`, and `lightened` reads `LIGHT`. The
      old docstring said "no Status moves it", and now says which two do
      and why that is a transient the route validator need not model;
    - `lightened` doubles `receive_knockback`.
  - **The Echo actions (`echo_runtime.gd`).** Nine primitives whose
    effect is the player's own movement (dash, air dash, double jump,
    wall kick, glide, blink, grapple to a surface, swing, hover) are
    refused while anchored. The refusal comes before the cooldown is
    charged, with "ANCHORED -- FIXED IN PLACE", instead of being paid for
    and stopped dead. Everything else fires.
  - **The enemy (`enemy.gd`).** `lightened` doubles an incoming knock.
    That is the whole of it an enemy can carry today: it has no mass
    class to drop a step, and nothing blows or conveys it.
  - **The object (`manipulable_body.gd`).** Anchored, a body is frozen in
    place, in the air included, with the STATIC freeze a PIN uses.
    - The freeze is one hold among several (pin, socket, weld, carry,
      bolt). The anchor freezes only a body nothing already holds,
      re-asserts that while it runs, and thaws only its own freeze.
    - `Manipulation.push` refuses an anchored body as `FIXED` (the verbs
      already did, by class).
    - `HandCarry` refuses it ("FIXED IN PLACE"), and lets go of one
      anchored in the hands.
  - **The pair (`status_effects.gd`).** Applying either removes the
    other, once the application is admitted: a refused `anchored` leaves
    a lightened body lightened.
- **Findings:**
  - **HS2-F1: a walk intent left on an anchored body lifts it every
    frame.** The first sabotage run caught 16 of 17
    (`H-STATUS-2_sabotages_first.log`). The miss was the anchored walk
    speed: without it, the anchored player pressing forward kept all the
    checks green.
    - A trace showed why (`H-STATUS-2_climb_trace.log`):
      the step the law promises lifted the body 0.5 m on every frame
      forward was held, 60 lifts in a second, and the floor snap pulled
      it back before the frame ended.
    - The residual is 3.5 mm, and a held body leaves none. The rule
      stays; the check now reads to the millimetre, and HS2-1 is caught.
  - **HS2-F2: two immunities were redundant, so they are gone.**
    - The player's knockback return: the hold overwrites the velocity
      every frame before anything moves.
    - The crate's impulse and force returns: measured with them removed
      (`H-STATUS-2_redundancy.log`), the STATIC freeze takes no impulse
      and keeps none to fire when it thaws, and a check now holds that
      ("an impulse landed while anchored is not released").
    - One mechanism each: the hold, and the freeze.
  - **HS2-F3 (my tests): four of the first run's failures were mine.**
    - Walking damps a knock and a dash within a few frames, so the free
      controls moved 0.42 m and 0.50 m, not the metre I had asked of
      them.
    - `push` takes a point to push toward, and I passed the crate's own.
    - Crates are not carriable by default.
    - An unheld enemy walks after a knock, which diluted the ×2 to ×1.4.
      Both enemies are now held by `rooted`, which is declared, forbids
      their own steps and still takes a knock.
- **The suite, `godot-status-kinetic`** (new, in CI; 35 checks,
  `H-STATUS-2_after.log`). The real player is driven through `Input`,
  with real enemies and crates on a real floor:
  - **An anchored player:**
    - walks 0.000 m where a free one walks 7.00;
    - jumps 0.000 m, with no `jumped`;
    - a knock (7, 3, 0) and an outside velocity (6, 12, 4) move it
      0.000 m;
    - it does not climb a step or shove a crate it presses into;
    - a launch pad does not fire it;
    - 3 m up, it still comes down.
  - **Its actions:** the dash refuses unpaid and says why. The shield
    fires, and a lever in reach is pulled.
  - **Its class:** a counting HEAVY plate is pressed while the player is
    anchored and released when the anchor ends, and the player walks
    again.
  - **A lightened player:** LIGHT, a knock of 4 m/s gives 8.00 m/s, and
    it walks and jumps unchanged. Anchoring removes the lightness and
    lightening removes the anchor.
  - **A lightened enemy**, held by `rooted` so the knock is all that
    moves it: it takes 16.0 m/s to a plain one's 8.0, and goes 0.62 m to
    0.31. To the verbs its mass is still unmodelled. The pair never
    coexists here either.
  - **An anchored object:**
    - it reads FIXED;
    - a 5 m/s impulse and a 3 kN push move it 0.000 m;
    - the verbs and the push refuse it, and the hands say why;
    - walked into, it gives 0.000 m;
    - anchored 3 m up, it hangs there, then thaws and falls.
  - **Among the other holds:**
    - a bolted crate stays frozen;
    - the pair on an object: anchored over lightened it is FIXED and
      frozen; lightened over that it is thawed, LIGHT, and moves 1.96 m
      to a plain crate's 0.68;
    - a HEAVY plate reads the crate's class as it is now;
    - a carried crate that is anchored is let go and stays where it was.
- **Also green on the final runtime** (`H-STATUS-2_suites.log`):
  `godot-status-family` (15), `godot-stats`, `godot-mass-class` (59), `godot-unweighted` (70), `godot-verb-runtime` (95), `godot-physics` (68), `godot-carry` (32), `godot-movement`, `godot-rules`, `godot-lab`, `godot-affordance`, `godot-rail-gantry` (41) and `godot-rail-junction` (140). No script errors.
- **Sabotages** (`H-STATUS-2_sabotages.log`), each restored byte for byte
  (sha256):

| # | Rule removed | Caught by |
|---|---|---|
| HS2-1 | the anchored walk keeps its intent (speed not zeroed) | "pressing forward: ... anchored, it climbs 0.0035 m" (HS2-F1) |
| HS2-2 | the anchored jump not blocked | "no `jumped` for a rule to answer" |
| HS2-3 | the hold removed | "a knock (7, 3, 0)" (+1) |
| HS2-4 | a grind rail keeps an anchored rider | "a grind rail ... lets go" |
| HS2-5 | a grind rail catches an anchored player | "a grind rail ... does not catch it again" |
| HS2-6 | a lightened player's knock not doubled | "the same knock (4 m/s)" |
| HS2-7 | the player's class ignores its Statuses | "its class drops a step" (3 in all) |
| HS2-8 | movement Echoes fire while anchored | "the dash refuses before it is paid for" |
| HS2-9 | the pair coexists | "anchoring it removes the lightness" (3 in all) |
| HS2-10 | the container ignores the table it holds | every as-declared case: "a second held forward" (23 in all) |
| HS2-11 | a lightened enemy's knock not doubled | "the same 8 m/s knock" |
| HS2-12 | an anchored object not frozen | "walked into for a second and a half" (6 in all) |
| HS2-13 | the anchor thaws a freeze it did not make | "a bolted crate anchored and released is still frozen" |
| HS2-14 | a push moves an anchored body | "so does a push" |
| HS2-15 | the hands pick up an anchored body | "the hands say" |
| HS2-16 | the hands keep a body anchored in them | "a carried crate anchored is let go" |
| HS2-17 | a launch pad fires an anchored player | "a launch pad fires the free player ... and not the anchored one" |

- **The sabotage runs:** 16 of 17 on the first run
  (`H-STATUS-2_sabotages_first.log`). The miss was HS2-F1, and its check
  now reads to the millimetre. All 17 were run again on the final suite:
  17 of 17 (`H-STATUS-2_sabotages.log`).

- **What stays open:**
  - **Dess's declaration (N-17).** Until it lands, nothing applies these
    four in play. When it does, `stats_driver` (the table pin at :589),
    `mass_class_driver` (`lightened` on self refused) and
    `unweighted_driver` (`anchored` on an object as the refused example)
    pin today's table and move with it. `godot-status-kinetic` switches
    to the real gate by itself.
  - **Delivery.** On-hit reaches only `Damageable` nodes, so no Echo can
    put a Status on an object or on the player through a hit. The player
    receives one through a rule's `apply_status` or a self-targeted
    `StatusComponent`. §12.5's `SELF_STATUS` (no roll, ends early on
    re-press) is not built.
  - **Not modelled:** wind and conveyors (there are none that push
    sideways), an enemy's mass class, and §15.8's feedback (the HUD
    sentence). What shows it is the stillness, and the refusal's words.
  - **Cleanse** leaves both alone. On the player, either may be the
    player's own build (§12.5: "`ANCHORED` on the player is immunity to
    every impulse in the room"), and the cleanse order's own rule is
    that it must never strip the player's buff. Both expire.
- **What the owner will notice:** nothing yet; no Echo delivers these
  four. When Dess declares them, a self-anchor holds you against every
  shove in the room, and an anchored crate stays put, in the air if that
  is where it was.

## 0.4 — D-10 (Dess's note; D-6 step 4): which arenas take the measured gantry — measured, and held as a gate

Dess's note D-10: "Please measure whether the gantry fits in the arena
sizes the composer can produce: the procedural maximum footprint at
`wall_height` 8.0, and the 24 m arena you found works, each with the
track crossing the room on the arrival axis, as the three-dock S1–S2–S3
layout would lay it. With the smallest size that fits, the composer
takes its room choice from your numbers, not from a guess."

- **What was measured** (`godot-gantry-census`, new):
  - the three-dock layout that `godot-rail-gantry` builds, run through
    the real `ZoneController`, with the arena at `wall_height` 8.0;
  - at each size, 168 layouts: 24 arena chamber ids × 7 chain shapes.
    - The props are seeded by the arena's chamber id.
    - The chain's shape is seeded by the zone id. A corner may turn the
      chain before the arena, after it, or both, the second turning
      back, and that gives seven shapes.
    - `0/0` is the track on the arrival axis, straight through: the case
      D-10 names. The other six are what the engine lays for other zone
      ids.
  - Whether a gantry stands is the engine's own answer
    (`RailNetworks.gantry_frame`).
- **The answer.** Each cell is the number of the 168 sampled layouts
  that take the gantry. · means not measured. In bold: all 168.

| width ↓ \ depth → | 16 | 18 | 20 | 22 | 24 | 26 | 28 |
|---|---|---|---|---|---|---|---|
| 16 | 58 | · | · | · | · | · | 137 |
| 18 | · | 62 | · | · | · | · | · |
| 20 | · | · | 125 | · | · | · | 166 |
| 22 | · | · | 150 | 166 | **168** | **168** | **168** |
| 24 | · | · | 157 | **168** | **168** | **168** | **168** |
| 26 | · | · | · | **168** | **168** | **168** | **168** |
| 28 | 144 | · | **168** | **168** | **168** | **168** | **168** |

  - **Width at least 24 m and depth at least 22 m: every sampled layout
    takes the gantry.**
    - That holds at every 2 m point of the range, and at two points off
      the grid (25.3 × 23.7 and 27.1 × 25.4).
    - That range is the landmark arena as the fallback composer rolls it
      (`epsilon/fallback.py`: width 24–28 m, depth 22–26 m), and it
      includes the procedural maximum, 28 × 28.
  - **The smallest square is 24 × 24.**
    - 22 × 22 refuses 2 layouts. Both are room c064, with the chain
      turned before the arena (`-90/0`, `-90/+90`).
    - In both, every position that passed the room, track and clearance
      tests was within the base kit's reach (62 and 105 of them).
      Nearest the arrival, a jump from a surface 2.6 m up (1.8 m in the
      other) lands on the deck.
    - 22 × 24 and 24 × 22 take all 168.
  - **On the arrival axis alone (`0/0`, D-10's case),** 22 × 22 takes
    all 24, as does every measured size with both spans at least 22 m.
  - **Below that:** a 20 m span refuses somewhere, except at 28 × 20. At
    16 × 16, 58 of 168 layouts take the gantry.
- **It is a sample and a grid, stated as one.** The claim covers 168
  layouts per size, at the sizes in the table. The fallback rolls to
  0.1 m, and a size between the measured points is not measured. What
  happens when a composed Zone refuses is D10-F1.
- **D10-F2 (my census): the Zone's `seed` field is not the layout's
  seed.**
  - The census's first version varied `seed` (7, 101, 2027) as the
    chain's axis, and its write-up said that three seeds give three
    track angles.
  - Checking that sentence found that nothing in the engine reads
    `seed`. The chain is seeded by `zone_id|theme`
    (`zone_builder.gd`), so every layout had been built three times,
    and every count it gave was a multiple of three
    (`D-10_census_vacuous_seeds.log`).
  - The turned chains had never been built. The rule the first census
    gave, "both spans at least 22 m", was wrong: with them built,
    22 × 22 refuses 2 of 168 and 20 × 28 refuses 2
    (`D-10_census_7shapes_first.log`, which fails that rule).
  - It was found before anything was committed. Its first sabotages
    (`D-10_sabotages_vacuous.log`) caught what they broke, and the
    sample they ran on was still a third of what it claimed.
  - **The census now reads each build's chain shape back from where the
    Zone put its rooms,** and fails if a zone id did not build the shape
    it is named for. Sabotage D10-4 is that mistake, remade.
- **The gate** (`godot-gantry-census`, in CI after `godot-rail-gantry`;
  `D-10_census.log`, 4 min 15 s):
  - 13 sizes × 168 layouts:
    - the landmark's range at every 2 m point;
    - the two points off the grid;
    - 28 × 28;
    - and the control, 16 × 16.
  - It fails if an arena at least 24 m wide and 22 m deep refuses any
    sampled layout (`GANTRY_ROOM_MIN_WIDTH`, `_DEPTH`: the composer's
    rule, which follow Dess's choice).
  - It fails if the control refuses none, since then the census cannot
    see a refusal. It refuses 110.
  - It fails if a zone id builds a chain shape other than its own.
  - `--census-sizes=24x22,26x22` measures any other sizes on request.
  - The boundary table above comes from two more runs:
    `D-10_census_7shapes_first.log` (squares and long arenas) and
    `D-10_boundary.log` (16 sizes around the edge, each refusing layout
    named).
- **Sabotages** (`D-10_sabotages.log`), each restored byte for byte
  (sha256):

| # | Rule broken | Caught by |
|---|---|---|
| D10-1 | the margins tripled (0.5 → 1.5 m) | "the composer's rule": 24 × 22 takes 145 of 168, and six sizes in all break it |
| D10-2 | the placement search three times coarser (1 → 3 m) | "the composer's rule": 24 × 22 takes 128, and seven sizes in all break it |
| D10-3 | a gantry that does not fit is left out and its control stands on the ground (a silent fallback) | "the control (16 x 16) refuses no layout: the census cannot see a refusal" |
| D10-4 | the census's zone ids all one (the D10-F2 mistake, remade) | "the sample did not build the chain shapes it names" |

  4 of 4. The runner is `D-10_sabotage_runner.py.txt`. The first census's
  two sabotages are kept (`D-10_sabotages_vacuous.log`): they were caught,
  on a sample a third the size it claimed.

- **The cost:** 89–106 ms per Zone build at the gated sizes, search
  included, and 61 ms at 16 × 16.
- **D10-F1, for Dess (N-18): a refused gantry is a silent, unsolvable
  Zone.**
  - Rail refusals are kept on the controller (`rail_refusals`), and are
    not in the `layout_result` the bridge judges.
  - Under D-4 that was safe, because a refusal could not be reached from
    a validated Zone: the schema refuses the non-consecutive span, which
    was the only case.
  - A gantry refusal can be reached. A schema-valid Zone whose room
    cannot hold one is built without its railway, and the Checks beyond
    a mandatory span cannot be reached.
  - The rule makes that rare in the sample. It cannot make it
    impossible. N-18 proposes the fix.
- **Evidence** (`post_playtest_evidence/`):
  - the gate as committed: `D-10_census.log`;
  - the boundary: `D-10_census_7shapes_first.log` and `D-10_boundary.log`;
  - D10-F2: `D-10_census_vacuous_first.log` (12 layouts),
    `D-10_census_vacuous_seeds.log` (72, a third of them distinct) and
    `D-10_sabotages_vacuous.log`;
  - the sabotages: `D-10_sabotages.log` and `D-10_sabotage_runner.py.txt`.
  - Each census log has the per-build `p3a:` shell-selection lines
    filtered out, and says how many. The two runs made by hand also have
    the make target's own filter applied.
- **What the owner will notice:** nothing yet. It is what lets the
  composer, D-6 step 4, put the Blindside gantry in a room the engine
  will build.

## CK5 checkpoint — the full frontier on `ccaac5c` (D-01, D-5, H-GRAPHS slice 1, D-9, H-STATUS slice 2, D-10)

- **On `ccaac5c` (D-10's head): 86 of 86 steps passed,** in two parts on
  that one revision (`CK5_frontier_on_ccaac5c.tsv`).
  - **Why two parts.** The container restarted during step 39
    (`godot-rail-gantry`), and that step's partial log was discarded.
    Steps 1–38 had passed (20:12–20:46 UTC). The tree was then
    restored: the five placement fixtures `godot-zone-audit` rewrites,
    whose changes were provenance stamps only, as at the end of CP4.
    Steps 39–86 then ran from a clean tree (20:47–21:50 UTC).
  - The steps are CP4's 82 and the four suites added since:
    - `godot-signal-verbs` (32 checks);
    - `godot-rail-gantry` (41);
    - `godot-gantry-census` (4 min 13 s);
    - `godot-status-kinetic` (35).
  - It covers every commit since CP4's frontier (`a2115b6`): Prod's
    D-01, D-5, H-GRAPHS slice 1, D-9, H-STATUS slice 2 and D-10, and
    Dess's G1, D-6 steps 1–2 and DESS-28.
  - `make test`: 2,299 passed (`CK5_make_test_on_ccaac5c.log`).
  - No log has a line starting `SCRIPT ERROR`. Every live suite passed,
    among them `godot-candidate-live` and both integrations.
  - These are local results; remote CI does not run (N-6).

## 0.4 — ML-F1/F2 (found by H-MACHINE-LIFE): enemies that left the world with nobody fighting them — repaired

- **How it was found.** H-MACHINE-LIFE's lifecycle run (next section)
  visits the candidate and Passing Zones five times each and does
  nothing in them but pull a lever and die twice. Its first run failed
  because rounds did not read alike: now and then an `enemy_defeated`
  was sent with nobody fighting.
  - Named, the deaths were `c006/melee#0` (the candidate's transit hall)
    and `c023/scuttler#1` (the passing Zone's last arena). Both ended at
    the fall-kill plane, outside every room.
  - CP1 had seen the first one (`PPT-02`, "observed, not investigated"),
    while it chased the player. It needs no player.
- **Why it matters.** A fall below `ENEMY_FALL_KILL_Y` counts as dead so
  that a `kill_all` stays satisfiable. The death is sent as
  `enemy_defeated`, D-06 keeps it, and the room's objective counts it.
  - `c006` is a `kill_all` room with one melee: a fall is a room cleared
    with nobody in it.
  - That is the fabricated clear D-06 rules out, reached by another road.
- **ML-F1: enemies built inside solids.**
  - The new suite's census of 23 distinct Zone fixtures (768 enemies)
    found 280 whose own collision box overlapped a static or rigid body
    when the Zone was built.
  - What they overlapped:
    - the room's warp station, which an arena's first ring spawn shares;
    - damageable crates;
    - cover boxes;
    - reward pedestals;
    - a shell's convex piece.
  - The physics pushes each out on its first step, which for most is a
    shove. The passing Zone's arena scuttler starts inside a prop, and
    down is the nearest way out, through its 0.5 m floor slab. It drops
    1.3 m in its first frame and falls in 7 of 8 builds
    (`ML-F_scuttler_frames.log`).
  - The spawner never asks where the room's other builders put things,
    and they never ask where the spawns are.
- **ML-F2: patrol beats over drops.** OV04 P07's patrol draws a beat at
  random anywhere within 4.5 m of the post, so a post near a drop draws
  some beats over it.
  - The transit hall's melee stands about a metre from the hall's drop.
  - It fell a second after the Zone was built on some visits and not
    others, depending on the draw.
- **What changed:**
  - **`EnemyFooting`** (new, `scripts/enemies/enemy_footing.gd`) says
    where a body may stand and how far it may walk, from the physics the
    room actually built.
    - To stand, a body's own box must overlap no static or rigid body,
      with floor within 3 m under it. The box is raised 0.15 m off the
      feet and trimmed 0.05 m at the head and sides.
    - A walk continues while every 0.5 m has floor within a stair's
      height (0.6 m) of the last, and no wall at knee height.
    - Its probes see through characters, since another enemy on a floor
      is not the floor's end.
  - **A footing pass at the end of `ZoneController.setup`,** after every
    room is built and before any physics step.
    - Each ground enemy is set down on the floor under it, where its
      first step would have landed it, and judged there.
    - One that does not stand is moved to the nearest spot that does, on
      rings out to 6 m, on the same floor, inside its room.
    - It moves 268 of the 768 fixture enemies, the farthest 6.0 m. Its
      moves and refusals are kept on the controller
      (`enemy_footing_moves`, `_refusals`).
  - **Reward pedestals are placed before they enter the tree.** A body
    moved after it enters is missing from that frame's physics queries.
    Before this, the pass left 16 enemies inside pedestals it could not
    see. The pedestal ends up in the same place either way.
  - **A patrol beat stops where the floor does.**
    - The direction is still drawn at random, so neighbours do not march
      in lockstep.
    - The beat is cut to the walkable reach from the post, and the walk
      from where the enemy now stands must keep to the floor too.
    - The draw goes round the compass. A beat under 1 m is none: the
      enemy stands its post and draws again.
  - **An idle walk stops at a ledge,** checked every 6 frames, on the
    floor, a metre ahead.
    - A patrol that meets one drops that beat.
    - A walk home that meets one takes up its post where it stands: an
      enemy that cannot walk back safely guards where it is.
    - Flyers are exempt.
  - **Unchanged: a chase.** An enemy the player lures off a ledge is the
    player's doing (PPT-02), and a chase runs through other code.
- **The suite, `godot-enemy-footing`** (new, in CI; 12 checks; about
  70 s). It judges with its own probes, not with `EnemyFooting`:
  - **every enemy stands:** 23 Zones and 768 enemies. None is inside a
    solid once set down, and every ground enemy has floor within 3 m
    under it;
  - **every move had a reason:** each enemy the pass moved stood inside
    something where it would have landed;
  - **none falls idle:** the passing and candidate Zones built three
    times each and watched for 4 s, with the player out of every enemy's
    notice. No enemy drops 2 m, and no `enemy_defeated` is sent;
  - **patrol beats keep to the floor.** 24 seeded draws per patroller
    from the post, and 24 from the end of a previous beat: 192 + 170 in
    the candidate, 408 + 363 in the passing Zone. None crosses a ledge
    (no floor within 2 m below the last 0.25 m sample, or a climb of
    more than 0.6 m). Stepping off a cover wedge's back (1.2 m at most)
    is terrain; the product's own rule is stricter;
  - **an idle walk stops at a ledge.** On a built 6 m slab, a melee
    walking home to a post 5 m past the edge stops 2.08 m out and takes
    up a post on the slab.
- **Reproduced first:** the final suite on the unchanged runtime of
  `574714c` (`ML-F_before.log`) fails 6 of 12:
  - 280 enemies inside a solid;
  - the passing scuttler drops in all 3 builds, sending a defeat each
    time;
  - 37 and 77 beats cross a ledge;
  - the melee walks off the slab.
  - **Probabilistic on the unchanged runtime:** the candidate's idle
    check passed there. Its melee dropped in 1 of 3 builds in an earlier
    run (`ML-F_before_first.log`) and 0 of 3 in this one, because the
    fall depends on the patrol's draw. The seeded beat check is the
    deterministic guard: it flags that melee's beats over the hall's
    edge every time.
- **Findings in my own suite, each measured before it was changed:**
  - a census threshold I wrote from a census that counted duplicate
    fixtures;
  - a check that asked the re-posted melee to stay within 1 m of its new
    post while it patrolled from it;
  - a gap probe that read another enemy as missing floor, and a 0.6 m
    step rule stricter than the danger. It flagged a cover wedge's back
    edge (`ML-F_wedge_paths.log`);
  - two ceiling grazes: a 1.40 m enemy under a 1.42 m balcony, and a
    1.60 m one under 1.62 m (`ML-F_ceilings.log`). The pass moved them,
    and the test called the moves needless. Both now trim the head by
    5 cm.
- **18 enemy-heavy suites on the repaired runtime, before the commit**
  (`ML-F_regression_suites.tsv`). 17 passed first time, among them:
  - `godot-combat-fairness`, `godot-counterfire-hosted`,
    `godot-passing-hosted`, `godot-resume`, both integrations;
  - the live `godot-resume-live` and `godot-candidate-live`.
- **One failed, and the test was wrong: `godot-encounter`'s flyer
  case.**
  - It checked that at least one flyer was "off the floor" by its
    pivot's height. PT-12 keeps a flyer's pivot on the floor and hangs
    its body at hover height, so the pivot says nothing about reach.
  - It had passed only because of ML-F1. The drifter was built inside
    the room's warp station and held station on its roof: pivot 2.03 m
    up, hover floor 2.6 m (`ML-F_encounter_flyers_before.log`). Stood
    clear of the station, its pivot is on the floor.
  - The check now reads the body above the floor under it, by its own
    ray past actors: 2.61 m and 1.96 m. Both runtimes pass it: the
    unchanged one's drifter is 1.98 m above the station roof. The rest
    of the case, the room finished from the ground with the player
    alive, is unchanged (`ML-F_encounter_after.log`, 51 checks).
- **Sabotages** (`ML-F_sabotages.log`), each restored byte for byte:

| # | Rule broken | Caught by |
|---|---|---|
| MLF-1 | the footing pass never runs | "no enemy is built inside a solid" (280), and the scuttler falls |
| MLF-2 | the fit test does not see solids | "no enemy is built inside a solid" |
| MLF-3 | a reward pedestal moved after it enters the tree | "no enemy is built inside a solid" (the pedestals) |
| MLF-4 | judged where it was placed, not where it lands | "every enemy the pass moved stood inside something" |
| MLF-9 | a head grazing a ceiling counted as inside | "every enemy the pass moved stood inside something" |
| MLF-5 | a patrol beat drawn at random again | "every beat's path from the post keeps to the floor" |
| MLF-6 | the walk from where it stands not checked | "every beat's path ... keeps to the floor" (a beat drawn from a previous one) |
| MLF-7 | the ledge guard off | "it stops on the slab" |
| MLF-8 | a walk home that meets a ledge keeps its old post | "takes up a post on the slab" |

  9 of 9 (`ML-F_sabotage_runner.py.txt`). The first run caught 7 of 8
  (`ML-F_sabotages_first.log`). MLF-4 was missed there because the
  suite did not look for needless moves; that check was added, and
  MLF-9 with it.

- **What the owner will notice:**
  - Enemies stay in their rooms until you fight them.
  - A room's `kill_all` is cleared by you, not by gravity.
  - Some enemies stand a few metres from where they used to, off a
    station, crate or pedestal they had been built inside.

## 0.4 — H-MACHINE-LIFE, slice 1: repeated lifecycles accrue nothing — measured

`05_INHERITED` O05-10.4 is PARTIAL: "Two-arcade isolation done; repeated
lifecycle counters remain." PROD_OV05 left it as: "counters or resources
do not accrue repeated effects after several enter/leave/restart cycles
has no dedicated measurement ... no counter is read across cycles."

- **The measurement, `godot-machine-life`** (new, in CI; 41 checks;
  2 min 45 s).
  - **Through the real `Main`, beside it,** as the reload proof runs.
    What outlives a Zone is `Main`'s:
    - the HUD, the minimap, the map and journal faces;
    - the rule runtime, the resource pool and the tones;
    - the `BridgeClient` autoload.

    So a cycle is `Main`'s own `_to_zone`, then the pause menu's return
    to the Hub (`_on_return_to_hub`), with the Zone record a bridge would
    serve set on `BridgeClient.snapshot`.
  - **A round:** the Hub, then the played candidate Zone, then the
    Passing Platforms Zone, then the Hub. Between them they hold every
    occurrence this line has built:
    - the reversible doorway;
    - the carried power cell and its consumer;
    - c009's latched route;
    - the Unweighted Switch and the Counterfire Arcade;
    - EX50-011's carriers.
  - **The first round enters fresh.** The later four re-enter with what a
    save carries: a state variable, and the arcade's and c009's latches.
    That is the restore path a restart takes.
  - **In each Zone:** every zone-state lever is pulled once, then the
    player dies and comes back twice. The deaths are the in-Zone restart,
    and the minors' death rules run on them.
  - **Read at the same point every time,** at the Hub after each round and
    in each Zone after its operations:
    - the engine's counts of nodes, orphan nodes, objects and resources;
    - every signal connection on `BridgeClient`, and in and out of each
      of `Main`'s long-lived nodes;
    - `Main`'s in-memory progress per Zone;
    - group membership over the whole tree, and running tweens;
    - the builders' static caches.

    That is 50 counters at the Hub, 59 in the candidate and 58 in the
    passing Zone.
- **The result, on the repaired runtime** (`H-MACHINE-LIFE_after.log`):
  - **Rounds 2–5 read what round 2 read, at the Hub and in both Zones.**
    Nothing accrues across four restored lifecycles.
  - The fresh round fills the caches, and they stay filled: theme
    materials 4 → 10, packs 4 → 10, textures 0 → 2, enemy tones 0 → 1.
    The Hub holds 578 nodes after every round.
  - Every round, one lever pull sends one `zone_state_selected`, two
    deaths make two respawns and two logged deaths, and a round sends
    what round 2 sent (the candidate 4 intents, the passing Zone 7).
  - **`objects` is the one counter read with slack (24).** The engine's
    object count moves by up to 8 between identical rounds: short-lived
    RefCounted objects such as query parameters and timers. The exact
    counters are what catch a node, connection, orphan or group leak.
- **Reproduced first: it failed, and not for an accrual**
  (`H-MACHINE-LIFE_first.log`). Rounds did not read alike, because
  `enemy_defeated` was sent now and then with nobody fighting.
  - The suite's named-death diagnostic found two enemies that had fallen
    out of the world: `c006/melee#0` and `c023/scuttler#1`
    (`H-MACHINE-LIFE_named_deaths.log`).
  - That is ML-F1/F2 (next section), repaired before this measurement
    could land. It is also why the suite keeps naming every enemy death
    and every enemy that leaves its room: a round that is not the same
    for a reason outside the counters says so.
- **Its own mistakes, before it counted:**
  - a `Textures` class that is `ProcTextures`;
  - a loop variable that shadowed `round()`;
  - the `objects` slack, set at 12 from one run and raised to 24 when
    the next run moved by 8.
- **What stays open in H-MACHINE-LIFE:**
  - power loss and restoration: no occurrence built so far has a power
    source, a `HAZARD_CONTROLLER` or a `LIGHT_CONTROLLER`;
  - O05-10.2's constrained assembly, and weld/assembly scope;
  - occupied, reversing and reset on a powered machine.

  All three need a real powered or constrained occurrence, and none
  exists yet.
- **What the owner will notice:** nothing. It is evidence that entering,
  leaving and dying do not leave anything behind.

## CK6 checkpoint — the full frontier on `d4fc7fe` (ML-F1/F2, H-MACHINE-LIFE slice 1)

- **On `d4fc7fe` (the ML-F and H-MACHINE-LIFE head): 88 of 88 steps
  passed,** in one run on that one revision, 00:15–01:52 UTC
  (`CK6_frontier_on_d4fc7fe.tsv`).
  - The steps are CK5's 86 and the two suites added since:
    - `godot-enemy-footing` (12 checks);
    - `godot-machine-life` (41).
  - It covers every commit since CK5's revision (`ccaac5c`): the CK5
    record and ML-F1/F2 with H-MACHINE-LIFE slice 1. Dess pushed nothing
    in between.
  - `make test`: 2,299 passed (`CK6_make_test_on_d4fc7fe.log`).
  - No log has a line starting `SCRIPT ERROR`. Seven logs contain the
    words, all in the Makefile's own echoed recipe (the `grep "SCRIPT
    ERROR"` gates of the live targets), none from the engine. Every live
    suite passed, among them `godot-candidate-live`,
    `godot-resume-live` and both integrations.
  - `godot-zone-audit` (step 22) rewrites the five placement fixtures,
    provenance stamps only, as at every checkpoint. They were restored
    after step 41, while the run continued; nothing after step 22 reads
    them.
  - These are local results; remote CI does not run (N-6).

## 0.4 — H-RAIL-BREADTH, slice 1: a railway with points in it — landed, runtime-only

`13_WORK_QUEUE` H-RAIL-BREADTH, "Switchable rail network and safe recall":
"Physical branch selection and occupied-switch/recall/restoration. Actual
track changes; no teleport across uncommissioned link." `05_INHERITED`
O05-16.2 was NOT STARTED. OV04 P17.2–P17.4 say what it has to do. DESS-01
splits the work: items 1–2 are the engine (a carrier that runs a graph, a
switch whose position selects the live track); items 3–5 are the bridge.
This slice is the engine half, built and measured on declaration-shaped
networks. **No Zone declares a switch yet**, so nothing here is a composed
occurrence (P17.5), and nothing is promoted into generation.

- **What landed.**
  - **`RailNetworkCarrier`** (a subclass: `RailCarrier`, the ordered
    route, is unchanged, and Blindside, EX50-011 and D-4 ride it as
    before). The network is laid from its declaration: docks, spans, and
    switches `{switch_id, dock_id, legs, leg}`.
    - It is laid as **lines**: one `RailPath` each, the longest runs with
      no turnout in them, meeting at **points**. The carrier changes line
      only at the points, where the lines share a position and a
      direction, so the change is not a jump.
    - **The points stand 11 m beyond the fork dock, toward the legs.**
      §21.6 queues a throw while the rail within 10 m is occupied. Points
      at a dock would be held by every carrier parked there, and nobody
      could choose a branch from the fork. The layout therefore refuses a
      dock inside the clearance, by name.
    - **Refused by name:** a loop or a detached dock; track dividing at a
      dock with no switch; a switch with one leg; a heel arriving from
      beyond the legs; a dock inside the points' clearance.
    - **Commissioning stays with the link.** An edge's own stretch is
      where its span stands. On a leg, that is beyond the points, so
      aligning one leg never lays the other. A journey over missing track
      is refused at the dock, naming the span, and nothing moves.
  - **`RailPoints`: the switch is §21.6's own `RAIL_SWITCH` actuator.**
    Its path is the tongue's pose for each leg, so a throw moves track.
    The tongue swings for 2.0 s, and a leg joins the heel only once the
    tongue has locked on it (`Actuator.settled_branch`).
  - **Recall, `call_to(dock)`.** It plans the route over commissioned
    track, sets each set of points it needs, and waits for them to lock.
    It reverses at a dock where the route turns back through a turnout.
    - Its state is always one of refused, queued, executing, completed
      or cancelled (P15.3).
    - A call while the carrier moves is refused, as EX50-011 §8 says: no
      queued arrivals.
    - A hand that throws the points while a call waits cancels the call.
      The call does not fight a lever.
  - **Levers:** a CALL lever at every dock and a POINTS lever at every
    fork, worked by `interact` (`CallLever`, EX50-011's, reused).
  - **Holds.**
    - Power loss holds the carrier and keeps its journey, and the points
      it is committed to stay locked through the outage.
    - The fail-safe stop ends the journey. A carrier stranded by it can
      still be commanded or called.
  - **Restore.** `restore_points` puts each tongue on its saved leg, and
    `park` puts the carrier at the declared home. Neither reports
    anything. A restore is not a throw or a journey.
- **Findings.** Three are defects in code that already existed. The
  other two were found by building this.
  - **RB-F1: §21.6's rule as written measures distance only.** A
    carrier dispatched toward the points from farther than 10 m is not
    "within" the clearance yet, so a throw at that moment applies, and
    the carrier meets it at speed.
    - **Reproduction:** the suite's control runs with the lock off. The
      same throw applies at once, and the carrier stops dead on the
      points, 0.20 m from them.
    - Without the crossing check as well (sabotage RB-2), it carries on
      along the leg it planned while the tongue is set for the other.
      P17.2 names exactly that: the carrier following the old path.
    - **Repair:** a route lock (`Actuator.lock_route`). A journey holds
      each set of points it will pass from dispatch until it is 10 m
      beyond them. A throw meanwhile is queued, never dropped.
  - **RB-F2: an actuator reset moved a `RAIL_SWITCH` under whatever was
    on it.** The reset row drove the tongue to `initial_t` regardless of
    §21.6, and left `branch()` naming the leg the tongue had just left.
    - **Reproduction:** sabotage RB-6 restores the reset as it was, and
      the RB-F2 case fails.
    - **Repair:** a switch's reset asks for its initial branch like any
      other throw: applied at once when the rail is clear, queued when
      it is not.
    - Nothing resets a rail switch in play yet. These points are the
      actuator's first real consumer.
  - **RB-F3: the ordered carrier drove with no power.** `power(false)`
    holds it and keeps its errand. A command during the outage fell
    through to the stranded branch, set a new errand, and `advance`
    drove the carrier until power returned and overwrote the errand.
    - **Reproduction:** sabotage RB-7, the request as it was.
    - **Repair:** an unpowered carrier refuses the command, saying why.
      The network carrier does the same.
    - No occurrence has a power source yet, so no player could have met
      this.
  - **RB-F4, open, for slice 2: a declared railway (D-4) builds nothing
    a player can command it with.** `RailNetworks` builds the carrier,
    the spans and their levers, but no receiver and no call lever.
    `godot-rail-zone` says as much ("no Zone here is played").
    - Nothing composes a railway into a played Zone today, so no player
      has met it.
    - The first composed one could not be ridden. Slice 2 builds CALL
      levers for every declared railway, as the network builder already
      does.
  - **RB-F5: `RailPath` refused a flat rail as a 90-degree pitch.** The
    baked length is a single-precision sum, so a straight 31 m rail
    reads a hair over 31. `polyline()`'s `ceil` then took one step more
    than there is, and the last two samples were both the end: a segment
    of no length, which `violations()` reads as vertical.
    - Found when the two-switch network's 31 m heel line was refused.
    - It could refuse a D-4 linear railway the same way.
    - **Reproduction:** sabotage RB-15, the sampler as it was, over 201
      level rails from 30 to 32 m.
    - **Repair:** a last step shorter than a thousandth of a step is
      rounding, not track, and is not taken. Any longer last step is
      kept, as before.
  - **Two defects in the new code, found and fixed before the commit.**
    - **The legs first left the points through a shared lead point.**
      Uniform Catmull-Rom over a 2 m span beside a 19 m one overshoots:
      the suite measured a 61-degree turn in a leg's first 0.2 m.
      - Clamped end tangents then gave 3.5 degrees in 0.1 m, a 1.6 m
        radius. Measured offline first, in a Python model of the curve
        that reproduced Godot's figure.
      - Now `RailPath.from_points` takes an optional end direction
        (every existing rail passes none), and a leg leaves its points
        along the heel with a handle a third of its span: 0.63 degrees
        across the points.
    - **Where two lines meet head to head at a set of points, their own
      directions are opposite.** A line that is a leg at both ends, or
      two heels, meet this way. A deck that faced its line would turn
      half a circle in one frame there, and `sync_to_physics` would hand
      that turn to its passengers.
      - The deck's facing now carries across a change of line.
      - The two-switch network holds it (sabotage RB-14).
- **`godot-rail-network`** (new, in CI; 70 checks; 24 s). It is
  hand-stepped, like `godot-rail-carrier`. Every journey is held to at
  most 0.175 m moved in a frame (no teleport), and at most 3.0 degrees
  of deck turn in a frame.
  - **Branch selection.** A throw from the fork applies at once, and the
    tongue swings 55 degrees and locks. Until it locks, FORWARD is
    refused and nothing moves. Then the carrier runs to the new leg and
    stands on its track.
  - **Points set against.** A carrier on the leg the points are not set
    for is refused ("set for A1, not for this track"). It is not routed
    onto the other leg.
  - **The route lock (§21.6 with RB-F1).**
    - A committed throw is queued, and applies once the carrier is
      clear.
    - Past the points, distance alone holds them.
    - The control with the lock off is stopped dead on the points.
  - **Conflicts.** FORWARD and BACK at once do neither. A hand on the
    lever cancels a waiting call.
  - **An unavailable link.**
    - Its leg is refused, naming the span, and so is a call beyond it.
    - The other leg still runs.
    - A span locking home through the junction commissions exactly that
      edge and reports its latch once.
  - **Recall on the Y.** Every dock calls the carrier from every other
    dock: 20 of 20 arrive.
    - From B1 to A2, on the other branch, the carrier stops only at S,
      where the route turns back, and runs through A1 without stopping.
    - The call reports its states in order: executing, queued,
      executing, completed.
  - **Two switches whose legs meet.** 42 of 42 calls arrive. T1 to T2
    crosses both sets of points in one run, and the deck turns at most
    1.72 degrees in a frame.
  - **Holds and power.**
    - Power lost 6 m short of the points: the carrier holds and the
      points stay locked. A command is refused, and on power it carries
      on to the leg it left for.
    - A fail-safe stop past the points, then the points thrown behind
      it: going back is refused until they are set back.
    - A stranded carrier can still be called home.
  - **RB-F2, RB-F3, RB-F5** each have a direct case.
  - **Restore.** The points come back on their leg and the carrier at the
    declared home, not dock 0, with nothing reported, and the restored
    network runs.
  - **The ordered route is a case of the network.** A four-dock chain on
    both carriers stops at the same docks, at the same offsets (largest
    difference 0.00000 m), in the same frames.
  - **Levers.** Pulling a CALL lever calls the carrier, and pulling the
    POINTS lever throws the points.
- **15 of 15 sabotages caught,** each file restored byte for byte
  (`H-RAIL-BREADTH_sabotages.log`). RB-6, RB-7 and RB-15 put the old code
  back and are the reproductions of RB-F2, RB-F3 and RB-F5.
  - RB-11, the points at the fork dock, also raised script errors: the
    suite indexes the points of a layout that was refused. The named
    check catches it first.
- **Regression:** **all green on the landed runtime**
  (`H-RAIL-BREADTH_regression_suites.tsv`): the suites that share what
  changed.
  - The actuator, the ordered carrier, the junction and `RailPath`:
    `godot-actuator` (93), `godot-rail-carrier` (73),
    `godot-rail-junction` (140, its re-park now through `park_at`),
    `godot-rail-zone` (25) and `godot-rail-gantry` (41).
  - EX50-011's carriers: `godot-passing-platforms` (70) and
    `godot-passing-hosted` (24).
  - `godot-movement` and `godot-affordance`, which read the rail sweep.
  - `godot-signal-graph` (61), `godot-signal-verbs` (32),
    `godot-constraints` (67) and `godot-counterfire` (59).
  - `godot-gantry-census`: every count as at CK6; only its timing column
    differs.
  - `godot-machine-life` (41) and `godot-candidate-live`, every phase.
  - `test_ci_coverage`, 3 passed.

  No log has a line starting `SCRIPT ERROR`.
- **What this does not do yet (slice 2, after Dess's half, N-19):**
  - no Zone declares a switch, and `RailNetworks` does not build one;
  - the setting and the carrier's dock are not saved through the bridge
    (P17.4's engine API exists; the Zone-state field is Dess's item 3);
  - reachability over switch position (item 4);
  - the relaxed validator (item 5);
  - RB-F4's call levers on declared railways;
  - a composed, played junction occurrence (P17.5).
- **What the owner will notice:** nothing yet. It is the machine a
  switchable railway needs, waiting for a Zone that asks for one.
