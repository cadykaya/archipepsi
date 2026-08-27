# Archipepsi — build state

## Highest completed milestone
Phase 2 (bridge): the entire campaign machine works headlessly against mock
AP **and against a real Archipelago 0.6.7 server** (`smoke_real.py`), with
save/reload showing no duplication. 180 tests green
(110 schema + 45 bridge + 25 APWorld).

## What currently works
- `make setup` / `make seed` / `make seed-multi` / `make host` (APWorld)
- `make test` — full suite from the repo root
- `make bridge` — WebSocket bridge on ws://127.0.0.1:38290
  (`--ap=real|mock`, `--epsilon=claude|mock|fallback`)
- `make smoke` — headless full loop: connect → scout → allocate →
  fallback-generate → enter → claim → confirm → Echo → equip → save →
  reload → regenerate
- `python3 -m archipepsi_bridge.smoke_real` — same against a live server
  (host one with `make host` first)
- Campaign brain: deterministic allocation (§10.5), tier gating, finale
  gating + goal reporting, shop stock/cadence/purchase/rollback, pending-
  check reconciliation (never event-waiting), Echo grant with bulk guard,
  WAITING_FOR_AP with reservation release, postgame.
- Providers: fallback + mock, with validate → one-repair → fallback
  pipeline and generation archive.

## In progress
Phase 3: Godot vertical slice. Godot 4.5.1.stable.official.f62fdbde1 is at
`godot-bin/godot` (downloaded; see docs/IMPLEMENTATION_DECISIONS.md).

## Remaining planned work
- Phase 3: bridge_client.gd, constants.gd export, main menu, Hub (8 modes),
  FPS controller, corridor+arena builders, melee enemy, claim flow, the
  reveal, Echo runtime (hitscan+recoil+knockback), inventory,
  enter/leave/exit/abandon.
- Phase 4: platform_path/tower/treasure_room builders, ranged/brute,
  remaining Echo effects.
- Phase 5: ClaudeEpsilonProvider (bridge-side pipeline is provider-ready).
- Phase 6: shop/finale UI in Godot (bridge logic already exists + tested).
- Phase 7: acceptance run, `.apworld` packaging via AP's build component.

## Known blockers / bugs
None known.

## Exact next concrete action
Run `make export` to generate `godot/scripts/autoload/constants.gd`, create
`godot/project.godot` pinned to 4.5.1, then write `bridge_client.gd`
(WebSocket + reconnect backoff + snapshot store) and the main menu scene.

## Commands
    make test                                   # 180 tests
    make smoke                                  # headless full loop
    make seed-multi && make host                # real server on :38281
    make bridge                                 # bridge for Godot
    godot-bin/godot --path godot --headless     # engine (once project exists)
