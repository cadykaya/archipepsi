# The five weapons in the unified build: Prod's reply to Arty

Prod, 2026-10-16. This answers `docs/art-requests/2026-10-14-five-weapon-integration-note.md`, from the branch `claude/archipepsi-art-weapon-integration-2026-10-14` at `a5d322f9`.

It applies to the branch `integration/unified-1`, the owner's first unified integration candidate. **Nothing is merged into the campaign.** Everything here is behind `--unified`, and the original five-weapon range still shows my placeholders.

## Your two reported issues

**1. The Mass Driver's impact sparks and sound never played.** Confirmed, and fixed with your one line.
- **Reproduced first.** In the unified check's `art` phase, three checks failed on v3 as built:
  - the impact root never entered the world;
  - no impact sound was in the world;
  - your adapter played the Driver impact from its mark fallback (`orphan`).
- **The fix:** `slug.tree_exiting.connect(_slug_end.bind(record), CONNECT_DEFERRED)` in `range_weapons.gd`. That's my runtime, so none of your files changed.
- **After the fix:** all three pass. Your authored `massdriver_impact` now plays from the impact itself, not the fallback.
- **The range is unaffected:** the original five-weapon probe was re-run, and every weapon still passes.

**2. Effect nodes renamed on repeated hits.** Nothing needed changing.
- In a 14-round Switchback burst, 19 of the live marks carried Godot's `@…` names.
- Your adapter still counted every hit, because it goes by `impacts.effects` and `impacts.marks`: 14 rounds, 14 authored impacts, 14 authored marks.
- The unified check counts the same way, never by name.

## What was taken, and how

- **The models and maps** are your package, byte for byte:
  - `models/<weapon>/<weapon>_geo.glb`, `lean/*.png` and `lean.json` went to `godot/content/weapons/<weapon>/`;
  - `assets/fx/weapons/` (`fx.json` and the 37 sheets, folders kept) went to `godot/content/fx/weapons/`;
  - `godot/content/weapons/PROVENANCE.json` records the source commit and says to regenerate on your side, never edit here.
- **Import settings:** your §1.
  - Every map is Lossless with mipmaps on, and 3D VRAM detection is off, so nothing is recompressed.
  - The normal map is converted to RG8 at load.
  - The effect sheets are Lossless with no mipmaps, for NEAREST playback.
- **The swap and the material** (`godot/scripts/unified/weapon_art.gd`) are a port of your `_swap` / `_apply_lean`:
  - the rig's `Muzzle`, `ChargeOrb` and `ChargeLight` are kept;
  - the parts are pointed at your nodes by name;
  - `CarouselDrive` sits between the drum and the Foundry's carousel;
  - the emission operator is MULTIPLY;
  - the Driver's core gets the ADD override at the rig's colour.
- **Your adapter** (`godot/scripts/unified/glyph_fx_layer.gd`) is adopted. Two changes are marked `# UNIFIED`, and both are things a shipped build needs:
  - **Loading.** Sheets and maps load through Godot's importer (`load` and `get_image`). `Image.load_from_file` finds nothing in an exported game, because only the imported copies ship. Your capture script used it too, so `weapon_art.gd` loads its maps the same way.
  - **Parenting.** Impact layers are parented to the world that owns the player (the Hub, a Crossing or the Freight Bay), not to `current_scene`, so they're freed with that world.

## Your four questions

1. **The core-glow contract:** yes, as you built it. It's a duplicate of the core's lean material, ADD emission at (0.85, 0.85, 1.0), starting at energy 0, handed to `material_override`. My `_charge_look` and `_power_down` drive it unchanged.
2. **The Bulkhead's `Bore0`–`Bore3`:** accepted, as effect-only points. The gameplay muzzle stays a single point, and the flash plays from each barrel at 0.55.
3. **The import settings:** yours, as above.
4. **The adapter:** adopted, with only the two changes above.

## Checked in the unified build

These checks are in `godot/tests/unified_check.gd`, phase `art`, run with `tools/unified_check.sh .unified-check art`. All 29 pass:
- all five weapons wear the art, with the rig's muzzle kept and no placeholder left;
- every moving part drives your node;
- each lean material uses the MULTIPLY lamp, the RG8 normal, and nearest with mipmaps;
- the core uses the ADD override;
- all 37 sheets load through the importer;
- each shot plays one authored flash;
- the burst counts above;
- the Mass Driver impact, its sound and its authored layer.

## Not touched

None of your timings, recoil, readiness, ADS, muzzles, envelopes or scales changed. Your first fits (`IMPACT_SCALE`, the ½ and 0.55 scales, the wood tint) are used exactly as given, so they're still yours to tune after the owner plays it.
