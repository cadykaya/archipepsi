# Archipepsi autonomous frontier

This file is the cheap wake-up state. Keep it short and current. Use `NEXT_STEPS.md` for the detailed project/history handoff and the v0.8 packet for authoritative contract details.

## THE ACTIVE FRONTIER: v0.9 — production and the authored-content transition

**`docs/design-packet-v0.9/IMPLEMENTATION_PLAN.md` is what wake-ups
execute.** S1–S10 (Echoes 2.0) are complete and are history below; the
plan is NOT exhausted.

The governing rule, from `docs/design-packet-v0.8/AUTHORED_CONTENT.md`
(normative, outranks the v0.9 plan): **developers author the alphabet, Godot
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
| S22 packaging/first-run | **done** — `make doctor`, secrets tests |
| S20 campaign spine | **hooks built; BLOCKED on Q3** (narrative) |
| S23 release hardening | **done** — `AUTOMATION_LIMITS.md` |

S22 added `make doctor` (a fresh-clone preflight that separates
REQUIRED from optional — no API key is reported as fine, because the
fallback provider is what a player without one plays) and the secrets
tests: no tracked file may contain a key-shaped string, `.env` must be
ignored AND git must agree, and no third-party binary may be tracked
without a licensing decision (Q2).

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

**Heartbeat behaviour: STOP. Every independently implementable stage is
done, and the owner's 2026-08-28 decisions
(`docs/design-packet-v0.9/OWNER_DECISIONS.md`) closed Q1, Q2 and Q3.**

Implemented since: the ending and postgame (D3), authored-shell semantic
authority with Godot measuring physical truth (D1), the asset licence
gate and notices (D2), the tier presentation arc (D4), visual layer
ownership (D6), and the art-lane review gate.

What remains needs a person, not more iteration
(`AUTOMATION_LIMITS.md`):

1. **Authored art** — the art lane is in STYLE LOCK 001-R and its assets
   are NOT approved. A file existing in the tree is not permission:
   `review: pending` entries are refused by the instantiator, and only
   `pass` ships. Do not recreate the art lane's work or choose between
   pending variants.
2. **Final writing** — the completion beat and postgame lines are
   placeholders in the established voice and say so in the source. D3
   fixed the structure and left the words open.
3. **Human playtesting** — every statable invariant has a test. Whether
   the game is GOOD is not among them. **Playtest 1 ran 2026-08-28 and
   ended at the title screen**: MOCK CAMPAIGN crashed on a null `world`,
   the menu panel sat in the bottom-right corner with QUIT off the edge,
   and the Output panel scrolled 81 warnings. All fixed; see below.
4. **`challenge_marker`** — deliberately deferred. The hook stays
   dormant and is not removed; a test refuses anything depending on it.
5. **Project code licensing** — separate from asset intake, and not
   decided.

## What playtest 2 taught

The game is playable end to end: Hub, portal, Zone, Checks claimed, a
Check sent to another slot. Everything below was found by a human in
about an hour, and every one of them had a green suite over it.

The pattern, stated once because it recurred all day: **these bugs are
correct as state, as geometry and as protocol, and wrong on screen.**
A backwards sign, a panel whose rect is off-screen, a room with no
ceiling, a fixture inside a slab — the bounds Dictionary is right, the
socket is in the right place, the snapshot validates. Nothing that
asserted on data could see any of it. What found them was standing
somewhere and looking, so the suites now do that: `godot-legible` builds
the Hub and reads its walls, `godot-boot` opens each panel and measures
it, `godot-test` stands inside each chamber and fires rays outward.

Three traps worth remembering, each caught by sabotage rather than by
review:

- A per-site fix leaves the others. `PRESET_CENTER` was wrong in SIX
  places; fixing the title screen for playtest 1 left five.
- A suite can pass on borrowed geometry. Every chamber was built at the
  origin, so they overlapped, and deleting `platform_path`'s ceiling
  failed the ARENA. Isolate before asserting.
- Fixing one half by breaking the other. Seeding the fallback per-run
  ends the sameness AND ends reproducibility; both halves are pinned.

**The fallback provider is the offline fixture.** It is what a player
with no `ANTHROPIC_API_KEY` gets, it is what the integration run plays,
and it was one hardcoded room list — so four Zones in a row were the same
Zone. It now varies deterministically by zone index. Real variety is the
Claude provider composing from the vocabulary; this is only about making
a keyless campaign bearable.

**Zone LENGTH: decided, implemented, NOT yet proven.** The owner's
CAMPAIGN SCALE brief (2026-08-28) answered the pacing question and
`docs/design-packet-v0.9/CAMPAIGN_SCALE.md` is the normative spec.
Defaults: `location_count: 450`, `zone_target_checks: 15`,
`zone_budget: 1000`, all exposed in YAML over bounded ranges
(30..600 / 1..30 / 200..2000). Every stage CS0-CS10 is implemented.

Read `CAMPAIGN_SCALE.md` before touching any of it. The three rules that
are load bearing and easy to break:

- **Epsilon does not declare its own score.** The engine computes
  `room_value` from what a room contains (`bridge/.../content_value.py`).
  A provider claiming a number is a provider grading its own homework.
- **Checks do not count as content.** `CHECK_VALUE = 0`. A Zone's length
  comes from what is in it, so the budget buys ROOMS, and a Zone with one
  Check and a thousand points is a long level rather than one big room.
- **Per-campaign config is truth, and the SAVE wins.** A run keeps the
  scale it was created with. A seed with no `campaign_scale` is a
  PROTOTYPE campaign (30 locations), never the current default —
  reinterpreting it would strand every Check it has.

## ART INTEGRATION — five engine contracts landed 2026-08-28

`docs/ART_INTEGRATION.md` is the index of every engine contract the art
lane consumes. Read it before touching anything the art branch depends
on. Summary of what is now unblocked, and what is not:

| Art req | Contract | State |
|---|---|---|
| 7 | `ENEMY_ENVELOPES` — ten roles, named fields, floor/flying explicit | **cleared** |
| 14 | `telegraph_started/finished`, `TelegraphOrigin`, `telegraph_progress()` | **cleared for the brute** |
| 15 | `AFFORDANCE_SIGNAL` — one identity for all seven affordances | **cleared** |
| 16 | `rail_ride_path()` / `build_rail_along()` — one authoritative polyline | **cleared** |
| 4 | `HubAnchors.epsilon_bay()` / `intruders()` — the bay is reserved | **cleared** |
| 19 | Enclosed by default; the tower is in the seal suite now | **cleared** |
| 20 | Two hazard-orange navigation markers removed, budget pinned at 2 | **cleared** |
| 3a | `ContentInstantiator.light_housing(theme)` | **cleared** |
| 5 | `ClusterFootprint` + `cluster_placement_errors()`, registry-enforced | **cleared** |
| Tier 7 | `shells.shell_catalog()` → request → validator → instantiator | **cleared** |
| 13 | `ProjectileSilhouette` — straight / falling / lobbed, by SHAPE | **cleared** |
| 11 | `RewardObject.state_profile()` — LOCKED and CONFIRMED are different FORMS | **cleared** |

**Three things they exposed, each worth remembering:**

- **`scale` on a CharacterBody3D scales its collider.** The brute's
  windup grew its own hitbox 12% and the hit flinch shrank it to 88%.
  Presentation now lives under a `Visual` container and structurally
  cannot move a collider.
- **The room-shell chain had three broken links and every link's own
  test passed.** `shell_id` was carried, validated and ignored, and
  nothing ever populated `legal_shell_ids`. A contract nothing connects
  is not a contract.
- **`make godot-<suite>` printing "TESTS OK" does not mean it passed.**
  The Makefile guards also fail on a raised runtime error. Sweep by EXIT
  CODE; a grep for the OK line hid a red suite for two commits.

**Two more, landed 2026-08-29, and both are the same lesson:** a state
the engine knows and the player cannot see is not a state the player has.

- **Requirement 13.** One primitive family flies three ways and looked
  one way — a sphere, scaled 1.5x for a lob. Now `straight`, `falling`
  and `lobbed` are different SHAPES, selected from the shot's own flight
  fields, because colour is not available: an Echo is tinted by the
  source world whose item it reinterprets, so spending hue on behaviour
  would overwrite identity with mechanics and lose both. `blast_radius`
  is tested before `gravity_scale` — a lob is also fully gravity-affected
  and would otherwise read as a falling bolt.
- **Requirement 11.** LOCKED and CONFIRMED were two greys eight percent
  of a shade apart plus a word, and a word is unreadable across a room.
  Now they are an open cradle and a collapsed spent mass. **The invariant
  is NOT that the destination ring exists** — it is that the forms
  differ, measured from geometry, with every state repainted one flat
  colour to prove the material is not what is talking.

Both intake seams exist and **no art-lane meshes were copied.** Register
a `projectile_visual`, or author a cradle, and it is used with no code
change.

**Still blocked, and none of it is engineering's:** telegraphs for melee
and ranged (they have no windup, and adding one changes difficulty —
combat decision); behaviour for the seven enveloped roles (same);
`arch_affordance_socket` (art has not chosen between a visible mount and
floor placement); neutral `concrete_facility` dressing (req 18);
`objective_marker` / `signage_module` navigation language;
`challenge_marker`.

## ECHO SCALE — the log outgrew its consumers, 2026-08-29

Same shape as CS8b, third time now: **the campaign scaled and a consumer
did not.** The interpretation log is complete local truth and stays
complete — nothing here truncates it, discards from it, or changes the
fold. What changed is who is handed all of it.

| Consumer | Was | Now |
|---|---|---|
| `PlayerContext.echoes` (Zone request) | every interpretation ever made | ≤12 examples + a whole-history aggregate |
| `EchoGenerationRequest.existing_echoes` | same, separately | the same projection, same code path |
| `CampaignSnapshot.interpretations` | whole log on every state change | only when it changed |

**The provider view is in `bridge/archipepsi_bridge/echo_projection.py`,
and it is the only one.** Three parts, all deterministic: the complete
folded capability set, an `accumulated_influence` aggregate counted over
the WHOLE log (top-N source games, recurring concepts, tags,
interpretation modes — bounded by the top-N, not by a window), and ≤12
detail examples chosen as the six most recent plus an evenly spaced walk
back through everything before them. The examples are FLAVOUR. Nothing
mechanical is read from them, so a Zone 28 request still knows about a
Zone 2 capability and a Zone 2 influence, which is the point: accumulated
world influence is intentional and a detail window would have thrown it
away. Both provider paths call `history_view()`; there is no second one
to forget. Measured at 449 Echoes: **89,585 → 3,520 characters**
(~22,400 → ~880 tokens), and 20× more history costs 18 characters.

**`derive()` is still not cached, and now says why with numbers.** The
old justification was "the log is at most 30 entries", true of the
prototype and false of a 450-location campaign. Measured: ~8 µs per
interpretation, linear — 0.2 ms at 30, 3.5 ms at 449, 5.0 ms at 600, on
an event-driven path that runs per intent, inside a message that spends
more than that on serialisation. A cache would be a second truth for the
one thing that has to be identical everywhere, bought for nothing.

**Snapshots stop re-sending the lifetime log.** `broadcast_snapshot()`
omits `interpretations` and sets `interpretations_complete: false` when
the log has not changed; the client puts its cached copy back before
anything reads the snapshot, so every consumer still just reads
`interpretations`. Back-compat is the DEFAULT: the flag defaults true, an
elided log is sent empty (never partial — the model refuses), and connect
and `hello` always answer complete, which is the whole correctness
argument. A real 30-Check campaign elides 74 times and the log arrives
gapless.

Two things worth carrying forward:

- **`mechanics` is now the big field, deliberately.** It is 97% of an
  elided late snapshot (~268 KB at 449). It is current derived state
  rather than history, and `CampaignSnapshot` validates `slots` against
  the `mechanics` it is sending — a v0.6 guard that eliding would switch
  off. Eliding it is a real option later; `TestTheFoldIsStillSentWhole`
  records the cost so the choice stays visible.
- **A test that only reads the end state cannot see this bug.** The first
  Godot sabotage — client never reattaches — PASSED, because the last
  snapshot before the driver's assertion happened to carry the log. The
  archive looks short only while it is short. `BridgeClient` now watches
  every snapshot for a log that went backwards within one campaign.

## PLAYTEST 2.5 — the pre-art baseline, ready 2026-08-29

`docs/PLAYTEST_BASELINE.md` is the operator's page: what to run, what it
measures, and the one instruction that matters — **change nothing to
make the numbers better.**

The comparison after authored art is about art only if everything else
held still, so the baseline's job is to hold everything else still and
be loud when it does not. `docs/baselines/playtest_2_5.json` records
three consecutive Zones (request and accepted output, verbatim), four
Echoes, and the campaign scale they were taken at; `make baseline`
regenerates it from source and it is never hand-edited.

Four tripwires, each sabotage-proven:

- the committed baseline no longer matches its generator — the engine
  builds a different Zone than anyone walked;
- a recorded Zone or Echo no longer replays from its own request, or no
  longer validates against today's schemas;
- **the campaign scale moved** — budget, Checks per Zone, location count,
  `CHECK_VALUE`, finale fraction, enemy cap. This is the owner's "do not
  retune" as a test, and it defends the COMPARISON rather than any of
  those numbers;
- someone retuned AND regenerated the baseline to match, which is the
  quiet version of the same thing. The 24-vs-30 Zone pacing figures are
  pinned separately for exactly that case.

Playtime records now stamp the **build** (commit, branch, tree clean or
not), because a measurement that cannot say which side of authored art
it is on cannot be compared to anything. It is handed in by the engine
rather than looked up: `instrumentation.py` imports nothing that could
reach anywhere and touches one file, and `version.build_metadata()`
shells out to git.

## THE ART A/B — CLOSED 2026-08-30, FREEZE LIFTED

**The A/B is decided and the gameplay freeze is lifted.** The result is
`docs/PLAYTEST_2_5_RESULT.md`; measured facts and interpretation are kept
apart there. Owner verdict: control valid, pipeline PASS, fixtures KEEP,
authored projectiles REJECT FOR NOW (reverted at `5f1435f` by moving the
three `projectile_*` registry entries back to `review: "pending"` — the
source art is preserved for redesign, and the art lane must export them
as pending or the next regeneration silently re-enables them), F3
DEFER.

The freeze text below is kept because it says what the freeze was for:

> Between the pre-art human run of Zone 1 and the post-art run of the
> SAME Zone 1, no unrelated runtime, gameplay or protocol optimization
> lands. The authored-art integration is the variable; anything else
> changing at the same time makes the comparison measure two things at
> once and neither cleanly.

Now unfrozen and available to pick up: **the `mechanics` websocket
payload.** It is ~97% of an elided
late snapshot (~268 KB at 449 Echoes), re-sent on every state change,
and it could be elided on exactly the key the Echo log already uses.
Three places say so where someone would trip over them —
`TestTheFoldIsStillSentWhole`, the `interpretations_complete` field
comment, and `docs/PLAYTEST_BASELINE.md`.

## PLAYTEST 2.5 — one double-click, one Zone

`Playtest 2.5 (Windows).bat`. The human plays **Zone 1 only**; Zone 2 is
optional (if Zone 1 looks anomalous, or for a second structural sample),
Zone 3 is not required and stays frozen in the corpus. The A/B uses the
same Zone 1 twice.

The launcher runs `archipepsi_bridge.playtest check`, refuses on drift
without ever repairing it, starts the bridge at the baseline scale,
keeps the run in `playtest-2.5/` away from real saves, and prints and
files the summary when the bridge stops. No pytest, no JSON hunting.
`make playtest-check` / `make playtest-report` are the same code from a
terminal.

**Two artifacts, and they are not the same Zone — this is the thing to
get right.** `docs/baselines/playtest_2_5.json` is a GENERATOR
FINGERPRINT built from fixed synthetic requests; nobody plays it. The
PLAYED Zone is the mock campaign's Zone 1 at the default scale, whose
request comes from the mock seed's own placements — same 23 rooms in the
same order with the same enemy counts, different theme, widths and
features. Printing the corpus Zone's numbers as "what you are about to
play" would have been confidently wrong, and a test now refuses to let
either quietly become the other.

Two things this needed that did not exist:

- **`--mock-scale`.** MOCK CAMPAIGN was the prototype's thirty locations
  and nothing could ask for anything else, so a human "playing the
  baseline" would have walked Zone 1 of a thirty-location campaign. The
  default is unchanged; the launcher passes `default`.
- **A level id on every playtime record** — sixteen characters of the
  Zone's own hash. Two records with the same id walked the same
  generated level, so the post-art run is PROVED to be the same level
  rather than assumed to be.

## What playtest 2.5 taught, 2026-08-29

The human played Zone 1 of the default-scale mock campaign and the
verdict was about CONTENT, not correctness: 23 rooms, 921 content
points, 32 activities across 19 rooms, and "nothing to do except shoot a
couple enemies or jump up a path". That indictment is the subject of
`docs/design-packet-v0.10/` and is NOT a bug list.

The bugs it did find are fixed, and three of the four are one shape:
**a guard inherits the blind spot of the fix it was built to protect.**

- Encounter timing was cancelled by `note_death()` and never scoped to a
  chamber, so 9 of 10 fights went untimed.
- The Hub described a thirty-Check game to a 450-Check player: the board
  and the denominators were pinned to the prototype. Fourth instance of
  "the options scaled and a consumer did not".
- **Zone signage rendered mirrored.** Playtest 1 found this in the Hub,
  it was fixed in the Hub, and the guard was built around the Hub -- so
  the Zone kept the bug through two more playtests.
- **A corridor had no end walls.** The playtest-2 comment names the three
  builders that had no ends; two of them got ends. Test 57 probes from
  the chamber's CENTRE only, so it was green the whole time. The seal
  suite now stands at 81 floor positions and looks four ways, and a
  sabotage proves test 57 cannot see an off-centre hole.

That last one also surfaced a contradiction nothing had ever hit:
`DOOR_WIDTH` 2.4 < `BRUTE_LANE` 2.6, so no doorway in this game has ever
met the lane budget. Resolved as stated design (a doorway is a narrowing
the 1.8 m brute passes with 0.3 a side) and pinned by a test rather than
left implicit.

One correction worth keeping: I reported that 24 of 25 `Label3D` sites
overflow their panels. **That was wrong on both mechanism and fact** --
`width` defaults to 500 and does nothing anyway because `autowrap_mode`
defaults OFF, and measurement shows every Hub sign fits. There was
nothing to fix, so `godot-legible` now measures the margin instead.

## v0.10 RESEARCH — hard progression, delivered 2026-08-29

`docs/design-packet-v0.10/RESEARCH_MEMO.md`. **Architecture D is proven,
not argued**: a disposable patch gated locations behind a capability
event and ran real `Generate.py` -- solo and multiworld generate clean,
and the negative control (same gate, event removed) FAILS generation.
So an unsatisfiable capability gate is a seed-generation error rather
than a dead seed discovered at hour twenty. **Archipelago polices this
for us.** The patch was reverted.

The owner's rule that governs the redesign: the multiworld must be
logically solvable; it is NOT that every room must be solvable with the
starting kit. Zone CLEARED (5 Checks + exit) is not Zone EXHAUSTED (15).

**No structural redesign is implemented and none is authorised.**

---

**OPEN PACING DECISION — recorded 2026-08-28, do NOT act on it.** The
owner spotted that the default campaign's goal becomes AVAILABLE well
before the campaign is finished: `FINALE_REQUIRED_FRACTION = 0.8` needs
360 of 449 Checks, which at 15 per Zone is exactly 24 Zones, against 30
for a 100% clear. At the provisional 40 minutes a Zone that is 16 hours
to the goal and 20 to a full clear.

So **do not quote "~20 hours" as the campaign length** — that is the
clear, not the ending. Both numbers are real and they are four hours
apart.

It is NOT to be changed yet: both figures are the unmeasured 40-minute
target multiplied out, and retuning a real gate to satisfy a guess is
exactly the mistake. Revisit on the first 1000-budget human playtest
evidence. `CAMPAIGN_SCALE.md` 3 holds the decision record, the
sensitivity table (only 100% reaches 30 Zones, so raising the percentage
alone is not an answer) and the owner's candidate fixes;
`test_campaign_config.py` pins the two numbers apart so they cannot be
quietly conflated again. The playtime log already carries what the
decision needs, so no instrumentation change comes first.

**The 40-minute Zone and the 20-hour campaign are still TARGETS.** They
are arithmetic, not measurements, and must not be described as proven.
CS10 is what can turn them into facts: Godot times each Zone (elapsed,
per-room dwell, deaths, encounter durations) and the bridge joins that to
the values it computed, one JSON line per Zone in `playtime.jsonl` beside
the saves. Local only — no analytics, no upload path, and a test asserts
`instrumentation.py` imports nothing that could reach a network. Read it
with `instrumentation.read_records()` / `summarise()`.

What CS8 turned up is the thing to remember: **the options, the item pool
and the apworld all scaled, and the ENGINE did not.** Scouting,
allocation, the save's Check cap, the goal id in five places, and the
acceptance validator were all still pinned to the prototype's thirty, so
a 450-location campaign scouted the first thirty, played them three at a
time, and ended itself when Check 030 confirmed. Every one of those had a
green suite over it, because the suite ran at prototype scale. The mock
backend now takes a `CampaignConfig` and
`bridge/tests/test_production_scale.py` runs the real engine at 450.

## ROOM GRAMMAR v0 — landed 2026-08-30

The first bounded slice of `docs/proposals/ROOM_FIRST_GAMEPLAY.md`,
approved in direction by the owner. **The rest of that proposal is still
unbuilt and still needs approval per slice.**

What exists now. `ArenaChamber.elevation` is an optional `ElevationBand`
(gallery or pit, one per room, bounded rise/coverage/side/access), so a
room can say it has a second height — the field that did not exist. The
arena builder builds it as ordinary composition: deck, lip, and a ramp
whose run is three times its rise, so base movement always reaches it
(NO REQUIREMENT BEFORE GUARANTEE, applied to geometry). Ranged enemies
take the deck. Two environmental objects exist and answer when hit —
`DestructibleCover` (pays in space, not loot) and `ReactiveBarrel`
(hazard orange honestly spent) — placed only into builder-vouched
sockets. `make godot-room` is the suite; `make godot-zone-audit` now
measures every declared band in the real assembled Zone.

The socket contract is the load-bearing part: **the builder emits points
it vouches for, and regions of architecture that content must avoid are
DECLARED as `reserved` sockets rather than inferred.** Three defects in
this batch were all one shape — the ramp is 6.8 m long so occupancy
classified it as architecture and it became the one invisible obstacle
in the room; ground sockets were offered blind and landed inside crates
and inside the gallery's own mass; and the pit was dug under an intact
floor slab, a sealed basement that every unit test passed.

Measured, not tuned: 5 of 23 chambers in the played Zone declare a band
(4 galleries, 1 pit) on the deterministic seed. On the same Zone, this
batch's engine changes produce byte-identical audit results to the
pre-batch engine — 0 structural failures, 10 placement notes, every one
of them in a `platform_path` room and none in an arena.

`ENVIRONMENT_OBJECT_VALUE` was written and then deleted: how many objects
a room can hold is a fact about its built geometry, and Python pricing it
would be the same builder-knows-what-the-composer-does-not failure.

Owner ruling after playing Zone 1: the problem is not the activity
families, it is that **the rooms are miserable**. "There's more stuff to
do, but it does nothing and it's not fun." A breakable crate with
something in it beats four buttons that do nothing.

The measurement that explains it: **a room's entire shape is three
numbers.** `ArenaChamber` is width, depth, wall_height. There is no field
in which a balcony, a pit, an alcove or a side branch could be described,
so 23 of 23 rooms are rectangles and all eight corridors are the same
7.9 m width. The flatness is not the generator doing badly — it is the
generator faithfully building everything the schema can say.

Consequences measured in the played Zone: elevation exists in exactly one
chamber type (`platform_path`, the special-case minigame, and the one
where all 23 floating activity elements are); 28 of 41 enemies are ranged
with nowhere to be ranged from; 9 of 10 combat rooms hold a single enemy
group; 7–11 inert props per arena against 2 affordance features in the
whole Zone.

The proposal's load-bearing idea is SOCKETS — the room declares where
things may go. Every placement bug this month was one bug, "the builder
knows things the composer does not", and each was fixed by handing the
composer more information afterwards. Sockets end the class.

**F3 is answered by this, not deferred by taste.** Art's own handoff
measured that an authored shell replaces per-chamber dimensions with one
fixed size per registry entry, so integrating it today makes rooms MORE
uniform. The fix Art names — a shell that declares what sizes it can be —
is the socket contract. Grammar first, then authored rooms.

Smallest slice proposed: one elevation band in an arena, ranged enemies
on it, and crates that break into something. No new subsystem.

## ACTIVITY CONVERSION — LANDED 2026-08-30

The batch proposed below was approved and is built. `531 of 921` content
points stopped being glowing boxes: `ActivityRuntime` owns one state
machine (`NOT_YET / IDLE / ACTIVE / COMPLETE`) with the four families
configured in one `RULES` table, and `ActivityElement` is one class with
three trigger modes (`touch` latching, `shot` through `Damageable`,
`stand` momentary with a `PLATE_HOLD_SECONDS` window).

**The owner correction that shaped it: activities are NOT restricted to
the permanent baseline kit.** Prerequisites are SEMANTIC CAPABILITY
SATISFACTION — "can the player grapple", never "does the player hold the
Grapple Echo" — expressed over the primitive vocabulary the fold already
produces (`mechanics.ACTIVITY_CAPABILITIES`, four capabilities, same
shape as `AFFORDANCE_REQUIREMENTS`).

**NO REQUIREMENT BEFORE GUARANTEE.** `capability_guarantee()` answers
with the cheapest proof that holds: A `permanent_baseline`, B
`already_possessed` (over the fold, not the loadout), C
`established_in_zone` (a parameter with no producer yet — the seam a
capability-establishment construct plugs into), D `forge_constructible`
(named, unreachable, deferred). `validate_zone` refuses any activity
requirement outside the guaranteed set, and the default is the permanent
baseline so a caller that forgets refuses MORE than it should.

Raw damage can never be logic: a requirement carries no number at all,
and a capability may not be keyed on `damage_dealt`/`damage_taken`
(`test_a_capability_can_never_be_a_damage_number`).

NOT YET is reachable rather than theoretical: generation reasons over
what the campaign OWNS, `snapshot.available_capabilities` says what is
EQUIPPED, and the gap is the gate. It never fakes an interaction and
never downgrades to a base-kit substitute.

`make godot-activity` drives every family to completion AND to failure
through real physics and the real damage path. Sabotage-proven: inert
elements → 17 failures, always-complete → 8, unchecked ordering → 2.

Two defects fixed on the way. `make_playtest_baseline.py` hardcoded
`unlocked_affordances=()`, so the archive held zero features where the
played Zone held two — evidence that under-reports is worse than none.
And the fallback emitted seven `timed_run`s with `time_limit = 0`; the
clock is now derived from the schema's own floor, never chosen.

`challenge_marker` stays deferred: completion grants a `flavor_log`, and
a test fails if `activity_runtime.gd` ever names the marker.

Zone digest moved `98e08663ce6b3b7a` -> `1bdf42f800c5637e`. Same 23
rooms, 15 Checks, 41 enemies; the value moved 921 -> 916 because seven
runs now earn `ACTIVITY_TIMED_BONUS` and the top-up loop lands
differently. **The A/B is closed, so the digest was free to move.**

## AVAILABLE, NOT ADOPTED: the Art lane's camera bench

Art surfaced an existing render toolchain on `claude/archipepsi-art`
(`docs/art/CAMERA_BENCH.md`, `tools/artpreview/`, `tools/shots/*.json`,
and a finished `docs/art/proposals/photo_mode.gd`). **Awareness only —
no owner mandate to adopt any of it, and nothing here depends on it.**

Worth knowing because it names a real gap: Production has no
screenshot/render capture path at all, so a visual regression can exist
with every logic suite green. That is what the mirrored Hub sign and the
one-slab light fixture were. If a future batch wants golden shots of
REAL generated Zones, read `CAMERA_BENCH.md` first — `--headless`
selects the dummy driver and an awaited SubViewport capture hangs with
no output, which is an hour nobody needs to spend twice.

## THE BATCH THAT BECAME THE ABOVE — proposed 2026-08-30, approved

`docs/proposals/NEXT_BATCH_ACTIVITY_CONVERSION.md`. **Built and landed;
kept for the reasoning, not as a to-do.**

The owner's stated priority is PLAYER ACTIVITY MUST BE FUNDED
INDEPENDENTLY OF CHECK COUNT. Measuring the played Zone sharpened it:
531 of its 921 content points (57.7%) are already activities, and
`Activities._row()` builds a `StaticBody3D` with a mesh and a collider
and nothing else. No `Area3D`, no signal, no completion; nothing outside
`activities.gd` reads the four kinds at all. So the budget already flows
away from Checks and none of it becomes gameplay — the binding
constraint is conversion, not funding, and adding rooms first would
scale a conversion rate of zero.

Why it was invisible: `test_the_engine_builds_every_activity_the_schema_admits`
reads `activities.gd` as TEXT and proves a `match` branch exists. Right
question when the seam was geometry; it cannot see that the branch
produces something inert. The same shape as the mirrored sign, the
centre-only seal probe and the fixture detector: **a guard inherits the
blind spot of the fix it was built to protect.**

Two smaller finds recorded there: `SECRET_VALUE` is priced in
`content_value.py:54` and no chamber field can produce one, and
`make_playtest_baseline.py:91` hardcodes `unlocked_affordances=()` so the
archived baseline under-reports optional content against the Zone that
was actually played (2 features).

## What playtest 1 taught, and the guard it left behind

Nine headless suites, a whole-campaign integration run and both CI tiers
were green while the game could not enter the Hub. Every one of those
suites is a DRIVER: it takes the dispatch branch in `Main._ready` and
returns before the real setup, then builds its own world. So the startup
path had NO coverage at all, and a refactor that deleted the two lines
assigning `world` and `tones` cost a day.

The general shape, worth carrying into any new test: **a suite that
substitutes for the code it is meant to protect proves nothing about it.**
Two structural guards now exist because a comment saying so did not work.

- `make godot-boot` calls the real `Main.boot()` and drives the
  transition that crashed. It runs FIRST in CI.
- `test_ci_coverage.py` fails when a Godot suite exists that CI does not
  run, because a hand-maintained list of tests falls behind the tests.

Godot's GDScript warnings are EDITOR-ONLY. `--import`, `--editor --quit`
and a SceneTree probe all report zero headlessly, so no CI tier can see
them and the count drifts silently. The three scratch analyzers used for
the sweep were not kept; a warning sweep means opening the editor.

Wake-ups are no-ops except for concrete regressions or CI failures. Do
NOT invent a new roadmap or speculative work to fill a heartbeat.
