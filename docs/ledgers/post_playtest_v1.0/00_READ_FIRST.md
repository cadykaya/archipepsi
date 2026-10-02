# Archipepsi — post-playtest team handoff
## Repair the experience, preserve the programme, plan the next worlds

**Packet version:** 1.0 • **Prepared:** 24 September 2026 • **Owner:** Skyiah  
**Audience:** Prod, Dess, Arty • **Mode:** planning and handoff preparation; no agent dispatched and no repository changed by preparing this packet.

## The outcome we are protecting

The owner says the game is **a lot more fun**. Carrying the power cell and installing it in its receiver was particularly satisfying. Enemy audio helped distinguish threats. The machinery concepts are worth keeping.

The same playtest exposed unfair attacks, misleading enemy bodies, unsafe resumption, puzzle rewards that bypass their puzzles, unclear controls and goals, and an inventory that prevents the player understanding their own equipment. These are findings about the player's experience, not instructions to discard the working systems.

This packet brings together three different bodies of work:

| Track | What belongs here | What must not happen |
|---|---|---|
| **Near-term repair + interface package** | Combat/resume defects; selected room corrections; pressure/control semantics; actual 3D pause menu, equipment and map; reward visibility | Calling this only cosmetic polish, or claiming these changes finish all of 0.4 |
| **Inherited 0.4 completion** | Full accepted Amalgam and existing commitments, including the still-unearned Blindside loop and runtime-only systems awaiting delivery | Quietly moving unfinished 0.4 requirements to 0.5/0.6 |
| **Future 0.5 / 0.6 design** | Four-pillar dungeons, inhabiting factions, death/drop systems and station chapter; later generated visual Echoes, Temporal Echoes and workshops | Starting the whole future programme merely because it is documented |

The UI/map work is explicitly requested new scope. Its **release number is unassigned**; it must be planned and delivered as a named package, not omitted because an older order excluded map redesign. The broad room/generator overhaul remains 0.5. Documents are not evidence of implementation.

## Start here, by lane

**Prod:** read `dispatch/PROD_START.md`, then the relevant entries in `02_PLAYTEST_FINDINGS.md` and `03_DELIVERY_PLAN.md`. First execution slice, once resumed: preserve the reference and capture the unfair combat/resume failures. Do not start with a full suite or a new world generator.

**Dess:** read `dispatch/DESS_START.md`, then `09_CONTRACTS_AND_DECISIONS.md` and the inherited queue. First slice: reconcile Prod's authorized shared-seam edits, issue the narrow resume/pressure/reward/map contracts needed by the repairs, and advance the remaining acquisition decisions without inventing AP guarantees.

**Arty:** read `dispatch/ARTY_START.md`, then `04_3D_MENU_MAP_AND_GLYPH.md` and `11_TOOLCHAIN_AND_ART_RECONCILIATION.md`. First slice: one usable Glyph visual system for the inventory/control/map cues and one distance-readable enemy lineup, not seventy-four more unfinished packs.

Everyone receives **the same packet**. Each reads only the relevant contract/source when needed. Do not spend the reset rereading every historical document or reproducing the full 64-step baseline three times.

## Reference revisions and evidence

The review reference is `cadykaya/archipepsi` branch `claude/archipepsi-0-4-blindside`, handed off at **`a7456373fc76d1c4f8148ccd6b1c6c0beb0eab70`**. This ref was checked while preparing the packet. Prod's frozen local run was **`46bf023`**, 64/64 command steps, approximately 65 minutes, with 2,103 Python tests reported, 46 headless Godot suites and 11 live suites. The handoff above adds documents and the test-generated capture provenance, not gameplay code. [S01–S03]

Those are **Prod's reported Linux results**, not runs performed for this handoff. The owner subsequently played on Windows; the exact local commit/save digest for that session has not been independently verified here. Do not use an older uploaded save to decide whether tonight's candidate contained bombs.

Arty's preserved delivery is **`4093ded`**. Glyph's inspected newer tooling ref is **`87db9e20dd0c7cb1a1f7a3c617a47d5efa3526de`**; her previous authoring baseline was **`6c80b63`**. A new menu built with Glyph is an owner requirement, not permission to migrate every old art project. [S06–S08]

## Authority and execution

Direct owner feedback and later explicit rulings govern the requested change. They do not erase the record of what an earlier test proved. Preserve both: **historical technical status** and **new owner-review disposition**.

This packet is not a blanket approval of proposed API shapes, prices, migration behavior or future story choices. Owner requirements are labelled; engineering recommendations and unresolved choices are labelled separately. When Skyiah actually resumes a lane, that lane proceeds through its authorized, ready tasks and does not stop after one small integration. It stops at a real blocking decision, resource limit, owner stop instruction, or the chosen delivery checkpoint, with an exact remainder.

No heartbeat, background watcher, PR subscription, scheduled wake-up, or automatic 5 p.m. launch is authorized. The reset time is the owner's reported availability window, not a task scheduled by this packet. No purchases, model-key acquisition, tool-PR merge, artwork approval, default promotion, or original-save migration is implicit.

## Reading map

`01` records decisions; `02` preserves the playtest; `03` sequences delivery; `04` specifies the requested UI/map; `05` retains all 85 prior queue units; `06–08` preserve future gameplay and story; `09` defines contract/decision handoffs; `10` defines proof and review; `11` reconciles tools/art; `12` is the source register; `13` is the executable work inventory. `references/` is unchanged source history, not an instruction to execute every old order again.
