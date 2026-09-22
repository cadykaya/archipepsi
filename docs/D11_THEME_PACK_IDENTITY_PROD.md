# D-11 — game-pack identity for the existing ThemePack consumer

**Dess → Prod.** A proposal to agree before either of us builds. The
owner's constraints are explicit: *"a backward-compatible pack identity
and resolution extension to the existing ThemePack consumer, keeping
game-pack identity distinct from the existing house families. No second
loader and no mass-renaming of existing themes."* **Nothing is
implemented.** I have deliberately not touched the schema, so we are
not building competing halves.

---

## 1. What exists

`constants.THEMES` is six **house families** — `concrete_facility`,
`rusted_industrial`, `neon_transit`, `gothic_stone`, `temple_ruin`,
`void_glitch` — and `Zone.theme` is exactly one of them.
`THEME_BY_GAME_HINT` maps a source game onto one of the six.

`theme_pack.gd` resolves `(theme, role)` against one descriptor at
`res://content/theme/THEME_PACK.json`, with a role fallback chain.

## 2. What is missing, stated precisely

A **game pack** — art authored for one source game — has no identity.
The only place it could go today is the theme name, and putting it
there means either renaming the six or overloading them. Both are ruled
out, and both would break every Zone already in a save.

## 3. The proposal: one optional field, one extra lookup key

**Bridge.** `Zone.theme_pack: str | None = None`, alongside the
unchanged `Zone.theme`.

- `Zone.theme` keeps its exact six-member vocabulary. No rename, no
  addition, no Zone in a save changes meaning.
- `theme_pack` is a separate identity, so a game pack and a house
  family can never be mistaken for each other — which is the owner's
  "distinct" requirement made structural rather than conventional.
- `None` is every Zone written before this, and it resolves exactly as
  today.

**Engine.** `ThemePack._resolve(theme, role)` gains one preceding
lookup: if a pack is named and the descriptor has a row for
`(pack, theme, role)`, use it; otherwise fall through to the existing
`(theme, role)` chain unchanged. Same loader, same descriptor file,
same fallback — one more key tried first.

**Descriptor.** An optional `packs` object beside the existing rows.
A descriptor without it is a descriptor that works exactly as it does
now, which is the backward-compatibility requirement discharged in the
file format as well as in the code.

## 4. Why the identity is a second field and not a prefixed name

A `"bomb_rush:neon_transit"` theme string would need `Zone.theme`'s
`Literal` opened to free text, and a closed vocabulary is the thing
that stops a Zone naming a theme nothing can render. Two fields keep
both closed: the family stays a `Literal`, and the pack is validated on
its own terms.

It also keeps the fallback honest. With two fields, a pack that lacks a
role falls back to a **named** house family that the Zone still
declares. With a merged string, the fallback target has to be
reconstructed by splitting it, and a split that failed would render a
grey box with nothing to point at.

## 5. What I would validate on my side

1. `theme_pack` charset and length, same treatment as every other id.
2. A Zone naming a pack still names a valid house family — so the
   fallback always has somewhere to go.
3. **Runtime-selected and owner-approved stay distinct from
   authored/imported.** The bridge would not select a pack on its own;
   a pack is named because something chose it, and until there is an
   approved selection rule the field is set by nothing in composition.
   That keeps the catalogue's coverage and a pack's production status
   from being read off each other.

## 6. What I need from you

Whether the resolution order in §3 is the one you want, and whether the
descriptor extension should be `packs` keyed by pack then theme, or a
flat `(pack, theme, role)` row list. Say which and I will land the
bridge half; I am not building it until then.
