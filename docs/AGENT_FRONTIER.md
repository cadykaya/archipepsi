# Archipepsi autonomous frontier

This file is the cheap wake-up state. Keep it short and current. Use `NEXT_STEPS.md` for the detailed project/history handoff and the v0.8 packet for authoritative contract details.

## Current frontier
- Branch: `claude/archipepsi-build-inzshp`
- Last implementation handoff before this file: `b584f52` — S3 partial
- v0.7 POC: complete
- Echoes 2.0 S1 + S1.1: complete
- S2: complete for its stage; 21/28 Action verbs runnable
- S3: **partial** — Resources + 15 HUD channels landed
- Next after S3: S4 rule engine

## S3 remaining obligations
1. Prove §7 pressure valve: full + irrelevant collapses to idle strip; changing/relevant expands.
2. Prove `ResourcePalette.RESERVED` separation from damage/danger/confirmation colors with a minimum color-distance test.
3. Pin source-glyph determinism.
4. Document/test that `_is_cost_of_slotted_action` is intentionally unreachable until S5 links exist; add the live proof when S5 lands.
5. Add archive provenance required by S3.
6. Resolve whether `EchoGenerationRequest` should carry `over_soft_budget`; record the decision rather than leaving dead steering logic.

## Stage dependency trap
S3 Resources alone unlock **no** additional Action verb. Rules/costs/events are S4. Links/traits/statuses are S5. `DEFERRED_PRIMITIVES` must name the **last** required dependency stage, not the first.

Nothing spends a Resource yet. That is expected. A full Resource channel collapsing to an idle strip is intentional pressure-valve behavior.

## Unresolved decision
Traits currently apply because they are owned, rather than only while equipped. Do not silently change this. Re-evaluate against the v0.8 contract when S5 makes the decision operational, and record any change in `docs/IMPLEMENTATION_DECISIONS.md`.

## Last full green verification
At `b584f52` / clean handoff:
- `make test`: 241 passed
- `check_packet.py`: green, 10 docs
- `make godot-test`: GODOT CHAMBER TESTS OK
- `make godot-blink`: 5125 resolved / 17825 refused; GODOT BLINK TESTS OK
- `make godot-integration`: GODOT INTEGRATION OK, full 12-zone campaign

Do not assume these counts remain current after new commits; update this section only after the corresponding suites actually run green.

## Core invariants
AP integrity > save integrity > deterministic campaign state > playable integration > polish.

Archipelago owns randomized truth. Python owns campaign/allocation/save/fold truth. Epsilon owns presentation/creative structured interpretation only. Godot renders/simulates and sends player intents. Persistent state changes go through transitions. Mechanics are derived from the interpretation log and never persisted as a second truth. Preserve base-kit solvability.

<!-- Compact frontier format authored by ChatGPT / GPT-5.6 Sol, OpenAI. -->
