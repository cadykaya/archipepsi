# ASSET AUTHORING — how an Archipepsi asset is made

Everything an author needs to build, verify and commit an asset. The *why*
is in [`ART_BIBLE.md`](ART_BIBLE.md); this is the *how*, and every rule here
exists because getting it wrong is invisible until it is expensive.

---

## 1. Getting a toolchain

Nothing is pre-installed and the sandbox is wiped between sessions.

```sh
mkdir -p .tools && cd .tools
curl -sSL -o blender.tar.xz \
  https://download.blender.org/release/Blender4.5/blender-4.5.9-linux-x64.tar.xz
tar -xf blender.tar.xz && mv blender-4.5.9-linux-x64 blender && rm blender.tar.xz

curl -sSL -o godot.zip \
  https://github.com/godotengine/godot/releases/download/4.5.1-stable/Godot_v4.5.1-stable_linux.x86_64.zip
unzip -oq godot.zip && chmod +x Godot_v4.5.1-stable_linux.x86_64
mv Godot_v4.5.1-stable_linux.x86_64 godot && rm godot.zip
```

Blender **4.5.9 LTS** and Godot **4.5.1 stable (f62fdbde1)** — the exact
versions `DESIGN.md` §20 and `godot/project.godot` name. `.tools/` is
gitignored.

---

## 2. Units, axes, origins

| | |
| --- | --- |
| **Units** | Metres. `scene.unit_settings.scale_length = 1.0`. Godot agrees. |
| **Build axes (Blender)** | +X right (width) · +Y forward (depth, the direction a Zone chains along) · **+Z up** |
| **Export** | `export_yup=True`, so Godot receives +Y up and +Z forward. Build in Z-up and do not think about it again. |
| **Scale** | 1:1. Never scale an object to fit; rebuild it at the right size, or the measured texel density lies. |

### Origins — the anchor system

**An asset declares where its origin is, and that declaration is not
bookkeeping.** Getting it wrong is invisible in every turntable shot and
catastrophic in a room: Batch 001's first composed room put the pipe runs at
ankle height and hid every ceiling downstand *above* the ceiling, because a
single `set_origin_floor_centre` had been applied to everything.

`common.set_origin(obj, anchor)`:

| anchor | Origin at | For |
| --- | --- | --- |
| `floor` | X/Y centred, lowest point at Z 0 | Anything standing on the ground: crates, terminals, wall panels, doorways |
| `ceiling` | X/Y centred, **highest** point at Z 0 | Anything hanging: ceiling bays, lights, grapple anchors. The asset occupies negative Z |
| `wall` | X centred, lowest point at Z 0, **back face at Y 0** | Anything bolted flush to a wall: signs, boxes |
| `module_floor` | X/Y centred, **Z untouched** | A module whose height within its bay is part of what it is — a pipe run at 2.55 m |
| `centre` | All three centred | Rarely right; use deliberately |

The anchor is recorded in every asset's manifest entry. A placer never has
to guess.

**Set the origin BEFORE projecting UVs.** World-planar projection reads
local coordinates, so an origin set afterwards bakes the build position into
the texture and two modules built at different heights tile with the grain
offset.

---

## 3. Naming and asset IDs

```
<family>_<name>[_<variant>]
```

Lowercase, underscores, no spaces, no capitals, matching the ID pattern the
zone schema already enforces for its own IDs (`^[a-z0-9_]+$`).

| Family prefix | For |
| --- | --- |
| `arch_` | L1 architectural modules |
| `prop_` | L0 props and dressing |
| `check_` | Check object concepts and variants |
| `epsilon_` | Epsilon presence |
| `portal_` | Portal and transition frames |
| `enemy_<archetype>_` | Enemy models |
| `anchor_`, `rail_`, `bounce_`, … | §13 affordance fixtures, one prefix per tag |
| `shell_` | L3 room shells |
| `land_` | L4 landmarks and set pieces |
| `theme_<theme>_<role>` | Theme material textures |

A **stable asset ID** is the file's path stem: `prop_crate`,
`arch_wall_panel`, `check_a_pedestal`. It never changes once the owner has
marked the asset PASS. A revision changes the file, never the ID; a genuinely
different asset gets a new ID.

Paths:

```
assets/models/batch001/<family>/<asset_id>.glb
assets/models/batch001/<family>/manifest.json
assets/textures/batch001/<asset_id>.png
assets/textures/theme/<theme>_<role>.png
tools/blender/build_<thing>.py          # the source, beside nothing binary
docs/art/review/batch001/<letter>_<asset_id>.png
```

**No `.blend` file is the source of truth for anything.** A model is a
Python script plus `tools/blender/`, and `tools/check_art_current.sh`
rebuilds every one and fails if a committed artefact moved.

---

## 4. Materials and texturing

- **Albedo only.** No normal, roughness or AO maps. Ever.
- **NEAREST with mipmaps.** Blender sets `interpolation = "Closest"`, glTF
  carries sampler NEAREST, and the art bench reports the filter it actually
  found after loading — a walk that finds no materials says so loudly rather
  than reporting a quiet success.
- **One material per surface role.** A second material slot has to earn
  itself: the light fixture has two because a lens must be emissive and a
  housing must not.
- **Emissive: `common.make_signal_material()` and nothing else.** Dark
  albedo, bright emission, strength ≈ 1.0. Bright albedo plus bright
  emission clips to white — see `ART_BIBLE.md` §4c.

### UVs

```python
common.uv_project_world(obj, texels_per_metre, texture_size)  # everything
common.uv_unwrap_prop(obj)   # exists, and is NOT used in Batch 001
```

World-planar projection at a fixed density, for props as well as
architecture. `ART_BIBLE.md` §5 has the reasoning; the short version is that
`smart_project` gives adjacent modules independent islands, and adjacent
modules with independent islands show a break in the grain at every seam.

Density is asserted, not hoped for:

```python
common.assert_texel_density(obj, name, tier, texture_size)
```

**If the density is out of band, change the TEXTURE SIZE, not the UVs.** The
UVs are a world-scale projection and moving them breaks tiling.

---

## 5. Collision

**A PROP does not author collision. A ROOM SHELL does.** The two halves
of that sentence used to be one half, and the missing half cost a whole
integration.

### 5a. Props: fit the collider the engine already has

Godot owns collision and traversal truth for everything the engine
places, and `AUTHORED_CONTENT.md` §5 is explicit about it. A light
housing, a check, a portal, a prop: the engine has a collider for it
already, and what the art lane owes is an asset that fits inside,
asserted at build time:

```python
common.assert_fits(obj, name, max_size, why)
```

Every mechanical box in Batch 001 is read from the engine, never retyped:

| Asset | Box | Source |
| --- | --- | --- |
| Melee enemy | 0.8 × 1.6 × 0.8 m | `enemies/enemy.gd` |
| Check | 1.4 × 2.6 × 1.4 m | `gameplay/reward.gd` |
| Portal | ≤ 3.6 m wide | narrowest corridor `zone.py` permits (4.0 m) |
| Grapple anchor | 1.4 × 1.4 m footprint, 5.6 m clearance | `generation/affordance_features.gd` |
| Prop | 1.4 × 1.4 m | `PROP_FOOTPRINT`, `generation/chamber_builders.gd` |
| Architecture module | 4.0 m on its long axis | the texture grid and the room sizes `zone.py` bounds |

This guard has already caught four real overruns during Batch 001. When it
fires: **shrink the asset, never the clearance.** A ledge that is 1.4 m in
one Zone and 1.9 m in another has not added variety, it has made the jump
untrustworthy.

### 5b. Room shells: author it, because nobody else can

A room shell is not placed inside a room. It **is** the room, and there
is no engine collider waiting for it to fit into. `ART_ASSET_SPEC.md` §3
has always said so -- author collision, never auto-trimesh anything a
player touches, walkable surfaces get convex or box shapes, and the
`-col` / `-convcol` / `-colonly` name suffixes are the route -- and §5a
above was read as if it overrode that. It does not. It is about props.

The cost of the gap, measured: Production integrated the eight shells at
`eda4fd9` and could not measure one of them. Every shell imported with a
single MeshInstance3D and zero colliders; the audit fired 625 probes into
rooms that were not there and reported "nothing is under this" 625 times.
Not a wrong answer -- **no** answer, which is the failure mode the audit
refuses to call a pass.

`tools/blender/roomcollision.py` is the rule as code, and it is a
DERIVATION rather than eight hand-built colliders:

| what | how |
| --- | --- |
| which pieces collide | the `role` already passed to `_paint`: `floor`, `wall`, `ceiling` collide, `trim` does not |
| what shape | a copy of the piece -- every shell part is a `brushkit.block`, so its convex hull is the box exactly |
| how it imports | `-convcolonly`, so it is convex, invisible, and leaves no MeshInstance3D for the envelope check to trip on |
| what proves it | `verify_collision.gd` loads the shipped `.tscn` and counts real `CollisionShape3D`s |

**Trim does not collide, and that is the spec's rule, not a shortcut.**
Collision is never larger than the visual mesh. A platform nose is 0.14 m
wider than the slab it skirts; colliding it would make every platform
wider than the `Surface` the manifest declares, which is the S18 rule
broken by an art change -- a visual that moved a reachability.

A ninth shell inherits all of this by being built the way the eight are.
If you add a new painted role, `roomcollision.ROLES` refuses it until it
has decided whether it is structure or decoration.

---

## 6. Building

```sh
B=.tools/blender/blender

$B -b --python tools/blender/build_materials.py         # H, theme probes
$B -b --python tools/blender/build_architecture.py      # F, the mini-kit
$B -b --python tools/blender/build_props.py             # G, dressing
$B -b --python tools/blender/build_concept_epsilon.py   # A
$B -b --python tools/blender/build_concept_check.py     # B
$B -b --python tools/blender/build_concept_portal.py    # C
$B -b --python tools/blender/build_concept_enemy.py     # D
$B -b --python tools/blender/build_concept_anchor.py    # E
```

Each prints one line per asset: path, triangles, measured size, measured
texel density. Each writes a `manifest.json` beside its `.glb` files with
those metrics plus the anchor.

**Deterministic.** Every hash in `paintkit` is seeded from a stable string,
so the same source produces byte-identical output. That is what makes the
freshness check meaningful.

---

## 7. Verifying

```sh
python3 tools/blender/engine_truth.py     # every engineering number is live
python3 tools/blender/palette.py          # anchors, ramps, value sandwich
python3 tools/blender/derive_budgets.py   # the arithmetic behind every budget
tools/check_art_current.sh                # committed assets match their source
tools/sabotage_checks.sh                  # every guard still fires on purpose
```

Three habits, all of them paid for:

- **Assert on the effect, never on the input.** "The builder set flat
  shading" passes happily through a builder that stopped. `assert_flat()`
  looks at the polygons.
- **A check that has never failed is unverified.** `tools/sabotage_checks.sh`
  reintroduces each bug and confirms the guard fires. Run it before trusting
  a new guard.
- **A new bench is the least trustworthy thing in the repository.** Establish
  what an instrument measures before believing what it says.

---

## 8. Review evidence

```sh
tools/review_sheet.sh <model.glb> <out.png> <label> <judge_distance_m>
tools/batch001_sheets.sh     # every Batch 001 asset, at the right distance
tools/composed_room.sh       # I: the room, greyscale, and the three Checks
```

Eight shots, identical for every asset: front · three-quarter · side · rear ·
silhouette · clay · scale-against-a-1.8 m-rod · **play distance with the
measured pixel height printed on it**.

**The sheet does not grow.** The only property that makes it worth having is
that it is the same for every asset; the moment one asset gets a ninth shot
chosen to suit it, the sheet stops being a comparison and becomes each
asset's own showreel. Role-specific questions get their own command, run
alongside, and may never relax the gate.

The judging distance is not a free choice:

| Family | Distance | Why |
| --- | --- | --- |
| Enemy | 18 m | `ENEMY_AGGRO_RADIUS` — where you first see one |
| Check, portal | 30 m | the longest corridor `zone.py` permits |
| Epsilon | 6 m | a Hub conversation distance |
| Grapple anchor | 5 m | it hangs at 5.1 m and you look up from the floor |
| Architecture module | 4 m | one module width; you walk past a wall at this range |
| Prop | 3 m | you walk up to it |

---

## 9. Rendering, and the two traps in this sandbox

- **`--headless` cannot render.** It selects the dummy driver, which never
  presents a frame, so an awaited `SubViewport` capture hangs forever with
  no output at all. Use `xvfb-run -a godot --rendering-driver opengl3`.
- **A `class_name` script is invisible until an import pass** writes
  `.godot/global_script_class_cache.cfg`. A `-s` run does not rescan, so
  every reference fails with "Identifier not declared in the current scope"
  for a file that is plainly there. Both review scripts run `--import` once.
- Only the **Compatibility** renderer initialises here, so every capture is
  a lower bound on the owner's Forward+ build.
- Use `pkill -x godot`, never `pkill -f godot` — the latter matches its own
  command line and kills the shell running it.

---

## 10. Reaching the asset registry

**This does not exist yet, and Batch 001 does not depend on it.**

Today every visual in `godot/` is procedural, built from primitives in code,
and `AUTHORED_CONTENT.md` §6 records that as debt. There is no asset
registry, no scene contract that names a `.glb`, and no import path from
`assets/` into the game.

The interface the art lane needs, documented so engineering can build it
when the content contracts settle:

1. **A registry keyed by stable asset ID**, mapping an ID to a resource path
   plus its anchor, footprint and category. Epsilon selects an ID; Godot
   resolves it. Epsilon never sees or supplies a path — an Epsilon that can
   name a resource path is an Epsilon that can name any file.
2. **Import settings that preserve NEAREST with mipmaps.** The bench proves
   the *runtime* GLTF path keeps it; the *editor* import path is untested and
   is an open question.
3. **A decision on `TEXTURE_SIZE_MAX`** for imported assets. 128 bounds the
   runtime generator. Batch 001 stays under it so nothing depends on the
   answer; the deferred viewmodel tier needs 256.
4. **A footprint contract for the Epsilon presence.** `hub.gd` has a generic
   2.0 × 3.0 × 0.8 m terminal and no dedicated Epsilon fixture. The concepts
   are built to 1.4 × 1.4 × 2.8 m, inside that envelope on every axis, so
   whichever contract lands they already fit.
5. **A larger footprint, or a level-2 placement path, for composed
   clusters.** `PROP_FOOTPRINT` is 1.4 m, which is right for L0 and too small
   for an L2 station.

Until these exist: **consume a contract if it is there, document the
interface if it is not, keep the asset independently buildable, and wait.**
Never edit gameplay logic to make an asset convenient.

---

## 11. Staying off the engineering branch

The art lane lives on `claude/archipepsi-art`, based on
`claude/archipepsi-build-inzshp`, and **never pushes to it.**

Everything the art lane writes is in paths the engineering branch does not
have:

```
assets/          art_palette.json, art_budgets.json, models/, textures/
tools/           blender/, artpreview/, *.sh
docs/art/
```

`godot/` is **read but never written.** The art preview is a *separate
Godot project* at `tools/artpreview/` with its own `project.godot`, and it
loads `.glb` files from absolute paths at runtime rather than importing them
as project resources. That means:

- no file inside `godot/` changes, so no merge conflict is created
- the engineering CI's import pass never sees an art scene
- nothing in the art lane can break a headless suite

The preview mirrors `godot/project.godot`'s rendering settings and reads its
colours from the same generated constants, so it cannot flatter an asset with
settings the game does not use. `check_art_current.sh` compares the two.

When engineering's contracts stabilise, approved art can be rebased,
cherry-picked or merged deliberately — by then it will be a set of files in
paths nobody else touches, plus one registry the engineering lane owns.

---

## The camera

Shots are data. `tools/shoot.sh <list.json>` runs a shot list and writes a
folder of PNGs; adding a shot is a JSON object and nudging one is a number.

```sh
tools/shoot.sh tools/shots/demo.json            # -> docs/art/review/shots/
tools/shoot.sh tools/shots/mylist.json out/dir
```

### A shot

```json
{ "name": "epsilon_wide",
  "scene": "model:batch002/epsilon/epsilon_installation.glb",
  "frame": 0.75, "azimuth": 18, "elevation": 6, "lens": 35,
  "caption": "EPSILON", "variants": ["grey", "silhouette"] }
```

| Field | What |
| --- | --- |
| `scene` | `hub`, `void`, or `model:<path under assets/models>` |
| `frame` | fraction of the frame the subject fits inside; **the distance is solved** |
| `orbit` | `[radius, azimuth, elevation]` if you want to place it by hand |
| `eye` | `[x, y, z]` floor position, plus `yaw` and `pitch` — stand where the player stands |
| `look` | `[[from], [at]]` — the raw case |
| `lens` | 35 mm equivalent focal length. 24 wide, 35 normal-wide, 50 normal, 85 portrait |
| `game_lens` | `true` to shoot at the engine's own 90°. Use it for anything claiming to show what the player sees |
| `dolly` `truck` `pedestal` `roll` | relative nudges, applied after placement |
| `variants` | `grey`, `silhouette`, `clay`, `guides` |
| `caption` `note` | the two label lines |

`defaults` at the top of the list applies to every shot in it.

### Why focal length and not fov

`Camera3D.fov` is the **vertical** angle under Godot's default KEEP_HEIGHT,
so the same number is a different picture at a different aspect. Two benches
derived screen positions from a formula that assumed it was horizontal and
put every label in the wrong place (`ART_LESSONS.md` L-34). Focal length has
no such ambiguity, and `camera_rig.gd` converts it for the actual viewport.

The game's own camera is 90°, which is not a focal length and is not
pretended to be one — that is what `game_lens` is for.

### In the game itself

`docs/art/proposals/photo_mode.gd` is a complete in-game free camera —
fly, look, roll, lens on the wheel, hide the interface, save a PNG — plus
`frame()`, `frame_orbit()` and `frame_box()` for scripted shots, using the
same framing maths as the bench so a composition transfers.

**It is a proposal and the art lane did not install it.** It belongs in
`godot/`, which this lane does not write. The file carries its own install
note.
