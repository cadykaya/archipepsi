# Archipepsi — Coding Agent Handoff

You are implementing the Archipepsi proof of concept.

## Read first

Read these files before coding:

1. `README.md`
2. `DESIGN.md`
3. `TECHNICAL_ARCHITECTURE.md`
4. `APWORLD_SPEC.md`
5. `EPSILON_SPEC.md`
6. `IMPLEMENTATION_PLAN.md`
7. `ACCEPTANCE_TESTS.md`

Use `ARCHIPEPSI_POC_DESIGN_SPEC_v0.2_ORIGINAL.md` only to recover context missing from the split.

`CHAT_TRANSCRIPT.md` is intent/history, not authority.

## Mission

Build the POC described by the packet. Work autonomously for as long as the coding session permits.

Preserve a **running vertical slice at all times**.

The first important playable milestone is:

> Start a Mock Campaign, enter an ugly generated Zone, clear a Check, persist/confirm that Check, receive a Conference Call-like Echo, equip/use it, quit, reload, and still have the same accepted Zone/Echo.

Then add real Archipelago integration, then real Epsilon generation, then the shop.

## Non-negotiable boundaries

- Stock Godot 4.x. Do not fork Godot.
- Runtime Epsilon returns structured data only. Never execute model-generated code.
- Archipelago owns item placement, delivered items, and checked/missing locations.
- Deterministic Archipepsi code allocates real AP location IDs to Zones/Hub shop stock.
- Epsilon may not add/remove/swap/reserve/check AP location IDs.
- Every accepted generated Zone must remain mandatory-path completable with base movement and Pepsi Pop.
- No hard Echo-gated mandatory traversal in this POC.
- Hub-only shop.
- Persist pending Check/shop transactions **before** network send.
- Reconcile against server truth after reconnect.
- Use current Archipelago `CommonContext` infrastructure where compatible.
- Configure Archipepsi item handling as `0b111`.
- Automatic scouting uses `create_as_hint = 0`.
- Refuse race-mode rooms for the POC before bulk scouting.
- One model repair attempt, then deterministic fallback.
- API keys/passwords never enter committed game files or logs.

## How to handle missing detail

Do not stop for minor aesthetic choices.

Choose the smallest implementation consistent with:

1. `DESIGN.md`
2. data safety
3. future local-Epsilon replacement
4. the acceptance tests

Record every material deviation or assumption in:

`docs/IMPLEMENTATION_DECISIONS.md`

## What not to do

Do not spend the session:

- inventing a custom engine
- building a voxel engine
- creating elaborate editor tooling
- making generated code execution work
- polishing art before the loop functions
- building abstractions that are not exercised by the current vertical slice
- expanding the content catalogs before their current versions work end-to-end

## Before ending the coding session

Run the highest integrated acceptance path currently possible.

Leave:

- the executable/project in a running state
- tests/logs updated
- exact setup commands in README
- `docs/IMPLEMENTATION_DECISIONS.md` current
- a brief `docs/NEXT_STEPS.md` naming the next concrete blocker

Do not sacrifice a completed earlier milestone to leave a later subsystem half-integrated.
