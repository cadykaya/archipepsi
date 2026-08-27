# Archipepsi — build state

## Where this is
**The full v0.7 POC (Phases 0–7) is complete and green**, and the build has
moved on to making it good to actually play. Everything below "What works"
is post-POC.

Proof the loop is real:
- `make godot-integration` plays the **entire campaign** headlessly through
  the live WebSocket bridge: 12 zones, tier unlocks, shop purchases with
  the double-buy refused (Test O), leave/resume (Test I), the finale,
  postgame (Test N), `ALL_CHECKS_CLEARED`, 26 foreign checks → 26 Echoes,
  nothing lost or duplicated. It also builds the Hub and checks its board.
- `python3 -m archipepsi_bridge.smoke_real` proves the same core loop plus
  **Test L** (kill the bridge at the loading screen; the GENERATED zone
  revives with its committed allocation) against a **real Archipelago
  0.6.7 server**.
- 191 pytest + the headless chamber-geometry suite.

## What works
- APWorld: `make seed` / `seed-multi` / `host` / `apworld` (official build
  component, manifest validated).
- Bridge: `make bridge` (real AP) / `make bridge-mock`; providers
  claude/mock/fallback behind validate → repair-once → fallback, with the
  generation archive and `make replay` to re-validate it (EPSILON_SPEC §14).
- Game: menu, Hub (8 modes, campaign board, shop, Echo terminal, abandon
  console, Static corruption + screen fuzz), 5 chamber builders with
  bending layouts, 3 enemies with distinct silhouettes, 10 Echo effects,
  reveal cards, zone title cards, inventory, pause, F3 overlay,
  procedural textures/audio.

## Post-POC work so far
- **Two adversarial review passes**, all findings fixed with regression
  tests. Notable: an externally-confirmed goal never set `goal_sent`;
  releasing a zone's last stuck location wedged reconcile; the tower's
  summit exit was sealed; the enemy sidestep tested post-slide velocity so
  it never fired.
- **Non-linear layouts**: 90° corners, alternating turns, exact rotated
  AABB overlap guards, forward-push clearance. 16-seed test across all
  themes including vertical chambers.
- **Mock Epsilon is a real designer** (six chamber shapes, boss rooms,
  authored notes). The fallback keeps its pinned §12.1 shape.
- **Readability**: objective waypoint (on-screen and edge-pinned with
  distance), zone progress, exit portal stating what holds it shut, damage
  direction wedge, Echo cooldown bar, campaign board showing all 30 Checks
  by tier tinted per recipient game.
- **Feel**: viewmodel with fire kick, hit punch, damage flash, footsteps,
  landing thump, room-tone hum, enemy damage tint, zone title cards.
- **Personality**: Epsilon graffiti, Static-garbled Hub board, Static-
  corrupted tracers, theme-signature props, designer notes surfaced.

## Latest session: playability pass (+ a third review)
- **Navigation**: objective waypoint (floats on target, pins to the screen
  edge as a chevron with distance), `CHECKS n/m CLAIMED`, exit portal
  stating what holds it shut. Zones bend now, so this is the readability
  the corner pieces owed.
- **Combat readability**: damage-direction wedge that tracks as you turn,
  Echo cooldown as a refilling bar, enemies that visibly cook toward
  death, distinct silhouettes per archetype (hunched charger / static
  tripod / heavy brute).
- **The multiworld, visible**: a campaign board on the Hub wall showing
  all 30 Checks in three rows of ten (the tier structure), each tinted by
  the game that receives its item — matching the bridge's sha256 theme
  rule exactly, pinned from both sides.
- **Presentation**: zone title cards with Epsilon's designer note and a
  featured-Echo credit, game-tinted reveal cards, muzzle flashes,
  footsteps, landing thumps, controls card, Epsilon narrating long
  generations.
- **Third adversarial review**, all findings fixed — several defeated the
  feature they were in (the title card printed "true"; the damage wedge
  never tracked; the waypoint chevron rendered off-screen; wounded
  enemies got dimmer; silhouettes clipped through doorways).

## Next useful work
1. **Play-feel pass on real hardware** — the manual checks in
   ACCEPTANCE_TESTS §7 (gap feel, reveal timing, Conference Call comedy)
   need human eyes. Cannot be done in this container.
2. **Live-fire the Claude provider** once `ANTHROPIC_API_KEY` exists
   (`EPSILON_PROVIDER=claude make bridge`); offline stub tests cover the
   mechanics, but a real generation archive would be the interesting thing
   — then `make replay` reports its first-try acceptance rate.
3. Secrets: the packet allows optional Echo-reachable alcoves (never on a
   mandatory path). Flavor-only payloads, since items are AP's alone.
4. Enemy audio: an aggro cue and a per-archetype attack tone. Currently
   only death and player fire make noise.

## Known blockers / bugs
None known. One recorded schema corner: `finale_offered` stays true in
postgame, so clients also require the goal to be missing
(`docs/IMPLEMENTATION_DECISIONS.md`).

## Commands
    make test                  # 191 pytest
    make godot-test            # chamber geometry
    make godot-integration     # the whole game, headlessly
    make replay ARCHIVE=<dir>  # re-validate a generation archive
    make seed-multi && make host && make bridge   # real server play
    godot-bin/godot --path godot                  # the game

Collect an archive while playing:
    cd bridge && python3 -m archipepsi_bridge --ap=mock --epsilon=mock \
      --archive-dir ../generation_archive
