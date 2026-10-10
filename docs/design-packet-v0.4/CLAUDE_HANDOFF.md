# Archipepsi — Coding Agent Handoff (v0.4)

You are implementing the Archipepsi proof of concept.

---

## Read first

`README.md`, then `DESIGN.md`, `TECHNICAL_ARCHITECTURE.md`, `APWORLD_SPEC.md`, `EPSILON_SPEC.md`, `IMPLEMENTATION_PLAN.md`, `ACCEPTANCE_TESTS.md`.

**No single document is the authority.** `README.md` defines the precedence order, with `schemas/` at the top. (v0.3's handoff told the agent to treat one file as the product *and* architecture authority, which collapsed the very structure the packet was split to create.)

`../design-packet/` (v0.3) and `../audit/` are history. Do not implement from them.

---

## Mission

Build the POC. Work autonomously for as long as the session permits.

**Your success criterion is: get as far down `IMPLEMENTATION_PLAN.md` §2 as possible while always leaving a working, runnable milestone.** It is not "finish the POC." The full surface is multi-day work; the plan is ordered so that stopping anywhere still leaves something real.

The first genuinely important milestone:

> Connect to Archipelago, scout 30 real locations, enter a generated Zone, clear a Check, watch the real item go to its real recipient, receive Epsilon's Echo of it, equip and fire it, return to the Hub, quit, reload, and still have the same accepted Zone and Echo.

---

## Non-negotiable boundaries

**Archipelago**
- Archipelago owns item placement, delivered items, and checked/missing locations.
- Deterministic Python code allocates AP location IDs. Epsilon may not add, remove, swap, reserve, renumber or check them.
- `game = "Archipepsi"`, `items_handling = 0b111`, `want_slot_data = True`.
- Automatic scouting uses `create_as_hint = 0`. Never non-zero.
- Refuse race-mode rooms before bulk scouting.
- **Finalize checks by reconciling against `checked_locations`, never by waiting for a server event.** `check_locations()` filters already-checked locations client-side and the server broadcasts nothing when nothing is new. Waiting hangs forever.
- Use `CommonContext` from the pinned checkout `bootstrap.py` creates. Do not write a second AP networking stack.

**Epsilon**
- Runtime Epsilon returns structured data only. Never execute model-generated code.
- Validate everything against `schemas/`. One repair attempt, then deterministic fallback.
- **Reject and repair; never silently clamp.**
- Treat AP-sourced strings as untrusted input.

**Gameplay**
- Every accepted Zone must be completable on the mandatory path with base movement and Pepsi Pop.
- No Echo-gated mandatory traversal. The schema cannot express one; keep it that way.
- **LMB is always Pepsi Pop. RMB is the equipped Echo.** Never rebind LMB on equip.
- Check 030 is reserved: never shop stock, never a normal Zone reward.
- Hub-only shop.

**Data safety**
- Persist pending Check and shop transactions **before** the network send.
- Save atomically: temp file, fsync, rename, keep one `.bak`.
- Reconcile against server truth after every reconnect.
- Never persist a second copy of AP truth and trust it over the server.
- API keys never enter committed files, Godot project files, or logs.

**Engine**
- Stock Godot 4.5.1 (`f62fdbde1`). Do not fork. No GDExtension without a recorded hard blocker.
- Python 3.11.15. Do not require a different interpreter.

---

## Rules that will save you time

**Copy `schemas/` verbatim.** It runs and it is tested. Run `pytest` on it before writing anything else — 37 tests, all green. Do not retype the models from the prose; the prose describes them, the code *is* them. Regenerate `constants.gd` and the JSON Schemas with `python schemas/export.py` and never hand-edit the outputs.

**Every gameplay number is already decided**, in `schemas/constants.py`. Do not invent movement, combat, or timing values. If one is missing, add it there rather than inline.

**Do not go asset shopping.** No searching for, downloading, or evaluating texture packs, asset packs or model libraries. Flat materials and procedurally generated 16×16 textures written in code. This rule exists because that search is an easy way to lose 45 minutes.

**Build the AP side first.** It is the risky part, it is provable in minutes with no engine, and if it fails nothing else matters. The Godot side degrades gracefully; the AP side does not.

**`--ap=real --epsilon=fallback` is your best test configuration.** The whole loop, no API cost, no nondeterminism.

---

## Handling missing detail

Do not stop for minor aesthetic choices. Choose the smallest implementation consistent with, in order: `DESIGN.md`, data safety, future local-Epsilon replacement, the acceptance tests.

Record every material deviation or assumption in `docs/IMPLEMENTATION_DECISIONS.md`.

If prose in this packet contradicts `schemas/`, the schema is right. Note the discrepancy and move on.

---

## What not to spend the session on

Inventing an engine. Building a voxel engine. Editor tooling. Making generated code execution work. Browsing for art. Polishing visuals before the loop functions. Abstractions the current slice does not exercise. Expanding catalogs before the current ones work end to end. A test framework addon for Godot.

---

## The one moment worth extra care

The reveal (`DESIGN.md` §16). Structurally it is the only genuinely novel moment in the loop — everything else is plumbing that exists to make it happen. Freeze input, show the card, play a sound, hold ~2 seconds. Treat it as core, not as polish that gets cut at T−30.

---

## Before the session ends — the T−60 rule

**T−60 minutes is a feature freeze. No new subsystems after that point.** No exceptions.

From T−60 the only permitted code changes are regression fixes to what already works. The goal is to leave the highest completed vertical slice fully running — not six later systems half-finished.

Then:

1. Make the highest completed milestone run end to end from documented commands.
2. Run **the T−60 gate** in `IMPLEMENTATION_PLAN.md` §1.1 — every automated test applicable to the phases you actually implemented — and record results **honestly**, including failures. Do not chase end-to-end tests for systems you never built.
3. Update `README.md` with exact setup and run commands, and the known limitations from `DESIGN.md` §18.
4. Update `docs/IMPLEMENTATION_DECISIONS.md`.
5. Write `docs/NEXT_STEPS.md` naming the exact next blocker.
6. Commit.

**Never sacrifice a working earlier milestone to leave a later subsystem half-integrated.** A working Phase 3 beats a broken Phase 5.
