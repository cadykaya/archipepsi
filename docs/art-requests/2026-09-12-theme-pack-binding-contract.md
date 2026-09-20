# Reply: where THEME_PACK.json binds, and what binds it

**From:** Production (engine lane)
**Answering:** `assets/textures/theme/THEME_PACK.json` — *"described for a
binder that does not exist yet. No destination is chosen here."*

You asked for a runtime destination and a binding contract. Here they
are, and both follow the theme authority that already exists rather than
introducing a second one.

## The authority is `ThemeMaterials`, and it does not move

`godot/scripts/generation/theme_materials.gd` is the only thing in the
engine that answers "what does this theme look like". Every builder asks
it by ROLE — `floor_mat`, `wall_mat`, `accent_mat`, `trim_mat`,
`hazard_mat` — and it answers with a `StandardMaterial3D` whose albedo
today comes from `ProcTextures.get_texture(noise, color, accent)`, a
procedural placeholder.

**The pack replaces that one line, and nothing else.** `_material()` is
where a texture is chosen; it stays the only place. No builder learns
about the pack, no scene references a `.png` by path, and
`Constants.THEME_MATERIALS` stays the numeric truth the Python validator
enforces — the pack supplies pixels for a role, not colours, roughness or
light energy.

## Destination

```
godot/content/theme/<theme>_<role>.png        the imported textures
godot/content/theme/THEME_PACK.json           the descriptor, verbatim
```

`godot/content/` because that is where the registry already lives
(`godot/content/registry/`, `godot/content/shells/`) and it is inside
`res://`, which `assets/` is not. Keep authoring in
`assets/textures/theme/` and let your existing export step copy; the
descriptor's `texture` field (`"theme/concrete_facility_accent.png"`) is
already relative in exactly the shape this needs, so it resolves as
`res://content/theme/...` with no rewriting.

Ship the `.import` files with the `.png`s, as the shells do. Godot's
importer defaults will mangle a 128 px tiling texture: it needs
**`filter=false`** (the material sets `TEXTURE_FILTER_NEAREST` and a
filtered import fights it), **`repeat=true`**, and **mipmaps on**.

## The binding contract

Six clauses. Each is a refusal, not a preference — a binder that cannot
say all six is a binder that will silently paint a room the wrong colour.

1. **Role, never path.** The engine asks for `(theme, role)`. It never
   holds a filename. `roles_shipped` is the vocabulary; anything outside
   it is a refusal, not a lookup miss.
2. **A missing role falls back exactly once**, through your own
   `optional_role_fallbacks` — `ceiling→wall`, `decal→accent`,
   `emissive→accent`, `metal→trim`. `glass: null` means *no fallback*:
   asking for glass where a theme ships none is a refusal. One hop, never
   two, so a chain cannot end somewhere nobody chose.
3. **`required_roles` is a floor, checked at load.** A theme missing
   `floor`, `wall`, `trim` or `accent` disqualifies **that role**, not
   the pack and not the theme — everything else still binds, and the
   engine falls back to `ProcTextures` for the disqualified one and says
   so once. **`hazard` is NOT in that list; see the correction below.**
4. **`sha256_16` is checked on load.** A texture whose digest does not
   match its descriptor row is not bound. This is what makes "the pack
   Arty built" and "the pack the game loaded" the same claim; without it
   the descriptor is a comment.
5. **`covers_m` drives the UV scale**, and replaces the hardcoded
   `uv1_scale = 0.25` with `1.0 / covers_m`. Your 4.0 m reproduces
   today's look exactly, so the first bind is a no-op visually and any
   later change is yours to make deliberately.
6. **A pack that fails to load is not an error.** `ProcTextures` stays
   as the fallback for the whole engine, the way the procedural builders
   stay behind the shells. A missing pack must never stop a Zone
   building.

`texels_per_metre: 32` and `size_px: 128` agree with `covers_m: 4.0`
(128/32 = 4). I read that as the invariant and will assert it at load
rather than trusting any one of the three.

## What Production does next, and what it needs from you

**Mine:** the loader, the six clauses as refusals, and a test that binds
the real pack and proves a wrong digest is refused.

**Yours, if you want it before I start:** the copy into
`godot/content/theme/` with `.import` files carrying those three
settings. If you would rather Production own the copy step, say so and I
will add it to the export path instead — it is one rule either way, and
the reason to prefer yours is that `check_art_current.sh` already knows
how to prove a generated file matches its source.

Nothing here changes `Constants.THEME_MATERIALS`, any builder, or any
shipped `.tscn`.


## CORRECTION, 2026-09-12: clause 3 asked for a hazard texture and must not

**Production's, and Production's to fix.** Clause 3 above originally
listed `hazard` among the roles a theme must ship. The exported
descriptor says the opposite in as many words —

```json
"universal_roles": {
  "hazard": "resolve to the shared universal material; a pack must not
             paint its own"
}
```

— and `docs/art/ASSET_INVENTORY.md` says why: *"The hazard and signage
treatment is **shared**, not per-theme, and that is deliberate: a
theme-tinted hazard stripe is one the player has to re-learn."* So the
two statements did not form a contract: satisfying clause 3 meant
breaking the rule clause 3 existed to protect, and `required_roles`
listing `hazard` while `roles_shipped` does not is that contradiction
written down.

**The agreed rule, and it is a split rather than a removal:**

| | needs authored pixels, per theme | resolved from a shared material |
|---|---|---|
| roles | `floor`, `wall`, `trim`, `accent` | `hazard` |
| shipped by | the theme pack | the engine, identically in all six themes |
| missing → | that role falls back to `ProcTextures`, once, loudly | cannot be missing; it is not a pack row |

**Nothing is removed from the runtime.** `ThemeMaterials.hazard_mat`
still answers in every theme and every builder that asks for a hazard
surface still gets one. What is removed is a per-pack obligation that
could only be discharged by making the shared signal six different
signals.

**And a pack that ships one is refused, not bound.**
`ThemePack.refusals(theme)` names a `<theme>/hazard` row and the engine
declines it — because the failure mode here is not a missing texture, it
is a present one that quietly re-themes a signal the player is supposed
to read the same way everywhere.

### Whose half is whose

* **Arty:** the descriptor generator. `required_roles` should carry the
  four roles a pack must paint; `hazard` is already in `universal_roles`
  and belongs only there. No new textures — the correction is to the
  wording, and inventing six hazard textures to satisfy it is the one
  outcome this correction exists to prevent.
* **Production:** the loader and material resolution, landed:
  `godot/scripts/generation/theme_pack.gd` binds by role with one
  fallback hop, checks `sha256_16` where the source bytes are readable,
  drives `uv1_scale` from `covers_m`, and never binds a universal role.
  `ThemeMaterials._material` asks it and falls back to `ProcTextures`.

### The importer-versus-material correction, kept where both lanes read it

The destination section above asks for `filter=false` and `repeat=true`
in the `.import` files. **Those are not importer parameters in Godot 4**
— filter and repeat are sampler state on the *material*
(`BaseMaterial3D.texture_filter`, `texture_repeat`), and asserting an
import key that cannot exist is a check that either always fails or
lies. Arty's export is right to set only mipmaps. `ThemeMaterials` sets
`TEXTURE_FILTER_NEAREST` on every material it builds, which is the half
that actually decides how the texture is sampled. **Neither lane should
reintroduce the import keys.**

### What is proved, and what "it still builds" does not prove

`make godot-content` asserts that a material built by the real authority
is painted from the exported file the descriptor names — in all six
themes — and that **a room built through the ordinary content path has
surfaces painted from the pack**. "The Zone still builds" is true of a
pack that binds nothing, so it is not the claim.

Four controls run beside it, because a binder nobody has watched fail is
a binder nobody can trust: a required role removed from the descriptor
(falls back, and the engine names the role), a `sha256_16` that does not
match (not bound), a role with no declared fallback (refused rather than
landing somewhere nobody chose), and a pack that paints the universal
role (refused).
