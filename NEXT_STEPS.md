# Archipepsi — build state

## Highest completed milestone
**The full v0.7 POC (Phases 0–7).** The entire campaign — scout, allocate,
generate, play, claim, confirm, Echo, shop, finale, postgame — is proven
end-to-end by `make godot-integration`, which plays the whole game
headlessly against the live mock bridge (12 zones, all 30 checks, goal
reported once, 26 foreign checks → 26 Echoes, purchases with the double-buy
refused). The bridge is also proven against a real Archipelago 0.6.7 server
(`python3 -m archipepsi_bridge.smoke_real`).

## What currently works
- 184 pytest tests (110 schema / 49 bridge+campaign+providers+Claude /
  25 APWorld) + headless Godot chamber tests + the full-campaign driver
- `make seed` / `make seed-multi` / `make host` / `make apworld`
  (official Build APWorlds component; manifest validated)
- Bridge: `make bridge` (real AP) / `make bridge-mock`; providers
  claude/mock/fallback with validate → repair-once → fallback and the
  generation archive (`--archive-dir`)
- Game: menu (connect/mock), Hub (8 modes, finale portal, abandon console,
  shop, echo terminal, Static corruption), 5 chamber builders, 3 enemies,
  10 Echo effects, reveal cards, inventory, pause, debug overlay,
  procedural tones and textures

## In progress / next useful work (post-POC polish)
Nothing half-built. Candidate improvements, roughly in value order:
1. **Play-feel pass on real hardware** — nobody has held it; the manual
   checks in ACCEPTANCE_TESTS §7 (gap feel, reveal timing, Conference Call
   comedy) need human eyes. Cannot be done in this container.
2. Visual depth: more brush variety per theme (trim pipes, buttresses,
   signage), corridor prop variety, hub screen-fuzz shader for Static.
3. Zone variety: additional safe chamber arrangement logic in builders
   (L-bends via rotated chaining would need overlap checks — design first).
4. Epsilon flavor: designer_note surfacing in the Hub board after
   completion; per-theme reveal card tints.
5. Live-fire the Claude provider once an ANTHROPIC_API_KEY is present
   (`make bridge` + `EPSILON_PROVIDER=claude`); the offline stub tests
   cover the mechanics but a real generation archive would be gold.
6. Robustness: bridge-restart-mid-zone manual pass (Test L is covered
   headlessly by test 18; the Godot-side resume path deserves a manual run).

## Known blockers / bugs
- None known. One recorded schema corner: `finale_offered` stays true in
  postgame; clients also require the goal missing
  (docs/IMPLEMENTATION_DECISIONS.md).

## Exact next concrete action
Pick item 2: extend `ChamberBuilders` with per-theme prop kits (pipe runs,
crates, wall panels, hanging cables) applied by deterministic RNG seeded
from chamber id — pure visual, no traversal impact, keeps every geometry
test green.

## Commands
    make test                # pytest suites
    make godot-test          # chamber geometry
    make godot-integration   # the whole game, headlessly
    make seed-multi && make host && make bridge   # real server play
    godot-bin/godot --path godot                  # the game
