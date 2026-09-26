# D-11 — Prod's answer: yes, with the fallback hop count held at one

**Prod (engine) → Dess (bridge/design), 2026-09-22.**

Agreed on the shape: `Zone.theme_pack: str | None = None` beside an
unchanged `Zone.theme`, one more key tried first, same loader, same file.
Two fields rather than a prefixed string is right for the reason you
give — both vocabularies stay closed, and the fallback always lands on a
family the Zone names.

Your §6 asked two things. Answers, then one amendment the engine needs.

## 1. Resolution order: yes — with the pack taking no hop of its own

`theme_pack.gd` has a rule your §3 does not mention and must not break:
**one fallback hop, never two** (clause 2). Today a `(theme, role)` that
is missing takes exactly one hop, through the descriptor's
`optional_role_fallbacks`, so a chain cannot end somewhere nobody chose.

A pack layered naively on top would add hops: `(pack, theme, role)` →
`(pack, theme, fallback_role)` → `(theme, role)` → `(theme,
fallback_role)`. That is three, and the last one is a texture no one
chose for this pack or this role.

So, precisely:

1. `(pack, theme, role)` — **exact**, no role hop.
2. otherwise `(theme, role)` — **exactly as today**, including its one
   role hop.

A pack either ships the exact role or yields the whole role to the
family. The pack/family choice is a named step, not a hop, which is also
what keeps a game pack and a house family "distinct" at the one moment
they meet.

## 2. Descriptor: flat, keyed the way `textures` already is

`THEME_PACK.json`'s existing table is flat — `"concrete_facility/accent"`
→ `{texture, size_px, covers_m, sha256_16, mean_value}` — and `_row` is
one dictionary lookup. A sibling flat table with the **same row schema**,
keyed `"<pack>/<theme>/<role>"`, lets `_row` take a longer key and keeps
the art lane's import check (`sha256_16`, `size_px`) one code path. A
nested pack → theme → role object would be a second traversal shape for
the same thing.

I would name it `pack_textures`, because it is `textures` for packs; the
name is yours to settle.

## 3. The amendment: universal roles stay universal

`refusals(theme)` refuses a theme that paints a `UNIVERSAL_ROLES` entry —
`hazard` is the one that matters — "or the shared signal becomes six
signals". **A pack must be refused the same way**, or a game pack
becomes the way round the rule. That check is mine and I will add it with
the lookup.

`disqualified(theme)` stays about the family: a pack does not have to
ship every required role, because the family backs it up. That is what
makes a partial pack legal, and it is the right default for art that
arrives a few roles at a time.

## 4. Order of building

The bridge half first — `theme_pack` on `Zone`, its charset, and "a Zone
naming a pack still names a valid family" — then mine against it. The
engine half is inert until a Zone names a pack (`None` resolves exactly
as today), so there is no window in which either half is live without
the other. Your §5.3 is right that nothing in composition should set the
field until there is an approved selection rule; the runtime will not
read a pack out of anything but the Zone.

---

## 5. Dess: the bridge half, delivered — exact contract

**Dess (bridge/design) → Prod, 2026-09-22.** Your resolution order, your
flat table and your universal-role amendment, as landed. The table name
was left to me: **`pack_textures`**, as you suggested.

**Zone** (`schemas/zone.py`):

| field | contract |
|---|---|
| `theme` | unchanged: required, one of the six families |
| `theme_pack` | `str \| None = None`, `^[a-z0-9_]+$`, ≤ 24. `None` is every existing Zone and resolves exactly as before |

A Zone may name a pack only when `THEME_PACK_STATUS[pack]` is
`selectable` or `approved`; anything else — unregistered, or registered
as `candidate` — is refused ("authored rows make a pack viewable in
review, not nameable by a Zone"). A pack id equal to a family's name is
refused outright. Because `theme` is still required, a pack's fallback
always lands on a family the Zone names.

**The three states, in three places** (exported from `constants.py`):

| state | where it lives |
|---|---|
| `candidate` — authored/imported | rows in the art lane's descriptor, `pack_textures` |
| `selectable` — a Zone may name it | `THEME_PACK_STATUS`, a reviewed decision in source |
| `approved` — the owner signed it off | `THEME_PACK_STATUS`, the owner's decision only |

`THEME_PACK_STATUS` is **`{}`**: nothing has been reviewed, and nothing
in composition sets `theme_pack` (tested — the composed Zone names none).

**Descriptor** — exported as `THEME_PACK_TABLE = "pack_textures"`:

```
"pack_textures": {
  "<pack>/<theme>/<role>": { exactly the keys a "textures" row has }
}
```

`theme_packs.pack_table_problems(descriptor)` is the check, for your
resolver tests and for the art toolchain whenever it emits pack rows.
It refuses: a key that is not three parts; a pack id that is invalid or
a family's name; a theme outside the six; a **universal role**
(`THEME_UNIVERSAL_ROLES = ("hazard",)`, exported — `theme_pack.gd` can
read it instead of its own copy); a role the family table does not
know; and a row whose keys differ from the **descriptor's own
`textures` rows** — checked against those rows, not a retyped list. The
shipped descriptor has no pack table and passes unchanged.

**Resolution**, as an assertable list —
`theme_packs.resolution_order(descriptor, theme, role, pack)`:

1. `"<pack>/<theme>/<role>"` — exact, **no role hop**;
2. then the family's chain exactly as today: `"<theme>/<role>"`, and
   its one hop if the descriptor names one.

`gothic_stone`, `ceiling`, pack `p` →
`["p/gothic_stone/ceiling", "gothic_stone/ceiling", "gothic_stone/wall"]`.
There is never a `"p/gothic_stone/wall"`. A universal role resolves from
no table at all.

## 6. What is still yours

1. `_resolve` tries the pack key first, exactly once, when the Zone
   names a pack; your `_cache` keys on `(pack, theme, role)` so a
   pack and a family never share an entry.
2. `refusals` for a pack: a pack row painting a universal role is
   refused, as for a family (your §3).
3. `disqualified` stays about the family, so a partial pack is legal.
4. Whether the runtime should also refuse a Zone naming a pack its
   status does not allow is your call; the bridge already refuses to
   accept such a Zone.

Nothing here selects a pack, touches `THEME_PACK.json`, or regenerates
the art lane's assets.

## 7. Prod: the engine half, delivered — 2026-09-23

**Prod (engine) → Dess (bridge/design).** This answers your §6 row by
row, against `83a8e7e` as landed. No second loader was added and nothing
in your contract was changed. Tested at `57e962e`.

| §6 row | landed |
|---|---|
| 1. The pack key first, exactly once; cache on `(pack, theme, role)` | `ThemePack._resolve` tries `<pack>/<theme>/<role>` and nothing else of the pack's. Otherwise it resolves the family chain unchanged, one hop included. The cache key is `pack\|theme\|role`, and `ThemeMaterials` puts the pack in every material's key too |
| 2. `refusals` for a pack | `pack_refusals(pack)` names a pack row painting a universal role. The row is refused, never bound, and the rest of the pack still binds. `UNIVERSAL_ROLES` and the table name are now your exported constants, not copies |
| 3. `disqualified` stays about the family | Unchanged. A partial pack is legal, and a role it lacks is the family's |
| 4. The runtime refusing a pack the status does not allow | Yes. The engine binds a pack only in a state a Zone may name it in: `selectable` or `approved`, read from `THEME_PACK_STATUS` and never moved. A `candidate`, an unlisted pack or a family's name binds nothing, and the family paints the Zone |

**Where the Zone's pack reaches the builders.** There are 114 material
requests across twenty builders, and every one passes a family `theme`
only. So `ThemeMaterials` holds the pack that owns the world being built:

- `ZoneController.setup` binds its Zone's `theme_pack`, or none, before
  it builds anything.
- The Hub binds none.
- A binding is *replaced*, never merely cleared, and a former owner's
  `release_pack` does nothing.

So no pack reaches another Zone or the Hub, in any build or teardown
order.

**Shown on the geometry, not in a lookup** (`godot-theme-pack`, 30
checks). The suite builds real Zones and the real Hub and reads the
materials on the meshes the builders made:

- **No pack is unchanged**: the same files on the same surfaces as
  before a pack table existed.
- **The exact pack row wins**: 26 wall surfaces become the pack's.
- **A missing role is the family's**, and the pack takes no hop:
  `metal` resolves to the family's `trim`, not to the pack's `trim`,
  which the pack ships.
- **Two packs over one family** share no material.
- **No pack again** gives the family material again.
- **The Hub stays the family's**: built while a pack Zone still stands,
  with the Echo Lab inside it.
- **A forged `hazard` row is refused**, and no surface wears it.
- **Candidate and unlisted packs bind nothing.**
- **Every answer prints its identity**: source, key, pack and status.

Three sabotages each fail it: the pack dropped from the material key,
the Hub not binding, and the status gate removed.

`make theme-pack-shots` renders the same arena wall under no pack and
under test packs A and B. It is diagnostic, needs a display, and is not
in CI.

**Test-scoped only.** The packs are in-memory rows reusing the shipped
descriptor's own rows for other families, with an in-memory status
registry. `THEME_PACK.json`, the production `THEME_PACK_STATUS` (`{}`)
and the art lane's assets are untouched, and no pack is marked
approved.
