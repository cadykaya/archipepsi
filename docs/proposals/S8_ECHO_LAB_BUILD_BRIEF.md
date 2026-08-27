# S8 Echo Lab — implementation brief

> **Status:** non-authoritative implementation prep, authored in parallel by ChatGPT / GPT-5.6 Sol.
> **Authority:** `docs/design-packet-v0.8/` and executable schemas/code always win. If S7 changes an interface named here, adapt this brief rather than preserving the wording.
> **Branch basis:** S6 completion (`9a766ca`). This file is deliberately isolated from the active S7 implementation branch.

## Purpose

S8 should turn the mechanics already shipped in S2–S7 into something the player can understand by touching it. The Echo Lab is a permanent Hub chamber where a newly acquired Action, Trait, Resource, Rule, Link, Status, upgrade, merge, or family evolution can be tested immediately without waiting for a generated Zone that happens to expose the right geometry or enemy state.

The contract is intentionally small: a target dummy, tall wall, long runway, gap, damage source, and moving target. The chamber grows when later vocabulary unlocks. It must never own Archipelago truth, allocate a Check, create a fake Check, send a location, or become required progression.

The useful mental model is **a deterministic instrument panel for the build**, not a second game mode.

## Non-negotiable boundaries

- The Lab lives in / is entered from the Hub. It is not a generated Zone and must not consume Zone allocation state.
- Entering, testing, resetting, dying/falling, or leaving the Lab must not send AP location intents or mutate checked-location truth.
- No Lab fixture is a Check, AP item, Signal Key, Epsilon Coin, or Echo.
- No Epsilon provider call is required to construct the Lab. Its geometry and fixture behavior are deterministic game code.
- The player tests the **same folded Mechanics and S7 loadout** used in real play. Do not build a second Echo runtime for the Lab.
- Lab-local health, target state, cooldown experiments, moving-target phase, and fixture toggles are transient. Do not invent persistent campaign truth for them.
- A reset may restore a clean testing state, but must not rewrite the interpretation log, component provenance, Mk levels, slot choices, or other earned build state.
- Base movement must always be enough to leave the Lab. No Echo can trap the player in it.

## Room grammar

A single readable chamber is preferable to a maze. Suggested topology, not normative dimensions:

```text
                         [ TALL WALL ]
                              |
                              |
[ HUB DOOR ]----[ RESET / INFO PAD ]----[ TARGET DUMMY ]
                         |          \
                         |           \----[ MOVING TARGET TRACK ]
                         |
                    [ LONG RUNWAY ]====================>
                         |
                      [ GAP ]
                         |
                  [ SAFE RETURN PIT ]

                 [ DAMAGE SOURCE ] off to one side
```

The important property is **visual legibility**: from the entrance, the player can infer where to test distance, height, movement, damage, statuses, defense, and recovery.

## Core S8 fixtures

### 1. Target dummy

Use the real combat/status interfaces wherever possible. It should:

- accept player Action damage and status application;
- expose enough feedback to tell whether damage/status/mark/burn/etc. happened;
- be unable to die permanently — either clamp to 1 HP, respawn immediately, or reset after a short deterministic delay;
- clear its temporary statuses on Lab reset;
- never emit `kill` unless the production contract specifically wants a kill-testing target. If kill rules need test coverage, provide a separate explicit kill/reset control rather than making ordinary dummy shooting farm events accidentally.

**Reason:** rules such as `kill -> fills resource` make an endlessly respawning target mechanically meaningful. That is useful only when deliberate; accidental kill-event farming in the Hub makes the Lab alter the build's economy rather than inspect it.

### 2. Tall wall

A broad vertical surface for:

- wall kick;
- blink collision/clearance behavior;
- grapple-to-surface / swing geometry;
- recoil or impulse height experiments;
- future S9 surface affordance overlays.

Provide floor markings or simple height bands if cheap. The Lab should answer “how high did that send me?” without requiring a debug overlay.

### 3. Long runway

A straight, obstruction-free lane for:

- dash / air dash distance;
- move-speed traits and resource-scaled speed;
- recoil movement;
- glide/hover carry;
- momentum-feeling builds;
- future timed challenge fixtures.

Simple distance ticks on the floor are enough. Avoid a bespoke measurement subsystem unless the game already has one.

### 4. Gap + safe return

A deliberately obvious gap for:

- double jump;
- hover/glide;
- grapple recovery;
- blink-to-surface;
- air-dash timing.

Failure should be cheap: a trigger/kill plane returns the player to a known Lab recovery point without touching campaign progression. Do not make the test walk back through the Hub.

### 5. Damage source

A clearly telegraphed, player-activated hazard for:

- shield/block/parry;
- `damage_taken` rules;
- low-health edges;
- regen/heal;
- cleanse / negative status behavior;
- damage-taken traits.

Prefer an **armed/disarmed control** over continuous ambient damage. A Lab that hurts the player simply for standing in it becomes annoying once passive rules exist.

The hazard should use the same production damage entry point as enemies so `damage_taken`, shields, block, status multipliers and I3/I7 behavior are genuinely exercised.

### 6. Moving target

A deterministic back-and-forth target for:

- hitscan/projectile leading;
- beam tracking;
- charge/burst timing;
- grapple-pull-target if legal for its target class;
- scan/mark;
- projectile gravity/bounce experimentation.

Movement should be simple and repeatable. The goal is comparison, not enemy AI.

## Reset semantics

A single obvious **RESET LAB** interaction should return transient test state to baseline:

- player HP/shield/statuses -> safe test baseline;
- Lab-created target HP/statuses -> baseline;
- moving target -> origin;
- Lab fixture toggles -> default;
- falling player -> recovery point;
- Action cooldowns and Resource current values -> use the project's existing Zone-entry/reset semantics if they can be invoked without inventing a second truth source.

Do **not** reset:

- interpretation log;
- folded ownership;
- family/Mk/provenance;
- S7 slot/favourite choices;
- AP receive/check state;
- campaign/Hub progression.

If the existing runtime has no clean public reset boundary for cooldowns/resources, expose one in the production runtime and have both Lab and Zone-entry code call it. Do not special-case internal fields in the Lab.

## “The Lab grows” seam

S8 should establish an append-only fixture registry or equivalent seam so S9 does not require a Lab rewrite.

At S8, ship the six core fixtures above. Later vocabulary may activate additional fixtures such as:

- water traversal -> water volume;
- grapple affordance -> explicit anchor fixture(s);
- rail/grind -> rail lane;
- wind interaction -> wind tunnel;
- breakable surfaces -> resettable breakable wall;
- bounce -> bounce pad;
- moving-platform capability -> dedicated moving platform fixture.

A fixture appearing later should be a deterministic consequence of owned capability/mechanics state, not a provider deciding Hub geometry.

The contract's player-facing beat is worth preserving:

```text
NEW MECHANIC DETECTED — TEST CHAMBER UPDATED

EPSILON: YOU ASKED WHAT IT DOES.
         THE WALL IS RIGHT THERE.
```

Do not spam this on every reload. If S8 has no existing “new since last seen” persistence that can safely support one-time notifications, make the message session-local rather than adding new campaign persistence just for a joke.

## S7 integration points to resolve after S7 lands

Do not guess these on the S6 branch. When implementing S8 from the live branch, explicitly locate the S7 public interfaces for:

1. reading all four slotted Actions;
2. invoking the same ActionRunner used in Zones;
3. reading favourites/comparison state if the Lab surfaces a quick swap UI;
4. checking `requires_equipped` traits through the normal stat stack;
5. resetting transient action cooldown/resource state without changing loadout;
6. routing Lab input through the same input bindings as ordinary play.

The Lab should contain almost no knowledge of component internals. It gives the existing runtime useful things to hit, cross, climb, survive, and measure.

## Suggested Godot ownership

Names are suggestions only; match the live project conventions after S7.

```text
godot/
  scenes/hub/
    echo_lab.tscn
  scripts/hub/
    echo_lab.gd              # fixture visibility, reset orchestration
    lab_target_dummy.gd      # thin adapter onto production damage/status API
    lab_damage_source.gd     # thin adapter onto production damage API
    lab_moving_target.gd     # deterministic motion only
  tests/
    ... lab driver / test entrypoint ...
```

Avoid cloning combat code into these scripts. If the dummy requires duplicate damage/status logic, that is evidence the production interface needs a reusable target component first.

## Proposed `make godot-lab` acceptance suite

The suite should boot the real project/autoloads, as the other Godot contract suites do, and prove at minimum:

1. The Lab scene instantiates and every core fixture is reachable/present.
2. Entering/leaving/resetting the Lab emits **no AP Check/location intent** and does not change campaign checked-location state.
3. A production damage Action can damage the dummy through the same path used on enemies.
4. A production status can be applied to and reset from the dummy.
5. The damage source reaches the player's normal production damage path and can exercise shield/block/status/`damage_taken` behavior rather than modifying HP directly.
6. Falling into the gap returns the player safely without campaign mutation.
7. Reset clears Lab-transient player/fixture state but preserves folded Mechanics and S7 loadout.
8. Moving-target motion is deterministic for a fixed step sequence.
9. The Lab works with **zero Echoes** / base kit, so a fresh campaign can always enter and leave it.
10. A representative mobility Action and representative combat Action can be exercised without constructing a generated Zone.

Add a vacuity guard: the suite must prove it actually caused at least one real damage/status/action transition. A test that only checked node existence is not enough.

## Integration-run value

Once S8 lands, extend the existing full 12-zone integration run only if it can do so cheaply. A useful end-to-end assertion would be:

- campaign owns at least one Action;
- enter Lab from Hub;
- exercise one currently slotted Action against a fixture;
- return to Hub;
- campaign interpretation/fold/check truth is unchanged by the visit.

Do not turn the full integration run into a fixture-by-fixture Lab test; that belongs in `godot-lab`.

## Implementation order

1. Add deterministic Lab room + Hub entrance/return path with **no mechanics-specific fixture behavior yet**; prove no AP/campaign mutation.
2. Add reset/recovery boundary.
3. Add dummy and moving target using production target interfaces.
4. Add wall/runway/gap geometry.
5. Add damage source through production player-damage path.
6. Add the `godot-lab` suite with vacuity guards.
7. Only then add vocabulary-driven fixture visibility/update messaging.
8. Run all currently applicable suites and full integration before declaring S8 complete.

This order leaves a usable Lab even if the later “grows with vocabulary” flourish uncovers an interface problem.

## Explicit non-goals for S8

Do not pull S9 forward accidentally. S8 should **not** implement:

- the S9 Affordance capability registry / generator grammar;
- local-reward persistence/catalog behavior;
- Info readout vocabulary;
- `pull_pickup` (still S9-gated);
- rail/water/wind/breakable mechanics that do not yet exist;
- deployables;
- a new provider prompt/pipeline (S10);
- AP rewards or progression inside the Lab.

S8 is finished when the existing vocabulary has a safe, deterministic place to be understood — not when every future fixture exists.

## Review note for Opus

This branch intentionally contains only this proposal so it cannot step on S7. After S7 is complete, read this brief against the live interfaces and the authoritative v0.8 packet. Cherry-pick the document if useful, or simply use it as a build/test checklist. **Do not merge implementation assumptions merely because they are written here.**
