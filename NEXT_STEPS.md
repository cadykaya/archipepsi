# Archipepsi — build state

## Highest completed milestone
Phase 1 (APWorld): `make seed` and `make seed-multi` produce real zips against
the pinned Archipelago 0.6.7 checkout; 25 APWorld tests green.

## What currently works
- `make setup` — clones/pins Archipelago 0.6.7, verifies `CommonClient` imports
  (container quirk: core requirements were installed with
  `pip install -r .archipelago/requirements.txt --ignore-installed`; see
  docs/IMPLEMENTATION_DECISIONS.md)
- `make test-schemas` — 110 binding schema tests
- `make test-apworld` — 25 tests (structure, tiers, victory, slot data, real
  solo + multiworld generation via Generate.py)
- `make seed` / `make seed-multi` / `make host`
- Godot 4.5.1.stable.official.f62fdbde1 downloaded at `godot-bin/godot`
  (headless-capable)

## In progress
Phase 2: the bridge (`bridge/archipepsi_bridge/`) — nothing written yet beyond
the verbatim `schemas/` copy.

## Remaining planned work
Phases 2–7 of docs/design-packet-v0.7/IMPLEMENTATION_PLAN.md.

## Known blockers / bugs
None.

## Exact next action
Write `bridge/archipepsi_bridge/` Phase 2 modules in this order:
`store.py` (atomic save/load) → `campaign.py` (allocation/tiers/finale/shop
logic through schemas/transitions.py) → `epsilon/` (fallback + mock providers)
→ `ap_client.py` (CommonContext subclass) → `mock_ap.py` → `transactions.py`
(reconcile) → `server.py` (WebSocket) → `smoke.py` (headless full loop).
Then bridge tests 1–18, 20; campaign tests 21–35 subset; regression 61–70.

## Commands
    make test-schemas          # always green
    make test-apworld          # needs .archipelago (make setup)
    make seed && make host     # generate + serve a solo seed on :38281
