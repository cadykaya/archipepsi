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

**Still blocked, and none of it is engineering's:** telegraphs for melee
and ranged (they have no windup, and adding one changes difficulty —
combat decision); behaviour for the seven enveloped roles (same);
`arch_affordance_socket` (art has not chosen between a visible mount and
floor placement); neutral `concrete_facility` dressing (req 18);
`objective_marker` / `signage_module` navigation language;
`challenge_marker`.

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
