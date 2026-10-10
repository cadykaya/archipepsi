# Archipepsi — Autonomous Build Packet v0.3

This packet reorganizes the self-audited v0.2 Archipepsi specification into smaller files so a coding agent can keep the relevant rules in context without having to reason across one 3,500+ line document.

It also preserves the complete v0.2 monolith and a transcript of the design conversation for intent/history.

## What to give the coding agent

Give it this entire directory/repository and tell it to read, in order:

1. `CLAUDE_HANDOFF.md`
2. `DESIGN.md`
3. `TECHNICAL_ARCHITECTURE.md`
4. `APWORLD_SPEC.md`
5. `EPSILON_SPEC.md`
6. `IMPLEMENTATION_PLAN.md`
7. `ACCEPTANCE_TESTS.md`
8. `DECISIONS_TO_REVIEW.md` only when it needs to know what is intentionally unresolved

`CHAT_TRANSCRIPT.md` is design context, not an implementation authority.

`ARCHIPEPSI_POC_DESIGN_SPEC_v0.2_ORIGINAL.md` is the preserved monolithic source and should be consulted if a split document appears to have lost context.

## Authority / conflict order

If two files appear to disagree, use this precedence:

1. **`DESIGN.md`** — what the game is and how it should feel/behave.
2. **`APWORLD_SPEC.md`** — Archipelago generation/network/game-logic rules.
3. **`EPSILON_SPEC.md`** — what Epsilon may receive, decide, and emit.
4. **`TECHNICAL_ARCHITECTURE.md`** — implementation boundaries, persistence, networking, security.
5. **`ACCEPTANCE_TESTS.md`** — observable pass/fail behavior.
6. **`IMPLEMENTATION_PLAN.md`** — build order and autonomous-work rules, not product truth.
7. **`ARCHIPEPSI_POC_DESIGN_SPEC_v0.2_ORIGINAL.md`** — fallback source when a detail is missing from the split.
8. **`CHAT_TRANSCRIPT.md`** — intent/history only. Later explicit specs beat older conversational brainstorming.

If a real technical constraint makes an authoritative requirement impossible, preserve the closest working behavior and record the deviation in `docs/IMPLEMENTATION_DECISIONS.md`. Do not silently redesign the product.

## POC mental model

```text
ARCHIPELAGO
owns randomized truth
        |
        v
COMMONCONTEXT-BASED PYTHON BRIDGE
normalizes AP state + talks to Epsilon
        |
        +----------------------+
        |                      |
        v                      v
DETERMINISTIC ALLOCATOR      EPSILON
chooses AP location IDs      designs presentation only
        |                      |
        +----------+-----------+
                   v
             VALIDATED JSON
                   |
                   v
                 GODOT
          builds template Zone
                   |
                   v
          PLAYER CLAIMS CHECK
                   |
                   v
          PERSIST PENDING TX
                   |
                   v
              AP CONFIRMS
              /        \
             v          v
      REAL ITEM SENT   LOCAL ECHO
                        |
                        v
                 FUTURE DESIGN
```

The most important boundary:

> **Archipelago decides the randomized truth. Archipepsi deterministic code decides which truth is currently presented. Epsilon decides what that presentation feels like.**

## Current POC

The proof of concept is intentionally small:

- 30 Archipepsi checks
- 2 Pepsi Keys / 3 formal AP tiers
- 10 Epsilon Coins
- fixed Hub
- 2–3 checks per generated Zone, target 3
- 5 chamber templates
- 3 enemy archetypes
- 3 objective types
- one equipped Echo at a time
- constrained composable Echo effects
- Hub-only shop
- Claude-compatible Epsilon provider first
- deterministic mock/fallback providers
- stock Godot 4.x
- Python bridge using current Archipelago client infrastructure
- no custom Godot fork
- no arbitrary model-generated executable code
- no mandatory Echo-gated traversal in the POC

## Important unresolved design questions

See `DECISIONS_TO_REVIEW.md`.

None of those questions should block the first vertical slice unless the coding agent reaches the affected feature and no safe default is already specified.

## Packet provenance

- `ARCHIPEPSI_POC_DESIGN_SPEC_v0.2_ORIGINAL.md` is the full self-audited source used to create these split files.
- `SOURCE_MAP.md` maps source sections into the split documents.
- `CHAT_TRANSCRIPT.md` preserves the visible Archipepsi design discussion leading to this packet.
