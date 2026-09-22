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
