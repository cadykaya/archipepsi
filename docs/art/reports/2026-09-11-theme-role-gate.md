# Theme-pack gap 2 — the role convention, declared and enforced

**Arty**

2026-09-11. Art branch `claude/archipepsi-art`. The next unblocked item in
the theme-pack queue, taken after Batch 043 was pinned and packaged.

**Tooling and documentation only.** No asset, texture, schema, manifest or
registry field is changed. Every `.glb` is byte-identical.

---

## The gap, as the preparation report stated it

> **2** — *The theme role convention is undeclared and unchecked. F3 proves
> it holds in all 597 slots today; nothing stops the next builder breaking
> it.* **Owner: Art.** *Cheapest item on the list and every later step
> depends on it.*

Batch 041 reconciled the §8 contract and produced `role_map.json`. That is a
**report**: it enumerates twelve shells by name at a pinned revision and
records what they carry. Two things a report cannot do, and both mattered.

## Finding 1 — there are twenty-three shells, and twelve were checked

`assets/models/*/shells/` holds **23** shell `.glb` files. The Batch 041 role
map covers **12**. The other eleven — `shell_arena_balcony`,
`shell_arena_pillars`, `shell_arena_pit`, `shell_arena_split`,
`shell_corridor_bays`, `shell_corridor_gallery`, `shell_corridor_narrow`,
`shell_corridor_stepped`, `shell_path_ascent`, `shell_path_spans`,
`shell_path_stagger` — are the room-shell vocabulary of Batches 015–019.
They are approved, they ship nowhere yet, and **nothing had ever classified
their surfaces.**

They turn out to follow the same `<prefix>_<role>` convention (`ab_`, `aq_`,
`ap_`, `as_`, `cb_`, `cg_`, `cn_`, `cs_`, `pa_`, `pn_`, `ps_`), so this is a
coverage gap rather than a naming defect. Each prefix was **read from the
shell's own exported material names**, not inferred from its id, and each is
now declared in `inspect_materials.LEGACY_SHELLS`.

The role map accordingly grows from **597 slots across 12 shells** to
**894 across 23**, still 0 unknown and 0 refused.

## Finding 2 — nothing checked the themes at all

The proposed check had three halves and only the first existed: *"assert all
shipped shells parse `<prefix>_<role>`, **that every role a shell uses exists
in every theme, and that no theme is short a role**."*

## What was built

`tools/content/check_theme_roles.py`, wired into `tools/check_art_current.sh`
so it runs with every other standing check.

It **discovers** shells rather than listing them — both the authored sources
and the exported content pack, because a convention that holds in one and not
the other breaks on the way to the game. It classifies every material name
through `inspect_materials.resolve`, so there is one classifier and not two.

A shell that is neither canonically named nor declared is **refused**, and
that refusal is the point: a thirteenth shell must not inherit the exemption
by looking similar. Declaring one is a deliberate act recorded in a diff.

Then theme completeness, from the palette rather than a hard-coded list, so a
seventh theme is covered the moment it exists:

| case | result |
| --- | --- |
| a required role (§8.1) missing from any theme | **fail**, naming the role and the themes |
| an optional role (§8.2) missing, with its fallback present in every theme | pass, with a note |
| an optional role missing and its fallback also incomplete | **fail** |
| a role some theme has that no shell uses | note — a variant or a spare, not a gap |
| **a theme shipping its own `hazard` texture** | **fail** |

That last row is the owner's ruling of 2026-09-10 made enforceable: every
pack must **resolve** `hazard`, and may resolve it to the same shared
universal material, so a theme with no hazard texture is complete and a theme
that painted one would mean a pack had re-tinted a colour the art lane holds
universal.

## Current state

```
[roles] note: `hazard` resolved by the shared universal hazard ramp
              (owner ruling, 2026-09-10), and no theme paints one —
              which is the required state
[roles] PASS -- 23 shell(s), 894 material slot(s), 5 role(s) in use,
                6 theme(s), 0 unresolved
```

All six themes carry `wall`, `floor`, `trim`, `accent` and `ceiling`.
`trim_plain` is in all six and `wall_ribbed` in `concrete_facility` alone;
both are Art texture **variants**, not pack roles, and the gate treats them
as such so no future pack inherits a seventh obligation for one theme's
convenience.

## Sabotage — and one hole it found

Three cases were forced before the gate was trusted.

| forced | result |
| --- | --- |
| removed `gothic_stone_floor.png` | **failed**: *"role `floor` is used by 23 shell(s) and 1 theme(s) have no texture for it: gothic_stone. §8.1 makes it required."* |
| removed `void_glitch_ceiling.png` | passed with a note — correct, §8.2 sends `ceiling` to `wall`, which every theme has |
| added `gothic_stone_hazard.png` | **passed. Wrong.** |

The third was a real hole. The universal-role check ran inside the loop over
*roles some shell uses*, no shell uses `hazard`, so the branch never
executed — and the final loop then excused the stray texture as *"a variant
or a spare"*. A check that cannot fire on the case it exists for is not a
check.

It now runs over `UNIVERSAL_ROLES` unconditionally, because a universal role
is universal whether a shell has reached for it yet or not, and the failure
it guards against is most likely **before** one has. Re-forced:

```
[roles] 1 PROBLEM(S)
  - role `hazard` resolves to the shared universal hazard ramp (owner
    ruling, 2026-09-10), but gothic_stone ship a theme texture for it.
    A pack must not re-tint a universal colour.
```

## What this does not do

No ThemePack schema, compiler or runtime binder — those are Production's, and
three of the four dependencies the Batch 041 report named are still open:
the material-mode and `protected_materials` fields, where the six-theme
texture set lands, and the binder itself. The fourth, the `hazard` ruling,
is settled and is now enforced here.

Nothing is rebuilt, nothing is promoted, and no review state changes.

## Files

| | |
| --- | --- |
| `tools/content/check_theme_roles.py` | the gate |
| `tools/content/inspect_materials.py` | eleven shells declared, with their measured prefixes |
| `tools/check_art_current.sh` | runs the gate, and Batch 043's geometry verifier, with every other standing check |
| `docs/art/review/theme_baseline_2026-09-10/theme_role_gate.json` | the gate's own report data |
| `docs/art/review/theme_baseline_2026-09-10/role_map.json` | regenerated: 894 slots across 23 shells |
