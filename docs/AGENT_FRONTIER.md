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

## THE OFFER RULES AND THE GEOMETRY ARE IN THE SAME ROOM — 2026-09-03

Independent audit `802732d`, `docs/audit/2026-09-03-physical-truth-adjudication.md`.
Vera's B-1 in one line: `MovementPackage` had eight call sites, all in
one test file, and every one passed a constant or a half-space predicate
over a bare box. `PhysicsDirectSpaceState3D` never appeared in the file
that called it. The offer rules and the geometry they were written to
judge had never met, and `RoomAudit` does not read `offers` at all.

**`SpaceProbe` is the one canonical real-geometry query.**
`ground_below` (first ground at or below a point, exact reach, no
window), `body_fits` / `stance_fits` (the whole capsule, and the body
above step height), `column_is_clear` / `first_block_point` (swept, not
sampled at the ends), `stand_pose` (`SUPPORT_LIFT`), and `refusal` --
which makes a detached root or a null space an explicit REFUSAL rather
than the clean pass a probe with nowhere to go always returns. `RoomAudit`
and the offer validators now share one implementation of "is that a
crate", so they cannot come to disagree about the same crate.

**The stride is deleted, not tuned.** `_grapples` walked down in 2 m
steps asking a 1.5 m window at each. Two errors, different causes: a
window narrower than the stride leaves a blind band per step, which
refused three real span anchors because the floor at y=0 fell between
the samples at 1.4 and -0.6; and a window reaches past both bounds, which
accepted hang space under `SWING_ROOM` and ground past `GRAPPLE_DROP`.
Widening fixes the first and worsens the second. Now: one measured drop,
compared against both bounds, and a swept hang column.

**A LAUNCH TARGET NAMES THE FLOOR** (owner ruling). Support is proven at
the authored point, the body pose is derived with `stand_pose`, the
capsule is proven at that pose, and the arc is flown between poses.
Sabotaged: without the lift, a landing on a clean deck face is refused
"96% along its own arc" -- the three false findings the audit predicted a
new caller would manufacture on its first run.

**A destination must hold a player.** Traversal endpoints, optional ones
included, are now capsule-standable rather than merely above a ray hit.
Calibrated twice on the way: the full capsule at the marker refused every
endpoint beside a riser, and re-reading `TraversalLaw`'s own lesson gave
the body-above-step-height test; then the exact point alone refused the
rubble stones owner ruling C(ii) calls architecture, so the check now
searches the endpoint's neighbourhood exactly as `TraversalLaw._seed`
does. **It still catches what it was added for**: the plenum's three
collar endpoints, `pl_machine` named, without waiting on Art's collar
repair. That is the Production half of the shared A-2 handoff.

**A real production caller.** `OfferBinding` is the post-instantiation
stage, and `ZoneController` calls it one deferred physics frame after the
Zone root enters the tree. `ContentInstantiator` cannot own that moment:
`build_chamber` returns a DETACHED root, so no collider is registered and
`get_world_3d()` is null -- every probe would answer "nothing there".
`MovementPackage.consume` now takes the space itself rather than two
callables, so a lambda cannot be handed to it, and all eight former stub
call sites were rebuilt on real colliders.

REAL-GEOMETRY VERDICTS, first ever recorded:

| room | built | declined |
| --- | --- | --- |
| hall | 3 (all grapples) | rail into `hl_ramp1_tread3`; launch arc into `hl_east_gantry` |
| plenum | 2 grapples | rail into `pl_collar_0`; launch body inside `pl_machine`; `grapple_1` 0.76 m of hang space |
| span | 3 (all grapples) | rail into `sp_pylon_0`; launch arc into `sp_deck` |
| yard | 5 (everything) | none |

Every one corroborates the audit, including the span's three grapples the
old stride refused. Yard is clean on offers. Eight approved P2 shells,
hall, span and yard all remain `structural=0 measured=0`; the plenum
carries the three collar endpoints as pending evidence.

TWO CAVEATS STILL OPEN and owned elsewhere: the plenum's collar annuli
importing as filled convex hulls (Art, A-1), and the rail/launch routes
that intersect real geometry in three of four rooms (Art, A-4/B-4).
Nothing here repaired content.

## EVERY AUTHORED SHELL MEASURES TRUE — 2026-09-03

Art `26a2914` (repair `4441ea5`) synced. The mirrored delta is ONE file,
`registry/authored_art.json`, and eight declared points inside it. No
`.glb`, no `.tscn`, no `SCENE_PLAN.json`, no geometry, no traversal, no
entry connector. Art's independent reproduction agreed with Production's
eleven findings and with which three of them the entry ruling had already
superseded.

The eight points, each moved laterally off the block it was named inside:

* plenum `reward` volume `(0, 29.333, 10)` -> `(5.25, 29.333, 10)`
* yard `cover_0..3` z `16 -> 13.4`, `34 -> 37.1`, `15 -> 12.4`,
  `33 -> 36.6`
* span `cover_0..2` x `-9 -> -12.1`, `8 -> 10.6`, `-7 -> -10.6`

**ALL TWELVE AUTHORED SHELLS NOW MEASURE structural=0 measured=0** — the
eight approved P2 shells, the hall, and all three Wave-1 LARGE rooms.
First time the whole registry has been clean.

PROVEN AUTHORED, not inferred from a quiet census. Each of the three
carries `authored_shell` equal to the id requested, instantiates from its
own `.tscn` (`root.scene_file_path`), and presents exactly the counts its
manifest declares — plenum 20/15, yard 6/5, span 6/5. A procedural arena
produces none of those.

The arrival check is not vacuous either: all three declare a
`player_entry`, all three report `[]`, and moving the plenum's into its
own machine volume produces the finding immediately.

FORM PRESERVED, measured: plenum entry `(0, 68, 0)` / exit `(0, 0, 22)`,
73.60 m of geometry, top-entry and bottom-exit intact. Yard 17.60 m tall,
entered at `(-43, 0, 26)` and left at `(+43, 0, 26)`. Span keeps
`deck_to_basin`, a `drop` from y=14 to y=0, one way. Marker parity 12
scenes / 160 markers / 0 disagreements.

TWO CAVEATS CARRIED FORWARD UNRESOLVED, by instruction, and neither is
explained away here:

1. The plenum's annular collar imports as a CONVEX COLLISION DISC. A
   ring whose hole is filled by its own collision hull is a floor where
   the room shows a void, and nothing in this pass looked at it.
2. There is still no canonical real-geometry `supported` caller for
   grapple validation. `MovementPackage` has no production caller at all,
   so the same three hall anchors build or decline depending on whether
   the probe window covers `_grapples`' own 2 m stride.

An independent audit owns both. Neither was touched.

## THE ENTRY IS WHERE THE ROOM SAYS IT IS — 2026-09-03

Owner ruling: `(0, 0, 0)` has no semantic meaning as the universal room
entrance. It was the value every shell happened to have, read by nobody,
and believed by `ZoneBuilder` and `RoomAudit` as though it were a
contract — so three LARGE rooms entered at their top or along their side
measured as having a sealed door in a solid wall, and the message blamed
the geometry for an assumption in the probe.

TWO CONCEPTS, KEPT APART. The **entry connector** (`doorway` socket
`entry`/`end_a`) is the room-to-room attachment transform; it sits on the
envelope and may sit slightly outside it — the yard's is 0.4 m past its
own west wall — so **no standing floor is required under it**. The
**`player_entry` volume** is the interior region the body arrives into,
and that is where capsule safety is proven. `player_entry` had been a
legal kind in `schemas/content.py` since S12 and was read by NOTHING: a
vocabulary word with no consumer, which is how three rooms declared an
arrival region no probe ever looked at.

`ZoneBuilder` now places a room so its entry connector lands on the
previous room's exit, `origin_for(join, yaw, entry)` and
`exit_cursor(origin, yaw, exit)`, both public so a test measures the seam
instead of reimplementing the subtraction. Vertical offset and yaw come
free: both connectors are room-local vectors turned by the room's own
yaw. The legacy fallback is `RoomContract.LEGACY_ENTRY` — named, not
assumed, because the old behaviour was identical AND invisible.

Seven proofs, each sabotage-checked. Reverting the audit to the origin
turns E1/E2 red with the exact old symptom; stubbing the arrival check
turns E5/E6 red; making `origin_for` return the join turns E3/E4/E7 red.

ONE STALE GUARD CORRECTED, not weakened. `movement_driver` pinned the
net-descent ruling by grepping `zone_builder.gd` for the literal
`cursor += _rot(yaw, result["exit_offset"])`. That line is gone, so the
guard pinned the SPELLING rather than the ruling; it now asserts the seam
itself — a room whose exit sits 6 m below its entry moves the chain down.

RESULT. Eight P2 shells unchanged at 0/0. The three entry findings
vanished — plenum 2 -> 1, span 4 -> 3, yard 5 -> 4 — and every declared
`player_entry` passes capsule safety on the first run, which is
independent evidence Art's arrival regions were right all along.

## HALL CERTIFIED — 2026-09-03

Art `0ed2292`: three `grapple_point` offers and one optional collar
`ring_s_to_ring_e`, no geometry change. 12 surfaces, 12 traversals (9
mandatory / 3 optional), 6 offers, 73 colliders, marker parity 12 scenes
/ 160 markers / 0 disagreements. **structural=0 measured=0.**

THE COLLAR IS OPTIONAL, AND `_traversal_is_true` SKIPS OPTIONAL
SEGMENTS, so `measured=0` did not prove it. Forced mandatory in a
throwaway manifest edit, the audit's own flood proved it and the room
still measured 0. That is the proof; the clean sheet alone was not one.

All three grapple offers BUILD through `MovementPackage`. But the same
offers DECLINE under a narrower `supported` probe, and the difference is
arithmetic rather than geometry: `_grapples` walks down in 2 m strides,
so a probe window narrower than the stride falls BETWEEN floors and
reports a 60 m hall as having no ground in it. **`MovementPackage` has
no production caller and Production has no canonical `clear`/`supported`
implementation** — the rules exist, their binding to real geometry does
not. Whoever writes that caller inherits this. Flagged, not fixed.

## shell_hall_transit IS TECHNICALLY CLEAN — 2026-09-03

Art `8fbb916` synced. The mirrored delta is five files: `SCENE_PLAN.json`
and four `.glb` meshes. The manifest and every `.tscn` are UNCHANGED, so
this is a pure geometry repair and marker parity could not have moved.

**THE HALL CERTIFIES: structural=0 measured=0**, over 12 surfaces and 11
traversals — not over zero probes, and not over a substitute room.

INSTANTIATED AUTHORED, proven four ways rather than inferred from the
absence of a REFUSED line: the builder's own stamp reads
`authored_shell=shell_hall_transit` (a fallback leaves it empty); the
instantiated root's `scene_file_path` is
`res://content/shells/shell_hall_transit.tscn`; that path is the one the
manifest declares; and the census surf/trav of 12/11 are exactly the
manifest's declared counts, which no procedural arena can produce.

THE SAWTOOTH IS GONE, measured with the real capsule's own ray at 0.10 m
along each segment. `basin_to_gallery`: 256 samples, 0 missing ground,
**max upward step +0.846 m**, max downward 0.000 — monotonic.
`gantry_to_exit`: 231 samples, 0 missing, **max upward step +0.875 m**,
max downward 0.000. Before the repair the same lines stepped ~1.40 m.
Both are inside `MAX_VERTICAL_STEP` = 1.0, and Art's own figure across 19
flights (0.89 m) sits just above Production's two measurements, which is
the right direction for a handoff claim to be wrong in.

A CAUTION ABOUT MY OWN PROBE, recorded because it nearly became a false
finding. The same straight-chord sampling reports max_up +21.000 for
`gallery_to_landing` and `ring_n_to_ring_e`. Those are not defects: the
chord between two ring surfaces cuts across the ring's open middle and
the ray falls to the basin floor and back. It is the collar-versus-chasm
trap again, from the other side — a chord probe is fine for a flight and
worthless for a loop. The authoritative flood passed both.

Nine mandatory segments chain unbroken vestibule -> basin -> gallery ->
landing -> bridge_n -> ring_n -> ring_e -> bridge_e -> gantry ->
exit_platform; `ring_s` and `ring_w` sit on the two optional segments by
design. Marker parity exact: 12 scenes, 158 markers, 0 disagreements.
Plinths keep their geometry and are not `stand` Surfaces; no plinth
traversal claims remain.

**Actual instantiated collider count: 73 `CollisionShape3D` (73
`StaticBody3D`, 3 `MeshInstance3D`).** Art's prose says 71. Not
reconciled, and deliberately not explained away — `all_solid_boxes`
returns 76 over the same root, so the three counts measure three
different things and only the 73 is what Godot instantiates.

Verdict: **TECHNICALLY CLEAN / OWNER REVIEW PENDING.** Still
`review: pending`, still out of the catalog, no owner pass assigned.

The refusal guard still bites: with the hall no longer refused, the
sabotage was recreated (review flipped to `pass` AND one traversal start
dragged 5 m off its marker) and the suite went red, exit 2, "approved
content and its authored scene was refused".

## HALL BUILDS; THE TWO CLIMBS DO NOT WALK — 2026-09-03

Art `6232a27` synced (`SCENE_PLAN.json`, `registry/authored_art.json`,
`shells/shell_hall_transit.tscn` — the `.glb` did NOT change, which is
itself the confirmation that only the markers were ever stale).

**THE STALE-SCENE DEFECT IS CLOSED.** Verified independently rather than
from Art's report: 12 scenes, 158 `Marker3D` nodes, **0 scene/manifest
disagreements**. `shell_hall_transit` now instantiates as AUTHORED —
surf=12, trav=11, sock=21, hull=73, **structural=0**. Surfaces 14 -> 12;
the plinths keep their geometry and stop being `stand` Surfaces, which
answers the 2026-09-02 finding.

**IT STILL DOES NOT CERTIFY: measured=2.** Both mandatory climbs —
`basin_to_gallery` (0 -> 11 m) and `gantry_to_exit` (21 -> 28 m) — fail
the walk-connectivity proof.

WHAT THE FINDING MEANS, measured rather than guessed. Sampled along each
flight, the AABB evidence and the physics evidence disagree, and they
disagree the way the recurring defect always does — two derivations of
one fact. `mesh_ground` over collision AABBs (what `ShellValidator` reads,
hence structural=0) sees clean monotonic treads: 21.00, 21.88, 22.75,
23.62, 24.50, 25.38, 26.25, 27.12, 28.00 — every rise 0.87. The physics
ray (what `RoomAudit` reads, and the final authority) sees a SAWTOOTH on
the same line: it reaches a tread top, descends 0.35-0.70 m before the
next tread, and the climb out is then **~1.40 m every time** —
21.17->22.57, 22.23->23.62, 22.92->24.32, 23.97->25.38, 24.68->26.07,
25.73->27.12, 26.43->27.82. `MAX_VERTICAL_STEP` is 1.0.

This is NOT a single-line sampling artifact, and the flood is what rules
that out: it is 8-connected at 0.4 m over the whole declared corridor and
visited 2312 cells of roughly 2848 available in the basin alone without
ever climbing. If any lane up either flight had rises within a step, the
search covered the width to find it.

So: a REAL geometry property, not a metadata defect and not a law that
needs relaxing. The real collision surface of both flights does not rise
monotonically, so a player walking up meets ~1.4 m rises. Art's to
remodel so the walking surface climbs in <=1.0 m increments, or the
owner's to re-declare these as something other than `walk`. Not repaired
here, and the law was not touched: `MAX_VERTICAL_STEP` stays 1.0 and no
tolerance was widened to make the room pass.

Small discrepancy worth a look: Production counts **73** CollisionShape3D
nodes in the hall; Art's handoff says 71.

Wave-1 unchanged and still inert — all four pending shells load,
`is_offerable` refuses each, catalog is exactly the eight approved P2
shells. Digest `6e8d83d0f3ec088b`, 23 rooms / 15 Checks / 922 points / 35
enemies, baseline byte-identical, 17/17 Godot suites and 1140 Python
tests green.

## HALL RECERTIFICATION — REFUSED, and the guard that hid it — 2026-09-02

Art `3b7bb02` is integrated verbatim (`SCENE_PLAN.json`,
`registry/authored_art.json`, `content/shells/`), including the three
Wave-1 LARGE rooms at `review: pending`. **`shell_hall_transit` DOES NOT
CERTIFY: it does not build.**

`ShellValidator` refuses it because Art's manifest and Art's own
`shell_hall_transit.tscn` disagree about where four traversals start and
end — eight endpoints, 0.71 m to 5.02 m apart. The refusal is real and
Production is right to make it.

WHICH HALF IS STALE, measured rather than assumed. Against the previous
manifest the scene's markers were exact (0 mismatches, all 26). Against
Art's new mesh, ALL 22 declared endpoints in the new manifest are
supported — every one finds ground within a legal step. So the manifest
is right about the geometry Art shipped and the `Marker3D` nodes are the
half that did not get regenerated. **The fix is Art's and it is one
file:** re-export `shell_hall_transit.tscn` from the source that
produced the manifest. Production did not hand-edit either artifact.

THE GUARD THAT HID IT, and this is the more durable lesson. The census
asked "did the authored scene answer?" as `not sockets.is_empty()` — and
a refusal falls back to the PROCEDURAL builder, whose rooms have sockets,
meshes and hulls like any other. So the hall was refused, silently
replaced by an arena, measured, and reported `structural=0 measured=0`:
a clean sheet for a room that never built, over a room nobody asked
about. The suite was GREEN while looking at the wrong geometry.

`ContentInstantiator` now stamps `authored_shell` on the result it
builds from a scene, because the builder is the only code that knows
which branch it took, and the driver asks it instead of inferring.
A refused shell gets no census line at all — it prints REFUSED and the
validator's reasons — since every number on that line would have been
the substitute room's. Sabotage: flipping the hall to `review: pass`
turns the suite red (exit 2, "approved content and its authored scene
was refused"); pending keeps it evidence, the same gate findings use.

SECOND FINDING, from the two plinth traversals Art deleted. The nine
MANDATORY traversals still chain unbroken vestibule -> basin -> gallery
-> landing -> bridge_n -> ring_n -> ring_e -> bridge_e -> gantry ->
exit, and the two optional ones close the ring westward, so base-kit
circulation survives the deletion. But `plinth_west` and `plinth_east`
are still declared `stand` surfaces, 6x6 m at y=4.0, and NOTHING
declared reaches them any more: no traversal, and no offer either — the
rail route passes nowhere near them and `launch_gantry` is the gantry at
(16, 21, 30). Under C(ii) a `stand` surface is a region OFFERED to a
placement consumer, so the hall now offers two standing regions that are
not behind a capability gate but behind nothing at all. Either the
plinths stop being surfaces or something declared reaches them. Owner /
Art decision; not repaired here.

The three Wave-1 rooms are INERT, proven at the seam rather than
asserted: all four pending shells load into the registry, `is_offerable`
refuses each, and `shell_catalog` is exactly the eight approved P2
shells. `SHELL_FOR_TYPE` still names the five procedural ids. Digest
`6e8d83d0f3ec088b`, 23 rooms, 15 Checks, 922 points, 35 enemies,
baseline byte-identical. Eight P2 shells still `structural=0
measured=0`.

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

## P2 OWNER APPROVAL ABSORBED — the eight shells ship — landed 2026-09-02

Art `5998ef8`, integrated verbatim. **Exactly one field moved**:
`review` "pending" -> "pass" on the eight room shells, plus the matching
`runtime_substitution` in `SCENE_PLAN.json`. Every other field on every
entry is byte-identical -- geometry, collision, sockets, surfaces,
traversal, volumes, size_class, exit_yaw, fits_floors, cameras. The three
projectile visuals stay pending.

**The catalog is no longer empty, and that is what approval MEANS.**
`shell_catalog()` now offers all eight under corridor / tower /
treasure_room, because a passed shell is shippable and therefore
offerable. `SHELL_FOR_TYPE` is untouched and still names only procedural
ids, so the DEFAULT route is unchanged and the fallback provider names no
shell at all (all 23 played rooms carry `shell_id: null`). But a live
Epsilon provider is now shown them and may name one -- so "unavailable to
ordinary Zone composition" is true of the default and the fallback, not
of the live path.

Zone digest `6e8d83d0f3ec088b` unchanged; the played Zone is identical.

**Review is now a HARD gate.** An approved shell that fails the contract
turns the suite red rather than reporting a note. All eight measure
`structural=0 measured=0`, so the gate binds and passes.

Two suite guards were re-anchored, both to something stronger:
`_test_a_pending_shell_never_reaches_a_zone` used to walk the registry
for whatever happened to be pending and assert it found eight -- a gate
that stops testing on the day everything is approved, which is the day it
matters most. It now MAKES a pending shell from a real one, so the
refusal is exercised whatever the pack's review state is (sabotage-proven
against `is_shippable`). And `test_the_committed_registry_offers_exactly
_what_it_has` said in its own failure message that when authored shells
arrived it should start asserting they ARE offered; it now asserts the
offered set is exactly the shippable authored shells.

**OUTSTANDING, and NOT mine to take**: the Playtest 2.5 baseline no
longer matches, because the request catalog Epsilon is shown now contains
the eight. Measured: nine changed leaves, ALL under
`zones[*].request.catalog.room_shells`, ZERO under any zone output.
`preflight_problems()` says in as many words that retaking it is "a
developer's call, not yours", so it was not retaken. `make baseline`
fixes it, and `test-bridge` is red on those two tests until it is run.

## P3.5A — the walk proof is physical — landed 2026-09-02

**The owner found a real unsoundness and it is fixed.** P3.5 used
declared `stand` rects AS the proof of connectivity: two ends inside one
Surface passed unconditionally, and two rects overlapping in the
manifest were taken as an edge. Under C(ii) a Surface promises only that
a valid placement can be FOUND in it, so one valid Surface may span a
chasm -- and that chasm was being called walkable.

**Rects now BOUND the search; geometry proves it.** A bounded flood over
player-radius samples: a node exists only where the evidence finds
support at a walkable height and the player's body fits above step
height, and an edge exists only between neighbours within one
`MAX_VERTICAL_STEP`. Rings, switchbacks and long ramps flood; chasms do
not. The cap FAILS CLOSED.

Evidence: `ShellValidator` floods collision hulls (support only -- an
AABB body test at surface EDGES false-refuses every P2 shell, measured);
`RoomAudit` floods with the real capsule and is the final authority.

Two engine bugs surfaced on the way: the audit's ground ray reached only
0.8 m below its reference and so could not SEE a legal 1.0 m step down,
and a one-player-width lattice anchored on the start sampled only the
riser column of a step.

S1-S6 all pass and both sabotages are caught.

**ONE OUTSTANDING, and it is Art data, not the law**: `shell_tower_spiral`
`platform_8_to_deck` is declared `walk` and crosses a **0.8 m void** at
x=3.0 between two decks (probed: floor at 9.00 for x<=2.6, nothing at
x=3.0, 8.00 for x>=3.4). That is a legal hop, not a walk. The shell is
`review: pass`, so the gate turns `godot-room-contract` RED -- working
as designed. One word in Art's manifest (`walk` -> `gap`) clears it, and
Production must not make that edit.

## P3.5 — LARGE-room traversal semantics — landed 2026-09-02

Art `28c5a99` integrated. **`shell_hall_transit` stays `review: pending`:
approval does not override the gate, and it does not pass yet.** Three
precise findings, all its own declarations rather than its geometry —
`basin_to_gallery` declares a mandatory walk from the basin to a gallery
11 m up with no declared surface chain between them, and
`gallery_to_landing` / `gantry_to_exit` start 1.0 m past the end of the
platforms they leave from, in air with no geometry under them.

**Traversal kinds are claims, not exemptions.** `TraversalLaw` states the
law once; `ShellValidator` runs it on collision hulls at import,
`RoomAudit` on rays in the tree. `gap` and `rise` keep their bounds
untouched; a `walk` is checked as CONNECTIVITY over the room's declared
surfaces. My first draft used a straight-line ground sample, which is
wrong and worth remembering: a ring collar and a chasm crossing are
identical along the chord, so no chord test can separate them.

**Rails are smooth.** Catmull-Rom handles from the authored points, which
the curve passes exactly through. Measured on the shipped `rail_helix`:
worst baked turn **1.68 deg** over 735 samples versus **62.4 deg** per
corner as segments. Pitch and envelope containment are measured on the
BAKED curve, because points can be legal while the curve between them is
not. An invented max-bow constant was deleted rather than tuned.

**`grapple_point` is a place, not a mechanic.** A region offer, validated
(anchor clear, room to swing, ground below) and never built — Epsilon
picks the verb, or declines.

**Offers were never reaching the room**: `_from_authored_scene` did not
emit the key at all, so the P3.0 seam was unconnected on the authored
path. Fixed.

Four sabotages, all caught. Digest `6e8d83d0f3ec088b`, catalog 8 (the
hall is not in it), eight P2 shells unchanged at `structural=0
measured=0`.

## P3.0 — LARGE-ROOM MOVEMENT FOUNDATION — landed 2026-09-02

Contract only. **No LARGE room was authored**, and none of the eight P2
shells was touched. Full record: `docs/LARGE_ROOM_MOVEMENT.md`.

**What the rail was**: two points on one axis and an `Area3D` that
lowered friction while the player fell through it under normal gravity.
Not path following, no entry, no jump-off, corridors only. Calling it a
spline grinder would have been a lie, so the audit says so plainly.

**`RailPath`** owns a `Curve3D` with an explicit 0.2 m bake interval and
is the single authority for beam, ride volume, runtime and validation.
Curves, climbs, descents and helices are legal; past 75 degrees is
refused, and so is a degenerate path -- at build time, not under a rider.

**`RailRider`** is pure state, so the whole ride is driven frame-exact
headlessly. Entry needs proximity AND motion along the path; direction
comes from the sign of that motion; exit is the endpoint or jump, never a
dead stop. **The rail DRIVES** -- a target pace shifted by slope, with
arrival momentum riding on top and bleeding away. That is progression,
not taste: a map-provided route may be mandatory, so the base kit must
finish it, and the first ballistic draft stalled a walking player a third
of the way up a 6 m climb.

**`LaunchSolver`** derives the trajectory from source, destination and
gravity -- no authored velocity anywhere, so moving either end moves the
arc. A chosen apex rather than minimum time makes it readable AND unique,
which is what makes it deterministic. Refuses an obstructed arc, an
unsupported landing, a landing with no room, and a landing smaller than
a player can aim at. `bounce_pad` stays: different offer.

**The offer seam**: `offers` on the room output and in the manifest,
closed to `rail_route`, `launch_source`, `launch_target` -- the three
with consumers. `grapple_anchor`, `platform_route` and `wind_column`
arrive through the same key with the packages that read them.
`MovementPackage` is the minimum harness proving an offer can be
consumed, validated, and DECLINED, with the room still a room.

Ten engineering fixtures, all ugly boxes and bare paths. Four sabotages
run; three caught. The fourth found that the "too few points" branch is
redundant with the length rule -- recorded as defence in depth rather
than dressed up, and the missing coverage added anyway.

Digest `6e8d83d0f3ec088b` unchanged, catalog empty, all eight P2 shells
still `review: "pending"`.

## P2 TECHNICALLY COMPLETE — the eight shells satisfy the room
## contract — landed 2026-09-02

Art `1d22cef` integrated verbatim (every Production content file
byte-identical to Art's). **All eight shells: 0 structural, 0 physical
findings**, with the probe census printed beside them so a clean sheet
cannot be a clean sheet over nothing.

Repairs: a deck well over the collapsed and spiral climbs (the deck was
the obstruction, so the deck moved, not the validated climbs), both
`high_3` sockets re-derived by `stance_spot`, and treasure `step_low`
withdrawn as a Surface with its geometry untouched.

**The seven old findings are closed, proven by running the same
certification probes against the old pack in a worktree** -- they fail
there and pass here. The old pack also fails **spiral `high_3`**, which
the previous contract missed because `_points_have_ground` uses a 0.5 m
box and that socket cleared it by ~0.05 m; measuring the real `ranged`
envelope shows it never had room. Independent confirmation of the
owner's judgment call.

Two certification probes added, both producer-independent and both
measuring against rules the audit ALREADY holds rather than adding new
ones mid-certification: a mandatory route must arrive somewhere a
standing player fits (resolved to the declared region, because a
traversal endpoint is where a rise is measured, not a spawn point), and
an `enemy_high` socket must hold the envelope of what stands there.

`review: "pending"` on all eight -- NOT promoted. Catalog empty, digest
`6e8d83d0f3ec088b`, Zone audit JSON byte-identical to `1648fa9`. No
Production code writes any field Art emits, so the next regeneration
needs no patch reapplied.

Full record: `docs/audit/P2_SHELL_PHYSICAL_VERDICT.md`.

## P2 SURFACE SEMANTICS — a Surface is an offer — landed 2026-09-01

**Owner ruling C(ii).** A `stand` Surface does not promise every point of
its rect is clear. It promises **a valid placement can be FOUND somewhere
in it** -- the same shape as "a socket is an offer, not an order". A
Surface with ZERO valid placements is still invalid.

**One solver**: `scripts/content/placement.gd`. It owns the candidates,
their order, the footprint rule and the verdict. `RoomAudit` asks "can
this keep its promise?"; `Activities` asks "where is the point?". Both
call `Placement.find`. Evidence necessarily differs -- the audit measures
a room in the tree, the composer runs on a detached root -- so each
passes a `clear` Callable and the suite pins the two verdicts against
each other on every producer.

**`Activities` stopped choosing blind.** Its last-resort spot used to be
the first candidate whatever was there; it is now the first the ROOM
allows, so only crowding is traded away, never geometry. A surface that
cannot hold an element is declined and the flat solve stands.
`ChamberBuilders.all_solid_boxes` reads collision shapes too, because an
authored shell is one merged mesh and the composer could not otherwise
see inside it.

**No percentage is law.** Validity is geometric: a footprint fits, or it
does not.

**Findings 75 -> 7.** Every C finding gone, every A and B finding kept:
collapsed `rubble_1_0`/`rubble_1_1` + socket `high_3`, spiral
`platform_6`, treasure `step_low` x3. Those stay Art's.

**Proven, not asserted.** Four sabotages, each caught: restore "every
point must be clear" (fails on the PROCEDURAL producer too), make the
audit never refuse, make the composer skip geometry, stop reading
colliders. Determinism: same chamber composed twice, identical
positions; no RNG in the solver. Producer independence: a real
procedural island roofed in three steps -- none, half, all -- and the
verdict follows the geometry. Real-Zone proof: the 23-chamber activity
audit JSON is **byte-identical** to `940211e`.

## P2 PHYSICAL VERDICT — the shells are measurable, and measured —
## landed 2026-09-01

Art `a798b2c` brings collision: **1 render mesh + 10-33 convex hulls per
shell**, no trimesh, no drawn collision mesh, and the player's own
capsule passes every entry and exit plane. The audit's answer is no
longer "not measurable".

**75 findings, and they are three different things.** Full record with
every number: `docs/audit/P2_SHELL_PHYSICAL_VERDICT.md`.

The probe that separated them: sweep each declared rect 15x15, inset by
the player's diameter, and ask whether a 0.4 x 1.8 m capsule fits
standing at the declared height. Legitimate surfaces measure 40-100 %
usable; the defects measure **0 %**. Nothing sits near the boundary.

* **A — real geometry defect (27).** The last rungs of the *collapsed*
  and *spiral* climbs run under the top deck: 1.50 m and 0.50 m of
  clearance on a `mandatory: true` route. Art's.
* **B — metadata derivation defect (28).** Treasure `step_low` is a
  0.40 m riser whose exposed ring is 0.40 m wide against a 0.80 m
  player: 0/225 usable, declared a Surface. Collapsed socket `high_3`
  sits 0.2 m inside the stone above it. Geometry correct in both;
  the claim is not.
* **C — contract semantic mismatch (20), NOT implemented.** A `stand`
  rect that is the mesh's true top face, part of it under a stair or a
  dais. **The tower stones ARE general-purpose stand surfaces** — 2.6 m
  square with 40-100 % clear — so demoting them to traversal-only would
  throw away real space. But the contract cannot say WHICH PART of a
  face is clear, and measurement does not settle who should: Art
  declares only clear rects, or the audit measures usable area and
  `Activities` checks clearance where it places. **Owner decision, on
  record, not guessed at.**

Whichever way C goes, the rule that catches A and B is unchanged: a
`stand` surface with zero usable area is refused.

**One audit defect fixed.** Two 1.00 m rises measured **1.000039101** —
`.glb` float quantisation — and were refused, while the span check three
lines below had always carried `+ 0.01`. `RoomAudit.AS_BUILT_SLACK`
names the tolerance once for both. Pinned from both sides: 4 mm over is
the same step, 15 cm over is still refused.

All eight stay `review: "pending"`. Catalog empty, digest unchanged,
every chamber still builds procedurally.

## P2 FINAL — the eight shells are in the catalog, and refused by the
## audit — landed 2026-09-01

All eight are IN the registry (29 entries load), carry the owner's size
classes, and are `review: pending` — nothing can select them, the
catalog offered to Epsilon is empty, and the digest is unchanged.

**None of them measures true, and the reason is one thing: the imported
meshes carry NO COLLISION.** One `MeshInstance3D`, zero
`CollisionObject3D`, zero `CollisionShape3D`, in every shell. So the
audit's verdict is **"not measurable"**, not "measured and safe":
Art's 47 predicted headroom notes are neither confirmed nor refuted,
and neither are the doors or the jumps. `ART_ASSET_SPEC.md` §3 is
explicit that collision is authored (`-col` / `-convcol` / `-colonly`),
so this is an export gap, reported and not worked around. No mesh
repaired, no contract weakened, no metadata flipped.

**The envelope defect was real and shared.** `_check_envelope` allowed
0.15 m and ran on the AUTHORED PATH ALONE. Measured: procedural rooms
overhang their own bounds by **0.20 m** (`_perimeter` centres its walls
on the boundary), authored shells by **0.40 m** (their entry wall sits
at z ∈ [−0.40, 0]). One shared `RoomContract.WALL_ALLOWANCE` = one wall
thickness + tolerance now binds both, the audit reads EVERY mesh rather
than furniture only, and `ShellValidator` delegates to the same rule.

**Review is now the audit gate.** A `pending` shell's findings are
evidence for review; a shell marked `pass` that fails the contract turns
the suite red. Flipping one to `pass` today is caught immediately.

## P2 PREP — ready to accept the eight shells — landed 2026-09-01

Engineering only. **No authored room landed; Art's exporter has not run
yet** (see "what remains" below). P3 is not started.

**A. The Check/cover collision is fixed.** P1 found a Check pedestal
standing inside a crate in 2 of 4 arenas. The arena now decides where
its Checks go BEFORE it scatters anything, declares that space as a
`reserved` region — so activities and barrels avoid it too — and its
props take the first free spot near the one they rolled. The rng stream
is untouched, so a room with no conflict is byte-identical to before.
The band is built first for the same reason: `_elevation_band` already
DECLARES its deck and its ramp, so the anchor is chosen against those
rather than against a second derivation of where the band is.
`make godot-zone-audit` now measures all 15 Check pedestals of the real
Zone where `ZoneController` will really put them.

**B. `exit_yaw`.** `ContentEntry.exit_yaw`, `{-90, 0, +90}` only,
mirrored in `content_registry.gd` and `room_contract.gd`, emitted by
`_from_authored_scene`, consumed by `ZoneBuilder` AFTER the room is
placed and overlap-guarded — so the turn steers only what comes next.
Absent or 0 is straight through, which is what every room did before.
**The sign is Art's and was expensive: a shell leaving through its +X
wall turns the chain +90 and is the LEFT corner.**

**C. `floors=4`.** `ContentEntry.fits_floors` names the tower floor
counts a shell was BUILT for; empty means it does not care. A shell that
does not fit is not used and the permanent procedural builder makes the
room — there is no arm anywhere that stretches one. Bounds come from
`constants.TOWER_MIN_FLOORS/MAX`, which the schema, both validators and
GDScript all read.

**D. Size/intent.** No thresholds were invented. `size_class` steers
WHICH shell is offered and nothing else; `intent` is read by nothing;
`cost` never reaches `room_value`. A source-reading test keeps all three
that way. **One owner taste call remains open** — see NEXT_STEPS.

**E.** `spawn`/`objective`/`secret`/`vista`/`presentation` socket kinds
still have no live consumer. Untouched, recorded as deferred cleanup:
the eight shells do not need them.

## P1 — ROOM CONTRACT PARITY + THE GEOMETRIC AUDIT — landed 2026-09-01

The first slice of the adopted ROOM_ARCHITECTURE_STUDY hybrid (PR #7,
`a63220f`). SMALL/MEDIUM/LARGE is the active size vocabulary;
MICRO/MASSIVE are deferred, not retired; F3 is NOT integrated. **P2 and
P3 are not started and need their own approval.**

The asymmetry it closes: `ChamberBuilders` and `_from_authored_scene`
both answer "build me this chamber", and the authored one answered with
**no `sockets` key at all** — no cover, no barrels, no reserved regions,
nowhere to stand — so `Activities` flat-solved against its bounding box.
That is the defect `552469d` closed for `platform_path`, waiting in the
one path no Zone takes yet.

Three pieces:

* **`room_contract.gd`** — the room OUTPUT written down. Required keys,
  a CLOSED socket vocabulary (`stand`, `reserved`, `cover`, `reactive`,
  `enemy_high`, `access`), each tied to a consumer that runs today, plus
  optional `traversal` in `TraversalSegment`'s own shape. Structure only.
* **`room_audit.gd`** — the same claims measured with rays, boxes and
  the player's own capsule. **Author-declared metadata is a claim;
  Godot measurement is authority.** It refuses to report a clean sheet
  for a room outside the scene tree, because a probe with nothing to hit
  comes back clean.
* **`make godot-room-contract`** — ONE suite over both producers, in CI.
  Per-producer suites inherit the blind spot of the fix they protect;
  this project has watched that happen three times.

Schema (mirrored into `content_registry.gd` the same commit): a
`Surface` model and `ContentEntry.surfaces`; `Socket.kind` gains the
three runtime kinds `cover`/`reactive`/`enemy_high`; `Socket.surface_id`.
An authored room shell that declares no surfaces is refused; a
`procedural_fallback` entry is exempt, and the procedural route stays
permanently legal.

`ShellValidator` now keeps a promise `content.py` has always made in
prose and nothing kept: measured mesh AABBs against the declared `size`
envelope.

**Zero player-facing change, verified**: `zone_digest 6e8d83d0f3ec088b`
and the real-Zone audit are unchanged (0 failures, 0 notes), and no
committed registry entry, fixture or baseline moved.

One defect the audit FOUND and P1 does not fix: an arena scatters three
cover boxes at random through the middle half of the room and
`reward_position` is a fixed point on the centre line, so a Check
pedestal can stand inside a crate (2 of 4 arenas in the suite).
`zone_controller.gd:150` places it with no clearance test. Reported,
pinned so it cannot grow, not fixed — moving either would be a
player-facing change.

**Playtest-hygiene follow-up, same contract, one kind wider.** The
`platform_path` defect from `docs/ZONE_ACTIVITY_AUDIT.md` §4 is closed.
The row solver reads a room's width and depth, and a `platform_path` has
no floor across them — its bounds reach forty metres into a kill pit, so
19 elements were standing on nothing. `platform_path` now emits a
`stand` socket per surface it builds (start ledge, each island, end
ledge) and the solver places onto one chosen surface per activity.
Islands are refused by measurement, not by name: what is left beside an
element must be at least `BRUTE_LANE`, and 2.5 m of mandatory route over
a pit cannot give it. The real-Zone audit is **0 failures, 0 notes**,
`no_ground_under` is now a structural failure rather than a note, and
every arena element is byte-identical to `2699805`.

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
