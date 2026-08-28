# Archipepsi art asset spec

**Audience:** anyone authoring a model, scene or material for Archipepsi in
Blender (or any DCC) and adding it to the game.

**The one rule this document serves** (`docs/design-packet-v0.8/AUTHORED_CONTENT.md`):

> DEVELOPERS AUTHOR THE ALPHABET. GODOT ENFORCES THE GRAMMAR. EPSILON WRITES SENTENCES.

You are making alphabet. Adding an asset is **a scene plus a manifest
entry**. It is never a change to generator logic, and it never requires
touching Python, the bridge, or anything Epsilon can see.

An asset a developer builds with Claude at their desk is ordinary
first-party content once it is reproducibly authored, reviewed, approved,
committed and registered under a stable id (`OWNER_DECISIONS.md` D2).
What stays forbidden is **runtime** generation — Epsilon producing a
mesh, texture, shader, audio clip or resource path while the game runs.
The boundary is about when and by whom, not about which tool.

Every number below is read from the code, not invented. Where a constant is
named, that constant is the authority and this document is the description —
if they ever disagree, the code is right and this file is stale.

---

## 1. Units and scale

**One Godot unit is one metre.** Set Blender's unit scale to 1.0 and export
at 1.0; do not "scale to fit" in the Godot import dialog, because the
registry's declared `size` is checked against real bounds and a scaled
import makes that declaration a lie.

The player is the ruler. Everything a human walks through is measured
against these (`godot/scripts/autoload/constants.gd`):

| Constant | Value | What it means for you |
|---|---|---|
| `PLAYER_HEIGHT` | 1.8 m | Capsule height. |
| `PLAYER_RADIUS` | 0.4 m | Capsule radius — 0.8 m across. |
| `PLAYER_EYE_HEIGHT` | 1.6 m | Camera height. **Put anything meant to be read at eye level here.** |
| `WALK_SPEED` | 7.0 m/s | Fast. Corridors that feel roomy at a walk feel tight at this speed. |
| `JUMP_APEX_HEIGHT` | ~1.33 m | Highest a base-kit player reaches. A ledge above this is Echo-only. |
| `JUMP_FLAT_REACH` | ~4.67 m | Furthest a base-kit player clears flat. |
| `SAFE_BASE_JUMP_GAP` | 2.6 m | The gap a mandatory path may use. **Never exceed this on a required route.** |

`SAFE_BASE_JUMP_GAP` is invariant **I3/I4** made concrete: the base kit must
clear every mandatory path. A required jump wider than 2.6 m is not a
difficulty choice, it is a seed that cannot be completed.

### Architectural dimensions

From `godot/scripts/generation/chamber_builders.gd` and `zone_builder.gd`:

| Constant | Value |
|---|---|
| `DOOR_WIDTH` | 2.4 m |
| `DOOR_HEIGHT` | 3.2 m |
| `CORRIDOR_HEIGHT` | 3.6 m |
| `WALL_THICKNESS` | 0.4 m |
| `CONNECTOR_LENGTH` | 5.0 m |
| `CONNECTOR_WIDTH` | 4.0 m |

A doorway that does not match `DOOR_WIDTH` × `DOOR_HEIGHT` will not be
refused outright — sockets carry their own `width`/`height` and the grammar
checks fit — but anything intended to interoperate with existing placeholder
geometry should use these.

---

## 2. Axes, origin and pivot

Godot is **Y-up, right-handed**. Blender is Z-up; the glTF exporter converts
for you, so author Z-up in Blender and let the exporter do it. Do not
pre-rotate your mesh to compensate — that produces a model whose object
transform is identity but whose geometry is lying.

**Level flow is +Z.** This is the convention `ZoneBuilder` chains on:

```
        entry face                              exit face
        (local z = 0)                           (local z = depth)
            |                                       |
            v                                       v
    ........+=======================================+........
            |                                       |
            |          room interior                |   --->  +Z
            |                                       |
    ........+=======================================+........
              ^
              local origin (0, 0, 0) sits ON the entry face,
              ON the floor, centred left-to-right
```

So, for a **room shell or connector**:

- **Origin** at the centre of the entry doorway's floor line: `x` centred on
  the opening, `y = 0` at the walkable floor, `z = 0` on the entry face.
- The room extends toward **+Z**. Your `exit_offset` is therefore
  `(0, rise, depth)` — the vector from the entry origin to the *next* piece's
  entry origin. Non-zero `rise` is fine (`platform_path` and `tower` both use
  it); the chain follows it.
- **Floor is exactly y = 0.** Not y = 0.02 "so it doesn't z-fight". Spawn
  points, clearance checks and reachability all assume the walkable surface
  is the local zero plane.

Note the nuance that has bitten before: a Godot `Node3D`'s own *front* is
`-Z`, so a character facing down the corridor is yawed 180° from identity
(see the spawn transform in `zone_builder.gd`). That applies to **things that
face**, not to the module's flow direction. Module local space flows +Z.
Don't "fix" one by rotating the other.

For a **prop**: origin at the point where it meets the surface it sits on
(base centre for a floor prop, mount face for a wall prop), oriented so its
visual front faces `-Z` — the Godot convention, so `look_at` works.

Apply all transforms before export. A prop with a non-uniform object scale
baked into its transform will have the wrong collision.

---

## 3. Collision

**Author collision. Never rely on an auto-generated trimesh for anything a
player touches.**

- Walkable floors, walls and ceilings: convex or box shapes. Trimesh
  (`StaticBody3D` + `ConcavePolygonShape3D`) is acceptable only for
  decorative geometry the player cannot stand on.
- Give collision its own child nodes; do not put a `CollisionShape3D`'s
  geometry in the visual mesh.
- **Collision is simpler than the visual mesh, and never larger than it.**
  A player who collides with something they can see through will report a
  bug; a player who walks through a wall will report a worse one.
- Godot's `-col` / `-convcol` / `-colonly` mesh-name suffixes work on import
  and are the least error-prone route. Use `-colonly` for invisible blockers.

**The S18 rule, stated here because it is your rule too:** swapping a
visual must not change a hitbox, a reachability, or anything AP believes.
Practically, that means if you replace a placeholder shell with an authored
one, the *collision* must preserve the walkable envelope, and the registry
entry's `size` and `clearances` must still be true. There is a test for this;
it will catch you, but it is faster to just not do it.

---

## 4. Naming

Asset ids are the contract. Nothing outside a manifest ever names a file, and
**Epsilon never sees a path at all** — it composes with semantic ids and tags
only.

**Content ids** (the `id` field): `snake_case`, prefixed by category.

| Category | Level | Prefix | Example |
|---|---|---|---|
| `prop` | 0 | `prop_` | `prop_crate_stack` |
| `module` | 1 | `mod_` | `mod_wall_panel_ribbed` |
| `connector` | 1 | `connector_` | `connector_straight_proc` |
| `fixture` | 2 | `fix_` | `fix_terminal_alcove` |
| `affordance_visual` | 2 | `afv_` | `afv_pressure_plate` |
| `interactable` | 0–2 | `int_` | `int_check_pedestal` |
| `room_shell` | 3 | `shell_` | `shell_arena_proc` |
| `landmark` | 4 | `mark_` | `mark_hub_spire` |
| `cluster` | 2 | `cluster_` | `cluster_survey_station` |

A **`cluster`** is a composed dressing or storytelling group that reads as
one thing — bigger than a prop, smaller than a room. It is the one
category that must declare a `footprint`, because `PROP_FOOTPRINT` is
1.4 m and an L2 station does not fit in it:

```json
"footprint": {
  "anchor": "floor_wall",   // or floor_corner, wall, ceiling
  "width": 4.0,             // along the wall it hangs on, max 6.0
  "height": 2.4,            // max 4.0
  "depth": 1.2,             // out from the wall, max 2.5
  "mount_height": 0.0       // 0 on the floor; where the underside hangs
}                           //   otherwise, and at least 2.75
```

There is no free-standing floor anchor: a cluster in the middle of a room
sits on the mandatory path. A colliding floor cluster costs
`depth + 0.4 m` of walking lane and what remains must still admit the
widest actor, so a cluster legal in an arena may not be legal in a
corridor — ask `constants.cluster_placement_errors()` before building.
See `docs/ART_INTEGRATION.md`.

An id is **permanent and globally unique**. It is what a save, a manifest and
a fallback chain refer to. Renaming one is a breaking change; add a new id
and set the old one's `fallback` instead.

**Files.** Scenes live under `res://content/` and nowhere else — the registry
refuses any other path, in both Godot and Python. Match the file stem to the
id: `res://content/shells/shell_arena_ruined.tscn`.

`res://content/test_fixtures/` is **not content**. It holds the deliberately
dumbest legal scenes, used only by `make godot-content` to exercise the
authored-scene path. No shipped manifest references them and they never
reach a zone. Do not put real assets there, and do not model to their
example.

**Nodes inside a scene.** `PascalCase` for structural nodes (`Floor`,
`WallNorth`, `CeilingTrim`), and sockets named exactly as their manifest
`name` (see below) so a human reading the scene tree can find them.

---

## 5. Sockets

A socket is a named point where the grammar may join something. It is the
only reason a room can be composed rather than hand-placed.

Fields (`bridge/archipepsi_bridge/schemas/content.py`, `class Socket`):

| Field | Meaning |
|---|---|
| `name` | 2+ chars, unique within the entry. `entry`, `exit`, `end_a`, `end_b`, `side_north`. |
| `kind` | `doorway`, `corridor_end`, `affordance`, `spawn`, … |
| `position` | `[x, y, z]` in module local space. |
| `yaw` | Degrees. Which way the opening faces. |
| `width`, `height` | The clear opening. **Required for `doorway` and `corridor_end`** — two openings cannot be checked for fit without them, and the fit check is the whole point. |

**Every `room_shell` and `connector` must declare at least one `doorway` or
`corridor_end` socket.** One with none is refused at load: nothing could ever
connect to it, so it could only ever appear as an unreachable island.

Naming convention: a piece with a direction uses `entry` / `exit`; a
symmetric piece uses `end_a` / `end_b`. Put a matching empty/`Marker3D` in
the `.tscn` under the same name, at the same transform, so the manifest can
be checked against the scene by eye.

---

## 6. Volumes

`volumes` declare space the game reasons about but does not render:

- `player_entry` — safe to materialise a player in. Must be clear of
  geometry for a 0.8 m × 1.8 m capsule.
- `enemy_spawn` — safe to materialise an enemy in.
- `objective` — where a check, portal or set piece is meant to go.
- `no_build` — keep procedural decoration out (sightlines, a set piece's
  breathing room).

Declared as `center` + `size` in module local space.

---

## 7. Materials

**Do not ship your own texture set without asking.** Archipepsi recolours
everything per theme at runtime through
`godot/scripts/generation/theme_materials.gd`, which offers `floor_mat`,
`wall_mat`, `accent_mat`, `trim_mat`, `hazard_mat` and `glow_material`.
A model with baked-in colour will look correct in exactly one theme and
wrong in the other seven.

Author with **material slots named for their role** — `floor`, `wall`,
`accent`, `trim`, `hazard` — and leave them as flat placeholder colours.

> **Not wired yet (S19).** Slot-name → themed-material assignment is the
> agreed convention but no loader reads it today; procedural geometry gets
> its materials directly from `ThemeMaterials`. Author to the convention
> anyway: it costs nothing now and is what S19 will bind to.

If an asset genuinely needs a unique authored material (a landmark, a hero
prop), that is fine and expected — say so in the manifest's `semantic_tags`
so it is not silently re-themed.

**Epsilon may not generate textures, audio, shaders, particle programs or
light placements, and may not supply resource paths.** That boundary is
enforced in code; it is stated here so you know the material vocabulary is
yours, permanently.

---

## 8. Lighting

Author geometry, not lights. Lighting is per-theme
(`light_color`, `light_energy`, `void_color` and the zone `WorldEnvironment`).

If a fixture is *meant* to be a light source, model the emissive geometry and
tag it; the placement logic attaches the actual `Light3D`. A `.tscn` with
hand-placed `OmniLight3D`s will be inconsistent with every theme and will
blow the light budget in a large zone.

---

## 9. LOD and performance

Godot 4 generates LODs automatically for imported meshes; leave **Generate
LODs on** and do not hand-author LOD chains unless a specific asset profiles
badly.

Declare `cost` in the manifest (0–1000, default 1) as a rough relative
expense.

> **Not wired yet.** `cost` is validated but nothing spends it. It exists so
> placement can be given a budget without a manifest migration later. An
> honest number now is worth more than a low one.

Rough targets, not hard gates: a prop under ~2k tris, a module under ~10k, a
room shell under ~50k including its props. A landmark may be whatever it
needs to be — there is one on screen.

---

## 10. Animation

Name animation clips by function, lowercase with underscores: `idle`,
`open`, `close`, `activate`, `hit`, `death`.

> **Not wired yet (S17).** The interactable scene contracts that will call
> these clips do not exist. The vocabulary is fixed now so authored assets
> made before S17 do not need renaming after it; a clip named
> `Armature|OpenAction` will not be found once they do.

Loop `idle`; do not loop one-shots. Keep the rest pose as the state the
object is in when the player first sees it.

---

## 11. Import settings

- **Format:** glTF 2.0 (`.glb` preferred — single file, no missing textures).
- Godot generates a `.import` next to the file. **Commit it.** It carries
  your import choices; without it another machine re-imports with defaults
  and gets different collision.
- Leave **Generate LODs** on, leave **Generate Tangents** on for anything
  with a normal map.
- Set **Root Type** to the node you actually want (`StaticBody3D` for a solid
  prop) rather than wrapping it later in code.
- Do not enable **Scale Mesh** — see §1.

---

## 12. How to add an asset without touching generator logic

This is the whole workflow. If you find yourself editing a `.gd` file that
is not your own scene's script, stop — that means the contract is missing
something, and the contract should be extended rather than worked around.

1. **Model it** to §§1–3.
2. **Save the scene** under `res://content/<category>/<id>.tscn`.
3. **Add a manifest entry.** Either extend a pack under
   `godot/content/registry/*.json` or add a new `.json` there. Minimum:

   ```json
   {
     "schema_version": 1,
     "pack": "my_pack",
     "entries": [
       {
         "id": "shell_arena_ruined",
         "level": 3,
         "category": "room_shell",
         "display_name": "Ruined Arena",
         "scene": "res://content/shells/shell_arena_ruined.tscn",
         "theme_tags": ["ruined", "industrial"],
         "semantic_tags": ["arena", "combat", "open"],
         "size": [24.0, 8.0, 24.0],
         "sockets": [
           {"name": "entry", "kind": "doorway",
            "position": [0.0, 0.0, 0.0], "yaw": 180.0,
            "width": 2.4, "height": 3.2},
           {"name": "exit", "kind": "doorway",
            "position": [0.0, 0.0, 24.0], "yaw": 0.0,
            "width": 2.4, "height": 3.2}
         ],
         "volumes": [
           {"name": "arena_floor", "kind": "enemy_spawn",
            "center": [0.0, 1.0, 12.0], "size": [18.0, 2.0, 18.0]}
         ],
         "fallback": "shell_arena_proc"
       }
     ]
   }
   ```

4. **Run the checks:**

   ```
   make godot-content                     # Godot: does the scene load, does it resolve
   cd bridge && python -m pytest tests/test_content_registry.py -q   # shape
   ```

   Both must pass. They report *every* mistake in a manifest, not just the
   first, so one run should be enough to fix it.

5. **Give it a `fallback`** to the procedural placeholder it replaces. That
   is the S13 rule:

   > AUTHORED SCENE IF AVAILABLE → VALIDATED PLACEHOLDER OTHERWISE

   With a fallback set, a half-finished asset degrades to something playable
   instead of breaking a zone. Without one, it is a hole.

You never touch `chamber_builders.gd`, `zone_builder.gd`, the bridge, or
anything Epsilon reads.

---

## 13. What is a placeholder and what is authored

Everything currently in `godot/content/registry/legacy_procedural.json` is
marked `"procedural_fallback": true`. That flag is not decoration — it is the
registry stating, honestly, that the entry is generated geometry and not
authored content. An entry may be **one or the other**, never both, and the
loader refuses an entry that claims a scene *and* the flag.

Existing primitive geometry is a **valid testable placeholder** until real
authored assets replace it. It is not something to be embarrassed about and
it is not something to dress up procedurally into pretending to be final art.
Replacing a placeholder means adding an authored entry that falls back to it,
proving the two suites green, and deleting nothing.
