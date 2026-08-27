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

## Post-POC work completed this run
- Acceptance Test I (leave/resume) runs inside the integration driver.
- Feel: first-person viewmodel with fire kick, enemy hit punch, damage
  flash, pulse/death tones.
- Look: greeble pass (ribs, ceiling beams, cables, vents, crates,
  buttresses, hazard strips), deterministic per chamber, lane-checked.
- Personality: Hub board quotes the last completed Zone and its
  designer_note; Epsilon Static garbles the board headline on a crawl
  timer; authored Epsilon graffiti appears on corridor walls; Static Pulse
  tracers discolor as Static accumulates; the victory card holds longer.

## Next useful work (roughly in value order)
1. **Play-feel pass on real hardware** — the manual checks in
   ACCEPTANCE_TESTS §7 (gap feel, reveal timing, Conference Call comedy)
   need human eyes. Cannot be done in this container.
2. Live-fire the Claude provider once an ANTHROPIC_API_KEY is present
   (`EPSILON_PROVIDER=claude make bridge`); offline stub tests cover the
   mechanics but a real generation archive would be gold.
3. Zone variety: safe non-linear arrangements (L-bends need rotated
   chaining + overlap checks — design before building).
4. Hub screen-fuzz shader tied to Static (a CanvasLayer shader, subtle).
5. Robustness: bridge-restart-mid-zone manual pass (Test L headless
   equivalent is covered by bridge test 18).

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
