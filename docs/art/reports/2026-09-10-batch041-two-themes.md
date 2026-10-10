# Batch 041 — one shipped room, two themes

**Arty** · art lane · branch `claude/archipepsi-art` · 2026-09-10

Inspection and proof. **No asset was rebuilt, no `.glb` exported, no
manifest field added, no schema or runtime changed, no review state
touched, no theme redesigned, and Wave 2 was not started.** All twelve
shipped shells are byte-identical to the revision this batch began at —
proved in §7, not asserted.

The Theme Pack system authority draft of 2026-09-03 arrived with this
brief. Its historical statements about which rooms were reviewed are
**superseded by the repository**: all twelve are `review: "pass"` as of
`ab74f5e`. Everything below is measured against the files as they stand.

---

## 1 · Source revisions

| | |
| --- | --- |
| Art head this batch began at | **`a2b6d59`** |
| Production revision inspected | **`2f727a7`**, `claude/archipepsi-echoes-continuation-b1adno` — read-only, **not merged** |
| Authority | `ARCHIPEPSI_THEME_PACK_SYSTEM_AUTHORITY_20260903.txt`, draft of 2026-09-03, supplied as a session attachment. **Not in the repository**, so §2 quotes it rather than linking it |
| Godot | 4.5.1.stable, Compatibility renderer (`opengl3`), under `xvfb` |
| Blender | 4.x headless, unused this batch — nothing was built |

Every shell in §3 carries the git blob id of the exact `.glb` it was
measured from, so the mapping is tied to a revision rather than to a
filename.

---

## 2 · The role contract, reconciled

### 2.1 What the draft requires, against what Art has

`REQUIRED_ROLES` and `OPTIONAL_ROLES` in
`tools/content/inspect_materials.py` are now transcriptions of §8.1 and
§8.2 rather than a list I chose.

| pack role | §8 status | fallback (§8.2) | Art texture today | verdict |
| --- | --- | --- | --- | --- |
| `floor` | **required** | — | 6 / 6 themes | met |
| `wall` | **required** | — | 6 / 6 | met |
| `trim` | **required** | — | 6 / 6 | met |
| `accent` | **required** | — | 6 / 6 | met as a texture; **no shipped shell uses an accent slot** |
| `hazard` | **required** | — | **0 / 6** | **not met — see G1** |
| `ceiling` | optional | → `wall` | 6 / 6 | authored outright, so the fallback never fires |
| `metal` | optional | → `trim` | 0 / 6 | acceptable: the fallback is the contract |
| `glass` | optional | → global safe glass | 0 / 6 | acceptable; the fallback is not a role, so no theme owes it |
| `emissive` | optional | → `accent`, emission off unless declared | 0 / 6 | acceptable |
| `decal` | optional | → `accent` | 0 / 6 | acceptable |

**37 PNG across six themes**, and the arithmetic is
6 themes × {`floor`, `wall`, `ceiling`, `trim`, `trim_plain`, `accent`}
= 36, plus `concrete_facility_wall_ribbed` = 37.

### 2.2 `trim_plain` and `wall_ribbed` are variants, not roles

They are recorded as `VARIANTS = {"trim_plain": "trim", "wall_ribbed":
"wall"}` — Art texture variants that resolve to a pack role *with a note*
and are deliberately absent from `ROLES`. Neither was promoted. Making
`wall_ribbed` a role would hand every future pack a seventh obligation
for one theme's convenience: `concrete_facility` is the only theme that
has ever had it.

### 2.3 Today's names are legacy, and the tool says so

§8.4 requires an imported surface material name to be the **exact
lowercase role id** — `floor`, never `cl_floor`, and never `floor.001`,
which it says an exporter must refuse rather than silently normalise.

**Not one of the 597 shipped slots complies.** All 597 are
`<prefix>_<role>[.NNN]`. The mapping records `naming: "legacy"` on every
shell and `canonical: 0` in its totals.

`resolve()` returns one of five kinds and **never guesses**:

| kind | meaning | resolves to a role? |
| --- | --- | --- |
| `canonical` | the name *is* a role id (§8.4) | yes |
| `legacy` | `<prefix>_<role>[.NNN]`, and the prefix belongs to one of the twelve enumerated shells | yes, with a note |
| `variant` | an Art texture variant | yes, to its parent role, with a note |
| `hero` | `hero_` prefix — protected, must be declared in `protected_materials` | **no** |
| `refused` | a role id carrying a Blender suffix — §8.4's own case | **no** |
| `unknown` | everything else | **no**, and it returns *why* |

A name is legacy because its shell is **enumerated by id** in
`LEGACY_SHELLS`, not because it matched a plausible-looking regular
expression. A thirteenth shell does not inherit the exemption by
resembling the twelve.

`python3 tools/content/inspect_materials.py --selftest` drives ten
probes through that classifier — the canonical id, the refused suffix, a
variant, a hero name, a typo, another shell's prefix, Blender's default
`Material.002`, and a role no shell uses. **10 probes, 0 wrong.** Every
refusal prints its diagnostic:

```
[sel] ok   cl_flooor   shell_corner_left -> unknown  REFUSED
      prefix `cl` recognised, but `flooor` is not a role or a known variant
[sel] ok   yd_floor    shell_corner_left -> unknown  REFUSED
      does not start with this shell's recognised prefix `cl_`
[sel] ok   floor.001   -                 -> refused  REFUSED
      `floor.001` is a role id carrying a Blender `.001` suffix;
      8.4 refuses it rather than normalising
```

---

## 3 · The compatibility mapping for the twelve shipped shells

`python3 tools/content/inspect_materials.py --map` →
`docs/art/review/theme_baseline_2026-09-10/role_map.json`.

**Inspection data under `docs/art/review/`. It is not a manifest, not a
schema, and nothing reads it at runtime.** No production field was added.

| shell | prefix | slots | images | blob | roles used |
| --- | --- | --- | --- | --- | --- |
| `shell_corner_left` | `cl` | 18 | 4 | `ba06f4dc` | ceiling floor trim wall |
| `shell_corner_right` | `cr` | 18 | 4 | `26f5bbbc` | ceiling floor trim wall |
| `shell_hall_transit` | `hl` | 77 | 4 | `ec67c93c` | ceiling floor trim wall |
| `shell_plenum_helix` | `pl` | 117 | 3 | `c862a693` | ceiling floor wall |
| `shell_span_basin` | `sp` | 56 | 4 | `3a75f010` | ceiling floor trim wall |
| `shell_tower_collapsed` | `tc` | 44 | 3 | `10d8927b` | floor trim wall |
| `shell_tower_gantry` | `tg` | 71 | 3 | `32576564` | floor trim wall |
| `shell_tower_spiral` | `ts` | 53 | 3 | `cc15ff28` | floor trim wall |
| `shell_treasure_cache` | `rc` | 38 | 4 | `7ab59330` | ceiling floor trim wall |
| `shell_treasure_coffer` | `rf` | 32 | 4 | `97682d50` | ceiling floor trim wall |
| `shell_treasure_vault` | `rv` | 30 | 4 | `ba420857` | ceiling floor trim wall |
| `shell_yard_gantry` | `yd` | 43 | 4 | `8acaaf06` | ceiling floor trim wall |

```
totals: canonical 0 | legacy 597 | variant 0 | hero 0 | refused 0 | unknown 0
```

**Every slot classifies. None is unknown, and none is guessed.**

Slots per role across all twelve: `floor` 274, `trim` 172, `wall` 137,
`ceiling` 14 — **597**. Two roles appear nowhere: **`accent`** (painted
in every theme, used by no shell) and **`hazard`** (painted in no theme).
The three towers are open-topped and have no `ceiling`; the plenum has no
`trim`. Those asymmetries are real, not defects.

---

## 4 · What Godot actually sees

The glTF file says one thing; the imported resource is what a binder
walks, and the two are not required to agree. Blender writes
`cl_floor.003` — Godot's importer may keep it, rename it, or leave
`resource_name` empty and leave only the surface index.

`tools/content/inspect_imported_materials.gd` loads all twelve `.tscn`
and records `mesh.surface_get_material(i).resource_name` per surface →
`imported_materials.json`.

```
mesh instances: 12
surfaces: 597   named: 597   blank: 0
shells with a NAME SET mismatch: 0   |  with a different order: 0
imported-name classification: {'legacy': 597}
```

**Godot preserves every name exactly, `.NNN` suffixes included, in the
same order.** So the role is recoverable at runtime from the imported
resource alone, in every approved shell, without a manifest field and
without re-exporting anything.

---

## 5 · One asset, two themes, at once

`tools/content/two_themes_proof.gd` instantiates
`res://content/shells/shell_corner_left.tscn` **twice** in one scene,
18 m apart, and themes instance A `concrete_facility` and instance B
`rusted_industrial` — by **`set_surface_override_material` per surface**,
per §8.5. No `.glb` was rebuilt, exported or touched.

Materials are keyed by `(theme, role)` and reused: **12 distinct
materials for 3 themes × 4 roles**, which is the draft's own rule that
assignment follows semantic role, not source-image identity.

### Results, from `instance_isolation.json`

| claim | measured |
| --- | --- |
| both instances share ONE imported mesh resource | `true` — `shell_corner_left.glb::ArrayMesh_n6pqu`, 18 surfaces |
| every surface resolves | 18 / 18 bound, **unresolved: 0** for A, B and the rebind |
| the shared mesh's own materials never change | identical before, after A, after B, and after the rebind |
| B is untouched while A is bound | B still carried no override at all |
| **A rebound to a *third* theme (`temple_ruin`) and B did not move** | B's 18 overrides byte-identical across the rebind |
| A did move | A's 18 overrides differ, as they must |
| collision unchanged by theming | 10 static bodies, 10 shapes, 22 nodes — digest identical before and after every bind, per instance |
| the two instances' structural digests match each other | `true` |

The structural digest takes each `CollisionShape3D`'s transform
**relative to its own instance root**, not in world space: the two
instances stand 18 m apart deliberately, so a global transform would
differ for a reason that has nothing to do with theming, and a digest
that always differs proves nothing.

### Images

| file | what |
| --- | --- |
| `TWO_THEMES_pair.png` | both instances, one scene, one frame — the evidence they coexist |
| `TWO_THEMES_A_concrete_facility.png` | inside A at eye height |
| `TWO_THEMES_B_rusted_industrial.png` | inside B, same camera geometry |
| `TWO_THEMES_comparison.png` | the phone-readable sheet: both interiors, the pair shot, and the ten PASS rows above |

All under `docs/art/review/theme_baseline_2026-09-10/`.

### What this proof does **not** cover

Honesty about §8.6 and §19.3, which ask for more than a collider digest:

* **covered** — identical collider count, shapes and instance-local
  transforms; identical node count; identical static-body count.
* **not covered** — socket / surface / traversal / volume / offer
  digests, `RoomAudit` results, and `MovementPackage` offer verdicts.
  Those live in Production's suites, and running them is not this
  batch's scope.
* **not covered** — §8.5's "binding is complete before the first visible
  frame". This is a `SceneTree` script that binds before it renders; a
  shipped binder has to guarantee it, and that guarantee is Production's.

---

## 6 · Unresolved contract gaps

Recorded honestly. **None of these was fixed here**, and none is a
decision the art lane may take alone.

**G1 — `hazard` is a required role and no theme has one, deliberately.**
This is a genuine contract collision, not a missing file. §8.1 makes
`hazard` a per-theme required role. The art lane's standing rule is the
opposite: `assets/art_palette.json` holds `hazard` under `universal`
with the note *"this will hurt you. Never used decoratively, in any
theme, for any reason"*, and `materials.py` says in as many words that a
theme-tinted hazard stripe is one the player has to re-learn. In
`rusted_industrial` the hazard band is composited **into** the trim
texture as a parameter (`_rust_trim_common(..., hazard)`), which is also
what backs `trim_plain`. §8.1 itself concedes that `hazard` "remains
subordinate to the engine's hazard readability rules".
*Recorded, not decided:* the coherent reading is that `hazard` is
required to **exist** and resolves to the **universal** ramp for every
pack — required, but not authored per theme. Production owns that call.

**G2 — `accent` is required, painted six times, and used by nothing.** A
pack author authoring an `accent` texture today is authoring for zero
shipped surfaces. Either the shells grow accent slots (a rebuild, out of
scope) or the role stays required-but-unused and the fact is written
down. It is now written down.

**G3 — every shipped name is legacy; zero are canonical.** Reaching §8.4
compliance means renaming materials in twelve builders and re-exporting
twelve `.glb`, which changes every shell's bytes. **Not started, and it
should not be started on speculation** — a binder can read the legacy
names today (§4), so this is a tidiness migration, not a blocker.

**G4 — no asset declares a material mode.** §8.3 requires every authored
visual asset to declare `themed`, `hybrid` or `authored`. The registry
entry schema is `category, display_name, exit_yaw, fallback, id, level,
review, scene, semantic_tags, size, size_class, sockets, surfaces,
volumes` — there is no such field, and this batch was told not to add
one.

**G5 — `protected_materials` does not exist either.** §8.4's `hero_`
mechanism has nowhere to be declared, so the classifier refuses a
`hero_` name rather than resolving it. That is the safe direction, and
it stays refused until the field exists.

**G6 — texture size sits below the draft's band.** Art paints theme
textures at **128 × 128**; §8.7's recommended band for tiling structural
textures is **256–512 px**. §8.7 also says nearest filtering "remains
available where it serves the late-90s look" and that these are gates,
not demands. So this is a *choice to confirm*, not a defect: 128 × 128
with NEAREST is the project's deliberate 1998 look, and raising it is a
visual decision, not a compliance one.

**G7 — the six-theme texture set still ships nowhere.** Only the preview
tool reads `assets/textures/theme/`. A binder cannot bind textures the
game does not have. Unchanged from the preparation report; repeated here
because §5 above quietly depends on it — the proof reads the loose PNGs
from `assets/`, which is exactly what a shipped binder could not do.

---

## 7 · Preservation checks

| check | result |
| --- | --- |
| twelve shipped shells byte-identical to `a2b6d59` | **yes** — `git diff --stat a2b6d59 -- assets/models godot/content assets/textures` is empty |
| any asset rebuilt or exported | **no** — Blender was not run |
| `THEME` build arguments added | **no** |
| manifest or schema fields added or changed | **no** — `godot/content/registry/authored_art.json` untouched |
| runtime changed | **no** — nothing under `godot/scripts/` was written |
| review state changed | **no** — twelve shells stay `pass`, three projectiles stay `pending` |
| new agency models | **none** |
| theme redesigns | **none** |
| Wave 2 | not started |
| `tools/check_art_current.sh` | **PASS** — every generated asset matches its source |
| `tools/blender/check_docs_metrics.py` | **PASS** — 245 of 245 built assets have their metrics quoted and verified |
| `python3 -m py_compile` on the changed tools | clean |
| `inspect_materials.py --selftest` | 10 probes, 0 wrong |
| `inspect_materials.py --map` | 597 classified, 0 unknown, 0 refused (exit 0) |

Shipped shell blob ids, unchanged:
`cl ba06f4dc` · `cr 26f5bbbc` · `hl ec67c93c` · `pl c862a693` ·
`sp 3a75f010` · `tc 10d8927b` · `tg 32576564` · `ts cc15ff28` ·
`rc 7ab59330` · `rf 97682d50` · `rv ba420857` · `yd 8acaaf06`

---

## 8 · What this is not

**A preview compatibility proof.** Not a shipped runtime binder, not
Theme Pack infrastructure, and not a completed migration to §8.4 naming.
It establishes three things and stops:

1. the role of every shipped surface is recoverable, by a classifier
   that diagnoses instead of guessing;
2. Godot hands that name to a binder intact;
3. two instances of one shipped room wear two themes at once, with the
   shared mesh untouched and the collision digest unchanged.

The rest — a texture set that ships, a declared material mode, a real
`ThemeBinder`, and a ruling on `hazard` — is Production's, or a later
batch's, or both.
