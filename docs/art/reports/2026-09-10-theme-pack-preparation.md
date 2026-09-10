# Theme pack preparation — inventory, baselines and authoring gaps

**Arty** · art lane · branch `claude/archipepsi-art` · 2026-09-10

Inspection, baselines and documentation only. No schema, no compiler, no
runtime binder, no Wave 2, no asset redesign. Nothing approved was
touched: no geometry, collision, manifest, review state or runtime
appearance changed.

---

## 1 · Source revisions

| | |
| --- | --- |
| Art head inspected | **`7ecd3fe`** (all twelve shells `review: pass`) |
| Production revision inspected | **`2f727a7`**, `claude/archipepsi-echoes-continuation-b1adno`, read-only |
| Godot | 4.5.1.stable, Compatibility renderer (`opengl3`) |
| `ARCHIPEPSI_THEME_PACK_SYSTEM_AUTHORITY_2026-09-03.txt` | **not present** in the repository or the session workspace — **detailed contract comparisons are unavailable**, and everything below proceeds from this brief alone |

Production history was not merged. Its files were read through
`git show` only.

---

## 2 · The six themes, as they actually exist

### 2.1 The single source of colour

`Constants.THEME_MATERIALS` (Production, `godot/scripts/autoload/constants.gd`)
holds all six themes as seven keys each — `base_color`, `accent_color`,
`trim_color`, `light_color`, `light_energy`, `roughness`, `noise`. The Art
lane does not hold a second copy: `tools/blender/engine_truth.py` parses
Production's own file and `tools/blender/palette.py` builds every ramp
from it, with `check_art_current.sh` failing if they drift.

**This is already a theme pack's data half, and it already works.**

### 2.2 Two texture worlds that never meet

| | procedural | authored |
| --- | --- | --- |
| built by | `ProcTextures` (`godot/scripts/generation/textures.gd`) | `tools/blender/materials.py` → `paintkit` |
| when | at runtime, in code | at Blender export |
| size | 64 × 64 | 128 × 128 |
| driven by | `noise` name + base/accent | a hand-authored painter per theme *and* role |
| reaches the player | in every generated chamber | only baked inside a shipped `.glb` |

A generated chamber is themed at runtime and costs nothing to reskin. An
authored shell's theme is **frozen at export**. That is the whole problem
this preparation exists to describe.

### 2.3 What exists, per theme

**Textures — `assets/textures/theme/` (37 PNG + manifest).** Six roles per
theme: `wall`, `floor`, `ceiling`, `trim`, `trim_plain`, `accent`. All six
themes complete. `concrete_facility` additionally has `wall_ribbed`, which
**no other theme has** — the one role asymmetry in the set.

**Painters — `tools/blender/materials.py`, `_TREATMENTS`.** Six themes ×
six role keys, all authored, all distinct functions. Two share within a
theme rather than having their own: `rusted_industrial` and `void_glitch`
paint `ceiling` with the floor and wall painter respectively.

**Fixture housings — 6 ship, 10 exist.**

| theme | ships | source | also exists, no seam |
| --- | --- | --- | --- |
| `concrete_facility` | `arch_light_fixture` | `batch001/architecture` | — |
| `rusted_industrial` | `light_rusted_cage` | `batch014/lights` | `light_rusted_clamp` |
| `neon_transit` | `light_neon_channel` | `batch014/lights` | `light_neon_edge` |
| `gothic_stone` | `light_gothic_corona` | `batch014/lights` | `light_gothic_lantern` |
| `temple_ruin` | `light_temple_bowl` | `batch014/lights` | `light_temple_niche` |
| `void_glitch` | `light_void_absent` | `batch014/lights` | `light_void_debug` |

`concrete_facility` is the odd one out: its housing comes from batch001,
not from the batch014 set, so "the fixtures" is not one directory.

**Theme dressing — `assets/models/batch013/dressing/`, 5 props, ships
nowhere.** `prop_sconce` + `prop_sconce_flame` (gothic), `prop_transit_sign`
(neon), `prop_column_stump` + `prop_root_fall` (temple). **Not a six-way
set** — concrete, rusted and void have no dressing prop, and the manifest
carries no `theme` field, so the association is by filename only.

**Generic object skins — none.** Every prop, decoy, interaction and
landmark builder hard-codes `THEME = "concrete_facility"`. There is no
theme-parameterised object skin anywhere in the lane.

**Lighting, fog and background — Production's, and per theme already.**
`zone_builder.gd` builds one `Environment` per zone: `background_color` and
`fog_light_color` from `ThemeMaterials.void_color(theme)`, `ambient_light_color`
from `light_color(theme)`, `ambient_light_energy` 0.35, `fog_density` 0.012.
**Art contributes nothing to this and does not need to** — it is already
data-driven off the same six specs.

**Animated / emissive effects — none in any theme.** No shipped asset
carries an animation, and emission is used only in review overlays, which
never ship. `void_glitch`'s identity is a static checker.

**Authored ↔ procedural binding.** `ContentInstantiator.SHELL_FOR_TYPE`
maps five chamber types to the five `*_proc` ids. **All twelve authored
shells are still unreferenced by it** — they are shippable and unreached.
Every authored entry declares `fallback` to its procedural id, so a missing
authored scene degrades rather than fails.

### 2.4 Exists vs. actually used

| asset family | exists | ships in the pack | reaches a player today |
| --- | --- | --- | --- |
| theme textures (37 PNG) | ✔ | ✘ | ✘ — **only consumer is the preview tool** |
| room shells (12) | ✔ | ✔ | ✘ — `SHELL_FOR_TYPE` still names `*_proc` |
| fixture housings (6 of 10) | ✔ | ✔ | ✔ |
| projectile visuals (3) | ✔ | ✔ | ✘ — held `pending` |
| dressing, props, interaction, secrets, landmarks, decoys, gates, keys | ✔ | ✘ | ✘ — **no seam exists** |

**Shared resources and fallbacks.** One palette file
(`assets/art_palette.json`) with six themes plus six theme-independent
`universal` roles (`signal`, `hazard`, `identity`, `send`, `dead`,
`glitch`); `Constants.AFFORDANCE_SIGNAL` is the engine's own signal colour
and no theme may redefine it. Every content entry has a `fallback`. Inside
a shell, the 3–5 painted images are **already shared** across all its
material slots.

---

## 3 · The twelve approved shells — material-slot findings

### 3.1 What the files contain

Measured with `tools/content/inspect_materials.py` (new, inspection-only)
against the shipped `.glb` glTF JSON:

| shell | prefix | material slots | images | roles present |
| --- | --- | --- | --- | --- |
| `shell_corner_left` | `cl` | 18 | 4 | ceiling floor trim wall |
| `shell_corner_right` | `cr` | 18 | 4 | ceiling floor trim wall |
| `shell_hall_transit` | `hl` | 77 | 4 | ceiling floor trim wall |
| `shell_plenum_helix` | `pl` | **117** | 3 | ceiling floor wall |
| `shell_span_basin` | `sp` | 56 | 4 | ceiling floor trim wall |
| `shell_tower_collapsed` | `tc` | 44 | 3 | floor trim wall |
| `shell_tower_gantry` | `tg` | 71 | 3 | floor trim wall |
| `shell_tower_spiral` | `ts` | 53 | 3 | floor trim wall |
| `shell_treasure_cache` | `rc` | 38 | 4 | ceiling floor trim wall |
| `shell_treasure_coffer` | `rf` | 32 | 4 | ceiling floor trim wall |
| `shell_treasure_vault` | `rv` | 30 | 4 | ceiling floor trim wall |
| `shell_yard_gantry` | `yd` | 43 | 4 | ceiling floor trim wall |

**597 material slots across the twelve, for at most four roles.**

### 3.2 The findings

**F1 — the theme is a hard-coded constant in each builder.** Eleven shells
carry `THEME = "concrete_facility"`; `build_plenum.py` carries
`THEME = "rusted_industrial"`. Nothing parameterises it, so today a second
theme of any room means a second `.glb`.
*Smallest correction:* make `THEME` a build-time argument with the current
value as default. Source-only, one line per builder, no output change while
the default holds.

**F2 — one material per PART, not per role.** Blender's `join` keeps each
source object's material, and the glTF exporter emits one primitive per
material, so the plenum ships 117 slots named `pl_floor`, `pl_floor.001` …
`pl_floor.103`. Nothing addressable is per-role.
*Smallest correction:* none needed for a swap — see F3. If a per-role slot
is ever wanted, it is a merge in `common.join`, and it would change every
shell's bytes, so it should not be done on speculation.

**F3 — and yet every slot is machine-classifiable.** Checked, not assumed:
**597 of 597** material names parse as `<prefix>_<role>[.NNN]` with
`role ∈ {wall, floor, ceiling, trim, accent}`, and **every one carries a
base-colour texture**. The role a slot plays is recoverable from its name
today, in every approved shell.
*Smallest correction:* state that convention and check it. A ten-line gate
beside the existing ones, no asset change.

**F4 — the prefix is per room and undeclared.** Twelve shells, twelve
prefixes (`cl` `cr` `hl` `pl` `sp` `tc` `tg` `ts` `rc` `rf` `rv` `yd`),
none of them recorded anywhere a consumer could read. A binder must either
parse the stem before the first `_` or be handed the map.
*Smallest correction:* emit the prefix into the manifest entry the exporter
already writes. Additive metadata; no existing field changes.

**F5 — a different naming convention in the non-shell families.** Shells
use `<prefix>_<role>`; the interaction kit uses `<asset>_<part>`
(`int_wall_switch_body`, `_accent`, `_cores`). A single reskin rule cannot
serve both.
*Smallest correction:* leave it. Record that room reskinning and object
reskinning are two problems, and do not force one vocabulary onto both.

**F6 — role coverage is uneven, for real reasons.** No shell in the twelve
uses `accent`, although all six themes paint one. The three towers have no
`ceiling` (open-topped); the plenum has no `trim`. A pack author will
otherwise ship an `accent` texture nothing consumes.
*Smallest correction:* documentation. The asymmetry is honest.

**F7 — `wall_ribbed` exists only for `concrete_facility`.** A future pack
copying the concrete role list will be asked for a seventh texture the
other five themes have never had.
*Smallest correction:* decide whether `wall_ribbed` is a role or a concrete
speciality, and say so in the role list. No asset work either way.

**F8 — the shared-resource hazard is the opposite of the usual one.** The
images inside a shell are already deduplicated (117 slots, 3 images), so a
naive per-slot texture swap would replace the same image 117 times. Harmless,
but a binder should key on the *image*, not the slot.
*Smallest correction:* none. Recorded so the first implementation does not
discover it at runtime.

### 3.3 The mechanism already exists — in the preview tool

`tools/artpreview/ComposedRoom.gd::_retheme` does today, in Godot, what a
binder must do: for every material on a loaded `.glb` whose albedo texture
is non-null, it substitutes `assets/textures/theme/<theme>_<role>.png` and
re-asserts NEAREST filtering. It is how the six baselines in §5 were made.

Two things it does not do, and they are the actual gap:

* it is handed the role because it composes the room from known modules —
  a shipped shell would have to recover the role from the material name
  (F3 says that works);
* it reads loose PNGs from `assets/`, which **ship nowhere**.

**So the missing pieces are a role convention that is checked, a texture
set that ships, and about thirty lines of runtime.** Not a rebuild of
twelve rooms.

### 3.4 Minimum scaffold / check / preview workflow

The smallest thing that lets an ordinary future pack be authored without
editing gameplay code or rebuilding every room — **proposed, not built**:

| step | what | where it would live |
| --- | --- | --- |
| **scaffold** | one command that stamps a new theme's six role PNGs from `THEME_MATERIALS` plus a painter stub, so a pack starts complete rather than partial | `tools/blender/` beside `build_materials.py` |
| **check** | a gate asserting every shipped shell's material names parse as `<prefix>_<role>`, that each role a shell uses has a texture in every theme, and that no theme is missing a role another has | beside `measure_offers.py` in `verify_content_pack.sh` |
| **preview** | `composed_room.sh` extended to load a *shipped shell* and retheme it, so a pack is judged in the room it will appear in rather than in the batch001 test room | `tools/artpreview/` |
| **baseline** | today's `make_theme_contact_sheet.py`, re-run per pack, diffed against `baseline.json` | already exists (§5) |

Nothing in that list needs a schema, a compiler, or a change to any
approved asset.

---

## 4 · Agency visual inventory

Every asset below **exists and ships nowhere** — there is no seam for
interaction visuals in `ContentInstantiator`. That is a *runtime* gap, not
an art gap, and the two are separated in the last column.

| thing | visual | status | note |
| --- | --- | --- | --- |
| **button** | `batch028/interaction/int_wall_switch` | **available** | wall-mounted, carries the shared state plate |
| **pressure plate** | `batch028/interaction/int_weight_button` | **available** | floor plate, 0.96 × 0.23 m |
| **crate (carryable)** | `batch028/interaction/int_carryable` | **available** | 0.64 m, hand-scale grips |
| **crate (scenery)** | `batch001/props/prop_crate` | **reusable with adaptation** | no state plate; it is a prop |
| **crate (deliberate decoy)** | `batch035/decoys/dec_crate_fixed` | **available** | exists to look fixed. Do not reuse as an agent |
| **powered door — mechanism** | `batch028/interaction/int_door_mechanism` | **available** | the ram and housing |
| **powered door — leaf** | `batch006/architecture/door_standard` | **reusable with adaptation** | one material, no state plate, built as architecture |
| **bridge — static span** | `batch020/architecture/arch_beam_span` | **reusable with adaptation** | a beam, not a deck; no walkable surface declared |
| **bridge — moving deck** | `batch009/affordance/movplat_deck` | **reusable with adaptation** | built for the moving-platform affordance |
| **bridge — extending / retracting** | — | **missing** | no visual for a bridge that appears |
| supporting: key receiver, breakable, launcher, machinery, logic indicator | `batch028/interaction/*` | **available** | five more of the same family |

### State variants — two patterns already in the project

* **Baked pairs.** `checkpoint_inactive` / `checkpoint_activated`,
  `portal_core_locked` / `portal_core_unlocked`, `forge_bench` /
  `forge_bench_working`. One mesh per state.
* **One mesh, a runtime-tinted region.** The whole batch028 family carries
  a single recessed *state plate* in the `signal` colour, deliberately, so
  that nine primitives share one causal vocabulary instead of eighteen
  meshes.

**A finding on the second pattern.** The builder reserves a `state_visual`
(`MeshInstance3D`) and a `state_label` (`Label3D`) — but the export joins
everything into **one node**. `int_wall_switch.glb` has 1 node and 3
materials (`_body`, `_accent`, `_cores`). The state plate survives as the
**`_cores` material slot**, not as an addressable child node.
*Smallest correction:* either export the plate as its own node, or declare
`_cores` as the state slot. **Not repaired here** — which it should be
depends on how Production drives state, and that is not chosen yet.

**No variant was built for a chain that has not been selected.** The
inventory stops at what exists.

---

## 5 · Contact sheets

Two sheets, phone-readable, from real captures — nothing simulated:

* `docs/art/review/theme_baseline_2026-09-10/THEME_BASELINE_colour.png`
* `docs/art/review/theme_baseline_2026-09-10/THEME_BASELINE_value.png`
* `docs/art/review/theme_baseline_2026-09-10/baseline.json` — machine-readable sidecar
* `docs/art/review/theme_baseline_2026-09-10/_raw_<theme>/` — the twelve source captures

| | |
| --- | --- |
| scene | `tools/artpreview/ComposedRoom.gd` via `tools/composed_room.sh` |
| camera | the game's own camera rig, ComposedRoom probe framing |
| renderer | Godot 4.5.1 Compatibility (`opengl3`), 1280 × 720 |
| art revision | `7ecd3fe` |
| fixture | the housing the pack ships for each theme |

**What the baselines show, including the limitation.** The room is composed
from batch001 architecture modules and rethemed by
`ComposedRoom._retheme` — so these are *procedural-module* rooms wearing
six themes. **There is no capture of an authored shell in a second theme,
because that is not currently possible**: the shell's texture is baked at
export. That absence is the honest state of authored-room theming today.

**And a finding from the value sheet.** `concrete_facility`, `neon_transit`
and `gothic_stone` are near-identical in value structure — three of six read
as the same pale grey room, with theme identity carried almost entirely by
hue on props and accents. That is exactly the weakness the owner's backlog
note about Neon Transit describes, now measured rather than felt.

---

## 6 · Prioritised gaps and ownership

| # | gap | owner | why this order |
| --- | --- | --- | --- |
| **1** | **No authored shell is reachable.** `SHELL_FOR_TYPE` still names the five `*_proc` ids, so twelve passed rooms appear in no Zone. | **Production** | Stage 3B. Everything below is decoration until a player can stand in one. |
| **2** | **The theme role convention is undeclared and unchecked.** F3 proves it holds in all 597 slots today; nothing stops the next builder breaking it. | **Art** | Cheapest item on the list and every later step depends on it. |
| **3** | **The six-theme texture set ships nowhere.** Only the preview tool reads it. | **Art** to ship it, **Production** to decide where it lands | A binder cannot bind textures the game does not have. |
| **4** | **The theme is a build-time constant per builder.** F1. | **Art** | Unblocks a second theme of an existing room without a binder at all. |
| **5** | **No runtime retheme path for an authored shell.** The mechanism exists in the preview tool; the game has no equivalent. | **Production** (Art to supply the convention and the set) | The actual Theme Pack feature. Gaps 2–4 are its prerequisites. |
| **6** | **Interaction visuals have no seam.** Nine agency primitives ship nowhere. | **Production** | Independent of themes; blocks any agency chain. |
| **7** | **State addressing is ambiguous** — plate survives as a material slot, not a node. | **Art**, once Production picks how state is driven | Small, and premature to fix first. |
| **8** | **Three of six themes share a value structure.** | **Art**, backlog | Owner has already flagged the Neon Transit direction. Follows infrastructure. |
| **9** | **Dressing is not a six-way set; no generic object skins.** | **Art**, backlog | Only matters once props have a seam. |

---

## 7 · Proposed first bounded Art production batch

**Batch 041 — the theme role contract, and one room proved in two themes.**
Proposed only; not started, and it needs an owner brief.

| | |
| --- | --- |
| **1. Declare the role list** | `wall`, `floor`, `ceiling`, `trim`, `accent`, `trim_plain`, and a ruling on `wall_ribbed` (F7). Documentation. |
| **2. A gate** | assert all shipped shells parse `<prefix>_<role>`, that every role a shell uses exists in every theme, and that no theme is short a role. Beside `measure_offers.py`. |
| **3. Prefix into the manifest** | additive field, so a consumer need not parse names (F4). |
| **4. `THEME` as a build argument** | default unchanged, so every current asset stays byte-identical (F1). |
| **5. One room, two themes, as evidence** | rebuild `shell_corner_left` — 18 slots, the smallest of the twelve — under a second theme into a scratch path, and contact-sheet it beside the original. **Not exported, not reviewed, not promoted**: it exists to prove the pipeline end to end at the smallest possible size. |

**Dependencies.** Item 5 needs nothing from Production. Items 1–4 need
nothing from anybody. **None of this implements a binder**, and none of it
changes an approved asset — the byte-identity of all twelve shells is a
condition of the batch, not a hope.

**Explicitly not in it:** a ThemePack schema, a compiler, a runtime binder,
Wave 2, the Neon Transit or Void Glitch refreshes, the cold station theme,
and any agency asset.

---

## Standing state

* All twelve room shells remain `review: "pass"`; the three projectile
  substitutions remain `pending`.
* **No approved asset, manifest, review state or runtime appearance was
  changed by this task.**
* **Theme Pack infrastructure does not exist.** This is preparation.
* Wave 2 has not started.
