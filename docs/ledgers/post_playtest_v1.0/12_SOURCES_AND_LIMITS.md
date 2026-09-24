# 12 — Source register, evidence boundaries and freshness

## Source IDs used in this packet

| ID | Source | What it supports / limitation |
|---|---|---|
| S00 | Skyiah's direct messages and supplied reports in this conversation | Owner feedback/requirements and reported experience. Not a recorded input trace or a verified local playtest save |
| S01 | `cadykaya/archipepsi@a745637`, `docs/ledgers/ov05_evidence/FROZEN_RUN.md` | Prod's 64-step Linux run at `46bf023`; not a run performed for this packet or Windows automation |
| S02 | Same ref, `docs/ledgers/PROD_OV05_READY_QUEUE.md` | Historical status of all 85 OV05 units; technical scope, blockers and limits retained |
| S03 | Same ref, `docs/AGENT_FRONTIER.md` and `docs/ledgers/PROD_OV05.md` | Handoff and temporary shared-seam ledger. Older lower frontier entries can be stale; the new owner feedback governs new requirements |
| S04 | Same ref, `docs/D11_THEME_PACK_PROD_ANSWER.md`, including §5 and §7 | Settled pack table/selection/fallback and delivered runtime; test packs are not approved production art |
| S05 | Mounted `ARCHIPEPSI_RIFT_DIRECTION_v0.3.1.md`, included unchanged | Approved workshop rules, explicitly unselected proposals, supersessions and 0.5/0.6 boundaries |
| S06 | Art archive `archipepsi-art-2026-09-22-ALL.zip`, README/reports/COVERAGE; `archipepsi@4093ded` coverage read | Seven in-progress kits, dated 81-row catalogue, no completed pack, course candidate and tooling trial. No fresh visual assessment of all frames here |
| S07 | `cadykaya/Caster-Guide-to-Fishing@a0eb2e4328dcc92ad8ae4856711691055b2faca3`, `scripts/ui/game_menu.gd` and `inventory_slot.gd` | Existing BG3-style layout and interaction reference; no render or live use of it in this handoff |
| S08 | `cadykaya/ECMS-GLYPH@87db9e20dd0c7cb1a1f7a3c617a47d5efa3526de`, `AGENTS.md`, `GAME_ASSETS.md`, prior art trial | Documented authoring/export features; ref rechecked. No new Glyph build, resource import or menu assembled here |
| S09 | `ARCHIPEPSI_TOOLCHAIN_REFRESH_2026-09-22.md`, included unchanged | Historical SigmAudio/Glyph feature and compatibility review. SigmAudio heads not freshly queried; no audio heard |
| S10 | Supplied full 0.4 scope, first-major approval, OV04/OV05 master/queue and recovered EX50-011/021/033 | Original obligations and scope labels; historical implementation assumptions may have been superseded |
| S11 | Godot 4.5 documentation: Pausing games and process mode | Paused physics/processes and still-active signals; implementation proposals must be tested in 4.5.1 |
| S12 | Godot 4.5 documentation: Using Viewports | Texture targets, input forwarding boundaries, separate worlds; does not implement the requested menu |
| S13 | Official godot-demo-projects `viewport/gui_in_3d/README.md` on master | Reference demo for GUI in 3D; not a pinned compatible code dependency or a claim it was run |
| S14 | Two supplied room research Markdown documents, included unchanged | Prior source-labelled research and proposed experiment methodology, not newly verified outside findings |

## Repository lookup references

Use the exact immutable ref with each path. Recheck the live branch at resumption; do not reset it to the reference merely because new commits exist.

- Archipepsi integrated handoff: `a7456373fc76d1c4f8148ccd6b1c6c0beb0eab70`.
- Frozen code reference: `46bf023` (resolve full SHA in the repository before executing a reproducibility run).
- Art delivery reference: `4093ded` on `claude/archipepsi-art`.
- Glyph new tooling: `87db9e20dd0c7cb1a1f7a3c617a47d5efa3526de` on `claude/feature-planning-roadmap-5oibiu`.
- Glyph prior Art authoring: `6c80b6315912a70b44c28d566ddff608eafa234a`.
- Caster's Guide reference: `a0eb2e4328dcc92ad8ae4856711691055b2faca3`.

## Public implementation references

These were read for implementation constraints, not to replace private project authority:

- https://docs.godotengine.org/en/4.5/tutorials/scripting/pausing_games.html
- https://docs.godotengine.org/en/4.5/tutorials/rendering/viewports.html
- https://raw.githubusercontent.com/godotengine/godot-demo-projects/master/viewport/gui_in_3d/README.md

All external implementation advice in this packet is labelled as a proposal. No source code from these pages is redistributed here.

## Important corrections carried forward

The old plate route was built to latch; its technical pass is not the owner's approval of pressure semantics. The Counterfire recollection is uncertain. Duplicate-room sightings are not yet a proven same-Zone duplication bug. Missing/noticed bombs is not a proven missing-grant bug. The unsafe enemy restoration is the owner's direct experience; exact record mechanics are for reproduction. Earlier arithmetic/code leads for artillery and flyer construction are not a new end-to-end test.

The old uploaded schema-8 save and older pressure-routing investigation concern another historical build. They are not used as the current candidate's equipment/encounter state. No personal save or raw user account data is packaged.

D-11's implementation supersedes Art's old namespace proposal. It does not approve the seven art candidates. The new Glyph UI mandate does not retroactively migrate old sources or make Glyph the accepted runtime generator for all 0.6 art. The new map request supersedes a previous no-map-design restriction only for the newly requested package.

## What was actually done to prepare this handoff

Read the conversation, relevant uploaded/reference materials and selected repository handoff/contract files. Confirmed the integrated Archipepsi and Glyph branch refs. Read Godot's official implementation references. Consolidated requirements, proposed work/dependencies, retained all 85 inherited units and produced this packet with file checksums.

No game or agent was started. No gameplay code, GitHub branch, PR, setting, grant, installed tool or original save was changed. No test suite, new asset build, listening review or Windows launcher was executed. No schedule/watch was armed. Work states in `data/WORK_QUEUE.json` are planned—not completed just because they have acceptance criteria.

## Source copies and versioning

`data/SOURCE_COPIES.json` lists unchanged included source bytes and their hashes. `SHA256SUMS.txt` covers the delivered packet. Historical references retain old instructions for provenance; the current root documents explain which ones are superseded. The all-in-one Markdown is derived from the modular documents, so editing the source sections and rebuilding avoids two divergent specifications.
