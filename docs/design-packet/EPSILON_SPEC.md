# Archipepsi — Epsilon Contract


This is the authority for runtime generation. Epsilon is a designer operating inside an allowlisted data contract, never an unrestricted runtime programmer.

The provider may change from Claude to a local model later. The normalized request/response contracts must not.


> **Authority note:** See `README.md` for conflict/precedence rules.


# 14. Generated Zone philosophy and layout contract

Epsilon should feel creative, but the engine should remain simple.

The POC uses a **linear chamber-template DSL**.

Epsilon chooses:

- target theme
- display name
- chamber sequence
- chamber parameters
- supported enemy archetypes
- supported objectives
- which already-supplied Check belongs to which chamber
- flavor text
- which owned Echoes it was inspired by

Epsilon does **not** choose world-space coordinates.

## 14.1 Chamber chaining

Every chamber constructor returns:

- an entrance transform
- an exit transform
- its generated collision/geometry bounds

The `ZoneBuilder` starts the first chamber at the origin and chains every later chamber to the prior exit, oriented generally along +Z.

The engine inserts a short connector doorway/corridor between chambers when needed.

The builder must guarantee:

- spawn is on walkable ground
- exits connect
- mandatory critical path never needs an Echo
- platform gaps stay within base jump limits
- no chamber intentionally overlaps another chamber
- Check reward objects are reachable after their objective is satisfied

This deliberately limits Epsilon’s freedom in exchange for a POC that can actually be validated.


# 15. POC chamber catalog

Only these chamber types are valid model output in v0.2.

## 15.1 `corridor`

Simple connector/traversal room.

Parameters:

- `length`: 6–30
- `width`: 4–10
- optional enemy list

No Check reward by default, though one may be placed at the exit if required by the selected location count.

---

## 15.2 `arena`

Rectangular combat room.

Parameters:

- `width`: 10–28
- `depth`: 10–28
- `wall_height`: 4–8
- enemy list
- objective: normally `kill_all`
- optional `reward_location_id`

A boss-like room is simply an `arena` containing one `brute`.

---

## 15.3 `platform_path`

Base-movement platforming room.

Parameters:

- `segment_count`: 3–8
- `gap_size`: clamped to safe base-jump range
- `vertical_step`: clamped to safe base-jump range
- optional enemy list
- objective: `platform_to_goal`
- optional `reward_location_id`

Owned mobility Echoes may make it easier or sillier, but are never mandatory.

---

## 15.4 `tower`

Vertical traversal chamber built from stairs/ramps/platforms.

Parameters:

- `floors`: 2–5
- optional enemy list
- objective: `reach_reward` or `kill_all`
- optional `reward_location_id`

The template itself guarantees a base-movement route.

---

## 15.5 `treasure_room`

Small safe reward room.

Parameters:

- optional flavor text
- exactly one `reward_location_id`

No enemies required.

---

## 15.6 Shop placement

`shop` is **not** a valid Zone chamber type in the POC.

All shop behavior occurs in the fixed Hub.

---

## 15.7 Boss placement

`arena` is **not** a separate chamber type in the POC.

Use an `arena` containing a single `brute`.


# 16. POC theme catalog

A theme is a validated palette, not generated art.

Implement at least:

- `grass_block`
- `stone_dungeon`
- `neon_city`
- `gothic_castle`
- `desert_scrap`
- `void_glitch`

Each theme defines:

- floor material
- wall material
- accent material
- sky/background
- light color/energy defaults if desired
- optional prop list

Target-game suggestions:

- Mario → `grass_block`
- Ocarina → `stone_dungeon`
- Bomb Rush Cyberfunk → `neon_city`
- Dark Souls → `gothic_castle`
- Borderlands → `desert_scrap`
- Archipepsi-native → `void_glitch`

Epsilon can deviate.

Use nearest-neighbor / pixel-friendly filtering for low-resolution texture assets.

---


# 17. Enemy catalog

Only three archetypes are required for the first autonomous implementation pass.

## 17.1 `melee`

- moves directly toward player
- short-range attack
- moderate speed
- low/moderate health

## 17.2 `ranged`

- stays still or uses extremely simple spacing behavior
- periodically fires a slow visible projectile
- low health

## 17.3 `brute`

- larger mesh/scale
- slow
- high health
- stronger melee attack
- used as POC boss

Do not block the POC on navmesh sophistication.

Direct steering plus collision recovery is acceptable.

If a generated room causes navigation problems, enemies may use simplified steering rather than requiring a perfect navigation bake.


# 18. Objective catalog

Only these mandatory objective types are required:

- `reach_reward`
- `kill_all`
- `platform_to_goal`

Rules:

### `reach_reward`

Reward becomes interactable immediately when reached.

### `kill_all`

Reward remains locked until all enemies registered to that chamber are dead.

### `platform_to_goal`

Reward becomes interactable when the player enters the goal/reward area.

Every Check must have one deterministic completion trigger.

No timed survival or switch puzzle is required in the first autonomous pass.


# 19. Zone JSON contract

This is model-facing normalized output.

The implementation must define an equivalent Pydantic model and JSON Schema.

Example:

```json
{
  "schema_version": 2,
  "zone_id": "zone_003",
  "display_name": "Cathedral of Excessive Firepower",
  "target_game": "Dark Souls III",
  "theme": "gothic_castle",
  "designer_note": "The wide arenas and vertical drops make the player's recoil-heavy shotgun fun without requiring it.",
  "featured_echo_ids": ["echo_89100004"],

  "chambers": [
    {
      "id": "c1",
      "type": "corridor",
      "length": 12.0,
      "width": 5.0,
      "enemies": []
    },
    {
      "id": "c2",
      "type": "arena",
      "width": 18.0,
      "depth": 18.0,
      "wall_height": 6.0,
      "objective": "kill_all",
      "enemies": [
        {
          "archetype": "melee",
          "count": 3
        }
      ],
      "reward_location_id": 89100012
    },
    {
      "id": "c3",
      "type": "tower",
      "floors": 3,
      "objective": "reach_reward",
      "enemies": [
        {
          "archetype": "ranged",
          "count": 2
        }
      ],
      "reward_location_id": 89100013
    }
  ]
}
```

There is intentionally **no `required_echo_ids` field in v0.2**.


# 20. Zone validation rules

Reject invalid output. Clamp only numeric values that are otherwise semantically valid.

## General

- `schema_version == 2`
- `zone_id` must exactly match request
- 1–6 chambers
- every requested AP location appears exactly once as `reward_location_id`
- no unrequested AP location appears
- no duplicate reward location IDs
- theme is allowlisted
- chamber type is allowlisted
- enemy archetype is allowlisted
- objective is allowlisted
- every `featured_echo_id` is already owned
- **no generated field can express a mandatory Echo requirement**

## Size / count limits

- corridor length: 6–30
- corridor width: 4–10
- arena width/depth: 10–28
- wall height: 4–8
- platform segments: 3–8
- platform gap: <= measured safe base-jump maximum
- tower floors: 2–5
- total enemies per Zone: <= 14
- total enemies in one chamber: <= 8
- brute count per Zone: <= 1
- text field length: <= 160 characters except `designer_note` <= 300

## Critical-path safety

The validator and template builders enforce:

- all mandatory platform gaps are base-jumpable
- tower template always has stairs/ramps/base platforms
- no Check is placed behind an Echo-only door
- no objective uses an unsupported puzzle state
- no shop or coin balance is part of Zone completion

If a model response implies otherwise in prose, prose is ignored; only validated structured fields affect gameplay.


# 21. Echo system

## 21.1 Grant rule

An Echo belongs to an **Archipepsi source location**, not merely an item name.

When a source location transitions to server-confirmed checked:

If its scouted recipient slot is **not** the Archipepsi slot:

1. AP has already/now sends the real item to the real recipient through normal server behavior.
2. Archipepsi checks for existing Echo with `source_location_id`.
3. If none exists, request Echo generation.
4. Validate once, repair once, fallback if needed.
5. Persist accepted Echo.
6. Add it to inventory.

If recipient slot **is** Archipepsi:

- no Echo is generated
- normal `ReceivedItems` handles the native Archipepsi item

Every Echo has:

`source_location_id`

This is the deduplication key.

Two different source locations containing identically named items can therefore produce two different Echoes.

---

## 21.2 Equipment rule

POC rule:

**Exactly one Echo is equipped at a time.**

All effects belonging to that Echo are active/usable according to its activation type.

There is no global stacking of passive effects from every collected Echo in v0.2.

This keeps balance and implementation understandable while still allowing unlimited Echo collection.

---

## 21.3 Echo identity

Example:

```json
{
  "schema_version": 2,
  "echo_id": "echo_89100004",
  "source_location_id": 89100004,
  "source_item_name": "Conference Call",
  "source_game": "Borderlands 2",
  "source_recipient_name": "Sage",

  "display_name": "Conference Call",
  "description": "A ridiculous shotgun interpretation with enough kick to double as movement.",

  "archetype": "weapon",
  "activation": "primary",

  "effects": [
    {
      "type": "hitscan_damage",
      "damage": 8.0,
      "pellets": 12,
      "spread_degrees": 10.0,
      "range": 35.0
    },
    {
      "type": "recoil_self",
      "force": 8.0
    },
    {
      "type": "knockback_target",
      "force": 5.0
    }
  ],

  "cooldown": 0.8,
  "tags": ["weapon", "shotgun", "recoil", "combat", "mobility"]
}
```

Accepted Echo JSON is canonical for that Campaign.


# 22. Echo archetypes and activation

POC archetypes:

- `weapon`
- `tool`
- `mobility`
- `passive`

POC activation values:

- `primary`
- `passive`

Rules:

- `primary`: pressing the primary Echo input attempts activation, subject to cooldown.
- `passive`: effects apply continuously while that Echo is the equipped Echo.
- an Echo may contain multiple compatible effects
- cooldown is defined at the Echo level
- no permanently consumable Echo exists


# 23. POC Echo effect vocabulary

Only these effect types are required in the first autonomous implementation pass.

## Active attack effects

### `hitscan_damage`

On activation:

- cast `pellets` ray(s) from camera aim
- random spread within `spread_degrees`
- damage first valid enemy hit per ray
- max distance `range`

Fields:

- `damage`
- `pellets`
- `spread_degrees`
- `range`

### `projectile_damage`

On activation:

- spawn a simple projectile from the player/camera
- travel forward
- damage first enemy hit
- despawn on hit or lifetime expiry

Fields:

- `damage`
- `speed`
- `lifetime`

---

## Active modifiers / motion

### `recoil_self`

On the same activation as an attack/tool:

- apply impulse to player opposite aim direction

Field:

- `force`

### `knockback_target`

Modifier for targets damaged by the same activation:

- apply force away from attack source

Field:

- `force`

### `dash`

On activation:

- impulse player mostly along view-forward direction
- no stamina

Field:

- `force`

### `grapple_to_surface`

On activation:

- raycast to static world geometry within range
- if hit, apply a strong pull/impulse toward hit point
- no rope simulation required

Fields:

- `range`
- `pull_force`

### `heal_self`

On activation:

- restore HP up to max

Field:

- `amount`

### `shield`

On activation:

- grant temporary absorbable shield HP

Fields:

- `amount`
- `duration`

---

## Passive effects

### `modify_gravity`

While equipped:

- multiply player gravity by `multiplier`

Field:

- `multiplier`

### `modify_speed`

While equipped:

- multiply walking speed by `multiplier`

Field:

- `multiplier`

---

## Compatibility rule

At least one of these must be true:

- Echo contains an active effect appropriate to `activation = primary`
- Echo contains a passive effect appropriate to `activation = passive`

For v0.2, do not combine passive-only effects with `activation = primary`, and do not combine attack effects with `activation = passive`.


# 24. Echo validation bounds

Use these POC bounds.

- damage: 1–25
- pellets: 1–16
- spread: 0–30 degrees
- hitscan range: 5–60
- projectile speed: 5–45
- projectile lifetime: 0.5–6 seconds
- recoil force: 0–16
- knockback force: 0–16
- dash force: 4–20
- grapple range: 5–35
- grapple pull force: 4–25
- gravity multiplier: 0.35–1.5
- speed multiplier: 0.65–1.6
- heal amount: 5–60
- shield amount: 5–80
- shield duration: 1–15 seconds
- Echo cooldown: 0.15–15 seconds
- effects per Echo: 1–3

If Epsilon requests an unsupported/invalid effect:

1. reject the whole Echo response
2. send exactly one repair request containing concise validation errors
3. if repaired response is still invalid, use fallback Echo


# 25. Echo generation request and exact model instruction

Epsilon receives:

```json
{
  "schema_version": 2,

  "source": {
    "location_id": 89100004,
    "item_name": "Conference Call",
    "source_game": "Borderlands 2",
    "recipient_name": "Sage",
    "item_flags": 1
  },

  "player_state": {
    "existing_echoes": [],
    "pepsi_keys": 0,
    "coins_available": 2
  },

  "allowed_archetypes": ["weapon", "tool", "mobility", "passive"],
  "allowed_effects": {},
  "balance_limits": {}
}
```

Use a provider prompt equivalent to:

> You are Epsilon, the procedural designer inside Archipepsi. Interpret one foreign Archipelago item as a recognizable but playful local Archipepsi Echo. You are producing data, not code. Use only the supplied archetypes, activation modes, effect names, fields, and numeric bounds. Prefer 1–3 effects. Preserve some semantic relationship to the item name and source game. It is good for an Echo to create surprising movement or combat possibilities, but it must remain understandable from its description. Do not invent APIs or mechanics. Return only one object matching the supplied schema.

Creativity modifies “how literal” the semantic interpretation is. It never changes the schema or safety bounds.


# 26. Future Zones account for owned Echoes

Every Zone request includes concise summaries of owned Echoes.

Epsilon is encouraged to:

- feature a recent Echo
- choose room shapes where that Echo is fun
- choose enemies that interact interestingly with it
- create optional easier routes for movement Echoes
- create optional secrets that become convenient with movement Echoes
- make weapon recoil useful for messing around
- vary design based on the current inventory rather than ignoring it

However, in the POC:

**Every mandatory path and mandatory objective must remain completable using base movement + the default attack.**

There are no Echo-only mandatory gates.

`featured_echo_ids` is descriptive/design metadata only.

This restriction should be reconsidered only after a traversal/reachability validator exists.


# 31. Zone generation request

Exact conceptual shape:

```json
{
  "schema_version": 2,
  "generation_id": "ExampleSeed-0-6-zone-003",

  "campaign": {
    "seed_name": "ExampleSeed",
    "slot_name": "Skyiah",
    "team": 0,
    "slot_id": 6,
    "zone_index": 3,
    "target_game": "Dark Souls III",
    "completed_zone_summaries": [
      {
        "name": "Neon Drain",
        "theme": "neon_city",
        "target_game": "Bomb Rush Cyberfunk"
      }
    ]
  },

  "player": {
    "pepsi_keys": 1,
    "coins_available": 4,
    "echoes": [
      {
        "echo_id": "echo_89100004",
        "display_name": "Conference Call",
        "archetype": "weapon",
        "activation": "primary",
        "tags": ["shotgun", "recoil", "mobility"],
        "description": "A ridiculous shotgun with severe backwards recoil."
      }
    ]
  },

  "locations": [
    {
      "location_id": 89100012,
      "location_name": "Archipepsi Check 012",
      "item_name": "Hookshot",
      "recipient_name": "Sage",
      "recipient_game": "Ocarina of Time",
      "item_flags": 1,
      "item_name_may_appear_in_player_text": false
    }
  ],

  "catalog": {
    "themes": [
      "grass_block",
      "stone_dungeon",
      "neon_city",
      "gothic_castle",
      "desert_scrap",
      "void_glitch"
    ],
    "chamber_types": [
      "corridor",
      "arena",
      "platform_path",
      "tower",
      "treasure_room"
    ],
    "enemy_archetypes": ["melee", "ranged", "brute"],
    "objectives": ["reach_reward", "kill_all", "platform_to_goal"]
  },

  "constraints": {
    "max_chambers": 6,
    "max_enemies_total": 14,
    "all_locations_must_appear_once": true,
    "critical_path_requires_echo": false
  }
}
```


# 32. Exact Epsilon Zone behavior

Use a provider system instruction equivalent to:

> You are Epsilon, the procedural level designer inside Archipepsi. You are given a small fixed set of Archipelago locations that MUST all appear exactly once in the Zone. Those location IDs were selected by deterministic game code; you may not add, remove, replace, reserve, or renumber them. Design a short blocky first-person Zone using only the supplied themes, chamber templates, enemies, objectives, and numeric fields. You are producing structured data, not executable code. Use the recipient game as strong thematic inspiration. You may use unrevealed item identity privately as design inspiration, but never place an unrevealed exact item name in player-facing text. Account for the player’s owned Echoes and make them fun to use, but every mandatory path must remain completable with base walking, base jumping, and the default attack. Prefer a coherent little videogame idea over random nonsense. Return only one schema-valid Zone object.

Quality preferences:

1. 2–5 chambers is usually enough.
2. Avoid repeating the exact same chamber type three times in a row.
3. Put at most one brute in a Zone.
4. Give each supplied Check a meaningful payoff moment.
5. If an Echo is featured, design opportunities for it without requiring it.
6. Use humor sparingly and coherently.
7. Do not explain your reasoning in the output.


# 33. Epsilon creativity setting

Add a Campaign configuration:

`epsilon_creativity`

POC values:

- `0` Conservative
- `1` Playful
- `2` Unhinged

Default:

`1`

Behavior guidance:

## Conservative

Item meaning stays recognizable.

## Playful

Item meaning stays connected but can reinterpret mechanics.

## Unhinged

Names and source concepts may be treated as semantic suggestions, but output still uses only supported game primitives.

This setting changes model instructions, not validation.

---


# 43. Generation failure handling

For each Zone or Echo request:

1. call configured Epsilon provider
2. parse returned object
3. schema + semantic validation
4. if invalid:
   - issue **one** repair request with concise validation errors
5. validate repaired result
6. if still invalid:
   - use deterministic fallback
7. save only normalized accepted data
8. log raw invalid output only in development logs
9. never crash gameplay due to malformed model output

Provider timeout target:

**60 seconds**

If provider errors/times out:

- skip repair
- use fallback
- show a subtle `EPSILON OFFLINE — FALLBACK USED` notification


# 44. Fallback Zone generator

Must exist.

It receives the same selected location set.

It produces a simple linear Zone:

```text
spawn
→ corridor
→ arena/check
→ corridor
→ platform/check
→ arena(brute)/check
→ exit
```

Theme chosen by hash/target game.

No model required.

This is both:

- failure recovery
- a test oracle for engine-side generation

---


# 45. Fallback Echo generator

Fallback must always emit one schema-valid v0.2 Echo.

Deterministic heuristics:

If lowercase item name contains:

- `conference call` -> shotgun-like hitscan, many pellets, spread, recoil
- `shotgun` -> hitscan, many pellets, spread, recoil
- `gun`, `rifle`, `pistol`, `cannon` -> hitscan or projectile weapon
- `sword`, `blade`, `knife` -> short-range-ish hitscan weapon with low range/high damage
- `hook`, `grapple` -> grapple tool
- `boot`, `shoe`, `skate` -> dash
- `wing`, `feather`, `cape` -> passive gravity modifier
- `shield`, `armor` -> shield
- `estus`, `potion`, `flask`, `food`, `heart` -> heal
- `rep` -> dash or passive speed boost
- `bomb`, `grenade`, `rocket` -> projectile weapon

Otherwise:

Use deterministic hash of:

`source_game | item_name | source_location_id`

to choose one of:

- modest hitscan weapon
- modest dash
- modest passive speed boost

Never emit unsupported effect types.


# 54. POC Echo safety rule

The v0.1 draft permitted a newly generated Zone to hard-require an already-owned Echo.

**That is removed from the POC.**

Reason:

The schema validator can verify ownership, but it cannot yet prove that arbitrary generated traversal geometry is genuinely solvable with a grapple, recoil weapon, gravity modifier, etc.

Therefore:

- mandatory Zone routes use base movement only
- mandatory combat can always be completed with Pepsi Pop
- owned Echoes still strongly influence design
- Echoes may provide optional shortcuts, combat advantages, faster traversal, and secrets

Hard Echo gates become a future feature after the project has a mechanical reachability validator or much more constrained gate templates.


# 69. Local Epsilon migration strategy

The POC must collect useful training/evaluation artifacts.

For every model generation, optionally save a development log containing:

- normalized input request
- raw provider output
- validation errors
- repaired output
- accepted normalized output
- whether fallback was required
- player rating later if implemented

Do NOT include secrets.

These records become:

- benchmark cases
- prompt regression tests
- possible future fine-tuning data where legally/contractually appropriate
- evidence for what intelligence the local model actually needs

The local model succeeds when it can satisfy the **same Zone and Echo contracts**.

No redesign of the game should be required.

---
